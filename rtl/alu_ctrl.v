module alu_ctrl (
    input [2:0]  funct3,
    input [6:0]  funct7,
    input [1:0]  aluCtrlOp,
    input        itype,   // I型指令类型的判断信号
    output reg [3:0] aluOp
);

    always @(*) begin
        case (param)
            2'b00:  aluOp <= `ALU_OP_ADD;           // Load or Store 根据ricv手册 Load或store地址 需要进行地址计算rs + imm
            2'b01: begin
                if (itype & func3[1:0] != 2'b0) begin
                    aluOp <= {1'b0, func3};
                end
                else begin
                    aluOp <= {funct7[5], funct3};   // normal ALUI/ALUR
                end
            end
            2'b10:  begin
                case(func3)
                    `BEQ_FUNCT3:  aluOp <= `ALU_OP_EQ;
                    `BNE_FUNCT3:  aluOp <= `ALU_OP_NEQ;
                    `BLT_FUNCT3:  aluOp <= `ALU_OP_SLT;
                    `BGE_FUNCT3:  aluOp <= `ALU_OP_GE;
                    `BLTU_FUNCT3: aluOp <= `ALU_OP_SLTU;
                    `BGEU_FUNCT3: aluOp <= `ALU_OP_GEU;
                    default:      aluOp <= `ALU_OP_XXX;
                endcase
            end
            default: aluOp <= `ALU_OP_XXX;
        endcase

    end
endmodule