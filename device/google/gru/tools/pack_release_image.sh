#!/usr/bin/env bash
#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# pack_release_image.sh - Assemble a complete bootable GPT microSD/USB disk image
#                         and .zip release archive for Google Gru (Scarlet/Kevin/Bob),
#                         ready to flash with BalenaEtcher, Rufus, or dd.
#

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
BUILD_TOP="${ANDROID_BUILD_TOP:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
PRODUCT_OUT="${PRODUCT_OUT:-$BUILD_TOP/out/target/product/gru}"
HOST_BIN="${HOST_OUT:-$BUILD_TOP/out/host/linux-x86}/bin"

DATE_TAG="${DATE_TAG:-$(date +%Y%m%d)}"
IMG_BASENAME="${IMG_BASENAME:-lineage-23.2-gru-${DATE_TAG}}"
OUTPUT_DIR="${1:-$PRODUCT_OUT}"
RAW_IMG="$OUTPUT_DIR/${IMG_BASENAME}.img"
ZIP_OUT="$OUTPUT_DIR/${IMG_BASENAME}.zip"
SHA_OUT="${ZIP_OUT}.sha256"

# Locate host tools from the LineageOS build tree
SGDISK="${SGDISK:-$HOST_BIN/sgdisk}"
SIMG2IMG="${SIMG2IMG:-$HOST_BIN/simg2img}"
MKE2FS="${MKE2FS:-$HOST_BIN/mke2fs}"
MAKE_F2FS="${MAKE_F2FS:-$HOST_BIN/make_f2fs}"
FSCK_F2FS="${FSCK_F2FS:-$HOST_BIN/fsck.f2fs}"

for tool in "$SGDISK" "$SIMG2IMG" "$MKE2FS" "$MAKE_F2FS"; do
    if [ ! -x "$tool" ]; then
        echo "ERROR: Required host tool not found or not executable: $tool" >&2
        exit 1
    fi
done

SUPER_SPARSE="$PRODUCT_OUT/super.img"
if [ ! -f "$SUPER_SPARSE" ]; then
    echo "ERROR: Missing $SUPER_SPARSE. Build Android first." >&2
    exit 1
fi

KPART_IMG="$PRODUCT_OUT/vmlinuz.kpart"
echo "=== [1/6] Building signed Depthcharge FIT kernel image (vmlinuz.kpart) ==="
"$TOOLS_DIR/pack_kpart.sh" "$KPART_IMG"

WORKDIR="$(mktemp -d "$OUTPUT_DIR/gru-release-work.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

echo "=== [2/6] Unsparsing super.img and formatting partition images ==="
SUPER_RAW="$WORKDIR/super.raw.img"
"$SIMG2IMG" "$SUPER_SPARSE" "$SUPER_RAW"
SUPER_BYTES="$(stat -c %s "$SUPER_RAW")"
if [ "$SUPER_BYTES" -ne 8589934592 ]; then
    echo "ERROR: Unexpected unsparsed super.img size: $SUPER_BYTES (expected 8589934592)" >&2
    exit 1
fi

# Partition geometry (512-byte sectors, 4 MiB / 8192-sector aligned)
# Total image size: 10.5 GiB = 11,274,289,152 bytes = 22,020,096 sectors
TOTAL_SECTORS=22020096
TOTAL_BYTES=$(( TOTAL_SECTORS * 512 ))

P1_START=8192       ; P1_SECTORS=131072    # KERN-A   :   64 MiB
P2_START=139264     ; P2_SECTORS=32768     # bootlog  :   16 MiB
P3_START=172032     ; P3_SECTORS=32768     # metadata :   16 MiB
P4_START=204800     ; P4_SECTORS=16384     # misc     :    8 MiB
P5_START=221184     ; P5_SECTORS=16777216  # super    : 8192 MiB (8 GiB)
P6_START=16998400   ; P6_SECTORS=5017600   # userdata : 2450 MiB (~2.39 GiB, 4 MiB aligned)
P6_END=$(( P6_START + P6_SECTORS - 1 ))    # 22015999 (leaves 4096 sectors at tail for backup GPT)

# Format bootlog.img (16 MiB ext4)
BOOTLOG_IMG="$WORKDIR/bootlog.img"
truncate -s $(( P2_SECTORS * 512 )) "$BOOTLOG_IMG"
"$MKE2FS" -q -F -t ext4 -b 4096 -L bootlog "$BOOTLOG_IMG"

# Format metadata.img (16 MiB ext4)
METADATA_IMG="$WORKDIR/metadata.img"
truncate -s $(( P3_SECTORS * 512 )) "$METADATA_IMG"
"$MKE2FS" -q -F -t ext4 -b 4096 -L metadata "$METADATA_IMG"

# Format userdata.img (2450 MiB f2fs, auto-expanded to full SD card on first boot)
USERDATA_IMG="$WORKDIR/userdata.img"
truncate -s $(( P6_SECTORS * 512 )) "$USERDATA_IMG"
"$MAKE_F2FS" -q -f -g android \
    -O encrypt,extra_attr,project_quota,quota,verity,compression \
    -l userdata \
    "$USERDATA_IMG" >/dev/null

if [ -x "$FSCK_F2FS" ]; then
    "$FSCK_F2FS" -f "$USERDATA_IMG" >/dev/null
fi

echo "=== [3/6] Creating 10.5 GiB GPT disk image and ChromeOS kernel attributes ==="
rm -f "$RAW_IMG"
truncate -s "$TOTAL_BYTES" "$RAW_IMG"

# ChromeOS kernel type GUID: FE3A2A5D-4F32-41A7-B725-ACCC3285A309 (sgdisk type 7f00)
# Linux filesystem data GUID: 0FC63DAF-8483-4772-8E79-3D69D8477DE4 (sgdisk type 8300)
# ChromeOS kernel attributes for priority=15, tries=15, successful=1:
#   bit 56 (successful=1), bits 52..55 (tries=15), bits 48..51 (priority=15)
"$SGDISK" --clear \
    --set-alignment=8192 \
    --new="1:${P1_START}:$(( P1_START + P1_SECTORS - 1 ))" \
        --typecode="1:FE3A2A5D-4F32-41A7-B725-ACCC3285A309" \
        --change-name="1:KERN-A" \
        --attributes="1:=:0x01ff000000000000" \
    --new="2:${P2_START}:$(( P2_START + P2_SECTORS - 1 ))" \
        --typecode="2:8300" \
        --change-name="2:bootlog" \
    --new="3:${P3_START}:$(( P3_START + P3_SECTORS - 1 ))" \
        --typecode="3:8300" \
        --change-name="3:metadata" \
    --new="4:${P4_START}:$(( P4_START + P4_SECTORS - 1 ))" \
        --typecode="4:8300" \
        --change-name="4:misc" \
    --new="5:${P5_START}:$(( P5_START + P5_SECTORS - 1 ))" \
        --typecode="5:8300" \
        --change-name="5:super" \
    --new="6:${P6_START}:${P6_END}" \
        --typecode="6:8300" \
        --change-name="6:userdata" \
    "$RAW_IMG" >/dev/null

echo "=== [4/6] Writing partition payloads into $RAW_IMG ==="
# Write payloads using 1 MiB block size where aligned (all start sectors are multiples of 2048 = 1 MiB)
dd if="$KPART_IMG"    of="$RAW_IMG" bs=1048576 seek=$(( P1_START / 2048 )) conv=notrunc status=none
dd if="$BOOTLOG_IMG"  of="$RAW_IMG" bs=1048576 seek=$(( P2_START / 2048 )) conv=notrunc status=none
dd if="$METADATA_IMG" of="$RAW_IMG" bs=1048576 seek=$(( P3_START / 2048 )) conv=notrunc status=none
dd if="$SUPER_RAW"    of="$RAW_IMG" bs=1048576 seek=$(( P5_START / 2048 )) conv=notrunc status=none
dd if="$USERDATA_IMG" of="$RAW_IMG" bs=1048576 seek=$(( P6_START / 2048 )) conv=notrunc status=none

echo "=== [5/6] Verifying GPT partition table ==="
"$SGDISK" --verify "$RAW_IMG"
"$SGDISK" --print "$RAW_IMG"
"$SGDISK" --info=1 "$RAW_IMG"

echo "=== [6/6] Compressing release archive ($ZIP_OUT) ==="
rm -f "$ZIP_OUT" "$SHA_OUT"
(
    cd "$OUTPUT_DIR"
    zip -6 "$(basename "$ZIP_OUT")" "$(basename "$RAW_IMG")"
    sha256sum "$(basename "$ZIP_OUT")" > "$(basename "$SHA_OUT")"
)

ZIP_SIZE="$(stat -c %s "$ZIP_OUT")"
ZIP_SHA="$(cat "$SHA_OUT")"
echo "=================================================================="
echo "Release build complete!"
echo "  Raw Disk Image : $RAW_IMG ($TOTAL_BYTES bytes / 10.5 GiB)"
echo "  Release Archive: $ZIP_OUT ($ZIP_SIZE bytes / $(( ZIP_SIZE / 1024 / 1024 )) MiB)"
echo "  SHA256         : $ZIP_SHA"
echo "=================================================================="
