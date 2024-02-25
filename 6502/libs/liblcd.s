; Zero Page Variables

MESSAGE = $fc   ; LCD Message address; 2-bytes

; Constants

; LCD Controller-related contants
E = %10000000   ; LCD controller Enable bit
RW = %01000000  ; LCD controller RW bit
RS = %00100000  ; LCD controller Register Select bit
RDY = %10000000 ; LCD controller Ready bit
ADDR = %01111111; LCD controller cursor address counter bits
DSP = %00001110 ; LCD display control; display on; Cursor on; no blink cursor
CSR = %00000110 ; LCD cursor contol; Increment cursor position; no scroll


; Hardware registers
; 6522 IO Registers
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003


; Get LCD address counter
;   Output:
;       A register - LCD address counter value
lcd_addr:
    lda #%00000000  ; Set all pins on Port B to input
    sta DDRB
.lcd_busy:
    lda #RW         ; Set RW to Read; Clear RS/E bits
    sta PORTA       ; "
    lda #(RW | E)   ; Set Enable bit
    sta PORTA
    lda PORTB       ; Read from Port B
    pha             ; Save port B result on stack
    and #RDY        ; Mask Instruction Ready bit
    bne .lcd_busy   ; Look again if not ready
    lda #RW         ; Reset Enable bit
    sta PORTA       ; "
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB        ; "
    pla             ; Recover saved port B value
    and #ADDR       ; Mask address bits
    rts

; Clear LCD Display
lcd_clear:
    pha
    lda #%00000001      ; Clear Display
    jsr lcd_instruction
    pla
    rts

; Init LCD display
lcd_init:
    pha
    lda #%11111111      ; Set all pins on port B to output
    sta DDRB
    lda #%11100000      ; Set top 3 pins on port A to output
    sta DDRA
    lda #%00111000      ; 8-bit mode; 2-line display; 5x8 format
    jsr lcd_instruction
    lda #DSP            ; Set display control
    jsr lcd_instruction
    lda #CSR            ; Set cursor control
    jsr lcd_instruction
    pla
    rts

; Send instruction to LCD controller
lcd_instruction:
    jsr lcd_wait
    sta PORTB
    lda #0          ; Clear RS/RW/E bits
    sta PORTA
    lda #E          ; Toggle enable bit to send instruction
    sta PORTA       ; "
    lda #0          ; "
    sta PORTA       ; "
    rts

; Read byte at LCD address couter
lcd_read
;   Output: A register - byte from address couter
;   Side Effect: LCD address counter increments/decrements (based on mode set)
    jsr lcd_wait
    lda #%00000000      ; Set all pins on Port B to input
    sta DDRB
    lda #(RW | RS)      ; Set RW to Read; RS to data; Clear E bit
    sta PORTA
    lda #(RW | RS | E)  ; Set Enable bit
    sta PORTA
    lda PORTB           ; Read from Port B
    pha                 ; Save data to stack
    lda #(RW | RS)      ; Set RW to Read; RS to data; Clear E bit
    sta PORTA           ; "
    lda #%11111111      ; Set all pins on port B to output
    sta DDRB            ; "
    pla                 ; Recover data saved to stack
    rts

; Wait for LCD to respond
lcd_wait:
    pha
    lda #%00000000  ; Set all pins on Port B to input
    sta DDRB
.lcd_busy:
    lda #RW         ; Set RW to Read; Clear RS/E bits
    sta PORTA       ; "
    lda #(RW | E)   ; Set Enable bit
    sta PORTA
    lda PORTB       ; Read from Port B
    and #RDY        ; Mask Instruction Ready bit
    bne .lcd_busy   ; Look again if not ready
    lda #RW         ; Reset Enable bit
    sta PORTA       ; "
    lda #%11111111  ; Set all pins on port B to output
    sta DDRB        ; "
    pla
    rts

; Set LCD address counter
;   Input: A register - Value to set address
lcd_set_addr:
    ora #%10000000  ; Set LCD set address commmand bit
    jsr lcd_instruction
    rts

; Print character to LCD screen
;   Input: A register - ascii char to print
print_char:
    pha
    jsr lcd_wait
    sta PORTB       ; Store A register to Port B
    lda #RS         ; Set RS bit; Clear RW/E bits
    sta PORTA
    lda #(RS | E)   ; Toggle enable bit to send instruction
    sta PORTA       ; "
    lda #RS         ; "
    sta PORTA       ; "
    pla
    rts

; Print Hex Value to LCD screen
;   Input: A register - Hex Value to print
print_hex:
    pha
    ror             ; rotate high order nibble into low order nibble
    ror
    ror
    ror
    jsr hex2char
    jsr print_char
    pla             ; Get original number off stack
    pha             ; And put it back
    jsr hex2char
    jsr print_char
    pla
    rts

; Print string to LCD screen
;   Input: x, y: low order, high order of message location
print_str:
    pha
    stx MESSAGE     ; Store low order byte of message location
    sty MESSAGE + 1 ; Store high order byte of message location
    ldy #0          ; y register holds offset from start of string
.print:
    lda (MESSAGE),y ; Load offset y from location pointed to by MESSAGE
    beq .done       ; Branch to done if we loaded null (0)
    jsr print_char  ; print the character loaded
    iny             ; prep for the next character
    jmp .print      ; loop back for next character
.done:
    pla
    rts

; Convert low order nibble of accumulator to ascii character (0-9 A-F)
;   Input A register - value to convert in low order bits. Destroys value in A
hex2char:
    and #%00001111  ; Get low order nibble
    cmp #$a
    bmi .range_0to9 ; If > $a, Skip past range $a-$f computation
    clc
    adc #"A" - $a   ; Add ascii of "A" minus $a to A (so $a will land on "A")
    jmp .done       ; Skip past range $0-$9 computation
.range_0to9
    clc             ; Add ascii of "0" to A
    adc #"0"
.done:
    rts