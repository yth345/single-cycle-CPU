# single-cycle-CPU

### 1. Task
Design a single cycle CPU that can support the following instructions in RISC-V:  
- R-type: add, sub, xor
- I-type: addi, srai, slti, lw
- S-type: sw
- SB-type: beq
- J-type: jal, jalr
- U-type: auipc
- extension: mul

### 2. CPU Architecture
<img src="CPU-architecture-2.png" width="800">

### 3. Run Simulation
`$ ncverilog Final_tb.v +define+leaf +access+r`  
`$ ncverilog Final_tb.v +define+perm +access+r`  
`$ ncverilog Final_tb.v +define+bonus +access+r`

### 4. Coding Style Check
`$ dv -no_gui`  
`design_vision> read_verilog CHIP.v`  
`design_vision> exit`
