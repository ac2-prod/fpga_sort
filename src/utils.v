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

/***** A comparator                                                       *****/
/******************************************************************************/
module COMPARATOR #(parameter              FLOAT  = "no",
                    parameter              SIGNED = "no",
                    parameter              KEYW   = 32)
                   (input  wire [KEYW-1:0] A,
                    input  wire [KEYW-1:0] B,
                    output wire            RESULT);

  generate
    if (FLOAT == "yes" || SIGNED == "yes") begin
      function comparator;
        input signed [KEYW-1:0] a;
        input signed [KEYW-1:0] b;
        comparator = (a <= b);
      endfunction
      assign RESULT = comparator(A, B);
    end else begin
      function comparator;
        input [KEYW-1:0] a;
        input [KEYW-1:0] b;
        comparator = (a <= b);
      endfunction
      assign RESULT = comparator(A, B);
    end
  endgenerate

endmodule

/***** A BlockRAM module                                                  *****/
/******************************************************************************/
module BRAM #(parameter               M_LOG      = 2,  // memory size in log scale
              parameter               DATW       = 64,
              parameter               USE_IPCORE = "INTEL")
             (input  wire             CLK,
              input  wire             WE,
              input  wire [M_LOG-1:0] RADDR,
              input  wire [M_LOG-1:0] WADDR,
              input  wire [DATW-1:0]  DIN,
              output reg  [DATW-1:0]  DOT);

  generate
    if (USE_IPCORE == "INTEL") begin
      wire [DATW-1:0] dot;
      always @(posedge CLK) DOT <= dot;
      altera_syncram #(
                       .address_aclr_b                     ("NONE"),
                       .address_reg_b                      ("CLOCK0"),
                       .clock_enable_input_a               ("BYPASS"),
                       .clock_enable_input_b               ("BYPASS"),
                       .clock_enable_output_b              ("BYPASS"),
                       .enable_ecc                         ("FALSE"),
                       .intended_device_family             ("Stratix 10"),
                       .lpm_type                           ("altera_syncram"),
                       .numwords_a                         ((1<<M_LOG)),
                       .numwords_b                         ((1<<M_LOG)),
                       .operation_mode                     ("DUAL_PORT"),
                       .outdata_aclr_b                     ("NONE"),
                       .outdata_sclr_b                     ("NONE"),
                       .outdata_reg_b                      ("CLOCK0"),
                       .power_up_uninitialized             ("FALSE"),
                       .ram_block_type                     ("M20K"),
                       .read_during_write_mode_mixed_ports ("OLD_DATA"),
                       .widthad_a                          (M_LOG),
                       .widthad_b                          (M_LOG),
                       .width_a                            (DATW),
                       .width_b                            (DATW),
                       .width_byteena_a                    (1)
                       )
      altera_syncram_component (
                                .address_a                 (WADDR),
                                .address_b                 (RADDR),
                                .clock0                    (CLK),
                                .data_a                    (DIN),
                                .wren_a                    (WE),
                                .q_b                       (dot),
                                .aclr0                     (1'b0),
                                .aclr1                     (1'b0),
                                .address2_a                (1'b1),
                                .address2_b                (1'b1),
                                .addressstall_a            (1'b0),
                                .addressstall_b            (1'b0),
                                .byteena_a                 (1'b1),
                                .byteena_b                 (1'b1),
                                .clock1                    (1'b1),
                                .clocken0                  (1'b1),
                                .clocken1                  (1'b1),
                                .clocken2                  (1'b1),
                                .clocken3                  (1'b1),
                                .data_b                    ({DATW{1'b1}}),
                                .eccencbypass              (1'b0),
                                .eccencparity              (8'b0),
                                .eccstatus                 (),
                                .q_a                       (),
                                .rden_a                    (1'b1),
                                .rden_b                    (1'b1),
                                .sclr                      (1'b0),
                                .wren_b                    (1'b0)
                                );
    end else begin
      reg [DATW-1:0] mem [(1<<M_LOG)-1:0];
      reg [DATW-1:0] o_reg;  // output register (if it is not declared, output register of BlockRAM is not activated)
      reg [DATW-1:0] m_buf;  // If it is not declared, the Quartus compiler will not infer mem[] as BlockRAM)
      always @(posedge CLK) DOT   <= o_reg;
      always @(posedge CLK) o_reg <= m_buf;
      always @(posedge CLK) m_buf <= mem[RADDR];
      always @(posedge CLK) if (WE) mem[WADDR] <= DIN;
    end
  endgenerate

endmodule


/***** A user logic taking the logarithim                                  ****/
/******************************************************************************/
module CLOG2 #(parameter               WIDTH = 32,
               parameter               CLOGW = 5)
              (input  wire             CLK,
               input  wire             RST,
               input  wire [WIDTH-1:0] I_VAL,
               input  wire             I_VLD,
               output reg  [CLOGW-1:0] O_LOG,
               output reg              O_VLD,
               output wire             READY);

  reg             state;
  reg [WIDTH-1:0] value;
  reg [CLOGW-1:0] clog2;
  reg             valid;

  always @(posedge CLK) begin
    if (RST) begin
      state <= 0;
      valid <= 0;
    end else begin
      case (state)
        1'b0: begin
          if (I_VLD) begin
            state <= 1;
            valid <= 0;
          end
        end
        1'b1: begin
          state <= (value != 0);
          valid <= (value == 0);
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    value <= (I_VLD) ? I_VAL - 1 : (value >> 1);
  end
  always @(posedge CLK) begin
    if      (I_VLD)      clog2 <= 0;
    else if (value != 0) clog2 <= clog2 + 1;
  end

  always @(posedge CLK) O_LOG <= clog2;
  always @(posedge CLK) O_VLD <= (RST) ? 0 : valid;
  assign READY = ~state;  // (state == 0);

endmodule


/***** A module to convert a float to an int expression for sorting        ****/
/******************************************************************************/
module FLOAT2INT #(parameter                  IO_WIDTH = 512,
                   parameter                  PAYW     = 32,
                   parameter                  KEYW     = 32)
                  (input  wire                CLK,
                   input  wire                RST,
                   input  wire [IO_WIDTH-1:0] DIN,
                   input  wire                DINEN,
                   output wire [IO_WIDTH-1:0] DOT,
                   output wire                DOTEN);

  localparam [63:0] DATW    = (PAYW + KEYW);
  localparam [63:0] NUMDATA = IO_WIDTH / DATW;

  wire [IO_WIDTH-1:0] dot;
  genvar i;
  generate
    for (i=0; i<NUMDATA; i=i+1) begin: convert
      // key
      reg            is_neg_0;  always @(posedge CLK) is_neg_0  <= DIN[(KEYW+DATW*i)-1];
      reg            negative;  always @(posedge CLK) negative  <= is_neg_0;
      reg [KEYW-1:0] inverted;  always @(posedge CLK) inverted  <= ~{1'b0, DIN[(KEYW+DATW*i)-2:DATW*i]};
      reg [KEYW-1:0] plus_rslt; always @(posedge CLK) plus_rslt <= inverted + 1;
      reg [KEYW-1:0] k_tmp_0;   always @(posedge CLK) k_tmp_0   <= DIN[(KEYW+DATW*i)-1:DATW*i];
      reg [KEYW-1:0] k_tmp_1;   always @(posedge CLK) k_tmp_1   <= k_tmp_0;
      reg [KEYW-1:0] key;       always @(posedge CLK) key       <= (negative) ? plus_rslt : k_tmp_1;
      if (PAYW == 0) begin
        // data
        assign dot[DATW*(i+1)-1:DATW*i] = key;
      end else begin
        // payload
        reg [PAYW-1:0] p_tmp_0; always @(posedge CLK) p_tmp_0   <= DIN[DATW*(i+1)-1:(KEYW+DATW*i)];
        reg [PAYW-1:0] p_tmp_1; always @(posedge CLK) p_tmp_1   <= p_tmp_0;
        reg [PAYW-1:0] payload; always @(posedge CLK) payload   <= p_tmp_1;
        // data
        assign dot[DATW*(i+1)-1:DATW*i] = {payload, key};
      end
    end
  endgenerate

  reg doten_tmp_0; always @(posedge CLK) doten_tmp_0 <= (RST) ? 0 : DINEN;
  reg doten_tmp_1; always @(posedge CLK) doten_tmp_1 <= (RST) ? 0 : doten_tmp_0;
  reg doten;       always @(posedge CLK) doten       <= (RST) ? 0 : doten_tmp_1;

  // Output
  assign DOT   = dot;
  assign DOTEN = doten;

endmodule


/***** A module to convert an int expression to a float                    ****/
/******************************************************************************/
module INT2FLOAT #(parameter                  IO_WIDTH = 512,
                   parameter                  PAYW     = 32,
                   parameter                  KEYW     = 32)
                  (input  wire                CLK,
                   input  wire                RST,
                   input  wire [IO_WIDTH-1:0] DIN,
                   input  wire                DINEN,
                   output wire [IO_WIDTH-1:0] DOT,
                   output wire                DOTEN);

  localparam [63:0] DATW    = (PAYW + KEYW);
  localparam [63:0] NUMDATA = IO_WIDTH / DATW;

  wire [IO_WIDTH-1:0] dot;
  genvar i;
  generate
    for (i=0; i<NUMDATA; i=i+1) begin: convert
      // key
      reg            is_neg_0;   always @(posedge CLK) is_neg_0   <= DIN[(KEYW+DATW*i)-1];
      reg            negative;   always @(posedge CLK) negative   <= is_neg_0;
      reg [KEYW-1:0] minus_rslt; always @(posedge CLK) minus_rslt <= DIN[(KEYW+DATW*i)-1:DATW*i] - 1;
      reg [KEYW-1:0] inverted;   always @(posedge CLK) inverted   <= ~minus_rslt;
      reg [KEYW-1:0] k_tmp_0;    always @(posedge CLK) k_tmp_0    <= DIN[(KEYW+DATW*i)-1:DATW*i];
      reg [KEYW-1:0] k_tmp_1;    always @(posedge CLK) k_tmp_1    <= k_tmp_0;
      reg [KEYW-1:0] key;        always @(posedge CLK) key        <= (negative) ? {1'b1, inverted[KEYW-2:0]} : k_tmp_1;
      if (PAYW == 0) begin
        // data
        assign dot[DATW*(i+1)-1:DATW*i] = key;
      end else begin
        // payload
        reg [PAYW-1:0] p_tmp_0;  always @(posedge CLK) p_tmp_0    <= DIN[DATW*(i+1)-1:(KEYW+DATW*i)];
        reg [PAYW-1:0] p_tmp_1;  always @(posedge CLK) p_tmp_1    <= p_tmp_0;
        reg [PAYW-1:0] payload;  always @(posedge CLK) payload    <= p_tmp_1;
        // data
        assign dot[DATW*(i+1)-1:DATW*i] = {payload, key};
      end
    end
  endgenerate

  reg doten_tmp_0; always @(posedge CLK) doten_tmp_0 <= (RST) ? 0 : DINEN;
  reg doten_tmp_1; always @(posedge CLK) doten_tmp_1 <= (RST) ? 0 : doten_tmp_0;
  reg doten;       always @(posedge CLK) doten       <= (RST) ? 0 : doten_tmp_1;

  // Output
  assign DOT   = dot;
  assign DOTEN = doten;

endmodule


/***** A data packer                                                       ****/
/******************************************************************************/
module DATA_PACKER #(parameter                 I_WIDTH  = 128,
                     parameter                 O_WIDTH  = 512,
                     parameter                 PACK_LOG = 2)
                    (input  wire               CLK,
                     input  wire               RST,
                     input  wire [I_WIDTH-1:0] DIN,
                     input  wire               DINEN,
                     output wire [O_WIDTH-1:0] DOT,
                     output wire               DOTEN);

  generate
    if (I_WIDTH == O_WIDTH) begin
      assign DOT   = DIN;
      assign DOTEN = DINEN;
    end else begin
      reg [O_WIDTH-1 :0] data_pack;
      reg [PACK_LOG-1:0] data_pack_cnt;
      reg                data_pack_en;
      always @(posedge CLK) begin
        if (DINEN) data_pack <= {DIN, data_pack[O_WIDTH-1:I_WIDTH]};
      end
      always @(posedge CLK) begin
        if      (RST)   data_pack_cnt <= 0;
        else if (DINEN) data_pack_cnt <= data_pack_cnt + 1;
      end
      always @(posedge CLK) data_pack_en <= &{DINEN, data_pack_cnt};
      assign DOT   = data_pack;
      assign DOTEN = data_pack_en;
    end
  endgenerate

endmodule


/***** A data slicer                                                       ****/
/******************************************************************************/
module DATA_SLICER #(parameter                 I_WIDTH    = 512,
                     parameter                 O_WIDTH    = 64,
                     parameter                 SLICE_LOG  = 3,
                     parameter                 USE_IPCORE = "INTEL")
                    (input  wire               CLK,
                     input  wire               RST,
                     input  wire               STALL,
                     input  wire [I_WIDTH-1:0] DIN,
                     input  wire               DINEN,
                     output wire [O_WIDTH-1:0] DOT,
                     output wire               DOTEN,
                     output wire               RDY);

  reg [O_WIDTH-1:0] dot;
  reg               doten;
  reg               shifting;
  reg [SLICE_LOG:0] shift_cnt;
  reg [I_WIDTH-1:0] shift_data;

  always @(posedge CLK) begin
    if (RST) begin
      shifting <= 0;
    end else begin
      case (shifting)
        1'b0: shifting <= DINEN;
        1'b1: shifting <= ~shift_cnt[SLICE_LOG];
      endcase
    end
  end

  always @(posedge CLK) begin
    case (shifting)
      1'b0: begin
        dot        <= DIN[O_WIDTH-1:0];
        shift_cnt  <= 2;  // 2 is for shift_cnt[SLICE_LOG]
        shift_data <= {{(O_WIDTH){1'b0}}, DIN[I_WIDTH-1:O_WIDTH]};
      end
      1'b1: begin
        dot        <= shift_data[O_WIDTH-1:0];
        shift_cnt  <= shift_cnt + 1;
        shift_data <= {{(O_WIDTH){1'b0}}, shift_data[I_WIDTH-1:O_WIDTH]};
      end
    endcase
  end

  always @(posedge CLK) begin
    doten <= (RST) ? 0 : |{shifting, DINEN};
  end

  wire               o_buf_enq;
  wire               o_buf_deq;
  wire [O_WIDTH-1:0] o_buf_din;
  wire [O_WIDTH-1:0] o_buf_dot;
  wire               o_buf_emp;
  wire               o_buf_ful;
  wire [SLICE_LOG+1:0] o_buf_cnt;

  assign o_buf_enq = doten;
  assign o_buf_deq = ~|{STALL, o_buf_emp};
  assign o_buf_din = dot;

  generate
    if (SLICE_LOG > 3) begin
      BS_FIFO #(SLICE_LOG+1, O_WIDTH, USE_IPCORE)
      o_buf(CLK, RST, o_buf_enq, o_buf_deq, o_buf_din,
            o_buf_dot, o_buf_emp, o_buf_ful, o_buf_cnt);
      assign RDY = ~|{shifting, o_buf_cnt[SLICE_LOG+1:3]};
    end else begin
      SRL_FIFO #(SLICE_LOG+1, O_WIDTH)
      o_buf(CLK, RST, o_buf_enq, o_buf_deq, o_buf_din,
            o_buf_dot, o_buf_emp, o_buf_ful, o_buf_cnt);
      assign RDY = ~|{shifting, o_buf_cnt[SLICE_LOG+1:SLICE_LOG]};
    end
  endgenerate

  assign DOT   = o_buf_dot;
  assign DOTEN = o_buf_deq;

endmodule


/***** A write buffer for AVALON_MM_WRITE                                  ****/
/******************************************************************************/
module WRITE_BUFFER #(parameter                 I_WIDTH             = 128,
                      parameter                 O_WIDTH             = 512,
                      parameter                 FIFO_SIZE           = 7,
                      parameter                 WRITE_REQ_THRESHOLD = 16,
                      parameter                 USE_IPCORE          = "INTEL")
                     (input  wire               CLK,
                      input  wire               RST,
                      input  wire [I_WIDTH-1:0] DIN,
                      input  wire               DINEN,
                      input  wire               DEQ,
                      output wire [O_WIDTH-1:0] DOT,
                      output wire               FULL,
                      output wire               WRITE_REQ);

  function integer clog2;
    input integer value;
    begin
      value = value - 1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value >> 1;
    end
  endfunction

  wire               i_buf_enq;
  wire               i_buf_deq;
  wire [I_WIDTH-1:0] i_buf_din;
  wire [I_WIDTH-1:0] i_buf_dot;
  wire               i_buf_emp;
  wire               i_buf_ful;
  wire [3:0]         i_buf_cnt;

  wire               o_buf_enq;
  wire               o_buf_deq;
  wire [O_WIDTH-1:0] o_buf_din;
  wire [O_WIDTH-1:0] o_buf_dot;
  wire               o_buf_emp;
  wire               o_buf_ful;
  wire [FIFO_SIZE:0] o_buf_cnt;

  reg                write_request;

  assign i_buf_enq = DINEN;
  assign i_buf_din = DIN;

  assign o_buf_deq = DEQ;

  SRL_FIFO #(3, I_WIDTH)  // 8-entry FIFO
  i_buf(CLK, RST, i_buf_enq, i_buf_deq, i_buf_din,
        i_buf_dot, i_buf_emp, i_buf_ful, i_buf_cnt);

  generate
    if (I_WIDTH <= O_WIDTH) begin
      localparam PACK_LOG = clog2(O_WIDTH / I_WIDTH);
      wire [I_WIDTH-1:0] data_packer_din;
      wire               data_packer_dinen;
      wire [O_WIDTH-1:0] data_packer_dot;
      wire               data_packer_doten;
      assign i_buf_deq         = ~|{i_buf_emp, o_buf_ful};
      assign data_packer_din   = i_buf_dot;
      assign data_packer_dinen = i_buf_deq;
      DATA_PACKER #(I_WIDTH, O_WIDTH, PACK_LOG)
      data_packer(CLK, RST, data_packer_din, data_packer_dinen,
                  data_packer_dot, data_packer_doten);
      assign o_buf_enq         = data_packer_doten;
      assign o_buf_din         = data_packer_dot;
    end else begin
      localparam SLICE_LOG = clog2(I_WIDTH / O_WIDTH);
      wire [I_WIDTH-1:0] data_slicer_din;
      wire               data_slicer_dinen;
      wire [O_WIDTH-1:0] data_slicer_dot;
      wire               data_slicer_doten;
      wire               data_slicer_rdy;
      assign i_buf_deq         = &{data_slicer_rdy, ~i_buf_emp};
      assign data_slicer_din   = i_buf_dot;
      assign data_slicer_dinen = i_buf_deq;
      DATA_SLICER #(I_WIDTH, O_WIDTH, SLICE_LOG, USE_IPCORE)
      data_slicer(CLK, RST, o_buf_ful, data_slicer_din, data_slicer_dinen,
                  data_slicer_dot, data_slicer_doten, data_slicer_rdy);
      assign o_buf_enq         = data_slicer_doten;
      assign o_buf_din         = data_slicer_dot;
    end
  endgenerate

  // SRL_FIFO #(FIFO_SIZE, O_WIDTH)
  BS_FIFO #(FIFO_SIZE, O_WIDTH, USE_IPCORE)
  o_buf(CLK, RST, o_buf_enq, o_buf_deq, o_buf_din,
        o_buf_dot, o_buf_emp, o_buf_ful, o_buf_cnt);

  always @(posedge CLK) begin
    // |o_buf_cnt[FIFO_SIZE:clog2(WRITE_REQ_THRESHOLD)] means (o_buf_cnt >= WRITE_REQ_THRESHOLD);
    write_request <= |o_buf_cnt[FIFO_SIZE:clog2(WRITE_REQ_THRESHOLD)];
  end

  // Output
  assign DOT       = o_buf_dot;
  assign FULL      = |i_buf_cnt[3:2];
  assign WRITE_REQ = write_request;

endmodule


/***** A multiply adder                                                   *****/
/******************************************************************************/
module MADD_KERNEL #(parameter                 LATENCY = 5,
                     parameter                 AX_DATW = 64,
                     parameter                 AY_DATW = 64,
                     parameter                 AZ_DATW = 64,
                     parameter                 OT_DATW = 128)
                    (input  wire               CLK,
                     input  wire [AX_DATW-1:0] AX,
                     input  wire [AY_DATW-1:0] AY,
                     input  wire [AZ_DATW-1:0] AZ,
                     output wire [OT_DATW-1:0] OT);

  // Input registers
  reg [AX_DATW-1:0] i_ax; always @(posedge CLK) i_ax <= AX;
  reg [AY_DATW-1:0] i_ay; always @(posedge CLK) i_ay <= AY;
  reg [AZ_DATW-1:0] i_az; always @(posedge CLK) i_az <= AZ;

  // pipeline registers
  reg [AX_DATW-1:0] ax_pd  [(LATENCY-2)-1:0];
  reg [OT_DATW-1:0] mul_pd [(LATENCY-2)-1:0];

  integer p;
  always @(posedge CLK) begin
    ax_pd[0]  <= i_ax;
    mul_pd[0] <= i_ay * i_az;
    for (p=1; p<(LATENCY-2); p=p+1) begin
      ax_pd[p]  <= ax_pd[p-1];
      mul_pd[p] <= mul_pd[p-1];
    end
  end

  // ax + mul_rslt (stored in output register)
  reg [OT_DATW-1:0] add_rslt;
  generate
    if (OT_DATW >= AX_DATW) begin
      always @(posedge CLK) begin
        add_rslt <= {{(OT_DATW-AX_DATW){1'b0}}, ax_pd[(LATENCY-2)-1]} + mul_pd[(LATENCY-2)-1];
      end
    end else begin
      always @(posedge CLK) begin
        add_rslt <= ax_pd[(LATENCY-2)-1] + mul_pd[(LATENCY-2)-1];
      end
    end
  endgenerate

  // Output
  assign OT = add_rslt;

endmodule


module MADD #(parameter                 LATENCY = 5,
              parameter                 AX_DATW = 64,
              parameter                 AY_DATW = 64,
              parameter                 AZ_DATW = 64,
              parameter                 OT_DATW = 128)
             (input  wire               CLK,
              input  wire               RST,
              input  wire               I_EN,
              input  wire [AX_DATW-1:0] AX,
              input  wire [AY_DATW-1:0] AY,
              input  wire [AZ_DATW-1:0] AZ,
              output wire [OT_DATW-1:0] OT,
              output wire               O_EN);

  reg [LATENCY-1:0] pc;

  integer p;
  always @(posedge CLK) begin
    if (RST) begin
      pc <= 0;
    end else begin
      pc[0] <= I_EN;
      for (p=1; p<LATENCY; p=p+1) begin
        pc[p] <= pc[p-1];
      end
    end
  end

  MADD_KERNEL #(LATENCY, AX_DATW, AY_DATW, AZ_DATW, OT_DATW)
  madd_kernel(CLK, AX, AY, AZ, OT);

  assign O_EN = pc[LATENCY-1];

endmodule

`default_nettype wire
