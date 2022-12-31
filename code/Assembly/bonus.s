.data
    n: .word 11  # test case: n = 11
.text
.globl __start


jal x0, __start
#----------------------------------------------------Do not modify above text----------------------------------------------------
FUNCTION:
# Todo: Define your own function
# We store the input n in register a0, and you should store your result in register a1
	addi sp, sp, -8
	sw x1, 4(sp)
	sw a0, 0(sp)
	addi x7, x0, 2
	slti x5, a0, 10
	beq x5, x0, cond1
	slti x5, a0, 1
	beq x5, x0, cond2
	
base:
	addi a1, x0, 7
	# lw x11, 0(sp)
	addi sp, sp, 8
	jalr x0, 0(x1)

cond1:
	# T(3/4n): save 3/4*a0 to a0
	addi x8, x0, 3
	mul x9, a0, x8
	srai a0, x9, 2
	jal x1, FUNCTION
	# 2 * T(3/4n)
	addi x6, a1, 0
	mul a1, x6, x7
	# + 7/8n - 137
	lw a0, 0(sp)
    lw x1, 4(sp)
    addi sp, sp, 8
    addi x8, x0, 7
    mul x9, a0, x8
    srai x9, x9, 3
    add a1, a1, x9
    addi a1, a1, -137
    jalr x0, 0(x1)
    
cond2:
	# T(n-1)
	addi a0, a0, -1
	jal x1, FUNCTION
	# 2 * T(n-1)
	addi x6, a1, 0
    lw a0, 0(sp)
    lw x1, 4(sp)
    addi sp, sp, 8
    mul a1, x6, x7
    jalr x0, 0(x1)

#----------------------------------------------------Do not modify below text----------------------------------------------------
__start:
    la   t0, n
    lw   a0, 0(t0)
    jal  x1, FUNCTION
    la   t0, n
    sw   a1, 4(t0)
    li a7, 10
    ecall
