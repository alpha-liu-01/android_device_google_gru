#!/bin/sh
# Read the phase 3 boot log. Does not write the SD or the eMMC.
set -eu
DIR=/home/user/phase3
OUT=$DIR/bootlog-copy.txt
say() { printf '%s\n' "$*" | tee -a "$OUT"; }
: > "$OUT"
if [ "$(id -u)" -ne 0 ]; then
    say ABORT_NOT_ROOT
    exit 1
fi
say "=== identity ==="
say "uname=$(uname -r)"
say "root=$(awk '$2=="/" {print $1; exit}' /proc/mounts)"
say "=== kernel slot ==="
cgpt show /dev/mmcblk0 | tee -a "$OUT"
say "=== emmc sha ==="
sha256sum /dev/mmcblk1p1 | tee -a "$OUT"
say "=== misc ==="
if dd if=/dev/mmcblk0p5 bs=4096 count=1 status=none | grep -a -q GRUDIAG1; then
    dd if=/dev/mmcblk0p5 bs=4096 count=1 status=none | tr '\0' '\n' | tee -a "$OUT"
else
    say MISC_EMPTY
fi
mkdir -p /mnt/gru-bootlog
if mountpoint -q /mnt/gru-bootlog; then
    umount /mnt/gru-bootlog
fi
mount -o ro /dev/mmcblk0p3 /mnt/gru-bootlog
say "=== files ==="
ls -la /mnt/gru-bootlog | tee -a "$OUT"
if [ -f /mnt/gru-bootlog/gru-phase3.log ]; then
    say "=== gru-phase3.log ==="
    wc -c /mnt/gru-bootlog/gru-phase3.log | tee -a "$OUT"
    cat /mnt/gru-bootlog/gru-phase3.log | tee -a "$OUT"
else
    say LOG_MISSING
fi
umount /mnt/gru-bootlog
chmod 644 "$OUT"
say READ_OK
