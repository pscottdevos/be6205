#! /usr/bin/env python
import serial
import sys
import time
import xmodem
from argparse import ArgumentParser
from io import BufferedWriter


BAUD_RATE = 115200

def write_rom(fp: BufferedWriter, device: str, start: bytes):
    sys.stdout.write(f'Sending at {BAUD_RATE} BAUD\n')
    with serial.Serial(device, BAUD_RATE, timeout=5) as dev:

        bytes_sent = [0, time.time()]

        def get(size, timeout=1):
            result = dev.read(size) or None
            return result

        def put(data, timeout=1):
            result = dev.write(data)
            bytes_sent[0] += result - 4
            kBs = int(round(bytes_sent[0]/1024, 0))
            t = round(time.time() - bytes_sent[1], 1)
            sys.stdout.write(f"\r{kBs}kB sent in {t} seconds")
            return result

        sys.stdout.write(dev.read(2).decode('ascii'))
        dev.write(b'w' + start + b'\r')
        sys.stdout.write(dev.readline().decode('ascii'))
        sys.stdout.write(dev.readline().decode('ascii'))
        modem = xmodem.XMODEM(get, put)
        result = modem.send(fp)
        sys.stdout.write(
            f'\n\nResult of Transmission: {"OK" if result else "ERROR"}\n'
        )


if __name__ == '__main__':

    parser = ArgumentParser(
        prog='TommyPROM binary ROM file writer',
        description='Writes binary ROM file to TommyPROM EEPROM writer'
    )
    parser.add_argument('filename', help="Path to binary file to write.")
    parser.add_argument('-d', '--device',
        default='/dev/ttyUSB0', help="path to serial (usb) device."
    )
    parser.add_argument('-s', '--start',
        default='0', help='Starting memory location on EEPROM in hex'
    )
    args = parser.parse_args()

    with open(args.filename, 'rb') as infile:
        write_rom(infile, args.device, args.start.encode('ascii'))

