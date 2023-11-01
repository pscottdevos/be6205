#! /usr/bin/env python

from io import IOBase

#   7   6   5   4   3   2   1   0
#   DI  BI  VCR HCR VBI HBI VSY HSY
#   |   |   |   |   |   |   |   |
#   |   |   |   |   |   |   |   |___Horizontal Sync
#   |   |   |   |   |   |   |_______Vertical Sync
#   |   |   |   |   |   |___________Horizontal Blank Interval
#   |   |   |   |   |_______________Vertical Blank Interval
#   |   |   |   |___________________Horizontal Counter Reset
#   |   |   |_______________________Vertical Counter Reset
#   |   |___________________________Blank Iterval
#   |_______________________________Display Interval

# Control Bits
HSY = 0b00000001
VSY = 0b00000010
HBI = 0b00000100
VBI = 0b00001000
HCR = 0b00010000
VCR = 0b00100000
BI  = 0b01000000
DI  = 0b10000000

# Inverted (XOR with 255 1s reverses all bits)
HSY_INV = HSY ^ 0b11111111
VSY_INV = VSY ^ 0b11111111
HCR_INV = HCR ^ 0b11111111
VCR_INV = VCR ^ 0b11111111

# Horizontal Points of Interest after ignoring the 2s bit (bit 1)
HBI_START = 100     # Start of Horizontal Blank Interval
HSY_START = 105     # Start of Horizontal Sync
HSY_END   = 121     # End of Horizontal Sync
HBI_END   = 132     # End of Horizontal Blank Interval

# Vertical Lines of Interest after ignoring the bits 7 and 8
VBI_START = 216     # Start of Vertical Blank Interval
VSY_START = 217     # Start of Vertical Sync
VSY_END   = 221     # End of Vertical Sync
VBI_END   = 244     # End of Vertical Blank Interval


def set_H_bits(x: int, byte: int):
    # H Display Interval
    if x < HBI_START:
        pass
    # H Front Porch
    elif x < HSY_START:
        byte |= BI | HBI
    # H Sync
    elif x < HSY_END:
        byte |= BI | HBI
        byte &= HSY_INV # hsync sig is inverted
    # H Back Porch
    elif x < HBI_END:
        byte |= BI | HBI
    # H Counter Reset
    elif x == HBI_END:
        byte &= HCR_INV
    # Filler
    else:
        byte = 0
    return byte


def main(outfile: str):
    with open(outfile, 'wb') as fp:
        for y in range(256):

            # we have to cycle through all 7 bits of horizontal addresses to
            # fill the address space after VBI_END and the start of the next
            # line
            for x in range(256):
                # sync and reset signals are inverted; set by default
                byte = HSY | VSY | HCR | VCR

                # V Display Interval
                if y < VBI_START:
                    # H Display Interval
                    if x < HBI_START:
                        byte |= DI
                    byte = set_H_bits(x, byte)
                # V Front Porch
                elif y < VSY_START:
                    byte |= BI | VBI
                    byte = set_H_bits(x, byte)
                # V Sync
                elif y < VSY_END:
                    byte |= BI | VBI
                    byte &= VSY_INV # vsync sig is inverted
                    byte = set_H_bits(x, byte)
                # V Back Porch
                elif y < VBI_END:
                    byte |= BI | VBI
                    byte = set_H_bits(x, byte)
                # V Counter Reset
                elif y == VBI_END:
                    # Just need one vertical reset byte
                    if x == 0:
                        byte &= VCR_INV
                        byte &= HCR_INV
                    # the rest is filler
                    else:
                        byte = 0
                # Filler
                else:
                    byte = 0

                fp.write(bytes([byte]))


if __name__ == "__main__":
    main('sync-prom.bin')
