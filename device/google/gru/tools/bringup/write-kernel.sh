#!/bin/sh
# Replace only the external microSD KERN-A FIT. Does not change the
# partition table, super, userdata, or the internal disk.
# The target is resolved by PARTLABEL and the MMC controller, not by
# mmcblk index or the capacity of a particular card.
set -eu
DIR=${DIR:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
LOG=$DIR/write-kernel.log
IMAGE=$DIR/kernel.kpart
EXPECT=5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a
# Shipped KERN-A is 32 MiB or 64 MiB. Anything larger is not this slot.
KERN_MAX=67108864
SD_CTRL=fe320000.mmc
EMMC_CTRL=fe330000.mmc
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }

disk_name() {
    base=${1##*/}
    case $base in
        mmcblk*p[0-9]*)
            printf '%s\n' "${base%%p[0-9]*}"
            ;;
        mmcblk*)
            printf '%s\n' "$base"
            ;;
        *)
            printf '%s\n' ""
            ;;
    esac
}

controller_of() {
    disk=$(disk_name "$1")
    if [ -z "$disk" ]; then
        printf '%s\n' ""
        return
    fi
    readlink -f "/sys/class/block/$disk/device"
}

run_logged() {
    out=$DIR/write-kernel.step
    if ! "$@" >"$out" 2>&1; then
        cat "$out" | tee -a "$LOG"
        return 1
    fi
    cat "$out" | tee -a "$LOG"
}

say "=== identity ==="
say "uname=$(uname -r)"
ROOT=$(awk '$2=="/" {print $1; exit}' /proc/mounts)
say "root=$ROOT"
if [ "$(id -u)" -ne 0 ]; then
    say ABORT_NOT_ROOT
    exit 1
fi
if [ "$(uname -r)" != 6.6.34 ]; then
    say ABORT_IDENTITY
    exit 1
fi
ROOT_CTRL=$(controller_of "$ROOT")
say "root_ctrl=$ROOT_CTRL"
case $ROOT_CTRL in
    *"$EMMC_CTRL"*) ;;
    *)
        say ABORT_IDENTITY
        exit 1
        ;;
esac

KERN_DEV=$(readlink -f /dev/disk/by-partlabel/KERN-A 2>/dev/null || true)
say "kern=$KERN_DEV"
if [ -z "$KERN_DEV" ]; then
    say ABORT_KERN
    exit 1
fi
KERN_CTRL=$(controller_of "$KERN_DEV")
say "kern_ctrl=$KERN_CTRL"
case $KERN_CTRL in
    *"$SD_CTRL"*) ;;
    *)
        say ABORT_KERN_DISK
        exit 1
        ;;
esac
case $KERN_CTRL in
    *"$EMMC_CTRL"*)
        say ABORT_EMMC_TARGET
        exit 1
        ;;
esac
PMOS_KERN=$(readlink -f /dev/disk/by-partlabel/pmOS_kernel 2>/dev/null || true)
SUPER_DEV=$(readlink -f /dev/disk/by-partlabel/super 2>/dev/null || true)
USERDATA_DEV=$(readlink -f /dev/disk/by-partlabel/userdata 2>/dev/null || true)
if [ -z "$PMOS_KERN" ] || [ "$KERN_DEV" = "$PMOS_KERN" ] \
    || [ "$KERN_DEV" = "$SUPER_DEV" ] || [ "$KERN_DEV" = "$USERDATA_DEV" ]; then
    say ABORT_KERN
    exit 1
fi
if awk -v dev="$KERN_DEV" '$1==dev {found=1} END {exit !found}' /proc/mounts; then
    say ABORT_MOUNTED
    exit 1
fi
if [ ! -f "$IMAGE" ]; then
    say ABORT_FILES
    exit 1
fi
KSIZE=$(stat -c %s "$IMAGE")
PSZ=$(blockdev --getsize64 "$KERN_DEV")
say "image_bytes=$KSIZE"
say "kern_bytes=$PSZ"
if [ "$KSIZE" -le 0 ] || [ "$KSIZE" -gt "$PSZ" ] || [ "$PSZ" -gt "$KERN_MAX" ]; then
    say "ABORT_SIZE $KSIZE $PSZ"
    exit 1
fi

say "pmOS_kernel=$PMOS_KERN"
PMOS_CTRL=$(controller_of "$PMOS_KERN")
case $PMOS_CTRL in
    *"$EMMC_CTRL"*) ;;
    *)
        say ABORT_EMMC
        exit 1
        ;;
esac
say "=== emmc sha before ==="
NOW=$(sha256sum "$PMOS_KERN" | awk '{print $1}')
say "$NOW"
if [ "$NOW" != "$EXPECT" ]; then
    say ABORT_EMMC
    exit 1
fi

say "=== kernel ==="
if ! run_logged depthchargectl check "$IMAGE"; then
    say ABORT_CHECK
    exit 1
fi
if ! run_logged depthchargectl write --no-prioritize --target "$KERN_DEV" "$IMAGE"; then
    say ABORT_WRITE
    exit 1
fi
sync
blockdev --flushbufs "/dev/$(disk_name "$KERN_DEV")"
say "=== emmc sha after ==="
AFTER=$(sha256sum "$PMOS_KERN" | awk '{print $1}')
say "$AFTER"
if [ "$AFTER" != "$EXPECT" ]; then
    say ABORT_EMMC_CHANGED
    exit 1
fi
WR=$(dd if="$KERN_DEV" bs=1 count="$KSIZE" status=none | sha256sum | awk '{print $1}')
IMG=$(sha256sum "$IMAGE" | awk '{print $1}')
say "image=$IMG"
say "written=$WR"
if [ "$IMG" != "$WR" ]; then
    say ABORT_MISMATCH
    exit 1
fi
say "WRITE_OK $KERN_DEV $KSIZE"
