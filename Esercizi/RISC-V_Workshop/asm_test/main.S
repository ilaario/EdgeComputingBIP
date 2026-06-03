
.section .init
.globl _start

_start:
    la a0, hello_str
    li a1, 0x10020000

print_loop:
    lb   t0, 0(a0)
    beqz t0, end_print
    sb   t0, 0(a1)
    addi a0, a0, 1
    j    print_loop 

end_print:
    # Return 0
    li      a2, 0x10010000
    li      a0, 0
    sw      a0, 0(a2)

__park_loop:
    j __park_loop


hello_str:
    .string "Hello from RISC-V asm!"