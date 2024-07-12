module pre_if (
    input [31:0] instr,
    input [31:0] pc,

    output [31:0] pre_pc
);

wire is_bxx = (instr[6:0] == OPCODE_BRANCH);
wire is_jal = (instr[6:0] == OPCODE_BRANCH);

//{{20{instr[31]}}} 表示将instr[31]（指令的最高位）扩展20位，用于填充立即数的高位。
// instr[7] 是条件跳转指令中的一个特定位。
// instr[30:25] 和 instr[11:8] 分别代表了立即数的不同部分。
// 1'b0 是附加的0，因为指令地址是2的幂次对齐的，所以最低位总是0。
wire [31:0] bimm =  {{20{instr[31]}}, instr[7],instr[30:25], instr[11:8], 1'b0};


    
endmodule