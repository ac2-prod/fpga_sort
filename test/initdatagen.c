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

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#define SORTLOG (10)
#define SEED (1872)

typedef unsigned int uint32_t;

uint32_t Xorshift(void) {
  static uint32_t x = 123456789;
  static uint32_t y = 362436069;
  static uint32_t z = 521288629;
  static uint32_t w = 88675123 ^ SEED;
  uint32_t t = x ^ (x << 11);

  x = y;
  y = z;
  z = w;
  return w = (w ^ (w >> 19)) ^ (t ^ (t >> 8));
}

void FisherYatesShuffle(uint32_t arr[], int numdata) {
  int i;
  for (i = numdata; i > 1; i--) {
    int end_idx = i - 1;
    int target_idx = Xorshift() % i;
    uint32_t temp = arr[end_idx];
    arr[end_idx] = arr[target_idx];
    arr[target_idx] = temp;
  }
}

int main(void) {
  const int numdata = (1 << SORTLOG);
  uint32_t *data = (uint32_t *)malloc(sizeof(uint32_t) * numdata);
  int i;
  FILE *fp = fopen("./answer.hex", "w");
  assert((fp != NULL));
  for (i = 0; i < numdata; i++) {
    data[i] = i + 1;
    fprintf(fp, "%08x\n", data[i]);
  }
  fclose(fp);

  FisherYatesShuffle(data, numdata);

  fp = fopen("./initdata.hex", "w");
  assert((fp != NULL));
  for (i = 0; i < numdata; i++) {
    fprintf(fp, "%08x\n", data[i]);
  }
  fclose(fp);

  free(data);

  return EXIT_SUCCESS;
}
