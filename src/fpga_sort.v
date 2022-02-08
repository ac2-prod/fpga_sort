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

/******************************************************************************/
module fpga_sort #(
                   /* memory access parameters */
                   parameter                             MAXBURST_LOG   = 4,
                   parameter                             WRITENUM_SIZE  = 5,
                   parameter                             DRAM_ADDRSPACE = 64,
                   parameter                             DRAM_DATAWIDTH = 512,
                   /* parameters for hybrid sorter's configuration */
                   parameter                             W_LOG          = 2,
                   parameter                             P_LOG          = 3,
                   parameter                             E_LOG          = 2,
                   parameter                             M_LOG          = 1,
                   parameter                             USE_IPCORE     = "INTEL",
                   parameter                             FLOAT          = "no",
                   parameter                             SIGNED         = "no",
                   parameter                             PAYW           = 32,
                   parameter                             KEYW           = 32,
                   parameter                             NUMW           = 32
                   )
                  (
                   /* global clock and low-actived reset */
                   input  wire                           clock,
                   input  wire                           resetn,
                   /* mapped to arguments from cl code */
                   input  wire [DRAM_ADDRSPACE-1     :0] cl_dummy,      // *dummy
                   input  wire [DRAM_ADDRSPACE-1     :0] cl_dst_addr,   // dst_addr
                   input  wire [DRAM_ADDRSPACE-1     :0] cl_src_addr,   // src_addr
                   input  wire [NUMW-1               :0] cl_numdata,    // numdata
                   output wire [ 31:0]                   cl_ret,        // ret
                   /* Avalon-ST Interface */
                   output reg                            ast_o_ready,
                   input  wire                           ast_i_valid,
                   output reg                            ast_o_valid,
                   input  wire                           ast_i_ready,
                   /* Avalon-MM Interface for read */
                   // this part will be automatically generated
                   // Region 0
                   input  wire [DRAM_DATAWIDTH-1     :0] src_0_readdata,
                   input  wire                           src_0_readdatavalid,
                   input  wire                           src_0_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_0_address,
                   output wire                           src_0_read,
                   output wire                           src_0_write,
                   input  wire                           src_0_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_0_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_0_byteenable,
                   output wire [MAXBURST_LOG         :0] src_0_burstcount,
                   // Region 1
                   input  wire [DRAM_DATAWIDTH-1     :0] src_1_readdata,
                   input  wire                           src_1_readdatavalid,
                   input  wire                           src_1_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_1_address,
                   output wire                           src_1_read,
                   output wire                           src_1_write,
                   input  wire                           src_1_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_1_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_1_byteenable,
                   output wire [MAXBURST_LOG         :0] src_1_burstcount,
                   // Region 2
                   input  wire [DRAM_DATAWIDTH-1     :0] src_2_readdata,
                   input  wire                           src_2_readdatavalid,
                   input  wire                           src_2_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_2_address,
                   output wire                           src_2_read,
                   output wire                           src_2_write,
                   input  wire                           src_2_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_2_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_2_byteenable,
                   output wire [MAXBURST_LOG         :0] src_2_burstcount,
                   // Region 3
                   input  wire [DRAM_DATAWIDTH-1     :0] src_3_readdata,
                   input  wire                           src_3_readdatavalid,
                   input  wire                           src_3_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_3_address,
                   output wire                           src_3_read,
                   output wire                           src_3_write,
                   input  wire                           src_3_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_3_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_3_byteenable,
                   output wire [MAXBURST_LOG         :0] src_3_burstcount,
                   // Region 4
                   input  wire [DRAM_DATAWIDTH-1     :0] src_4_readdata,
                   input  wire                           src_4_readdatavalid,
                   input  wire                           src_4_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_4_address,
                   output wire                           src_4_read,
                   output wire                           src_4_write,
                   input  wire                           src_4_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_4_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_4_byteenable,
                   output wire [MAXBURST_LOG         :0] src_4_burstcount,
                   // Region 5
                   input  wire [DRAM_DATAWIDTH-1     :0] src_5_readdata,
                   input  wire                           src_5_readdatavalid,
                   input  wire                           src_5_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_5_address,
                   output wire                           src_5_read,
                   output wire                           src_5_write,
                   input  wire                           src_5_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_5_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_5_byteenable,
                   output wire [MAXBURST_LOG         :0] src_5_burstcount,
                   // Region 6
                   input  wire [DRAM_DATAWIDTH-1     :0] src_6_readdata,
                   input  wire                           src_6_readdatavalid,
                   input  wire                           src_6_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_6_address,
                   output wire                           src_6_read,
                   output wire                           src_6_write,
                   input  wire                           src_6_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_6_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_6_byteenable,
                   output wire [MAXBURST_LOG         :0] src_6_burstcount,
                   // Region 7
                   input  wire [DRAM_DATAWIDTH-1     :0] src_7_readdata,
                   input  wire                           src_7_readdatavalid,
                   input  wire                           src_7_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] src_7_address,
                   output wire                           src_7_read,
                   output wire                           src_7_write,
                   input  wire                           src_7_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] src_7_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] src_7_byteenable,
                   output wire [MAXBURST_LOG         :0] src_7_burstcount,
                   /* Avalon-MM Interface for write */
                   input  wire [DRAM_DATAWIDTH-1     :0] dst_readdata,
                   input  wire                           dst_readdatavalid,
                   input  wire                           dst_waitrequest,
                   output wire [DRAM_ADDRSPACE-1     :0] dst_address,
                   output wire                           dst_read,
                   output wire                           dst_write,
                   input  wire                           dst_writeack,
                   output wire [DRAM_DATAWIDTH-1     :0] dst_writedata,
                   output wire [(DRAM_DATAWIDTH>>3)-1:0] dst_byteenable,
                   output wire [MAXBURST_LOG         :0] dst_burstcount
                   );

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value >> 1;
    end
  endfunction

  localparam [63:0] DATW                    = (PAYW + KEYW);
  localparam [63:0] ALLWAY_LOG              = (E_LOG + W_LOG);
  localparam [63:0] RECORDS_SORTED_INITPASS = (1 << (P_LOG + ALLWAY_LOG));
  localparam [63:0] PACK_LOG                = clog2((DATW<<P_LOG) / DRAM_DATAWIDTH);
  localparam [63:0] READNUM_SIZE            = (ALLWAY_LOG + PACK_LOG);
  localparam [63:0] ELEMS_LOG_PER_ACCESS    = clog2(DRAM_DATAWIDTH / DATW);

  wire                                                   CLK;
  wire                                                   RST;
  reg                                                    rst;
  wire                                                   start;
  reg                                                    finish;
  reg  [1:0]                                             state;

  reg                                                    special_rst;

  reg  [DRAM_ADDRSPACE-1                             :0] dst_addr;
  reg  [DRAM_ADDRSPACE-1                             :0] src_addr;
  reg  [NUMW-1                                       :0] sortnum;

  reg                                                    argument_recieved;
  wire [clog2(NUMW)-1                                :0] sortlog;
  wire                                                   sortlog_done;
  wire                                                   clog2_rdy;

  reg                                                    use_stnet;
  reg                                                    final_pass;
  reg                                                    bypass;
  reg  [(NUMW-(E_LOG+P_LOG))-1                       :0] bypass_cnt_per_vtree;
  reg  [clog2(W_LOG)                                 :0] final_read_waylog;
  reg  [clog2(NUMW)-1                                :0] waylog_per_portion;
  reg  [clog2(NUMW)-1                                :0] portion_log;
  reg  [(NUMW-E_LOG)-1                               :0] ejected_cnt;
  reg  [NUMW-1                                       :0] elems_stored;
  reg                                                    pass_done;
  reg  [31:0]                                            passnum;

  reg  [clog2(NUMW)-1                                :0] mul_passnum_allwaylog;

  wire                                                   hybrid_sorter_use_stnet;
  wire                                                   hybrid_sorter_in_ful;
  wire [((DATW<<P_LOG)<<M_LOG)-1                     :0] hybrid_sorter_din;
  wire [(1<<M_LOG)-1                                 :0] hybrid_sorter_dinen;
  wire [((E_LOG+W_LOG)<<M_LOG)-1                     :0] hybrid_sorter_din_idx;
  wire [(DATW<<E_LOG)-1                              :0] hybrid_sorter_dot;
  wire                                                   hybrid_sorter_doten;
  wire [(1<<(E_LOG+W_LOG))-1                         :0] hybrid_sorter_emp;
  wire [(1<<E_LOG)-1                                 :0] hybrid_sorter_bufed;

  wire                                                   wbuf_deq;
  wire [(DATW<<E_LOG)-1                              :0] wbuf_din;
  wire                                                   wbuf_dinen;
  wire [DRAM_DATAWIDTH-1                             :0] wbuf_dot;
  wire                                                   wbuf_ful;
  wire                                                   wbuf_request_sent;

  reg  [1:0]                                             write_state;
  reg  [(NUMW-(ELEMS_LOG_PER_ACCESS+WRITENUM_SIZE))-1:0] write_requestnum;

  reg                                                    write_request;
  reg  [DRAM_ADDRSPACE-1                             :0] write_initaddr;
  wire [WRITENUM_SIZE                                :0] write_datanum;
  wire [DRAM_DATAWIDTH-1                             :0] write_data;
  wire                                                   write_data_acceptable;
  wire                                                   write_request_rdy;
  wire                                                   write_request_done;

  assign CLK    = clock;
  assign RST    = ~resetn;
  assign start  = &{ast_o_ready, ast_i_valid};
  assign cl_ret = passnum[0];

  always @(posedge CLK) begin
    rst <= start;
  end

  genvar i;
  generate
    for (i=0; i<(1<<M_LOG); i=i+1) begin: mem_read_controllers
      reg                            read_request;
      reg  [DRAM_ADDRSPACE-1     :0] read_initaddr;
      reg  [READNUM_SIZE         :0] read_datanum;
      wire [DRAM_DATAWIDTH-1     :0] read_data;
      wire                           read_datavalid;
      wire                           read_request_rdy;
      wire [ALLWAY_LOG-1         :0] read_index;

      wire [DRAM_DATAWIDTH-1     :0] amm_read_readdata;
      wire                           amm_read_readdatavalid;
      wire                           amm_read_waitrequest;
      wire [DRAM_ADDRSPACE-1     :0] amm_read_address;
      wire                           amm_read_read;
      wire                           amm_read_write;
      wire                           amm_read_writeack;
      wire [DRAM_DATAWIDTH-1     :0] amm_read_writedata;
      wire [(DRAM_DATAWIDTH>>3)-1:0] amm_read_byteenable;
      wire [MAXBURST_LOG         :0] amm_read_burstcount;

      // this part will be automatically generated
      if (i == 0) begin
        assign amm_read_readdata      = src_0_readdata;
        assign amm_read_readdatavalid = src_0_readdatavalid;
        assign amm_read_waitrequest   = src_0_waitrequest;
        assign src_0_address          = amm_read_address;
        assign src_0_read             = amm_read_read;
        assign src_0_write            = amm_read_write;
        assign amm_read_writeack      = src_0_writeack;
        assign src_0_writedata        = amm_read_writedata;
        assign src_0_byteenable       = amm_read_byteenable;
        assign src_0_burstcount       = amm_read_burstcount;
      end else if (i == 1) begin
        assign amm_read_readdata      = src_1_readdata;
        assign amm_read_readdatavalid = src_1_readdatavalid;
        assign amm_read_waitrequest   = src_1_waitrequest;
        assign src_1_address          = amm_read_address;
        assign src_1_read             = amm_read_read;
        assign src_1_write            = amm_read_write;
        assign amm_read_writeack      = src_1_writeack;
        assign src_1_writedata        = amm_read_writedata;
        assign src_1_byteenable       = amm_read_byteenable;
        assign src_1_burstcount       = amm_read_burstcount;
      end else if (i == 2) begin
        assign amm_read_readdata      = src_2_readdata;
        assign amm_read_readdatavalid = src_2_readdatavalid;
        assign amm_read_waitrequest   = src_2_waitrequest;
        assign src_2_address          = amm_read_address;
        assign src_2_read             = amm_read_read;
        assign src_2_write            = amm_read_write;
        assign amm_read_writeack      = src_2_writeack;
        assign src_2_writedata        = amm_read_writedata;
        assign src_2_byteenable       = amm_read_byteenable;
        assign src_2_burstcount       = amm_read_burstcount;
      end else if (i == 3) begin
        assign amm_read_readdata      = src_3_readdata;
        assign amm_read_readdatavalid = src_3_readdatavalid;
        assign amm_read_waitrequest   = src_3_waitrequest;
        assign src_3_address          = amm_read_address;
        assign src_3_read             = amm_read_read;
        assign src_3_write            = amm_read_write;
        assign amm_read_writeack      = src_3_writeack;
        assign src_3_writedata        = amm_read_writedata;
        assign src_3_byteenable       = amm_read_byteenable;
        assign src_3_burstcount       = amm_read_burstcount;
      end else if (i == 4) begin
        assign amm_read_readdata      = src_4_readdata;
        assign amm_read_readdatavalid = src_4_readdatavalid;
        assign amm_read_waitrequest   = src_4_waitrequest;
        assign src_4_address          = amm_read_address;
        assign src_4_read             = amm_read_read;
        assign src_4_write            = amm_read_write;
        assign amm_read_writeack      = src_4_writeack;
        assign src_4_writedata        = amm_read_writedata;
        assign src_4_byteenable       = amm_read_byteenable;
        assign src_4_burstcount       = amm_read_burstcount;
      end else if (i == 5) begin
        assign amm_read_readdata      = src_5_readdata;
        assign amm_read_readdatavalid = src_5_readdatavalid;
        assign amm_read_waitrequest   = src_5_waitrequest;
        assign src_5_address          = amm_read_address;
        assign src_5_read             = amm_read_read;
        assign src_5_write            = amm_read_write;
        assign amm_read_writeack      = src_5_writeack;
        assign src_5_writedata        = amm_read_writedata;
        assign src_5_byteenable       = amm_read_byteenable;
        assign src_5_burstcount       = amm_read_burstcount;
      end else if (i == 6) begin
        assign amm_read_readdata      = src_6_readdata;
        assign amm_read_readdatavalid = src_6_readdatavalid;
        assign amm_read_waitrequest   = src_6_waitrequest;
        assign src_6_address          = amm_read_address;
        assign src_6_read             = amm_read_read;
        assign src_6_write            = amm_read_write;
        assign amm_read_writeack      = src_6_writeack;
        assign src_6_writedata        = amm_read_writedata;
        assign src_6_byteenable       = amm_read_byteenable;
        assign src_6_burstcount       = amm_read_burstcount;
      end else if (i == 7) begin
        assign amm_read_readdata      = src_7_readdata;
        assign amm_read_readdatavalid = src_7_readdatavalid;
        assign amm_read_waitrequest   = src_7_waitrequest;
        assign src_7_address          = amm_read_address;
        assign src_7_read             = amm_read_read;
        assign src_7_write            = amm_read_write;
        assign amm_read_writeack      = src_7_writeack;
        assign src_7_writedata        = amm_read_writedata;
        assign src_7_byteenable       = amm_read_byteenable;
        assign src_7_burstcount       = amm_read_burstcount;
      end

      AVALON_MM_READ #(
                       MAXBURST_LOG,
                       READNUM_SIZE,
                       DRAM_ADDRSPACE,
                       DRAM_DATAWIDTH
                       )
      avalon_mm_read(
                     CLK,
                     rst,
                     ////////// User logic interface ///////////////
                     read_request,
                     read_initaddr,
                     read_datanum,
                     read_data,
                     read_datavalid,
                     read_request_rdy,
                     ////////// Avalon-MM interface  ///////////////
                     amm_read_readdata,
                     amm_read_readdatavalid,
                     amm_read_waitrequest,
                     amm_read_address,
                     amm_read_read,
                     amm_read_write,
                     amm_read_writeack,
                     amm_read_writedata,
                     amm_read_byteenable,
                     amm_read_burstcount
                     );

      wire [DRAM_DATAWIDTH-1:0] data_packer_din;
      wire                      data_packer_dinen;
      wire [(DATW<<P_LOG)-1 :0] data_packer_dot;
      wire                      data_packer_doten;

      if (FLOAT == "yes") begin
        wire [DRAM_DATAWIDTH-1:0] float2int_din;
        wire                      float2int_dinen;
        wire [DRAM_DATAWIDTH-1:0] float2int_dot;
        wire                      float2int_doten;
        assign float2int_din     = read_data;
        assign float2int_dinen   = read_datavalid;
        FLOAT2INT #(DRAM_DATAWIDTH, PAYW, KEYW)
        float2int(CLK, rst, float2int_din, float2int_dinen,
                  float2int_dot, float2int_doten);
        assign data_packer_din   = float2int_dot;
        assign data_packer_dinen = float2int_doten;
      end else begin
        assign data_packer_din   = read_data;
        assign data_packer_dinen = read_datavalid;
      end

      DATA_PACKER #(DRAM_DATAWIDTH, (DATW<<P_LOG), PACK_LOG)
      data_packer(CLK, rst, data_packer_din, data_packer_dinen,
                  data_packer_dot, data_packer_doten);

      assign hybrid_sorter_din[((DATW<<P_LOG)*(i+1))-1:(DATW<<P_LOG)*i]     = data_packer_dot;
      assign hybrid_sorter_dinen[i]                                         = data_packer_doten;
      assign hybrid_sorter_din_idx[((E_LOG+W_LOG)*(i+1))-1:(E_LOG+W_LOG)*i] = read_index;

    end
  endgenerate

  assign hybrid_sorter_use_stnet = use_stnet;
  assign hybrid_sorter_in_ful    = wbuf_ful;

  HYBRID_SORTER #(
                  W_LOG,
                  P_LOG,
                  E_LOG,
                  M_LOG,
                  USE_IPCORE,
                  FLOAT,
                  SIGNED,
                  DATW,
                  KEYW,
                  NUMW,
                  clog2(NUMW)
                  )
  hybrid_sorter(
                CLK,
                rst,
                special_rst,
                pass_done,
                final_pass,
                bypass,
                mul_passnum_allwaylog,
                waylog_per_portion,
                bypass_cnt_per_vtree,
                hybrid_sorter_use_stnet,
                hybrid_sorter_in_ful,
                hybrid_sorter_din,
                hybrid_sorter_dinen,
                hybrid_sorter_din_idx,
                hybrid_sorter_dot,
                hybrid_sorter_doten,
                hybrid_sorter_emp,
                hybrid_sorter_bufed
                );

  generate
    if (FLOAT == "yes") begin
      wire [(DATW<<E_LOG)-1:0] int2float_din;
      wire                     int2float_dinen;
      wire [(DATW<<E_LOG)-1:0] int2float_dot;
      wire                     int2float_doten;
      assign int2float_din   = hybrid_sorter_dot;
      assign int2float_dinen = &{~special_rst, hybrid_sorter_doten};
      INT2FLOAT #((DATW<<E_LOG), PAYW, KEYW)
      int2float(CLK, rst, int2float_din, int2float_dinen,
                int2float_dot, int2float_doten);
      assign wbuf_din        = int2float_dot;
      assign wbuf_dinen      = int2float_doten;
    end else begin
      assign wbuf_din        = hybrid_sorter_dot;
      assign wbuf_dinen      = &{~special_rst, hybrid_sorter_doten};
    end
  endgenerate

  WRITE_BUFFER #((DATW<<E_LOG), DRAM_DATAWIDTH, (WRITENUM_SIZE+1), (1<<WRITENUM_SIZE), USE_IPCORE)  // 6(WRITENUM_SIZE+1) is arbitrary value (more than 4 is preferred)
  write_buffer(CLK, rst, wbuf_din, wbuf_dinen, wbuf_deq,
               wbuf_dot, wbuf_ful, wbuf_request_sent);

  assign wbuf_deq      = write_data_acceptable;
  assign write_datanum = (1 << WRITENUM_SIZE);
  assign write_data    = wbuf_dot;

  AVALON_MM_WRITE #(MAXBURST_LOG, WRITENUM_SIZE, DRAM_ADDRSPACE, DRAM_DATAWIDTH)
  avalon_mm_write(CLK,
                  rst,
                  ////////// User logic interface ///////////////
                  write_request,
                  write_initaddr,
                  write_datanum,
                  write_data,
                  write_data_acceptable,
                  write_request_rdy,
                  write_request_done,
                  ////////// Avalon-MM interface  ///////////////
                  dst_readdata,
                  dst_readdatavalid,
                  dst_waitrequest,
                  dst_address,
                  dst_read,
                  dst_write,
                  dst_writeack,
                  dst_writedata,
                  dst_byteenable,
                  dst_burstcount);

  // Control logics for returned value and its condition
  // #################################################################
  // for Avalon-ST protocol
  always @(posedge CLK) begin
    if (RST) begin
      state       <= 0;
      ast_o_ready <= 0;
      ast_o_valid <= 0;
    end else begin
      case (state)
        0: begin  // sorter is ready
          state       <= 1;
          ast_o_ready <= 1;
        end
        1: begin  // wait for ast_i_valid to be asserted
          state <= {~ast_o_ready, ast_o_ready};
          if (ast_i_valid) begin
            ast_o_ready <= 0;
          end
        end
        2: begin  // ovalid is asserted
          state       <= {1'b1, finish};
          ast_o_valid <= finish;
        end
        3: begin  // sorter is done
          state       <= {(2){~ast_i_ready}};
          ast_o_valid <= ~ast_i_ready;
        end
      endcase
    end
  end

  // /* sorting process is done */
  always @(posedge CLK) begin
    if (rst) begin
      finish <= 0;
    end else begin
      if (&{pass_done, final_pass}) finish <= 1;
    end
  end

  ///// hold off on this implementation for debugging
  // /* counter */
  // reg [31:0] cycle;
  // always @(posedge CLK) begin
  //   if (rst) begin
  //     finish <= 0;
  //     cycle  <= 0;
  //   end else begin
  //     if      (&{pass_done, final_pass}) finish <= 1;
  //     else if (!finish)                  cycle <= cycle + 1;
  //   end
  // end

  // Control logics of hybrid_sorter operation
  // #################################################################
  /* reset signal to start a portion generation */
  localparam [63:0] RESET_CYCLE = 7;

  reg [clog2(RESET_CYCLE):0] special_rst_cnt;

  always @(posedge CLK) begin
    if (rst) begin
      special_rst     <= 1;
      special_rst_cnt <= RESET_CYCLE - 1;
    end else begin
      case (special_rst)
        1'b0: begin
          special_rst     <= |{&{(ejected_cnt==1), hybrid_sorter_doten}, pass_done};
          special_rst_cnt <= (pass_done) ? RESET_CYCLE - 1 : 1;
        end
        1'b1: begin
          special_rst     <= |special_rst_cnt;  // (special_rst_cnt != 0)
          special_rst_cnt <= special_rst_cnt - 1;
        end
      endcase
    end
  end

  /* recieve arguments from cl code and calculate sortlog */
  always @(posedge CLK) begin
    if (start) begin
      dst_addr <= cl_dst_addr;
      src_addr <= cl_src_addr;
      sortnum  <= cl_numdata;
      // sortnum  <= (cl_numdata < RECORDS_SORTED_INITPASS) ? RECORDS_SORTED_INITPASS : cl_numdata;
    end
  end
  always @(posedge CLK) begin
    argument_recieved <= start;
  end
  CLOG2 #(NUMW, clog2(NUMW))
  CLOG2_SORTNUM(CLK, start, sortnum, argument_recieved, sortlog, sortlog_done, clog2_rdy);

  /* Will be the sorting network used? */
  always @(posedge CLK) use_stnet <= ~|passnum;  // (passnum == 0);

  /* counting elements to be stored in an external memory */
  always @(posedge CLK) begin
    if (rst) begin
      elems_stored <= 0;
    end else begin
      case ({wbuf_deq, pass_done})
        2'b01: elems_stored <= 0;
        2'b10: elems_stored <= elems_stored + (1 << ELEMS_LOG_PER_ACCESS);
      endcase
    end
  end

  /* the entire dataset has been passed */
  always @(posedge CLK) begin
    pass_done <= &{(elems_stored==sortnum), write_request_done};
  end

  /* counting how many times the entire dataset has been passed */
  always @(posedge CLK) begin
    if      (rst)       passnum <= 0;
    else if (pass_done) passnum <= passnum + 1;
  end

  /* counting how many elements are ejected from the hybrid sorter to generate a portion */
  // (P_LOG + (passnum+1) * ALLWAY_LOG)
  wire [clog2(NUMW)-1:0] madd_calc_ecnt_rslt;
  MADD_KERNEL #(5, 32, 32, 32, clog2(NUMW))
  madd_calc_ecnt(CLK, P_LOG, (passnum+1), ALLWAY_LOG[31:0], madd_calc_ecnt_rslt);

  always @(posedge CLK) begin
    if      (special_rst)         ejected_cnt <= (final_pass) ? (sortnum >> E_LOG) : (1 << (madd_calc_ecnt_rslt - E_LOG));
    else if (hybrid_sorter_doten) ejected_cnt <= ejected_cnt - 1;
  end

  /* taking the logarithim of the number of ways per portion and the number of portions */
  // (P_LOG + passnum * ALLWAY_LOG)
  reg [clog2(NUMW)-1:0] madd_calc_portion_log_rslt;
  always @(posedge CLK) begin
    if      (rst)       madd_calc_portion_log_rslt <= P_LOG;
    else if (pass_done) madd_calc_portion_log_rslt <= madd_calc_ecnt_rslt;
  end

  always @(posedge CLK) begin
    bypass_cnt_per_vtree <= (sortnum >> (E_LOG + P_LOG));
    // final_read_waylog    <= (bypass) ? W_LOG : |waylog_per_portion;
    final_read_waylog    <= (bypass) ? W_LOG : 0;
    waylog_per_portion   <= ALLWAY_LOG - portion_log;
    portion_log          <= sortlog - madd_calc_portion_log_rslt;
  end

  /* determing whether this is final pass */
  // (0 + passnum * ALLWAY_LOG) = (passnum * ALLWAY_LOG)
  always @(posedge CLK) begin
    if      (rst)       mul_passnum_allwaylog <= 0;
    else if (pass_done) mul_passnum_allwaylog <= madd_calc_ecnt_rslt - P_LOG;
  end

  always @(posedge CLK) begin
    final_pass <= &{(sortnum <= (RECORDS_SORTED_INITPASS << mul_passnum_allwaylog)), sortlog_done};
    bypass     <= &{~use_stnet, final_pass, (portion_log <= E_LOG)};
  end

  // AVALON_MM's state machines
  // #################################################################
  /* state machine for AVALON_MM_READ */

  // READ_REQUEST_CON_F
  wire                      f_read_req;
  wire [DRAM_ADDRSPACE-1:0] f_read_initaddr;
  wire [READNUM_SIZE    :0] f_read_datanum;
  wire [ALLWAY_LOG-1    :0] f_read_index;

  reg                       f_read_data_buffered;
  always @(posedge CLK) begin
    f_read_data_buffered <= (rst) ? 0 : |hybrid_sorter_bufed;
  end

  READ_REQUEST_CON_F #(
                       READNUM_SIZE,
                       DRAM_ADDRSPACE,
                       DRAM_DATAWIDTH,
                       PACK_LOG,
                       ELEMS_LOG_PER_ACCESS,
                       ALLWAY_LOG,
                       NUMW
                       )
  read_request_con_f(
                     CLK,
                     rst,
                     hybrid_sorter_emp[(1<<(E_LOG+W_LOG))-1],
                     sortlog_done,
                     src_addr,
                     sortnum,
                     hybrid_sorter_dinen[0],
                     f_read_data_buffered,
                     mem_read_controllers[0].read_request_rdy,
                     f_read_req,
                     f_read_initaddr,
                     f_read_datanum,
                     f_read_index
                     );

  // MADD (ax + ay * az): read_initaddr + p * ((sortnum>>ALLWAY_LOG)<<clog2(DATW>>3))
  // calculation for init value of each read pointer
  reg                       madd_i_en;
  reg  [DRAM_ADDRSPACE-1:0] ax;
  reg  [ALLWAY_LOG-1:    0] ay;
  reg  [DRAM_ADDRSPACE-1:0] az;
  wire [DRAM_ADDRSPACE-1:0] madd_rslt;
  wire                      madd_o_en;

  MADD #(5, DRAM_ADDRSPACE, ALLWAY_LOG, DRAM_ADDRSPACE, DRAM_ADDRSPACE)
  madd(CLK, rst, madd_i_en, ax, ay, az, madd_rslt, madd_o_en);

  reg  [ALLWAY_LOG:      0] init_idx;
  reg                       init_start;

  always @(posedge CLK) begin
    madd_i_en <= (rst) ? 0 : &{init_start, ~init_idx[ALLWAY_LOG]};
  end

  always @(posedge CLK) begin
    ax <= (passnum[0]) ? dst_addr : src_addr;
  end

  always @(posedge CLK) begin
    if (rst) begin
      init_start <= 0;
    end else begin
      case (init_start)
        1'b0: begin
          init_start <= &{pass_done, ~final_pass};
        end
        1'b1: begin
          init_start <= ~init_idx[ALLWAY_LOG];
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    init_idx <= (init_start) ? init_idx + 1 : 0;
    ay       <= init_idx[ALLWAY_LOG-1:0];
  end

  always @(posedge CLK) begin
    az <= ((sortnum>>ALLWAY_LOG)<<clog2(DATW>>3));
  end

  reg [ALLWAY_LOG-1:0] madd_rslt_idx;
  always @(posedge CLK) begin
    if      (rst)       madd_rslt_idx <= 0;
    else if (madd_o_en) madd_rslt_idx <= madd_rslt_idx + 1;
  end

  // READ_REQUEST_CON_S
  localparam R_LOG = ALLWAY_LOG[31:0] - M_LOG;

  reg [DRAM_ADDRSPACE-1:0] requester_init_data;
  always @(posedge CLK) begin
    requester_init_data <= madd_rslt;
  end

  generate
    for (i=0; i<(1<<M_LOG); i=i+1) begin: read_requesters
      wire                      s_read_req;
      wire [DRAM_ADDRSPACE-1:0] s_read_initaddr;
      wire [READNUM_SIZE    :0] s_read_datanum;
      wire [R_LOG-1         :0] s_read_index;

      reg                       s_read_data_buffered;
      always @(posedge CLK) begin
        s_read_data_buffered <= (rst) ? 0 : |hybrid_sorter_bufed[((1<<(E_LOG-M_LOG))*(i+1))-1:((1<<(E_LOG-M_LOG))*i)];
      end

      reg requester_init_data_en;
      if (M_LOG == 0) begin
        always @(posedge CLK) begin
          requester_init_data_en <= (rst) ? 0 : madd_o_en;
        end
      end else begin
        always @(posedge CLK) begin
          requester_init_data_en <= (rst) ? 0 : &{madd_o_en, (madd_rslt_idx[ALLWAY_LOG-1:R_LOG] == i)};
        end
      end

      READ_REQUEST_CON_S #(
                           READNUM_SIZE,
                           DRAM_ADDRSPACE,
                           DRAM_DATAWIDTH,
                           PACK_LOG,
                           ELEMS_LOG_PER_ACCESS,
                           clog2(W_LOG),
                           R_LOG,
                           ALLWAY_LOG,
                           USE_IPCORE,
                           NUMW
                           )
      read_request_con_s(
                         CLK,
                         rst,
                         hybrid_sorter_emp[((1<<R_LOG)*(i+1))-1:((1<<R_LOG)*i)],
                         pass_done,
                         final_pass,
                         final_read_waylog,
                         sortnum,
                         hybrid_sorter_dinen[i],
                         s_read_data_buffered,
                         requester_init_data,
                         requester_init_data_en,
                         mem_read_controllers[i].read_request_rdy,
                         s_read_req,
                         s_read_initaddr,
                         s_read_datanum,
                         s_read_index
                         );

      if (i == 0) begin
        always @(posedge CLK) begin
          mem_read_controllers[i].read_request  <= (use_stnet) ? f_read_req      : s_read_req;
          mem_read_controllers[i].read_initaddr <= (use_stnet) ? f_read_initaddr : s_read_initaddr;
          mem_read_controllers[i].read_datanum  <= (use_stnet) ? f_read_datanum  : s_read_datanum;
        end
        if (M_LOG == 0) begin
          assign mem_read_controllers[i].read_index = (use_stnet) ? f_read_index : s_read_index;
        end else begin
          wire [M_LOG-1:0] requester_id = i;
          assign mem_read_controllers[i].read_index = (use_stnet) ? f_read_index : {requester_id, s_read_index};
        end
      end else begin
        always @(posedge CLK) begin
          mem_read_controllers[i].read_request  <= s_read_req;
          mem_read_controllers[i].read_initaddr <= s_read_initaddr;
          mem_read_controllers[i].read_datanum  <= s_read_datanum;
        end
        wire [M_LOG-1:0] requester_id = i;
        assign mem_read_controllers[i].read_index = {requester_id, s_read_index};
      end
    end
  endgenerate

  /* state machine for AVALON_MM_WRITE */
  always @(posedge CLK) begin
    if (rst) begin
      write_state   <= 0;
      write_request <= 0;
    end else begin
      case (write_state)
        ////////// reset ////////////////////////////////
        0: begin
          write_state <= sortlog_done;
        end
        ////////// send write_request ///////////////////
        1: begin
          if (wbuf_request_sent) begin
            write_state   <= 2;
            write_request <= 1;
          end
        end
        ////////// memory write is operating ////////////
        2: begin
          write_request <= 0;
          if (write_request_done) begin
            write_state <= {(~|write_requestnum), 1'b1};  // (~|write_requestnum) ? 3 : 1
          end
        end
        ////////// wait until the next pass begins //////
        3: begin
          if (&{pass_done, ~final_pass}) write_state <= 0;
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    case (write_state)
      2'b00: begin
        write_requestnum <= ((sortnum >> ELEMS_LOG_PER_ACCESS) >> WRITENUM_SIZE);
        write_initaddr   <= (passnum[0]) ? src_addr : dst_addr;
      end
      default: begin
        if (write_request) begin
          write_requestnum <= write_requestnum - 1;
          write_initaddr   <= write_initaddr + ((DRAM_DATAWIDTH>>3) << WRITENUM_SIZE);
        end
      end
    endcase
  end

endmodule

`default_nettype wire
