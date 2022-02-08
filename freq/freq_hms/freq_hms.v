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

`default_nettype none

`define E_LOG            (2)
`define USE_IPCORE ("INTEL")
`define FLOAT         ("no")
`define SIGNED        ("no")
`define PAYW            (32)
`define KEYW            (32)

`define DATW   (`PAYW+`KEYW)

module freq_hms(input  wire                       CLK,
                input  wire                       RST,
                input  wire                       IN_FULL,
                input  wire [(`DATW<<`E_LOG)-1:0] DIN,
                input  wire [(1<<`E_LOG)-1:0]     DINEN,
                output wire [(1<<`E_LOG)-1:0]     FULL,
                output wire [(`DATW<<`E_LOG)-1:0] DOT,
                output wire                       DOTEN);

  MERGE_TREE #(
               `E_LOG,
               `USE_IPCORE,
               `FLOAT,
               `SIGNED,
               `DATW,
               `KEYW
               )
  merge_tree(
             CLK,
             RST,
             IN_FULL,
             DIN,
             DINEN,
             FULL,
             DOT,
             DOTEN
             );

endmodule

`default_nettype wire
