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

`include "hms.v"
`include "fifo.v"
`include "utils.v"

`define E_LOG            (5)  // 1 ~ 5
`define USE_IPCORE ("INTEL")
`define FLOAT         ("no")
`define SIGNED        ("no")
`define PAYW            (32)
`define KEYW            (32)

`define DATW   (`PAYW+`KEYW)

module tb_MERGE_TREE();
  reg CLK; initial begin CLK=0; forever #50 CLK=~CLK; end
  reg RST; initial begin RST=1; #400 RST=0; end
  reg rst; always @(posedge CLK) rst <= RST;  // To synchronize with the rst of merge_node

  wire [(`DATW<<`E_LOG)-1:0] merge_tree_din;
  wire [(1<<`E_LOG)-1:0]     merge_tree_dinen;
  wire [(1<<`E_LOG)-1:0]     merge_tree_ful;
  wire [(`DATW<<`E_LOG)-1:0] merge_tree_dot;
  wire                       merge_tree_doten;

  wire [(`DATW<<`E_LOG)-1:0] check_records;

  reg [(1<<`E_LOG)-1:0] stall;
  always @(posedge CLK) stall <= merge_tree_ful;

  assign merge_tree_dinen = ~stall;  // must be sync with COUPLER and MERGE_LOGIC

  genvar i;
  generate
    for (i=0; i<(1<<`E_LOG); i=i+1) begin: loop
      wire [`KEYW-1:0] init_key     = (1<<`E_LOG) - i;
      wire [`KEYW-1:0] chk_rslt_key = i + 1;
      reg  [`DATW-1:0] init_record;
      reg  [`DATW-1:0] chk_rslt;
      if (`PAYW == 0) begin
        always @(posedge CLK) begin
          if      (rst)                 init_record <= init_key;
          else if (merge_tree_dinen[i]) init_record <= init_record + (1<<`E_LOG);
        end
        always @(posedge CLK) begin
          if      (rst)              chk_rslt <= chk_rslt_key;
          else if (merge_tree_doten) chk_rslt <= chk_rslt + (1<<`E_LOG);
        end
      end else begin
        wire [`PAYW-1:0] init_data_payload = i + 1;
        wire [`PAYW-1:0] chk_rslt_payload  = (1<<`E_LOG) - i;
        always @(posedge CLK) begin
          if      (rst)                 init_record <= {init_data_payload, init_key};
          else if (merge_tree_dinen[i]) init_record <= init_record + (1<<`E_LOG);
        end
        always @(posedge CLK) begin
          if      (rst)              chk_rslt <= {chk_rslt_payload, chk_rslt_key};
          else if (merge_tree_doten) chk_rslt <= chk_rslt + (1<<`E_LOG);
        end
      end
      assign merge_tree_din[`DATW*(i+1)-1:`DATW*i] = init_record;
      assign check_records[`DATW*(i+1)-1:`DATW*i]  = chk_rslt;
    end
  endgenerate

  MERGE_TREE #(`E_LOG, `USE_IPCORE, `FLOAT, `SIGNED, `DATW, `KEYW)
  merge_tree(CLK, RST, 1'b0, merge_tree_din, merge_tree_dinen,
             merge_tree_ful, merge_tree_dot, merge_tree_doten);

  // show result
  always @(posedge CLK) begin
    if (merge_tree_doten) begin
      case (`E_LOG)
        1: $write("%d %d ", merge_tree_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree_dot[(`KEYW+`DATW*1)-1:`DATW*1]);
        2: $write("%d %d %d %d ", merge_tree_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree_dot[(`KEYW+`DATW*1)-1:`DATW*1], merge_tree_dot[(`KEYW+`DATW*2)-1:`DATW*2], merge_tree_dot[(`KEYW+`DATW*3)-1:`DATW*3]);
        3: $write("%d %d %d %d %d %d %d %d ", merge_tree_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree_dot[(`KEYW+`DATW*1)-1:`DATW*1], merge_tree_dot[(`KEYW+`DATW*2)-1:`DATW*2], merge_tree_dot[(`KEYW+`DATW*3)-1:`DATW*3], merge_tree_dot[(`KEYW+`DATW*4)-1:`DATW*4], merge_tree_dot[(`KEYW+`DATW*5)-1:`DATW*5], merge_tree_dot[(`KEYW+`DATW*6)-1:`DATW*6], merge_tree_dot[(`KEYW+`DATW*7)-1:`DATW*7]);
        4: $write("%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d ", merge_tree_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree_dot[(`KEYW+`DATW*1)-1:`DATW*1], merge_tree_dot[(`KEYW+`DATW*2)-1:`DATW*2], merge_tree_dot[(`KEYW+`DATW*3)-1:`DATW*3], merge_tree_dot[(`KEYW+`DATW*4)-1:`DATW*4], merge_tree_dot[(`KEYW+`DATW*5)-1:`DATW*5], merge_tree_dot[(`KEYW+`DATW*6)-1:`DATW*6], merge_tree_dot[(`KEYW+`DATW*7)-1:`DATW*7], merge_tree_dot[(`KEYW+`DATW*8)-1:`DATW*8], merge_tree_dot[(`KEYW+`DATW*9)-1:`DATW*9], merge_tree_dot[(`KEYW+`DATW*10)-1:`DATW*10], merge_tree_dot[(`KEYW+`DATW*11)-1:`DATW*11], merge_tree_dot[(`KEYW+`DATW*12)-1:`DATW*12], merge_tree_dot[(`KEYW+`DATW*13)-1:`DATW*13], merge_tree_dot[(`KEYW+`DATW*14)-1:`DATW*14], merge_tree_dot[(`KEYW+`DATW*15)-1:`DATW*15]);
        5: $write("%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d ", merge_tree_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree_dot[(`KEYW+`DATW*1)-1:`DATW*1], merge_tree_dot[(`KEYW+`DATW*2)-1:`DATW*2], merge_tree_dot[(`KEYW+`DATW*3)-1:`DATW*3], merge_tree_dot[(`KEYW+`DATW*4)-1:`DATW*4], merge_tree_dot[(`KEYW+`DATW*5)-1:`DATW*5], merge_tree_dot[(`KEYW+`DATW*6)-1:`DATW*6], merge_tree_dot[(`KEYW+`DATW*7)-1:`DATW*7], merge_tree_dot[(`KEYW+`DATW*8)-1:`DATW*8], merge_tree_dot[(`KEYW+`DATW*9)-1:`DATW*9], merge_tree_dot[(`KEYW+`DATW*10)-1:`DATW*10], merge_tree_dot[(`KEYW+`DATW*11)-1:`DATW*11], merge_tree_dot[(`KEYW+`DATW*12)-1:`DATW*12], merge_tree_dot[(`KEYW+`DATW*13)-1:`DATW*13], merge_tree_dot[(`KEYW+`DATW*14)-1:`DATW*14], merge_tree_dot[(`KEYW+`DATW*15)-1:`DATW*15], merge_tree_dot[(`KEYW+`DATW*16)-1:`DATW*16], merge_tree_dot[(`KEYW+`DATW*17)-1:`DATW*17], merge_tree_dot[(`KEYW+`DATW*18)-1:`DATW*18], merge_tree_dot[(`KEYW+`DATW*19)-1:`DATW*19], merge_tree_dot[(`KEYW+`DATW*20)-1:`DATW*20], merge_tree_dot[(`KEYW+`DATW*21)-1:`DATW*21], merge_tree_dot[(`KEYW+`DATW*22)-1:`DATW*22], merge_tree_dot[(`KEYW+`DATW*23)-1:`DATW*23], merge_tree_dot[(`KEYW+`DATW*24)-1:`DATW*24], merge_tree_dot[(`KEYW+`DATW*25)-1:`DATW*25], merge_tree_dot[(`KEYW+`DATW*26)-1:`DATW*26], merge_tree_dot[(`KEYW+`DATW*27)-1:`DATW*27], merge_tree_dot[(`KEYW+`DATW*28)-1:`DATW*28], merge_tree_dot[(`KEYW+`DATW*29)-1:`DATW*29], merge_tree_dot[(`KEYW+`DATW*30)-1:`DATW*30], merge_tree_dot[(`KEYW+`DATW*31)-1:`DATW*31]);
      endcase
      $write("\n");
      $fflush();
    end
  end

  // always @(posedge CLK) begin
  //   if (!rst) begin
  //     if (merge_tree_dinen[0]) begin
  //       $write("%d ", merge_tree_din[(`KEYW+`DATW*0)-1:`DATW*0]);
  //     end else begin
  //       $write("           ");
  //     end
  //     $write("|");
  //     if (merge_tree_dinen[1]) begin
  //       $write("%d ", merge_tree_din[(`KEYW+`DATW*1)-1:`DATW*1]);
  //     end else begin
  //       $write("           ");
  //     end
  //     $write("||");
  //     if (merge_tree.level[0].nodes[0].merge_node.coupler_A_doten) begin
  //       $write("%d %d ", merge_tree.level[0].nodes[0].merge_node.coupler_A_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree.level[0].nodes[0].merge_node.coupler_A_dot[(`KEYW+`DATW*1)-1:`DATW*1]);
  //     end else begin
  //       $write("                      ");
  //     end
  //     $write("|");
  //     if (merge_tree.level[0].nodes[0].merge_node.coupler_B_doten) begin
  //       $write("%d %d ", merge_tree.level[0].nodes[0].merge_node.coupler_B_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree.level[0].nodes[0].merge_node.coupler_B_dot[(`KEYW+`DATW*1)-1:`DATW*1]);
  //     end else begin
  //       $write("                      ");
  //     end
  //     $write("||");
  //     if (merge_tree.level[0].node_doten[0]) begin
  //       $write("%d %d ", merge_tree.level[0].node_dot[(`KEYW+`DATW*0)-1:`DATW*0], merge_tree.level[0].node_dot[(`KEYW+`DATW*1)-1:`DATW*1]);
  //     end
  //     $write("\n");
  //     $fflush();
  //   end
  // end

  // error checker
  always @(posedge CLK) begin
    if (merge_tree_doten) begin
      if (merge_tree_dot != check_records) begin
        $write("\nError!\n");
        $finish();
      end
    end
  end

  // simulation finish condition
  reg [31:0] cycle;
  always @(posedge CLK) begin
    if (rst) begin
      cycle <= 0;
    end else begin
      cycle <= cycle + 1;
      if (cycle >= 200) $finish();
    end
  end

endmodule

`default_nettype wire
