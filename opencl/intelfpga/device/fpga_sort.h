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

#ifndef INCLUDE_GUARD_FPGA_SORT_H
#define INCLUDE_GUARD_FPGA_SORT_H

uint fpga_sort(__global uint2 volatile* restrict dummy, const ulong dst_addr,
               const ulong src_addr, const uint numdata);

#endif  // INCLUDE_GUARD_FPGA_SORT_H
