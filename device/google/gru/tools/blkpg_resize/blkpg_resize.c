/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <errno.h>
#include <fcntl.h>
#include <linux/blkpg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 5) {
        fprintf(stderr, "Usage: %s <disk_dev> <part_num> <start_bytes> <length_bytes>\n", argv[0]);
        return 1;
    }

    const char *disk = argv[1];
    int part_num = atoi(argv[2]);
    long long start = atoll(argv[3]);
    long long length = atoll(argv[4]);

    if (part_num <= 0 || start < 0 || length <= 0) {
        fprintf(stderr, "Invalid arguments: part_num=%d, start=%lld, length=%lld\n",
                part_num, start, length);
        return 1;
    }

    int fd = open(disk, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        perror("Failed to open disk device");
        return 1;
    }

    struct blkpg_partition p;
    memset(&p, 0, sizeof(p));
    p.pno = part_num;
    p.start = start;
    p.length = length;

    struct blkpg_ioctl_arg a;
    memset(&a, 0, sizeof(a));
    a.op = BLKPG_RESIZE_PARTITION;
    a.flags = 0;
    a.datalen = sizeof(p);
    a.data = &p;

    if (ioctl(fd, BLKPG, &a) < 0) {
        perror("ioctl BLKPG_RESIZE_PARTITION failed");
        close(fd);
        return 1;
    }

    close(fd);
    return 0;
}
