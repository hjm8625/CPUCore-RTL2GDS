`timescale 1ns / 1ps

module stall_tb;

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
    integer load_use_hazard_count;
    integer jr_hazard_count;
    integer stall_count;

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
        load_use_hazard_count = 0; // lw -> 1 cycle stall
        jr_hazard_count = 0;       // jr -> 2 cycle stall
        stall_count = 0;

        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            instruction_memory[i] = 32'b0;
            data_memory[i] = 32'b0;
        end

        data_memory[1] = 32'd21; // initial value

        instruction_memory[0] = 32'h8c08_0004;  // lw    $8, 4($0)
        instruction_memory[1] = 32'h0108_4821;  // addu  $9, $8, $8   (load-use stall)
        instruction_memory[2] = 32'h240a_0020;  // addiu $10, $0, 32  (JR target)
        instruction_memory[3] = 32'h0140_0008;  // jr    $10          (JR stall)
        instruction_memory[4] = 32'hac00_0000;  // sw    $0, 0($0)    (should not execute)
        instruction_memory[5] = 32'h2409_0063;  // addiu $9, $0, 99   (should not execute)
        instruction_memory[6] = 32'h0000_0000;  // nop
        instruction_memory[7] = 32'h0000_0000;  // nop
        instruction_memory[8] = 32'hac09_0008;  // sw    $9, 8($0)    (result)

        repeat (2) @(posedge clk);
        @(negedge clk); // avoid race condition
        rst = 1'b0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycle_count <= cycle_count + 1;

            if (dut.load_use_hazard)
                load_use_hazard_count <= load_use_hazard_count + 1;
            if (dut.jr_hazard)
                jr_hazard_count <= jr_hazard_count + 1;
            if (dut.stall)
                stall_count <= stall_count + 1;

            if (dmem_write && dmem_ready) begin
                if (dmem_addr === 32'd0)
                    $fatal(1, "JR flush error: wrong path sw was executed");

                if (dmem_addr !== 32'd8)
                    $fatal(1, "Address error: 0x%08x, It should be 0x00000008", dmem_addr);

                if (dmem_wdata !== 32'd42)
                    $fatal(1, "Value error: %0d, It should be 42", dmem_wdata);

                if (load_use_hazard_count != 1)
                    $fatal(1, "Load-use hazard count error: %0d, It should be 1", load_use_hazard_count);

                if (jr_hazard_count != 2)
                    $fatal(1, "JR hazard count error: %0d, It should be 2", jr_hazard_count);

                if (stall_count != 3)
                    $fatal(1, "Stall count error: %0d, It should be 3", stall_count);

                $display("PASS: stall test passed");
                $finish;
            end

            if (cycle_count >= TIMEOUT_CYCLES)
                $fatal(1, "Timeout!!!");
        end
    end

endmodule
