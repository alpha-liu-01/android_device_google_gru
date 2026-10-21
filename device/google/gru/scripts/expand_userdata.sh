#!/system/bin/sh
#
# Userdata partition & F2FS expander for Google Gru (rk3399-gru-scarlet).
# Expands the userdata partition on the external microSD card (fe320000.mmc)
# to claim 100% of the drive capacity on first boot.
# Never touches the internal eMMC (fe330000.sdhci).
#

LOG_FILE="/metadata/expand_userdata.log"
exec >> "$LOG_FILE" 2>&1

log() {
    echo "[expand_userdata] $*"
    echo "[expand_userdata] $*" > /dev/kmsg 2>/dev/null || true
}

log "Started at $(date)"

# 1. Resolve the userdata block device from /dev/block/by-name/userdata
USERDATA_DEV=""
for i in 1 2 3 4 5; do
    USERDATA_DEV=$(readlink -f /dev/block/by-name/userdata 2>/dev/null)
    if [ -n "$USERDATA_DEV" ] && [ -b "$USERDATA_DEV" ]; then
        break
    fi
    sleep 0.5
done

# Fallback: derive from mounted /metadata on the same boot disk
if [ -z "$USERDATA_DEV" ] || [ ! -b "$USERDATA_DEV" ]; then
    META_DEV=$(grep -w "/metadata" /proc/mounts 2>/dev/null | awk '{print $1}')
    if [ -n "$META_DEV" ] && [ -b "$META_DEV" ]; then
        META_BASE=$(basename "$META_DEV")
        case "$META_BASE" in
            mmcblk*p*)
                DISK_PREFIX="/dev/block/${META_BASE%p*}"
                for p in "${DISK_PREFIX}p6" "${DISK_PREFIX}p7"; do
                    if [ -b "$p" ]; then
                        USERDATA_DEV="$p"
                        break
                    fi
                done
                ;;
        esac
    fi
fi

if [ -z "$USERDATA_DEV" ] || [ ! -b "$USERDATA_DEV" ]; then
    log "ERROR: Userdata block device not found. Aborting."
    exit 1
fi

DEV_BASE=$(basename "$USERDATA_DEV")
DISK=""
PART=""
case "$DEV_BASE" in
    mmcblk*p*|nvme*p*)
        DISK="/dev/block/${DEV_BASE%p*}"
        PART="${DEV_BASE##*p}"
        ;;
    sd[a-z][0-9]*)
        DISK="/dev/block/$(echo "$DEV_BASE" | sed -E 's/[0-9]+$//')"
        PART=$(echo "$DEV_BASE" | grep -oE '[0-9]+$')
        ;;
    *)
        log "ERROR: Unrecognized block device naming '$DEV_BASE'. Aborting."
        exit 1
        ;;
esac

DISK_NAME=$(basename "$DISK")
SYSFS_DISK_PATH=$(readlink -f "/sys/class/block/${DISK_NAME}" 2>/dev/null)

log "Detected DISK=$DISK ($SYSFS_DISK_PATH), PART=$PART, USERDATA_DEV=$USERDATA_DEV"

# 2. Strict hardware safety guard: never touch internal eMMC (fe330000.sdhci)
case "$SYSFS_DISK_PATH" in
    *fe330000.sdhci*)
        log "SAFETY ABORT: $DISK is internal eMMC ($SYSFS_DISK_PATH). Refusing to modify."
        exit 1
        ;;
    *fe320000.mmc*)
        log "Verified external microSD controller (fe320000.mmc)."
        ;;
    *)
        log "WARNING: Controller path '$SYSFS_DISK_PATH' is not fe320000.mmc. Aborting for safety."
        exit 1
        ;;
esac

CURR_PART_SECTORS=$(cat "/sys/class/block/${DEV_BASE}/size" 2>/dev/null)
TOTAL_DISK_SECTORS=$(cat "/sys/class/block/${DISK_NAME}/size" 2>/dev/null)
START_SECTOR=$(cat "/sys/class/block/${DEV_BASE}/start" 2>/dev/null)

log "CURR_PART_SECTORS=$CURR_PART_SECTORS, TOTAL_DISK_SECTORS=$TOTAL_DISK_SECTORS, START_SECTOR=$START_SECTOR"

if [ -z "$CURR_PART_SECTORS" ] || [ -z "$TOTAL_DISK_SECTORS" ] || [ -z "$START_SECTOR" ]; then
    log "ERROR: Unable to read partition geometry from sysfs. Aborting."
    exit 1
fi

# 3. Check if userdata already occupies the disk (within 16 MiB / 32768 sectors margin)
TARGET_MIN_SECTORS=$(( TOTAL_DISK_SECTORS - START_SECTOR - 32768 ))
if [ "$CURR_PART_SECTORS" -ge "$TARGET_MIN_SECTORS" ]; then
    log "Userdata is already expanded ($CURR_PART_SECTORS sectors >= $TARGET_MIN_SECTORS). Nothing to do."
    exit 0
fi

log "Expanding userdata from $CURR_PART_SECTORS sectors to fill disk ($TOTAL_DISK_SECTORS total sectors)..."

# 4. If /data was already mounted in first_stage_mount, unmount it temporarily
#    before early_hal / post-fs-data so resize.f2fs can run cleanly.
WAS_MOUNTED=0
MOUNT_OPTS=""
if grep -qw "/data" /proc/mounts 2>/dev/null; then
    WAS_MOUNTED=1
    MOUNT_OPTS=$(awk '$2 == "/data" {print $4; exit}' /proc/mounts)
    log "/data is currently mounted (opts=$MOUNT_OPTS); unmounting for offline resize.f2fs..."
    if ! /system/bin/umount /data 2>/dev/null; then
        log "Standard umount /data busy; trying lazy detach Not recommended, aborting resize."
        exit 1
    fi
    log "Successfully unmounted /data."
fi

# 5. Relocate secondary GPT header to the physical end of the SD card
log "Running sgdisk --move-second-header $DISK..."
/system/bin/sgdisk --move-second-header "$DISK"

# 6. Read PARTUUID to preserve it across partition recreation
PARTUUID=$(/system/bin/sgdisk --info="$PART" "$DISK" 2>/dev/null | grep -i "Partition unique GUID" | awk '{print $NF}')
log "Preserving PARTUUID=$PARTUUID"

# 7. Recreate userdata partition extending to the end of the disk
log "Recreating partition $PART: start=$START_SECTOR, end=0..."
if [ -n "$PARTUUID" ]; then
    /system/bin/sgdisk --delete="$PART" --new="${PART}:${START_SECTOR}:0" --partition-guid="${PART}:${PARTUUID}" --change-name="${PART}:userdata" "$DISK"
else
    /system/bin/sgdisk --delete="$PART" --new="${PART}:${START_SECTOR}:0" --change-name="${PART}:userdata" "$DISK"
fi

# 8. Determine new sector count and update live kernel partition table via BLKPG_RESIZE_PARTITION
END_SECTOR=$(/system/bin/sgdisk --info="$PART" "$DISK" 2>/dev/null | grep -i "Last sector" | awk '{print $3}')
log "New GPT partition $PART end sector: $END_SECTOR"

if [ -n "$END_SECTOR" ] && [ "$END_SECTOR" -gt "$START_SECTOR" ]; then
    NEW_SECTORS=$(( END_SECTOR - START_SECTOR + 1 ))
    START_BYTES=$(( START_SECTOR * 512 ))
    LENGTH_BYTES=$(( NEW_SECTORS * 512 ))

    if [ -x /vendor/bin/blkpg_resize ]; then
        log "Calling /vendor/bin/blkpg_resize $DISK $PART $START_BYTES $LENGTH_BYTES..."
        /vendor/bin/blkpg_resize "$DISK" "$PART" "$START_BYTES" "$LENGTH_BYTES"
    else
        log "ERROR: /vendor/bin/blkpg_resize not found or not executable!"
    fi
fi

# 9. Resize F2FS filesystem offline while unmounted
sleep 0.5
log "Resizing F2FS filesystem on $USERDATA_DEV..."
if [ -x /system/bin/resize.f2fs ]; then
    /system/bin/resize.f2fs "$USERDATA_DEV"
elif [ -x /system/bin/resize2fs ]; then
    /system/bin/resize2fs "$USERDATA_DEV"
fi

# 10. Remount /data if it was mounted before expansion
if [ "$WAS_MOUNTED" -eq 1 ]; then
    log "Remounting $USERDATA_DEV on /data..."
    if [ -n "$MOUNT_OPTS" ]; then
        /system/bin/mount -t f2fs -o "$MOUNT_OPTS" "$USERDATA_DEV" /data
    else
        /system/bin/mount -t f2fs "$USERDATA_DEV" /data
    fi
    log "Remount /data status: $?"
fi

log "Userdata expansion complete at $(date)."
exit 0
