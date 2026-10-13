`timescale 1ns / 1ps

module Forwarding_tb;

    localparam integer MEM_WORDS = 256;
    localparam integer TIMEOUT_CYCLES = 100;

    reg clk;
    reg rst;

    wire        imem_req;
    wire [31:0] imem_addr;
    wire        imem_ready;
    wire [31:0] imem_rdata;

    wire        dmem_req;
    wire        dmem_read;
    wire        dmem_write;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_ready;
    wire [31:0] dmem_rdata;

    reg [31:0] instruction_memory [0:MEM_WORDS-1];
    reg [31:0] data_memory        [0:MEM_WORDS-1];

    integer i;
    integer cycle_count;
    integer forward_a_exmem_count;
    integer forward_a_memwb_count;
    integer forward_b_exmem_count;
    integer forward_b_memwb_count;

    CPUCore dut (
        .clk(clk),
        .rst(rst),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_ready(imem_ready),
        .imem_rdata(imem_rdata),
        .dmem_req(dmem_req),
        .dmem_read(dmem_read),
        .dmem_write(dmem_write),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_ready(dmem_ready),
        .dmem_rdata(dmem_rdata)
    );

    always #5 clk = ~clk;

    // Zero wait state instruction and data memories
    assign imem_ready = imem_req;
    assign imem_rdata = instruction_memory[imem_addr[9:2]];
    assign dmem_ready = dmem_req;
    assign dmem_rdata = data_memory[dmem_addr[9:2]];

    always @(posedge clk) begin
        if (dmem_write && dmem_ready)
            data_memory[dmem_addr[9:2]] <= dmem_wdata;
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        cycle_count = 0;
        forward_a_exmem_count = 0;
        forward_a_memwb_count = 0;
        forward_b_exmem_count = 0;
        forward_b_memwb_count = 0;

        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            instruction_memory[i] = 32'b0;
            data_memory[i] = 32'b0;
        end

        instruction_memory[0] = 32'h2408_0005;  // addiu $8,  $0, 5
        instruction_memory[1] = 32'h2409_0007;  // addiu $9,  $0, 7
        instruction_memory[2] = 32'h0109_5021;  // addu  $10, $8, $9      (forward memwbA, exmemB)
        instruction_memory[3] = 32'h0148_5823;  // subu  $11, $10, $8     (forward exmemA)
        instruction_memory[4] = 32'h016a_6026;  // xor   $12, $11, $10    (forward exmemA, memwbB)
        instruction_memory[5] = 32'h018b_6821;  // addu  $13, $12, $11    (forward exmemA, memwbB)
        instruction_memory[6] = 32'hac0d_0004;  // sw    $13, 4($0)       (forward exmemB)

        repeat (2) @(posedge clk);
        @(negedge clk); // avoid race condition
        rst = 1'b0;
    end

    // Check the results when test is finished
    // I made test to check 2 things
    // 1. Are addr, value correct? (result)
    // 2. Does the forwarding unit work? (procedure)
    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;

            if (dut.forwardA_exmem)
                forward_a_exmem_count <= forward_a_exmem_count + 1;
            if (dut.forwardA_memwb)
                forward_a_memwb_count <= forward_a_memwb_count + 1;
            if (dut.forwardB_exmem)
                forward_b_exmem_count <= forward_b_exmem_count + 1;
            if (dut.forwardB_memwb)
                forward_b_memwb_count <= forward_b_memwb_count + 1;

            if (dmem_write && dmem_ready) begin
                // address error
                if (dmem_addr !== 32'd4) // !==, X,Z should be failed
                    $fatal(1, "Address error : 0x%08x, It should be 0x00000004", dmem_addr);
                // value error
                if (dmem_wdata !== 32'd18)
                    $fatal(1, "Value error : %0d, It should be 18", dmem_wdata);
                
                // forwarding unit error
                if (forward_a_exmem_count != 3)
                    $fatal(1, "EX/MEM to operand A count error: %0d, It should be 3", forward_a_exmem_count);
                if (forward_a_memwb_count != 1)
                    $fatal(1, "MEM/WB to operand A count error: %0d, It should be 1", forward_a_memwb_count);
                if (forward_b_exmem_count != 2)
                    $fatal(1, "EX/MEM to operand B count error: %0d, It should be 2", forward_b_exmem_count);
                if (forward_b_memwb_count != 2)
                    $fatal(1, "MEM/WB to operand B count error: %0d, It should be 2", forward_b_memwb_count);

                $display("PASS: forwarding test passed");
                $finish;
            end

            if (cycle_count >= TIMEOUT_CYCLES)
                $fatal(1, "Timeout!!!");
        end
    end

endmodule
