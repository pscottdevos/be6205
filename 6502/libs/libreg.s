; Depends on libhw.s

; Set video register bank and block. Does not set any of the IRQ-related
; bits (i.e. bits 2-5)
;   Vars:   BNK_SEL     0 = None, 1 = BG RAM, 2 = FG RAM
;           BLK_SEL     Video RAM block 0 - 3 (any other value will cause IRQ
;                       problems)
set_video_reg:
    pha
    lda BNK_SEL     ; Load bank selection
    bne .set_bnk    ; If bank is zero...
    lda #SYS_RAM_SEL; Set neither FG nor BG ram; use high speed clock
    jmp .set_blk
.set_bnk:
    cmp #$1         ; check for BG bank
    beq .set_bg
    ; For some reason jumping directly to FG RAM breaks the system so we
    ; Set for BG ram first and then switch to FG RAM
    lda #BG_RAM_SEL ; Set for BG RAM; use low speed clock
    clc
    adc BLK_SEL     ; Set RAM block
    sta VID_REG     ; Store to video register
    nop             ; No Ops seem to help with stability after switching
    nop
    ; Now we switch to FG RAM
    lda #FG_RAM_SEL ; Set for FG RAM; use low speed clock
    jmp .set_blk
.set_bg:
    lda #BG_RAM_SEL ; Set for BG RAM; use low speed clock
.set_blk:
    clc
    adc BLK_SEL     ; Set RAM block
    sta VID_REG
    sta VID_REG_VAL ; Store the video register value (because reg is write-only)
    nop             ; No Ops seem to help with stability after switching
    nop
    pla
    rts


; Set ram block without changing bank, clock, or irq-related bits
;   Vars:   BLK_SEL     Video RAM block 0 - 3 (any other value will cause IRQ
;                       problems)
set_ram_blk:
    pha
    lda VID_REG_VAL ; Load the current value of the video register
    and #BNK_MSK    ; Clear the bank select bits
    clc
    adc BLK_SEL     ; Set RAM block
    sta VID_REG
    sta VID_REG_VAL ; Store the video register value (because reg is write-only)
    pla
    rts


; Wait for resume button press; Disable interrupts so they don't resume
; before user has a chance to push the button
;   Vars:   VID_REG_VAL stored value last written to video register
wait:
    pha
    lda VID_REG_VAL ; Load the video register value
    ora #INH_IRQ    ; Set the IRQ inhibit bit
    sta VID_REG     ; Store result in the video register
    .byte $cb       ; Wait for resume button press (65c02 wait instruction)
    lda VID_REG_VAL ; Load original video register value...
    sta VID_REG     ;   ...and store it to video register
    pla
    rts


; Interrupt handler. Checks for type of interrupt and calls appropriate
; handler
irq:
    pha
.check_fb_col
    lda IRQ_REG
    and #FB_COL         ; Check for FG/BG object collision
    beq .check_vbs      ; If not FB_COL, check for start of vert blank interval
    jsr handle_fb_col   ; call collision handler
    lda VID_REG_VAL     ; Pulse the FB_COL interrupt clear bit
    ora #FB_COL
    sta VID_REG
    lda VID_REG_VAL
    sta VID_REG
    pla
    rti
.check_vbs:
    lda IRQ_REG
    and #VBS            ; Check for VBS interrupt
    beq .done           ; If not VBS interrupt, we're done
    jsr handle_vbs      ; call VBS handler
    lda VID_REG_VAL     ; Pulse the VBS interrupt clear bit
    ora #VBS
    sta VID_REG
    lda VID_REG_VAL
    sta VID_REG
.done
    pla
    rti