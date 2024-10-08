.data
    file: .asciiz "projects/MIPS-MIDI-player/loz_title.mid" # cwd is the location of the jar
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
parse_event:
    # Event format:
    # var-len dtime, 4bit event type, 1byte param1, 1byte param2
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
    lw $t0, ($v0)                # load word into $t0
    addi $gp, $gp, -4            # deallocate space on heap

    # Read in delta time
    jal parse_delta_time
    move $s0, $v0

    # restore $s* and $ra
    lw $s7, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# $a0 = file descriptor
# $a1 = ms/tick
# $v0 = delta time
parse_delta_time:
    # Store $s* in stack to be restored
    addi $sp, $sp, -16
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s7, 8($sp)
    sw $ra, 12($sp)

    li $s1 0                     # counter in loop
    move $sp, $fp
pdt_loop:
    # Read in byte
    move $a0, $s7
    li $a1, 1                    # how many bytes to read
    jal read_bytes
    lw $t0, ($v0)                # load word into $t0
    sub $gp, $gp, 1              # deallocate space on heap
    andi $s0, $t0, 0x80          # mask and store MSB in $s0
    andi $t0, $t0, 0x7F          # mask out MSB
    addi $sp, $sp, -1            # allocate space in stack
    sb $t0, 0($sp)               # store dtime on stack

    addi $s1, $s1, 1             # increment counter
    beq $s0, $zero, pdt_end      # if MSB in byte is 0
pdt_end:
    lw $t0, ($fp)                # load dtime from stack
    add $sp, $sp, $s1            # deallocate space on stack

    addi $t1, $sp, 32            # calculate shift amount
    srl $t0, $t0, $t1            # shift dtime to be in LSB

    multu $t0, $a1               # multiply dtime by ms/tick
    mflo $v0                     # return dtime in ms

    # restore $s* and $ra
    lw $s0, 0($sp)
    sw $s1, 4($sp)
    lw $s7, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# $a0 = bpm (beats per minute)
# $a1 = ppq (pulses per quarter note)
calc_ms_tick:
    # calculate ms/tick
    multu $a1, $a2               # multiply bpm by ppq
    mflo $s0                     # store remainder in $s0
    li $t1, 60000
    divu $t1, $s0 
    mflo $v0                     # store ms/tick in $s0
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
