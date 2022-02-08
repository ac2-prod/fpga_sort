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

#include <clocktime.h>
#include <fpga_sort.h>

#define SEED (1872)

uint Xorshift(uint *x, uint *y, uint *z, uint *w) {
  const uint t = *x ^ (*x << 11);
  *x = *y; *y = *z; *z = *w;
  return *w = (*w ^ (*w >> 19)) ^ (t ^ (t >> 8));
}

uint FisherYatesShuffle(__global uint2 volatile* restrict arr,
                        const int numdata) {
  uint x = 123456789;
  uint y = 362436069;
  uint z = 521288629;
  uint w = 88675123 ^ SEED;
  uint n = 1;
  for (int i = numdata; i > 1; i--) {
    const int end_idx = i - 1;
    const int target_idx = Xorshift(&x, &y, &z, &w) % i;
    const uint2 temp = arr[end_idx];
    arr[end_idx] = arr[target_idx];
    arr[target_idx] = temp;
    n++;
  }
  return n;
}

__kernel void tb_fpga_sort(
                           __global uint2 volatile* restrict dummy,
                           __global uint2 volatile* restrict dst,
                           __global uint2 volatile* restrict src,
                           const uint numdata,
                           __global ulong *restrict cycle)
{
  // data initialized
  const uint count = FisherYatesShuffle(src, numdata);

  // Retrieve src and dst addresses
  const ulong dst_addr = (ulong)dst;
  const ulong src_addr = (ulong)src;

  ulong t0 = 0;
  ulong t1 = 0;

  // Do sort
  const uint n = (uint)clocktime((ulong)count, &t0);
#ifdef USE_EMULATOR
  const uint ret = fpga_sort(src, dst_addr, src_addr, n);
#else
  const uint ret = fpga_sort(dummy, dst_addr, src_addr, n);
#endif
  const bool in_src = (clocktime((ulong)ret, &t1) == 0);

  // copy sorted data to dst[] if it is stored in src[]
  if (in_src) {
    for (uint i = 0; i < numdata; i++) {
      dst[i] = src[i];
    }
  }

  *cycle = t1 - t0;
}
