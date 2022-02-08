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

`define W_LOG                  (3)
`define P_LOG                  (4)
`define E_LOG                  (2)
`define USE_IPCORE       ("INTEL")
`define PAYW                  (32)
`define KEYW                  (32)

`define DATW         (`PAYW+`KEYW)
`define C_LOG      (`E_LOG+`W_LOG)
`define FIFO_WIDTH (`DATW<<`P_LOG)

module freq_input_buffer(
                         input  wire                   CLK,
                         input  wire                   RST,
                         input  wire                   enq,
                         input  wire [`C_LOG-1:0]      enq_idx,
                         input  wire                   deq,
                         input  wire [`C_LOG-1:0]      deq_idx,
                         input  wire [`FIFO_WIDTH-1:0] din,
                         output wire [`FIFO_WIDTH-1:0] dot,
                         output wire [(1<<`C_LOG)-1:0] emp,
                         output wire [(1<<`C_LOG)-1:0] rdy
                         );

  MULTI_CHANNEL_TWOENTRY_FIFO #(
                                (`E_LOG+`W_LOG),
                                (`DATW<<`P_LOG),
                                `USE_IPCORE
                                )
  input_buffer(
               CLK,
               RST,
               enq,
               enq_idx,
               deq,
               deq_idx,
               din,
               dot,
               emp,
               rdy
               );

endmodule

`default_nettype wire
