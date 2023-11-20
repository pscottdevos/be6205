PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

E = %10000000
RW = %01000000
RS = %00100000
RDY = %10000000

value = $0200       ; loc value to convert to decimal
mod10 = $0202       ; loc modulus
message = $0204     ; six bytes for message

    .org $8000

init:
    ldx #$ff        ; Start stack pointer at top of stack
    txs

    lda #%11111111  ; Set all pins on port B to output
    sta DDRB

    lda #%11100000  ; Set top 3 pins on port A to output
    sta DDRA

    lda #%00111000  ; 8-bit mode; 2-line display; 5x8 format
    jsr lcd_instruction

    lda #%00001110  ; Set display on; Cursor on; no blink cursor
    jsr lcd_instruction

    lda #%00000110  ; Increment cursor position; no scroll
    jsr lcd_instruction

    lda #%00000001  ; Clear Display
    jsr lcd_instruction

    ; initialize message to zero length string
    lda #0
    sta message

    ; Initalize value to be the number to convert
    lda number
    sta value
    lda number + 1
    sta value + 1

divide:
    ; Initialize remainder to 0
    lda #0
    sta mod10
    sta mod10 + 1

    ldx #16
    clc
.divloop:
    ; Rotate quotient and remainder 1 bit left
    rol value
    rol value + 1
    rol mod10
    rol mod10 + 1

    ; a,y = dividend - divisor
    sec
    lda mod10
    sbc #10
    tay                 ; Save low byte of subtraction
    lda mod10 + 1
    sbc #0
    bcc .ignore_result  ; Branch if dividend < divisor
    sty mod10
    sta mod10 + 1

.ignore_result
    dex
    bne .divloop
    rol value           ; shift in the last bit of the quotient
    rol value + 1

    lda mod10
    clc
    adc #"0"
    jsr push_char

    ; if value != 0 keep dividing
    lda value
    ora value + 1       ; checks if any bits in either loc are 1
    bne divide          ; if quotient is not zero, keep going


.print:
    lda message,x
    beq loop
    jsr print_char
    inx
    jmp .print

    

loop:
    jmp loop
    
number:
    .word 1729

; Add char in a registor to beginning of string at message
push_char:
    pha             ; push new first character on the stack
    ldy #0          ; string index

.char_loop
    lda message, y  ; move yth char on message to x reg
    tax
    pla             ; get the new yth char from stack
    sta message, y  ; store new yth char in y pos of message
    iny             ; ready for next character
    txa             ; push prior yth char onto stack
    pha
    bne .char_loop  ; loop if not null at end of string

    pla             ; Pull final (null) char from stack
    sta message,y   ; put at the end of the message
    rts

lcd_wait:
    pha
    lda #%00000000  ; Set all pins read on Port B
    sta DDRB
.lcd_busy:
    lda #RW         ; Set RW to Read; Clear RS/E bits
    sta PORTA       ; "
    lda #(RW | E)   ; Set Enable bit
    sta PORTA
    lda PORTB       ; Read from Port B
    and #RDY        ; Mask Instruction Ready bit
    bne .lcd_busy    ; Look again if not ready

    lda #RW         ; Reset Enable bit
    sta PORTA       ; "
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB        ; "
    pla
    rts

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

print_char:
    jsr lcd_wait
    sta PORTB
    sta PORTB       ; Store A register to Port B
    lda #RS         ; Set RS bit; Clear RW/E bits
    sta PORTA
    lda #(RS | E)   ; Toggle enable bit to send instruction
    sta PORTA       ; "
    lda #RS         ; "
    sta PORTA       ; "
    rts

    .ifdef vectors
    .org $fffc
    .word init
    .word $0000
    .endif