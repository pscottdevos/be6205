#! /usr/bin/env python
from pathlib import Path
from argparse import ArgumentParser
from io import BufferedWriter

from PIL import Image

DIR = Path(__file__).parent

def convert_image(
        image: Image.Image,
        outfile: BufferedWriter,
        binary_size: int,
        image_size: tuple[int],
):
    '''Converts image to Ben Eater 64-color video card compatible image'''

    # Get the palette image to be used in quantizing the source image
    palette = get_palette()
    # Save the palette image. Can be helpful to debug hardware problems
    # if BE video image doesn't match the expected image (saved below)
    palette.save(DIR/'palette.png')
    # resize the image
    image = image.resize(image_size)
    # quantize() converts the image to the 64 colors of our palette
    # image. Dithering simulates a color by creating a "checkerboard"
    # of colors that the eye blends together. Floyd Steinberg is the
    # only dithering algorithm supported by the Pillow library at
    # this time.
    image = image.quantize(
        colors=64, palette=palette, dither=Image.FLOYDSTEINBERG
    )
    # Save the quantized image so we can compare it to what we
    # see on our VGA monitor
    image.save('converted.png')
    # Convert the image to RGB so we can read off the RGB values
    # directly instead of looking them up in the palette
    image = image.convert('RGB')
    # Number of scan lines is binary size * 1024 / 128 (128 is the number
    # of addresses per scan line) which works out to binary_size * 8
    for y in range(binary_size * 8):
        # 128 is the number of memory addresses per scan line. This is
        # fixed by the Ben Eater video card design of using 7 row address
        # lines.
        for x in range(128):
            # If we are inside the image area, compute the pixel's color value
            if x < image_size[0] and y < image_size[1]:
                # getpixel() gets a tuple of RGB values for each pixel
                # in the case of a RGB image. If we used the palette-mode
                # image, it would return a single integer index value
                # that points to the color in the palette.
                r, g, b = image.getpixel((x, y))
                # In the Ben Eater design, the low order two bits (1s
                # and 2s places) are blue, the next higher two bits (4s
                # and 8s places) are green and the next higher two bits
                # after that (16s and 32s places) are red. the highest
                # two bits are ignored (this will set them to zero)
                color = 16*int(r/64) + 4*int(g/64) + int(b/64)
            # If we are outside the size of the image, color is 0 (black)
            else:
                color = 0
            # Convert the integer to a byte string of length 1. It doesn't
            # matter the byte order because there is only one byte, but
            # 'little' or 'big' must be supplied.
            outfile.write(color.to_bytes(1, 'little'))

def get_palette() -> Image:
    '''Creates an image that can be used as a palette'''

    # List all the colors in hexidecimal in order of R,G,B,R,G,B...
    # and convert to byte string. Color palette is chosen to
    # match the colors produceable by the Ben Eater video card
    palette_bytes = bytes([
        0x00, 0x00, 0x00,
        0x00, 0x00, 0x55,
        0x00, 0x00, 0xaa,
        0x00, 0x00, 0xff,
        0x00, 0x55, 0x00,
        0x00, 0x55, 0x55,
        0x00, 0x55, 0xaa,
        0x00, 0x55, 0xff,
        0x00, 0xaa, 0x00,
        0x00, 0xaa, 0x55,
        0x00, 0xaa, 0xaa,
        0x00, 0xaa, 0xff,
        0x00, 0xff, 0x00,
        0x00, 0xff, 0x55,
        0x00, 0xff, 0xaa,
        0x00, 0xff, 0xff,
        0x55, 0x00, 0x00,
        0x55, 0x00, 0x55,
        0x55, 0x00, 0xaa,
        0x55, 0x00, 0xff,
        0x55, 0x55, 0x00,
        0x55, 0x55, 0x55,
        0x55, 0x55, 0xaa,
        0x55, 0x55, 0xff,
        0x55, 0xaa, 0x00,
        0x55, 0xaa, 0x55,
        0x55, 0xaa, 0xaa,
        0x55, 0xaa, 0xff,
        0x55, 0xff, 0x00,
        0x55, 0xff, 0x55,
        0x55, 0xff, 0xaa,
        0x55, 0xff, 0xff,
        0xaa, 0x00, 0x00,
        0xaa, 0x00, 0x55,
        0xaa, 0x00, 0xaa,
        0xaa, 0x00, 0xff,
        0xaa, 0x55, 0x00,
        0xaa, 0x55, 0x55,
        0xaa, 0x55, 0xaa,
        0xaa, 0x55, 0xff,
        0xaa, 0xaa, 0x00,
        0xaa, 0xaa, 0x55,
        0xaa, 0xaa, 0xaa,
        0xaa, 0xaa, 0xff,
        0xaa, 0xff, 0x00,
        0xaa, 0xff, 0x55,
        0xaa, 0xff, 0xaa,
        0xaa, 0xff, 0xff,
        0xff, 0x00, 0x00,
        0xff, 0x00, 0x55,
        0xff, 0x00, 0xaa,
        0xff, 0x00, 0xff,
        0xff, 0x55, 0x00,
        0xff, 0x55, 0x55,
        0xff, 0x55, 0xaa,
        0xff, 0x55, 0xff,
        0xff, 0xaa, 0x00,
        0xff, 0xaa, 0x55,
        0xff, 0xaa, 0xaa,
        0xff, 0xaa, 0xff,
        0xff, 0xff, 0x00,
        0xff, 0xff, 0x55,
        0xff, 0xff, 0xaa,
        0xff, 0xff, 0xff,
    ])
    # Create an RGB image from the palatte byte string. Image
    # is a row of pixels of each color followed by two rows of
    # black (0, 0, 0)
    palette = Image.frombytes('RGB', (64, 1), palette_bytes)
    # Convert image to a Palette image. Using Adaptive strategy
    # forces image to use the palette colors. If you leave off
    # the palette argument, it will convert the image to using
    # the default "Web" palette which consists of the 216 color
    # combinations of the values (00, 33, 66, 99, cc, ff)
    palette = palette.convert('P', colors=64, palette=Image.ADAPTIVE)
    return palette


if __name__ == '__main__':
    # Require an image file and an output file. The output file will be
    # the binary loaded on the Video card ROM
    parser = ArgumentParser(
        prog='BE VGA Card Image Converter',
        description='Converts an image to bin file compatible with Ben Eater '
            'VGA Card'
    )
    parser.add_argument('imagefile', help="name of image file")
    parser.add_argument('outfile', help="name of output file")
    # Default height is 75. Use 64 if generating image for
    # Ben Eater 6502 computer video card
    parser.add_argument(
        '-g', '--height', default=75, type=int,
        help='height of final image'
    )
    # Default width is 100. Use 128 to make full use of
    # SDV hardware scrolling
    parser.add_argument(
        '-w', '--width', default=100, type=int,
        help='width of final image'
    )
    # Default to 32kB ROM image. Some EPROM programmers require binary
    # EPROM image to match the size of the EPROM being programmed.
    parser.add_argument(
        '-s', '--size', default=32, type=int,
        help='Size (in kilobytes) of binary to create'
    )
    args = parser.parse_args()

    image = Image.open(args.imagefile)
    with open(args.outfile, 'wb') as outfile:
        convert_image(
            image, outfile,
            binary_size=args.size,
            image_size=(args.width, args.height)
        )