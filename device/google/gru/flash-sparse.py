#!/usr/bin/env python3
"""Write an Android sparse image to one block device."""
import os
import struct
import sys

RAW = 0xCAC1
FILL = 0xCAC2
DONT = 0xCAC3
CRC = 0xCAC4


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: flash-sparse.py IMAGE DEVICE")
    image, device = sys.argv[1:]
    if device != "/dev/mmcblk0p6":
        raise SystemExit("refuse device " + device)
    with open(image, "rb") as src:
        header = src.read(28)
        if len(header) != 28:
            raise SystemExit("short header")
        magic, major, minor, file_hdr, chunk_hdr, blk, blocks, chunks, _sum = struct.unpack(
            "<IHHHHIIII", header
        )
        if magic != 0xED26FF3A:
            raise SystemExit("not a sparse image")
        if file_hdr < 28 or chunk_hdr < 12:
            raise SystemExit("bad header size")
        src.read(file_hdr - 28)
        expected = blk * blocks
        fd = os.open(device, os.O_RDWR)
        try:
            size = os.lseek(fd, 0, os.SEEK_END)
            os.lseek(fd, 0, os.SEEK_SET)
            if size != expected:
                raise SystemExit("device size %d != image %d" % (size, expected))
            position = 0
            for _ in range(chunks):
                raw = src.read(chunk_hdr)
                if len(raw) != chunk_hdr:
                    raise SystemExit("short chunk header")
                kind, _reserved, count, total = struct.unpack("<HHII", raw[:12])
                payload = total - chunk_hdr
                nbytes = count * blk
                if kind == RAW:
                    left = payload
                    while left:
                        buf = src.read(min(1024 * 1024, left))
                        if not buf:
                            raise SystemExit("short raw chunk")
                        os.write(fd, buf)
                        left -= len(buf)
                    position += payload
                elif kind == FILL:
                    pattern = src.read(4)
                    if len(pattern) != 4:
                        raise SystemExit("short fill")
                    repeats = nbytes // 4
                    block = pattern * 1024
                    full, rest = divmod(repeats, 1024)
                    for _ in range(full):
                        os.write(fd, block)
                    if rest:
                        os.write(fd, pattern * rest)
                    position += nbytes
                elif kind == DONT:
                    os.lseek(fd, nbytes, os.SEEK_CUR)
                    position += nbytes
                elif kind == CRC:
                    src.read(payload)
                else:
                    raise SystemExit("unknown chunk %#x" % kind)
            if position != expected:
                raise SystemExit("wrote %d, expected %d" % (position, expected))
            os.fsync(fd)
        finally:
            os.close(fd)
    print("SPARSE_OK", expected)


if __name__ == "__main__":
    main()
