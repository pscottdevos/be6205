; Zero page definitions
REG_VAL = $00   ; Register value
WT_TIME = $01   ; outer timer index; 1 byte
CYCLE = $02     ; cycle index, counts times each test has run
MESSAGE = $03   ; Location of Message; 2 bytes
PP_DIR = $05    ; Current ping-pong test direction; 0 = left; 1 = right; 1 byte

; Hardware addresses

; Test register
REG = $5000    ; Register 0 memory location
REG1 = $5001    ; Register 1 memory location
REG2 = $5002    ; Register 2 memory location

; 6522 IO Registers
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

; 6502 vectors
VECTORS = $fffa

; Start of ROM
ROM = $8000

; Constants
Cycles = 5      ; (decimal) Number of times to run each test in each loop

; LCD Controller-related contants
E = %10000000   ; LCD controller Enable bit
RW = %01000000  ; LCD controller RW bit
RS = %00100000  ; LCD controller Register Select bit
RDY = %10000000 ; LCD controller Ready bit


    .org ROM

nmi:
irq:
reset:
    ldx #$ff        ; Start stack pointer at top of stack
    txs

    lda #$10        ; Init wait timer - waiting for LCD display to be ready
    jsr wait        ; wait
    jsr lcd_init    ; Then initialize LCD

;##################################
; Main program loop
;##################################
tests:
    ; print alt bits message
    jsr lcd_clear
    ldx #<alt_bits_msg
    ldy #>alt_bits_msg
    lda #$55
    jsr print_str

    ; Set up for alternate bits test
    lda #Cycles     ; Init cycle counter
    sta CYCLE

alternate_bits_test:
    lda #$55        ; set even numbered bits
    sta REG
    lda #$07        ; Init wait timer
    jsr wait        ; wait
    lda #$aa        ; set odd numbered bits
    sta REG
    lda #$07        ; Init wait timer
    jsr wait        ; wait
    dec CYCLE       ; Loop unless done with test
    bne alternate_bits_test

    ; print rot bits message
    jsr lcd_clear
    ldx #<rot_bits_msg
    ldy #>rot_bits_msg
    jsr print_str

    ; Set up for rotate bits test
    lda #Cycles     ; Init cycle counter
    sta CYCLE
    lda #%00000000  ; Prepare register value no bits set
    sta REG_VAL
    sec             ; set the carry bit

rotate_bits_test:
    lda REG_VAL     ; Store register value to register
    sta REG
    lda #$02        ; Init wait timer
    jsr wait        ; wait
    rol REG_VAL     ; Rotate left (with carry)
    ; Loop until register value is zero again
    bne rotate_bits_test

    dec CYCLE       ; Loop unless done with test
    bne rotate_bits_test


    ; print ping pong bits message
    jsr lcd_clear
    ldx #<ping_pong_msg
    ldy #>ping_pong_msg
    jsr print_str

    ; Set up for ping-pong bits test
    lda #Cycles     ; Init cycle counter
    sta CYCLE

ping_pong_test:
    lda #$00        ; Start with ping-pong dir to left
    sta PP_DIR
    lda #%00000001  ; Set bit 0 of Register value
    sta REG_VAL
.loop:
    lda REG_VAL     ; Store Register value to Register
    sta REG
    lda #$01        ; Init wait timer
    jsr wait        ; Wait
    lda PP_DIR      ; If ping-pong dir is zero...
    beq .do_rol     ;   branch to rotate left
.do_ror:
    clc
    ror REG_VAL     ; Otherwise rotate right and...
    jmp .past_rol   ;   jump past rol
.do_rol:
    clc
    rol REG_VAL     ; Rotate Register value left
.past_rol:
    lda REG_VAL        
    cmp #%10000000  ; If Register value != 10000000...
    bne .bit_right  ;   branch to test right bit 
    lda #$01
    sta PP_DIR      ; Change ping-pong direction to right
    jmp .loop       ; jump back to rotate bits again
.bit_right:
    cmp #%00000001  ; If Register value != 00000001...
    bne .loop       ;   branch back to rotate bits again
    lda #$00        ; Otherwise
    sta PP_DIR      ;   Change ping-pong direction to left
    dec CYCLE       ; If no cycles remain
    bne .loop       ;   branch back to rotate bits again

    jmp tests       ; Loop back to first test forever
;##################################
; End Main program loop
;##################################


; Subroutine Library

; Clear LCD Display
lcd_clear:
    pha
    lda #%00000001  ; Clear Display
    jsr lcd_instruction
    pla
    rts

; Init LCD display
lcd_init:
    pha
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB
    lda #%11100000  ; Set top 3 pins on port A to output
    sta DDRA
    lda #%00111000  ; 8-bit mode; 2-line display; 5x8 format
    jsr lcd_instruction
    lda #%00001100  ; Set display on; Cursor off; no blink cursor
    jsr lcd_instruction
    lda #%00000110  ; Increment cursor position; no scroll
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

; Wait for LCD to respond
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

; Print character to LCD screen
;   Input: A register - ascii char to print
print_char:
    jsr lcd_wait
    sta PORTB       ; Store A register to Port B
    lda #RS         ; Set RS bit; Clear RW/E bits
    sta PORTA
    lda #(RS | E)   ; Toggle enable bit to send instruction
    sta PORTA       ; "
    lda #RS         ; "
    sta PORTA       ; "
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
    pla
    sta REG2
    tax
    pla
    tay
    dey
    tya
    sta REG1
    pha
    txa
    pha
    rts

; Wait time specified in A register
;   Input: A register - timer value to wait
wait:
    sta WT_TIME ; Store at WT_TIME address
.loop2
    ldy #$00    ; loop y 256 times
.loop1
    ldx #$00    ; loop x 256 times
.loop0
    dex         ; dec x and...
    bne .loop0  ;   inner loop until zero
    dey         ; dec y and...
    bne .loop1  ;   middle loop until zero
    dec WT_TIME ; dec value at WT_TIME and...
    bne .loop2  ;   outer loop until zero
    rts

; ROM Data

alt_bits_msg:
    .asciiz "Alternate bits                          test"

rot_bits_msg:
    .asciiz "Rotate bits test"

ping_pong_msg:
    .asciiz "Ping pong test"


    .ifdef vectors
    .org VECTORS
    .word nmi
    .word reset
    .word irq
    .endif
