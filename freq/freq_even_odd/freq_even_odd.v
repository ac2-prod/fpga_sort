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

`define P_LOG              (4)
`define FLOAT           ("no")
`define SIGNED          ("no")
`define PAYW              (32)
`define KEYW              (32)

`define DATW     (`PAYW+`KEYW)

module freq_even_odd(input  wire                       CLK,
                     input  wire                       RST,
                     input  wire [(`DATW<<`P_LOG)-1:0] DIN,
                     input  wire                       DINEN,
                     output wire [(`DATW<<`P_LOG)-1:0] DOT,
                     output wire                       DOTEN);

  EVEN_ODD #(
             `P_LOG,
             `FLOAT,
             `SIGNED,
             `DATW,
             `KEYW
             )
  even_odd(
           CLK,
           RST,
           DIN,
           DINEN,
           DOT,
           DOTEN
           );

endmodule

`default_nettype wire
