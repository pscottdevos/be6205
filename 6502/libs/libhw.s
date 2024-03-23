; Zero page variables
; Block is 8k range within 32k video memory chip
BLK_SEL = $fa       ; Selected video ram block; 1 byte
; Bank is which chip (FG or BG RAM)
BNK_SEL = $fb       ; Selected video ram bank; 1 byte 0 = sys, 1 = BG, 2 = FG
VID_REG_VAL = $fc   ; Value stored in (write-only) video register

; Hardware
VID_RAM = $2000     ; Starting location of video RAM block
RSV_ADDR = $4000    ; Starting location of reserved addresses

; Video Registers
VRT_SCROLL = $5010  ; Vertical scroll register
HRZ_SCROLL = $5020  ; Horizontal scroll register
VID_REG = $5070     ; Video RAM section register (write-only)
IRQ_REG = $5070     ; IRQ Status Register (read-only)

; ROM
ROM = $8000         ; Start of ROM
NODEBUG = $c000     ; Start of non-debuggable ROM area

; 6502 Start of Vectors
VECTORS = $fffa

; IRQ Masks
FB_COL_NBL  = %01000000 ; OR with vid RAM value to enable FB_COL at mem location
FB_COL_PRV  = %10111111 ; AND with vid RAM value to prevent FB_COL interrupt at
                        ;   memory location
SYS_RAM_SEL = %11000000 ; Turns off BG and FG RAM and selects high speed clock
FG_RAM_SEL  = %01100000 ; Turns on FG RAM and selects low speed clock
BG_RAM_SEL  = %10100000 ; Turns on BG RAM and selects low speed clock
BNK_MSK     = %11111100 ; AND with VID_REG_VAL to clear bank select bits
VBS     = %00000100     ; Use as mask to check for VBS interrupt
                        ;   as a set mask to clear VBS interrupt
FB_COL  = %00001000     ; Use as mask to check for collision interrupt;
                        ;   as a set mask to clear collision interrupt
INH_IRQ = %00010000     ; Use as a set mask to prevent VBS and FB_COL interrupts
ALL_IRQ = VBS | FB_COL  ; Use as a mask to check for ALL; as a set mask to clear