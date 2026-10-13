// 로직 쉽게 하기 위해 global에 define

// ALU
`define		ALU_ADDU			4'b0000
`define		ALU_AND				4'b0001
`define		ALU_NOR				4'b0010
`define		ALU_OR				4'b0011
`define		ALU_SLL				4'b0100
`define		ALU_SRA				4'b0101
`define		ALU_SRL				4'b0110
`define		ALU_SUBU			4'b0111
`define		ALU_XOR				4'b1000
`define		ALU_SLT				4'b1001
`define		ALU_SLTU			4'b1010
`define		ALU_EQ				4'b1011
`define		ALU_NEQ				4'b1100
`define		ALU_LUI				4'b1101

// FUNCT
`define		FUNCT_SLL			6'd0
`define		FUNCT_SRL			6'd2
`define		FUNCT_SRA			6'd3
`define 	FUNCT_JR			6'd8
`define		FUNCT_ADDU			6'd33
`define		FUNCT_SUBU			6'd35
`define		FUNCT_AND			6'd36
`define		FUNCT_OR			6'd37
`define		FUNCT_XOR			6'd38
`define		FUNCT_NOR			6'd39
`define		FUNCT_SLT			6'd42
`define		FUNCT_SLTU			6'd43

// OP_type
`define		OP_RTYPE			6'd0
`define		OP_J				6'd2
`define		OP_JAL				6'd3
`define		OP_BEQ				6'd4
`define		OP_BNE				6'd5
`define		OP_ADDIU			6'd9
`define		OP_SLTI				6'd10
`define		OP_SLTIU			6'd11
`define		OP_ANDI				6'd12
`define		OP_ORI				6'd13
`define		OP_XORI				6'd14
`define		OP_LUI				6'd15
`define		OP_LW				6'd35
`define		OP_SW				6'd43

///////////////////////////////
// multicycle용 global
/*
`define S_IF   3'd0
`define S_ID   3'd1
`define S_EX   3'd2
`define S_MEM  3'd3
`define S_WB   3'd4
`define S_JR   3'd5
`define S_JAL  3'd6
//
//control 부분 추가
//ALUSrcA
`define ALUSrcA_PC   1'b0
`define ALUSrcA_REG  1'b1
//ALUSrcB
`define ALUSrcB_REG   2'b00
`define ALUSrcB_4     2'b01
`define ALUSrcB_IMM   2'b10
`define ALUSrcB_IMM_S 2'b11
//PCsource
`define PCSource_ALU    2'b00
`define PCSource_ALUOut 2'b01
`define PCSource_JUMP   2'b10
//IorD
`define IorD_PC     1'b0
`define IorD_ALUOut 1'b1 */
///////////////////////////////////////////////\

// Reg destination T,D
`define     RegDst_RT   1'b0
`define     RegDst_RD   1'b1
// memory to Reg - ALU, MEM 부분
`define     MemtoReg_ALU 1'b0
`define     MemtoReg_MEM 1'b1

/// BTB
// BTB entry type
`define BTB_EMPTY   2'b00
`define BTB_JUMP    2'b01
`define BTB_BRANCH  2'b10
//PHT
`define SNT  2'b00  // Strongly Not Taken
`define WNT  2'b01  // Weakly Not Taken
`define WT  2'b10  // Weakly Taken
`define ST  2'b11  // Strongly Taken
