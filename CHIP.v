// Your code
module CHIP(clk,
            rst_n,
            // For mem_D
            mem_wen_D,
            mem_addr_D,
            mem_wdata_D,
            mem_rdata_D,
            // For mem_I
            mem_addr_I,
            mem_rdata_I
    );
    //==== I/O Declaration ========================
    input         clk, rst_n ;
    // For mem_D
    output        mem_wen_D  ;
    output [31:0] mem_addr_D ;
    output [31:0] mem_wdata_D;
    input  [31:0] mem_rdata_D;
    // For mem_I
    output [31:0] mem_addr_I ;
    input  [31:0] mem_rdata_I;

    //==== Reg/Wire Declaration ===================
    //---------------------------------------//
    // Do not modify this part!!!            //
    // Exception: You may change wire to reg //
    reg    [31:0] PC          ;              //
    reg    [31:0] PC_nxt      ;              //
    wire          regWrite    ;              //
    wire   [ 4:0] rs1, rs2, rd;              //
    wire   [31:0] rs1_data    ;              //
    wire   [31:0] rs2_data    ;              //
    reg    [31:0] rd_data     ;              //
    //---------------------------------------//

    // Todo: other wire/reg
    wire valid, ready;

    reg         mem_wen_D;
    reg  [31:0] mem_addr_D;
    reg  [31:0] mem_wdata_D;

    reg  [31:0] code;
    wire [ 3:0] instr;
    wire [19:0] imm20;
    wire [11:0] imm12;
    wire [32:0] alu_result;  // +1 bit for overflow?
    wire [63:0] mul_result;

    //==== Instruction ============================
    parameter AUIPC = 4'd0;
    parameter JAL   = 4'd1;
    parameter JALR  = 4'd2;
    parameter BEQ   = 4'd3;
    parameter LW    = 4'd4;
    parameter SW    = 4'd5;
    parameter ADDI  = 4'd6;
    parameter SLTI  = 4'd7;
    parameter ADD   = 4'd8;
    parameter SUB   = 4'd9;
    parameter XOR   = 4'd10;
    parameter MUL   = 4'd11;
    parameter SRAI  = 4'd12;


    //==== Submodule Connection ===================
    //---------------------------------------//
    // Do not modify this part!!!            //
    reg_file reg0(                           //
        .clk(clk),                           //
        .rst_n(rst_n),                       //
        .wen(regWrite),                      //
        .a1(rs1),                            //
        .a2(rs2),                            //
        .aw(rd),                             //
        .d(rd_data),                         //
        .q1(rs1_data),                       //
        .q2(rs2_data));                      //
    //---------------------------------------//

    // Todo: other submodules
    ID id0(
        .code(code),
        .instr(instr),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm20(imm20),
        .imm12(imm12)
    );

    EX ex0(
        .instr(instr),
        .rs1_d(rs1_data),
        .rs2_d(rs2_data),
        .imm20(imm20),
        .imm12(imm12),
        .PC(PC),
        .result(alu_result)
    );

    mulDiv mul0(
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .ready(ready),
        .in_A(rs1_data),
        .in_B(rs2_data),
        .out(mul_result)
    );


    //==== Combinational Part =====================
    // 0. control
    assign regWrite = (instr == BEQ || instr == SW || (instr == MUL && !ready)) ? 0 : 1;
    assign valid = (instr == MUL) ? 1 : 0;

    // 1. IF: instruction fetch
    assign mem_addr_I = PC;

    // 2. ID: instruction decode
    // decode in ID submodule
    // read register in reg_file submodule
    always @(*) begin
        code = mem_rdata_I;
    end

    // 3. EX: execute
    // calculate alu_result in EX submodule
    // update PC_nxt
    always @(*) begin
        case (instr)
            BEQ: begin 
                if (alu_result == 0) begin
                    PC_nxt = PC + {{19{imm12[11]}}, imm12, 1'b0};
                end
                else PC_nxt = PC + 4;
            end
            JAL:   PC_nxt = alu_result;
            JALR:  PC_nxt = alu_result;
            MUL: begin
                if (ready) PC_nxt = PC + 4;
                else       PC_nxt = PC;
            end
            default: PC_nxt = PC + 4;
        endcase
    end

    // 4. MEM: memory access
    always @(*) begin
        case (instr)
            LW: begin
                mem_wen_D = 0;
                mem_addr_D = alu_result;
                mem_wdata_D = 0;
            end
            SW: begin
                mem_wen_D = 1;
                mem_addr_D = alu_result;
                mem_wdata_D = rs2_data;
            end
            default: begin
                mem_wen_D = 0;
                mem_addr_D = 0;
                mem_wdata_D = 0;
            end
        endcase
    end

    // 5. WB: write back
    always @(*) begin
        case (instr)
            AUIPC: rd_data = alu_result;
            JAL:   rd_data = PC + 4;
            JALR:  rd_data = PC + 4;
            LW:    rd_data = mem_rdata_D;
            ADDI:  rd_data = alu_result;
            SLTI:  rd_data = alu_result;
            ADD:   rd_data = alu_result;
            SUB:   rd_data = alu_result;
            XOR:   rd_data = alu_result;
            MUL:   rd_data = mul_result;
            SRAI:  rd_data = alu_result;
            default: rd_data = 0;
        endcase
    end

    //==== Sequential Part ========================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC <= 32'h00400000; // Do not modify this value!!!
        end
        else begin
            PC <= PC_nxt;
        end
    end
endmodule


module reg_file(clk, rst_n, wen, a1, a2, aw, d, q1, q2);

    parameter BITS = 32;
    parameter word_depth = 32;
    parameter addr_width = 5; // 2^addr_width >= word_depth

    input clk, rst_n, wen; // wen: 0:read | 1:write
    input [BITS-1:0] d;
    input [addr_width-1:0] a1, a2, aw;

    output [BITS-1:0] q1, q2;

    reg [BITS-1:0] mem [0:word_depth-1];
    reg [BITS-1:0] mem_nxt [0:word_depth-1];

    integer i;

    assign q1 = mem[a1];
    assign q2 = mem[a2];

    always @(*) begin
        for (i=0; i<word_depth; i=i+1)
            mem_nxt[i] = (wen && (aw == i)) ? d : mem[i];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem[0] <= 0; // zero: hard-wired zero
            for (i=1; i<word_depth; i=i+1) begin
                case(i)
                    32'd2: mem[i] <= 32'h7fffeffc; // sp: stack pointer
                    32'd3: mem[i] <= 32'h10008000; // gp: global pointer
                    default: mem[i] <= 32'h0;
                endcase
            end
        end
        else begin
            mem[0] <= 0;
            for (i=1; i<word_depth; i=i+1)
                mem[i] <= mem_nxt[i];
        end
    end
endmodule



module mulDiv(clk, rst_n, valid, ready, in_A, in_B, out);
    // Todo: your HW2
    input         clk, rst_n;
    input         valid;
    output        ready;
    input  [31:0] in_A, in_B;
    output [63:0] out;

    reg [ 1:0] state, state_nxt;
    reg [ 4:0] counter, counter_nxt;
    reg [63:0] shreg, shreg_nxt;
    reg [31:0] alu_in, alu_in_nxt;
    reg [31:0] alu_out;

    // state
    parameter IDLE = 2'd0;
    parameter MULDIV = 2'd1;
    parameter OUT = 2'd2;


    assign out = shreg;
    assign ready = (state == OUT) ? 1 : 0;

    // Combinational always block
    // FSM
    always @(*) begin
        case (state)
            IDLE: begin
                if (valid) state_nxt = MULDIV;
                else state_nxt = IDLE;
            end
            MULDIV: begin
                if (counter == 31) state_nxt = OUT;
                else state_nxt = MULDIV;
            end
            OUT: state_nxt = IDLE;
            default: state_nxt = IDLE;
        endcase
    end

    // counter
    always @(*) begin
        if (state == MULDIV) counter_nxt = counter + 1;
        else counter_nxt = 0;
    end
    
    // ALU input
    always @(*) begin
        case (state)
            IDLE: begin
                if (valid) alu_in_nxt = in_B;
                else       alu_in_nxt = 0;
            end
            MULDIV:  alu_in_nxt = alu_in;
            OUT:     alu_in_nxt = 0;
            default: alu_in_nxt = 0;
        endcase
    end

    // ALU output
    always @(*) begin
        if (state == MULDIV) begin
            if (shreg[0] == 1'b1) alu_out = shreg[63:32] + alu_in;
            else                  alu_out = shreg[63:32];
        end
        else alu_out = 33'd0;
    end

    // shift register
    always @(*) begin
        case (state)
            IDLE: begin
                if (valid) shreg_nxt = {32'b0, in_A};
                else       shreg_nxt = shreg;
            end
            MULDIV:  shreg_nxt = {alu_out, shreg[31:1]};
            default: shreg_nxt = shreg;
        endcase
    end

    // Sequential always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= OUT;
            counter <= 0;
            shreg <= 0;
            alu_in <= 0;
        end
        else begin
            state <= state_nxt;
            counter <= counter_nxt;
            shreg <= shreg_nxt;
            alu_in <= alu_in_nxt;
        end
    end
endmodule



module ID(code, instr, rd, rs1, rs2, imm20, imm12);
    // input instruction code
    // output code segment for later use
    input  [31:0] code;
    output [ 3:0] instr;
    output [ 4:0] rd, rs1, rs2;
    output [19:0] imm20;
    output [11:0] imm12;

    reg [ 3:0] type;
    reg [ 4:0] rd, rs1, rs2;
    reg [19:0] imm20;
    reg [11:0] imm12;

    parameter AUIPC = 7'b10111;
    parameter JAL   = 7'b1101111;
    parameter JALR  = 7'b1100111;
    parameter BEQ   = 7'b1100011;
    parameter LW    = 7'b11;
    parameter SW    = 7'b100011;
    parameter ALUI  = 7'b10011;
    parameter ALU   = 7'b110011;

    parameter ADDI  = 3'b0;
    parameter SLTI  = 3'b10;
    parameter SRAI  = 3'b101;
    parameter ADD   = 4'b0;
    parameter SUB   = 4'b1000;
    parameter XOR   = 4'b100;

    assign instr = type;

    always @(*) begin
        rd = 0;
        rs1 = 0;
        rs2 = 0;
        imm20 = 0;
        imm12 = 0;
        case (code[6:0])
            AUIPC: begin
                type = 4'd0;
                rd = code[11:7];
                imm20 = code[31:12];
            end
            JAL: begin
                type = 4'd1;
                rd = code[11:7];
                imm20 = {code[31], code[19:12], code[20], code[30:21]};
            end
            JALR: begin
                type = 4'd2;
                rd = code[11:7];
                rs1 = code[19:15];
                imm12 = code[31:20];
            end
            BEQ: begin
                type = 4'd3;
                rs1 = code[19:15];
                rs2 = code[24:20];
                imm12 = {code[31], code[7], code[30:25], code[11:8]};
            end
            LW: begin
                type = 4'd4;
                rd = code[11:7];
                rs1 = code[19:15];
                imm12 = code[31:20];
            end
            SW: begin
                type = 4'd5;
                rs1 = code[19:15];
                rs2 = code[24:20];
                imm12 = {code[31:25], code[11:7]};
            end
            ALUI: begin
                rd = code[11:7];
                rs1 = code[19:15];
                case (code[14:12])
                    ADDI: begin 
                        type = 4'd6;
                        imm12 = code[31:20];
                    end
                    SLTI: begin
                        type = 4'd7;
                        imm12 = code[31:20];
                    end
                    SRAI: begin
                        type = 4'd12;
                        imm12 = {7'b0, code[24:20]};
                    end
                    default: begin
                        type = 4'd6;
                        imm12 = 12'b0;
                    end
                endcase
            end
            ALU: begin
                rd = code[11:7];
                rs1 = code[19:15];
                rs2 = code[24:20];
                if (code[31:25] == 7'b1) type = 4'd11;  // MUL
                else begin
                    case ({code[30], code[14:12]})
                        ADD: type = 4'd8;
                        SUB: type = 4'd9;
                        XOR: type = 4'd10;
                        default: type = 4'd8;
                    endcase
                end
            end
            default: type = 4'd0;
        endcase
    end
endmodule


module EX(instr, rs1_d, rs2_d, imm20, imm12, PC, result);
    input  [ 3:0] instr;
    input  [31:0] rs1_d, rs2_d;
    input  [19:0] imm20;
    input  [11:0] imm12;
    input  [31:0] PC;
    output [32:0] result;  // +1 bit for overflow?

    reg    [32:0] result;

    parameter AUIPC = 4'd0;
    parameter JAL   = 4'd1;
    parameter JALR  = 4'd2;
    parameter BEQ   = 4'd3;
    parameter LW    = 4'd4;
    parameter SW    = 4'd5;
    parameter ADDI  = 4'd6;
    parameter SLTI  = 4'd7;
    parameter ADD   = 4'd8;
    parameter SUB   = 4'd9;
    parameter XOR   = 4'd10;
    parameter MUL   = 4'd11;
    parameter SRAI  = 4'd12;

    always @(*) begin
        case (instr)
            AUIPC: result = {imm20, 12'b0} + PC;
            JAL:   result = PC + {{11{imm20[19]}}, imm20, 1'b0}; // write PC+4 to rd later
            JALR:  result = rs1_d + {{20{imm12[11]}}, imm12};
            BEQ:   result = rs1_d - rs2_d;
            LW:    result = rs1_d + {{20{imm12[11]}}, imm12};
            SW:    result = rs1_d + {{20{imm12[11]}}, imm12};
            ADDI:  result = rs1_d + {{20{imm12[11]}}, imm12};
            SLTI:  result = rs1_d < {{20{imm12[11]}}, imm12} ? 1 : 0;
            ADD:   result = rs1_d + rs2_d;
            SUB:   result = rs1_d - rs2_d;
            XOR:   result = rs1_d ^ rs2_d;
            SRAI:  result = rs1_d >>> imm12;
            default: result = 0;
        endcase
    end
endmodule
