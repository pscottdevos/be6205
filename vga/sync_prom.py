#! /usr/bin/env python

from io import IOBase

#   7   6   5    4    3   2   1    0
#   VBI BI  VCRB HCRB RES VBS VSYB HSYB
#   |   |   |    |    |   |   |    |
#   |   |   |    |    |   |   |    |___ Horizontal Sync Bar
#   |   |   |    |    |   |   |________ Vertical Sync Bar
#   |   |   |    |    |   |____________ Video Blank Interval Starting
#   |   |   |    |    |________________ Reserved (unused)
#   |   |   |    |_____________________ Horizontal Counter Reset Bar
#   |   |   |__________________________ Vertical Counter Reset Bar
#   |   |______________________________ Blank Iterval
#   |__________________________________ Vertical Blank Interval

# Control Bits
HSY = 0b00000001
VSY = 0b00000010
VBS = 0b00000100
RES = 0b00001000
HCR = 0b00010000
VCR = 0b00100000
BI  = 0b01000000
VBI = 0b10000000

# Inverted (XOR with 255 reverses all bits)
HSY_INV = HSY ^ 255
VSY_INV = VSY ^ 255
HCR_INV = HCR ^ 255
VCR_INV = VCR ^ 255

# Horizontal Points of Interest after ignoring the 1s bit (bit 0)
HBI_START = 100     # Start of Horizontal Blank Interval
HSY_START = 105     # Start of Horizontal Sync
HSY_END   = 121     # End of Horizontal Sync
HBI_END   = 132     # End of Horizontal Blank Interval

# Vertical Lines of Interest after ignoring the bits 7 and 8
VBI_START = 216     # Start of Vertical Blank Interval
VSY_START = 217     # Start of Vertical Sync
VSY_END   = 221     # End of Vertical Sync
VBI_END   = 244     # End of Vertical Blank Interval

irq_recovery_time = 2   # The number of horz counter periods to "pad" the end
                        # the end of of the blank interval for the BIE signal

def set_H_bits(x: int, signals: int):
    """
i   Sets the horizontal-related bits of the signals
    x: horizontal counter value
    y: vertical counter value
    signals: signal bits
    """
    # Horizontal Display Interval
    if x < HBI_START:
        pass
    # Horizontal Front Porch
    elif x < HSY_START:
        signals |= BI
    # Horizontal Sync
    elif x < HSY_END:
        signals |= BI
        signals &= HSY_INV # hsync sig is inverted
    # Horizontal Back Porch
    elif x < HBI_END:
        signals |= BI
    # Horizontal Counter Reset
    else:
        # Just need one horizontal counter reset normally, but in case system
        # power up at an address "between" scan lines, want to reset HCR to
        # get things started
        signals &= HCR_INV
    return signals


def main(outfile: str):
    with open(outfile, 'wb') as fp:
        for y in range(256):

            # we have to cycle through all 8 bits of horizontal addresses to
            # fill the address space after VBI_END and the start of the next
            # line
            for x in range(256):
                # sync and reset signals are inverted; set by default
                # horizontal and vertical counter reset also set by default
                signals = HSY | VSY | HCR | VCR

                # Vertical Display Interval
                if y < VBI_START:
                    # V Display Interval
                    signals = set_H_bits(x, signals)
                # Vertical Front Porch
                elif y < VSY_START:
                    signals |= BI | VBI
                    signals = set_H_bits(x, signals)
                # Vertical Sync
                elif y < VSY_END:
                    signals |= BI | VBI
                    signals &= VSY_INV # vsync sig is inverted
                    signals = set_H_bits(x, signals)
                # Vertical Back Porch
                elif y < VBI_END:
                    signals |= BI | VBI
                    signals = set_H_bits(x, signals)
                # Vertical Counter Reset
                else:
                    # Just need one vertical reset byte normally, but system
                    # could start at power up with any random address, so best
                    # to reset HCR and VCR until the end of the address space
                    signals &= VCR_INV
                    signals &= HCR_INV

                # Pulse VBS at the start of the first line of the vertical blank
                # interval
                if y == VBI_START and x in range(0, 4):
                    signals |= VBS

                fp.write(bytes([signals]))


if __name__ == "__main__":
    main('sync-prom.bin')
