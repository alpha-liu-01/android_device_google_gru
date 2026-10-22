#!/bin/sh
# Write super.img onto the external microSD "super" partition.
# The target is resolved by PARTLABEL and the MMC controller, not by
# mmcblk index. The internal eMMC is only read for the pmOS_kernel checksum.
set -eu
DIR=${DIR:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
LOG=$DIR/write-super.log
SUPER=$DIR/super.img
EXPECT=5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a
SUPER_BYTES=8589934592
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

SUPER_DEV=$(readlink -f /dev/disk/by-partlabel/super 2>/dev/null || true)
USERDATA_DEV=$(readlink -f /dev/disk/by-partlabel/userdata 2>/dev/null || true)
say "super=$SUPER_DEV"
say "userdata=$USERDATA_DEV"
if [ -z "$SUPER_DEV" ] || [ "$SUPER_DEV" = "$USERDATA_DEV" ]; then
    say ABORT_SUPER
    exit 1
fi
SUPER_CTRL=$(controller_of "$SUPER_DEV")
say "super_ctrl=$SUPER_CTRL"
case $SUPER_CTRL in
    *"$SD_CTRL"*) ;;
    *)
        say ABORT_SUPER_DISK
        exit 1
        ;;
esac
case $SUPER_CTRL in
    *"$EMMC_CTRL"*)
        say ABORT_EMMC_TARGET
        exit 1
        ;;
esac
if [ "$(blockdev --getsize64 "$SUPER_DEV")" != "$SUPER_BYTES" ]; then
    say ABORT_SUPER_SIZE
    exit 1
fi
if awk -v dev="$SUPER_DEV" '$1==dev {found=1} END {exit !found}' /proc/mounts; then
    say ABORT_MOUNTED
    exit 1
fi
if [ ! -f "$SUPER" ]; then
    say ABORT_FILES
    exit 1
fi

KERN_DEV=$(readlink -f /dev/disk/by-partlabel/pmOS_kernel 2>/dev/null || true)
say "pmOS_kernel=$KERN_DEV"
KERN_CTRL=$(controller_of "$KERN_DEV")
case $KERN_CTRL in
    *"$EMMC_CTRL"*) ;;
    *)
        say ABORT_EMMC
        exit 1
        ;;
esac
say "=== emmc sha before ==="
NOW=$(sha256sum "$KERN_DEV" | awk '{print $1}')
say "$NOW"
if [ "$NOW" != "$EXPECT" ]; then
    say ABORT_EMMC
    exit 1
fi

say "=== super ==="
python3 "$DIR/flash-sparse.py" "$SUPER" "$SUPER_DEV"
sync
blockdev --flushbufs "/dev/$(disk_name "$SUPER_DEV")"
say "=== emmc sha after ==="
AFTER=$(sha256sum "$KERN_DEV" | awk '{print $1}')
say "$AFTER"
if [ "$AFTER" != "$EXPECT" ]; then
    say ABORT_EMMC_CHANGED
    exit 1
fi
say "WRITE_OK $SUPER_DEV"
