PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

E = %10000000
RW = %01000000
RS = %00100000
RDY = %10000000

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

    ldx #0
print:
    lda message,x
    beq loop
    jsr print_char
    inx
    jmp print

message:
     .asciiz "Witness Me!"

loop:
    jmp loop

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
