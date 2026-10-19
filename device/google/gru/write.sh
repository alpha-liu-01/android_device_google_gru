#!/bin/sh
# Write the phase 3 Android image to the SD card only.
set -eu
set -o pipefail
DIR=/home/user/phase3
LOG=$DIR/write.log
IMAGE=$DIR/kernel.kpart
SUPER=$DIR/super.img
SD=/dev/mmcblk0
EMMC=/dev/mmcblk1
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }
run() { "$@" 2>&1 | tee -a "$LOG"; }

say "=== identity ==="
run uname -r
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
if [ ! -f "$IMAGE" ] || [ ! -f "$SUPER" ] || [ ! -f "$DIR/flash-sparse.py" ]; then
    say ABORT_FILES
    exit 1
fi
KSIZE=$(stat -c %s "$IMAGE")
SSIZE=$(stat -c %s "$SUPER")
say "kpart=$KSIZE super=$SSIZE"
if [ "$KSIZE" -gt 33554432 ] || [ "$SSIZE" != 1273803184 ]; then
    say ABORT_SIZE
    exit 1
fi
SUPER_SHA=$(sha256sum "$SUPER" | awk '{print $1}')
say "super_sha=$SUPER_SHA"
if [ "$SUPER_SHA" != b112c4f599e4c09309766066d97e704effe3f792ce557b80aac4fdf5a2dc2a46 ]; then
    say ABORT_SUPER_SHA
    exit 1
fi

say "=== cgpt before ==="
cgpt show "$SD" | tee "$DIR/cgpt-sd-before.txt" | tee -a "$LOG"
say "--- emmc ---"
cgpt show "$EMMC" | tee "$DIR/cgpt-emmc-before.txt" | tee -a "$LOG"
say "=== emmc sha before ==="
sha256sum "${EMMC}p1" | tee "$DIR/emmc-before.sha256" | tee -a "$LOG"
BEFORE=$(awk '{print $1}' "$DIR/emmc-before.sha256")
if [ "$BEFORE" != 5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a ]; then
    say ABORT_EMMC_BEFORE
    exit 1
fi

say "=== repartition sd ==="
# Shrink partition 3 before moving partition 4, so the entries never overlap.
cgpt add -i 3 -b 139264 -s 131072 -t data -l bootlog "$SD"
cgpt add -i 4 -b 270336 -s 131072 -t data -l metadata "$SD"
cgpt add -i 5 -b 401408 -s 16384 -t data -l misc "$SD"
cgpt add -i 6 -b 417792 -s 16777216 -t data -l super "$SD"
cgpt add -i 7 -b 17195008 -s 104970240 -t data -l userdata "$SD"
partprobe "$SD" || blockdev --rereadpt "$SD"
sleep 1
cgpt show "$SD" | tee "$DIR/cgpt-sd-after.txt" | tee -a "$LOG"

python3 - << 'PY' | tee -a "$LOG"
import re, sys
text = open("/home/user/phase3/cgpt-sd-after.txt").read()
want = {
    1: (8192, 65536, "KernelA", "priority=10"),
    2: (73728, 65536, "KernelB", "priority=0"),
    3: (139264, 131072, "bootlog", None),
    4: (270336, 131072, "metadata", None),
    5: (401408, 16384, "misc", None),
    6: (417792, 16777216, "super", None),
    7: (17195008, 104970240, "userdata", None),
}
pat = re.compile(
    r"^\s+(\d+)\s+(\d+)\s+(\d+)\s+Label: \"(.*)\"\n"
    r"\s+Type: .*\n"
    r"\s+UUID: .*\n"
    r"(?:\s+Attr: ([^\n]*))?",
    re.M,
)
found = {}
for m in pat.finditer(text):
    start, size, num, label, attr = m.groups()
    found[int(num)] = (int(start), int(size), label, attr or "")
if set(found) != set(want):
    print("ABORT_GPT", sorted(found))
    sys.exit(2)
for num, (start, size, label, attr) in want.items():
    got = found[num]
    if got[0] != start or got[1] != size or got[2] != label:
        print("ABORT_GPT", num, got)
        sys.exit(2)
    if attr is not None and attr not in got[3]:
        print("ABORT_ATTR", num, got[3])
        sys.exit(2)
print("GPT_OK")
PY

check_size() {
    got=$(blockdev --getsize64 "$1")
    if [ "$got" != "$2" ]; then
        say "ABORT_PART $1 $got $2"
        exit 1
    fi
}
check_size /dev/mmcblk0p1 33554432
check_size /dev/mmcblk0p2 33554432
check_size /dev/mmcblk0p3 67108864
check_size /dev/mmcblk0p4 67108864
check_size /dev/mmcblk0p5 8388608
check_size /dev/mmcblk0p6 8589934592
check_size /dev/mmcblk0p7 53744762880

say "=== format ==="
mkfs.ext4 -F -L bootlog /dev/mmcblk0p3
mkfs.ext4 -F -L metadata /dev/mmcblk0p4
dd if=/dev/zero of=/dev/mmcblk0p5 bs=1048576 count=8 status=none
python3 "$DIR/flash-sparse.py" "$SUPER" /dev/mmcblk0p6
mkfs.f2fs -f -l userdata /dev/mmcblk0p7

say "=== kernel ==="
run depthchargectl check "$IMAGE"
run depthchargectl write --no-prioritize --target /dev/mmcblk0p1 "$IMAGE"
sync
blockdev --flushbufs "$SD"

say "=== emmc sha after ==="
sha256sum "${EMMC}p1" | tee "$DIR/emmc-after.sha256" | tee -a "$LOG"
cgpt show "$EMMC" | tee "$DIR/cgpt-emmc-after.txt" >/dev/null
cmp "$DIR/emmc-before.sha256" "$DIR/emmc-after.sha256"
cmp "$DIR/cgpt-emmc-before.txt" "$DIR/cgpt-emmc-after.txt"
dd if=/dev/mmcblk0p1 bs=4096 count=$((KSIZE / 4096)) status=none | sha256sum | tee "$DIR/written.sha256" | tee -a "$LOG"
sha256sum "$IMAGE" | tee "$DIR/image.sha256" | tee -a "$LOG"
IMG=$(awk '{print $1}' "$DIR/image.sha256")
WR=$(awk '{print $1}' "$DIR/written.sha256")
if [ "$IMG" != "$WR" ]; then
    say ABORT_MISMATCH
    exit 1
fi
say "WRITE_OK /dev/mmcblk0p1 $KSIZE"
