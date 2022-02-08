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

/*****  A FIFO with a single entry                                        *****/
/******************************************************************************/
module ONE_ENTRY_FIFO #(parameter                    FIFO_WIDTH = 64)  // fifo width in bit
                       (input  wire                  CLK,
                        input  wire                  RST,
                        input  wire                  enq,
                        input  wire                  deq,
                        input  wire [FIFO_WIDTH-1:0] din,
                        output reg  [FIFO_WIDTH-1:0] dot,
                        output wire                  emp,
                        output wire                  full);

  reg v;
  assign emp  = ~v;
  // assign full = &{v, ~deq};
  assign full =  v;

  initial begin
    dot = 0;
  end

  always @(posedge CLK) begin
    if (RST) begin
      v <= 0;
    end else begin
      casex ({enq, deq})
        2'b01: begin v <= 0; end
        2'b1x: begin v <= 1; end
      endcase
    end
  end
  always @(posedge CLK) begin
    if (enq) dot <= din;
  end

endmodule


/***** A FIFO with only two entries                                       *****/
/******************************************************************************/
module TWO_ENTRY_FIFO #(parameter                    FIFO_WIDTH = 64)  // fifo width in bit
                       (input  wire                  CLK,
                        input  wire                  RST,
                        input  wire                  enq,
                        input  wire                  deq,
                        input  wire [FIFO_WIDTH-1:0] din,
                        output wire [FIFO_WIDTH-1:0] dot,
                        output wire                  emp,
                        output wire                  full,
                        output reg  [1:0]            cnt);

  reg                  head, tail;
  reg [FIFO_WIDTH-1:0] mem [1:0];

  assign emp  = ~|cnt;
  assign full = cnt[1];
  assign dot  = mem[head];

  always @(posedge CLK) begin
    if (RST) {cnt, head, tail} <= 0;
    else begin
      case ({enq, deq})
        2'b01: begin
          head   <= ~head;
          cnt[1] <= 1'b0;
          cnt[0] <= cnt[1];
        end
        2'b10: begin
          tail   <= ~tail;
          cnt[1] <= cnt[0];
          cnt[0] <= ~cnt[0];
        end
        2'b11: begin
          head <= ~head;
          tail <= ~tail;
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    if (enq) mem[tail] <= din;
  end

endmodule


/***** A BlockRAM-based FIFO                                              *****/
/******************************************************************************/
module BFIFO #(parameter                    FIFO_SIZE  =  4,  // size in log scale, 4 for 16 entry
               parameter                    FIFO_WIDTH = 32,  // fifo width in bit
               parameter                    USE_IPCORE = "INTEL")
              (input  wire                  CLK,
               input  wire                  RST,
               input  wire                  enq,
               input  wire                  deq,
               input  wire [FIFO_WIDTH-1:0] din,
               output wire [FIFO_WIDTH-1:0] dot,
               output wire                  emp,
               output wire                  full,
               output reg  [FIFO_SIZE:0]    cnt);

  reg [FIFO_SIZE-1:0] head, tail;

  initial begin
    head = 0;
  end

  wire [FIFO_SIZE-1:0] raddr = head;
  wire [FIFO_SIZE-1:0] waddr = tail;

  BRAM #(FIFO_SIZE, FIFO_WIDTH, USE_IPCORE)
  bram(CLK, enq, raddr, waddr, din, dot);

  assign emp  = ~|cnt;
  assign full = cnt[FIFO_SIZE];

  always @(posedge CLK) begin
    if (RST) {cnt, head, tail} <= 0;
    else begin
      case ({enq, deq})
        2'b01: begin head<=head+1;               cnt<=cnt-1; end
        2'b10: begin               tail<=tail+1; cnt<=cnt+1; end
        2'b11: begin head<=head+1; tail<=tail+1;             end
      endcase
    end
  end

endmodule


/***** A Distributed RAM-based FIFO                                       *****/
/******************************************************************************/
module DFIFO #(parameter                    FIFO_SIZE  =  4,  // size in log scale, 4 for 16 entry
               parameter                    FIFO_WIDTH = 32)  // fifo width in bit
              (input  wire                  CLK,
               input  wire                  RST,
               input  wire                  enq,
               input  wire                  deq,
               input  wire [FIFO_WIDTH-1:0] din,
               output wire [FIFO_WIDTH-1:0] dot,
               output wire                  emp,
               output wire                  full,
               output reg  [FIFO_SIZE:0]    cnt);

  reg [FIFO_SIZE-1:0]  head, tail;
  reg [FIFO_WIDTH-1:0] mem [(1<<FIFO_SIZE)-1:0];

  assign emp  = ~|cnt;
  assign full = cnt[FIFO_SIZE];
  assign dot  = mem[head];

  always @(posedge CLK) begin
    if (RST) {cnt, head, tail} <= 0;
    else begin
      case ({enq, deq})
        2'b01: begin head<=head+1;               cnt<=cnt-1; end
        2'b10: begin               tail<=tail+1; cnt<=cnt+1; end
        2'b11: begin head<=head+1; tail<=tail+1;             end
      endcase
    end
  end
  always @(posedge CLK) begin
    if (enq) mem[tail] <= din;
  end

endmodule


/***** An SRL(Shift Register LUT)-based FIFO                              *****/
/******************************************************************************/
module SRL_FIFO #(parameter                    FIFO_SIZE  = 4,   // size in log scale, 4 for 16 entry
                  parameter                    FIFO_WIDTH = 32)  // fifo width in bit
                 (input  wire                  CLK,
                  input  wire                  RST,
                  input  wire                  enq,
                  input  wire                  deq,
                  input  wire [FIFO_WIDTH-1:0] din,
                  output wire [FIFO_WIDTH-1:0] dot,
                  output wire                  emp,
                  output wire                  full,
                  output reg  [FIFO_SIZE:0]    cnt);

  reg  [FIFO_SIZE-1:0]  head;
  reg  [FIFO_WIDTH-1:0] mem [(1<<FIFO_SIZE)-1:0];

  initial begin
    head = {(FIFO_SIZE){1'b1}};
  end

  assign emp  = ~|cnt;
  assign full = cnt[FIFO_SIZE];
  assign dot  = mem[head];

  always @(posedge CLK) begin
    if (RST) begin
      cnt  <= 0;
      head <= {(FIFO_SIZE){1'b1}};
    end else begin
      case ({enq, deq})
        2'b01: begin cnt <= cnt - 1; head <= head - 1; end
        2'b10: begin cnt <= cnt + 1; head <= head + 1; end
      endcase
    end
  end

  integer i;
  always @(posedge CLK) begin
    if (enq) begin
      mem[0] <= din;
      for (i=1; i<(1<<FIFO_SIZE); i=i+1) mem[i] <= mem[i-1];
    end
  end

endmodule


/***** A BFIFO with Show-ahead mode                                       *****/
/******************************************************************************/
module BS_FIFO #(parameter                    FIFO_SIZE  =  4,  // size in log scale, 4 for 16 entry
                 parameter                    FIFO_WIDTH = 32,  // fifo width in bit
                 parameter                    USE_IPCORE = "INTEL")
                (input  wire                  CLK,
                 input  wire                  RST,
                 input  wire                  enq,
                 input  wire                  deq,
                 input  wire [FIFO_WIDTH-1:0] din,
                 output wire [FIFO_WIDTH-1:0] dot,
                 output wire                  emp,
                 output wire                  full,
                 output reg  [FIFO_SIZE:0]    cnt);

  wire                  ibuf_enq;
  wire                  ibuf_deq;
  wire [FIFO_WIDTH-1:0] ibuf_din;
  wire [FIFO_WIDTH-1:0] ibuf_dot;
  wire                  ibuf_emp;
  wire                  ibuf_ful;
  wire [FIFO_SIZE:0]    ibuf_cnt;

  wire                  obuf_enq;
  wire                  obuf_deq;
  wire [FIFO_WIDTH-1:0] obuf_din;
  wire [FIFO_WIDTH-1:0] obuf_dot;
  wire                  obuf_emp;
  wire                  obuf_ful;
  wire [3:0]            obuf_cnt;


  integer               p;
  reg  [2:0]            valid;

  assign ibuf_enq = enq;
  assign ibuf_deq = ~|{(obuf_cnt > 4), ibuf_emp};
  assign ibuf_din = din;

  assign obuf_enq = valid[2];
  assign obuf_deq = deq;
  assign obuf_din = ibuf_dot;

  always @(posedge CLK) begin
    if (RST) begin
      valid <= 0;
    end else begin
      valid[0] <= ibuf_deq;
      for (p=1; p<3; p=p+1) begin
        valid[p] <= valid[p-1];
      end
    end
  end

  always @(posedge CLK) begin
    if (RST) cnt <= 0;
    else begin
      case ({enq, deq})
        2'b01: cnt <= cnt - 1;
        2'b10: cnt <= cnt + 1;
      endcase
    end
  end

  BFIFO #(FIFO_SIZE, FIFO_WIDTH, USE_IPCORE)
  ibuf(CLK, RST, ibuf_enq, ibuf_deq, ibuf_din,
       ibuf_dot, ibuf_emp, ibuf_ful, ibuf_cnt);

  SRL_FIFO #(3, FIFO_WIDTH)
  obuf(CLK, RST, obuf_enq, obuf_deq, obuf_din,
       obuf_dot, obuf_emp, obuf_ful, obuf_cnt);

  assign dot  = obuf_dot;
  assign emp  = obuf_emp;
  assign full = cnt[FIFO_SIZE];

endmodule


/*****  The ram layer's FIFO                                              *****/
/******************************************************************************/
module RAM_LAYER_FIFO #(parameter                    C_LOG      = 2,  // # of channels in log scale
                        parameter                    FIFO_WIDTH = 32,
                        parameter                    USE_IPCORE = "INTEL")
                       (input  wire                  CLK,
                        input  wire                  RST,
                        input  wire                  enq,
                        input  wire [C_LOG-1:0]      enq_idx,
                        input  wire                  deq,
                        input  wire [C_LOG-1:0]      deq_idx,
                        input  wire [C_LOG-1:0]      req_idx,
                        input  wire [FIFO_WIDTH-1:0] din,
                        output wire [FIFO_WIDTH-1:0] dot,
                        output wire [(1<<C_LOG)-1:0] emp,
                        output wire [(1<<C_LOG)-1:0] full);

  wire [C_LOG-1:0] raddr = req_idx;
  wire [C_LOG-1:0] waddr = enq_idx;

  BRAM #(C_LOG, FIFO_WIDTH, USE_IPCORE)
  bram(CLK, enq, raddr, waddr, din, dot);

  reg [(1<<C_LOG)-1:0] v;

  always @(posedge CLK) begin
    if (RST) begin
      v <= 0;
    end else begin
      case ({enq, deq})
        2'b01: begin v[deq_idx] <= 0;                  end
        2'b10: begin                  v[enq_idx] <= 1; end
        2'b11: begin v[deq_idx] <= 0; v[enq_idx] <= 1; end
      endcase
    end
  end

  // Output
  assign emp  = ~v;
  assign full =  v;

endmodule


/*****  A multi-channel FIFO with one entry                               *****/
/******************************************************************************/
module MULTI_CHANNEL_ONEENTRY_FIFO #(parameter                    C_LOG      = 2,  // # of channels in log scale
                                     parameter                    FIFO_WIDTH = 32,
                                     parameter                    USE_IPCORE = "INTEL")
                                    (input  wire                  CLK,
                                     input  wire                  RST,
                                     input  wire                  enq,
                                     input  wire [C_LOG-1:0]      enq_idx,
                                     input  wire                  deq,
                                     input  wire [C_LOG-1:0]      deq_idx,
                                     input  wire [FIFO_WIDTH-1:0] din,
                                     output wire [FIFO_WIDTH-1:0] dot,
                                     output wire [(1<<C_LOG)-1:0] emp,
                                     output wire [(1<<C_LOG)-1:0] full);

  wire [C_LOG-1:0] raddr = deq_idx;
  wire [C_LOG-1:0] waddr = enq_idx;

  BRAM #(C_LOG, FIFO_WIDTH, USE_IPCORE)
  bram(CLK, enq, raddr, waddr, din, dot);

  reg [(1<<C_LOG)-1:0] v;

  always @(posedge CLK) begin
    if (RST) begin
      v <= 0;
    end else begin
      case ({enq, deq})
        2'b01: begin v[deq_idx] <= 0;                  end
        2'b10: begin                  v[enq_idx] <= 1; end
        2'b11: begin v[deq_idx] <= 0; v[enq_idx] <= 1; end
      endcase
    end
  end

  // Output
  assign emp  = ~v;
  assign full =  v;

endmodule


/*****  A multi-channel FIFO with two entries                             *****/
/******************************************************************************/
module MULTI_CHANNEL_TWOENTRY_FIFO #(parameter                    C_LOG      = 2,  // # of channels in log scale
                                     parameter                    FIFO_WIDTH = 32,
                                     parameter                    USE_IPCORE = "INTEL")
                                    (input  wire                  CLK,
                                     input  wire                  RST,
                                     input  wire                  enq,
                                     input  wire [C_LOG-1     :0] enq_idx,
                                     input  wire                  deq,
                                     input  wire [C_LOG-1     :0] deq_idx,
                                     input  wire [FIFO_WIDTH-1:0] din,
                                     output wire [FIFO_WIDTH-1:0] dot,
                                     output reg  [(1<<C_LOG)-1:0] emp,
                                     output reg  [(1<<C_LOG)-1:0] rdy);

  wire                   head_enq;
  wire [C_LOG-1      :0] head_enq_idx;
  wire                   head_deq;
  wire [C_LOG-1      :0] head_deq_idx;
  wire [FIFO_WIDTH-1 :0] head_din;
  wire [FIFO_WIDTH-1 :0] head_dot;
  wire [(1<<C_LOG)-1 :0] head_emp;
  wire [(1<<C_LOG)-1 :0] head_ful;

  wire                   tail_enq;
  wire [C_LOG-1      :0] tail_enq_idx;
  wire                   tail_deq;
  wire [C_LOG-1      :0] tail_deq_idx;
  wire [FIFO_WIDTH-1 :0] tail_din;
  wire [FIFO_WIDTH-1 :0] tail_dot;
  wire [(1<<C_LOG)-1 :0] tail_emp;
  wire [(1<<C_LOG)-1 :0] tail_ful;

  integer                p;
  reg [3:0]              valid;
  reg [C_LOG-1      :0]  idx [3:0];
  reg [C_LOG-1      :0]  round_robin_sel;

  assign head_enq     = valid[3];
  assign head_enq_idx = idx[3];
  assign head_deq     = deq;
  assign head_deq_idx = deq_idx;
  assign head_din     = tail_dot;

  assign tail_enq     = enq;
  assign tail_enq_idx = enq_idx;
  assign tail_deq     = valid[0];
  assign tail_deq_idx = idx[0];
  assign tail_din     = din;

  MULTI_CHANNEL_ONEENTRY_FIFO #(C_LOG, FIFO_WIDTH, USE_IPCORE)
  head(CLK, RST, head_enq, head_enq_idx, head_deq, head_deq_idx, head_din,
       head_dot, head_emp, head_ful);
  MULTI_CHANNEL_ONEENTRY_FIFO #(C_LOG, FIFO_WIDTH, USE_IPCORE)
  tail(CLK, RST, tail_enq, tail_enq_idx, tail_deq, tail_deq_idx, tail_din,
       tail_dot, tail_emp, tail_ful);

  always @(posedge CLK) begin
    round_robin_sel <= (RST) ? 0 : round_robin_sel + 1;
  end
  always @(posedge CLK) begin
    if (RST) begin
      valid <= 0;
    end else begin
      valid[0] <= ~|{head_ful[round_robin_sel], tail_emp[round_robin_sel]};
      for (p=1; p<4; p=p+1) begin
        valid[p] <= valid[p-1];
      end
    end
  end
  always @(posedge CLK) begin
    idx[0] <= round_robin_sel;
    for (p=1; p<4; p=p+1) begin
      idx[p] <= idx[p-1];
    end
  end

  // Output
  assign dot = head_dot;

  always @(posedge CLK) emp  <= tail_emp;
  always @(posedge CLK) rdy  <= head_ful;

endmodule

`default_nettype wire
