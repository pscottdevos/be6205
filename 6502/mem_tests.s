LOC = $00       ; 2 byte location to write to and read from
VAL = $02       ; 1 byte value to test


; Test register
REG0 = $5000    ; Register 0 memory location
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

FILL_START = $0003
FILL_STOP_PAGE = $20

    .org ROM

nmi:
irq:
reset:
    cld                 ; Binary mode
    lda #0              ; Set registers to zero
    sta REG0
    sta REG1
    sta REG2

    lda #$00            ; Set test value
    sta VAL

start_test:
    ldx #>FILL_START    ; Set X to high-order byte of start location
    ldy #<FILL_START    ; Set Y to low-order byte of start location

.loop1:
    lda #0              ; Store current page to LOC
    sta LOC             ;   low-order byte
    stx LOC + 1         ;   high order byte
    lda VAL             ; Load test value
    sta (LOC),y         ; Save test value to test location
    lda #0              ; Clear the data lines
    lda (LOC),y         ; Load test value from test location
    stx REG0            ; Store test value loaded to register
    sty REG1            ; Store high-order byte of test location to register
    sta REG2            ; Store low-order byte of test location to register
    cmp VAL             ; Check if value matches test value
    bne stop            ; If not equal stop
    iny                 ; Increment Y to next test memorty location
    bne .loop1          ; Loop back unless at the end of the page
    inx                 ; Increment X to next page
    txa                 ; Transfer page number to accumulator
    cmp #FILL_STOP_PAGE ; Compare with stop page (we test *up to* stop page)
    bne .loop1          ; If not yet at stop page, loop back

    ; This is to test that writing to the ports does not affect what is in RAM
    ;lda VAL             ; Load the test value
    ;eor #%11111111      ; Invert all the bits of the test value
    ;sta PORTB           ; Store inverted-bit value to port B
    ;sta PORTA           ; Store inverted-bit value to port A
    ;sta DDRB            ; Store inverted-bit value to data direction register B
    ;sta DDRA            ; Store inverted-bit value to data direction register A

    ldx #>FILL_START    ; Set X to high-order byte of start location again
    ldy #<FILL_START    ; Set Y to low-order byte of start location again

.loop2:
    lda #0              ; Store current page to LOC
    sta LOC             ;   low-order byte
    stx LOC + 1         ;   high-order byte
    lda (LOC),y         ; Load test value from test location
    stx REG0            ; Store test value loaded to register
    sty REG1            ; Store high-order byte of test location to register
    sta REG2            ; Store low-order byte of test location to register
    cmp VAL             ; Check if value matches test value
    bne stop            ; If not equal stop
    iny                 ; Increment Y to next test memorty location
    bne .loop2          ; Loop back unless at the end of the page
    inx                 ; Increment X to next page
    txa                 ; Transfer page number to accumulator
    cmp #FILL_STOP_PAGE ; Compare with stop page (we test *up to* stop page)
    bne .loop2          ; If not yet at stop page, loop back

.change_val:
    inc VAL

    jmp start_test      ; Run tests forever (unless a test fails)


stop:
    stx REG0            ; Store test value loaded to register
    sty REG1            ; Store high-order byte of test location to register
    sta REG2            ; Store low-order byte of test location to register

stay
    jmp stay


    .ifdef vectors
    .org VECTORS
    .word nmi
    .word reset
    .word irq
    .endif