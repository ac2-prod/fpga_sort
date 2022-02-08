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

#ifndef CLOCKTIME_H
#define CLOCKTIME_H

// struct clocktime32_t {
//     uint p[1];
//     ulong t;
//     uint v;
// } __attribute__((packed));

struct clocktime64_t {
  ulong t;
  ulong v;
} __attribute__((packed));

// struct clocktime128_t {
//     uint p[2];
//     ulong t;
//     uint4 v;
// } __attribute__((packed));

// struct clocktime256_t {
//     uint p[6];
//     ulong t;
//     uint8 v;
// } __attribute__((packed));

// struct clocktime512_t {
//     uint p[14];
//     ulong t;
//     uint16 v;
// } __attribute__((packed));

// struct clocktime32_t clocktime32(uint x);
struct clocktime64_t clocktime64(ulong x);
// struct clocktime128_t clocktime128(uint4 x);
// struct clocktime256_t clocktime256(uint8 x);
// struct clocktime512_t clocktime512(uint16 x);

#define DEFINE_CLOCKTIME(type, width)                                 \
  static inline __attribute__((always_inline, __overloadable__)) type \
  clocktime(type value, ulong* time) {                                \
    struct clocktime##width##_t s = clocktime##width(value);          \
    *time = s.t;                                                      \
    return s.v;                                                       \
  }

// DEFINE_CLOCKTIME(uint, 32)
DEFINE_CLOCKTIME(ulong, 64)
// DEFINE_CLOCKTIME(uint8, 256)
// DEFINE_CLOCKTIME(uint16, 512)

#undef DEFINE_CLOCKTIME

#endif
