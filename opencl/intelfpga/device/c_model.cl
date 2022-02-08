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

void heapDown(__global uint2 volatile* restrict sortdata, int datasize, int root) {
  int maxchild;

  while (1) {
    maxchild = root * 2 + 1;
    if (root*2+2 <= datasize) {  // right node exists?
      if (sortdata[root*2+1].s0 < sortdata[root*2+2].s0) {
        maxchild = root * 2 + 2;
      }
    } else if (!(root*2+1 <= datasize)) {
      break; // here is bottom
    }

    if (sortdata[root].s0 < sortdata[maxchild].s0) {
      uint2 temp = sortdata[root];
      sortdata[root] = sortdata[maxchild];
      sortdata[maxchild] = temp;
      root = maxchild;
    } else {
      break; // all values are lower than the root
    }

  }

}

void HeapSort(__global uint2 volatile* restrict sortdata, int datasize) {
  int i;

  datasize--;
  for (i = (datasize>>1); i >= 0; i--) {
    heapDown(sortdata, datasize, i);
  }

  while (1) {
    uint2 temp = sortdata[0];
    sortdata[0] = sortdata[datasize];
    sortdata[datasize] = temp;
    datasize--;
    if (!datasize) break;
    heapDown(sortdata, datasize, 0);
  }

}

uint fpga_sort(
               __global uint2 volatile* restrict dummy,
               const ulong dst_addr,
               const ulong src_addr,
               const uint numdata
               )
{
  HeapSort(dummy, numdata);
  return 0;
}
