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

/***** A core module                                                      *****/
/******************************************************************************/
module HYBRID_SORTER #(parameter                                W_LOG      = 2,
                       parameter                                P_LOG      = 3,
                       parameter                                E_LOG      = 2,
                       parameter                                M_LOG      = 1,
                       parameter                                USE_IPCORE = "INTEL",
                       parameter                                FLOAT      = "no",
                       parameter                                SIGNED     = "no",
                       parameter                                DATW       = 64,
                       parameter                                KEYW       = 32,
                       parameter                                NUMW       = 32,
                       parameter                                LOGW       = 5)
                      (input  wire                              CLK,
                       input  wire                              RST,
                       input  wire                              SPECIAL_RST,
                       input  wire                              PASS_DONE,
                       input  wire                              FINAL_PASS,
                       input  wire                              BYPASS,
                       input  wire [LOGW-1                  :0] MUL_PASSNUM_ALLWAYLOG,
                       input  wire [LOGW-1                  :0] WAYLOG_PER_PORTION,
                       input  wire [(NUMW-(E_LOG+P_LOG))-1  :0] ECNT_BYPASS_PER_VTREE,
                       input  wire                              USE_STNET,
                       input  wire                              IN_FULL,
                       input  wire [((DATW<<P_LOG)<<M_LOG)-1:0] DIN,
                       input  wire [(1<<M_LOG)-1            :0] DINEN,
                       input  wire [((E_LOG+W_LOG)<<M_LOG)-1:0] DIN_IDX,
                       output wire [(DATW<<E_LOG)-1         :0] DOT,
                       output wire                              DOTEN,
                       output wire [(1<<(E_LOG+W_LOG))-1    :0] EMP,
                       output wire [(1<<E_LOG)-1            :0] BUFED);

  // Input
  //////////////////////////////////////////////////////////////////////////////
  reg [((DATW<<P_LOG)<<M_LOG)-1:0] din;     always @(posedge CLK) din     <= DIN;
  reg [(1<<M_LOG)-1            :0] dinen;   always @(posedge CLK) dinen   <= (RST) ? 0 : DINEN;
  reg [((E_LOG+W_LOG)<<M_LOG)-1:0] din_idx; always @(posedge CLK) din_idx <= DIN_IDX;


  // Core
  //////////////////////////////////////////////////////////////////////////////
  wire [(DATW<<P_LOG)-1:0]      even_odd_din;
  wire                          even_odd_dinen;
  reg  [(E_LOG+W_LOG)-1:0]      even_odd_din_idx;
  wire [(DATW<<P_LOG)-1:0]      even_odd_dot;
  wire                          even_odd_doten;
  reg  [(E_LOG+W_LOG)-1:0]      pidx [(P_LOG*(P_LOG+1))-1:0];  // pipeline regester for even_odd_din_idx

  wire [(1<<(E_LOG+W_LOG))-1:0] empty_list;
  wire [(1<<E_LOG)-1:0]         buffered_list;

  wire                          merge_tree_in_ful;
  wire [(DATW<<E_LOG)-1:0]      merge_tree_din;
  wire [(1<<E_LOG)-1:0]         merge_tree_dinen;
  wire [(1<<E_LOG)-1:0]         merge_tree_ful;
  wire [(DATW<<E_LOG)-1:0]      merge_tree_dot;
  wire                          merge_tree_doten;

  // A bootstrap sorter
  //////////////////////////////////////////////////////////
  assign even_odd_din   = din[((DATW<<P_LOG)*1)-1:((DATW<<P_LOG)*0)];
  assign even_odd_dinen = dinen[0];

  EVEN_ODD #(P_LOG, FLOAT, SIGNED, DATW, KEYW)
  even_odd(CLK, RST, even_odd_din, even_odd_dinen, even_odd_dot, even_odd_doten);

  always @(posedge CLK) even_odd_din_idx <= din_idx[((E_LOG+W_LOG)*1)-1:((E_LOG+W_LOG)*0)];

  integer p;
  always @(posedge CLK) begin
    pidx[0] <= even_odd_din_idx;
    for (p=1; p<(P_LOG*(P_LOG+1)); p=p+1) pidx[p] <= pidx[p-1];
  end

  // A cluster of input buffers and virtual merge sorter trees
  //////////////////////////////////////////////////////////
  // Input registers
  reg                     muxed_dinen;
  reg [(E_LOG+W_LOG)-1:0] muxed_din_idx;
  reg [(DATW<<P_LOG)-1:0] muxed_din;
  always @(posedge CLK) begin
    if (RST) muxed_dinen <= 0;
    else     muxed_dinen <= (USE_STNET) ? even_odd_doten : dinen[0];
  end
  always @(posedge CLK) begin
    muxed_din_idx <= (USE_STNET) ? pidx[(P_LOG*(P_LOG+1))-1] : din_idx[((E_LOG+W_LOG)*1)-1:((E_LOG+W_LOG)*0)];
    muxed_din     <= (USE_STNET) ? even_odd_dot : din[((DATW<<P_LOG)*1)-1:((DATW<<P_LOG)*0)];
  end

  genvar i;
  generate
    for (i=0; i<(1<<E_LOG); i=i+1) begin: port
      // A virtual merge sorter tree
      ////////////////////////////
      wire                     vmerge_sorter_tree_in_ful;
      reg  [(DATW<<P_LOG)-1:0] vmerge_sorter_tree_din;
      reg                      vmerge_sorter_tree_dinen;
      reg  [W_LOG-1        :0] vmerge_sorter_tree_din_idx;
      wire [DATW-1:0]          vmerge_sorter_tree_dot;
      wire                     vmerge_sorter_tree_doten;
      wire [(1<<W_LOG)-1:0]    vmerge_sorter_tree_emp;

      assign vmerge_sorter_tree_in_ful  = merge_tree_ful[i];

      if (i < (1<<(E_LOG-M_LOG))) begin
        always @(posedge CLK) vmerge_sorter_tree_din     <= muxed_din;
        always @(posedge CLK) vmerge_sorter_tree_dinen   <= (RST) ? 0 : &{muxed_dinen, (muxed_din_idx[(E_LOG+W_LOG)-1:W_LOG] == i)};
        always @(posedge CLK) vmerge_sorter_tree_din_idx <= muxed_din_idx[W_LOG-1:0];
      end else begin
        always @(posedge CLK) vmerge_sorter_tree_din     <= (USE_STNET) ? muxed_din : din[((DATW<<P_LOG)*((i/(1<<(E_LOG-M_LOG)))+1))-1:((DATW<<P_LOG)*(i/(1<<(E_LOG-M_LOG))))];
        always @(posedge CLK) begin
          if (RST) vmerge_sorter_tree_dinen <= 0;
          else     vmerge_sorter_tree_dinen <= (USE_STNET) ? &{muxed_dinen, (muxed_din_idx[(E_LOG+W_LOG)-1:W_LOG] == i)} : &{dinen[(i/(1<<(E_LOG-M_LOG)))], (din_idx[((E_LOG+W_LOG)+((E_LOG+W_LOG)*(i/(1<<(E_LOG-M_LOG)))))-1:(W_LOG+((E_LOG+W_LOG)*(i/(1<<(E_LOG-M_LOG)))))] == i)};
        end
        always @(posedge CLK) vmerge_sorter_tree_din_idx <= (USE_STNET) ? muxed_din_idx[W_LOG-1:0] : din_idx[(W_LOG+((E_LOG+W_LOG)*(i/(1<<(E_LOG-M_LOG)))))-1:((E_LOG+W_LOG)*(i/(1<<(E_LOG-M_LOG))))];
      end

      vMERGE_SORTER_TREE #(W_LOG, P_LOG, E_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW, NUMW, LOGW)
      vmerge_sorter_tree(CLK, RST, SPECIAL_RST, FINAL_PASS, BYPASS, MUL_PASSNUM_ALLWAYLOG, WAYLOG_PER_PORTION, ECNT_BYPASS_PER_VTREE, vmerge_sorter_tree_in_ful, vmerge_sorter_tree_din, vmerge_sorter_tree_dinen, vmerge_sorter_tree_din_idx,
                         vmerge_sorter_tree_dot, vmerge_sorter_tree_doten, vmerge_sorter_tree_emp);

      assign merge_tree_din[DATW*(i+1)-1:DATW*i]         = vmerge_sorter_tree_dot;
      assign merge_tree_dinen[i]                         = vmerge_sorter_tree_doten;
      assign empty_list[(1<<W_LOG)*(i+1)-1:(1<<W_LOG)*i] = vmerge_sorter_tree_emp;
      assign buffered_list[i]                            = vmerge_sorter_tree_dinen;
    end
  endgenerate

  // A high bandwidth merge sorter tree
  //////////////////////////////////////////////////////////
  assign merge_tree_in_ful = IN_FULL;

  MERGE_TREE #(E_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
  merge_tree(CLK, SPECIAL_RST, merge_tree_in_ful, merge_tree_din, merge_tree_dinen,
             merge_tree_ful, merge_tree_dot, merge_tree_doten);


  // Output
  //////////////////////////////////////////////////////////////////////////////
  assign DOT   = merge_tree_dot;
  assign DOTEN = merge_tree_doten;
  assign EMP   = empty_list;
  assign BUFED = buffered_list;

endmodule

`default_nettype wire
