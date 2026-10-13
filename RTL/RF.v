// Register File
`timescale 1ns / 100ps

module RF (
        input clk,
        input rst,
        input [4:0] rd_addr1,
        input [4:0] rd_addr2,
        output [31:0] rd_data1,
        output [31:0] rd_data2,
        input RegWrite,
        input [4:0] wr_addr,
        input [31:0] wr_data
    );

    reg [31:0] register_file [0:31];
    
    //Bypass : WB data to the ID stage in the same cycle (RAW hazard)
    // caution, write to register0 is ignored
    wire bypass_rd1 = RegWrite && (wr_addr != 5'd0) &&
                      (wr_addr == rd_addr1);
    wire bypass_rd2 = RegWrite && (wr_addr != 5'd0) &&
                      (wr_addr == rd_addr2);

    // if bypass, use wr_data directly
    assign rd_data1 = (rd_addr1 == 5'd0) ? 32'b0 :
                      bypass_rd1 ? wr_data : register_file[rd_addr1];
    assign rd_data2 = (rd_addr2 == 5'd0) ? 32'b0 :
                      bypass_rd2 ? wr_data : register_file[rd_addr2];

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                register_file[i] <= 32'b0;
        end
        // register0 should be ignored..
        else if (RegWrite && (wr_addr != 5'd0)) begin
            register_file[wr_addr] <= wr_data;
        end
    end

endmodule
