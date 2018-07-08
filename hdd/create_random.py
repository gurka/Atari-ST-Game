import sys
import random

if __name__ == '__main__':
    if len(sys.argv) != 5:
        print("usage: {} NUM_VALUES NUM_BYTES MIN_VALUE MAX_VALUE".format(sys.argv[0]))
        sys.exit(1)

    num_values = int(sys.argv[1])
    num_bytes = int(sys.argv[2])
    min_value = int(sys.argv[3])
    max_value = int(sys.argv[4])

    if min_value >= max_value:
        print("MIN_VALUE must be less than MAX_VALUE")
        sys.exit(1)

    if ((num_bytes == 1 and max_value > 255) or
        (num_bytes == 2 and max_value > 65535) or
        (num_bytes == 3 and max_value > 16777215) or
        (num_bytes == 4 and max_value > 4294967295) or
        (num_bytes < 1) or
        (num_bytes > 4)):
        print("Invalid combination of NUM_BYTES and MAX_VALUE")
        sys.exit(1)

    random.seed()

    with open('RANDOM.BIN', 'wb') as f:
        for i in range(num_values):
            f.write(random.randint(min_value, max_value).to_bytes(num_bytes, byteorder='big'))

    print("Wrote RANDOM.BIN")
