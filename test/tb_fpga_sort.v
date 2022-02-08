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

`include "avalon_mmcon.v"
`include "even_odd.v"
`include "fifo.v"
`include "fpga_sort.v"
`include "hms.v"
`include "hybrid_sorter.v"
`include "read_request_con.v"
`include "utils.v"
`include "virtualtree.v"

/* memory access parameters */
`define MAXBURST_LOG      (4)
`define WRITENUM_SIZE     (5)
`define DRAM_ADDRSPACE   (64)
`define DRAM_DATAWIDTH  (512)

/* parameters for hybrid sorter's configuration */
`define W_LOG             (3)
`define P_LOG             (4)
`define E_LOG             (3)
`define M_LOG             (3)
`define USE_IPCORE  ("INTEL")
`define FLOAT          ("no")
`define SIGNED         ("no")
`define PAYW             (32)
`define KEYW             (32)
`define NUMW             (32)

/* RTL simulation parameter */
`define SORTLOG          (10)
`define INITTYPE   ("random")
`define LATENCY          (50)  // memory access latency cycles

/******************************************************************************/
module tb_fpga_sort();

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value >> 1;
    end
  endfunction

  localparam [63:0] SORTNUM         = (1 << `SORTLOG);
  localparam [63:0] DATW            = `PAYW + `KEYW;
  localparam [63:0] DRAM_SIZE       = ((SORTNUM >> clog2(`DRAM_DATAWIDTH/DATW)) << 1);  // size in 64bytes. <<1 means that this sorter uses twice memory capacity
  localparam [63:0] BANK_0_INITADDR = 0;
  localparam [63:0] BANK_1_INITADDR = ((DRAM_SIZE>>1) * (`DRAM_DATAWIDTH>>3)); // Byte addressing

  /* global clock and low-actived reset */
  reg CLK;   initial begin CLK=0; forever #50 CLK=~CLK; end
  reg RST_X; initial begin RST_X=0; #400 RST_X=1;       end

  /* a signal to show whether the RTL simulation is ready */
  wire                            init_done;

  /* mapped to arguments from cl code */
  wire [ 63:0]                    cl_dummy       = 0;
  wire [ 63:0]                    m_dst_addr     = BANK_1_INITADDR;  // *Y
  wire [ 63:0]                    m_src_addr     = BANK_0_INITADDR;  // *X
  wire [ 31:0]                    m_input_index  = SORTNUM;          // N
  wire [ 31:0]                    m_output_value;                    // *C

  /* Avalon-ST Interface */
  wire                            m_ready_out;
  reg                             m_valid_in;
  wire                            m_valid_out;
  wire                            m_ready_in = 1;

  /* Avalon-MM Interface for read */
  // this part will be automatically generated
  // Region 0
  wire [`DRAM_DATAWIDTH-1     :0] src_0_readdata;      // input
  wire                            src_0_readdatavalid; // input
  wire                            src_0_waitrequest;   // input
  wire [`DRAM_ADDRSPACE-1     :0] src_0_address;
  wire                            src_0_read;
  wire                            src_0_write;         // unused
  wire                            src_0_writeack;      // unused
  wire [`DRAM_DATAWIDTH-1     :0] src_0_writedata;     // unused
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_0_byteenable;
  wire [`MAXBURST_LOG         :0] src_0_burstcount;
  // Region 1
  wire [`DRAM_DATAWIDTH-1     :0] src_1_readdata;
  wire                            src_1_readdatavalid;
  wire                            src_1_waitrequest;
  wire [`DRAM_ADDRSPACE-1     :0] src_1_address;
  wire                            src_1_read;
  wire                            src_1_write;
  wire                            src_1_writeack;
  wire [`DRAM_DATAWIDTH-1     :0] src_1_writedata;
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_1_byteenable;
  wire [`MAXBURST_LOG         :0] src_1_burstcount;
  // Region 2
  wire [`DRAM_DATAWIDTH-1     :0] src_2_readdata;      // input
  wire                            src_2_readdatavalid; // input
  wire                            src_2_waitrequest;   // input
  wire [`DRAM_ADDRSPACE-1     :0] src_2_address;
  wire                            src_2_read;
  wire                            src_2_write;         // unused
  wire                            src_2_writeack;      // unused
  wire [`DRAM_DATAWIDTH-1     :0] src_2_writedata;     // unused
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_2_byteenable;
  wire [`MAXBURST_LOG         :0] src_2_burstcount;
  // Region 3
  wire [`DRAM_DATAWIDTH-1     :0] src_3_readdata;
  wire                            src_3_readdatavalid;
  wire                            src_3_waitrequest;
  wire [`DRAM_ADDRSPACE-1     :0] src_3_address;
  wire                            src_3_read;
  wire                            src_3_write;
  wire                            src_3_writeack;
  wire [`DRAM_DATAWIDTH-1     :0] src_3_writedata;
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_3_byteenable;
  wire [`MAXBURST_LOG         :0] src_3_burstcount;
  // Region 4
  wire [`DRAM_DATAWIDTH-1     :0] src_4_readdata;      // input
  wire                            src_4_readdatavalid; // input
  wire                            src_4_waitrequest;   // input
  wire [`DRAM_ADDRSPACE-1     :0] src_4_address;
  wire                            src_4_read;
  wire                            src_4_write;         // unused
  wire                            src_4_writeack;      // unused
  wire [`DRAM_DATAWIDTH-1     :0] src_4_writedata;     // unused
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_4_byteenable;
  wire [`MAXBURST_LOG         :0] src_4_burstcount;
  // Region 5
  wire [`DRAM_DATAWIDTH-1     :0] src_5_readdata;
  wire                            src_5_readdatavalid;
  wire                            src_5_waitrequest;
  wire [`DRAM_ADDRSPACE-1     :0] src_5_address;
  wire                            src_5_read;
  wire                            src_5_write;
  wire                            src_5_writeack;
  wire [`DRAM_DATAWIDTH-1     :0] src_5_writedata;
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_5_byteenable;
  wire [`MAXBURST_LOG         :0] src_5_burstcount;
  // Region 6
  wire [`DRAM_DATAWIDTH-1     :0] src_6_readdata;      // input
  wire                            src_6_readdatavalid; // input
  wire                            src_6_waitrequest;   // input
  wire [`DRAM_ADDRSPACE-1     :0] src_6_address;
  wire                            src_6_read;
  wire                            src_6_write;         // unused
  wire                            src_6_writeack;      // unused
  wire [`DRAM_DATAWIDTH-1     :0] src_6_writedata;     // unused
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_6_byteenable;
  wire [`MAXBURST_LOG         :0] src_6_burstcount;
  // Region 7
  wire [`DRAM_DATAWIDTH-1     :0] src_7_readdata;
  wire                            src_7_readdatavalid;
  wire                            src_7_waitrequest;
  wire [`DRAM_ADDRSPACE-1     :0] src_7_address;
  wire                            src_7_read;
  wire                            src_7_write;
  wire                            src_7_writeack;
  wire [`DRAM_DATAWIDTH-1     :0] src_7_writedata;
  wire [(`DRAM_DATAWIDTH>>3)-1:0] src_7_byteenable;
  wire [`MAXBURST_LOG         :0] src_7_burstcount;

  /* Avalon-MM Interface for write */
  wire [`DRAM_DATAWIDTH-1     :0] dst_readdata;
  wire                            dst_readdatavalid;
  wire                            dst_waitrequest;
  wire [`DRAM_ADDRSPACE-1     :0] dst_address;
  wire                            dst_read;
  wire                            dst_write;
  wire                            dst_writeack;
  wire [`DRAM_DATAWIDTH-1     :0] dst_writedata;
  wire [(`DRAM_DATAWIDTH>>3)-1:0] dst_byteenable;
  wire [`MAXBURST_LOG         :0] dst_burstcount;

  // DRAM stub module
  //////////////////////////////////////////////////////////
  DRAM #(
         `MAXBURST_LOG,
         `DRAM_ADDRSPACE,
         `DRAM_DATAWIDTH,
         `M_LOG,
         `PAYW,
         `KEYW,
         `SORTLOG,
         `INITTYPE,
         `LATENCY
         )
  dram(
       CLK,
       RST_X,
       init_done,
       /* Avalon-MM Interface for read */
       // this part will be automatically generated
       // Region 0
       src_0_readdata,
       src_0_readdatavalid,
       src_0_waitrequest,
       src_0_address,
       src_0_read,
       src_0_byteenable,
       src_0_burstcount,
       // Region 1
       src_1_readdata,
       src_1_readdatavalid,
       src_1_waitrequest,
       src_1_address,
       src_1_read,
       src_1_byteenable,
       src_1_burstcount,
       // Region 2
       src_2_readdata,
       src_2_readdatavalid,
       src_2_waitrequest,
       src_2_address,
       src_2_read,
       src_2_byteenable,
       src_2_burstcount,
       // Region 3
       src_3_readdata,
       src_3_readdatavalid,
       src_3_waitrequest,
       src_3_address,
       src_3_read,
       src_3_byteenable,
       src_3_burstcount,
       // Region 4
       src_4_readdata,
       src_4_readdatavalid,
       src_4_waitrequest,
       src_4_address,
       src_4_read,
       src_4_byteenable,
       src_4_burstcount,
       // Region 5
       src_5_readdata,
       src_5_readdatavalid,
       src_5_waitrequest,
       src_5_address,
       src_5_read,
       src_5_byteenable,
       src_5_burstcount,
       // Region 6
       src_6_readdata,
       src_6_readdatavalid,
       src_6_waitrequest,
       src_6_address,
       src_6_read,
       src_6_byteenable,
       src_6_burstcount,
       // Region 7
       src_7_readdata,
       src_7_readdatavalid,
       src_7_waitrequest,
       src_7_address,
       src_7_read,
       src_7_byteenable,
       src_7_burstcount,
       /* Avalon-MM Interface for write */
       dst_waitrequest,
       dst_address,
       dst_write,
       dst_writeack,
       dst_writedata,
       dst_byteenable,
       dst_burstcount
       );

  // Core Module Instantiation
  //////////////////////////////////////////////////////////
  fpga_sort #(
              /* memory access parameters */
              `MAXBURST_LOG,
              `WRITENUM_SIZE,
              `DRAM_ADDRSPACE,
              `DRAM_DATAWIDTH,
              /* parameters for hybrid sorter's configuration */
              `W_LOG,
              `P_LOG,
              `E_LOG,
              `M_LOG,
              `USE_IPCORE,
              `FLOAT,
              `SIGNED,
              `PAYW,
              `KEYW,
              `NUMW
              )
         core(
              /* global clock and low-actived reset */
              CLK,
              RST_X,
              /* mapped to arguments from cl code */
              cl_dummy,
              m_dst_addr,
              m_src_addr,
              m_input_index,
              m_output_value,
              /* Avalon-ST Interface */
              m_ready_out,
              m_valid_in,
              m_valid_out,
              m_ready_in,
              /* Avalon-MM Interface for read */
              // this part will be automatically generated
              // Region 0
              src_0_readdata,      // input
              src_0_readdatavalid, // input
              src_0_waitrequest,   // input
              src_0_address,
              src_0_read,
              src_0_write,         // unused
              src_0_writeack,      // unused
              src_0_writedata,     // unused
              src_0_byteenable,
              src_0_burstcount,
              // Region 1
              src_1_readdata,      // input
              src_1_readdatavalid, // input
              src_1_waitrequest,   // input
              src_1_address,
              src_1_read,
              src_1_write,         // unused
              src_1_writeack,      // unused
              src_1_writedata,     // unused
              src_1_byteenable,
              src_1_burstcount,
              // Region 2
              src_2_readdata,      // input
              src_2_readdatavalid, // input
              src_2_waitrequest,   // input
              src_2_address,
              src_2_read,
              src_2_write,         // unused
              src_2_writeack,      // unused
              src_2_writedata,     // unused
              src_2_byteenable,
              src_2_burstcount,
              // Region 3
              src_3_readdata,      // input
              src_3_readdatavalid, // input
              src_3_waitrequest,   // input
              src_3_address,
              src_3_read,
              src_3_write,         // unused
              src_3_writeack,      // unused
              src_3_writedata,     // unused
              src_3_byteenable,
              src_3_burstcount,
              // Region 4
              src_4_readdata,      // input
              src_4_readdatavalid, // input
              src_4_waitrequest,   // input
              src_4_address,
              src_4_read,
              src_4_write,         // unused
              src_4_writeack,      // unused
              src_4_writedata,     // unused
              src_4_byteenable,
              src_4_burstcount,
              // Region 5
              src_5_readdata,      // input
              src_5_readdatavalid, // input
              src_5_waitrequest,   // input
              src_5_address,
              src_5_read,
              src_5_write,         // unused
              src_5_writeack,      // unused
              src_5_writedata,     // unused
              src_5_byteenable,
              src_5_burstcount,
              // Region 6
              src_6_readdata,      // input
              src_6_readdatavalid, // input
              src_6_waitrequest,   // input
              src_6_address,
              src_6_read,
              src_6_write,         // unused
              src_6_writeack,      // unused
              src_6_writedata,     // unused
              src_6_byteenable,
              src_6_burstcount,
              // Region 7
              src_7_readdata,      // input
              src_7_readdatavalid, // input
              src_7_waitrequest,   // input
              src_7_address,
              src_7_read,
              src_7_write,         // unused
              src_7_writeack,      // unused
              src_7_writedata,     // unused
              src_7_byteenable,
              src_7_burstcount,
              /* Avalon-MM Interface for write */
              dst_readdata,      // unused
              dst_readdatavalid, // unused
              dst_waitrequest,   // input
              dst_address,
              dst_read,          // unused
              dst_write,
              dst_writeack,      // input
              dst_writedata,
              dst_byteenable,
              dst_burstcount
              );

  // activate the RTL simulation
  reg started;
  always @(posedge CLK) begin
    if (!RST_X) begin
      m_valid_in <= 0;
      started    <= 0;
    end else begin
      m_valid_in <= (m_ready_out && init_done && !started);
      started    <= (init_done);
    end
  end

  // elapsed cycle
  reg [63:0] cycle; always @(posedge CLK) cycle <= (!started) ? 0 : cycle + 1;

  // Debug Info
  always @(posedge CLK) begin
    if (init_done) begin
      $write(" %b %b %d |", core.rst, core.special_rst, core.state);
      // if (cycle == 5000) $finish();  // step execution
      $write(" %d |", cycle);
      $write(" P%1d(%b) %d |", core.passnum, core.final_pass, core.read_request_con_f.read_requestnum);
      $write(" (%d,%d,%d) |", dram.mem_read[0].read_state, core.mem_read_controllers[0].avalon_mm_read.state, core.read_request_con_f.read_state);
      if (src_0_readdatavalid) $write(" %08x %08x ", src_0_readdata[(`KEYW+DATW*1)-1:DATW*1], src_0_readdata[(`KEYW+DATW*0)-1:DATW*0]); else $write("                   ");
      $write("|");
      if (core.hybrid_sorter_dinen[0]) $write(" %08x %08x(%4d) ", core.hybrid_sorter_din[(`KEYW+DATW*1)-1:DATW*1], core.hybrid_sorter_din[(`KEYW+DATW*0)-1:DATW*0], core.hybrid_sorter_din_idx[((`E_LOG+`W_LOG)*1)-1:(`E_LOG+`W_LOG)*0]);
      else $write("                         ");
      // $write("|");
      // if (core.hybrid_sorter_bufed[3]) $write(" %08x %08x(%4d) ", core.hybrid_sorter.port[3].vmerge_sorter_tree_din[(`KEYW+DATW*1)-1:DATW*1], core.hybrid_sorter.port[3].vmerge_sorter_tree_din[(`KEYW+DATW*0)-1:DATW*0], core.hybrid_sorter.port[3].vmerge_sorter_tree_din_idx);
      // else $write("                         ");
      // if (core.hybrid_sorter_bufed[2]) $write(" %08x %08x(%4d) ", core.hybrid_sorter.port[2].vmerge_sorter_tree_din[(`KEYW+DATW*1)-1:DATW*1], core.hybrid_sorter.port[2].vmerge_sorter_tree_din[(`KEYW+DATW*0)-1:DATW*0], core.hybrid_sorter.port[2].vmerge_sorter_tree_din_idx);
      // else $write("                         ");
      // if (core.hybrid_sorter_bufed[1]) $write(" %08x %08x(%4d) ", core.hybrid_sorter.port[1].vmerge_sorter_tree_din[(`KEYW+DATW*1)-1:DATW*1], core.hybrid_sorter.port[1].vmerge_sorter_tree_din[(`KEYW+DATW*0)-1:DATW*0], core.hybrid_sorter.port[1].vmerge_sorter_tree_din_idx);
      // else $write("                         ");
      // if (core.hybrid_sorter_bufed[0]) $write(" %08x %08x(%4d) ", core.hybrid_sorter.port[0].vmerge_sorter_tree_din[(`KEYW+DATW*1)-1:DATW*1], core.hybrid_sorter.port[0].vmerge_sorter_tree_din[(`KEYW+DATW*0)-1:DATW*0], core.hybrid_sorter.port[0].vmerge_sorter_tree_din_idx);
      // else $write("                         ");

      $write("|");

      $write(" %b ", core.hybrid_sorter_emp);

      $write("|");

      if (core.hybrid_sorter.port[3].vmerge_sorter_tree.tf_doten) $write(" %08x(%4d) ", core.hybrid_sorter.port[3].vmerge_sorter_tree.tf_dot[`KEYW-1:0], core.hybrid_sorter.port[3].vmerge_sorter_tree.tf_dot_idx);
      else $write("                ");
      if (core.hybrid_sorter.port[2].vmerge_sorter_tree.tf_doten) $write(" %08x(%4d) ", core.hybrid_sorter.port[2].vmerge_sorter_tree.tf_dot[`KEYW-1:0], core.hybrid_sorter.port[2].vmerge_sorter_tree.tf_dot_idx);
      else $write("                ");
      if (core.hybrid_sorter.port[1].vmerge_sorter_tree.tf_doten) $write(" %08x(%4d) ", core.hybrid_sorter.port[1].vmerge_sorter_tree.tf_dot[`KEYW-1:0], core.hybrid_sorter.port[1].vmerge_sorter_tree.tf_dot_idx);
      else $write("                ");
      if (core.hybrid_sorter.port[0].vmerge_sorter_tree.tf_doten) $write(" %08x(%4d) ", core.hybrid_sorter.port[0].vmerge_sorter_tree.tf_dot[`KEYW-1:0], core.hybrid_sorter.port[0].vmerge_sorter_tree.tf_dot_idx);
      else $write("                ");

      $write("|");

      $write("|");

      if (`E_LOG >= 3) begin
        if (core.hybrid_sorter.merge_tree_dinen[7]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*7)-1:DATW*7]);
        else $write("          ");
        if (core.hybrid_sorter.merge_tree_dinen[6]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*6)-1:DATW*6]);
        else $write("          ");
        if (core.hybrid_sorter.merge_tree_dinen[5]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*5)-1:DATW*5]);
        else $write("          ");
        if (core.hybrid_sorter.merge_tree_dinen[4]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*4)-1:DATW*4]);
        else $write("          ");
      end
      if (core.hybrid_sorter.merge_tree_dinen[3]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*3)-1:DATW*3]);
      else $write("          ");
      // if (core.hybrid_sorter.merge_tree.level[0].nodes[1].merge_node.coupler_B_doten) $write("%08x ", core.hybrid_sorter.merge_tree.level[0].nodes[1].merge_node.coupler_B_dot[(`KEYW+DATW*0)-1:DATW*0]);
      // else $write("         ");
      if (core.hybrid_sorter.merge_tree_dinen[2]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*2)-1:DATW*2]);
      else $write("          ");
      // if (core.hybrid_sorter.merge_tree.level[0].nodes[1].merge_node.coupler_A_doten) $write("%08x ", core.hybrid_sorter.merge_tree.level[0].nodes[1].merge_node.coupler_A_dot[(`KEYW+DATW*0)-1:DATW*0]);
      // else $write("         ");
      if (core.hybrid_sorter.merge_tree_dinen[1]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*1)-1:DATW*1]);
      else $write("          ");
      // if (core.hybrid_sorter.merge_tree.level[0].nodes[0].merge_node.coupler_B_doten) $write("%08x ", core.hybrid_sorter.merge_tree.level[0].nodes[0].merge_node.coupler_B_dot[(`KEYW+DATW*0)-1:DATW*0]);
      // else $write("         ");
      if (core.hybrid_sorter.merge_tree_dinen[0]) $write(" %08x ", core.hybrid_sorter.merge_tree_din[(`KEYW+DATW*0)-1:DATW*0]);
      else $write("          ");
      // if (core.hybrid_sorter.merge_tree.level[0].nodes[0].merge_node.coupler_A_doten) $write("%08x ", core.hybrid_sorter.merge_tree.level[0].nodes[0].merge_node.coupler_A_dot[(`KEYW+DATW*0)-1:DATW*0]);
      // else $write("         ");

      // $write("|");

      // if (core.hybrid_sorter.merge_tree.level[1].nodes[0].merge_node.coupler_B_doten) $write("%08x ", core.hybrid_sorter.merge_tree.level[1].nodes[0].merge_node.coupler_B_dot[(`KEYW+DATW*0)-1:DATW*0]);
      // else $write("         ");
      // if (core.hybrid_sorter.merge_tree.level[1].nodes[0].merge_node.coupler_A_doten) $write("%08x ", core.hybrid_sorter.merge_tree.level[1].nodes[0].merge_node.coupler_A_dot[(`KEYW+DATW*0)-1:DATW*0]);
      // else $write("         ");

      $write("||");
      if (core.wbuf_dinen) $write(" %08x %08x %08x %08x ", core.wbuf_din[(`KEYW+DATW*3)-1:DATW*3],
                                  core.wbuf_din[(`KEYW+DATW*2)-1:DATW*2], core.wbuf_din[(`KEYW+DATW*1)-1:DATW*1], core.wbuf_din[(`KEYW+DATW*0)-1:DATW*0]);
      else $write("                                     ");

      $write("|");

      if (core.wbuf_deq) $write(" %08x %08x(%4d) ", core.wbuf_dot[(`KEYW+DATW*1)-1:DATW*1], core.wbuf_dot[(`KEYW+DATW*0)-1:DATW*0], dram.write_address[`DRAM_ADDRSPACE-1:clog2(`DRAM_DATAWIDTH>>3)]);
      else $write("                         ");

      $write("%d %d", core.write_buffer.i_buf_cnt, core.write_buffer.o_buf_cnt);
      $write("\n");
      $fflush();
    end
  end

  // error checker
  genvar i;
  generate
    if (`INITTYPE=="sorted" || `INITTYPE=="reverse") begin
      for (i=0; i<(1<<`E_LOG); i=i+1) begin: error_checker
        wire [`KEYW-1:0] check_key = i + 1;
        reg  [DATW-1 :0] check_record;
        always @(posedge CLK) begin
          if (!RST_X) begin
            check_record <= (`PAYW == 0) ? check_key : {{(`PAYW){1'b1}}, check_key};
          end else begin
            if (&{core.final_pass, core.wbuf_dinen}) begin
              check_record <= check_record + (1<<`E_LOG);
              if (core.wbuf_din[DATW*(i+1)-1:DATW*i] != check_record) begin
                $write("\nError!\n");
                $write("%d %d\n", core.wbuf_din[(`KEYW+DATW*i)-1:DATW*i], check_record[`KEYW-1:0]);
                $finish();
              end
            end
          end
        end
      end
    end else if (`INITTYPE=="random") begin
      reg [`KEYW-1:0] check_key_mem [SORTNUM-1:0];
      initial begin
        $readmemh("answer.hex", check_key_mem, 0, SORTNUM-1);
      end
      for (i=0; i<(1<<`E_LOG); i=i+1) begin: error_checker
        reg [`SORTLOG-1:0] check_idx;
        reg [DATW-1    :0] check_record;
        always @(posedge CLK) begin
          if (!RST_X) begin
            check_idx    <= i + (1<<`E_LOG);
            check_record <= (`PAYW == 0) ? check_key_mem[i] : {{(`PAYW){1'b1}}, check_key_mem[i]};
          end else begin
            if (&{core.final_pass, core.wbuf_dinen}) begin
              check_idx    <= check_idx + (1<<`E_LOG);
              check_record <= (`PAYW == 0) ? check_key_mem[check_idx] : {{(`PAYW){1'b1}}, check_key_mem[check_idx]};
              if (core.wbuf_din[DATW*(i+1)-1:DATW*i] != check_record) begin
                $write("\nError!\n");
                $write("%08x %08x\n", core.wbuf_din[(`KEYW+DATW*i)-1:DATW*i], check_record[`KEYW-1:0]);
                $finish();
              end
            end
          end
        end
      end
    end else begin
      always @(posedge CLK) begin
        $write("Error! INITTYPE is wrong.\n");
        $finish();
      end
    end
  endgenerate

  // Show the elapsed cycles
  always @(posedge CLK) begin
    if (m_valid_out) begin : simulation_finish
      $write("Returned value: %d\n", m_output_value);
      $write("--> ");
      if (m_output_value == 1) $write("Sorted sequence in dst_addr\n");
      else                     $write("Sorted sequence in src_addr\n");
      $write("\nIt takes %d cycles\n", cycle);
      $write("Sorting finished!\n");
      $finish();
    end
  end

endmodule


/******************************************************************************/
module DRAM #(parameter                             MAXBURST_LOG   = 4,
              parameter                             DRAM_ADDRSPACE = 64,
              parameter                             DRAM_DATAWIDTH = 512,
              parameter                             M_LOG          = 1,
              parameter                             PAYW           = 32,
              parameter                             KEYW           = 32,
              parameter                             SORTLOG        = 10,
              parameter                             INITTYPE       = "reverse",
              parameter                             LATENCY        = 50)
             (input  wire                           CLK,
              input  wire                           RST_X,
              output reg                            init_done,
              /* Avalon-MM Interface for read */
              // this part will be automatically generated
              // Region 0
              output wire [DRAM_DATAWIDTH-1     :0] src_0_readdata,
              output wire                           src_0_readdatavalid,
              output wire                           src_0_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_0_address,
              input  wire                           src_0_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_0_byteenable,
              input  wire [MAXBURST_LOG         :0] src_0_burstcount,
              // Region 1
              output wire [DRAM_DATAWIDTH-1     :0] src_1_readdata,
              output wire                           src_1_readdatavalid,
              output wire                           src_1_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_1_address,
              input  wire                           src_1_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_1_byteenable,
              input  wire [MAXBURST_LOG         :0] src_1_burstcount,
              // Region 2
              output wire [DRAM_DATAWIDTH-1     :0] src_2_readdata,
              output wire                           src_2_readdatavalid,
              output wire                           src_2_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_2_address,
              input  wire                           src_2_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_2_byteenable,
              input  wire [MAXBURST_LOG         :0] src_2_burstcount,
              // Region 3
              output wire [DRAM_DATAWIDTH-1     :0] src_3_readdata,
              output wire                           src_3_readdatavalid,
              output wire                           src_3_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_3_address,
              input  wire                           src_3_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_3_byteenable,
              input  wire [MAXBURST_LOG         :0] src_3_burstcount,
              // Region 4
              output wire [DRAM_DATAWIDTH-1     :0] src_4_readdata,
              output wire                           src_4_readdatavalid,
              output wire                           src_4_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_4_address,
              input  wire                           src_4_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_4_byteenable,
              input  wire [MAXBURST_LOG         :0] src_4_burstcount,
              // Region 5
              output wire [DRAM_DATAWIDTH-1     :0] src_5_readdata,
              output wire                           src_5_readdatavalid,
              output wire                           src_5_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_5_address,
              input  wire                           src_5_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_5_byteenable,
              input  wire [MAXBURST_LOG         :0] src_5_burstcount,
              // Region 6
              output wire [DRAM_DATAWIDTH-1     :0] src_6_readdata,
              output wire                           src_6_readdatavalid,
              output wire                           src_6_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_6_address,
              input  wire                           src_6_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_6_byteenable,
              input  wire [MAXBURST_LOG         :0] src_6_burstcount,
              // Region 7
              output wire [DRAM_DATAWIDTH-1     :0] src_7_readdata,
              output wire                           src_7_readdatavalid,
              output wire                           src_7_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] src_7_address,
              input  wire                           src_7_read,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] src_7_byteenable,
              input  wire [MAXBURST_LOG         :0] src_7_burstcount,
              /* Avalon-MM Interface for write */
              output wire                           dst_waitrequest,
              input  wire [DRAM_ADDRSPACE-1     :0] dst_address,
              input  wire                           dst_write,
              output wire                           dst_writeack,
              input  wire [DRAM_DATAWIDTH-1     :0] dst_writedata,
              input  wire [(DRAM_DATAWIDTH>>3)-1:0] dst_byteenable,
              input  wire [MAXBURST_LOG         :0] dst_burstcount);

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value >> 1;
    end
  endfunction

  localparam [63:0] SORTNUM     = (1 << SORTLOG);
  localparam [63:0] DATW        = PAYW + KEYW;
  localparam [63:0] INITCNT_NUM = (SORTNUM >> clog2(DRAM_DATAWIDTH/DATW));
  localparam [63:0] INITCNT_LOG = clog2(INITCNT_NUM);
  localparam [63:0] DRAM_SIZE   = (INITCNT_NUM << 1);  // size in 64bytes. <<1 means that this sorter uses twice memory capacity

  reg  [DRAM_DATAWIDTH-1:0] mem [DRAM_SIZE-1:0];
  reg  [KEYW-1:0] init_key_mem [SORTNUM-1:0];

  reg                                        write_state;
  reg                                        write_waitrequest;
  reg                                        write_writeack;
  reg  [DRAM_ADDRSPACE-1:0]                  write_address;
  reg  [MAXBURST_LOG    :0]                  write_burstcount;
  wire [DRAM_DATAWIDTH-1:0]                  write_data;

  wire [DRAM_DATAWIDTH-1:0]                  init_data;
  reg  [INITCNT_LOG-1   :0]                  init_cnt;
  wire [INITCNT_LOG-1   :0]                  init_idx = init_cnt + 1;

  genvar                                     i, j, k;

  // Initialization
  //////////////////////////////////////////////////////////
  initial begin
    init_cnt = 0;
  end

  always @(posedge CLK) begin
    if (!RST_X) begin
      init_done <= 0;
      init_cnt  <= 0;
    end else if (!init_done) begin
      init_done     <= (init_cnt == (INITCNT_NUM-1));
      init_cnt      <= init_cnt + 1;
      mem[init_cnt] <= init_data;
    end
  end

  generate
    if (INITTYPE == "random") begin
      initial begin
        $readmemh("initdata.hex", init_key_mem, 0, SORTNUM-1);
      end
    end
    for (i=0; i<(DRAM_DATAWIDTH/DATW); i=i+1) begin: record
      reg [KEYW-1:0] init_key;
      always @(posedge CLK) begin
        if (INITTYPE == "sorted") begin
          if      (!RST_X)     init_key <= (i + 1);
          else if (!init_done) init_key <= init_key + (DRAM_DATAWIDTH/DATW);
        end else if (INITTYPE == "reverse") begin
          if      (!RST_X)     init_key <= (SORTNUM - i);
          else if (!init_done) init_key <= init_key - (DRAM_DATAWIDTH/DATW);
        end else if (INITTYPE == "random") begin
          if      (!RST_X)     init_key <= init_key_mem[i];
          else if (!init_done) init_key <= init_key_mem[(DRAM_DATAWIDTH/DATW)*init_idx+i];
        end
      end
      assign init_data[DATW*(i+1)-1:DATW*i] = (PAYW == 0) ? init_key : {{(PAYW){1'b1}}, init_key};
    end
  endgenerate


  // Simulate memory access behaviour
  //////////////////////////////////////////////////////////

  // read behaviour
  ////////////////////////////
  generate
    for (i=0; i<(1<<M_LOG); i=i+1) begin: mem_read
      reg                                        read_state;
      reg  [31:0]                                read_latency;
      reg                                        read_waitrequest;
      reg  [DRAM_ADDRSPACE-1:0]                  read_address;
      reg  [MAXBURST_LOG    :0]                  read_burstcount;
      wire [DRAM_DATAWIDTH-1:0]                  read_data;

      wire                                       fifo_enq;
      wire                                       fifo_deq;
      wire [(MAXBURST_LOG+1)+DRAM_ADDRSPACE-1:0] fifo_din;
      wire [(MAXBURST_LOG+1)+DRAM_ADDRSPACE-1:0] fifo_dot;
      wire                                       fifo_emp;
      wire                                       fifo_ful;
      wire [4:0]                                 fifo_cnt;

      wire [DRAM_ADDRSPACE-1                 :0] amm_slave_address;
      wire                                       amm_slave_read;
      wire [MAXBURST_LOG                     :0] amm_slave_burstcount;

      // this part will be automatically generated
      for (j=0; j<(DRAM_DATAWIDTH>>3); j=j+1) begin: read_byte
        for (k=0; k<8; k=k+1) begin: read_bit
          if      (i == 0) assign src_0_readdata[8*j+k] = src_0_byteenable[j] & read_data[8*j+k];
          else if (i == 1) assign src_1_readdata[8*j+k] = src_1_byteenable[j] & read_data[8*j+k];
          else if (i == 2) assign src_2_readdata[8*j+k] = src_2_byteenable[j] & read_data[8*j+k];
          else if (i == 3) assign src_3_readdata[8*j+k] = src_3_byteenable[j] & read_data[8*j+k];
          else if (i == 4) assign src_4_readdata[8*j+k] = src_4_byteenable[j] & read_data[8*j+k];
          else if (i == 5) assign src_5_readdata[8*j+k] = src_5_byteenable[j] & read_data[8*j+k];
          else if (i == 6) assign src_6_readdata[8*j+k] = src_6_byteenable[j] & read_data[8*j+k];
          else if (i == 7) assign src_7_readdata[8*j+k] = src_7_byteenable[j] & read_data[8*j+k];
        end
      end
      if (i == 0) begin
        assign src_0_readdatavalid  = (read_state == 1);
        assign src_0_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_0_address;
        assign amm_slave_read       = src_0_read;
        assign amm_slave_burstcount = src_0_burstcount;
      end else if (i == 1) begin
        assign src_1_readdatavalid  = (read_state == 1);
        assign src_1_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_1_address;
        assign amm_slave_read       = src_1_read;
        assign amm_slave_burstcount = src_1_burstcount;
      end else if (i == 2) begin
        assign src_2_readdatavalid  = (read_state == 1);
        assign src_2_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_2_address;
        assign amm_slave_read       = src_2_read;
        assign amm_slave_burstcount = src_2_burstcount;
      end else if (i == 3) begin
        assign src_3_readdatavalid  = (read_state == 1);
        assign src_3_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_3_address;
        assign amm_slave_read       = src_3_read;
        assign amm_slave_burstcount = src_3_burstcount;
      end else if (i == 4) begin
        assign src_4_readdatavalid  = (read_state == 1);
        assign src_4_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_4_address;
        assign amm_slave_read       = src_4_read;
        assign amm_slave_burstcount = src_4_burstcount;
      end else if (i == 5) begin
        assign src_5_readdatavalid  = (read_state == 1);
        assign src_5_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_5_address;
        assign amm_slave_read       = src_5_read;
        assign amm_slave_burstcount = src_5_burstcount;
      end else if (i == 6) begin
        assign src_6_readdatavalid  = (read_state == 1);
        assign src_6_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_6_address;
        assign amm_slave_read       = src_6_read;
        assign amm_slave_burstcount = src_6_burstcount;
      end else if (i == 7) begin
        assign src_7_readdatavalid  = (read_state == 1);
        assign src_7_waitrequest    = |{fifo_ful, read_waitrequest};
        assign amm_slave_address    = src_7_address;
        assign amm_slave_read       = src_7_read;
        assign amm_slave_burstcount = src_7_burstcount;
      end

      initial begin
        read_address = 0;
      end

      assign read_data = mem[read_address[DRAM_ADDRSPACE-1:clog2(DRAM_DATAWIDTH>>3)]];

      assign fifo_enq = &{amm_slave_read, read_waitrequest};
      assign fifo_deq = (read_latency == LATENCY);
      assign fifo_din = {amm_slave_burstcount, amm_slave_address};

      SRL_FIFO #(4, ((MAXBURST_LOG+1)+DRAM_ADDRSPACE))
      read_request_fifo(CLK, ~RST_X, fifo_enq, fifo_deq, fifo_din,
                        fifo_dot, fifo_emp, fifo_ful, fifo_cnt);

      always @(posedge CLK) begin
        if (!RST_X) begin
          read_waitrequest <= 1;
        end else begin
          if (read_waitrequest) begin if (amm_slave_read) read_waitrequest <= 0; end
          else                  begin if (~fifo_ful)      read_waitrequest <= 1; end
        end
      end

      always @(posedge CLK) begin
        if (!RST_X) begin
          read_state      <= 0;
          read_latency    <= 0;
          read_address    <= 0;
          read_burstcount <= 0;
        end else if (init_done) begin
          case (read_state)
            0: begin
              if (read_latency == LATENCY) begin
                read_state      <= 1;
                read_latency    <= 0;
                read_address    <= fifo_dot[DRAM_ADDRSPACE-1:0];
                read_burstcount <= fifo_dot[(MAXBURST_LOG+1)+DRAM_ADDRSPACE-1:DRAM_ADDRSPACE];
              end else if (~fifo_emp) begin
                read_latency <= read_latency + 1;
              end
            end
            1: begin
              if (read_burstcount == 1) read_state <= 0;
              read_address    <= (read_address[DRAM_ADDRSPACE-1:clog2(DRAM_DATAWIDTH>>3)] == DRAM_SIZE-1) ? 0 : read_address + (DRAM_DATAWIDTH>>3);
              read_burstcount <= read_burstcount - 1;
            end
          endcase
        end
      end

    end
  endgenerate

  // write behaviour
  ////////////////////////////
  assign dst_waitrequest = write_waitrequest;
  assign dst_writeack    = write_writeack;

  generate
    for (i=0; i<(DRAM_DATAWIDTH>>3); i=i+1) begin: write_byte
      for (j=0; j<8; j=j+1) begin: write_bit
        assign write_data[8*i+j] = dst_byteenable[i] & dst_writedata[8*i+j];
      end
    end
  endgenerate

  always @(posedge CLK) begin
    if (!RST_X) begin
      write_state       <= 0;
      write_waitrequest <= 1;
      write_writeack    <= 0;
      write_address     <= 0;
      write_burstcount  <= 0;
    end else if (init_done) begin
      case (write_state)
        0: begin
          write_writeack <= 0;
          if (dst_write) begin
            write_state       <= 1;
            write_waitrequest <= 0;
            write_address     <= dst_address;
            write_burstcount  <= dst_burstcount;
          end
        end
        1: begin
          if (write_burstcount == 1) begin
            write_state       <= 0;
            write_waitrequest <= 1;
            write_writeack    <= 1;
          end
          write_address    <= (write_address[DRAM_ADDRSPACE-1:clog2(DRAM_DATAWIDTH>>3)] == DRAM_SIZE-1) ? 0 : write_address + (DRAM_DATAWIDTH>>3);
          write_burstcount <= write_burstcount - 1;
          mem[write_address[DRAM_ADDRSPACE-1:clog2(DRAM_DATAWIDTH>>3)]] <= write_data;
        end
      endcase
    end
  end

endmodule

`default_nettype wire
