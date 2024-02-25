; Depends on libhw.s

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