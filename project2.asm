.data
file: .asciiz "MIPS-MIDI-player/loz_title.mid" # cwd is the location of the jar
.text

main:
    li $v0, 13                   # system call for open file
    la $a0, file                 
    li $a1, 0                    # open for reading
    li $a2, 0                    
    syscall                      # open the file
    move $s7, $v0                # load file descriptor

while_loop:

    move $a0, $s7                # load file descriptor
    li $a1, 4                    # how many bytes to read
    jal read_bytes               # call read_bytes
    lw $s0, ($v0)                # load word
    addi $gp, $gp, -4            # deallocate space on heap

    beq $s0 $zero, end_of_file   # goto end_of_file if at eof
    move $a0, $s7                # load file descriptor

    li $s1, 0x4d546864           # load Header Chunk id
    bne $s1, $s0, cond_1_f       # branch if not equal: skip header
    jal parse_header
    move $s2, $v0                # store track quantity
    move $s3, $v1                # store time division
cond_1_f:

    j while_loop
end_of_file:
    li $v0, 16                   # close file
    move $a0, $s0                # close file
    syscall                      # close file

    li $v0, 10                   # end program
    syscall                      # end program

# $a0 = file descriptor
# $v0 = track quantity
# $v1 = time division
parse_header:
    # Store $s* in stack to be restored
    addi $sp, $sp, -12
    sw $s0, 0($sp)
    sw $s7, 4($sp)
    sw $ra, 8($sp)

    # load arguments
    move $s7, $a0

    # Read in chunk size
    move $a0, $s7
    li $a1, 4                    # how many bytes to read
    jal read_bytes
    lw $s0, ($v0)                # load word into $s0
    addi $gp, $gp, -4            # deallocate space on heap

    # Read in format type, track quantity and time division
    move $a0, $s7                
    move $a1, $s0                # how many bytes to read
    jal read_bytes
    lw $t1, 0($v0)               # load word into $t1
    sub $gp, $gp, $s0            # deallocate space on heap

    # return track quantity and time division
    andi $v0, $t1, 0xFFFF0000    # mask out track quantity
    srl $v0, $v0, 16             # shift track quantity to the right
    andi $v1, $t1, 0x0000FFFF    # mask out time division

    # restore $s* and $ra
    lw $s7, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# $a0 = file descriptor
# $a1 = amount of bytes to read
# $v0 = address of last byte on heap
read_bytes:
    # Store $s* and $ra in stack to be restored
    addi $sp, $sp, -32
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s3, 8($sp)
    sw $s4, 12($sp)
    sw $s5, 16($sp)
    sw $s6, 20($sp)
    sw $s7, 24($sp)
    sw $ra, 28($sp)

    move $s7, $a0                # load file descriptor
    move $s6, $a1                # store byte amount in $s6 to use as counter in loop
    move $s5, $a1                # store byte amount in $s5 for later use
    li $s4, 4 
    li $s3, 1

    # Allocate space on heap and stack
    add $gp, $gp, $a1
    addi $sp, $sp, -4

    # For each byte to read
rb_loop:
    blt $s6, $s3,  rb_end        # if amount of bytes to read is 0, return

    # Read in byte
    li $v0, 14                   
    move $a0, $s7                
    la $a1, 0($sp)               
    li $a2, 1                    # max input size (1 byte)
    syscall

    lw $s0, 0($sp)               # load byte from stack into $s0

    sub $s1, $gp, $s3            # Calculate byte address on heap
    sb $s0, ($s1)                # store byte in heap
    addi $s3, $s3, 1             # increment byte counter
    j rb_loop

rb_end:
    addi $sp $sp, 4              # deallocate space on stack
    move $v0, $s1                # Return address to last byte on heap

    # Restore $s* and $ra
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s3, 8($sp)
    lw $s4, 12($sp)
    lw $s5, 16($sp)
    lw $s6, 20($sp)
    lw $s7, 24($sp)
    lw $ra, 28($sp)
    addi $sp, $sp, 32

    jr $ra                       # Return
