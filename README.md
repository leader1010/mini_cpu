# mini_cpu
 mini_cpu by RISC-V



## CPU架构设计

<img src="https://s2.loli.net/2024/08/02/bYZUMgSDwF3oWcm.png"/>



![image-20240802003309495](https://s2.loli.net/2024/08/02/RZhUlvtAFWGiCEM.png)

根据CPU流水线作业5个阶段

取指阶段（Instruction Fetch）：取指阶段是指将指令从存储器中读取出来的过程。程序指针寄存器用来指定当前指令在存储器中的位置。读取一条指令后，程序指针寄存器会根据指令的长度自动递增，或者改写成指定的地址。

译码阶段（Instruction Decode）：指令译码是指将存储器中取出的指令进行翻译的过程。指令译码器对指令进行拆分和解释，识别出指令类别以及所需的各种操作数。

执行阶段（Instruction Execute）：指令执行是指对指令进行真正运算的过程。例如指令是一条加法运算指令，则对操作数进行相加操作；如果是一条乘法运算指令，则进行乘法运算。在“执行”阶段最关键的模块为算术逻辑单元（Arithmetic Logical Unit，ALU），它是实施具体运算的硬件功能单元。

访存阶段（Memory Access）：访存是指存储器访问指令将数据从存储器中读出，或写入存储器的过程。

写回阶段（Write-Back）：写回是指将指令执行的结果写回通用寄存器的过程。如果是普通运算指令，该结果值来自于“执行”阶段计算的结果；如果是存储器读指令，该结果来自于“访存”阶段从存储器中读取出来的数据。

可相应设计5个模块





## 取指阶段

### 预读取模块 pre_if

```verilog
module pre_if (
    input [31:0] instr,
    input [31:0] pc,

    output [31:0] pre_pc
);

wire is_bxx = (instr[6:0] == OPCODE_BRANCH);
wire is_jal = (instr[6:0] == OPCODE_BRANCH);

 //B型指令的立即数拼接
//{{20{instr[31]}}} 表示将instr[31]（指令的最高位）扩展20位，用于填充立即数的高位。
// instr[7] 是条件跳转指令中的一个特定位。
// instr[30:25] 和 instr[11:8] 分别代表了立即数的不同部分。
// 1'b0 是附加的0，因为指令地址是2的幂次对齐的，所以最低位总是0。
wire [31:0] bimm =  {{20{instr[31]}}, instr[7],instr[30:25], instr[11:8], 1'b0};
 //J型指令的立即数拼接
wire [31:0] jimm = {{12{instr[31]}},  instr[19:12], instr[20], instr[30:21], 1b'0};

// B型指令bimm[31]通常用于条件判断 这里也这么规定
wire [31:0] addr = is_jal ? jimm : (is_bxx & bimm[31])? bimm : 4;
assign pre_pc = pc + addr;
    
endmodule
```

在一个没有流水线的CPU中，`pc`指向下一条指令的地址，CPU会按照以下步骤执行指令：

1. 使用`pc`从内存中取出指令（取指操作）。
2. 对取出的指令进行译码，确定指令类型和操作数等信息。
3. 执行指令。

引入流水线后，这些步骤可以重叠，以提高CPU的吞吐量。以下是结合波形的关系描述：

- **时钟周期T1**：`pc`指向第一条指令的位置，CPU在第一个时钟周期内完成取指操作，读取`instr`。
- **时钟周期T2**：在第二个时钟周期，CPU开始对第一条指令进行译码，同时`pc`增加指向下一条指令的地址，并开始取下一条指令。
- **时钟周期T3**：在第三个时钟周期，CPU可以同时进行取指、译码和执行操作。如果使用的是五级流水线，那么到第五个时钟周期时，可以同时有5个操作在进行。

预读取电路的作用是在当前指令还在译码或执行阶段时，提前读取下一条指令。这通过以下方式实现：

- 根据当前的`pc`值和指令的偏移量（可能是固定的4字节，或者对于跳转指令是特定的偏移量），计算出预测的下一个`pc`值（`pre_pc`）。
- 使用这个预测的`pc`值提前从内存中读取下一条指令。



### 取指数据通路模块 if_id

  由上述的指令预读取模块把指令从存储器中读取之后，需要把它发送给译码模块进行翻译。但是，预读取模块读出的指令，并不是全部都能发送后续模块去执行。例如上面的条件分支指令，在指令完成之前就把后续的指令预读取出来了。如果指令执行之后发现跳转的条件不成立，这时预读取的指令就是无效的，需要对流水线进行冲刷（flush），把无效的指令都清除掉。完整代码见github代码仓

``````verilog
//指令通路 
always @(posedge clock) begin
    if (reset) begin
        reg_instr <= 32'h0;
    end else if (flush) begin
        reg_instr <= 32'h0;
    end else if (valid) begin
        reg_instr <= in_instr;
    end end
``````





## 译码阶段 

控制逻辑和数据传输逻辑分开

### 译码模块 decode

解析出功能码funct3 funct7，源寄存器 rs1，rs2，目标寄存器rd 以及立即数（见github代码仓）

``````verilog
//---------- decode rs1、rs2 -----------------
assign rs1_addr = instr[19:15]; 
assign rs2_addr = instr[24:20];
//---------- decode rd -----------------------
assign rd_addr = instr[11:7]; 
//---------- decode funct3、funct7 -----------
assign funct7 = instr[31:25]; 
assign funct3 = instr[14:12]; 
``````



### 译码控制模块  id_ex_ctrl

  从存储器中读取出来的指令，不一定都能够给到执行单元去执行的。比如，当指令发生冲突时，需要对流水线进行冲刷，这时就需要清除流水线中的指令。同样的，译码阶段的指令信号也需要清除。译码控制模块就是为了实现这一功能。而此模块负责处理控制信号，例如跳转 (`jump`)、分支 (`branch`)、内存读取 (`mem_read`)、内存写入 (`mem_write`)、寄存器写入 (`reg_write`) 等信号

``````verilog
always @(posedge clk or posedge reset) begin
    if (reset) begin
        reg_noflush <= 1'h0;
    end else if (flush) begin
        reg_noflush <= 1'h0;
    end else if (valid) begin
        reg_noflush <= in_noflush;
    end
end
``````



### 译码数据通路模块 id_ex

​	此模块负责处理数据信息,入rs2数据

``````verilog
always @(posedge clk or posedge reset) begin
    if (reset) begin
        reg_rs2_addr <= 5'h0;
    end else if (flush) begin
        reg_rs2_addr <= 5'h0;
    end else if (valid) begin
        reg_rs2_addr <= in_rs2_addr;
    end
end
``````





## 执行阶段

  执行阶段可将指令分为三类**算术逻辑指令**、**分支跳转指令**、**存储器访问指令**。在 ALU 模块中，指令可以分成三类来处理：**第一类是普通的 ALU 指令，包括逻辑运算、移位操作等指令；第二类指令负责完成存储器访问指令 Load 和 Store 的地址生成工作；第三类是负责分支跳转指令的结果解析和执行。**这就是流水线执行阶段的核心模块 ALU 的设计思路。

![image-20240825225551730](https://s2.loli.net/2024/08/25/8sBAHuJdSVbvz5h.png)



### 执行控制模块 alu_ctrl

  在译码模块里根据指令的 7 位操作码 opcode 字段，还产生了一个 ALU 执行的指令控制字段 aluCrtlOp。

![image-20240825232741256](https://s2.loli.net/2024/08/25/HtUXcLFJVW5Of2Y.png)

  根据 2 位执行类型字段 aluCrtlOp，以及指令译码得到的操作码 funct7 和 funct3，就可以设计执行控制模块了

~~~~~~verilog
module ALUCtrl (
    input [2:0]  funct3,
    input [6:0]  funct7,
    input [1:0]  aluCtrlOp,
    input        itype,
    output reg [3:0] aluOp
);
    always @(*) begin
      case(aluCtrlOp)
        2'b00:  aluOp <= `ALU_OP_ADD;           // Load/Store
        2'b01:  begin
          if(itype & funct3[1:0] != 2'b01)
            aluOp <= {1'b0, funct3};
          else
            aluOp <= {funct7[5], funct3};   // normal ALUI/ALUR
        end
        2'b10:  begin
          case(funct3)                    // bxx
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
~~~~~~

  这里要注意的是，当 aluCtrlOp 等于（01）时，需要根据 funct3 和 funct7 产生 ALU 的操作码。在前面的译码模块中，已经为我们提供了 I 型指令类型的判断信号 itype。如果是 itype 信号等于“1”，操作码直接由 funct3 和高位补“0”组成；如果不是 I 型指令，ALU 操作码则要由 funct3 和 funct7 的第五位组成。



### 通用寄存器 gen_reg

​    在 ALU 模块开始执行运算之前，还需要提前完成一个操作——读取通用寄存器。在参与 ALU 逻辑运算的两个操作数中，至少有一个来自于通用寄存器，另一个可以来自于通用寄存器或者指令自带的立即数。另外，**处于流水线上的指令是并发执行的，在读取通用寄存器的同时，可能还需要写入数据到通用寄存器，所以需要一套写地址和写数据接口**

~~~~~~verilog
assign regRData1 = wen & (regWAddr == regRAddr1) ? regWData : ((regRAddr1 != 5'b0) ? regs[regRAddr1] : 32'b0); 
assign regRData2 = wen & (regWAddr == regRAddr2) ? regWData : ((regRAddr2 != 5'b0) ? regs[regRAddr2] : 32'b0);
~~~~~~



### ALU 模块设计 alu

略

