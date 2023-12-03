; Zero page definitions
REG_VAL = $00   ; Register value
TIMER = $01     ; outer timer index; 1 byte
CYCLE = $02     ; cycle index, counts times each test has run
MESSAGE = $03   ; Location of Message; 2 bytes
PP_DIR = $05    ; Current ping-pong test direction; 0 = left; 1 = right; 1 byte

; Hardware addresses
REG = $5000     ; Register being tested memory location

; Constants
Cycles = 5      ; (decimal) Number of times to run each test in each loop


    .org $8000

nmi:
irq:
reset:
    ; Set up for alternate bits test
    lda #Cycles         ; Init cycle counter
    sta CYCLE

alternate_bits_test
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


    ; Set up for rotate bits test
    lda #Cycles     ; Init cycle counter
    sta CYCLE
    lda #%00000000  ; Prepare register value no bits set
    sta REG_VAL
    sec             ; set the carry bit


rotate_bits_test
    lda REG_VAL     ; Store register value to register
    sta REG
    lda #$02        ; Init wait timer
    jsr wait        ; wait
    rol REG_VAL     ; Rotate left (with carry)
    ; Loop until register value is zero again
    bne rotate_bits_test

    dec CYCLE       ; Loop unless done with test
    bne rotate_bits_test


    ; Set up for ping-pong bits test
    lda #Cycles     ; Init cycle counter
    sta CYCLE

ping_pong_test
    lda #$00        ; Start with ping-pong dir to left
    sta PP_DIR
    lda #%00000001  ; Set bit 0 of Register value
    sta REG_VAL
.loop
    lda REG_VAL     ; Store Register value to Register
    sta REG
    lda #$01        ; Init wait timer
    jsr wait        ; Wait
    lda PP_DIR      ; If ping-pong dir is zero...
    beq .do_rol     ;   branch to rotate left
.do_ror
    clc
    ror REG_VAL     ; Otherwise rotate right and...
    jmp .past_rol   ;   jump past rol
.do_rol
    clc
    rol REG_VAL     ; Rotate Register value left
.past_rol
    lda REG_VAL        
    cmp #%10000000  ; If Register value != 10000000...
    bne .bit_right  ;   branch to test right bit 
    lda #$01
    sta PP_DIR      ; Change ping-pong direction to right
    jmp .loop       ; jump back to rotate bits again
.bit_right
    cmp #%00000001  ; If Register value != 00000001...
    bne .loop       ;   branch back to rotate bits again
    lda #$00        ; Otherwise
    sta PP_DIR      ;   Change ping-pong direction to left
    dec CYCLE       ; If no cycles remain
    bne .loop       ;   branch back to rotate bits again


    jmp reset       ; Loop back to first test forever


; Subroutine Library

; Wait time specified in A register
wait:
    sta TIMER
.loop2
    ldy #$00
.loop1
    ldx #$00
.loop0
    dex
    bne .loop0
    dey
    bne .loop1
    dec TIMER
    bne .loop2
    rts



    .ifdef vectors
    .org VECTORS
    .word nmi
    .word reset
    .word irq
    .endif
