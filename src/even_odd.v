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

/***** Compare-and-exchange (CAE)                                         *****/
/******************************************************************************/
module CAE #(parameter              FLOAT  = "no",
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


/***** Compare-and-exchange (CAE) for keys                                *****/
/******************************************************************************/
module K_CAE #(parameter              FLOAT  = "no",
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


/***** Do exchange (CAE) for payloads                                     *****/
/******************************************************************************/
module P_EXCHANGE #(parameter              PAYW = 32)
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


/***** BOX                                                                *****/
/******************************************************************************/
module BOX #(parameter                       P_LOG  = 4,
             parameter                       FLOAT  = "no",
             parameter                       SIGNED = "no",
             parameter                       DATW   = 64,
             parameter                       KEYW   = 32)
            (input  wire                     CLK,
             input  wire [(DATW<<P_LOG)-1:0] DIN,
             output wire [(DATW<<P_LOG)-1:0] DOT);

  localparam PAYW = DATW - KEYW;

  genvar i, j, k;
  generate
    if (PAYW == 0) begin
      reg [(DATW<<P_LOG)-1:0] pd [P_LOG-1:0];  // pipeline regester for data
      for (i=0; i<P_LOG; i=i+1) begin: stage
        wire [(DATW<<P_LOG)-1:0] dot;
        if (i == 0) begin
          for (j=0; j<(1<<(P_LOG-1)); j=j+1) begin: caes
            CAE #(FLOAT, SIGNED, DATW, KEYW) cae(CLK,
                                                 DIN[DATW*(j+1)-1:DATW*j],
                                                 DIN[DATW*((j+1)+(1<<(P_LOG-1)))-1:DATW*(j+(1<<(P_LOG-1)))],
                                                 dot[DATW*(j+1)-1:DATW*j],
                                                 dot[DATW*((j+1)+(1<<(P_LOG-1)))-1:DATW*(j+(1<<(P_LOG-1)))]);
          end
          always @(posedge CLK) pd[i] <= dot;
        end else begin
          for (k=0; k<((1<<i)-1); k=k+1) begin: blocks
            for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: caes
              CAE #(FLOAT, SIGNED, DATW, KEYW) cae(CLK,
                                                   pd[i-1][DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                                                   pd[i-1][DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                                                   dot[DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                                                   dot[DATW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:DATW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))]);
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
          for (j=0; j<(1<<(P_LOG-1)); j=j+1) begin: k_caes
            wire o_cmp;
            wire i_cmp;  // input of P_EXCHANGE
            K_CAE #(FLOAT, SIGNED, KEYW) k_cae(CLK,
                                               i_key[KEYW*(j+1)-1:KEYW*j],
                                               i_key[KEYW*((j+1)+(1<<(P_LOG-1)))-1:KEYW*(j+(1<<(P_LOG-1)))],
                                               o_key[KEYW*(j+1)-1:KEYW*j],
                                               o_key[KEYW*((j+1)+(1<<(P_LOG-1)))-1:KEYW*(j+(1<<(P_LOG-1)))],
                                               o_cmp);
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
          always @(posedge CLK) k_preg[i] <= o_key;
          // payload
          for (j=0; j<(1<<(P_LOG-1)); j=j+1) begin: p_exchanges
            P_EXCHANGE #(PAYW) p_exchange(k_caes[j].i_cmp,
                                          p_sreg[P_LOG-1][PAYW*(j+1)-1:PAYW*j],
                                          p_sreg[P_LOG-1][PAYW*((j+1)+(1<<(P_LOG-1)))-1:PAYW*(j+(1<<(P_LOG-1)))],
                                          o_payload[PAYW*(j+1)-1:PAYW*j],
                                          o_payload[PAYW*((j+1)+(1<<(P_LOG-1)))-1:PAYW*(j+(1<<(P_LOG-1)))]);
          end
          always @(posedge CLK) p_preg[i] <= o_payload;
        end else begin
          // key
          for (k=0; k<((1<<i)-1); k=k+1) begin: k_blocks
            for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: k_caes
              wire o_cmp;
              wire i_cmp;  // input of P_EXCHANGE
              K_CAE #(FLOAT, SIGNED, KEYW) k_cae(CLK,
                                                 k_preg[i-1][KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                                                 k_preg[i-1][KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                                                 o_key[KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                                                 o_key[KEYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:KEYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                                                 o_cmp);
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
            for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: p_exchanges
              P_EXCHANGE #(PAYW) p_exchange(k_blocks[k].k_caes[j].i_cmp,
                                            p_preg[i-1][PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                                            p_preg[i-1][PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))],
                                            o_payload[PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1))))],
                                            o_payload[PAYW*((j+1)+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))-1:PAYW*(j+(k*(1<<(P_LOG-i)))+(1<<(P_LOG-(i+1)))+(1<<(P_LOG-(i+1))))]);
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


/***** Sorting Network                                                    *****/
/******************************************************************************/
module EVEN_ODD #(parameter                       P_LOG = 4,
                  parameter                       FLOAT  = "no",
                  parameter                       SIGNED = "no",
                  parameter                       DATW  = 64,
                  parameter                       KEYW  = 32)
                 (input  wire                     CLK,
                  input  wire                     RST,
                  input  wire [(DATW<<P_LOG)-1:0] DIN,
                  input  wire                     DINEN,
                  output wire [(DATW<<P_LOG)-1:0] DOT,
                  output wire                     DOTEN);


  // Input
  ////////////////////////////////////////////////////////////////////////////////////////////////
  reg [(DATW<<P_LOG)-1:0] din;   always @(posedge CLK) din   <= DIN;
  reg                     dinen; always @(posedge CLK) dinen <= (RST) ? 0 : DINEN;


  // Core
  ////////////////////////////////////////////////////////////////////////////////////////////////
  reg pc [(P_LOG*(P_LOG+1))-1:0];  // pipeline regester for control

  genvar i, j;
  generate
    for (i=0; i<P_LOG; i=i+1) begin: level
      wire [(DATW<<P_LOG)-1:0] box_din;
      wire [(DATW<<P_LOG)-1:0] box_dot;
      for (j=0; j<(1<<(P_LOG-(i+1))); j=j+1) begin: boxes
        BOX #((i+1), FLOAT, SIGNED, DATW, KEYW)
        box(CLK, box_din[DATW*(1<<(i+1))*(j+1)-1:DATW*(1<<(i+1))*j], box_dot[DATW*(1<<(i+1))*(j+1)-1:DATW*(1<<(i+1))*j]);
      end
    end
  endgenerate

  generate
    for (i=0; i<P_LOG; i=i+1) begin: connection
      if (i == 0) assign level[i].box_din = din;
      else        assign level[i].box_din = level[i-1].box_dot;
    end
  endgenerate

  integer p;
  always @(posedge CLK) begin
    if (RST) begin
      for (p=0; p<(P_LOG*(P_LOG+1)); p=p+1) pc[p] <= 0;
    end else begin
      pc[0] <= dinen;
      for (p=1; p<(P_LOG*(P_LOG+1)); p=p+1) pc[p] <= pc[p-1];
    end
  end


  // Output
  ////////////////////////////////////////////////////////////////////////////////////////////////
  assign DOT   = level[P_LOG-1].box_dot;
  assign DOTEN = pc[(P_LOG*(P_LOG+1))-1];

endmodule

`default_nettype wire
