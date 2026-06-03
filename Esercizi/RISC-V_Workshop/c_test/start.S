
.section .init
.globl _start

_start:
    # Set stack pointer
    la      sp, _stack_top
    
    # Setup main arguments in stack (null, null)
    addi    sp, sp, -8
    sw      x0, 0(sp)
    sw      x0, 4(sp)
    
    # Call main, returns in a0
    jal     main
    
    # Write main return code
    li      a2, 0x10010000
    sw      a0, 0(a2)

__park_loop:
    j __park_loop
