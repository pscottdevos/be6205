
; Constants

; LCD Controller-related contants
E = %10000000   ; LCD controller Enable bit
RW = %01000000  ; LCD controller RW bit
RS = %00100000  ; LCD controller Register Select bit
RDY = %10000000 ; LCD controller Ready bit
ADDR = %01111111; LCD controller cursor address counter bits
DSP = %00001110 ; LCD display control; display on; Cursor on; no blink cursor
CSR = %00000110 ; LCD cursor contol; Increment cursor position; no scroll

; Zero page variables
LOC = $00           ; Page of memory under test; 2 bytes
VAL = $02           ; "Raw" test value; 1 byte
START_PAGE = $03    ; Page at which to start testing; 1 byte
STOP_PAGE = $04     ; Page at which to stop testing; 1 byte
; Block is 8k range within 32k video memory chip
BLK_SEL = $05       ; Selected video ram block; 1 byte
; Bank is which chip (FG or BG RAM)
BNK_SEL = $06       ; Selected video ram bank; 1 bit
ERRORS = $07        ; Total Errors; 2 bytes
MESSAGE = $09       ; LCD Message address
LCD_VEC = $fe   ; Address of saved LCD data (for indirect, indexed addressing)

; Debugger variables
A = $1fff           ; A register
X = $1ffe           ; X register
Y = $1ffd           ; Y register
PC = $1ffb          ; Program Counter; 2 bytes
S = $1ffa           ; Status register
SP = $1ff9          ; Stack Pointer
SV = $1ff8          ; Value at Stack Pointer
LCD_DATA = SV - 81  ; Reserve 81 (decimal) bytes for LCD data

; Hardware
; RAM
SYS_RAM = $0200     ; Starting location of testable system RAM block
VID_RAM = $2000     ; Starting location of video RAM block
RSV_ADDR = $4000    ; Starting location of reserved addresses

; Hardware registers
; 6522 IO Registers
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

; Video Registers
VID_RAM_REG = $5070

; ROM
ROM = $8000         ; Start of ROM
NODEBUG = $c000     ; Start of non-debuggable ROM area

; 6502 Start of Vectors
VECTORS = $fffa

    .org ROM

irq:
    rti

reset:
    cld             ; Binary mode
    ldx #$ff        ; Set top of stack
    txs
    sei
    jsr lcd_init    ; Initialize LCD
    jsr lcd_clear   ; Clear LCD screen
    lda #$00        ; Set total errors
    sta ERRORS
    sta ERRORS + 1

.system_ram
    lda #%11000000  ; Deselect video RAM
    sta VID_RAM_REG
    lda #>SYS_RAM   ; Set start page for system RAM
    sta START_PAGE
    lda #>VID_RAM-1 ; Stop one shy of vid ram to not overwrite debug vars
    sta STOP_PAGE
    lda #$0         ; Set inital test value to zero
    sta VAL

    jsr test_block  ; Test system memory

.video_ram
    lda #$0         ; Select BG RAM
    sta BNK_SEL
    lda #$0         ; Select lowest block
    sta BLK_SEL
.block_loop
    jsr set_video_reg   ; Set the video register bank and block
    lda #>VID_RAM       ; Set start page for Video RAM
    sta START_PAGE
    lda #>RSV_ADDR      ; Set stop page for Video RAM
    sta STOP_PAGE
    lda #$0             ; Set inital test value to zero
    sta VAL

    jsr test_block      ; Test video RAM block

    inc BLK_SEL         ; Move to next block
    lda BLK_SEL         ; Load BLK_SEL into A to test it.
    cmp #$04            ; Have we tested all four blocks?
    bne .block_loop     ; If not, loop back
    lda #$0
    sta BLK_SEL
    inc BNK_SEL         ; Move to FG bank
    lda BNK_SEL
    cmp #$02            ; Done after BG and FG tested
    bne .block_loop     ; Loop back

    .byte $cb           ; Wait for button press
    jmp reset           ; Start over
    

; Set video register bank and block
;   Vars:   BNK_SEL     Boolean 0 = BG RAM, 1 = FG RAM
;           BLK_SEL     Video RAM block 0 - 3
set_video_reg:
    pha
    lda BNK_SEL         ; Load bank selection
    and #%00000001      ; Only interested in low order bit
    beq .bg
    lda #%01000000      ; Set for FG RAM
    jmp .set_blk
.bg
    lda #%10000000      ; Set for BG RAM
.set_blk
    clc
    adc BLK_SEL         ; Set RAM block
    sta VID_RAM_REG
    pla
    rts

; Test a block of RAM
;   Vars:   LOC         Current location of testing
;           VAL         Current value to compute value to store
;           START_PAGE  Memory page at which to start test
;           STOP_PAGE   Memory page *up to* which to test
;           ERRORS      Total errors
test_block:
    ldx #START_PAGE ; Set X to high-order byte of test start location
    ldy #$0         ; Set X to low-order byte of test start location
    ; Write test data to block of RAM
.write_page:
    lda #$0         ; Store current page to LOC
    sta LOC         ;   low-order
    stx LOC + 1     ;   high-order
    tya             ; Test-value at address is address low-order byte...
    clc             ;   ...plus test value; this gives diff val at each address
    adc VAL         ;   in page, but still tests all values at each address
    sta (LOC),Y     ; Store to current test location
    iny
    bne .write_page ; Loop back for each address in page
    inx             ; Increment x to next page
    txa             ; Transfer page number to accumulator
    cmp STOP_PAGE   ; Compare with stop page (we test *up to* stop page)
    bne .write_page ; If not yet at stop page, loop back

    ; Read back data and check if it is correct
    ldx #START_PAGE ; Set X to high-order byte of test start location
    ldy #$0         ; Set X to low-order byte of test start location
.read_page:
    lda #$0         ; Store current page to LOC
    sta LOC         ;   low-order
    stx LOC + 1     ;   high-order
    tya             ; Test-value at address should be address low-order byte...
    clc             ;   ...plus test value; this gives diff val at each address
    adc VAL         ;   in page, but still tests all values at each address
    pha             ; Store value for error reporting
    cmp (LOC),y     ; Compare with value at test location
    beq .passed     ; If test passes jump over error reporting
    clc
    inc ERRORS      ; Add 1 to errors detected
    bne .rep_errs   ; If ERRORS rolls over...
    inc ERRORS + 1  ;   ...increment high order byte of error counter
.rep_errs           ; Report Errors
    pla             ; Get computed expected memory value off stack
    pha             ; Put it back because we pull it again below
    jsr print_errors; Print error information
.passed:
    pla             ; Get stored value back off stack and throw it away
    iny             ; Get next address
    bne .read_page  ; Loop back until we roll over to zero
    jsr print_status; Print current value and address
    inx             ; Increment x to next page
    txa             ; Transfer page number to A
    cmp STOP_PAGE   ; Compare with stop page (we test *up to* stop page)
    bne .read_page  ; Loop back until STOP_PAGE is reached
    inc VAL         ; Increment value by one
    bne test_block  ; Loop back to test entire block with next test value
    nop
    rts

; Print current test value and address to LCD
;   Vars:   VAL - "raw" test value
;           BLK_SEL - memory chip selection
;           BNK_sEL - 8k bank selection
print_status:
    lda #%10000000  ; Set LCD address counter to start of first line
    jsr lcd_instruction
    lda ERRORS
    jsr print_hex
    lda #" "
    jsr print_char
    lda VAL         ; Print "raw" test value
    jsr print_hex
    lda #" "
    jsr print_char
    txa
    jsr print_hex
    tya
    jsr print_hex
    lda #" "
    jsr print_char
    lda BNK_SEL
    jsr print_hex
    lda #":"
    jsr print_char
    lda BLK_SEL
    jsr print_hex
    rts

; Print errors to LCD
;   Input:  A register - Computed test value
;   Vars:   VAL - "raw" test value
;           ERRORS - 2 byte number of errors encountered
print_errors:
    pha             ; Save A reg on stack for later
    lda #%10101000  ; Set LCD address counter to start of second line
    jsr lcd_instruction
    lda #"V"
    jsr print_char
    lda VAL         ; Report value, address and total errors
    jsr print_hex
    lda #" "
    jsr print_char
    lda #"C"
    jsr print_char
    pla             ; Get computed test value read off stack
    jsr print_hex   ; Print stored value.
    lda #"R"
    jsr print_char
    lda (LOC),y     ; Value at test location
    jsr print_hex
    lda #" "
    jsr print_char
    lda #"M"
    jsr print_char
    txa             ; Print test memory location
    jsr print_hex 
    tya
    jsr print_hex
    rts


    .org NODEBUG
; Subroutine Library

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

    ; Restore stack
    pha             ; Restore the value at the stack pointer
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
    lda #%10000000  ; Set LCD address counter to 0
    jsr lcd_instruction
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
    ldx #40 - 16    ; Print spaces to get to next line
    lda #" "
.next_char
    jsr print_char
    dex
    bne .next_char

    lda #"P"        ; Program counter; 6 chars including space
    jsr print_char
    lda #"C"
    jsr print_char
    lda #":"
    jsr print_char
    lda PC + 1
    jsr print_hex
    lda PC
    jsr print_hex
    lda #" "
    jsr print_char

    lda #"S"        ; Stack pointer and value; 5 chars including space
    jsr print_char
    lda #"P"
    jsr print_char
    lda #":"
    jsr print_char
    lda SP
    jsr print_hex
    lda #"/"
    jsr print_char
    lda SV
    jsr print_hex

    .byte $cb       ; Wait for interrupt; wdc65c02 instruction
    lda #%10000000  ; Set LCD address counter to 0
    jsr lcd_instruction
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

; Get LCD address counter
;   Output:
;       A register - LCD address counter value
lcd_addr:
    lda #%00000000  ; Set all pins on Port B to input
    sta DDRB
.lcd_busy:
    lda #RW         ; Set RW to Read; Clear RS/E bits
    sta PORTA       ; "
    lda #(RW | E)   ; Set Enable bit
    sta PORTA
    lda PORTB       ; Read from Port B
    pha             ; Save port B result on stack
    and #RDY        ; Mask Instruction Ready bit
    bne .lcd_busy   ; Look again if not ready
    lda #RW         ; Reset Enable bit
    sta PORTA       ; "
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB        ; "
    pla             ; Recover saved port B value
    and #ADDR       ; Mask address bits
    rts

; Clear LCD Display
lcd_clear:
    pha
    lda #%00000001      ; Clear Display
    jsr lcd_instruction
    pla
    rts

; Init LCD display
lcd_init:
    pha
    lda #%11111111      ; Set all pins on port B to output
    sta DDRB
    lda #%11100000      ; Set top 3 pins on port A to output
    sta DDRA
    lda #%00111000      ; 8-bit mode; 2-line display; 5x8 format
    jsr lcd_instruction
    lda #DSP            ; Set display control
    jsr lcd_instruction
    lda #CSR            ; Set cursor control
    jsr lcd_instruction
    pla
    rts

; Send instruction to LCD controller
lcd_instruction:
    jsr lcd_wait
    sta PORTB
    lda #0          ; Clear RS/RW/E bits
    sta PORTA
    lda #E          ; Toggle enable bit to send instruction
    sta PORTA       ; "
    lda #0          ; "
    sta PORTA       ; "
    rts

; Read byte at LCD address couter
lcd_read
;   Output: A register - byte from address couter
;   Side Effect: LCD address counter increments/decrements (based on mode set)
    jsr lcd_wait
    lda #%00000000      ; Set all pins on Port B to input
    sta DDRB
    lda #(RW | RS)      ; Set RW to Read; RS to data; Clear E bit
    sta PORTA
    lda #(RW | RS | E)  ; Set Enable bit
    sta PORTA
    lda PORTB           ; Read from Port B
    pha                 ; Save data to stack
    lda #(RW | RS)      ; Set RW to Read; RS to data; Clear E bit
    sta PORTA           ; "
    lda #%11111111      ; Set all pins on port B to output
    sta DDRB            ; "
    pla                 ; Recover data saved to stack
    rts

; Wait for LCD to respond
lcd_wait:
    pha
    lda #%00000000  ; Set all pins on Port B to input
    sta DDRB
.lcd_busy:
    lda #RW         ; Set RW to Read; Clear RS/E bits
    sta PORTA       ; "
    lda #(RW | E)   ; Set Enable bit
    sta PORTA
    lda PORTB       ; Read from Port B
    and #RDY        ; Mask Instruction Ready bit
    bne .lcd_busy   ; Look again if not ready
    lda #RW         ; Reset Enable bit
    sta PORTA       ; "
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB        ; "
    pla
    rts

; Print character to LCD screen
;   Input: A register - ascii char to print
print_char:
    pha
    jsr lcd_wait
    sta PORTB       ; Store A register to Port B
    lda #RS         ; Set RS bit; Clear RW/E bits
    sta PORTA
    lda #(RS | E)   ; Toggle enable bit to send instruction
    sta PORTA       ; "
    lda #RS         ; "
    sta PORTA       ; "
    pla
    rts

; Print Hex Value to LCD screen
;   Input: A register - Hex Value to print
print_hex:
    pha
    ror             ; rotate high order nibble into low order nibble
    ror
    ror
    ror
    jsr hex2char
    jsr print_char
    pla             ; Get original number off stack
    pha             ; And put it back
    jsr hex2char
    jsr print_char
    pla
    rts

; Print string to LCD screen
;   Input: x, y: low order, high order of message location
print_str:
    pha
    stx MESSAGE     ; Store low order byte of message location
    sty MESSAGE + 1 ; Store high order byte of message location
    ldy #0          ; y register holds offset from start of string
.print:
    lda (MESSAGE),y ; Load offset y from location pointed to by MESSAGE
    beq .done       ; Branch to done if we loaded null (0)
    jsr print_char  ; print the character loaded
    iny             ; prep for the next character
    jmp .print      ; loop back for next character
.done:
    pla
    rts

; Convert low order nibble of accumulator to ascii character (0-9 A-F)
;   Input A register - value to convert in low order bits. Destroys value in A
hex2char:
    and #%00001111  ; Get low order nibble
    cmp #$a
    bmi .range_0to9 ; If > $a, Skip past range $a-$f computation
    clc
    adc #"A" - $a   ; Add ascii of "A" minus $a to A (so $a will land on "A")
    jmp .done       ; Skip past range $0-$9 computation
.range_0to9
    clc             ; Add ascii of "0" to A
    adc #"0"
.done:
    rts

    .org VECTORS
    .word nmi
    .word reset
    .word irq
