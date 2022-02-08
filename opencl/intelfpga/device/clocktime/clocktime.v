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

module clocktime #(
    parameter IDATA_WIDTH = 32,
    parameter TIME_WIDTH = 64,
    parameter ODATA_PADS = 0
) (
    input wire          clock,
    input wire          resetn,
    input wire          ivalid,
    input wire          iready,
    output wire         ovalid,
    output wire         oready,
    input wire [IDATA_WIDTH-1:0]   idata,
    output wire [IDATA_WIDTH + TIME_WIDTH + ODATA_PADS - 1:0] odata
);
    reg [63:0]         count;
    reg                valid;
    reg [IDATA_WIDTH-1:0]         data;

    always @(posedge clock) begin
        if (~resetn) begin
            count <= '0;
        end else begin
            count <= count + 1'd1;
        end
    end

    always @(posedge clock) begin
        if (~resetn) begin
            data <= '0;
            valid <= '0;
        end else begin
            valid <= ivalid;
            data <= idata;
        end
    end

    assign oready = 1'b1;
    assign odata = {data, count, {ODATA_PADS{1'b0}}};
    assign ovalid = valid;
endmodule
