; Zero page variables

LOC = $00           ; Page of memory under test; 2 bytes
VAL = $02           ; "Raw" test value; 1 byte
ERRORS = $07        ; Total Errors; 2 bytes
START_PAGE = $03    ; Page at which to start testing; 1 byte
STOP_PAGE = $04     ; Page at which to stop testing; 1 byte

; Constants

SYS_RAM = $0200     ; Starting location of testable system RAM block


    .incdir libs    ; search libs dir for include files
    .include libhw.s

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
    lda #0               ; Set LCD address counter to start of first line
    jsr lcd_set_addr
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
    lda #40         ; Set LCD address counter to start of second line
    jsr lcd_set_addr
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

    .org NODEBUG    ; This area of memory does not trigger the debugger board
    .include liblcd.s
    .include libdebug.s
    .include libreg.s

    .org VECTORS
    .word nmi
    .word reset
    .word irq
