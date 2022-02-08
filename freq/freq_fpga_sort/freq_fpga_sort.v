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

/* memory access parameters */
`define MAXBURST_LOG       (4)
`define WRITENUM_SIZE      (5)
`define DRAM_ADDRSPACE    (64)
`define DRAM_DATAWIDTH   (512)
/* parameters for hybrid sorter's configuration */
`define W_LOG              (3)
`define P_LOG              (4)
`define E_LOG              (2)
`define M_LOG              (2)
`define USE_IPCORE   ("INTEL")
`define FLOAT           ("no")
`define SIGNED          ("no")
`define PAYW              (32)
`define KEYW              (32)
`define NUMW              (32)


module freq_fpga_sort(
                      /* global clock and low-actived reset */
                      input  wire                            clock,
                      input  wire                            resetn,
                      /* mapped to arguments from cl code */
                      input  wire [`DRAM_ADDRSPACE-1     :0] cl_dummy,      // *dummy
                      input  wire [`DRAM_ADDRSPACE-1     :0] cl_dst_addr,   // dst_addr
                      input  wire [`DRAM_ADDRSPACE-1     :0] cl_src_addr,   // src_addr
                      input  wire [`NUMW-1               :0] cl_numdata,    // numdata
                      output wire [ 31:0]                    m_output_value,  // *C
                      /* Avalon-ST Interface */
                      output wire                            m_ready_out,
                      input  wire                            m_valid_in,
                      output wire                            m_valid_out,
                      input  wire                            m_ready_in,
                      /* Avalon-MM Interface for read */
                      // this part will be automatically generated
                      // Region 0
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_0_readdata,
                      input  wire                            src_0_readdatavalid,
                      input  wire                            src_0_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_0_address,
                      output wire                            src_0_read,
                      output wire                            src_0_write,
                      input  wire                            src_0_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_0_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_0_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_0_burstcount,
                      // Region 1
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_1_readdata,
                      input  wire                            src_1_readdatavalid,
                      input  wire                            src_1_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_1_address,
                      output wire                            src_1_read,
                      output wire                            src_1_write,
                      input  wire                            src_1_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_1_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_1_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_1_burstcount,
                      // Region 2
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_2_readdata,
                      input  wire                            src_2_readdatavalid,
                      input  wire                            src_2_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_2_address,
                      output wire                            src_2_read,
                      output wire                            src_2_write,
                      input  wire                            src_2_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_2_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_2_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_2_burstcount,
                      // Region 3
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_3_readdata,
                      input  wire                            src_3_readdatavalid,
                      input  wire                            src_3_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_3_address,
                      output wire                            src_3_read,
                      output wire                            src_3_write,
                      input  wire                            src_3_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_3_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_3_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_3_burstcount,
                      // Region 4
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_4_readdata,
                      input  wire                            src_4_readdatavalid,
                      input  wire                            src_4_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_4_address,
                      output wire                            src_4_read,
                      output wire                            src_4_write,
                      input  wire                            src_4_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_4_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_4_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_4_burstcount,
                      // Region 5
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_5_readdata,
                      input  wire                            src_5_readdatavalid,
                      input  wire                            src_5_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_5_address,
                      output wire                            src_5_read,
                      output wire                            src_5_write,
                      input  wire                            src_5_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_5_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_5_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_5_burstcount,
                      // Region 6
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_6_readdata,
                      input  wire                            src_6_readdatavalid,
                      input  wire                            src_6_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_6_address,
                      output wire                            src_6_read,
                      output wire                            src_6_write,
                      input  wire                            src_6_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_6_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_6_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_6_burstcount,
                      // Region 7
                      input  wire [`DRAM_DATAWIDTH-1     :0] src_7_readdata,
                      input  wire                            src_7_readdatavalid,
                      input  wire                            src_7_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] src_7_address,
                      output wire                            src_7_read,
                      output wire                            src_7_write,
                      input  wire                            src_7_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] src_7_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] src_7_byteenable,
                      output wire [`MAXBURST_LOG         :0] src_7_burstcount,
                      /* Avalon-MM Interface for write */
                      input  wire [`DRAM_DATAWIDTH-1     :0] dst_readdata,
                      input  wire                            dst_readdatavalid,
                      input  wire                            dst_waitrequest,
                      output wire [`DRAM_ADDRSPACE-1     :0] dst_address,
                      output wire                            dst_read,
                      output wire                            dst_write,
                      input  wire                            dst_writeack,
                      output wire [`DRAM_DATAWIDTH-1     :0] dst_writedata,
                      output wire [(`DRAM_DATAWIDTH>>3)-1:0] dst_byteenable,
                      output wire [`MAXBURST_LOG         :0] dst_burstcount
                      );

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
  fpga_sort(
            /* global clock and low-actived reset */
            clock,
            resetn,
            /* mapped to arguments from cl code */
            cl_dummy,      // *dummy
            cl_dst_addr,   // dst_addr
            cl_src_addr,   // src_addr
            cl_numdata,    // numdata
            m_output_value,  // *C
            /* Avalon-ST Interface */
            m_ready_out,
            m_valid_in,
            m_valid_out,
            m_ready_in,
            /* Avalon-MM Interface for read */
            // this part will be automatically generated
            // Region 0
            src_0_readdata,
            src_0_readdatavalid,
            src_0_waitrequest,
            src_0_address,
            src_0_read,
            src_0_write,
            src_0_writeack,
            src_0_writedata,
            src_0_byteenable,
            src_0_burstcount,
            // Region 1
            src_1_readdata,
            src_1_readdatavalid,
            src_1_waitrequest,
            src_1_address,
            src_1_read,
            src_1_write,
            src_1_writeack,
            src_1_writedata,
            src_1_byteenable,
            src_1_burstcount,
            // Region 2
            src_2_readdata,
            src_2_readdatavalid,
            src_2_waitrequest,
            src_2_address,
            src_2_read,
            src_2_write,
            src_2_writeack,
            src_2_writedata,
            src_2_byteenable,
            src_2_burstcount,
            // Region 3
            src_3_readdata,
            src_3_readdatavalid,
            src_3_waitrequest,
            src_3_address,
            src_3_read,
            src_3_write,
            src_3_writeack,
            src_3_writedata,
            src_3_byteenable,
            src_3_burstcount,
            // Region 4
            src_4_readdata,
            src_4_readdatavalid,
            src_4_waitrequest,
            src_4_address,
            src_4_read,
            src_4_write,
            src_4_writeack,
            src_4_writedata,
            src_4_byteenable,
            src_4_burstcount,
            // Region 5
            src_5_readdata,
            src_5_readdatavalid,
            src_5_waitrequest,
            src_5_address,
            src_5_read,
            src_5_write,
            src_5_writeack,
            src_5_writedata,
            src_5_byteenable,
            src_5_burstcount,
            // Region 6
            src_6_readdata,
            src_6_readdatavalid,
            src_6_waitrequest,
            src_6_address,
            src_6_read,
            src_6_write,
            src_6_writeack,
            src_6_writedata,
            src_6_byteenable,
            src_6_burstcount,
            // Region 7
            src_7_readdata,
            src_7_readdatavalid,
            src_7_waitrequest,
            src_7_address,
            src_7_read,
            src_7_write,
            src_7_writeack,
            src_7_writedata,
            src_7_byteenable,
            src_7_burstcount,
            /* Avalon-MM Interface for write */
            dst_readdata,
            dst_readdatavalid,
            dst_waitrequest,
            dst_address,
            dst_read,
            dst_write,
            dst_writeack,
            dst_writedata,
            dst_byteenable,
            dst_burstcount
            );

endmodule

`default_nettype wire
