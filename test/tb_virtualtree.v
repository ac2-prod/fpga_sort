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

`include "virtualtree.v"
`include "fifo.v"
`include "utils.v"
`include "hms.v"

`define W_LOG             (4)
`define P_LOG             (4)
`define E_LOG             (2)
`define USE_IPCORE  ("INTEL")
`define FLOAT          ("no")
`define SIGNED         ("no")
`define PAYW             (32)
`define KEYW             (32)
`define NUMW             (32)

`define DATW    (`PAYW+`KEYW)

module tb_vMERGE_SORTER_TREE();

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value >> 1;
    end
  endfunction

  reg CLK; initial begin CLK=0; forever #50 CLK=~CLK; end
  reg RST; initial begin RST=1; #400 RST=0; end

  wire [(`DATW<<`P_LOG)-1:0] vtree_din;
  wire                       vtree_dinen;
  reg  [`W_LOG-1         :0] vtree_din_idx;
  wire [`DATW-1          :0] vtree_dot;
  wire                       vtree_doten;
  wire [(1<<`W_LOG)-1    :0] vtree_emp;

  reg  [(`W_LOG+`P_LOG)-1:0] vtree_dot_cnt;

  reg                        init_done;

  reg [31:0]                 cycle;

  wire [`KEYW-1:0]           check_init_key = 1;
  reg  [`DATW-1:0]           check_record;


  assign vtree_dinen = ~|{RST, init_done};

  always @(posedge CLK) begin
    if      (RST)            init_done <= 0;
    else if (&vtree_din_idx) init_done <= 1;
  end

  genvar i;
  generate
    for (i=0; i<(1<<`P_LOG); i=i+1) begin: loop
      wire [`KEYW-1:0] init_key = 1 + (i<<`W_LOG);
      reg  [`DATW-1:0] init_record;
      always @(posedge CLK) begin
        if      (RST)         init_record <= {{`PAYW{1'b1}}, init_key};
        else if (vtree_dinen) init_record <= init_record + 1;
      end
      assign vtree_din[`DATW*(i+1)-1:`DATW*i] = init_record;
    end
  endgenerate

  always @(posedge CLK) begin
    if      (RST)         vtree_din_idx <= 0;
    else if (vtree_dinen) vtree_din_idx <= vtree_din_idx + 1;
  end

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
                       clog2(`NUMW)
                       )
  vmerge_sorter_tree(
                     CLK,
                     RST,
                     RST,   // SPECIAL_RST
                     1'b0,  // FINAL_PASS
                     1'b0,  // BYPASS
                     0,     // MUL_PASSNUM_ALLWAYLOG
                     0,     // WAYLOG_PER_PORTION
                     0,     // ECNT_BYPASS
                     1'b0,  // IN_FULL
                     vtree_din,
                     vtree_dinen,
                     vtree_din_idx,
                     vtree_dot,
                     vtree_doten,
                     vtree_emp
                     );

  // show result
  always @(posedge CLK) begin
    if (!RST) begin
      $write("%d", cycle);
      ////////////// TREE_FILLER
      $write(" || ");
      if (vtree_dinen) $write("%d", vtree_din[`KEYW-1:0]);
      else             $write("          ");
      $write(" | ");
      $write("%b (%d) %b", vtree_emp, vmerge_sorter_tree.tree_filler.state, vmerge_sorter_tree.tree_filler.queue_ful);
      ////////////// The bottom of SORTER_STAGE_TREE
      $write(" || ");
      if (vmerge_sorter_tree.sst_dinen) $write("%d", vmerge_sorter_tree.sst_din[`KEYW-1:0]);
      else                              $write("          ");
      $write(" | ");
      $write("%b %b (%d %d) %b",
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-1].body.sorter_stage_body.ram_layer.odd_emp,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-1].body.sorter_stage_body.ram_layer.even_emp,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-1].body.sorter_stage_body.ram_layer.req_deq_st,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-1].body.sorter_stage_body.ram_layer.req_gen_st,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-1].body.sorter_stage_body.queue_ful);
      ////////////// level 2 of SORTER_STAGE_TREE
      $write(" || ");
      if (vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].dinen)
        $write("%d", vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].din[`KEYW-1:0]);
      else
        $write("          ");
      $write(" | ");
      $write("%b %b (%d %d) %b",
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].body.sorter_stage_body.ram_layer.odd_emp,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].body.sorter_stage_body.ram_layer.even_emp,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].body.sorter_stage_body.ram_layer.req_deq_st,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].body.sorter_stage_body.ram_layer.req_gen_st,
             vmerge_sorter_tree.sorter_stage_tree.stage[`W_LOG-2].body.sorter_stage_body.queue_ful);
      ////////////// SORTER_STAGE_ROOT
      $write(" || ");
      if (vmerge_sorter_tree.sorter_stage_tree.stage[0].dinen)
        $write("%d", vmerge_sorter_tree.sorter_stage_tree.stage[0].din[`KEYW-1:0]);
      else
        $write("          ");
      $write(" | ");
      $write("%b%b (%d) %b %d",
             vmerge_sorter_tree.sorter_stage_tree.stage[0].root.sorter_stage_root.fifo_1_emp,
             vmerge_sorter_tree.sorter_stage_tree.stage[0].root.sorter_stage_root.fifo_0_emp,
             vmerge_sorter_tree.sorter_stage_tree.stage[0].root.sorter_stage_root.state,
             vmerge_sorter_tree.sorter_stage_tree.stage[0].root.sorter_stage_root.tmp_ful,
             vmerge_sorter_tree.sorter_stage_tree.stage[0].root.sorter_stage_root.obuf_cnt);
      ////////////// Output of vMERGE_SORTER_TREE
      $write(" || ");
      if (vtree_doten) $write("%d", vtree_dot[`KEYW-1:0]);
      else             $write("          ");
      $write("\n");
      $fflush();
    end
  end

  // error checker
  always @(posedge CLK) begin
    if (RST) begin
      check_record <= {{`PAYW{1'b1}}, check_init_key};
    end else begin
      if (vtree_doten) begin
        check_record <= check_record + 1;
        if (vtree_dot != check_record) begin
          $write("\nError!\n");
          $write("%d %d\n", vtree_dot[`KEYW-1:0], check_record[`KEYW-1:0]);
          $finish();
        end
      end
    end
  end

  // simulation finish condition
  always @(posedge CLK) begin
    if (RST) begin
      cycle <= 0;
      vtree_dot_cnt <= 0;
    end else begin
      cycle <= cycle + 1;
      // if (cycle >= 250) $finish();
      if (vtree_doten) begin
        vtree_dot_cnt <= vtree_dot_cnt + 1;
        if (vtree_dot_cnt == (1<<(`W_LOG+`P_LOG))-1) begin
          $finish();
        end
      end
    end
  end

endmodule

`default_nettype wire
