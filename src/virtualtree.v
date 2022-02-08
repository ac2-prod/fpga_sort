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

/*****  A Block RAM-based buffer layer                                    *****/
/******************************************************************************/
module RAM_LAYER #(parameter                    W_LOG      = 2,
                   parameter                    BOTTOM     = 1,
                   parameter                    P_LOG      = 3,
                   parameter                    USE_IPCORE = "INTEL",
                   parameter                    FLOAT      = "no",
                   parameter                    SIGNED     = "no",
                   parameter                    DATW       = 64,
                   parameter                    KEYW       = 32)
                  (input  wire                  CLK,
                   input  wire                  RST,
                   input  wire                  QUEUE_IN_FULL,
                   input  wire                  ENQ,
                   input  wire [W_LOG-1     :0] ENQ_IDX,
                   input  wire                  REQ,
                   input  wire [(W_LOG-1)-1 :0] REQ_IDX,
                   output wire                  O_DEQ,
                   input  wire [(DATW<<P_LOG)-1:0] DIN,
                   output wire [(DATW<<P_LOG)-1:0] DOT,
                   output wire [(W_LOG-1)-1 :0] O_IDX,
                   input  wire                  FDR_ENQ,
                   input  wire [(W_LOG-1)-1 :0] FDR_IDX,
                   input  wire [(DATW<<P_LOG)-1:0] FDR_DIN,
                   output wire [(DATW<<P_LOG)-1:0] FDR_DOT,
                   output wire                  FDR_INIT_EJECTED,
                   output wire                  DATA_VALID,
                   output wire [W_LOG-1     :0] O_REQUEST,
                   output wire                  O_REQUEST_VALID);

  localparam [63:0] FIFO_WIDTH = (DATW<<P_LOG);
  localparam [63:0] PAYW       = DATW - KEYW;

  wire [FIFO_WIDTH-1:0] init_dummy_data;

  genvar i;
  generate
    for (i=0; i<(1<<P_LOG); i=i+1) begin: setdata
      if (FLOAT == "yes" || SIGNED == "yes") begin
        localparam [KEYW-1:0] MIN_KEY = {1'b1, {(KEYW-1){1'b0}}};
        if (PAYW == 0) begin
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = MIN_KEY;
        end else begin
          localparam [PAYW-1:0] DUMMY_PAYLOAD = {(PAYW){1'b1}};
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = {DUMMY_PAYLOAD, MIN_KEY};
        end
      end else begin
        localparam [KEYW-1:0] MIN_KEY = {(KEYW){1'b0}};
        if (PAYW == 0) begin
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = MIN_KEY;
        end else begin
          localparam [PAYW-1:0] DUMMY_PAYLOAD = {(PAYW){1'b1}};
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = {DUMMY_PAYLOAD, MIN_KEY};
        end
      end
    end
  endgenerate

  function [FIFO_WIDTH-1:0] mux;
    input [FIFO_WIDTH-1:0] in0;
    input [FIFO_WIDTH-1:0] in1;
    input                  sel;
    begin
      case (sel)
        1'b0: mux = in0;
        1'b1: mux = in1;
      endcase
    end
  endfunction

  function [W_LOG-1:0] sel_req_gen;
    input [(W_LOG-1)-1:0] in;
    input [          1:0] sel;
    begin
      case (sel)
        2'b01: sel_req_gen = {in, 1'b0};
        2'b10: sel_req_gen = {in, 1'b1};
        default: sel_req_gen = 0;
      endcase
    end
  endfunction

  // Input Buffer
  reg even_enq;
  reg odd_enq;
  always @(posedge CLK) begin
    if (RST) begin
      even_enq <= 0;
      odd_enq  <= 0;
    end else begin
      even_enq <= &{ENQ, ~ENQ_IDX[0]};
      odd_enq  <= &{ENQ,  ENQ_IDX[0]};
    end
  end

  reg [(W_LOG-1)-1 :0] enq_idx;
  reg [FIFO_WIDTH-1:0] din;
  always @(posedge CLK) begin
    enq_idx <= ENQ_IDX[W_LOG-1:1];
    din     <= DIN;
  end

  wire                      even_deq, odd_deq;
  wire [(W_LOG-1)-1     :0] deq_idx;
  reg  [(W_LOG-1)-1     :0] req_idx;
  wire [FIFO_WIDTH-1    :0] even_dot, odd_dot;
  wire [(1<<(W_LOG-1))-1:0] even_emp, odd_emp;
  wire [(1<<(W_LOG-1))-1:0] even_full, odd_full;

  reg                       fdr_enq;
  reg  [(W_LOG-1)-1     :0] fdr_enq_idx;
  reg                       fdr_deq;
  reg  [(W_LOG-1)-1     :0] fdr_deq_idx;
  reg  [FIFO_WIDTH-1    :0] fdr_din;
  wire [FIFO_WIDTH-1    :0] fdr_dot;
  wire [(1<<(W_LOG-1))-1:0] fdr_emp;
  wire [(1<<(W_LOG-1))-1:0] fdr_ful;

  reg  [(W_LOG-1)       :0] fdr_init_idx;
  reg                       fdr_init_done;
  reg                       fdr_init_ejected;

  // registers for state machine
  reg                       req_deq_st;
  reg  [2:0]                req_gen_st;
  reg                       emp0;
  reg                       emp1;
  reg                       fdr_emp_buf;
  reg                       emp0_request;
  reg                       emp1_request;
  reg  [W_LOG-1         :0] request;
  reg                       request_valid;
  reg                       eject_request;
  reg [(1<<(W_LOG-1))-1 :0] init_ejected_done;

  // BlockRAM's latency: 3 clocks
  reg  [2:0]                valid;
  integer                   p;

  // registers for ram_layer -> comparator
  reg  [FIFO_WIDTH-1    :0] even_dot_buf;
  reg  [FIFO_WIDTH-1    :0] odd_dot_buf;
  reg  [FIFO_WIDTH-1    :0] fdr_dot_buf;
  reg                       comp_rslt;
  reg                       buf_valid;

  // registers for comparator -> mux
  reg  [FIFO_WIDTH-1    :0] dot_selected;
  reg  [FIFO_WIDTH-1    :0] dot_feedback;
  reg                       doten;
  reg                       deq0;
  reg                       deq1;

  // shifted idx: 5 clocks
  reg  [(W_LOG-1)-1     :0] s_idx [4:0];

  assign even_deq = deq0;
  assign odd_deq  = deq1;
  assign deq_idx  = s_idx[4];

  initial begin
    s_idx[0]    = 0;
    s_idx[1]    = 0;
    s_idx[2]    = 0;
    s_idx[3]    = 0;
    s_idx[4]    = 0;
    req_idx     = 0;
    fdr_deq_idx = 0;
  end

  RAM_LAYER_FIFO #((W_LOG-1), FIFO_WIDTH, USE_IPCORE)
  even_numbered_fifo(CLK, RST, even_enq, enq_idx, even_deq, deq_idx, req_idx, din,
                     even_dot, even_emp, even_full);
  RAM_LAYER_FIFO #((W_LOG-1), FIFO_WIDTH, USE_IPCORE)
  odd_numbered_fifo(CLK, RST, odd_enq, enq_idx, odd_deq, deq_idx, req_idx, din,
                    odd_dot, odd_emp, odd_full);
  MULTI_CHANNEL_ONEENTRY_FIFO #((W_LOG-1), FIFO_WIDTH, USE_IPCORE)
  feedback_data_ram(CLK, RST, fdr_enq, fdr_enq_idx, fdr_deq, fdr_deq_idx, fdr_din,
                    fdr_dot, fdr_emp, fdr_ful);

  always @(posedge CLK) begin
    fdr_enq       <= (RST) ? 0 : |{FDR_ENQ, ~fdr_init_idx[(W_LOG-1)]};
    fdr_init_idx  <= (RST) ? 0 : fdr_init_idx + {{(W_LOG-1){1'b0}}, ~|{fdr_init_done, FDR_ENQ}};
    fdr_init_done <= (RST) ? 0 : fdr_init_idx[(W_LOG-1)];
  end
  always @(posedge CLK) begin
    fdr_enq_idx <= (FDR_ENQ) ? FDR_IDX : fdr_init_idx[(W_LOG-1)-1:0];
    fdr_din     <= (FDR_ENQ) ? FDR_DIN : init_dummy_data;  // init_dummy_data is for ejecting the first record
  end
  always @(posedge CLK) begin
    fdr_deq_idx <= req_idx;
  end

  always @(posedge CLK) begin
    req_idx     <= REQ_IDX;
    emp0        <= even_emp[REQ_IDX];
    emp1        <= odd_emp[REQ_IDX];
    fdr_emp_buf <= fdr_emp[REQ_IDX];
  end

  always @(posedge CLK) begin
    if (RST) begin
      req_deq_st <= 0;
      fdr_deq    <= 0;
    end else begin
      case (req_deq_st)
        0: begin
          req_deq_st <= &{REQ, ~fdr_deq};
          fdr_deq    <= 0;
        end
        1: begin
          req_deq_st <= |{fdr_emp_buf, emp1, emp0};
          fdr_deq    <= ~|{fdr_emp_buf, emp1, emp0};
        end
      endcase
    end
  end

  always @(posedge CLK) begin
    if (RST) begin
      req_gen_st    <= 0;
      emp0_request  <= 0;
      emp1_request  <= 0;
      request_valid <= 0;
      eject_request <= 0;
    end else begin
      case (req_gen_st)
        0: begin
          request_valid <= 0;
          if (&{REQ, ~request_valid}) begin
            // (init_ejected_done[REQ_IDX]) ? 3 : 1;
            req_gen_st <= {init_ejected_done[(1<<(W_LOG-1))-1], init_ejected_done[REQ_IDX], 1'b1};
          end
        end
        1: begin
          req_gen_st    <= {2'b01, ~|{emp1, emp0}};
          request_valid <= |{emp1, emp0};
          eject_request <= 1;
          casex ({emp1, emp0})
            2'bx1: begin
              request      <= {req_idx, 1'b0};
              emp0_request <= 1;
            end
            2'b10: begin
              request      <= {req_idx, 1'b1};
              emp1_request <= 1;
            end
          endcase
        end
        2: begin
          request_valid <= (BOTTOM) ? 0 : ~|{QUEUE_IN_FULL, request_valid, eject_request};
          case ({emp1_request, emp0_request})
            2'b00: begin req_gen_st   <= 1;    end
            2'b01: begin emp0_request <= emp0; end
            2'b10: begin emp1_request <= emp1; end
          endcase
          if (request_valid) begin
            eject_request <= ~eject_request;
          end
        end
        3: begin
          req_gen_st    <= {1'b0, {(2){~doten}}};
          request       <= sel_req_gen(deq_idx, {deq1, deq0});
          request_valid <= doten;
        end
        default: begin
          request       <= sel_req_gen(deq_idx, {deq1, deq0});
          request_valid <= doten;
        end
      endcase
    end
  end

  // BlockRAM's latency: 3 clocks
  ///////////////////////////
  always @(posedge CLK) begin
    if (RST) begin
      valid <= 0;
    end else begin
      valid[0] <= fdr_deq;
      for (p=1; p<3; p=p+1) begin
        valid[p] <= valid[p-1];
      end
    end
  end

  // ram_layer -> comparator
  ///////////////////////////
  wire comparator_rslt;
  COMPARATOR #(FLOAT, SIGNED, KEYW)
  comparator(even_dot[KEYW-1:0], odd_dot[KEYW-1:0], comparator_rslt);

  always @(posedge CLK) begin
    even_dot_buf <= even_dot;
    odd_dot_buf  <= odd_dot;
    fdr_dot_buf  <= fdr_dot;
    comp_rslt    <= comparator_rslt;
  end
  always @(posedge CLK) begin
    buf_valid <= (RST) ? 0 : valid[2];
  end

  // comparator -> mux
  ///////////////////////////
  always @(posedge CLK) begin
    dot_selected <= mux(odd_dot_buf, even_dot_buf, comp_rslt);
    dot_feedback <= fdr_dot_buf;
  end
  always @(posedge CLK) begin
    if (RST) begin
      doten <= 0;
      deq0  <= 0;
      deq1  <= 0;
    end else begin
      doten <= buf_valid;
      deq0  <= &{buf_valid,  comp_rslt};
      deq1  <= &{buf_valid, ~comp_rslt};
    end
  end

  // shifted idx: 5 clocks
  ///////////////////////////
  always @(posedge CLK) begin
    s_idx[0] <= fdr_deq_idx;
    for (p=1; p<5; p=p+1) begin
      s_idx[p] <= s_idx[p-1];
    end
  end

  // Output
  always @(posedge CLK) begin
    if      (RST)   init_ejected_done          <= 0;
    else if (doten) init_ejected_done[deq_idx] <= 1;
  end
  always @(posedge CLK) begin
    fdr_init_ejected <= (RST) ? 0 : init_ejected_done[deq_idx];
  end

  assign O_DEQ            = fdr_deq;
  assign DOT              = dot_selected;
  assign O_IDX            = deq_idx;
  assign FDR_DOT          = dot_feedback;
  assign FDR_INIT_EJECTED = fdr_init_ejected;
  assign DATA_VALID       = doten;
  assign O_REQUEST        = request;
  assign O_REQUEST_VALID  = request_valid;

endmodule


/*****  A body of the sorter stage                                        *****/
/******************************************************************************/
module SORTER_STAGE_BODY #(parameter                       W_LOG     = 2,
                           parameter                       BOTTOM    = 1,
                           parameter                       P_LOG     = 3,
                           parameter                       USE_IPCORE = "INTEL",
                           parameter                       FLOAT      = "no",
                           parameter                       SIGNED     = "no",
                           parameter                       DATW      = 64,
                           parameter                       KEYW      = 32)
                          (input  wire                     CLK,
                           input  wire                     RST,
                           input  wire                     QUEUE_IN_FULL,
                           input  wire [(W_LOG-1)-1    :0] I_REQUEST,
                           input  wire                     I_REQUEST_VALID,
                           input  wire [(DATW<<P_LOG)-1:0] DIN,
                           input  wire                     DINEN,
                           input  wire [W_LOG-1        :0] DIN_IDX,
                           output wire                     QUEUE_FULL,
                           output wire [W_LOG-1        :0] O_REQUEST,
                           output wire                     O_REQUEST_VALID,
                           output wire [(DATW<<P_LOG)-1:0] DOT,
                           output wire                     DOTEN,
                           output wire [(W_LOG-1)-1    :0] DOT_IDX);

  wire                         queue_enq;
  wire                         queue_deq;
  wire [(W_LOG-1)-1        :0] queue_din;
  wire [(W_LOG-1)-1        :0] queue_dot;
  wire                         queue_emp;
  wire                         queue_ful;

  wire                         ram_layer_enq;
  wire [W_LOG-1            :0] ram_layer_enq_idx;
  wire                         ram_layer_req;
  wire [(W_LOG-1)-1        :0] ram_layer_req_idx;
  wire                         ram_layer_o_deq;
  wire [(DATW<<P_LOG)-1    :0] ram_layer_din;
  wire [(DATW<<P_LOG)-1    :0] ram_layer_dot;
  wire [(W_LOG-1)-1        :0] ram_layer_o_idx;
  wire                         ram_layer_fdr_enq;
  wire [(W_LOG-1)-1        :0] ram_layer_fdr_idx;
  wire [(DATW<<P_LOG)-1    :0] ram_layer_fdr_din;
  wire [(DATW<<P_LOG)-1    :0] ram_layer_fdr_dot;
  wire                         ram_layer_fdr_init_ejected;
  wire                         ram_layer_data_valid;
  wire [W_LOG-1            :0] ram_layer_o_request;
  wire                         ram_layer_o_request_valid;

  wire [(DATW<<(P_LOG+1))-1:0] boem_din;
  wire [(DATW<<(P_LOG+1))-1:0] boem_dot;

  // registers for BOEM
  integer                      p;
  reg [(W_LOG-1)-1         :0] sbuf          [((P_LOG+1)<<1)-1:0];  // '<<1' is because of two-stage CAS
  reg [1                   :0] valid_shifted [((P_LOG+1)<<1)-1:0];  // [1]: fdr_enq's flag [0]: boem_dot's flag

  assign queue_enq         = I_REQUEST_VALID;
  assign queue_deq         = ram_layer_o_deq;
  assign queue_din         = I_REQUEST;

  assign ram_layer_enq     = DINEN;
  assign ram_layer_enq_idx = DIN_IDX;
  assign ram_layer_req     = ~|{QUEUE_IN_FULL, queue_emp};
  assign ram_layer_req_idx = queue_dot;
  assign ram_layer_din     = DIN;
  assign ram_layer_fdr_enq = valid_shifted[((P_LOG+1)<<1)-1][1];
  assign ram_layer_fdr_idx = sbuf[((P_LOG+1)<<1)-1];
  assign ram_layer_fdr_din = boem_dot[(DATW<<(P_LOG+1))-1:(DATW<<P_LOG)];

  assign boem_din          = {ram_layer_dot, ram_layer_fdr_dot};

  ONE_ENTRY_FIFO #(W_LOG-1)
  request_queue(CLK, RST, queue_enq, queue_deq, queue_din,
                queue_dot, queue_emp, queue_ful);

  RAM_LAYER #(W_LOG, BOTTOM, P_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
  ram_layer(
            CLK,
            RST,
            QUEUE_IN_FULL,
            ram_layer_enq,
            ram_layer_enq_idx,
            ram_layer_req,
            ram_layer_req_idx,
            ram_layer_o_deq,
            ram_layer_din,
            ram_layer_dot,
            ram_layer_o_idx,
            ram_layer_fdr_enq,
            ram_layer_fdr_idx,
            ram_layer_fdr_din,
            ram_layer_fdr_dot,
            ram_layer_fdr_init_ejected,
            ram_layer_data_valid,
            ram_layer_o_request,
            ram_layer_o_request_valid
            );

  // a merge network (latency: (P_LOG+1)<<1)
  ///////////////////////////
  BOEM #(P_LOG+1, FLOAT, SIGNED, DATW, KEYW)
  boem(CLK, boem_din, boem_dot);

  always @(posedge CLK) begin
    sbuf[0] <= ram_layer_o_idx;
    for (p=1; p<((P_LOG+1)<<1); p=p+1) sbuf[p] <= sbuf[p-1];
  end
  always @(posedge CLK) begin
    if (RST) begin
      for (p=0; p<((P_LOG+1)<<1); p=p+1) begin
        valid_shifted[p] <= 0;
      end
    end else begin
      valid_shifted[0] <= {ram_layer_data_valid, &{ram_layer_data_valid, ram_layer_fdr_init_ejected}};
      for (p=1; p<((P_LOG+1)<<1); p=p+1) begin
        valid_shifted[p] <= valid_shifted[p-1];
      end
    end
  end

  // Output
  //////////////////////////////////////////////////////////
  assign QUEUE_FULL      = queue_ful;
  assign O_REQUEST       = ram_layer_o_request;
  assign O_REQUEST_VALID = ram_layer_o_request_valid;
  assign DOT             = boem_dot[(DATW<<P_LOG)-1:0];
  assign DOTEN           = valid_shifted[((P_LOG+1)<<1)-1][0];
  assign DOT_IDX         = sbuf[((P_LOG+1)<<1)-1];

endmodule


/*****  A root of the sorter stage                                        *****/
/******************************************************************************/
module SORTER_STAGE_ROOT #(parameter                       P_LOG = 3,
                           parameter                       USE_IPCORE = "INTEL",
                           parameter                       FLOAT      = "no",
                           parameter                       SIGNED     = "no",
                           parameter                       DATW  = 64,
                           parameter                       KEYW  = 32)
                          (input  wire                     CLK,
                           input  wire                     RST,
                           input  wire                     QUEUE_IN_FULL,
                           input  wire                     IN_FULL,
                           input  wire [(DATW<<P_LOG)-1:0] DIN,
                           input  wire                     DINEN,
                           input  wire                     DIN_IDX,
                           output wire                     O_REQUEST,
                           output wire                     O_REQUEST_VALID,
                           output wire [DATW-1         :0] DOT,
                           output wire                     DOTEN);

  localparam PAYW = DATW - KEYW;

  wire [(DATW<<P_LOG)-1:0] init_dummy_data;

  genvar i;
  generate
    for (i=0; i<(1<<P_LOG); i=i+1) begin: setdata
      if (FLOAT == "yes" || SIGNED == "yes") begin
        localparam [KEYW-1:0] MIN_KEY = {1'b1, {(KEYW-1){1'b0}}};
        if (PAYW == 0) begin
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = MIN_KEY;
        end else begin
          localparam [PAYW-1:0] DUMMY_PAYLOAD = {(PAYW){1'b1}};
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = {DUMMY_PAYLOAD, MIN_KEY};
        end
      end else begin
        localparam [KEYW-1:0] MIN_KEY = {(KEYW){1'b0}};
        if (PAYW == 0) begin
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = MIN_KEY;
        end else begin
          localparam [PAYW-1:0] DUMMY_PAYLOAD = {(PAYW){1'b1}};
          assign init_dummy_data[DATW*(i+1)-1:DATW*i] = {DUMMY_PAYLOAD, MIN_KEY};
        end
      end
    end
  endgenerate

  function [(DATW<<P_LOG)-1:0] mux;
    input [(DATW<<P_LOG)-1:0] in0;
    input [(DATW<<P_LOG)-1:0] in1;
    input                     sel;
    begin
      case (sel)
        1'b0: mux = in0;
        1'b1: mux = in1;
      endcase
    end
  endfunction

  function sel_req_gen;
    input [1:0] sel;
    begin
      case (sel)
        2'b01: sel_req_gen = 1'b0;
        2'b10: sel_req_gen = 1'b1;
        default: sel_req_gen = 0;
      endcase
    end
  endfunction

  reg [(DATW<<P_LOG)-1:0] din_0;
  reg                     enq_0;
  reg [(DATW<<P_LOG)-1:0] din_1;
  reg                     enq_1;
  always @(posedge CLK) begin
    din_0 <= DIN;
    din_1 <= DIN;
  end
  always @(posedge CLK) begin
    if (RST) begin
      enq_0 <= 0;
      enq_1 <= 0;
    end else begin
      enq_0 <= &{DINEN, ~DIN_IDX};
      enq_1 <= &{DINEN,  DIN_IDX};
    end
  end

  wire                         fifo_0_enq, fifo_1_enq;
  wire                         fifo_0_deq, fifo_1_deq;
  wire [(DATW<<P_LOG)-1    :0] fifo_0_din, fifo_1_din;
  wire [(DATW<<P_LOG)-1    :0] fifo_0_dot, fifo_1_dot;
  wire                         fifo_0_emp, fifo_1_emp;
  wire                         fifo_0_ful, fifo_1_ful;

  reg                          fdr_enq;
  reg                          fdr_deq;
  reg  [(DATW<<P_LOG)-1    :0] fdr_din;
  wire [(DATW<<P_LOG)-1:    0] fdr_dot;
  wire                         fdr_emp;
  wire                         fdr_ful;

  reg                          fdr_init_done;

  wire [(DATW<<(P_LOG+1))-1:0] boem_din;
  reg                          boem_dinen;
  wire [(DATW<<(P_LOG+1))-1:0] boem_dot;

  wire                         tmp_enq;
  wire                         tmp_deq;
  wire [(DATW<<P_LOG)-1    :0] tmp_din;
  wire [(DATW<<P_LOG)-1:    0] tmp_dot;
  wire                         tmp_emp;
  wire                         tmp_ful;

  wire                         obuf_enq;
  wire                         obuf_deq;
  wire [(DATW<<P_LOG)-1    :0] obuf_din;
  wire [(DATW<<P_LOG)-1    :0] obuf_dot;
  wire                         obuf_emp;
  wire                         obuf_ful;
  wire [1:0]                   obuf_cnt;

  wire [(DATW<<P_LOG)-1    :0] data_slicer_din;
  wire                         data_slicer_dinen;
  wire [DATW-1             :0] data_slicer_dot;
  wire                         data_slicer_doten;
  wire                         data_slicer_rdy;

  // registers for state machine
  reg  [1:0]                   state;
  reg                          emp0;
  reg                          emp1;
  reg                          fdr_emp_buf;
  reg                          request;
  reg                          request_valid;
  reg                          eject_request;

  // registers for ram_layer -> comparator
  reg  [(DATW<<P_LOG)-1    :0] fifo_0_dot_buf;
  reg  [(DATW<<P_LOG)-1    :0] fifo_1_dot_buf;
  reg  [(DATW<<P_LOG)-1    :0] fdr_dot_buf;
  reg                          comp_rslt;
  reg                          buf_valid;

  // registers for comparator -> mux
  reg  [(DATW<<P_LOG)-1    :0] boem_din_selected;
  reg  [(DATW<<P_LOG)-1    :0] boem_din_feedback;
  reg                          deq_0;
  reg                          deq_1;

  // registers for BOEM
  integer                      p;
  reg [1:0]                    valid_shifted [((P_LOG+1)<<1)-1:0];  // [1]: fdr_enq's flag [0]: boem_dot's flag
  reg                          init_record_ejected;

  // stall signal
  reg stall;
  always @(posedge CLK) stall <= obuf_ful;

  assign fifo_0_enq = enq_0;
  assign fifo_0_deq = deq_0;
  assign fifo_0_din = din_0;

  assign fifo_1_enq = enq_1;
  assign fifo_1_deq = deq_1;
  assign fifo_1_din = din_1;

  assign boem_din   = {boem_din_selected, boem_din_feedback};

  assign tmp_enq    = valid_shifted[((P_LOG+1)<<1)-1][0];
  assign tmp_deq    = ~|{obuf_ful, tmp_emp};
  assign tmp_din    = boem_dot[(DATW<<P_LOG)-1:0];

  assign obuf_enq   = tmp_deq;
  assign obuf_deq   = &{data_slicer_rdy, ~obuf_emp};
  assign obuf_din   = tmp_dot;

  assign data_slicer_din   = obuf_dot;
  assign data_slicer_dinen = obuf_deq;

  ONE_ENTRY_FIFO #((DATW<<P_LOG))
  fifo_0(CLK, RST, fifo_0_enq, fifo_0_deq, fifo_0_din,
         fifo_0_dot, fifo_0_emp, fifo_0_ful);
  ONE_ENTRY_FIFO #((DATW<<P_LOG))
  fifo_1(CLK, RST, fifo_1_enq, fifo_1_deq, fifo_1_din,
         fifo_1_dot, fifo_1_emp, fifo_1_ful);
  ONE_ENTRY_FIFO #((DATW<<P_LOG))
  feedback_data_ram(CLK, RST, fdr_enq, fdr_deq, fdr_din,
                    fdr_dot, fdr_emp, fdr_ful);

  always @(posedge CLK) begin
    fdr_init_done <= ~RST;
    fdr_enq       <= (RST) ? 0 : |{~fdr_init_done, valid_shifted[((P_LOG+1)<<1)-1][1]};
  end
  // init_dummy_data is for ejecting the first record
  always @(posedge CLK) begin
    fdr_din <= (fdr_init_done) ? boem_dot[(DATW<<(P_LOG+1))-1:(DATW<<P_LOG)] : init_dummy_data;
  end

  always @(posedge CLK) begin
    emp0        <= fifo_0_emp;
    emp1        <= fifo_1_emp;
    fdr_emp_buf <= fdr_emp;
  end

  always @(posedge CLK) begin
    if (RST) begin
      state         <= 0;
      request       <= 0;
      request_valid <= 0;
      eject_request <= 0;
      fdr_deq       <= 0;
    end else begin
      case (state)
        0: begin
          if (request_valid) begin
            eject_request <= ~eject_request;
          end
          if (&{eject_request, request_valid}) begin
            request <= ~request;
          end
          request_valid <= ~|{QUEUE_IN_FULL, request_valid};
          state         <= &{request, eject_request, request_valid};
        end
        1: begin
          request_valid <= 0;
          if (~|{QUEUE_IN_FULL, stall}) begin
            state <= 2;
          end
        end
        2: begin
          state   <= {1'b1, ~|{fdr_emp_buf, emp1, emp0}};
          fdr_deq <= ~|{fdr_emp_buf, emp1, emp0};
        end
        3: begin
          state         <= {~boem_dinen, 1'b1};
          fdr_deq       <= 0;
          request       <= sel_req_gen({deq_1, deq_0});
          request_valid <= boem_dinen;
        end
      endcase
    end
  end

  // ram_layer -> comparator
  ///////////////////////////
  wire comparator_rslt;
  COMPARATOR #(FLOAT, SIGNED, KEYW)
  comparator(fifo_0_dot[KEYW-1:0], fifo_1_dot[KEYW-1:0], comparator_rslt);

  always @(posedge CLK) begin
    fifo_0_dot_buf <= fifo_0_dot;
    fifo_1_dot_buf <= fifo_1_dot;
    fdr_dot_buf    <= fdr_dot;
    comp_rslt      <= comparator_rslt;
  end
  always @(posedge CLK) begin
    buf_valid <= (RST) ? 0 : fdr_deq;
  end

  // comparator -> mux
  ///////////////////////////
  always @(posedge CLK) begin
    boem_din_selected <= mux(fifo_1_dot_buf, fifo_0_dot_buf, comp_rslt);
    boem_din_feedback <= fdr_dot_buf;
  end
  always @(posedge CLK) begin
    if (RST) begin
      boem_dinen <= 0;
      deq_0      <= 0;
      deq_1      <= 0;
    end else begin
      boem_dinen <= buf_valid;
      deq_0      <= &{buf_valid,  comp_rslt};
      deq_1      <= &{buf_valid, ~comp_rslt};
    end
  end

  // a merge network (latency: (P_LOG+1)<<1)
  ///////////////////////////
  BOEM #(P_LOG+1, FLOAT, SIGNED, DATW, KEYW)
  boem(CLK, boem_din, boem_dot);

  always @(posedge CLK) begin
    if (RST) begin
      for (p=0; p<((P_LOG+1)<<1); p=p+1) begin
        valid_shifted[p] <= 0;
      end
    end else begin
      valid_shifted[0] <= {boem_dinen, &{boem_dinen, init_record_ejected}};
      for (p=1; p<((P_LOG+1)<<1); p=p+1) begin
        valid_shifted[p] <= valid_shifted[p-1];
      end
    end
  end
  always @(posedge CLK) begin
    if      (RST)        init_record_ejected <= 0;
    else if (boem_dinen) init_record_ejected <= 1;
  end

  // an output buffers
  ///////////////////////////
  ONE_ENTRY_FIFO #((DATW<<P_LOG))
  tmp(CLK, RST, tmp_enq, tmp_deq, tmp_din,
      tmp_dot, tmp_emp, tmp_ful);

  // TWO_ENTRY_FIFO #((DATW<<P_LOG))
  SRL_FIFO #(1, (DATW<<P_LOG))
  obuf(CLK, RST, obuf_enq, obuf_deq, obuf_din,
       obuf_dot, obuf_emp, obuf_ful, obuf_cnt);

  DATA_SLICER #((DATW<<P_LOG), DATW, P_LOG, USE_IPCORE)
  data_slicer(CLK, RST, IN_FULL, data_slicer_din, data_slicer_dinen,
              data_slicer_dot, data_slicer_doten, data_slicer_rdy);

  // Output
  assign O_REQUEST       = request;
  assign O_REQUEST_VALID = request_valid;
  assign DOT             = data_slicer_dot;
  assign DOTEN           = data_slicer_doten;

endmodule


/***** A tree of sorter stage                                             *****/
/******************************************************************************/
module SORTER_STAGE_TREE #(parameter                       W_LOG = 2,
                           parameter                       P_LOG = 3,
                           parameter                       USE_IPCORE = "INTEL",
                           parameter                       FLOAT      = "no",
                           parameter                       SIGNED     = "no",
                           parameter                       DATW  = 64,
                           parameter                       KEYW  = 32)
                          (input  wire                     CLK,
                           input  wire                     RST,
                           input  wire                     QUEUE_IN_FULL,
                           input  wire                     IN_FULL,
                           input  wire [(DATW<<P_LOG)-1:0] DIN,
                           input  wire                     DINEN,
                           input  wire [W_LOG-1        :0] DIN_IDX,
                           output wire [W_LOG-1        :0] O_REQUEST,
                           output wire                     O_REQUEST_VALID,
                           output wire [DATW-1         :0] DOT,
                           output wire                     DOTEN);

  genvar i;
  generate
    for (i=0; i<W_LOG; i=i+1) begin: stage
      wire                     queue_in_full;
      wire [(DATW<<P_LOG)-1:0] din;
      wire                     dinen;
      wire [i:0]               din_idx;
      wire [i:0]               o_request;
      wire                     o_request_valid;
      wire                     doten;
      if (i == 0) begin: root
        wire            in_full;
        wire [DATW-1:0] dot;
        SORTER_STAGE_ROOT #(P_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
        sorter_stage_root(CLK, RST, queue_in_full, in_full, din, dinen, din_idx,
                          o_request, o_request_valid, dot, doten);
      end else begin: body
        wire [i-1:0]             i_request;
        wire                     i_request_valid;
        wire                     queue_full;
        wire [(DATW<<P_LOG)-1:0] dot;
        wire [i-1:0]             dot_idx;
        SORTER_STAGE_BODY #((i+1), ((i+1)==W_LOG), P_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
        sorter_stage_body(CLK, RST, queue_in_full, i_request, i_request_valid, din, dinen, din_idx,
                          queue_full, o_request, o_request_valid, dot, doten, dot_idx);
      end
    end
  endgenerate

  generate
    for (i=0; i<W_LOG; i=i+1) begin: connection
      if (i == W_LOG-1) begin
        assign stage[W_LOG-1].queue_in_full    = QUEUE_IN_FULL;
        assign O_REQUEST                       = stage[W_LOG-1].o_request;
        assign O_REQUEST_VALID                 = stage[W_LOG-1].o_request_valid;
        assign stage[W_LOG-1].din              = DIN;
        assign stage[W_LOG-1].dinen            = DINEN;
        assign stage[W_LOG-1].din_idx          = DIN_IDX;
      end else begin
        assign stage[i].queue_in_full          = stage[i+1].body.queue_full;
        assign stage[i+1].body.i_request       = stage[i].o_request;
        assign stage[i+1].body.i_request_valid = stage[i].o_request_valid;
        assign stage[i].din                    = stage[i+1].body.dot;
        assign stage[i].dinen                  = stage[i+1].doten;
        assign stage[i].din_idx                = stage[i+1].body.dot_idx;
      end
    end
  endgenerate

  assign stage[0].root.in_full = IN_FULL;
  assign DOT                   = stage[0].root.dot;
  assign DOTEN                 = stage[0].doten;

endmodule


/***** A tree filler                                                      *****/
/******************************************************************************/
module TREE_FILLER #(parameter                       W_LOG = 2,
                     parameter                       P_LOG = 3,  // sorting network size in log scale
                     parameter                       E_LOG = 2,
                     parameter                       USE_IPCORE = "INTEL",
                     parameter                       FLOAT  = "no",
                     parameter                       SIGNED = "no",
                     parameter                       DATW  = 64,
                     parameter                       KEYW  = 32,
                     parameter                       NUMW  = 32,
                     parameter                       LOGW  = 5)
                    (input  wire                     CLK,
                     input  wire                     RST,
                     input  wire                     SPECIAL_RST,
                     input  wire                     FINAL_PASS,
                     input  wire                     BYPASS,
                     input  wire [LOGW-1:0]          MUL_PASSNUM_ALLWAYLOG,
                     input  wire [LOGW-1:0]          WAYLOG_PER_PORTION,
                     input  wire [(NUMW-(E_LOG+P_LOG))-1:0] ECNT_BYPASS,
                     input  wire [W_LOG-1        :0] I_REQUEST,
                     input  wire                     I_REQUEST_VALID,
                     input  wire                     IN_FULL,
                     input  wire [(DATW<<P_LOG)-1:0] DIN,
                     input  wire                     DINEN,
                     input  wire [W_LOG-1        :0] DIN_IDX,
                     output wire                     QUEUE_FULL,
                     output wire [(DATW<<P_LOG)-1:0] DOT,
                     output wire                     DOTEN,
                     output wire [W_LOG-1        :0] DOT_IDX,
                     output wire [(1<<W_LOG)-1   :0] EMP,
                     output wire [DATW-1         :0] BYPASS_DOT,
                     output wire                     BYPASS_DOTEN);

  localparam PAYW = DATW - KEYW;

  wire [(DATW<<P_LOG)-1:0] sentinel;

  genvar i;
  generate
    for (i=0; i<(1<<P_LOG); i=i+1) begin: setdata
      if (FLOAT == "yes" || SIGNED == "yes") begin
        localparam [KEYW-1:0] MAX_KEY = {1'b0, {(KEYW-1){1'b1}}};
        if (PAYW == 0) begin
          assign sentinel[DATW*(i+1)-1:DATW*i] = MAX_KEY;
        end else begin
          localparam [PAYW-1:0] DUMMY_PAYLOAD = {(PAYW){1'b1}};
          assign sentinel[DATW*(i+1)-1:DATW*i] = {DUMMY_PAYLOAD, MAX_KEY};
        end
      end else begin
        localparam [KEYW-1:0] MAX_KEY = {(KEYW){1'b1}};
        if (PAYW == 0) begin
          assign sentinel[DATW*(i+1)-1:DATW*i] = MAX_KEY;
        end else begin
          localparam [PAYW-1:0] DUMMY_PAYLOAD = {(PAYW){1'b1}};
          assign sentinel[DATW*(i+1)-1:DATW*i] = {DUMMY_PAYLOAD, MAX_KEY};
        end
      end
    end
  endgenerate

  wire                     queue_enq;
  reg                      queue_deq;
  wire [W_LOG-1        :0] queue_din;
  wire [W_LOG-1        :0] queue_dot;
  wire                     queue_emp;
  wire                     queue_ful;

  wire                     tfr_enq;
  wire [W_LOG-1        :0] tfr_enq_idx;
  reg                      tfr_deq;
  reg  [W_LOG-1        :0] tfr_deq_idx;
  wire [(DATW<<P_LOG)-1:0] tfr_din;
  wire [(DATW<<P_LOG)-1:0] tfr_dot;
  wire [(1<<W_LOG)-1   :0] tfr_emp;
  wire [(1<<W_LOG)-1   :0] tfr_ful;

  localparam ECNTW = (NUMW-(E_LOG+P_LOG));

  reg                      emt_we;
  wire [W_LOG-1        :0] emt_raddr;
  reg  [W_LOG-1        :0] emt_waddr;
  reg  [(1+ECNTW)-1    :0] emt_din;
  wire [(1+ECNTW)-1    :0] emt_dot;
  reg  [ECNTW-1:0]         emt_init_cnt;
  reg  [W_LOG          :0] emt_init_wadr;
  reg  [(1<<W_LOG)-1   :0] emt_init_list;
  reg                      emt_init_done;
  reg                      emt_update;
  reg  [W_LOG-1        :0] emt_update_wadr;
  reg  [(1+ECNTW)-1    :0] emt_update_val;

  integer                  p;
  reg  [2:0]               bram_latency;

  reg  [ 1:0]              state;
  reg  [ECNTW-1:0]         ecnt;
  reg  [(DATW<<P_LOG)-1:0] dot;
  reg                      doten;
  reg  [W_LOG-1        :0] dot_idx;

  wire [ECNTW-1:0]         ejected_cnt;
  wire                     portion_ejected;

  wire                     tmp_enq;
  wire                     tmp_deq;
  wire [(DATW<<P_LOG)-1:0] tmp_din;
  wire [(DATW<<P_LOG)-1:0] tmp_dot;
  wire                     tmp_emp;
  wire                     tmp_ful;

  wire [(DATW<<P_LOG)-1:0] data_slicer_din;
  wire                     data_slicer_dinen;
  wire [DATW-1         :0] data_slicer_dot;
  wire                     data_slicer_doten;
  wire                     data_slicer_rdy;

  reg  [ECNTW-1:0]         ecnt_bypass;
  reg                      bypass_done;
  reg  [W_LOG-1        :0] idx_bypass;

  reg  [1:0]               state_bypass;
  reg  [2:0]               valid_bypass;

  reg  [(DATW<<P_LOG)-1:0] dot_bypass;
  reg                      doten_bypass;

  assign queue_enq       = I_REQUEST_VALID;
  assign queue_din       = I_REQUEST;

  assign tfr_enq         = DINEN;
  assign tfr_enq_idx     = DIN_IDX;
  assign tfr_din         = DIN;

  assign emt_raddr       = queue_dot;

  assign ejected_cnt     = emt_dot[ECNTW-1:0];
  assign portion_ejected = emt_dot[ECNTW];

  initial begin
    idx_bypass  = 0;
    dot_idx     = 0;
    tfr_deq_idx = 0;
  end

  always @(posedge CLK) begin
    queue_deq   <= (SPECIAL_RST) ? 0 : &{~|state, ~queue_emp, emt_init_list[queue_dot]};
    tfr_deq     <= (SPECIAL_RST) ? 0 : |{valid_bypass[0], &{state[1], ~bram_latency[0], ~tfr_emp[dot_idx]}};
    tfr_deq_idx <= (BYPASS) ? idx_bypass : dot_idx;
  end

  ONE_ENTRY_FIFO #(W_LOG)
  request_queue(CLK, SPECIAL_RST, queue_enq, queue_deq, queue_din,
                queue_dot, queue_emp, queue_ful);

  MULTI_CHANNEL_ONEENTRY_FIFO #(W_LOG, (DATW<<P_LOG), USE_IPCORE)
  tree_filler_ram(CLK, RST, tfr_enq, tfr_enq_idx, tfr_deq, tfr_deq_idx, tfr_din,
                  tfr_dot, tfr_emp, tfr_ful);

  BRAM #(W_LOG, 1+ECNTW, USE_IPCORE) // [ECNTW] for ecnt's end flag. [ECNTW-1:0] for ecnt.
  ecnt_manage_table(CLK, emt_we, emt_raddr, emt_waddr, emt_din, emt_dot);

  always @(posedge CLK) begin
    if (SPECIAL_RST) begin
      emt_init_cnt <= (FINAL_PASS) ? (1 << (MUL_PASSNUM_ALLWAYLOG - WAYLOG_PER_PORTION)) : (1 << MUL_PASSNUM_ALLWAYLOG);
    end
  end
  always @(posedge CLK) begin
    emt_we        <= (SPECIAL_RST) ? 0 : |{emt_update, ~emt_init_wadr[W_LOG]};
    emt_init_wadr <= (SPECIAL_RST) ? 0 : emt_init_wadr + {{(W_LOG){1'b0}}, ~|{emt_init_done, emt_update}};
    emt_init_done <= (SPECIAL_RST) ? 0 : emt_init_wadr[W_LOG];
  end
  always @(posedge CLK) begin
    if (SPECIAL_RST) begin
      emt_init_list <= 0;
    end else if (~emt_update) begin
      emt_init_list[0] <= 1;
      for (p=1; p<(1<<W_LOG); p=p+1) begin
        emt_init_list[p] <= emt_init_list[p-1];
      end
    end
  end
  always @(posedge CLK) begin
    emt_update <= (SPECIAL_RST) ? 0 : &{state[1], (bram_latency[2:1] == 2'b01)};
    emt_waddr  <= (emt_update) ? emt_update_wadr : emt_init_wadr[W_LOG-1:0];
    emt_din    <= (emt_update) ? emt_update_val  : {1'b0, emt_init_cnt};
  end

  always @(posedge CLK) begin
    if (SPECIAL_RST) begin
      doten        <= 0;
      state        <= 0;
      bram_latency <= 0;
    end else begin
      case (state)
        0: begin
          doten        <= 0;
          state        <= &{~queue_emp, emt_init_list[queue_dot], ~BYPASS};  // state 0 -> 1
          bram_latency <= 0;
        end
        1: begin
          bram_latency[0] <= queue_deq;
          for (p=1; p<3; p=p+1) begin
            bram_latency[p] <= bram_latency[p-1];
          end
          if (bram_latency[2]) begin
            state <= {~portion_ejected, 1'b0};  // (portion_ejected) ? 0 : 2;
          end
          doten <= &{bram_latency[2], portion_ejected};
        end
        2: begin
          bram_latency[0] <= ~tfr_emp[dot_idx];
          for (p=1; p<3; p=p+1) begin
            bram_latency[p] <= bram_latency[p-1];
          end
          state <= {~bram_latency[2], 1'b0};
          doten <= bram_latency[2];
        end
      endcase
    end
  end

  always @(posedge CLK) begin
    // if state 2 -> tfr_dot else if state 1 -> sentinel
    dot <= (state[1]) ? tfr_dot : sentinel;
  end
  always @(posedge CLK) begin
    if (queue_deq) dot_idx <= queue_dot;
  end
  always @(posedge CLK) begin
    // state 1 and bram_latency[2] is 1
    if (&{state[0], bram_latency[2]}) begin
      ecnt <= ejected_cnt;
    end
  end
  reg        emt_update_val_msb;
  reg [ECNTW-1:0] emt_update_val_rest;
  always @(posedge CLK) begin
    emt_update_val_msb  <= (ecnt == 1);
    emt_update_val_rest <= ecnt - 1;
  end
  always @(posedge CLK) begin
    emt_update_wadr <= dot_idx;
    emt_update_val  <= {emt_update_val_msb, emt_update_val_rest};
  end

  // bypass logic
  ///////////////////////////////////////////
  always @(posedge CLK) begin
    if (SPECIAL_RST) begin
      ecnt_bypass <= ECNT_BYPASS;
      bypass_done <= 0;
      idx_bypass  <= 0;
    end else if (valid_bypass[2]) begin
      ecnt_bypass <= ecnt_bypass - 1;
      bypass_done <= (ecnt_bypass == 1);
      idx_bypass  <= idx_bypass + 1;
    end
  end

  always @(posedge CLK) begin
    dot_bypass   <= (bypass_done) ? sentinel : tfr_dot;
    doten_bypass <= (SPECIAL_RST) ? 0 : |{(state_bypass == 2'b10), valid_bypass[2]};
  end

  always @(posedge CLK) begin
    if (SPECIAL_RST) begin
      valid_bypass <= 0;
    end else begin
      valid_bypass[0] <= (state_bypass == 2'b01);
      for (p=1; p<3; p=p+1) begin
        valid_bypass[p] <= valid_bypass[p-1];
      end
    end
  end

  always @(posedge CLK) begin
    if (SPECIAL_RST) begin
      state_bypass <= 0;
    end else begin
      case (state_bypass)
        0: begin
          if (&{~tmp_ful, BYPASS}) begin
            // if (bypass_done) 2 else if (~tfr_emp[idx_bypass]) 1
            state_bypass <= {bypass_done, ~tfr_emp[idx_bypass]};
          end
        end
        1: begin  // eject tfr_dot
          state_bypass <= 3;
        end
        2: begin  // eject dummy value
          state_bypass <= 3;
        end
        3: begin
          if (doten_bypass) begin
            state_bypass <= 0;
          end
        end
      endcase
    end
  end

  assign tmp_enq = doten_bypass;
  assign tmp_deq = &{data_slicer_rdy, ~tmp_emp};
  assign tmp_din = dot_bypass;

  assign data_slicer_din   = tmp_dot;
  assign data_slicer_dinen = tmp_deq;

  ONE_ENTRY_FIFO #((DATW<<P_LOG))
  tmp(CLK, SPECIAL_RST, tmp_enq, tmp_deq, tmp_din,
      tmp_dot, tmp_emp, tmp_ful);

  DATA_SLICER #((DATW<<P_LOG), DATW, P_LOG, USE_IPCORE)
  data_slicer(CLK, SPECIAL_RST, IN_FULL, data_slicer_din, data_slicer_dinen,
              data_slicer_dot, data_slicer_doten, data_slicer_rdy);

  // Output
  assign QUEUE_FULL = queue_ful;
  assign DOT        = dot;
  assign DOTEN      = doten;
  assign DOT_IDX    = dot_idx;
  assign EMP        = tfr_emp;
  assign BYPASS_DOT   = data_slicer_dot;
  assign BYPASS_DOTEN = data_slicer_doten;

endmodule


/***** A virtual merge sorter tree                                       *****/
/******************************************************************************/
module vMERGE_SORTER_TREE #(parameter                       W_LOG      = 2,
                            parameter                       P_LOG      = 3,
                            parameter                       E_LOG      = 2,
                            parameter                       USE_IPCORE = "INTEL",
                            parameter                       FLOAT      = "no",
                            parameter                       SIGNED     = "no",
                            parameter                       DATW       = 64,
                            parameter                       KEYW       = 32,
                            parameter                       NUMW       = 32,
                            parameter                       LOGW       = 5)
                           (input  wire                     CLK,
                            input  wire                     RST,
                            input  wire                     SPECIAL_RST,
                            input  wire                     FINAL_PASS,
                            input  wire                     BYPASS,
                            input  wire [LOGW-1:0]          MUL_PASSNUM_ALLWAYLOG,
                            input  wire [LOGW-1:0]          WAYLOG_PER_PORTION,
                            input  wire [(NUMW-(E_LOG+P_LOG))-1:0] ECNT_BYPASS,
                            input  wire                     IN_FULL,
                            input  wire [(DATW<<P_LOG)-1:0] DIN,
                            input  wire                     DINEN,
                            input  wire [W_LOG-1        :0] DIN_IDX,
                            output wire [DATW-1         :0] DOT,
                            output wire                     DOTEN,
                            output wire [(1<<W_LOG)-1   :0] EMP);

  reg special_rst;
  always @(posedge CLK) special_rst <= SPECIAL_RST;

  // stall signal
  reg stall;
  always @(posedge CLK) stall <= IN_FULL;

  wire [W_LOG-1        :0] tf_i_request;
  wire                     tf_i_request_valid;
  wire                     tf_in_full;
  wire [(DATW<<P_LOG)-1:0] tf_din;
  wire                     tf_dinen;
  wire [W_LOG-1        :0] tf_din_idx;
  wire                     tf_queue_full;
  wire [(DATW<<P_LOG)-1:0] tf_dot;
  wire                     tf_doten;
  wire [W_LOG-1        :0] tf_dot_idx;
  wire [(1<<W_LOG)-1   :0] tf_emp;
  wire [DATW-1         :0] tf_bypass_dot;
  wire                     tf_bypass_doten;

  wire                     sst_queue_in_full;
  wire                     sst_in_full;
  wire [(DATW<<P_LOG)-1:0] sst_din;
  wire                     sst_dinen;
  wire [W_LOG-1        :0] sst_din_idx;
  wire [W_LOG-1        :0] sst_o_request;
  wire                     sst_o_request_valid;
  wire [DATW-1         :0] sst_dot;
  wire                     sst_doten;

  reg                      obuf_enq;
  reg  [DATW-1         :0] obuf_din;
  wire                     obuf_deq;
  wire [DATW-1         :0] obuf_dot;
  wire                     obuf_emp;
  wire                     obuf_ful;
  wire [3:0]               obuf_cnt;

  assign tf_i_request       = sst_o_request;
  assign tf_i_request_valid = sst_o_request_valid;
  assign tf_in_full         = |obuf_cnt[3:2];
  assign tf_din             = DIN;
  assign tf_dinen           = DINEN;
  assign tf_din_idx         = DIN_IDX;

  assign sst_queue_in_full = tf_queue_full;
  assign sst_in_full       = |obuf_cnt[3:2];
  assign sst_din           = tf_dot;
  assign sst_dinen         = tf_doten;
  assign sst_din_idx       = tf_dot_idx;

  assign obuf_deq          = ~|{stall, obuf_emp};

  TREE_FILLER #(W_LOG, P_LOG, E_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW, NUMW, LOGW)
  tree_filler(CLK, RST, special_rst, FINAL_PASS, BYPASS, MUL_PASSNUM_ALLWAYLOG, WAYLOG_PER_PORTION, ECNT_BYPASS, tf_i_request, tf_i_request_valid, tf_in_full, tf_din, tf_dinen, tf_din_idx,
              tf_queue_full, tf_dot, tf_doten, tf_dot_idx, tf_emp, tf_bypass_dot, tf_bypass_doten);

  SORTER_STAGE_TREE #(W_LOG, P_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
  sorter_stage_tree(CLK, special_rst, sst_queue_in_full, sst_in_full, sst_din, sst_dinen, sst_din_idx,
                    sst_o_request, sst_o_request_valid, sst_dot, sst_doten);

  always @(posedge CLK) begin
    obuf_enq <= (special_rst) ? 0 : |{tf_bypass_doten, sst_doten};
    obuf_din <= (BYPASS) ? tf_bypass_dot : sst_dot;
  end

  // TWO_ENTRY_FIFO #(DATW)
  SRL_FIFO #(3, DATW)
  obuf(CLK, special_rst, obuf_enq, obuf_deq, obuf_din,
       obuf_dot, obuf_emp, obuf_ful, obuf_cnt);

  // Output
  //////////////////////////////////////////////////////////
  assign DOT   = obuf_dot;
  assign DOTEN = obuf_deq;
  assign EMP   = tf_emp;

endmodule

`default_nettype wire
