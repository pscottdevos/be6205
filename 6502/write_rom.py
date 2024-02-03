#! /usr/bin/env python
import serial
import sys
import time
import xmodem
from argparse import ArgumentParser
from io import BufferedWriter, BufferedRandom


BAUD_RATE = 115200

def read_response(dev: BufferedRandom):
    response = b''
    while True:
        byte = dev.read(1)
        response += byte
        if byte == b'>':
            break
    return response.decode('ascii')


def write_rom(fp: BufferedWriter, device: str, start: bytes):
    # Report BAUD rate to user
    sys.stdout.write(f'Sending at {BAUD_RATE} BAUD\n')
    # Open Serial Device to connect to TommyPROM
    with serial.Serial(device, BAUD_RATE, timeout=5) as dev:

        # Keep track of number of bytes sent and time sent. Using list
        # so we can update values inside functions below
        bytes_sent = [0, time.time()]

        # Function to get size bytes from serial device.
        # function is passed to xmodem.XMODEM()
        def get(size, timeout=1):
            result = dev.read(size) or None
            return result

        # Function to put bytes to serial device. Function is
        # passed to xmodem.XMODEM()
        def put(data, timeout=1):
            # write data and record number of bytes sent
            result = dev.write(data)
            # keep running total of bytes. subtract 4 for header and footer
            # of xprotocol for each block of data
            bytes_sent[0] += result - 4
            # round off to 10ths of kilobytes
            kBs = round(bytes_sent[0]/1024, 1)
            # compute total time since start and round off to 10ths of second
            t = round(time.time() - bytes_sent[1], 1)
            # Report to user total number of bytes received and total time
            sys.stdout.write(f"\r{kBs}kB sent in {t} seconds")
            return result

        # Report response from TommyPROM upon startup
        sys.stdout.write(read_response(dev))

        # Issue command to start writing at start address
        dev.write(b'w' + start + b'\r')
        # w command returns text that doesn't end in a prompt (>)
        sys.stdout.write(dev.readline().decode('ascii'))
        sys.stdout.write(dev.readline().decode('ascii'))
        # Send the image using xmodem protocol
        modem = xmodem.XMODEM(get, put)
        success = modem.send(fp)
        sys.stdout.write(read_response(dev))
        sys.stdout.write(
            f'\n\nResult of Transmission: {"OK" if success else "ERROR"}\n'
        )


if __name__ == '__main__':

    parser = ArgumentParser(
        prog='writerom.py',
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
        device = args.device
        start_addr = args.start.encode('ascii')
        write_rom(infile, device, start_addr)

