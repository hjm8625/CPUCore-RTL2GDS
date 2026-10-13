`timescale 1ns / 1ps
`include "GLOBAL.v"

module CPUCore(
    input       clk,
    input       rst,
    // external memory interfaces for chches
    // This project focuses on RTL to GDS implementation of CPUCore
    // maybe... caches are integrated in future work....
    input         imem_ready,
    input  [31:0] imem_rdata,
    output        imem_req,
    output [31:0] imem_addr,

    input         dmem_ready,
    input  [31:0] dmem_rdata,
    output        dmem_req,
    output        dmem_read,
    output        dmem_write,
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata
    );

    reg [31:0] PC;
    
    wire [31:0] inst;
    wire [31:0]  d_read_data;

    assign dmem_req = EX_MEM_valid && (EX_MEM_MemRead || EX_MEM_MemWrite);
    assign imem_req = !rst && !dmem_req;

    assign imem_addr = PC;
    assign inst = imem_rdata;

    assign dmem_read  = dmem_req && EX_MEM_MemRead;
    assign dmem_write = dmem_req && EX_MEM_MemWrite;
    assign dmem_addr  = EX_MEM_ALUOut;
    assign dmem_wdata = EX_MEM_B;
    assign d_read_data = dmem_rdata;
    
    // hold pipeline stages while external memory is waiting for ready
    // future work...
    wire imem_wait = imem_req && !imem_ready;
    wire dmem_wait = dmem_req && !dmem_ready;
    wire memory_hold = imem_wait || dmem_wait;

    
    // Pipelin registers for 5 stage pipeline (IF/ID/EX/MEM/WB)
    // IF/ID
    reg [31:0] IF_ID_PC;
    reg [31:0] IF_ID_PC4;
    reg [31:0] IF_ID_inst;
    reg        IF_ID_pred_taken;
    reg [31:0] IF_ID_pred_next_pc;
    reg        IF_ID_valid;

    // ID/EX
    reg [31:0] ID_EX_PC;
    reg [31:0] ID_EX_PC4;
    reg [31:0] ID_EX_A;
    reg [31:0] ID_EX_B;
    reg [31:0] ID_EX_ext_imm;
    reg [4:0]  ID_EX_rs;
    reg [4:0]  ID_EX_rt;
    reg [4:0]  ID_EX_rd;
    reg [4:0]  ID_EX_shamt;
    reg [25:0] ID_EX_immj;
    reg [3:0]  ID_EX_ALUOp;
    reg        ID_EX_ALUSrc;
    reg        ID_EX_RegDst;
    reg        ID_EX_MemRead;
    reg        ID_EX_MemWrite;
    reg        ID_EX_MemtoReg;
    reg        ID_EX_RegWrite;
    reg        ID_EX_Branch;
    reg        ID_EX_BranchNE;
    reg        ID_EX_pred_taken;
    reg [31:0] ID_EX_pred_next_pc;
    reg        ID_EX_valid;

    // EX/MEM
    reg [31:0] EX_MEM_branch_target;
    reg [31:0] EX_MEM_ALUOut;
    reg [31:0] EX_MEM_B;
    reg [4:0]  EX_MEM_wr_addr;
    reg        EX_MEM_zero;
    reg        EX_MEM_MemRead;
    reg        EX_MEM_MemWrite;
    reg        EX_MEM_MemtoReg;
    reg        EX_MEM_RegWrite;
    reg        EX_MEM_Branch;
    reg        EX_MEM_BranchNE;
    reg        EX_MEM_valid;

    // MEM/WB
    reg [31:0] MEM_WB_mem_data;
    reg [31:0] MEM_WB_ALUOut;
    reg [4:0]  MEM_WB_wr_addr;
    reg        MEM_WB_MemtoReg;
    reg        MEM_WB_RegWrite;
    reg        MEM_WB_valid;
    
    //////////////////////////////////////////////////////////////

    // Instruction field in ID stage
    wire [5:0] id_opcode = IF_ID_inst[31:26];
    wire [4:0] id_rs     = IF_ID_inst[25:21];
    wire [4:0] id_rt     = IF_ID_inst[20:16];
    wire [4:0] id_rd     = IF_ID_inst[15:11];
    wire [4:0] id_shamt  = IF_ID_inst[10:6];
    wire [5:0] id_funct  = IF_ID_inst[5:0];
    wire [15:0] id_immi  = IF_ID_inst[15:0];
    wire [25:0] id_immj  = IF_ID_inst[25:0];
    
    // regsiter operands in ID stage
    wire [31:0] rd_data1;
    wire [31:0] rd_data2;

    // write back data in WB stage
    wire [31:0] wb_data = (MEM_WB_MemtoReg) ? MEM_WB_mem_data : MEM_WB_ALUOut;

    // control signals - ctrl.v
    wire [3:0] ctrl_ALUOp;
    wire       ctrl_ALUSrc;
    wire       ctrl_RegDst;
    wire       ctrl_MemRead;
    wire       ctrl_MemWrite;
    wire       ctrl_MemtoReg;
    wire       ctrl_RegWrite;
    wire       ctrl_Branch;
    wire       ctrl_BranchNE;
    wire       ctrl_SignExtend;
    wire       ctrl_Jump;
    wire       ctrl_JR;
    wire       ctrl_JAL;
    wire       use_rs;
    wire       use_rt;
    
    // Extend 16bit imm for ID stage inst
    wire [31:0] id_ext_imm = ctrl_SignExtend ? {{16{id_immi[15]}}, id_immi} : {16'b0, id_immi};
    
    // generate target address
    wire [31:0] id_jump_target = {IF_ID_PC4[31:28], id_immj, 2'b00};
    
    // select destination reg in EX stage
    wire [4:0] id_ex_dest = ID_EX_RegDst ? ID_EX_rd : ID_EX_rt;

    // Hazard units //////////////////////////////////////////////////
    // detect lw and jr
    wire load_use_hazard = IF_ID_valid && ID_EX_valid && ID_EX_MemRead &&
                           (id_ex_dest != 5'd0) &&
                           ((use_rs && (id_rs == id_ex_dest)) ||
                            (use_rt && (id_rt == id_ex_dest)));

    wire jr_hazard = IF_ID_valid && ctrl_JR &&
                     (
                         (ID_EX_valid && ID_EX_RegWrite &&
                          (id_ex_dest != 5'd0) &&
                          (id_rs == id_ex_dest)) ||

                         (EX_MEM_valid && EX_MEM_RegWrite &&
                          (EX_MEM_wr_addr != 5'd0) &&
                          (id_rs == EX_MEM_wr_addr))
                     );

    wire stall = load_use_hazard || jr_hazard;

    //////////////////////////////////////////////////////////////////

    // Forwarding units //////////////////////////////////////////////

    wire forwardA_exmem = EX_MEM_valid && EX_MEM_RegWrite && !EX_MEM_MemRead &&
                          (EX_MEM_wr_addr != 5'd0) &&
                          (EX_MEM_wr_addr == ID_EX_rs);
    wire forwardA_memwb = MEM_WB_valid && MEM_WB_RegWrite &&
                          (MEM_WB_wr_addr != 5'd0) &&
                          (MEM_WB_wr_addr == ID_EX_rs) &&
                          !forwardA_exmem;

    wire forwardB_exmem = EX_MEM_valid && EX_MEM_RegWrite && !EX_MEM_MemRead &&
                          (EX_MEM_wr_addr != 5'd0) &&
                          (EX_MEM_wr_addr == ID_EX_rt);
    wire forwardB_memwb = MEM_WB_valid && MEM_WB_RegWrite &&
                          (MEM_WB_wr_addr != 5'd0) &&
                          (MEM_WB_wr_addr == ID_EX_rt) &&
                          !forwardB_exmem;

    wire [31:0] forwarded_A = forwardA_exmem ? EX_MEM_ALUOut :
                              forwardA_memwb ? wb_data : ID_EX_A;
    wire [31:0] forwarded_B = forwardB_exmem ? EX_MEM_ALUOut :
                              forwardB_memwb ? wb_data : ID_EX_B;

    /////////////////////////////////////////////////////////////////
    
    // select alu_operand2 (It could be influenced by forwarding)
    wire [31:0] alu_operand2 = ID_EX_ALUSrc ? ID_EX_ext_imm : forwarded_B;
    wire [31:0] alu_result;
    
    // Branch signals
    wire [31:0] branch_target = ID_EX_PC4 + (ID_EX_ext_imm << 2);
    wire branch_actual_taken = ID_EX_valid && ID_EX_Branch &&
                               (ID_EX_BranchNE ? (alu_result != 32'b0) : (alu_result == 32'b0));
    wire [31:0] branch_correct_pc = branch_actual_taken ? branch_target : ID_EX_PC4;
    wire branch_mispredict = ID_EX_valid && ID_EX_Branch &&
                              (ID_EX_pred_next_pc != branch_correct_pc);

    // BTB signals - BTB.v
    wire        btb_hit;
    wire [1:0]  btb_type;
    wire [31:0] btb_target;
    wire        pht_predict_taken;

    // predictions in IF stage
    wire predict_jump   = btb_hit && (btb_type == `BTB_JUMP);
    wire predict_branch = btb_hit && (btb_type == `BTB_BRANCH) && pht_predict_taken;
    wire pred_taken     = predict_jump || predict_branch;
    wire [31:0] pred_next_pc = pred_taken ? btb_target : (PC + 32'd4);
    
    // jump resolution in ID stage
    wire id_jump_valid = IF_ID_valid && (ctrl_Jump || ctrl_JAL || ctrl_JR) && !stall && !branch_mispredict;
    wire [31:0] id_jump_actual_target = ctrl_JR ? rd_data1 : id_jump_target;
    wire id_jump_redirect = id_jump_valid &&
                             (ctrl_JR || !IF_ID_pred_taken ||
                              (IF_ID_pred_next_pc != id_jump_actual_target));

    // BTB updates
    wire btb_update_branch = ID_EX_valid && ID_EX_Branch;
    wire btb_update_jump   = id_jump_valid && !ctrl_JR;
    wire btb_update_en     = (btb_update_branch || btb_update_jump) &&
                             !memory_hold;
    wire [31:0] btb_update_pc = btb_update_branch ? ID_EX_PC : IF_ID_PC;
    wire [31:0] btb_update_target = btb_update_branch ? branch_target : id_jump_actual_target;
    wire [1:0]  btb_update_type = btb_update_branch ? `BTB_BRANCH : `BTB_JUMP;
    
    // PHT updates
    wire pht_update_en = ID_EX_valid && ID_EX_Branch && !memory_hold;

    always @(posedge clk) begin
        // all reset
        if (rst) begin
            PC <= 32'b0;
            //IF_ID
            IF_ID_PC <= 32'b0;
            IF_ID_PC4 <= 32'b0;
            IF_ID_inst <= 32'b0;
            IF_ID_pred_taken <= 1'b0;
            IF_ID_pred_next_pc <= 32'b0;
            IF_ID_valid <= 1'b0;
            // ID_EX
            ID_EX_PC <= 32'b0;
            ID_EX_PC4 <= 32'b0;
            ID_EX_A <= 32'b0;
            ID_EX_B <= 32'b0;
            ID_EX_ext_imm <= 32'b0;
            ID_EX_rs <= 5'b0;
            ID_EX_rt <= 5'b0;
            ID_EX_rd <= 5'b0;
            ID_EX_shamt <= 5'b0;
            ID_EX_immj <= 26'b0;
            ID_EX_ALUOp <= `ALU_ADDU;
            ID_EX_ALUSrc <= 1'b0;
            ID_EX_RegDst <= `RegDst_RT;
            ID_EX_MemRead <= 1'b0;
            ID_EX_MemWrite <= 1'b0;
            ID_EX_MemtoReg <= `MemtoReg_ALU;
            ID_EX_RegWrite <= 1'b0;
            ID_EX_Branch <= 1'b0;
            ID_EX_BranchNE <= 1'b0;
            ID_EX_pred_taken <= 1'b0;
            ID_EX_pred_next_pc <= 32'b0;
            ID_EX_valid <= 1'b0;
            //EX_MEM
            EX_MEM_branch_target <= 32'b0;
            EX_MEM_ALUOut <= 32'b0;
            EX_MEM_B <= 32'b0;
            EX_MEM_wr_addr <= 5'b0;
            EX_MEM_zero <= 1'b0;
            EX_MEM_MemRead <= 1'b0;
            EX_MEM_MemWrite <= 1'b0;
            EX_MEM_MemtoReg <= `MemtoReg_ALU;
            EX_MEM_RegWrite <= 1'b0;
            EX_MEM_Branch <= 1'b0;
            EX_MEM_BranchNE <= 1'b0;
            EX_MEM_valid <= 1'b0;
            //MEM_WB
            MEM_WB_mem_data <= 32'b0;
            MEM_WB_ALUOut <= 32'b0;
            MEM_WB_wr_addr <= 5'b0;
            MEM_WB_MemtoReg <= `MemtoReg_ALU;
            MEM_WB_RegWrite <= 1'b0;
            MEM_WB_valid <= 1'b0;
        end
        else if (!memory_hold) begin // memory hold -> stops stages
            //mispredict-> correct
            if (branch_mispredict)
                PC <= branch_correct_pc;
            // jump-> target
            else if (id_jump_redirect)
                PC <= id_jump_actual_target;
            // no stall -> next_pc
            else if (!stall && imem_req && imem_ready)
                PC <= pred_next_pc;
            
            // IF_ID flush
            if (branch_mispredict || id_jump_redirect) begin
                IF_ID_PC <= 32'b0;
                IF_ID_PC4 <= 32'b0;
                IF_ID_inst <= 32'b0;
                IF_ID_pred_taken <= 1'b0;
                IF_ID_pred_next_pc <= 32'b0;
                IF_ID_valid <= 1'b0;
            end
            else if (!stall && dmem_req && dmem_ready) begin
                IF_ID_PC <= 32'b0;
                IF_ID_PC4 <= 32'b0;
                IF_ID_inst <= 32'b0;
                IF_ID_pred_taken <= 1'b0;
                IF_ID_pred_next_pc <= 32'b0;
                IF_ID_valid <= 1'b0;
            end
            else if (!stall && imem_req && imem_ready) begin
                IF_ID_PC <= PC;
                IF_ID_PC4 <= PC + 32'd4;
                IF_ID_inst <= inst;
                IF_ID_pred_taken <= pred_taken;
                IF_ID_pred_next_pc <= pred_next_pc;
                IF_ID_valid <= 1'b1;
            end
            
            // bubble insert in ID_EX stage (but, JAL need to write through pipeline)
            if (branch_mispredict || stall || (id_jump_valid && !ctrl_JAL)) begin
                ID_EX_PC <= 32'b0;
                ID_EX_PC4 <= 32'b0;
                ID_EX_A <= 32'b0;
                ID_EX_B <= 32'b0;
                ID_EX_ext_imm <= 32'b0;
                ID_EX_rs <= 5'b0;
                ID_EX_rt <= 5'b0;
                ID_EX_rd <= 5'b0;
                ID_EX_shamt <= 5'b0;
                ID_EX_immj <= 26'b0;
                ID_EX_ALUOp <= `ALU_ADDU;
                ID_EX_ALUSrc <= 1'b0;
                ID_EX_RegDst <= `RegDst_RT;
                ID_EX_MemRead <= 1'b0;
                ID_EX_MemWrite <= 1'b0;
                ID_EX_MemtoReg <= `MemtoReg_ALU;
                ID_EX_RegWrite <= 1'b0;
                ID_EX_Branch <= 1'b0;
                ID_EX_BranchNE <= 1'b0;
                ID_EX_pred_taken <= 1'b0;
                ID_EX_pred_next_pc <= 32'b0;
                ID_EX_valid <= 1'b0;
            end
            else begin
                ID_EX_PC <= IF_ID_PC;
                ID_EX_PC4 <= IF_ID_PC4;
                ID_EX_A <= ctrl_JAL ? IF_ID_PC4 : rd_data1;
                ID_EX_B <= rd_data2;
                ID_EX_ext_imm <= ctrl_JAL ? 32'b0 : id_ext_imm;
                ID_EX_rs <= id_rs;
                ID_EX_rt <= ctrl_JAL ? 5'd31 : id_rt;
                ID_EX_rd <= id_rd;
                ID_EX_shamt <= id_shamt;
                ID_EX_immj <= id_immj;
                ID_EX_ALUOp <= ctrl_JAL ? `ALU_ADDU : ctrl_ALUOp;
                ID_EX_ALUSrc <= ctrl_JAL ? 1'b1 : ctrl_ALUSrc;
                ID_EX_RegDst <= ctrl_JAL ? `RegDst_RT : ctrl_RegDst;
                ID_EX_MemRead <= ctrl_MemRead;
                ID_EX_MemWrite <= ctrl_MemWrite;
                ID_EX_MemtoReg <= ctrl_MemtoReg;
                ID_EX_RegWrite <= ctrl_RegWrite;
                ID_EX_Branch <= ctrl_Branch;
                ID_EX_BranchNE <= ctrl_BranchNE;
                ID_EX_pred_taken <= IF_ID_pred_taken;
                ID_EX_pred_next_pc <= IF_ID_pred_next_pc;
                ID_EX_valid <= IF_ID_valid;
            end

            EX_MEM_branch_target <= branch_target;
            EX_MEM_ALUOut <= alu_result;
            EX_MEM_B <= forwarded_B;
            EX_MEM_wr_addr <= id_ex_dest;
            EX_MEM_zero <= (alu_result == 32'b0);
            EX_MEM_MemRead <= ID_EX_MemRead;
            EX_MEM_MemWrite <= ID_EX_MemWrite;
            EX_MEM_MemtoReg <= ID_EX_MemtoReg;
            EX_MEM_RegWrite <= ID_EX_RegWrite;
            EX_MEM_Branch <= ID_EX_Branch;
            EX_MEM_BranchNE <= ID_EX_BranchNE;
            EX_MEM_valid <= ID_EX_valid;
            
            MEM_WB_mem_data <= d_read_data;
            MEM_WB_ALUOut <= EX_MEM_ALUOut;
            MEM_WB_wr_addr <= EX_MEM_wr_addr;
            MEM_WB_MemtoReg <= EX_MEM_MemtoReg;
            MEM_WB_RegWrite <= EX_MEM_RegWrite;
            MEM_WB_valid <= EX_MEM_valid;
        end
    end
    CTRL ctrl (
        .opcode(id_opcode),
        .funct(id_funct),
        .valid(IF_ID_inst != 32'b0),
        .ALUOp(ctrl_ALUOp),
        .ALUSrc(ctrl_ALUSrc),
        .RegDst(ctrl_RegDst),
        .MemRead(ctrl_MemRead),
        .MemWrite(ctrl_MemWrite),
        .MemtoReg(ctrl_MemtoReg),
        .RegWrite(ctrl_RegWrite),
        .Branch(ctrl_Branch),
        .BranchNE(ctrl_BranchNE),
        .SignExtend(ctrl_SignExtend),
        .Jump(ctrl_Jump),
        .JR(ctrl_JR),
        .JAL(ctrl_JAL),
        .use_rs(use_rs),
        .use_rt(use_rt)
    );

    RF rf (
        .clk(clk),
        .rst(rst),
        .rd_addr1(id_rs),
        .rd_addr2(id_rt),
        .rd_data1(rd_data1),
        .rd_data2(rd_data2),
        .RegWrite(MEM_WB_valid && MEM_WB_RegWrite && !memory_hold),
        .wr_addr(MEM_WB_wr_addr),
        .wr_data(wb_data)
    );

    ALU alu (
        .operand1(forwarded_A),
        .operand2(alu_operand2),
        .shamt(ID_EX_shamt),
        .funct(ID_EX_ALUOp),
        .alu_result(alu_result)
    );

    BTB btb (
        .clk(clk),
        .rst(rst),
        .pc(PC),
        .hit(btb_hit),
        .pc_type(btb_type),
        .target(btb_target),
        .update_en(btb_update_en),
        .update_pc(btb_update_pc),
        .update_target(btb_update_target),
        .update_type(btb_update_type)
    );

    PHT pht (
        .clk(clk),
        .rst(rst),
        .pc(PC),
        .predict_taken(pht_predict_taken),
        .update_en(pht_update_en),
        .update_pc(ID_EX_PC),
        .actual_taken(branch_actual_taken)
    );
endmodule
