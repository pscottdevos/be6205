; Zero page variables
PC = $fc        ; Program Counter; 2 bytes
LCD_VEC = $fe   ; Address of saved LCD data (for indirect, indexed addressing)

; Debugger variables
A = $1fff           ; A register
X = $1ffe           ; X register
Y = $1ffd           ; Y register
S = $1ffa           ; Status register
SP = $1ff9          ; Stack Pointer
SV1 = $1ff8         ; Value at Stack Pointer plus one
SV = $1ff7          ; Value at Stack Pointer
LCD_DATA = SV - 81  ; Reserve 81 (decimal) bytes for LCD data

nmi:
    ; Save the values of all registers/stack into RAM
    sty Y           ; Save the registers
    stx X
    sta A
    pla             ; Save the status register from the stack
    sta S
    pla             ; Save the program counter
    sta PC          ;   low-order address
    pla             ;   high-order address
    sta PC + 1
    tsx             ; Save the stack pointer (position prior to NMI)
    stx SP
    pla             ; Save the value at the stack pointer
    sta SV
    pla             ; Save the value at stack pointer plus one
    sta SV1


    ; Restore stack
    pha             ; Restore the value at the stack pointer plus one
    lda SV          ; Restore the value at the stack pointer
    pha
    lda PC + 1      ; Restore the program counter; low order address
    pha
    lda PC          ; Restore the program counter; high order address
    pha
    lda S           ; Restore the status register
    pha

    ; Stop here to allow user to see what's on the LCD screen before we replace
    ; it with the dubugging data
    .byte $cb       ; Wait for interrupt; wdc65c02 instruction

    ; Save the current state of the LCD
    lda #<LCD_DATA  ; Copy low-order address of LCD saved data to vector
    sta LCD_VEC
    lda #>LCD_DATA  ; Copy high-order address of LCD saved data to vector
    sta LCD_VEC + 1
    jsr lcd_addr    ; Get LCD address counter into A
    ldy #80
    sta (LCD_VEC),y ; Save LCD address counter value
    lda #0          ; Set LCD address counter to 0
    jsr lcd_set_addr
    ldy #79         ; Index to LCD saved data
.get_lcd_byte
    jsr lcd_read    ; Read next byte (and increment address counter)
    sta (LCD_VEC),y ; Save data
    dey             ; Decrement index and loop back until index goes negative
    bpl .get_lcd_byte

    ; Publish results to the LCD
    jsr lcd_init
    lda #%00001100 ; LCD display control; display off; Cursor on; no blink cursor
    jsr lcd_instruction
    lda #%00000110 ; LCD cursor contol; Increment cursor position; no scroll
    jsr lcd_instruction
    jsr lcd_clear

    lda A
    jsr print_hex
    lda #":"
    jsr print_char

    lda X
    jsr print_hex
    lda #":"
    jsr print_char

    lda Y
    jsr print_hex
    lda #" "
    jsr print_char

; Print flag or "-" for each of NVBDIZC
.n_flag
    lda S           ; Load the status register
    and #%10000000  ; Mask the flag of interest
    beq .dash_n     ; Branch to print "-" if flag not set
    lda #"N"        ; Print the flag
    jsr print_char
    jmp .v_flag     ; Jump over print "-"
.dash_n
    lda #"-"        ; Print "-"
    jsr print_char

.v_flag
    lda S
    and #%01000000
    beq .dash_v
    lda #"V"
    jsr print_char
    jmp .b_flag
.dash_v
    lda #"-"
    jsr print_char

.b_flag
    lda S
    and #%00010000
    beq .dash_b
    lda #"B"
    jsr print_char
    jmp .d_flag
.dash_b
    lda #"-"
    jsr print_char

.d_flag
    lda S
    and #%00001000
    beq .dash_d
    lda #"D"
    jsr print_char
    jmp .i_flag
.dash_d
    lda #"-"
    jsr print_char

.i_flag
    lda S
    and #%00000100
    beq .dash_i
    lda #"I"
    jsr print_char
    jmp .z_flag
.dash_i
    lda #"-"
    jsr print_char

.z_flag
    lda S
    and #%00000010
    beq .dash_z
    lda #"Z"
    jsr print_char
    jmp .c_flag
.dash_z
    lda #"-"
    jsr print_char

.c_flag
    lda S
    and #%00000001
    beq .dash_c
    lda #"C"
    jsr print_char
    jmp .done_flags
.dash_c
    lda #"-"
    jsr print_char

.done_flags
    lda #40
    jsr lcd_set_addr

    lda PC + 1      ; Program counter; 5 chars including colon
    jsr print_hex
    lda PC
    jsr print_hex
    lda #":"
    jsr print_char
    ldx #0          ; Value at program counter; 3 chars including space
    lda (PC,X)
    jsr print_hex
    lda #" "
    jsr print_char

    lda SP          ; Stack pointer; 3 chars including slash
    jsr print_hex
    lda #"/"
    jsr print_char
    lda SV1
    jsr print_hex
    lda SV
    jsr print_hex

    .byte $cb       ; Wait for interrupt; wdc65c02 instruction
    lda #0          ; Set LCD address counter to 0
    jsr lcd_set_addr
    ldy #79         ; Index to LCD saved data
.print_lcd_byte
    lda (LCD_VEC),y ; Recover LCD data
    jsr print_char  ; Print to LC
    dey             ; Decrement index and loop back until index goes negative
    bpl .print_lcd_byte
    ldy #80
    lda (LCD_VEC),y ; Load value of LCD address counter
    ora #%10000000  ; Set Address command bit and set LCD address counter
    jsr lcd_instruction
    jsr lcd_init    ; Initialize LCD back to primary mode

    ; Restore Registers to original values
    lda A
    ldx X
    ldy Y

    rti