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
#include <unistd.h>

#include <algorithm>
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

class my_uint2_less {
 public:
  bool operator()(const cl_uint2& left, const cl_uint2& right) const {
    return (left.s[0] < right.s[0]);
  }
};

int main(int argc, char** argv) {
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

  for (auto& p : platforms) {
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
  char const* str;
  str = getenv("OMPI_COMM_WORLD_LOCAL_RANK");
  if (str) {
    dev_idx = atoi(str);
  }

  std::vector<cl::Device> devs;
  platform.getDevices(CL_DEVICE_TYPE_ALL, &devs);
  auto const& dev = devs.at(dev_idx);
  auto ctx = cl::Context{dev};

  cl::Context::setDefault(ctx);
  cl::Device::setDefault(dev);

  ///// Create program /////
  auto dev_cl = dev();
  auto len = static_cast<size_t>(st.st_size);
  auto image = (const unsigned char*)data;
  cl_int error;

  auto prg = clCreateProgramWithBinary(ctx(), 1, &dev_cl, &len, &image, nullptr,
                                       &error);
  cl::detail::errHandler(error, "clCreateProgramWithBinary");

  ///// Create command queue /////
  cl::CommandQueue cq0(ctx, dev);

  ///// Create kernel /////
  cl::Kernel k_fpga_sort(cl::Program(prg, true), "tb_fpga_sort");

  ///// Create kernel functor /////
  cl::KernelFunctor<cl::Buffer, cl::Buffer, cl::Buffer, cl_uint, cl::Buffer>
      f_fpga_sort(k_fpga_sort);

  ///// Create buffer (for host and device) /////
  size_t const numdata = (1 << (std::stoull(std::string(argv[2]))));
  size_t const BUF_SIZE = sizeof(cl_uint2) * numdata;

  ///// host buffers
  cl_uint2* h_send;
  cl_uint2* h_recv;
  posix_memalign((void**)&h_send, 64, BUF_SIZE);
  posix_memalign((void**)&h_recv, 64, BUF_SIZE);

  ///// device buffers
  cl::Buffer d_dummy(ctx, CL_MEM_READ_WRITE, sizeof(cl_uint2));
  cl::Buffer d_dst(ctx, CL_MEM_READ_WRITE, BUF_SIZE);
  cl::Buffer d_src(ctx, CL_MEM_READ_WRITE, BUF_SIZE);
  cl::Buffer d_cycle(ctx, CL_MEM_READ_WRITE, sizeof(cl_ulong));

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
  // fprintf(stderr, "GPU programming: OpenACC Version %d\n", _OPENACC);
  fprintf(stderr, "FPGA programming: %s\n",
          platform.getInfo<CL_PLATFORM_VERSION>().c_str());

  /// Set FPGA data to be sorted
  cq0.enqueueWriteBuffer(d_src, CL_TRUE, 0, BUF_SIZE, h_send);

  /// Invoke FPGA sort
  f_fpga_sort(cl::EnqueueArgs(cq0, cl::NDRange(1), cl::NDRange(1)), d_dummy,
              d_dst, d_src, (cl_uint)numdata, d_cycle);
  cq0.finish();

  /// Do verification
  fprintf(stderr, "\n");
  fprintf(stderr, "Verification\n");
  fprintf(stderr, "========================\n");

  // Retrieve data to be verified from FPGA
  cq0.enqueueReadBuffer(d_dst, CL_TRUE, 0, BUF_SIZE, h_recv);

  // Prepare correct data
  std::sort(&h_send[0], &h_send[numdata], my_uint2_less());

  // Check data
#pragma omp parallel for
  for (int i = 0; i < (int)numdata; i++) {
    if (h_send[i].s[0] != h_recv[i].s[0]) {
      fprintf(stderr, "Failed!\n");
      fprintf(stderr, "h_send[%d].s[0] = %08x, h_recv[%d].s[0] = %08x\n", i,
              h_send[i].s[0], i, h_recv[i].s[0]);
      exit(EXIT_FAILURE);
    }
  }
  fprintf(stderr, "Passed!\n");

  // Show result
  fprintf(stderr, "------------------------------\n");
  for (int i = 0; i < 10; i++) {
    fprintf(stderr, "h_recv[%d].s[0] = %08x\n", i, h_recv[i].s[0]);
  }
  fprintf(stderr, ".....\n");
  for (int i = (int)(numdata - 10); i < (int)numdata; i++) {
    fprintf(stderr, "h_recv[%d].s[0] = %08x\n", i, h_recv[i].s[0]);
  }
  fprintf(stderr, "------------------------------\n");

  cl_ulong elapsed_cycles;
  cq0.enqueueReadBuffer(d_cycle, CL_TRUE, 0, sizeof(cl_ulong), &elapsed_cycles);
  fprintf(stderr, "elapsed cycles = %lu\n", elapsed_cycles);

  free(h_send);
  free(h_recv);

  return 0;
}
