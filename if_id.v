module if_id (
    input clk,
    input reset,
    input [31:0] in_instr,
    input [31:0] in_pc,
    input flush,
    input valid,

    output [31:0] out_instr,
    output [31:0] out_pc,
    output out_noflush

);  
    // 使用reg信号类型 进行状态保持 确保流水线设计的准确性和准确性
    reg [31:0] reg_instr;
    reg [31:0] reg_pc;
    // 其他上下文中使用
    reg [31:0] reg_pc_next;
    reg reg_noflush;
    
    // 指令传递
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_instr <= 32'h0;
        end
        else if (flush) begin
            reg_instr <= 32'h0;
        end
        else if (valid) begin
            reg_instr <= in_instr;
        end
        
    end


    // pc计数值传递
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_pc = <= 32'h0;
        end
        else if (flush) begin
            reg_pc = <= 32'h0;
        end
        else if (valid) begin
            reg_pc = in_pc;
        end
        
    end

    // 冲刷标志位
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_noflush <= 1'h0;
        end
        else if (flush) begin
            reg_noflush <= 1'h0;
        end
        else if (valid) begin
            reg_noflush = 1'h1;
        end
        
    end
    
endmodule