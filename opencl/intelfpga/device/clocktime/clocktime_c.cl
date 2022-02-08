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

#include "clocktime.h"

struct timespec {
    ulong tv_sec;
    ulong tv_nsec;
};
int clock_gettime(int, struct timespec*);

/* struct clocktime32_t clocktime32(uint x) { */
/*     struct clocktime32_t s; */
/*     struct timespec ts; */
/*     clock_gettime(1, &ts); */

/*     s.p[0] = 0; */
/*     s.t = ts.tv_sec * 1000000000 + ts.tv_nsec; */
/*     s.v = x; */
/*     return s; */
/* } */

struct clocktime64_t clocktime64(ulong x) {
    struct clocktime64_t s;
    struct timespec ts;
    clock_gettime(1, &ts);

    s.t = ts.tv_sec * 1000000000 + ts.tv_nsec;
    s.v = x;
    return s;
}

/* struct clocktime128_t clocktime128(uint4 x) { */
/*     struct clocktime128_t s; */
/*     struct timespec ts; */
/*     clock_gettime(1, &ts); */

/*     s.p[0] = 0; */
/*     s.p[1] = 0; */
/*     s.t = ts.tv_sec * 1000000000 + ts.tv_nsec; */
/*     s.v = x; */
/*     return s; */
/* } */

/* struct clocktime256_t clocktime256(uint8 x) { */
/*     struct clocktime256_t s; */
/*     struct timespec ts; */
/*     clock_gettime(1, &ts); */

/*     s.p[0] = 0; */
/*     s.p[1] = 0; */
/*     s.p[2] = 0; */
/*     s.p[3] = 0; */
/*     s.p[4] = 0; */
/*     s.p[5] = 0; */
/*     s.t = ts.tv_sec * 1000000000 + ts.tv_nsec; */
/*     s.v = x; */
/*     return s; */
/* } */

/* struct clocktime512_t clocktime512(uint16 x) { */
/*     struct clocktime512_t s; */
/*     struct timespec ts; */
/*     clock_gettime(1, &ts); */

/*     s.p[0] = 0; */
/*     s.p[1] = 0; */
/*     s.p[2] = 0; */
/*     s.p[3] = 0; */
/*     s.p[4] = 0; */
/*     s.p[5] = 0; */
/*     s.p[6] = 0; */
/*     s.p[7] = 0; */
/*     s.p[8] = 0; */
/*     s.p[9] = 0; */
/*     s.p[10] = 0; */
/*     s.p[11] = 0; */
/*     s.p[12] = 0; */
/*     s.p[13] = 0; */
/*     s.t = ts.tv_sec * 1000000000 + ts.tv_nsec; */
/*     s.v = x; */
/*     return s; */
/* } */
