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

/***** A read request controller for the first pass                       *****/
/******************************************************************************/
module READ_REQUEST_CON_F #(
                            parameter                             READNUM_SIZE         = 32,
                            parameter                             DRAM_ADDRSPACE       = 64,
                            parameter                             DRAM_DATAWIDTH       = 512,
                            parameter                             PACK_LOG             = 1,
                            parameter                             ELEMS_LOG_PER_ACCESS = 3,
                            parameter                             ALLWAY_LOG           = 5,
                            parameter                             NUMW                 = 32
                            )
                           (
                            input  wire                           CLK,
                            input  wire                           RST,
                            input  wire                           REQ,
                            input  wire                           CLOG2_DONE,
                            input  wire [DRAM_ADDRSPACE-1     :0] SRC_ADDR,
                            input  wire [NUMW-1               :0] SORTNUM,
                            input  wire                           DATA_INTO_SORTER,
                            input  wire                           DATA_STORED,
                            /* An output port of the User logic interface of AVALON_MM_READ */
                            input  wire                           READ_REQUEST_RDY,
                            /* To input ports of the User logic interface of AVALON_MM_READ */
                            output wire                           READ_REQ,
                            output wire [DRAM_ADDRSPACE-1     :0] READ_INITADDR,
                            output wire [READNUM_SIZE         :0] READ_NUM,
                            // index to point which buffer in tree_filler stores read data
                            output wire [ALLWAY_LOG-1         :0] READ_INDEX
                            );

  reg [1:0]                                            read_state;
  reg                                                  read_request;
  reg [DRAM_ADDRSPACE-1                            :0] read_initaddr;
  reg [ALLWAY_LOG-1                                :0] read_index;
  reg [READNUM_SIZE                                :0] read_datanum;
  reg [(NUMW-(ELEMS_LOG_PER_ACCESS+READNUM_SIZE))-1:0] read_requestnum;

  /* state machine for a read request controller */
  always @(posedge CLK) begin
    if (RST) begin
      read_state   <= 0;
      read_request <= 0;
    end else begin
      case (read_state)
        0: begin
          read_state <= CLOG2_DONE;
        end
        1: begin  // send read_request
          if (REQ) begin
            read_state   <= 2;
            read_request <= 1;
          end
        end
        2: begin  // memory read is operating
          read_request <= 0;
          if (&{READ_REQUEST_RDY, ~|read_datanum}) begin
            read_state <= {~|read_requestnum, 1'b1};  // (~|read_requestnum) ? 3 : 1;
          end
        end
        3: begin  // All data has been read from the external memory
        end
      endcase
    end
  end

  // set read_initaddr and read_requestnum
  always @(posedge CLK) begin
    if (RST) begin
      read_initaddr   <= SRC_ADDR;
      read_requestnum <= (SORTNUM >> (ELEMS_LOG_PER_ACCESS + READNUM_SIZE));
  end else begin
      if (read_request) begin
        read_initaddr   <= read_initaddr + ((DRAM_DATAWIDTH>>3) << READNUM_SIZE);
        read_requestnum <= read_requestnum - 1;
      end
    end
  end

  // set read_index and read_datanum
  always @(posedge CLK) begin
    if (read_state == 1) begin
      read_index   <= 0;
      read_datanum <= (1 << READNUM_SIZE);
    end else begin
      if (DATA_INTO_SORTER) read_index   <= read_index + 1;
      if (DATA_STORED)      read_datanum <= read_datanum - (1 << PACK_LOG);
    end
  end

  assign READ_REQ      = read_request;
  assign READ_INITADDR = read_initaddr;
  assign READ_NUM      = read_datanum;
  assign READ_INDEX    = read_index;

endmodule


/***** A read request controller for subsequent passes                    *****/
/******************************************************************************/
module READ_REQUEST_CON_S #(
                            parameter                             READNUM_SIZE         = 32,
                            parameter                             DRAM_ADDRSPACE       = 64,
                            parameter                             DRAM_DATAWIDTH       = 512,
                            parameter                             PACK_LOG             = 1,
                            parameter                             ELEMS_LOG_PER_ACCESS = 3,
                            parameter                             W_LOG_LOG            = 2,
                            parameter                             R_LOG                = 5,
                            parameter                             ALLWAY_LOG           = 5,
                            parameter                             USE_IPCORE           = "INTEL",
                            parameter                             NUMW                 = 32
                            )
                           (
                            input  wire                           CLK,
                            input  wire                           RST,
                            input  wire [(1<<(R_LOG))-1       :0] REQ,
                            input  wire                           PASS_DONE,
                            input  wire                           FINAL_PASS,
                            input  wire [W_LOG_LOG            :0] FINAL_READ_WAYLOG,
                            input  wire [NUMW-1               :0] SORTNUM,
                            input  wire                           DATA_INTO_SORTER,
                            input  wire                           DATA_STORED,
                            input  wire [DRAM_ADDRSPACE-1     :0] RMT_INIT_DATA,
                            input  wire                           RMT_INIT_EN,
                            /* An output port of the User logic interface of AVALON_MM_READ */
                            input  wire                           READ_REQUEST_RDY,
                            /* To input ports of the User logic interface of AVALON_MM_READ */
                            output wire                           READ_REQ,
                            output wire [DRAM_ADDRSPACE-1     :0] READ_INITADDR,
                            output wire [READNUM_SIZE         :0] READ_NUM,
                            // index to point which buffer in tree_filler stores read data
                            output wire [R_LOG-1              :0] READ_INDEX
                            );

  // Show in log scale how many read memory controllers are configured
  localparam M_LOG = ALLWAY_LOG - R_LOG;

  reg  [2:0]                                                                    read_state;
  reg                                                                           read_request;
  reg  [DRAM_ADDRSPACE-1                                                    :0] read_initaddr;
  reg  [R_LOG-1                                                             :0] read_index;
  reg  [READNUM_SIZE                                                        :0] read_datanum;
  reg  [(NUMW-(ELEMS_LOG_PER_ACCESS+PACK_LOG+M_LOG))-1                      :0] read_requestnum;
  reg  [(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))-1                 :0] read_requestnum_per_way;

  // reg and wire of a Block RAM based table for managing read pointers
  reg                                                                           rmt_we;
  reg  [R_LOG-1                                                             :0] rmt_raddr;
  reg  [R_LOG-1                                                             :0] rmt_waddr;
  reg  [1+(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE-1:0] rmt_din;
  wire [1+(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE-1:0] rmt_dot;
  reg  [R_LOG:  0]                                                              rmt_init_wadr;
  reg                                                                           rmt_initdone;

  // rmt_dot -- rmt_ptr_data
  //         |_ rmt_rcnt_data
  //         |_ rmt_rend_data
  wire [DRAM_ADDRSPACE-1:0]                                    rmt_ptr_data  = rmt_dot[DRAM_ADDRSPACE-1:0];
  wire [(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))-1:0] rmt_rcnt_data = rmt_dot[(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE-1:DRAM_ADDRSPACE];
  wire                                                         rmt_rend_data = rmt_dot[1+(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE-1];

  initial begin
    rmt_raddr = 0;
  end

  BRAM #(R_LOG, (1+(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE), USE_IPCORE)
  read_manage_table(CLK, rmt_we, rmt_raddr, rmt_waddr, rmt_din, rmt_dot);

  // set rmt_raddr
  always @(posedge CLK) begin
    case (read_state)
      1: begin
        rmt_raddr <= 0;
      end
      2: begin
        rmt_raddr <= rmt_raddr + 1;
      end
      4: begin
        rmt_raddr <= rmt_raddr + (1 << FINAL_READ_WAYLOG);
      end
    endcase
  end

  // shift register for Block RAM's latency
  integer p;
  reg  [2:0]       rmt_latency;
  reg  [R_LOG-1:0] rmt_ridx_buf [2:0];
  always @(posedge CLK) begin
    rmt_latency[0]  <= &{|read_state[2:1], ~read_state[0]};
    rmt_ridx_buf[0] <= rmt_raddr;
    for (p=1; p<3; p=p+1) begin
      rmt_latency[p]  <= rmt_latency[p-1];
      rmt_ridx_buf[p] <= rmt_ridx_buf[p-1];
    end
  end

  /* state machine for a read request controller */
  always @(posedge CLK) begin
    if (RST) begin
      read_state   <= 0;
      read_request <= 0;
    end else begin
      case (read_state)
        0: begin  // READ_REQUEST_CON_S activated
          read_state <= &{PASS_DONE, ~FINAL_PASS};
        end
        1: begin  // Initialize read_manage_table
          if (rmt_initdone) begin
            read_state <= (2 << FINAL_PASS);
          end
        end
        ////////// subsequent passes ///////////////////
        2: begin  // searching which way needs data and send read_request
          if (&{rmt_latency[2], REQ[rmt_ridx_buf[2]], ~rmt_rend_data}) begin
            read_state   <= 3;
            read_request <= 1;
          end
        end
        3: begin  // memory read is operating
          read_request <= 0;
          if (&{READ_REQUEST_RDY, ~|read_datanum}) begin
            read_state <= {1'b0, |read_requestnum, 1'b0};
          end
        end
        ////////// final pass //////////////////////////
        4: begin  // searching which ways of a portion need data and send read_request
          if (&{rmt_latency[2], REQ[rmt_ridx_buf[2]+(1<<FINAL_READ_WAYLOG)-1], ~rmt_rend_data}) begin
            read_state   <= 5;
            read_request <= 1;
          end
        end
        5: begin
          read_request <= 0;
          if (&{READ_REQUEST_RDY, ~|read_datanum}) begin
            read_state <= {|read_requestnum, 2'b00};
          end
        end
      endcase
    end
  end

  // set read_initaddr
  always @(posedge CLK) begin
    read_initaddr <= rmt_ptr_data;
  end

  // set read_requestnum
  always @(posedge CLK) begin
    if (read_state == 1) begin
      read_requestnum <= (FINAL_PASS) ? (SORTNUM >> (ELEMS_LOG_PER_ACCESS + FINAL_READ_WAYLOG + PACK_LOG + M_LOG)) : (SORTNUM >> (ELEMS_LOG_PER_ACCESS + PACK_LOG + M_LOG));
    end else begin
      if (read_request) read_requestnum <= read_requestnum - 1;
    end
  end

  // set read_index and read_datanum
  always @(posedge CLK) begin
    if (&{|read_state[2:1], ~read_state[0]}) begin
      read_index   <= rmt_ridx_buf[2];
      read_datanum <= (FINAL_PASS) ? (1 << (FINAL_READ_WAYLOG + PACK_LOG)) : (1 << PACK_LOG);
    end else begin
      if (DATA_INTO_SORTER) read_index   <= read_index + 1;
      if (DATA_STORED)      read_datanum <= read_datanum - (1 << PACK_LOG);
    end
  end

  // calculate stride_width
  reg [DRAM_ADDRSPACE-1:0] stride_width;
  always @(posedge CLK) begin
    stride_width <= (FINAL_PASS) ? ((DRAM_DATAWIDTH>>3) << (FINAL_READ_WAYLOG + PACK_LOG)) : ((DRAM_DATAWIDTH>>3) << PACK_LOG);
  end

  // flags to calculate how many read requests should be generated
  reg [(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))-1:0] rcnt_per_way;
  always @(posedge CLK) begin
    rcnt_per_way            <= rmt_rcnt_data;
    read_requestnum_per_way <= (SORTNUM >> (ALLWAY_LOG + ELEMS_LOG_PER_ACCESS + PACK_LOG));
  end

  // a control logic for updating read_manage_table
  always @(posedge CLK) begin
    if (RST) begin
      rmt_we        <= 0;
      rmt_init_wadr <= 0;
      rmt_initdone  <= 0;
    end else begin
      case (rmt_initdone)
        1'b0: begin
          rmt_we        <= RMT_INIT_EN;
          rmt_init_wadr <= (RMT_INIT_EN) ? rmt_init_wadr + 1 : rmt_init_wadr;
          rmt_initdone  <= rmt_init_wadr[R_LOG];
        end
        1'b1: begin
          rmt_we        <= read_request;
          rmt_init_wadr <= 0;
          rmt_initdone  <= ~PASS_DONE;
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    rmt_waddr                                                                                  <= (read_request) ? read_index                                      : rmt_init_wadr[R_LOG-1:0];
    rmt_din[DRAM_ADDRSPACE-1:0]                                                                <= (read_request) ? read_initaddr + stride_width                    : RMT_INIT_DATA;
    rmt_din[(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE-1:DRAM_ADDRSPACE] <= (read_request) ? rcnt_per_way + 1                                : 0;
    rmt_din[1+(NUMW-(ALLWAY_LOG+ELEMS_LOG_PER_ACCESS+PACK_LOG))+DRAM_ADDRSPACE-1]              <= (read_request) ? (rcnt_per_way == (read_requestnum_per_way - 1)) : 0;
  end

  assign READ_REQ      = read_request;
  assign READ_INITADDR = read_initaddr;
  assign READ_NUM      = read_datanum;
  assign READ_INDEX    = read_index;

endmodule

`default_nettype wire
