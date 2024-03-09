#! /usr/bin/env python

from io import IOBase

#   7   6   5    4    3   2   1    0
#   DI  BI  VCRB HCRB BIE BIS VSYB HSYB
#   |   |   |    |    |   |   |    |
#   |   |   |    |    |   |   |    |___Horizontal Sync Bar
#   |   |   |    |    |   |   |________Vertical Sync Bar
#   |   |   |    |    |   |____________Blank Interval Starting (Now)
#   |   |   |    |    |________________Blank Interval Ending (Soon)
#   |   |   |    |_____________________Horizontal Counter Reset Bar
#   |   |   |__________________________Vertical Counter Reset Bar
#   |   |______________________________Blank Iterval
#   |__________________________________Display Interval

# Control Bits
HSY = 0b00000001
VSY = 0b00000010
BIS = 0b00000100
BIE = 0b00001000
HCR = 0b00010000
VCR = 0b00100000
BI  = 0b01000000
DI  = 0b10000000

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

def set_H_bits(x: int, y: int, signals: int):
    """
i   Sets the horizontal-related bits of the signals
    x: horizontal counter value
    y: vertical counter value
    signals: signal bits
    """
    # H Display Interval
    if x < HBI_START:
        # Pulse BIS at the start of the first line of the vertical blank
        # interval
        if y == VBI_START and x == 0:
            signals |= BIS
    # H Front Porch
    elif x < HSY_START:
        # Pulse BIS at the start of the horizontal blank interval except
        # during the vertical blank interval
        if y < VBI_START and x == HBI_START:
            signals |= BIS
        signals |= BI
    # H Sync
    elif x < HSY_END:
        signals |= BI
        signals &= HSY_INV # hsync sig is inverted
    # H Back Porch
    elif x < HBI_END:
        # Pulse BIE near the end of the horizontal blank interval except
        # during the vertical blanking interval lines prior to the last line
        # I.e. do pulse on the last line of the VBI
        if (y < VBI_START or y == VBI_END) and x == HBI_END - irq_recovery_time:
            signals |= BIE
        signals |= BI
    # H Counter Reset
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

                # V Display Interval
                if y < VBI_START:
                    # H Display Interval
                    if x < HBI_START:
                        signals |= DI
                    signals = set_H_bits(x, signals)
                # V Front Porch
                elif y < VSY_START:
                    signals |= BI | BIE
                    signals = set_H_bits(x, signals)
                # V Sync
                elif y < VSY_END:
                    signals |= BI | BIE
                    signals &= VSY_INV # vsync sig is inverted
                    signals = set_H_bits(x, signals)
                # V Back Porch
                elif y < VBI_END:
                    signals |= BI | BIE
                    signals = set_H_bits(x, signals)
                # V Counter Reset
                else:
                    # Just need one vertical reset byte normally, but system
                    # could start at power up with any random address, so best
                    # to reset HCR and VCR until the end of the address space
                    signals &= VCR_INV
                    signals &= HCR_INV

                fp.write(bytes([signals]))


if __name__ == "__main__":
    main('sync-prom.bin')
