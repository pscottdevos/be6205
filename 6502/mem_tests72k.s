; Zero page variables

LOC = $00           ; Page of memory under test; 2 bytes
VAL = $02           ; "Raw" test value; 1 byte
START_PAGE = $03    ; Page at which to start testing; 1 byte
STOP_PAGE  = $04    ; Page at which to stop testing; 1 byte
JIFFIES = $05       ; Real-time clock 1/60th of seconds
SECONDS = $06       ; Real-time clock seconds
MINUTES = $07       ; Real-time clock minutes
HOURS   = $08       ; Real-time clock hours
ERRORS = $09       ; Total Errors; 2 bytes

; Constants

SYS_RAM = $0200     ; Starting location of testable system RAM block


    .incdir libs    ; search libs dir for include files
    .include libhw.s

    .org ROM

reset:
    cld             ; Binary mode
    ldx #$ff        ; Set top of stack
    txs
    jsr lcd_init    ; Initialize LCD
    jsr lcd_clear   ; Clear LCD screen
    lda #$00        ; Set total errors
    sta ERRORS
    sta ERRORS + 1
    sta JIFFIES     ; Set real run-time to zero
    sta SECONDS
    sta MINUTES
    sta HOURS
    cli             ; enable interrupts

.wait
    jsr wait        ; Wait for resume button press


.system_ram
    lda #$0             ; Select no video RAM; high speed clock
    sta BNK_SEL
    sta BLK_SEL
    jsr set_video_reg   ; Set the video register bank and block
    lda #>SYS_RAM       ; Set start page for system RAM
    sta START_PAGE
    lda #>VID_RAM-1     ; Stop one shy of vid ram to not overwrite debug vars
    sta STOP_PAGE
    lda #$0             ; Set inital test value to zero
    sta VAL

    jsr zero_block
    jsr test_block      ; Test system memory

.video_ram
    lda #$1             ; Select BG RAM
    sta BNK_SEL
    lda #$0             ; Select lowest block
    sta BLK_SEL
.block_loop
    jsr set_video_reg   ; Set the video register bank and block
    lda #>VID_RAM       ; Set start page for Video RAM
    sta START_PAGE
    lda #>RSV_ADDR      ; Set stop page for Video RAM
    sta STOP_PAGE
    lda #$0             ; Set inital test value to zero
    sta VAL

    jsr zero_block
    jsr test_block      ; Test video RAM block

    inc BLK_SEL         ; Move to next block
    lda BLK_SEL         ; Load BLK_SEL into A to test it.
    cmp #$04            ; Have we tested all four blocks?
    bne .block_loop     ; If not, loop back
    lda #$0
    sta BLK_SEL
    inc BNK_SEL         ; Move to FG bank
    lda BNK_SEL         ; Load BNK_SEL to test it
    cmp #$3             ; Have we moved past FG bank?
    bne .block_loop     ; If not, loop back
    jmp .system_ram     ; Start over


; Zero a block of RAM
;   Vars:   LOC         Current location of testing
;           START_PAGE  Memory page at which to start test
;           STOP_PAGE   Memory page *up to* which to test
zero_block:
    pha
    ldx #START_PAGE ; Set X to high-order byte fo test start location
    ldy #$0         ; Set Y to low-order byte of test start location
.zero_page
    lda #$0         ; Store current page to LOC
    sta LOC         ;   low-order
    stx LOC + 1     ;   high-order
    sta (LOC),y     ; Store zero to current location
    iny
    bne .zero_page  ; Loop back for each address in page
    inx             ; Increment to next page
    txa             ; Transfer page number to accumulator
    cmp STOP_PAGE   ; Compare with stop page (we test *up to* stop page)
    bne .zero_page  ; If not yet at stop page, loop back
    pla
    rts
    

; Test an 8k block of RAM
;   Vars:   LOC         Current location of testing
;           VAL         Current value to compute value to store
;           START_PAGE  Memory page at which to start test
;           STOP_PAGE   Memory page *up to* which to test
;           ERRORS      Total errors
;           BNK_SEL     Bank selection
test_block:
    ldx #START_PAGE ; Set X to high-order byte of test start location
    ldy #$0         ; Set Y to low-order byte of test start location
    ; Write test data to block of RAM
.write_page:
    lda #$0         ; Store current page to LOC
    sta LOC         ;   low-order
    stx LOC + 1     ;   high-order
    tya             ; Test-value at address is address low-order byte...
    clc             ;   ...plus test value; this gives diff val at each address
    adc VAL         ;   in page, but still tests all values at each address
    pha             ; Save A register
    lda BNK_SEL
    cmp #$2         ; Test for FG RAM
    bne .store_test_val ; Store value as-is for system and BG RAM
    pla             ; Get stored value
    and #FB_COL_PRV ; Mask out collision bit
    pha             ; Push A register so it gets pulled below
.store_test_val
    pla
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
    pha             ; Save A register for testing for errors
    lda BNK_SEL
    cmp #$2         ; Test for FG RAM
    bne .read_test_val ; Store value as-is for system and BG RAM
    pla             ; Get stored value
    and #FB_COL_PRV ; Mask out collision bit
    pha             ; Push A register so it gets pulled below
.read_test_val
    pla             ; Pull the test result value
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
    jsr zero_block  ; Zero out the block
    rts

; Print current test value and address to LCD
;   Input:  X - high order byte of address under test
;           Y - low order byte of address under test
;   Vars:   VAL - "raw" test value
;           BLK_SEL - memory chip selection
;           BNK_sEL - 8k bank selection
print_status:
    pha
    lda #0          ; Set LCD address counter to start of first line
    jsr lcd_set_addr
    lda ERRORS + 1
    jsr print_hex
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
    lda #" "
    jsr print_char
    lda BNK_SEL
    jsr print_hex
    lda #":"
    jsr print_char
    lda BLK_SEL
    jsr print_hex
    lda #40
    jsr lcd_set_addr
    lda HOURS
    jsr print_hex
    lda #":"
    jsr print_char
    lda MINUTES
    jsr print_hex
    lda #":"
    jsr print_char
    lda SECONDS
    jsr print_hex
    lda #":"
    jsr print_char
    lda JIFFIES
    jsr print_hex
    lda #" "
    jsr print_char
    jsr print_char
    jsr print_char
    jsr print_char
    jsr print_char
    pla
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

handle_fb_col:
    rts

handle_vbs:
    pha

    inc JIFFIES
    lda JIFFIES
    cmp #120
    bne .done
    lda #0
    sta JIFFIES

    inc SECONDS
    lda SECONDS
    cmp #60
    bne .done
    lda #0
    sta SECONDS

    inc MINUTES
    lda MINUTES
    cmp #60
    bne .done
    lda #0
    sta MINUTES

    inc HOURS
.done
    pla
    rts

    .org NODEBUG    ; This area of memory does not trigger the debugger board
    .include liblcd.s
    .include libdebug.s
    .include libreg.s

    .org VECTORS
    .word nmi
    .word reset
    .word irq
