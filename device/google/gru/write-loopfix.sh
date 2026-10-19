#!/bin/sh
# Replace the SD KernelA FIT and the super image. Does not change the
# partition table, userdata, metadata, bootlog, or the internal disk.
set -eu
DIR=/home/user/phase3
LOG=$DIR/write-loopfix.log
IMAGE=$DIR/kernel.kpart
SUPER=$DIR/super.img
SD=/dev/mmcblk0
EMMC=/dev/mmcblk1
EXPECT=5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }

say "=== identity ==="
say "uname=$(uname -r)"
ROOT=$(awk '$2=="/" {print $1; exit}' /proc/mounts)
say "root=$ROOT"
if [ "$(id -u)" -ne 0 ]; then
    say ABORT_NOT_ROOT
    exit 1
fi
if [ "$(uname -r)" != 6.6.34 ] || [ "$ROOT" != /dev/mmcblk1p3 ]; then
    say ABORT_IDENTITY
    exit 1
fi
if awk '$1 ~ /mmcblk0/ {found=1} END {exit !found}' /proc/mounts; then
    say ABORT_MOUNTED
    exit 1
fi
if [ "$(blockdev --getsize64 "$SD")" != 62549655552 ]; then
    say ABORT_DISK
    exit 1
fi
if [ ! -f "$IMAGE" ] || [ ! -f "$SUPER" ]; then
    say ABORT_FILES
    exit 1
fi
KSIZE=$(stat -c %s "$IMAGE")
if [ "$KSIZE" -gt 33554432 ]; then
    say "ABORT_SIZE $KSIZE"
    exit 1
fi
say "=== emmc sha before ==="
NOW=$(sha256sum "${EMMC}p1" | awk '{print $1}')
say "$NOW"
if [ "$NOW" != "$EXPECT" ]; then
    say ABORT_EMMC
    exit 1
fi
say "=== kernel ==="
depthchargectl check "$IMAGE" 2>&1 | tee -a "$LOG"
depthchargectl write --no-prioritize --target /dev/mmcblk0p1 "$IMAGE" 2>&1 | tee -a "$LOG"
sync
blockdev --flushbufs "$SD"
WR=$(dd if=/dev/mmcblk0p1 bs=1 count="$KSIZE" status=none | sha256sum | awk '{print $1}')
IMG=$(sha256sum "$IMAGE" | awk '{print $1}')
say "kernel_image=$IMG"
say "kernel_written=$WR"
if [ "$IMG" != "$WR" ]; then
    say ABORT_KERNEL_MISMATCH
    exit 1
fi
say "=== super ==="
python3 "$DIR/flash-sparse.py" "$SUPER" /dev/mmcblk0p6
sync
blockdev --flushbufs "$SD"
say "=== emmc sha after ==="
AFTER=$(sha256sum "${EMMC}p1" | awk '{print $1}')
say "$AFTER"
if [ "$AFTER" != "$EXPECT" ]; then
    say ABORT_EMMC_CHANGED
    exit 1
fi
say "WRITE_OK /dev/mmcblk0p1 $KSIZE"
