`timescale 1ns / 1ps
`include "GLOBAL.v"

module BTB_tb;

    reg         clk;
    reg         rst;
    reg  [31:0] pc;
    reg         update_en;
    reg  [31:0] update_pc;
    reg  [31:0] update_target;
    reg  [1:0]  update_type;

    wire        hit;
    wire [31:0] target;
    wire [1:0]  pc_type;

    integer i;

    BTB dut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .update_en(update_en),
        .update_pc(update_pc),
        .update_target(update_target),
        .update_type(update_type),
        .hit(hit),
        .target(target),
        .pc_type(pc_type)
    );

    always #5 clk = ~clk;

    task automatic update_entry;
        input [31:0] entry_pc;
        input [31:0] entry_target;
        input [1:0]  entry_type;
        begin
            @(negedge clk);
            update_pc = entry_pc;
            update_target = entry_target;
            update_type = entry_type;
            update_en = 1'b1;

            @(posedge clk);
            #1;
            update_en = 1'b0;
        end
    endtask

    task automatic check_hit;
        input [31:0] query_pc;
        input [31:0] expected_target;
        input [1:0]  expected_type;  // empty, jump, branch
        begin
            pc = query_pc;
            #1;

            if (hit !== 1'b1)
                $fatal(1, "BTB hit error: PC 0x%08x should hit", query_pc);

            if (target !== expected_target)
                $fatal(1, "BTB target error: 0x%08x, It should be 0x%08x",
                       target, expected_target);

            if (pc_type !== expected_type)
                $fatal(1, "BTB type error: %02b, It should be %02b",
                       pc_type, expected_type);
        end
    endtask

    task automatic check_miss;
        input [31:0] query_pc;
        begin
            pc = query_pc;
            #1;

            if (hit !== 1'b0)
                $fatal(1, "BTB miss error: PC 0x%08x should miss", query_pc);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        pc = 32'b0;
        update_en = 1'b0;
        update_pc = 32'b0;
        update_target = 32'b0;
        update_type = `BTB_EMPTY;

        repeat (2) @(posedge clk);
        @(negedge clk); // avoid race condition
        rst = 1'b0;
        #1;

        // All entries must be empty 
        for (i = 0; i < 64; i = i + 1) begin
            if (dut.tag_table[i] !== 24'b0)
                $fatal(1, "BTB tag reset error");
            if (dut.type_table[i] !== `BTB_EMPTY)
                $fatal(1, "BTB type reset error");
            if (dut.target_table[i] !== 32'b0)
                $fatal(1, "BTB target reset error");
        end

        check_miss(32'h0000_0100); // idx 0, tag1

        // Write and read a branch entry at index 0
        update_entry(32'h0000_0100, 32'h0000_0180, `BTB_BRANCH);
        check_hit(32'h0000_0100, 32'h0000_0180, `BTB_BRANCH);

        // what if same BTB index, but different tags?
        check_miss(32'h0000_0200); // idx 0, tag2

        // Replace the branch entry with a jump entry at the same index
        update_entry(32'h0000_0200, 32'h0000_0300, `BTB_JUMP);
        check_hit(32'h0000_0200, 32'h0000_0300, `BTB_JUMP);
        check_miss(32'h0000_0100); // so, it should be missed because of replacement

        $display("PASS: BTB test passed");
        $finish;
    end

endmodule
