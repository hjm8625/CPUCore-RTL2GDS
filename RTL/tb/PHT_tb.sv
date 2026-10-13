`timescale 1ns / 1ps
`include "GLOBAL.v"

// this test is just PHT test
module PHT_tb;

    reg         clk;
    reg         rst;
    reg  [31:0] pc;
    reg         update_en;
    reg  [31:0] update_pc;
    reg         actual_taken;
    wire        predict_taken;

    integer i;

    PHT dut (
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .update_en(update_en),
        .update_pc(update_pc),
        .actual_taken(actual_taken),
        .predict_taken(predict_taken)
    );

    always #5 clk = ~clk;

    // Select counter[0] by making PC[9:2] equal to the current GBH
    task automatic update_counter_zero;
        input       taken;
        input [1:0] expected_state;
        input [7:0] expected_gbh;
        begin
            @(negedge clk);
            pc = {22'b0, dut.gbh, 2'b00};
            update_pc = {22'b0, dut.gbh, 2'b00};
            actual_taken = taken;
            update_en = 1'b1;

            @(posedge clk);
            #1;
            update_en = 1'b0;

            if (dut.counter[0] !== expected_state)
                $fatal(1, "PHT state error: %02b, It should be %02b",
                       dut.counter[0], expected_state);

            if (dut.gbh !== expected_gbh)
                $fatal(1, "GBH error: %08b, It should be %08b",
                       dut.gbh, expected_gbh);
            
            // change pc with updated GBH and select fixed counter[0]
            pc = {22'b0, dut.gbh, 2'b00};
            #1;

            if (dut.idx !== 8'd0)
                $fatal(1, "GShare index error: %0d, It should be 0", dut.idx);

            if (predict_taken !== expected_state[1])
                $fatal(1, "Prediction error: %0b, It should be %0b",
                       predict_taken, expected_state[1]);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        pc = 32'b0;
        update_en = 1'b0;
        update_pc = 32'b0;
        actual_taken = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk); // avoid race condition
        rst = 1'b0;
        #1;

        if (dut.gbh !== 8'b0)
            $fatal(1, "GBH reset error");

        for (i = 0; i < 256; i = i + 1) begin
            if (dut.counter[i] !== `SNT)
                $fatal(1, "PHT reset error");
        end

        if (predict_taken !== 1'b0)
            $fatal(1, "Prediction reset error");

        // Taken transitions ascending
        update_counter_zero(1'b1, `WNT, 8'b00000001); // SNT -> WNT
        update_counter_zero(1'b1, `WT,  8'b00000011); // WNT -> WT
        update_counter_zero(1'b1, `ST,  8'b00000111); // WT  -> ST
        update_counter_zero(1'b1, `ST,  8'b00001111); // ST  -> ST

        // Not-taken transitions descending
        update_counter_zero(1'b0, `WT,  8'b00011110); // ST  -> WT
        update_counter_zero(1'b0, `WNT, 8'b00111100); // WT  -> WNT
        update_counter_zero(1'b0, `SNT, 8'b01111000); // WNT -> SNT
        update_counter_zero(1'b0, `SNT, 8'b11110000); // SNT -> SNT

        $display("PASS: PHT test passed");
        $finish;
    end

endmodule
