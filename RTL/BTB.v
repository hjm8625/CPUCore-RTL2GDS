// BTB
// 64 entry direct-mapped
`timescale 1ns / 1ps
`include "GLOBAL.v"

module BTB(
    input         clk,
    input         rst,

    input  [31:0] pc,
    // update thing
    input         update_en,
    input  [31:0] update_pc,
    input  [31:0] update_target,
    input  [1:0]  update_type,

    output        hit,
    output [31:0] target,
    output [1:0]  pc_type
    );
    
    // divide 32bits as 24(tag),6(idx),2(align)
    reg [23:0] tag_table    [0:63];
    reg [1:0]  type_table   [0:63];
    reg [31:0] target_table [0:63];

    wire [5:0]  idx = pc[7:2];
    wire [23:0] tag = pc[31:8];
    wire [5:0]  updidx = update_pc[7:2];

    assign pc_type = type_table[idx];
    assign target  = target_table[idx];
    // hit : no empty(2'b00) and tag==tag_table[idx]
    // empty 00, jump 01, branch 10 (made in global.v)
    assign hit = (type_table[idx] != `BTB_EMPTY) && (tag_table[idx] == tag);

    integer i;
    always @(posedge clk) begin
        // all 0 start
        if (rst) begin
            for (i = 0; i < 64; i = i + 1) begin
                tag_table[i]    <= 24'b0;
                type_table[i]   <= `BTB_EMPTY;
                target_table[i] <= 32'b0;
            end
        end
        else begin
            // store tag, type, target in updidx
            if (update_en) begin
                tag_table[updidx] <= update_pc[31:8];
                type_table[updidx] <= update_type;
                target_table[updidx] <= update_target;
            end
        end
    end

endmodule
