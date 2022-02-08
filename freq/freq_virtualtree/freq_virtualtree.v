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

`define W_LOG             (3)
`define P_LOG             (4)
`define E_LOG             (2)
`define USE_IPCORE  ("INTEL")
`define FLOAT          ("no")
`define SIGNED         ("no")
`define PAYW             (32)
`define KEYW             (32)
`define NUMW             (32)
`define LOGW              (5)

`define DATW    (`PAYW+`KEYW)

module freq_virtualtree(input  wire                       CLK,
                        input  wire                       RST,
                        input  wire                       SPECIAL_RST,
                        input  wire                       FINAL_PASS,
                        input  wire                       BYPASS,
                        input  wire [`LOGW-1:0]           MUL_PASSNUM_ALLWAYLOG,
                        input  wire [`LOGW-1:0]           WAYLOG_PER_PORTION,
                        input  wire [(`NUMW-(`E_LOG+`P_LOG))-1:0] ECNT_BYPASS,
                        input  wire                       IN_FULL,
                        input  wire [(`DATW<<`P_LOG)-1:0] DIN,
                        input  wire                       DINEN,
                        input  wire [`W_LOG-1         :0] DIN_IDX,
                        output wire [`DATW-1          :0] DOT,
                        output wire                       DOTEN,
                        output wire [(1<<`W_LOG)-1   : 0] EMP);

  vMERGE_SORTER_TREE #(
                       `W_LOG,
                       `P_LOG,
                       `E_LOG,
                       `USE_IPCORE,
                       `FLOAT,
                       `SIGNED,
                       `DATW,
                       `KEYW,
                       `NUMW,
                       `LOGW
                       )
  vmerge_sorter_tree(
                     CLK,
                     RST,
                     SPECIAL_RST,
                     FINAL_PASS,
                     BYPASS,
                     MUL_PASSNUM_ALLWAYLOG,
                     WAYLOG_PER_PORTION,
                     ECNT_BYPASS,
                     IN_FULL,
                     DIN,
                     DINEN,
                     DIN_IDX,
                     DOT,
                     DOTEN,
                     EMP
                     );

endmodule

`default_nettype wire
