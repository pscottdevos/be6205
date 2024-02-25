; Zero page vars

WAIT = $00          ; How long to wait between scroll events
DIR = $01           ; Scroll direction


    .incdir libs    ; search libs dir for include files
    .include libhw.s

    .org ROM

irq:
    rti

reset:
    cld             ; Binary mode
    ldx #$ff        ; Set top of stack
    txs
    ldx #0          ; Set scroll value to zero
    stx HRZ_SCROLL  ; Write to scroll register
    sei
    jsr lcd_init    ; Initialize LCD
    jsr lcd_clear
    lda #$80
    sta WAIT        ; Set maximum wait time between scrolls
    lda #0          ; Set scroll direction
    sta DIR
    ldx #0          ; Set current horz scroll value to zero
.print_msg
    jsr lcd_clear
    phx             ; save x current scroll value
    lda DIR
    bne .msg2       ; If DIR is zero...
    ldx #<msg1
    ldy #>msg1
    jmp .skip_msg2  ; ...and jump over printing msg2
.msg2
    ldx #<msg2
    ldy #>msg2
.skip_msg2
    jsr print_str
    plx             ; restore x, y registers
.scroll_pxl
    stx HRZ_SCROLL  ; Write to scroll register
    ldy WAIT
    jsr wait        ; Wait a bit
    lda DIR
    bne .dec_dir    ; If DIR is zero...
    inx             ; ...inc X
    jmp .skip_dex   ; ...and jump over dex X
.dec_dir
    dex             ; Otherwise dec X
.skip_dex
    bne .scroll_pxl ; Scroll all the way around
    lsr WAIT        ; Lower time between scrolls
    bne .scroll_pxl ; stop when time rolls back over

    lda #$80
    sta WAIT        ; Set maximum wait time between scrolls
    lda DIR
    cmp #0
    bne .setdir0
    lda #1
    sta DIR
    jmp .done_setdir
.setdir0
    lda #0
    sta DIR
.done_setdir
    jmp .print_msg

msg1
    .asciiz "Scrolling Left"
msg2
    .asciiz "Scrolling Right"


; Wait for a bit
;   Input: Y register, outer loop (wait time)
wait:
    phx
.outer:
    ldx #$ff
.inner:
    dex
    bne .inner
    dey
    bne .outer
    plx
    rts


    .org NODEBUG    ; This area of memory does not trigger the debugger board
    .include liblcd.s
    .include libdebug.s
    .include libreg.s

    .org VECTORS
    .word nmi
    .word reset
    .word irq
