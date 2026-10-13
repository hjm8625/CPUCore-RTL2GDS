`timescale 1ns / 1ps
`include "GLOBAL.v"

module CTRL(
    input  [5:0] opcode,
    input  [5:0] funct,
    input        valid,

    output reg [3:0] ALUOp,
    output reg       ALUSrc,
    output reg       RegDst,
    output reg       MemRead,
    output reg       MemWrite,
    output reg       MemtoReg,
    output reg       RegWrite,
    output reg       Branch,
    output reg       BranchNE,
    output reg       SignExtend,
    output reg       Jump,
    output reg       JR,
    output reg       JAL,
    output reg       use_rs,
    output reg       use_rt
    );

    always @(*) begin
        ALUOp      = `ALU_ADDU;
        ALUSrc     = 1'b0;
        RegDst     = `RegDst_RT;
        MemRead    = 1'b0;
        MemWrite   = 1'b0;
        MemtoReg   = `MemtoReg_ALU;
        RegWrite   = 1'b0;
        Branch     = 1'b0;
        BranchNE   = 1'b0;
        SignExtend = 1'b1;
        Jump       = 1'b0;
        JR         = 1'b0;
        JAL        = 1'b0;
        use_rs     = 1'b0;
        use_rt     = 1'b0;

        if (valid) begin
            case (opcode)
                `OP_RTYPE: begin
                    RegDst = `RegDst_RD;
                    case (funct)
                        `FUNCT_SLL: begin
                            ALUOp = `ALU_SLL;
                            RegWrite = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_SRL: begin
                            ALUOp = `ALU_SRL;
                            RegWrite = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_SRA: begin
                            ALUOp = `ALU_SRA;
                            RegWrite = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_ADDU: begin
                            ALUOp = `ALU_ADDU;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_SUBU: begin
                            ALUOp = `ALU_SUBU;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_AND: begin
                            ALUOp = `ALU_AND;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_OR: begin
                            ALUOp = `ALU_OR;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_XOR: begin
                            ALUOp = `ALU_XOR;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_NOR: begin
                            ALUOp = `ALU_NOR;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_SLT: begin
                            ALUOp = `ALU_SLT;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_SLTU: begin
                            ALUOp = `ALU_SLTU;
                            RegWrite = 1'b1;
                            use_rs = 1'b1;
                            use_rt = 1'b1;
                        end
                        `FUNCT_JR: begin
                            JR = 1'b1;
                            use_rs = 1'b1;
                        end
                        default: begin
                            // Unsupported funct: no architectural side effect.
                        end
                    endcase
                end

                `OP_LW: begin
                    ALUSrc   = 1'b1;
                    MemRead  = 1'b1;
                    MemtoReg = `MemtoReg_MEM;
                    RegWrite = 1'b1;
                    use_rs   = 1'b1;
                end

                `OP_SW: begin
                    ALUSrc   = 1'b1;
                    MemWrite = 1'b1;
                    use_rs   = 1'b1;
                    use_rt   = 1'b1;
                end

                `OP_BEQ: begin
                    ALUOp  = `ALU_SUBU;
                    Branch = 1'b1;
                    use_rs = 1'b1;
                    use_rt = 1'b1;
                end

                `OP_BNE: begin
                    ALUOp    = `ALU_SUBU;
                    Branch   = 1'b1;
                    BranchNE = 1'b1;
                    use_rs   = 1'b1;
                    use_rt   = 1'b1;
                end

                `OP_J: begin
                    Jump = 1'b1;
                end

                `OP_JAL: begin
                    JAL      = 1'b1;
                    RegWrite = 1'b1;
                end

                `OP_ADDIU: begin
                    ALUSrc   = 1'b1;
                    ALUOp    = `ALU_ADDU;
                    RegWrite = 1'b1;
                    use_rs   = 1'b1;
                end

                `OP_ANDI: begin
                    ALUSrc     = 1'b1;
                    ALUOp      = `ALU_AND;
                    RegWrite   = 1'b1;
                    SignExtend = 1'b0;
                    use_rs     = 1'b1;
                end

                `OP_ORI: begin
                    ALUSrc     = 1'b1;
                    ALUOp      = `ALU_OR;
                    RegWrite   = 1'b1;
                    SignExtend = 1'b0;
                    use_rs     = 1'b1;
                end

                `OP_XORI: begin
                    ALUSrc     = 1'b1;
                    ALUOp      = `ALU_XOR;
                    RegWrite   = 1'b1;
                    SignExtend = 1'b0;
                    use_rs     = 1'b1;
                end

                `OP_SLTI: begin
                    ALUSrc   = 1'b1;
                    ALUOp    = `ALU_SLT;
                    RegWrite = 1'b1;
                    use_rs   = 1'b1;
                end

                `OP_SLTIU: begin
                    ALUSrc   = 1'b1;
                    ALUOp    = `ALU_SLTU;
                    RegWrite = 1'b1;
                    use_rs   = 1'b1;
                end

                `OP_LUI: begin
                    ALUSrc     = 1'b1;
                    ALUOp      = `ALU_LUI;
                    RegWrite   = 1'b1;
                    SignExtend = 1'b0;
                end
            endcase
        end
    end

endmodule
