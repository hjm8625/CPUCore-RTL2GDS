// PHT
// using GShare branch predictor
`timescale 1ns / 1ps
`include "GLOBAL.v"

module PHT(
    input         clk,
    input         rst,

    input  [31:0] pc,
    input         update_en,
    input  [31:0] update_pc,
    input         actual_taken,

    output        predict_taken
    );

    reg [1:0] counter [0:255];
    reg [7:0] gbh; // Global Branch History 

    wire [7:0] idx     = pc[9:2] ^ gbh; // using xor
    wire [7:0] upd_idx = update_pc[9:2] ^ gbh;

    assign predict_taken = counter[idx][1]; // -NT : 0, -T : 1

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1) begin
                counter[i] <= `SNT;
            end
            gbh <= 0;
        end
        else begin
            if (update_en) begin
                case (counter[upd_idx])
                    // SNT-WNT-WT-ST
                    // Strongly not taken
                    `SNT: begin
                        if (actual_taken)
                            counter[upd_idx] <= `WNT;
                        else
                            counter[upd_idx] <= `SNT;
                    end
                    // weakly not taken
                    `WNT: begin
                        if (actual_taken)
                            counter[upd_idx] <= `WT;
                        else
                            counter[upd_idx] <= `SNT;
                    end
                    // weakly taken
                    `WT: begin
                        if (actual_taken)
                            counter[upd_idx] <= `ST;
                        else
                            counter[upd_idx] <= `WNT;
                    end
                    //strongly taken
                    `ST: begin
                        if (actual_taken)
                            counter[upd_idx] <= `ST;
                        else
                            counter[upd_idx] <= `WT;
                    end

                    default: begin
                        counter[upd_idx] <= `SNT; 
                    end
                endcase
                //
                gbh <= {gbh[6:0], actual_taken};
            end
        end
    end

endmodule