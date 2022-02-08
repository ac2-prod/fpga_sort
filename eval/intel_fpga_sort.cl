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

#include <fpga_sort.h>

__kernel void intel_fpga_sort(
                              __global uint2 volatile* restrict dummy,
                              __global uint2 volatile* restrict dst,
                              __global uint2 volatile* restrict src,
                              const uint numdata,
                              __global ulong *restrict ret)
{
  // Retrieve src and dst addresses
  const ulong dst_addr = (ulong)dst;
  const ulong src_addr = (ulong)src;
  // Do sort
#ifdef USE_EMULATOR
  *ret = (ulong)fpga_sort(src, dst_addr, src_addr, numdata);
#else
  *ret = (ulong)fpga_sort(dummy, dst_addr, src_addr, numdata);
#endif
}
