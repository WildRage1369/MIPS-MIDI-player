.data
file: .asciiz "loz_title.mid" # cwd is the location of the jar
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
    li $a1, 8                    # how many bytes to read
    jal read_bytes               # call read_bytes
    lw $s0, ($v0)                # load word

    beq $s0 $zero, end_of_file   # goto end_of_file if at eof
    move $a0, $s7                # load file descriptor

    li $s1, 0x6468544d           # load Header Chunk id
    bne $s1, $s0, cond_1_f       # branch if equal: goto parse_header
    la $s6, parse_header
    jalr $s6
    addi $sp, $sp, -8            # allocate space for return values
    sw $v0, 0($sp)               # store track quantity
    sw $v1, 4($sp)               # store time division
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
    move $s7, $a0                # load file descriptor

    # Read in chunk size
    li $v0, 14                   # load read file system call
    move $a0, $s7                # load file descriptor
    addi $sp, $sp, -4            # allocate space for len buffer
    la $a1, 0($sp)               # load len buffer
    li $a2, 2                    # max input size (4 bytes)
    syscall                      # read file syscall

    lw $s0, 0($sp)               # load len buffer data into $s0
    addi $sp, $sp, 4             # deallocate len buffer

    # Read in track quantity and time division
    li $v0, 14                   # load read file system call
    move $a0, $s7                # load file descriptor
    sub $sp, $sp, $s0            # allocate space for etc buffer
    la $a1, 0($sp)               # load etc buffer
    move $a2, $s0                # max input size (6 bytes)
    syscall                      # read file syscall

    lw $s0, 0($sp)               # load etc buffer data into $s0
    addi $sp, $sp, 4             # deallocate etc buffer

    # return track quantity and time division
    andi $v0, $s0, 0x00FF00      # mask out track quantity
    andi $v1, $s0, 0x0000FF      # mask out time division
    jr $ra                       # return

# $a0 = file descriptor
# $v0 = word
read_word:
    # Store $s0 and $s1 to be restored
    addi $sp, $sp, -8
    sw $s0, 0($sp)
    sw $s1, 4($sp)

    move $s7 $a0                 # load file descriptor
    addi $sp, $sp, -4            # allocate space for buffer

    li $v0, 14                   # load open file system call
    move $a0, $s7                # load file descriptor
    la $a1, 0($sp)               # load buffer
    li $a2, 1                    # max input size (1 byte)
    syscall                      # read byte 1

    lw $s0, 0($sp)               # load byte 1 into $s0
    sll $v1, $s0, 24             # shift byte 1 left 3 bytes (0xXX00 0000)

    li $v0, 14                   # load open file system call
    move $a0, $s7                # load file descriptor
    la $a1, 0($sp)               # load buffer
    li $a2, 1                    # max input size (1 byte)
    syscall                      # read byte 2

    lw $s0, 0($sp)               # load byte 2 into $s0
    sll $s0, $s0, 16             # shift byte 2 left 2 bytes
    or $v1, $v1, $s0             # combine buffer data (0xXXXX 0000)

    li $v0, 14                   # load open file system call
    move $a0, $s7                # load file descriptor
    la $a1, 0($sp)               # load buffer
    li $a2, 1                    # max input size (1 byte)
    syscall                      # read byte 3

    lw $s0, 0($sp)               # load byte 3 into $s0
    sll $s0, $s0, 8              # shift byte 3 left 1 byte
    or $v1, $v1, $s0             # combine buffer data (0xXXXX XX00)

    li $v0, 14                   # load open file system call
    move $a0, $s7                # load file descriptor
    la $a1, 0($sp)               # load buffer
    li $a2, 1                    # max input size (1 byte)
    syscall                      # read byte 4

    lw $s0, 0($sp)               # load byte 4 into $s0
    or $v1, $v1, $s0             # combine buffer data (0xXXXX XXXX)
    move $v0, $v1                # return word

    addi $sp, $sp, 4             # deallocate buffer

    # Restore $s0 and $s1
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    addi $sp, $sp, 8

    jr $ra                       # Return

# $a0 = file descriptor
# $a1 = amount of bytes to read
# $v0 = address of first byte on heap
read_bytes:
    # Store $s0 and $s1 to be restored
    addi $sp, $sp, -8
    sw $s0, 0($sp)
    sw $s1, 4($sp)

    move $s7, $a0                # load file descriptor
    move $s6, $a1                # store byte amount in $s6 to use as counter in loop
    move $s5, $a1                # store byte amount in $s5 for later use

    # Allocate space on heap and stack
    add $gp, $gp, $a1
    addi $sp, $sp, -4

    # For each byte to read
rb_loop:
    beq $s6, $zero,  rb_end      # if amount of bytes to read is 0, return

    # Read in byte
    li $v0, 14                   
    move $a0, $s7                
    la $a1, 0($sp)               
    li $a2, 1                    # max input size (1 byte)
    syscall                      

    lw $s0, 0($sp)               # load byte from stack into $s0

    sub $s1, $gp, $s6            # Calculate byte address on heap
    sb $s0, ($s1)                # store byte in heap
    addi $s6, $s6, -1            # increment (-) byte counter
    j rb_loop                    

rb_end:
    la $v0, ($gp)             # Return address to first byte on heap
    add $v0, $v0, $s5         # Add offset to return address

    # Restore $s0 and $s1
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    addi $sp, $sp, 8

    jr $ra                       # Return
