; Zero page variables
; Block is 8k range within 32k video memory chip
BLK_SEL = $fa       ; Selected video ram block; 1 byte
; Bank is which chip (FG or BG RAM)
BNK_SEL = $fb       ; Selected video ram bank; 1 bit
; RAM

; Hardware
VID_RAM = $2000     ; Starting location of video RAM block
RSV_ADDR = $4000    ; Starting location of reserved addresses

; Video Registers
VRT_SCROLL = $5010  ; Vertical scroll register
HRZ_SCROLL = $5020  ; Horizontal scroll register
VID_RAM_REG = $5070 ; Video RAM section register

; ROM
ROM = $8000         ; Start of ROM
NODEBUG = $c000     ; Start of non-debuggable ROM area

; 6502 Start of Vectors
VECTORS = $fffa

