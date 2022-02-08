// Copyright 2022 Ryohei Kobayashi
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <fcntl.h>
#include <omp.h>
#include <sys/stat.h>
#include <thrust/device_ptr.h>
#include <thrust/sort.h>
#include <unistd.h>

#include <random>
#include <vector>

#ifndef CL_HPP_ENABLE_EXCEPTIONS
#define CL_HPP_ENABLE_EXCEPTIONS
#endif
#ifndef CL_TARGET_OPENCL_VERSION
#define CL_TARGET_OPENCL_VERSION 200
#endif
#ifndef CL_HPP_TARGET_OPENCL_VERSION
#define CL_HPP_TARGET_OPENCL_VERSION 200
#endif
#ifndef CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#endif

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wignored-qualifiers"
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wsign-compare"
#include <CL/cl.h>
#include <CL/cl_ext_intelfpga.h>

#include <CL/cl2.hpp>
#pragma GCC diagnostic pop

#include <time.h>

class Timer {
 public:
  Timer();
  ~Timer();
  void Reset();
  void Start();
  void Stop();
  void Display();
  double Seconds();

 private:
  double seconds_;
  double ref_;
};

Timer::Timer() {
  seconds_ = 0.0;
  ref_ = 0.0;
  struct timespec ts;
  clock_getres(CLOCK_MONOTONIC, &ts);
  fprintf(stderr, "Timer Initialized (precision: %ld.%09ld sec)\n",
          (long)ts.tv_sec, ts.tv_nsec);
}

Timer::~Timer() {}

void Timer::Reset() {
  seconds_ = 0.0;
  ref_ = 0.0;
}

void Timer::Start() {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  ref_ = (double)(ts.tv_sec) + (double)ts.tv_nsec * 1e-9;
}

void Timer::Stop() {
  seconds_ -= ref_;
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  ref_ = (double)(ts.tv_sec) + (double)ts.tv_nsec * 1e-9;
  seconds_ += ref_;
}

void Timer::Display() {
  fprintf(stderr, "Elapsed time: \t%lf sec\n", seconds_);
}

double Timer::Seconds() { return seconds_; }

#define CUCHECK(call)                                                         \
  {                                                                           \
    cudaError err = call;                                                     \
    if (cudaSuccess != err) {                                                 \
      fprintf(stderr, "Cuda error in file '%s' in line %i : %s.\n", __FILE__, \
              __LINE__, cudaGetErrorString(err));                             \
      exit(EXIT_FAILURE);                                                     \
    }                                                                         \
  }

struct Elem {
  unsigned int key;
  unsigned int val;
};

struct Arr {
  unsigned int *key;
  unsigned int *val;

  Arr(size_t numdata_) {
    size_t const buf_size = sizeof(unsigned int) * numdata_;
    CUCHECK(cudaMalloc(&key, buf_size));
    CUCHECK(cudaMalloc(&val, buf_size));
  }

  ~Arr() {
    CUCHECK(cudaFree(key));
    CUCHECK(cudaFree(val));
  }
};

template <typename T>
class dev_cmp_custom_key {
 public:
  __host__ __device__ bool operator()(const T &lhs, const T &rhs) const {
    return (lhs.key < rhs.key);
  }
};

int main(int argc, char **argv) {
  if (argc == 1) {
    fprintf(stderr,
            "Usage: ./test_fpga_sort.exe <AOCX file> <numdata in log scale>\n");
    // fprintf(stderr, "\n");
    exit(EXIT_FAILURE);
  }
  if (argc != 3) {
    fprintf(stderr, "Error!\nThe number of arguments is wrong.\n");
    exit(EXIT_FAILURE);
  }

  ///// Create platform //////
  cl::Platform platform;
  std::vector<cl::Platform> platforms;
  cl::Platform::get(&platforms);

  for (auto &p : platforms) {
    auto const name = p.getInfo<CL_PLATFORM_NAME>();
    if (name.find("Intel(R) FPGA SDK for OpenCL(TM)") != std::string::npos) {
      platform = p;
      break;
    }
  }

  if (!platform()) {
    throw cl::Error(CL_DEVICE_NOT_FOUND, "Platform not found");
  }
  if (cl::Platform::setDefault(platform) != platform) {
    throw cl::Error(CL_DEVICE_NOT_FOUND, "Platform not found");
  }

  ///// Check aocx //////
  auto const fd = open(argv[1], O_RDONLY);
  if (fd == -1) {
    perror("open");
    throw cl::Error(CL_INVALID_PROGRAM_EXECUTABLE, "open(2)");
  }

  struct stat st;

  if (fstat(fd, &st)) {
    throw cl::Error(CL_INVALID_PROGRAM_EXECUTABLE, "fstat(2)");
  }

  auto data = new char[st.st_size];
  if (read(fd, data, st.st_size) != st.st_size) {
    throw cl::Error(CL_INVALID_PROGRAM_EXECUTABLE, "read(2)");
  }

  ///// Create context //////
  int dev_idx = 0;
  char const *str;
  str = getenv("OMPI_COMM_WORLD_LOCAL_RANK");
  if (str) {
    dev_idx = atoi(str);
  }

  std::vector<cl::Device> devs;
  platform.getDevices(CL_DEVICE_TYPE_ALL, &devs);
  auto const &dev = devs.at(dev_idx);
  auto ctx = cl::Context{dev};

  cl::Context::setDefault(ctx);
  cl::Device::setDefault(dev);

  ///// Create program /////
  auto dev_cl = dev();
  auto len = static_cast<size_t>(st.st_size);
  auto image = (const unsigned char *)data;
  cl_int error;

  auto prg = clCreateProgramWithBinary(ctx(), 1, &dev_cl, &len, &image, nullptr,
                                       &error);
  cl::detail::errHandler(error, "clCreateProgramWithBinary");

  ///// Create command queue /////
  cl::CommandQueue cq0(ctx, dev);

  ///// Create kernel /////
  cl::Kernel k_fpga_sort(cl::Program(prg, true), "intel_fpga_sort");

  ///// Create kernel functor /////
  cl::KernelFunctor<cl::Buffer, cl::Buffer, cl::Buffer, cl_uint, cl::Buffer>
      f_fpga_sort(k_fpga_sort);

  ///// Create buffer (for host and device) /////
  size_t const numdata = (1 << (std::stoull(std::string(argv[2]))));
  size_t const BUF_SIZE = sizeof(cl_uint2) * numdata;

  ///// host buffers
  cl_uint2 *h_send;
  cl_uint2 *h_recv;
  posix_memalign((void **)&h_send, 64, BUF_SIZE);
  posix_memalign((void **)&h_recv, 64, BUF_SIZE);

  ///// device buffers
  cl::Buffer d_dummy(ctx, CL_MEM_READ_WRITE, sizeof(cl_uint2));
  cl::Buffer d_dst(ctx, CL_MEM_READ_WRITE, BUF_SIZE);
  cl::Buffer d_src(ctx, CL_MEM_READ_WRITE, BUF_SIZE);
  cl::Buffer d_ret(ctx, CL_MEM_READ_WRITE, sizeof(cl_ulong));

  ///// Set init data /////
#pragma omp parallel
  {
    std::mt19937 g(omp_get_thread_num() + 1);
    std::uniform_int_distribution<> d(0, INT32_MAX - 1);
#pragma omp for
    for (size_t i = 0; i < numdata; ++i) {
      h_send[i].s[0] = d(g);        // key
      h_send[i].s[1] = 0xffffffff;  // value
    }
  }

  memset(h_recv, 0x0, BUF_SIZE);

  ///// OpenCL-enabled FPGA sort //////
  /////////////////////////////////////
  /// Show this experiment setup
  fprintf(stderr, "Configuration\n");
  fprintf(stderr, "========================\n");
  fprintf(stderr, "numdata = %zu (%zu bytes)\n", numdata, BUF_SIZE);
  fprintf(stderr, "OpenMP Version %d\n", _OPENMP);
  fprintf(stderr, "GPU programming: CUDA Version %d\n", __CUDACC_VER_MAJOR__);
  fprintf(stderr, "FPGA programming: %s\n",
          platform.getInfo<CL_PLATFORM_VERSION>().c_str());
  Timer stop_watch;

  /// Set FPGA data to be sorted
  cq0.enqueueWriteBuffer(d_src, CL_TRUE, 0, BUF_SIZE, h_send);

  /// Invoke FPGA sort
  stop_watch.Reset();
  stop_watch.Start();
  f_fpga_sort(cl::EnqueueArgs(cq0, cl::NDRange(1), cl::NDRange(1)), d_dummy,
              d_dst, d_src, (cl_uint)numdata, d_ret);
  cq0.finish();
  stop_watch.Stop();
  const double fpga_elapsed_time = stop_watch.Seconds();

  /// Do verification
  fprintf(stderr, "\n");
  fprintf(stderr, "Verification\n");
  fprintf(stderr, "========================\n");

  // Retrieve data to be verified from FPGA
  cl_ulong h_ret;
  cq0.enqueueReadBuffer(d_ret, CL_TRUE, 0, sizeof(cl_ulong), &h_ret);
  cq0.enqueueReadBuffer(((h_ret == 0) ? d_src : d_dst), CL_TRUE, 0, BUF_SIZE,
                        h_recv);

  // Prepare correct data by using GPU
  /********** Data structure: AoS **********/
  Elem *gpu_h_buf;
  CUCHECK(cudaMallocHost(&gpu_h_buf, BUF_SIZE));

#pragma omp parallel for
  for (size_t i = 0; i < numdata; ++i) {
    gpu_h_buf[i].key = h_send[i].s[0];
    gpu_h_buf[i].val = h_send[i].s[1];
  }

  Elem *gpu_d_buf;
  CUCHECK(cudaMalloc(&gpu_d_buf, BUF_SIZE));

  CUCHECK(cudaMemcpy(gpu_d_buf, gpu_h_buf, BUF_SIZE, cudaMemcpyHostToDevice));
  thrust::device_ptr<Elem> d_buf_ptr(gpu_d_buf);

  stop_watch.Reset();
  stop_watch.Start();
  thrust::sort(&d_buf_ptr[0], &d_buf_ptr[numdata], dev_cmp_custom_key<Elem>());
  stop_watch.Stop();
  const double gpu_elapsed_time_aos = stop_watch.Seconds();

  CUCHECK(cudaMemcpy(gpu_h_buf, gpu_d_buf, BUF_SIZE, cudaMemcpyDeviceToHost));

  // Check data
#pragma omp parallel for
  for (int i = 0; i < (int)numdata; i++) {
    if (gpu_h_buf[i].key != h_recv[i].s[0]) {
      fprintf(stderr, "Failed!\n");
      fprintf(stderr, "gpu_h_buf[%d].key = %08x, h_recv[%d].s[0] = %08x\n", i,
              gpu_h_buf[i].key, i, h_recv[i].s[0]);
      exit(EXIT_FAILURE);
    }
  }

  CUCHECK(cudaFreeHost(gpu_h_buf));
  CUCHECK(cudaFree(gpu_d_buf));

  /********** Data structure: SoA **********/
  unsigned int *key_array;
  unsigned int *val_array;
  size_t const buf_size = sizeof(unsigned int) * numdata;
  CUCHECK(cudaMallocHost(&key_array, buf_size));
  CUCHECK(cudaMallocHost(&val_array, buf_size));
#pragma omp parallel for
  for (size_t i = 0; i < numdata; ++i) {
    key_array[i] = h_send[i].s[0];
    val_array[i] = h_send[i].s[1];
  }

  Arr gpu_mem(numdata);

  CUCHECK(cudaMemcpy(gpu_mem.key, key_array, buf_size, cudaMemcpyHostToDevice));
  CUCHECK(cudaMemcpy(gpu_mem.val, val_array, buf_size, cudaMemcpyHostToDevice));

  thrust::device_ptr<unsigned int> dev_ptr_key(gpu_mem.key);
  thrust::device_ptr<unsigned int> dev_ptr_val(gpu_mem.val);

  stop_watch.Reset();
  stop_watch.Start();
  thrust::sort_by_key(&dev_ptr_key[0], &dev_ptr_key[numdata], &dev_ptr_val[0]);
  stop_watch.Stop();
  const double gpu_elapsed_time_soa = stop_watch.Seconds();

  CUCHECK(cudaMemcpy(key_array, gpu_mem.key, buf_size, cudaMemcpyDeviceToHost));
  CUCHECK(cudaMemcpy(val_array, gpu_mem.val, buf_size, cudaMemcpyDeviceToHost));

  // Check data
#pragma omp parallel for
  for (int i = 0; i < (int)numdata; i++) {
    if (key_array[i] != h_recv[i].s[0]) {
      fprintf(stderr, "Failed!\n");
      fprintf(stderr, "key_array[%d] = %08x, h_recv[%d].s[0] = %08x\n", i,
              key_array[i], i, h_recv[i].s[0]);
      exit(EXIT_FAILURE);
    }
  }

  CUCHECK(cudaFreeHost(key_array));
  CUCHECK(cudaFreeHost(val_array));

  // Show result
  fprintf(stderr, "Passed!\n");
  fprintf(stderr, "------------------------------\n");
  for (int i = 0; i < 10; i++) {
    fprintf(stderr, "h_recv[%d].s[0] = %08x\n", i, h_recv[i].s[0]);
  }
  fprintf(stderr, ".....\n");
  for (int i = (int)(numdata - 10); i < (int)numdata; i++) {
    fprintf(stderr, "h_recv[%d].s[0] = %08x\n", i, h_recv[i].s[0]);
  }
  fprintf(stderr, "------------------------------\n");

  fprintf(stderr, "FPGA elapsed time:\t%lf sec\n", fpga_elapsed_time);
  fprintf(stderr, "GPU elapsed time (AoS):\t%lf sec\n", gpu_elapsed_time_aos);
  fprintf(stderr, "GPU elapsed time (SoA):\t%lf sec\n", gpu_elapsed_time_soa);

  free(h_send);
  free(h_recv);

  return 0;
}
