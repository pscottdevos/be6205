#! /usr/bin/env python
from pathlib import Path
from argparse import ArgumentParser
from io import BufferedWriter

from PIL import Image

DIR = Path(__file__).parent

def convert_image(image: Image.Image, outfile: BufferedWriter):

    with open(DIR/'64-color.act', 'rb') as fp:
        palette = Image.frombytes('RGB', (64*3, 1), fp.read()).convert('P', colors=64)
        palette.save(DIR/'64-color.bmp')
        palette.save(DIR/'64-color.png')
    image = image.resize((128, 75))
    image = image.quantize(colors=64, palette=palette, dither=Image.FLOYDSTEINBERG)
    image.save(DIR/'resize.png')
    image = image.convert('RGB')
    for y in range(75):
        for x in range(128):
            if x >= 100:
                pixel = 0
            else:
                r, g, b = (int(c / 64) for c in image.getpixel((x, y)))
                pixel = r * 16 + g * 4 + b
            outfile.write(pixel.to_bytes(1, 'little'))


if __name__ == '__main__':
    parser = ArgumentParser(
        prog='BE VGA Card Image Converter',
        description='Converts an image to bin file compatible with Ben Eater '
            'VGA Card'
    )
    parser.add_argument('imagefile', help="name of image file")
    parser.add_argument('outfile', help="name of output file")

    args = parser.parse_args()
    image = Image.open(args.imagefile)
    with open(args.outfile, 'wb') as outfile:
        convert_image(image, outfile)
