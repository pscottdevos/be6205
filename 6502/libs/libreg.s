; Depends on libhw.s

; Set video register bank and block
;   Vars:   BNK_SEL     0 = None, 1 = BG RAM, 3-FF = FG RAM
;           BLK_SEL     Video RAM block 0 - 3
set_video_reg:
    pha
    lda BNK_SEL         ; Load bank selection
    bne .set_bnk        ; If bank is zero...
    lda #%11000000      ; Set neither FG nor BG ram; use high speed clock
    jmp .set_blk
.set_bnk
    cmp #$1             ; check for BG bank
    beq .set_bg
    lda #%01100000      ; Set for FG RAM; use low speed clock
    jmp .set_blk
.set_bg
    lda #%10100000      ; Set for BG RAM; use low speed clock
.set_blk
    clc
    adc BLK_SEL         ; Set RAM block
    sta VID_RAM_REG
    nop
    nop
    pla
    rts