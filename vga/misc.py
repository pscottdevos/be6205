import sync_prom as sp

def test_bit_skip():
    print('Bit Skip Test')
    special_numbers = (216, 217, 221, 244)
    for y in range(630):
        y_str = f'{y:09b}'
        new_y_str = y_str[0] + y_str[3:]
        new_y = int(new_y_str, 2)
        if new_y in special_numbers:
            print(y, new_y)
    print()

def find_vcr_bit():
    with open('sync-prom.bin', 'rb') as fp:
        for i, byte in enumerate(fp.read()):
            if byte & sp.VCR:
                print(i, f'{byte:08b}')


if __name__ == '__main__':
    find_vcr_bit()