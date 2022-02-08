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
`timescale 1 ps / 1 ps

`include "even_odd.v"
`include "utils.v"

`define P_LOG          (9)
`define FLOAT       ("no")
`define SIGNED      ("no")
`define PAYW          (32)
`define KEYW          (32)

`define DATW (`PAYW+`KEYW)

module tb_even_odd();

  reg CLK; initial begin CLK=0; forever #50 CLK=~CLK; end
  reg RST; initial begin RST=1; #400 RST=0; end

  wire [(`DATW<<`P_LOG)-1:0] init_data;
  wire [(`DATW<<`P_LOG)-1:0] chk_rslt;

  reg                        finish;

  reg  [(`DATW<<`P_LOG)-1:0] DIN;
  reg                        DINEN;

  wire [(`DATW<<`P_LOG)-1:0] DOT;
  wire                       DOTEN;

  EVEN_ODD #(`P_LOG, `FLOAT, `SIGNED, `DATW, `KEYW) even_odd(CLK, RST, DIN, DINEN, DOT, DOTEN);

  genvar i;
  generate
    for (i=0; i<(1<<`P_LOG); i=i+1) begin: loop
      wire [`KEYW-1:0] init_data_key = (1<<`P_LOG) - i;
      wire [`KEYW-1:0] chk_rslt_key  = i + 1;
      if (`PAYW == 0) begin
        assign init_data[`DATW*(i+1)-1:`DATW*i] = init_data_key;
        assign chk_rslt[`DATW*(i+1)-1:`DATW*i]  = chk_rslt_key;
      end else begin
        wire [`PAYW-1:0] init_data_payload = i + 1;
        wire [`PAYW-1:0] chk_rslt_payload  = (1<<`P_LOG) - i;
        assign init_data[`DATW*(i+1)-1:`DATW*i] = {init_data_payload, init_data_key};
        assign chk_rslt[`DATW*(i+1)-1:`DATW*i]  = {chk_rslt_payload, chk_rslt_key};
      end
      always @(posedge CLK) if (DOTEN) $write("%d ", DOT[(`KEYW+`DATW*i)-1:`DATW*i]);
    end
  endgenerate

  always @(posedge CLK) begin
    if (RST) begin
      DIN    <= init_data;
      DINEN  <= 1;
      finish <= 0;
    end else begin
      DINEN  <= 0;
      finish <= DOTEN;
      if (DOTEN && (chk_rslt != DOT)) $write("ERROR!!\n");
      if (finish) begin
        $write("\n");
        $finish();
      end
    end
  end

endmodule

`default_nettype wire
