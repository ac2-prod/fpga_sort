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

/***** A control logic of memory load access from an RTL module in OpenCL *****/
/******************************************************************************/
module AVALON_MM_READ #(parameter                             MAXBURST_LOG   = 4,
                        parameter                             READNUM_SIZE   = 32, // how many data in 512 bit are loaded (log scale)
                        parameter                             DRAM_ADDRSPACE = 64,
                        parameter                             DRAM_DATAWIDTH = 512)
                       (input  wire                           CLK,
                        input  wire                           RST,
                        ////////// User logic interface ports ///////////////
                        input  wire                           READ_REQ,
                        input  wire [DRAM_ADDRSPACE-1     :0] READ_INITADDR,
                        input  wire [READNUM_SIZE         :0] READ_NUM,
                        output wire [DRAM_DATAWIDTH-1     :0] READ_DATA,
                        output wire                           READ_DATAEN,
                        output wire                           READ_RDY,
                        ////////// Avalon-MM interface ports for read ///////
                        input  wire [DRAM_DATAWIDTH-1     :0] AVALON_MM_READDATA,
                        input  wire                           AVALON_MM_READDATAVALID,
                        input  wire                           AVALON_MM_WAITREQUEST,
                        output wire [DRAM_ADDRSPACE-1     :0] AVALON_MM_ADDRESS,
                        output wire                           AVALON_MM_READ,
                        output wire                           AVALON_MM_WRITE,      // unused
                        input  wire                           AVALON_MM_WRITEACK,   // unused
                        output wire [DRAM_DATAWIDTH-1     :0] AVALON_MM_WRITEDATA,  // unused
                        output wire [(DRAM_DATAWIDTH>>3)-1:0] AVALON_MM_BYTEENABLE,
                        output wire [MAXBURST_LOG         :0] AVALON_MM_BURSTCOUNT);

  localparam MAXBURST_NUM  = (1 << MAXBURST_LOG);
  localparam ACCESS_STRIDE = ((DRAM_DATAWIDTH>>3) << MAXBURST_LOG);

  reg [1:0]                         state;
  reg                               busy;
  reg [DRAM_ADDRSPACE-1:0]          address;
  reg                               read_request;
  reg [MAXBURST_LOG:0]              burstcount;
  reg [MAXBURST_LOG:0]              last_burstcount;
  reg [READNUM_SIZE-MAXBURST_LOG:0] burstnum;  // # of burst accesses operated

  // state machine for read
  always @(posedge CLK) begin
    if (RST) begin
      state        <= 0;
      busy         <= 0;
      read_request <= 0;
    end else begin
      case (state)
        ///// wait read request /////
        0: begin
          if (READ_REQ) begin
            state <= 1;
            busy  <= 1;
          end
        end
        ///// send read request /////
        1: begin
          state        <= 2;
          read_request <= 1;
        end
        ///// read transfer     /////
        2: begin
          if (!AVALON_MM_WAITREQUEST) begin
            state        <= (burstnum != 1);  // (burstnum == 1) ? 0 : 1;
            busy         <= (burstnum != 1);
            read_request <= 0;
          end
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    case (state)
      2'b00: begin
        address  <= READ_INITADDR;
        burstnum <= (READ_NUM + (MAXBURST_NUM-1)) >> MAXBURST_LOG;
      end
      2'b10: begin
        if (!AVALON_MM_WAITREQUEST) begin
          address  <= address + ACCESS_STRIDE;
          burstnum <= burstnum - 1;
        end
      end
    endcase
  end
  always @(posedge CLK) begin
    burstcount <= (burstnum == 1) ? last_burstcount : MAXBURST_NUM;
  end
  always @(posedge CLK) begin
    if (READ_REQ) begin
      // ~|READ_NUM[MAXBURST_LOG-1:0] is (READ_NUM[MAXBURST_LOG-1:0] == 0)
      last_burstcount <= (~|READ_NUM[MAXBURST_LOG-1:0]) ? MAXBURST_NUM : {1'b0, READ_NUM[MAXBURST_LOG-1:0]};
    end
  end

  // Output to user logic interface
  assign READ_DATA            = AVALON_MM_READDATA;
  assign READ_DATAEN          = AVALON_MM_READDATAVALID;
  assign READ_RDY             = ~busy;

  // Output to Avalon-MM interface
  assign AVALON_MM_ADDRESS    = address;
  assign AVALON_MM_READ       = read_request;
  assign AVALON_MM_WRITE      = 0;
  assign AVALON_MM_WRITEDATA  = 0;
  assign AVALON_MM_BYTEENABLE = {(DRAM_DATAWIDTH>>3){1'b1}};
  assign AVALON_MM_BURSTCOUNT = burstcount;

endmodule


/***** A control logic of memory store access from an RTL module in OpenCL ****/
/******************************************************************************/
module AVALON_MM_WRITE #(parameter                             MAXBURST_LOG   = 4,
                         parameter                             WRITENUM_SIZE  = 32, // how many data in 512 bit are stored (log scale)
                         parameter                             DRAM_ADDRSPACE = 64,
                         parameter                             DRAM_DATAWIDTH = 512)
                        (input  wire                           CLK,
                         input  wire                           RST,
                         ////////// User logic interface ports ///////////////
                         input  wire                           WRITE_REQ,
                         input  wire [DRAM_ADDRSPACE-1     :0] WRITE_INITADDR,
                         input  wire [WRITENUM_SIZE        :0] WRITE_NUM,
                         input  wire [DRAM_DATAWIDTH-1     :0] WRITE_DATA,
                         output wire                           WRITE_DATA_ACCEPTABLE,
                         output wire                           WRITE_RDY,
                         output wire                           WRITE_REQ_DONE,
                         ////////// Avalon-MM interface ports for write //////
                         input  wire [DRAM_DATAWIDTH-1     :0] AVALON_MM_READDATA,      // unused
                         input  wire                           AVALON_MM_READDATAVALID, // unused
                         input  wire                           AVALON_MM_WAITREQUEST,
                         output wire [DRAM_ADDRSPACE-1     :0] AVALON_MM_ADDRESS,
                         output wire                           AVALON_MM_READ,          // unused
                         output wire                           AVALON_MM_WRITE,
                         input  wire                           AVALON_MM_WRITEACK,
                         output wire [DRAM_DATAWIDTH-1     :0] AVALON_MM_WRITEDATA,
                         output wire [(DRAM_DATAWIDTH>>3)-1:0] AVALON_MM_BYTEENABLE,
                         output wire [MAXBURST_LOG         :0] AVALON_MM_BURSTCOUNT);

  localparam MAXBURST_NUM  = (1 << MAXBURST_LOG);
  localparam ACCESS_STRIDE = ((DRAM_DATAWIDTH>>3) << MAXBURST_LOG);

  reg [1:0]                          state;
  reg                                busy;
  reg [DRAM_ADDRSPACE-1:0]           address;
  reg                                write_request;
  reg [MAXBURST_LOG:0]               remaining_datanum;
  reg [MAXBURST_LOG:0]               burstcount;
  reg [MAXBURST_LOG:0]               last_burstcount;
  reg [WRITENUM_SIZE-MAXBURST_LOG:0] burstnum;  // # of burst accesses operated

  // state machine for write
  always @(posedge CLK) begin
    if (RST) begin
      state         <= 0;
      busy          <= 0;
      write_request <= 0;
    end else begin
      case (state)
        ///// wait write request /////
        0: begin
          if (WRITE_REQ) begin
            state <= 1;
            busy  <= 1;
          end
        end
        ///// send write request /////
        1: begin
          state         <= 2;
          write_request <= 1;
        end
        ///// write transfer     /////
        2: begin
          if (&{(!AVALON_MM_WAITREQUEST), (remaining_datanum == 1)}) begin
            state         <= {(burstnum == 1), 1'b1};  // (burstnum == 1) ? 3 : 1
            write_request <= 0;
          end
        end
        ///// wait writeack     //////
        3: begin
          if (AVALON_MM_WRITEACK) begin
            state <= 0;
            busy  <= 0;
          end
        end
      endcase
    end
  end
  always @(posedge CLK) begin
    case (state)
      2'b00: begin
        address  <= WRITE_INITADDR;
        burstnum <= (WRITE_NUM + (MAXBURST_NUM-1)) >> MAXBURST_LOG;
      end
      2'b10: begin
        if (&{(!AVALON_MM_WAITREQUEST), (remaining_datanum == 1)}) begin
          address  <= address + ACCESS_STRIDE;
          burstnum <= burstnum - 1;
        end
      end
    endcase
  end
  always @(posedge CLK) begin
    case (state)
      2'b01: begin
        remaining_datanum <= (burstnum == 1) ? last_burstcount : MAXBURST_NUM;
      end
      2'b10: begin
        if (!AVALON_MM_WAITREQUEST) begin
          remaining_datanum <= remaining_datanum - 1;
        end
      end
    endcase
  end
  always @(posedge CLK) begin
    burstcount <= (burstnum == 1) ? last_burstcount : MAXBURST_NUM;
  end
  always @(posedge CLK) begin
    if (WRITE_REQ) begin
      // ~|WRITE_NUM[MAXBURST_LOG-1:0] is (WRITE_NUM[MAXBURST_LOG-1:0] == 0)
      last_burstcount <= (~|WRITE_NUM[MAXBURST_LOG-1:0]) ? MAXBURST_NUM : {1'b0, WRITE_NUM[MAXBURST_LOG-1:0]};
    end
  end

  // Output to user logic interface
  assign WRITE_DATA_ACCEPTABLE = &{~AVALON_MM_WAITREQUEST, write_request};
  assign WRITE_RDY             = ~busy;
  assign WRITE_REQ_DONE        = &{state, AVALON_MM_WRITEACK};  // &{(state == 3), AVALON_MM_WRITEACK};

  // Output to Avalon-MM interface
  assign AVALON_MM_ADDRESS     = address;
  assign AVALON_MM_READ        = 0;
  assign AVALON_MM_WRITE       = write_request;
  assign AVALON_MM_WRITEDATA   = WRITE_DATA;
  assign AVALON_MM_BYTEENABLE  = {(DRAM_DATAWIDTH>>3){1'b1}};
  assign AVALON_MM_BURSTCOUNT  = burstcount;

endmodule

`default_nettype wire
