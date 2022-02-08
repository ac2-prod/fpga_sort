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

/***** A pipelined CAS (this version is for a datapath of key and value)  *****/
/******************************************************************************/
module CAS #(parameter              FLOAT  = "no",
             parameter              SIGNED = "no",
             parameter              DATW = 64,
             parameter              KEYW = 32)
            (input  wire            CLK,
             input  wire [DATW-1:0] DIN0,
             input  wire [DATW-1:0] DIN1,
             output wire [DATW-1:0] DOT0,
             output wire [DATW-1:0] DOT1);

  function [DATW-1:0] mux;
    input [DATW-1:0] a;
    input [DATW-1:0] b;
    input            sel;
    begin
      case (sel)
        1'b0: mux = a;
        1'b1: mux = b;
      endcase
    end
  endfunction

  wire comparator_rslt;
  COMPARATOR #(FLOAT, SIGNED, KEYW)
  comparator(DIN0[KEYW-1:0], DIN1[KEYW-1:0], comparator_rslt);

  reg [DATW-1:0] din0;      always @(posedge CLK) din0      <= DIN0;
  reg [DATW-1:0] din1;      always @(posedge CLK) din1      <= DIN1;
  reg            comp_rslt; always @(posedge CLK) comp_rslt <= comparator_rslt;

  assign DOT0 = mux(din1, din0, comp_rslt);
  assign DOT1 = mux(din0, din1, comp_rslt);

endmodule


/***** A pipelined CAS only for keys                                      *****/
/******************************************************************************/
module K_CAS #(parameter              FLOAT  = "no",
               parameter              SIGNED = "no",
               parameter              KEYW   = 32)
              (input  wire            CLK,
               input  wire [KEYW-1:0] DIN0,
               input  wire [KEYW-1:0] DIN1,
               output wire [KEYW-1:0] DOT0,
               output wire [KEYW-1:0] DOT1,
               output wire            COMP);

  function [KEYW-1:0] mux;
    input [KEYW-1:0] a;
    input [KEYW-1:0] b;
    input            sel;
    begin
      case (sel)
        1'b0: mux = a;
        1'b1: mux = b;
      endcase
    end
  endfunction

  wire comparator_rslt;
  COMPARATOR #(FLOAT, SIGNED, KEYW)
  comparator(DIN0, DIN1, comparator_rslt);

  reg [KEYW-1:0] din0;      always @(posedge CLK) din0      <= DIN0;
  reg [KEYW-1:0] din1;      always @(posedge CLK) din1      <= DIN1;
  reg            comp_rslt; always @(posedge CLK) comp_rslt <= comparator_rslt;

  assign DOT0 = mux(din1, din0, comp_rslt);
  assign DOT1 = mux(din0, din1, comp_rslt);
  assign COMP = comp_rslt;

endmodule


/***** Do swap for payloads                                               *****/
/******************************************************************************/
module P_SWAP #(parameter              PAYW = 32)
               (input  wire            COMP,
                input  wire [PAYW-1:0] DIN0,
                input  wire [PAYW-1:0] DIN1,
                output wire [PAYW-1:0] DOT0,
                output wire [PAYW-1:0] DOT1);

  function [PAYW-1:0] mux;
    input [PAYW-1:0] a;
    input [PAYW-1:0] b;
    input            sel;
    begin
      case (sel)
        1'b0: mux = a;
        1'b1: mux = b;
      endcase
    end
  endfunction

  assign DOT0 = mux(DIN1, DIN0, COMP);
  assign DOT1 = mux(DIN0, DIN1, COMP);

endmodule


/***** A Batcher's odd-even merger                                        *****/
/******************************************************************************/
module BOEM #(parameter                       P_LOG = 2,
              parameter                       FLOAT  = "no",
              parameter                       SIGNED = "no",
              parameter                       DATW  = 64,
              parameter                       KEYW  = 32)
             (input  wire                     CLK,
              input  wire [(DATW<<P_LOG)-1:0] DIN,
              output wire [(DATW<<P_LOG)-1:0] DOT);

  localparam PAYW = DATW - KEYW;

  genvar i, j, k;
  generate
    if (PAYW == 0) begin
      reg [(DATW<<P_LOG)-1:0] pd [P_LOG-1:0];  // pipeline regester inserted between CAS
      for (i=0; i<P_LOG; i=i+1) begin: stage
        wire [(DATW<<P_LOG)-1:0] dot;
        if (i == 0) begin
          for (j=0; j<(1<<(P_LOG-1)); j=j+1) begin: pipelined_cas
            if (j == 0) begin  // Redundant CAS Elimination
              reg [DATW-1:0] buf0; always @(posedge CLK) buf0 <= DIN[DATW*(j+1)-1:DATW*j];
              reg [DATW-1:0] buf1; always @(posedge CLK) buf1 <= DIN[DATW*((j+1)+(1<<(P_LOG-1)))-1:DATW*(j+(1<<(P_LOG-1)))];
              assign dot[DATW*(j+1)-1:DATW*j] = buf0;
              assign dot[DATW*((j+1)+(1<<(P_LOG-1)))-1:DATW*(j+(1<<(P_LOG-1)))] = buf1;
            end else begin
              CAS #(FLOAT, SIGNED, DATW, KEYW)
              cas(
                  CLK,
                  DIN[DATW*(j+1)-1:DATW*j],
                  DIN[DATW*((j+1)+(1<<(P_LOG-1)))-1:DATW*(j+(1<<(P_LOG-1)))],
                  dot[DATW*(j+1)-1:DATW*j],
                  dot[DATW*((j+1)+(1<<(P_LOG-1)))-1:DATW*(j+(1<<(P_LOG-1)))]
                  );
            end
          end
          always @(posedge CLK) pd[i] <= dot;
        end else begin
          for (k=0; k<((1<<i)-1); k=k+1) begin: blocks
            for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: pipelined_cas
              CAS #(FLOAT, SIGNED, DATW, KEYW)
              cas(
                  CLK,
                  pd[i-1][DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                  pd[i-1][DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                  dot[DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                  dot[DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))]
                  );
            end
          end
          reg [DATW*(1<<(P_LOG-(i+1)))-1:0] pd_upper_buf;
          reg [DATW*(1<<(P_LOG-(i+1)))-1:0] pd_lower_buf;
          always @(posedge CLK) pd_upper_buf <= pd[i-1][(DATW<<P_LOG)-1:DATW*((1<<P_LOG)-(1<<(P_LOG-(i+1))))];
          always @(posedge CLK) pd_lower_buf <= pd[i-1][DATW*(1<<(P_LOG-(i+1)))-1:0];
          always @(posedge CLK) pd[i] <= {pd_upper_buf,
                                          dot[DATW*((1<<P_LOG)-(1<<(P_LOG-(i+1))))-1:DATW*(1<<(P_LOG-(i+1)))],
                                          pd_lower_buf};
        end
      end
      assign DOT = pd[P_LOG-1];
    end else begin
      /// input
      wire [(KEYW<<P_LOG)-1:0] i_key;
      wire [(PAYW<<P_LOG)-1:0] i_payload;
      for (i=0; i<(1<<P_LOG); i=i+1) begin: set_i_data
        assign i_key[KEYW*(i+1)-1:KEYW*i] = DIN[(KEYW+DATW*i)-1:DATW*i];
        assign i_payload[PAYW*(i+1)-1:PAYW*i] = DIN[DATW*(i+1)-1:(KEYW+DATW*i)];
      end
      /// core
      reg [(KEYW<<P_LOG)-1:0] k_preg [P_LOG-1:0];  // pipeline regester for key
      reg [(PAYW<<P_LOG)-1:0] p_preg [P_LOG-1:0];  // pipeline regester for payload
      integer p;
      reg [(PAYW<<P_LOG)-1:0] p_sreg [P_LOG-1:0];  // shift register for payload
      always @(posedge CLK) begin
        p_sreg[0] <= i_payload;
        for (p=1; p<P_LOG; p=p+1) begin
          p_sreg[p] <= p_sreg[p-1];
        end
      end
      for (i=0; i<P_LOG; i=i+1) begin: stage
        wire [(KEYW<<P_LOG)-1:0] o_key;
        wire [(PAYW<<P_LOG)-1:0] o_payload;
        if (i == 0) begin
          // key
          for (j=0; j<(1<<(P_LOG-1)); j=j+1) begin: pipelined_k_cas
            if (j == 0) begin  // Redundant K_CAS Elimination
              reg [KEYW-1:0] k_buf0; always @(posedge CLK) k_buf0 <= i_key[KEYW*(j+1)-1:KEYW*j];
              reg [KEYW-1:0] k_buf1; always @(posedge CLK) k_buf1 <= i_key[KEYW*((j+1)+(1<<(P_LOG-1)))-1:KEYW*(j+(1<<(P_LOG-1)))];
              assign o_key[KEYW*(j+1)-1:KEYW*j] = k_buf0;
              assign o_key[KEYW*((j+1)+(1<<(P_LOG-1)))-1:KEYW*(j+(1<<(P_LOG-1)))] = k_buf1;
            end else begin: k_cas_exists
              wire o_cmp;
              wire i_cmp;  // input of P_SWAP
              K_CAS #(FLOAT, SIGNED, KEYW)
              k_cas(
                    CLK,
                    i_key[KEYW*(j+1)-1:KEYW*j],
                    i_key[KEYW*((j+1)+(1<<(P_LOG-1)))-1:KEYW*(j+(1<<(P_LOG-1)))],
                    o_key[KEYW*(j+1)-1:KEYW*j],
                    o_key[KEYW*((j+1)+(1<<(P_LOG-1)))-1:KEYW*(j+(1<<(P_LOG-1)))],
                    o_cmp
                    );
              if (P_LOG-(i+1) == 0) begin
                assign i_cmp = o_cmp;
              end else begin
                reg [(P_LOG-(i+1))-1:0] cmp_buf;
                always @(posedge CLK) begin
                  cmp_buf[0] <= o_cmp;
                  for (p=1; p<(P_LOG-(i+1)); p=p+1) begin
                    cmp_buf[p] <= cmp_buf[p-1];
                  end
                end
                assign i_cmp = cmp_buf[(P_LOG-(i+1))-1];
              end
            end
          end
          always @(posedge CLK) k_preg[i] <= o_key;
          // payload
          for (j=0; j<(1<<(P_LOG-1)); j=j+1) begin: p_swaps
            if (j == 0) begin  // Redundant P_SWAP Elimination
              assign o_payload[PAYW*(j+1)-1:PAYW*j] = p_sreg[P_LOG-1][PAYW*(j+1)-1:PAYW*j];
              assign o_payload[PAYW*((j+1)+(1<<(P_LOG-1)))-1:PAYW*(j+(1<<(P_LOG-1)))] = p_sreg[P_LOG-1][PAYW*((j+1)+(1<<(P_LOG-1)))-1:PAYW*(j+(1<<(P_LOG-1)))];
            end else begin
              P_SWAP #(PAYW)
              p_swap(
                     pipelined_k_cas[j].k_cas_exists.i_cmp,
                     p_sreg[P_LOG-1][PAYW*(j+1)-1:PAYW*j],
                     p_sreg[P_LOG-1][PAYW*((j+1)+(1<<(P_LOG-1)))-1:PAYW*(j+(1<<(P_LOG-1)))],
                     o_payload[PAYW*(j+1)-1:PAYW*j],
                     o_payload[PAYW*((j+1)+(1<<(P_LOG-1)))-1:PAYW*(j+(1<<(P_LOG-1)))]
                     );
            end
          end
          always @(posedge CLK) p_preg[i] <= o_payload;
        end else begin
          // key
          for (k=0; k<((1<<i)-1); k=k+1) begin: k_blocks
            for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: pipelined_k_cas
              wire o_cmp;
              wire i_cmp;  // input of P_SWAP
              K_CAS #(FLOAT, SIGNED, KEYW)
              k_cas(
                    CLK,
                    k_preg[i-1][KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                    k_preg[i-1][KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                    o_key[KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                    o_key[KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                    o_cmp
                    );
              if (P_LOG-(i+1) == 0) begin
                assign i_cmp = o_cmp;
              end else begin
                reg [(P_LOG-(i+1))-1:0] cmp_buf;
                always @(posedge CLK) begin
                  cmp_buf[0] <= o_cmp;
                  for (p=1; p<(P_LOG-(i+1)); p=p+1) begin
                    cmp_buf[p] <= cmp_buf[p-1];
                  end
                end
                assign i_cmp = cmp_buf[(P_LOG-(i+1))-1];
              end
            end
          end
          reg [KEYW*(1<<(P_LOG-(i+1)))-1:0] k_preg_upper_buf;
          reg [KEYW*(1<<(P_LOG-(i+1)))-1:0] k_preg_lower_buf;
          always @(posedge CLK) k_preg_upper_buf <= k_preg[i-1][(KEYW<<P_LOG)-1:KEYW*((1<<P_LOG)-(1<<(P_LOG-(i+1))))];
          always @(posedge CLK) k_preg_lower_buf <= k_preg[i-1][KEYW*(1<<(P_LOG-(i+1)))-1:0];
          always @(posedge CLK) k_preg[i] <= {k_preg_upper_buf,
                                              o_key[KEYW*((1<<P_LOG)-(1<<(P_LOG-(i+1))))-1:KEYW*(1<<(P_LOG-(i+1)))],
                                              k_preg_lower_buf};
          // payload
          for (k=0; k<((1<<i)-1); k=k+1) begin: p_blocks
            for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: p_swaps
              P_SWAP #(PAYW)
              p_swap(k_blocks[k].pipelined_k_cas[j].i_cmp,
                     p_preg[i-1][PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                     p_preg[i-1][PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                     o_payload[PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                     o_payload[PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))]
                     );
            end
          end
          always @(posedge CLK) p_preg[i] <= {p_preg[i-1][(PAYW<<P_LOG)-1:PAYW*((1<<P_LOG)-(1<<(P_LOG-(i+1))))],
                                              o_payload[PAYW*((1<<P_LOG)-(1<<(P_LOG-(i+1))))-1:PAYW*(1<<(P_LOG-(i+1)))],
                                              p_preg[i-1][PAYW*(1<<(P_LOG-(i+1)))-1:0]};
        end
      end
      /// output
      for (i=0; i<(1<<P_LOG); i=i+1) begin: set_o_data
        assign DOT[DATW*(i+1)-1:DATW*i] = {p_preg[P_LOG-1][PAYW*(i+1)-1:PAYW*i], k_preg[P_LOG-1][KEYW*(i+1)-1:KEYW*i]};
      end
    end
  endgenerate

endmodule


/***** An E-record merge network                                          *****/
/******************************************************************************/
module MERGE_NETWORK #(parameter                       E_LOG = 2,
                       parameter                       FLOAT  = "no",
                       parameter                       SIGNED = "no",
                       parameter                       DATW  = 64,
                       parameter                       KEYW  = 32)
                      (input  wire                     CLK,
                       input  wire                     RST,
                       input  wire [(DATW<<E_LOG)-1:0] DIN_A,
                       input  wire                     SEL_A,
                       input  wire [(DATW<<E_LOG)-1:0] DIN_B,
                       input  wire                     SEL_B,
                       output wire [(DATW<<E_LOG)-1:0] DOT,
                       output wire                     DOTEN);

  localparam PAYW = DATW - KEYW;

  wire [(DATW<<E_LOG)-1:0] init_dummy_data;

  genvar i;
  generate
    for (i=0; i<(1<<E_LOG); i=i+1) begin: setdata
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

  function [(DATW<<E_LOG)-1:0] mux;
    input [(DATW<<E_LOG)-1:0] in0;
    input [(DATW<<E_LOG)-1:0] in1;
    input                     sel;
    begin
      case (sel)
        1'b0: mux = in0;
        1'b1: mux = in1;
      endcase
    end
  endfunction

  // Input
  //////////////////////////////////////////////////////////
  reg [(DATW<<E_LOG)-1:0] din_a;
  reg [(DATW<<E_LOG)-1:0] din_b;
  always @(posedge CLK) begin
    din_a <= DIN_A;
    din_b <= DIN_B;
  end

  reg sel_a;
  reg sel_b;
  always @(posedge CLK) begin
    if (RST) begin
      sel_a <= 0;
      sel_b <= 0;
    end else begin
      sel_a <= SEL_A;
      sel_b <= SEL_B;
    end
  end

  reg dinen;
  always @(posedge CLK) begin
    dinen <= (RST) ? 0 : |{SEL_B,SEL_A};
  end

  // Core part
  //////////////////////////////////////////////////////////
  wire [(DATW<<E_LOG)-1:0] c_2 = mux(din_b, din_a, sel_a);

  reg a_selected;
  always @(posedge CLK) begin
    if (dinen) a_selected <= sel_a;
  end

  wire update_r_1 = &{dinen,^{a_selected,sel_a}};

  reg [(DATW<<E_LOG)-1:0] r_1;
  reg [(DATW<<E_LOG)-1:0] r_2;
  always @(posedge CLK) begin
    if      (RST)   r_2 <= init_dummy_data;  // init_dummy_data is for ejecting the first record
    else if (dinen) r_2 <= c_2;
  end
  always @(posedge CLK) begin
    if      (RST)        r_1 <= init_dummy_data;  // init_dummy_data is for ejecting the first record
    else if (update_r_1) r_1 <= r_2;
  end

  wire [(DATW<<(E_LOG+1))-1:0] m_l_din = {r_2, r_1};
  wire [(DATW<<(E_LOG+1))-1:0] m_l_dot;
  BOEM #(E_LOG+1, FLOAT, SIGNED, DATW, KEYW)
  M_L(CLK, m_l_din, m_l_dot);

  // Shift Register
  integer p; reg [(DATW<<E_LOG)-1:0] sbuf [((E_LOG+1)<<1)-1:0];  // '<<1' is because of two-stage CAS
  always @(posedge CLK) begin
    sbuf[0] <= c_2;
    for (p=1; p<((E_LOG+1)<<1); p=p+1) sbuf[p] <= sbuf[p-1];
  end

  wire [(DATW<<(E_LOG+1))-1:0] m_s_din = {sbuf[((E_LOG+1)<<1)-1], m_l_dot[(DATW<<(E_LOG+1))-1:(DATW<<E_LOG)]};
  wire [(DATW<<(E_LOG+1))-1:0] m_s_dot;
  BOEM #(E_LOG+1, FLOAT, SIGNED, DATW, KEYW)
  M_S(CLK, m_s_din, m_s_dot);

  reg init_record_ejected;
  always @(posedge CLK) begin
    if      (RST)   init_record_ejected <= 0;
    else if (dinen) init_record_ejected <= 1;
  end

  reg [(((E_LOG+1)<<1)<<1)-1:0] pc;  // pipeline regester for control (outer '<<1' is for ML and MS)
  always @(posedge CLK) begin
    if (RST) begin
      pc <= 0;
    end else begin
      pc[0] <= &{dinen, init_record_ejected};
      for (p=1; p<(((E_LOG+1)<<1)<<1); p=p+1) pc[p] <= pc[p-1];
    end
  end

  // Output
  //////////////////////////////////////////////////////////
  assign DOT   = m_s_dot[(DATW<<E_LOG)-1:0];
  assign DOTEN = pc[(((E_LOG+1)<<1)<<1)-1];

endmodule


/***** A merge logic                                                      *****/
/******************************************************************************/
module MERGE_LOGIC #(parameter                       E_LOG      = 2,
                     parameter                       USE_IPCORE = "INTEL",
                     parameter                       FLOAT      = "no",
                     parameter                       SIGNED     = "no",
                     parameter                       DATW       = 64,
                     parameter                       KEYW       = 32)
                    (input  wire                     CLK,
                     input  wire                     RST,
                     input  wire                     IN_FULL,
                     input  wire                     ENQ_A,
                     input  wire [(DATW<<E_LOG)-1:0] DIN_A,
                     input  wire                     ENQ_B,
                     input  wire [(DATW<<E_LOG)-1:0] DIN_B,
                     output wire                     FUL_A,
                     output wire                     FUL_B,
                     output wire [(DATW<<E_LOG)-1:0] DOT,
                     output wire                     DOTEN);

  localparam PAYW = DATW - KEYW;

  wire [(DATW<<E_LOG)-1:0] init_dummy_data;

  genvar i;
  generate
    for (i=0; i<(1<<E_LOG); i=i+1) begin: setdata
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

  // stall signal
  reg stall;
  always @(posedge CLK) stall <= IN_FULL;

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value >> 1;
    end
  endfunction

  function mux;
    input       a;
    input       b;
    input       c;
    input [1:0] sel;
    begin
      case (sel)
        2'b00: mux = a;
        2'b01: mux = b;
        2'b10: mux = b;
        2'b11: mux = c;
      endcase
    end
  endfunction

  localparam FIFO_SIZE = clog2(((((E_LOG+1)<<1)<<1)+2));  // '+2' is because of two input registers

  wire                     fifo_A_enq, fifo_B_enq;
  wire                     fifo_A_deq, fifo_B_deq;
  wire [(DATW<<E_LOG)-1:0] fifo_A_din, fifo_B_din;
  wire [(DATW<<E_LOG)-1:0] fifo_A_dot, fifo_B_dot;
  wire                     fifo_A_emp, fifo_B_emp;
  wire                     fifo_A_ful, fifo_B_ful;
  wire [5:0]               fifo_A_cnt, fifo_B_cnt;

  reg  [(DATW<<E_LOG)-1:0] A [2:0];
  reg  [(DATW<<E_LOG)-1:0] B [2:0];

  reg  [2:0]               init_A;
  reg  [2:0]               init_B;

  reg  [1:0]               comp_history;

  assign fifo_A_enq = ENQ_A;
  assign fifo_A_deq = &{~stall, ~fifo_A_emp, comp_history[0]};
  assign fifo_A_din = DIN_A;

  assign fifo_B_enq = ENQ_B;
  assign fifo_B_deq = ~|{stall, fifo_B_emp, comp_history[0]};
  assign fifo_B_din = DIN_B;

  BS_FIFO #(5, (DATW<<E_LOG), USE_IPCORE)
  fifo_A(CLK, RST, fifo_A_enq, fifo_A_deq, fifo_A_din,
         fifo_A_dot, fifo_A_emp, fifo_A_ful, fifo_A_cnt);
  BS_FIFO #(5, (DATW<<E_LOG), USE_IPCORE)
  fifo_B(CLK, RST, fifo_B_enq, fifo_B_deq, fifo_B_din,
         fifo_B_dot, fifo_B_emp, fifo_B_ful, fifo_B_cnt);

  integer p;
  always @(posedge CLK) begin
    if (RST) begin
      for (p=0; p<3; p=p+1) begin
        A[p]      <= init_dummy_data;  // init_dummy_data is for ejecting the first record
        init_A[p] <= 0;
      end
    end else if (fifo_A_deq) begin
      A[0]      <= fifo_A_dot;
      init_A[0] <= 1;
      for (p=1; p<3; p=p+1) begin
        A[p]      <= A[p-1];
        init_A[p] <= init_A[p-1];
      end
    end
  end
  always @(posedge CLK) begin
    if (RST) begin
      for (p=0; p<3; p=p+1) begin
        B[p]      <= init_dummy_data;  // init_dummy_data is for ejecting the first record
        init_B[p] <= 0;
      end
    end else if (fifo_B_deq) begin
      B[0]      <= fifo_B_dot;
      init_B[0] <= 1;
      for (p=1; p<3; p=p+1) begin
        B[p]      <= B[p-1];
        init_B[p] <= init_B[p-1];
      end
    end
  end

  generate
    for (i=0; i<3; i=i+1) begin: comp
      wire comparator_rslt;
      COMPARATOR #(FLOAT, SIGNED, KEYW)
      comparator(A[i][KEYW-1:0], B[2-i][KEYW-1:0], comparator_rslt);
      reg rslt;
      always @(posedge CLK) begin
        if (RST) begin
          rslt <= 0;
        end else if (|{fifo_B_deq,fifo_A_deq}) begin
          rslt <= comparator_rslt;
        end
      end
    end
  endgenerate

  always @(posedge CLK) begin
    if (RST) begin
      comp_history <= 0;
    end else if (|{fifo_B_deq,fifo_A_deq}) begin
      comp_history[0] <= mux(comp[2].rslt, comp[1].rslt, comp[0].rslt, comp_history);
      comp_history[1] <= comp_history[0];
    end
  end

  reg [(DATW<<E_LOG)-1:0] mnet_din_a;
  reg [(DATW<<E_LOG)-1:0] mnet_din_b;
  always @(posedge CLK) begin
    mnet_din_a <= A[2];
    mnet_din_b <= B[2];
  end

  reg mnet_sel_a;
  reg mnet_sel_b;
  always @(posedge CLK) begin
    if (RST) begin
      mnet_sel_a <= 0;
      mnet_sel_b <= 0;
    end else begin
      mnet_sel_a <= &{init_A[2], fifo_A_deq};
      mnet_sel_b <= &{init_B[2], fifo_B_deq};
    end
  end

  wire [(DATW<<E_LOG)-1:0] mnet_dot;
  wire                     mnet_doten;
  MERGE_NETWORK #(E_LOG, FLOAT, SIGNED, DATW, KEYW)
  merge_network(CLK, RST, mnet_din_a, mnet_sel_a, mnet_din_b, mnet_sel_b,
                mnet_dot, mnet_doten);

  wire                     fifo_C_enq;
  wire                     fifo_C_deq;
  wire [(DATW<<E_LOG)-1:0] fifo_C_din;
  wire [(DATW<<E_LOG)-1:0] fifo_C_dot;
  wire                     fifo_C_emp;
  wire                     fifo_C_ful;
  wire [FIFO_SIZE:0]       fifo_C_cnt;

  wire                     obuf_enq;
  wire                     obuf_deq;
  wire [(DATW<<E_LOG)-1:0] obuf_din;
  wire [(DATW<<E_LOG)-1:0] obuf_dot;
  wire                     obuf_emp;
  wire                     obuf_ful;
  wire [1:0]               obuf_cnt;

  assign fifo_C_enq = mnet_doten;
  assign fifo_C_deq = ~|{stall, fifo_C_emp};
  assign fifo_C_din = mnet_dot;

  BS_FIFO #(FIFO_SIZE, (DATW<<E_LOG), USE_IPCORE)
  fifo_C(CLK, RST, fifo_C_enq, fifo_C_deq, fifo_C_din,
         fifo_C_dot, fifo_C_emp, fifo_C_ful, fifo_C_cnt);

  // Output
  assign FUL_A = fifo_A_ful;
  assign FUL_B = fifo_B_ful;
  assign DOT   = fifo_C_dot;
  assign DOTEN = fifo_C_deq;

endmodule


/***** A coupler                                                          *****/
/******************************************************************************/
module COUPLER #(parameter                           E_LOG = 2,
                 parameter                           DATW  = 64)
                (input  wire                         CLK,
                 input  wire                         RST,
                 input  wire                         IN_FULL,
                 input  wire [(DATW<<(E_LOG-1))-1:0] DIN,
                 input  wire                         DINEN,
                 output wire [(DATW<<E_LOG)-1:0]     DOT,
                 output wire                         DOTEN);

  // stall signal
  reg stall;
  always @(posedge CLK) stall <= IN_FULL;

  reg [(DATW<<E_LOG)-1:0] record_buf;
  reg                     record_buf_cnt;
  reg                     record_buf_en;

  always @(posedge CLK) begin
    if (DINEN) record_buf <= {DIN, record_buf[(DATW<<E_LOG)-1:(DATW<<(E_LOG-1))]};
  end
  always @(posedge CLK) begin
    if      (RST)   record_buf_cnt <= 0;
    else if (DINEN) record_buf_cnt <= ~record_buf_cnt;
  end
  always @(posedge CLK) begin  // old version has bug here
    if      (RST)    record_buf_en <= 0;
    else if (!stall) record_buf_en <= &{DINEN, record_buf_cnt};
  end

  // Output
  assign DOT   = record_buf;
  assign DOTEN = &{record_buf_en, (~stall)};

endmodule


/***** A merge node                                                       *****/
/******************************************************************************/
module MERGE_NODE #(parameter                           E_LOG      = 2,
                    parameter                           USE_IPCORE = "INTEL",
                    parameter                           FLOAT      = "no",
                    parameter                           SIGNED     = "no",
                    parameter                           DATW       = 64,
                    parameter                           KEYW       = 32)
                   (input  wire                         CLK,
                    input  wire                         RST,
                    input  wire                         IN_FULL,
                    input  wire [(DATW<<(E_LOG-1))-1:0] DIN_A,
                    input  wire                         DINEN_A,
                    input  wire [(DATW<<(E_LOG-1))-1:0] DIN_B,
                    input  wire                         DINEN_B,
                    output wire                         FUL_A,
                    output wire                         FUL_B,
                    output wire [(DATW<<E_LOG)-1:0]     DOT,
                    output wire                         DOTEN);

  reg rst;
  always @(posedge CLK) rst <= RST;

  wire [(DATW<<E_LOG)-1:0] coupler_A_dot, coupler_B_dot;
  wire                     coupler_A_doten, coupler_B_doten;

  COUPLER #(E_LOG, DATW)
  coupler_A(CLK, rst, FUL_A, DIN_A, DINEN_A, coupler_A_dot, coupler_A_doten);
  COUPLER #(E_LOG, DATW)
  coupler_B(CLK, rst, FUL_B, DIN_B, DINEN_B, coupler_B_dot, coupler_B_doten);

  MERGE_LOGIC #(E_LOG, USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
  merge_logic(CLK, rst, IN_FULL, coupler_A_doten, coupler_A_dot, coupler_B_doten, coupler_B_dot,
              FUL_A, FUL_B, DOT, DOTEN);

endmodule


/***** A merge tree                                                       *****/
/******************************************************************************/
module MERGE_TREE #(parameter                       E_LOG      = 2,
                    parameter                       USE_IPCORE = "INTEL",
                    parameter                       FLOAT      = "no",
                    parameter                       SIGNED     = "no",
                    parameter                       DATW       = 64,
                    parameter                       KEYW       = 32)
                   (input  wire                     CLK,
                    input  wire                     RST,
                    input  wire                     IN_FULL,
                    input  wire [(DATW<<E_LOG)-1:0] DIN,
                    input  wire [(1<<E_LOG)-1:0]    DINEN,
                    output wire [(1<<E_LOG)-1:0]    FULL,
                    output wire [(DATW<<E_LOG)-1:0] DOT,
                    output wire                     DOTEN);

  genvar i, j;
  generate
    for (i=0; i<E_LOG; i=i+1) begin: level
      wire [(1<<(E_LOG-(i+1)))-1:0] node_in_full;
      wire [(DATW<<E_LOG)-1:0]      node_din;
      wire [(1<<(E_LOG-i))-1:0]     node_dinen;
      wire [(1<<(E_LOG-i))-1:0]     node_full;
      wire [(DATW<<E_LOG)-1:0]      node_dot;
      wire [(1<<(E_LOG-(i+1)))-1:0] node_doten;
      for (j=0; j<(1<<(E_LOG-(i+1))); j=j+1) begin: nodes
        MERGE_NODE #((i+1), USE_IPCORE, FLOAT, SIGNED, DATW, KEYW)
        merge_node(CLK, RST, node_in_full[j], node_din[(DATW<<(i))*(2*j+1)-1:(DATW<<(i))*(2*j)], node_dinen[2*j], node_din[(DATW<<(i))*(2*j+2)-1:(DATW<<(i))*(2*j+1)], node_dinen[2*j+1],
                   node_full[2*j], node_full[2*j+1], node_dot[(DATW<<(i+1))*(j+1)-1:(DATW<<(i+1))*j], node_doten[j]);
      end
    end
  endgenerate

  generate
    for (i=0; i<E_LOG; i=i+1) begin: connection
      if (i == 0) begin
        assign level[0].node_din   = DIN;
        assign level[0].node_dinen = DINEN;
        assign FULL                = level[0].node_full;
      end else begin
        assign level[i].node_din       = level[i-1].node_dot;
        assign level[i].node_dinen     = level[i-1].node_doten;
        assign level[i-1].node_in_full = level[i].node_full;
      end
    end
  endgenerate

  assign level[E_LOG-1].node_in_full = IN_FULL;
  assign DOT                         = level[E_LOG-1].node_dot;
  assign DOTEN                       = level[E_LOG-1].node_doten;

endmodule

`default_nettype wire
