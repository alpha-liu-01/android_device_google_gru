#!/usr/bin/env bash
#
# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# pack_kpart.sh - Build ChromeOS Depthcharge signed FIT image (vmlinuz.kpart)
#                 for Google Gru Chromebooks & Tablets (Scarlet / Kevin / Bob)
#                 entirely on the x86_64 build host.
#

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
BUILD_TOP="${ANDROID_BUILD_TOP:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
PRODUCT_OUT="${PRODUCT_OUT:-$BUILD_TOP/out/target/product/gru}"
HOST_BIN="${HOST_OUT:-$BUILD_TOP/out/host/linux-x86}/bin"
KERNEL_BUILD_TOOLS="$BUILD_TOP/prebuilts/kernel-build-tools/linux-x86/bin"
LINEAGE_TOOLS="$BUILD_TOP/prebuilts/tools-lineage/linux-x86/bin"

PREBUILT_DIR="$DEVICE_DIR/prebuilt/6.6.34-phase2"
KERNEL_IMAGE="$PREBUILT_DIR/vmlinuz"
CMDLINE_FILE="$DEVICE_DIR/cmdline.txt"
RAMDISK_IMG="${RAMDISK_IMG:-$PRODUCT_OUT/ramdisk.img}"
OUTPUT_KPART="${1:-$PRODUCT_OUT/vmlinuz.kpart}"

# Locate required host tools
MKIMAGE="${MKIMAGE:-$LINEAGE_TOOLS/mkimage}"
DTC="${DTC:-$KERNEL_BUILD_TOOLS/dtc}"
FUTILITY="${FUTILITY:-$HOST_BIN/futility-host}"
DEVKEYS_DIR="${DEVKEYS_DIR:-$BUILD_TOP/external/vboot_reference/tests/devkeys}"

for tool in "$MKIMAGE" "$DTC" "$FUTILITY"; do
    if [ ! -x "$tool" ]; then
        echo "ERROR: Required host tool not found or not executable: $tool" >&2
        echo "       If futility-host is missing, run: m futility-host" >&2
        exit 1
    fi
done

for f in "$KERNEL_IMAGE" "$CMDLINE_FILE" "$RAMDISK_IMG" \
         "$DEVKEYS_DIR/kernel.keyblock" "$DEVKEYS_DIR/kernel_data_key.vbprivk"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Required input file missing: $f" >&2
        exit 1
    fi
done

DTBS=(
    "rk3399-gru-scarlet-kd"
    "rk3399-gru-scarlet-inx"
    "rk3399-gru-scarlet-dumo"
    "rk3399-gru-kevin"
    "rk3399-gru-bob"
)

for dtb in "${DTBS[@]}"; do
    if [ ! -f "$PREBUILT_DIR/${dtb}.dtb" ]; then
        echo "ERROR: Required DTB missing: $PREBUILT_DIR/${dtb}.dtb" >&2
        exit 1
    fi
done

# A libcomposite.ko that creates /sys/class/android_usb makes system_server
# wait forever for the (never started) USB gadget HAL; the UI never draws.
if grep -q -a android_usb "$PREBUILT_DIR"/*.ko; then
    echo "ERROR: $(grep -l -a android_usb "$PREBUILT_DIR"/*.ko | tr '\n' ' ')contain android_usb." >&2
    echo "       Restore the original modules from the kernel modules_install tree." >&2
    exit 1
fi

WORKDIR="$(mktemp -d /tmp/gru-kpart.XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "=== [1/4] Wrapping Android ramdisk with gru-keep and 6.6.34-phase2 modules ==="
WRAPPED_CPIO="$("$DEVICE_DIR/wrap-ramdisk.sh" "$RAMDISK_IMG" "$WORKDIR/ramdisk")"
cp "$WRAPPED_CPIO" "$WORKDIR/ramdisk.cpio"

echo "=== [2/4] Compressing kernel Image with LZMA ==="
lzma -9 -z -k -c "$KERNEL_IMAGE" > "$WORKDIR/vmlinuz.lzma"

for dtb in "${DTBS[@]}"; do
    cp "$PREBUILT_DIR/${dtb}.dtb" "$WORKDIR/${dtb}.dtb"
done

echo "=== [3/4] Assembling Flattened Image Tree (FIT) with 5 Gru DTBs ==="
cat > "$WORKDIR/kernel.its" << 'EOF'
/dts-v1/;

/ {
    description = "LineageOS 23.2 Kernel FIT Image for Google Gru (Scarlet/Kevin/Bob)";
    #address-cells = <1>;

    images {
        kernel-1 {
            description = "Linux 6.6.34-phase2 arm64";
            data = /incbin/("vmlinuz.lzma");
            type = "kernel_noload";
            arch = "arm64";
            os = "linux";
            compression = "lzma";
            load = <0>;
            entry = <0>;
            hash-1 {
                algo = "crc32";
            };
        };

        fdt-1 {
            description = "rk3399-gru-scarlet-kd";
            data = /incbin/("rk3399-gru-scarlet-kd.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };

        fdt-2 {
            description = "rk3399-gru-scarlet-inx";
            data = /incbin/("rk3399-gru-scarlet-inx.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };

        fdt-3 {
            description = "rk3399-gru-scarlet-dumo";
            data = /incbin/("rk3399-gru-scarlet-dumo.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };

        fdt-4 {
            description = "rk3399-gru-kevin";
            data = /incbin/("rk3399-gru-kevin.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };

        fdt-5 {
            description = "rk3399-gru-bob";
            data = /incbin/("rk3399-gru-bob.dtb");
            type = "flat_dt";
            arch = "arm64";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };

        ramdisk-1 {
            description = "LineageOS 23.2 ramdisk with gru-keep";
            data = /incbin/("ramdisk.cpio");
            type = "ramdisk";
            arch = "arm64";
            os = "linux";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };
    };

    configurations {
        default = "conf-1";

        conf-1 {
            description = "rk3399-gru-scarlet-kd";
            kernel = "kernel-1";
            loadables = "kernel-1";
            fdt = "fdt-1";
            ramdisk = "ramdisk-1";
        };

        conf-2 {
            description = "rk3399-gru-scarlet-inx";
            kernel = "kernel-1";
            loadables = "kernel-1";
            fdt = "fdt-2";
            ramdisk = "ramdisk-1";
        };

        conf-3 {
            description = "rk3399-gru-scarlet-dumo";
            kernel = "kernel-1";
            loadables = "kernel-1";
            fdt = "fdt-3";
            ramdisk = "ramdisk-1";
        };

        conf-4 {
            description = "rk3399-gru-kevin";
            kernel = "kernel-1";
            loadables = "kernel-1";
            fdt = "fdt-4";
            ramdisk = "ramdisk-1";
        };

        conf-5 {
            description = "rk3399-gru-bob";
            kernel = "kernel-1";
            loadables = "kernel-1";
            fdt = "fdt-5";
            ramdisk = "ramdisk-1";
        };
    };
};
EOF

(
    cd "$WORKDIR"
    PATH="$(dirname "$DTC"):$PATH" "$MKIMAGE" \
        -D "-I dts -O dtb -p 2048" \
        -f kernel.its \
        image.itb >/dev/null
)

echo "=== [4/4] Signing ChromeOS vboot kernel partition (vmlinuz.kpart) ==="
RAW_CMDLINE="$(tr -d '\r\n' < "$CMDLINE_FILE")"
case "$RAW_CMDLINE" in
    kern_guid=%U*)
         FINAL_CMDLINE="$RAW_CMDLINE"
        ;;
    *)
        FINAL_CMDLINE="kern_guid=%U $RAW_CMDLINE"
        ;;
esac
printf '%s\n' "$FINAL_CMDLINE" > "$WORKDIR/cmdline.txt"

dd if=/dev/zero of="$WORKDIR/bootloader.bin" bs=4096 count=1 status=none

mkdir -p "$(dirname "$OUTPUT_KPART")"
"$FUTILITY" vbutil_kernel \
    --pack "$OUTPUT_KPART" \
    --keyblock "$DEVKEYS_DIR/kernel.keyblock" \
    --signprivate "$DEVKEYS_DIR/kernel_data_key.vbprivk" \
    --version 1 \
    --config "$WORKDIR/cmdline.txt" \
    --bootloader "$WORKDIR/bootloader.bin" \
    --vmlinuz "$WORKDIR/image.itb" \
    --arch arm

"$FUTILITY" vbutil_kernel --verify "$OUTPUT_KPART" >/dev/null

KPART_SIZE="$(stat -c %s "$OUTPUT_KPART")"
KPART_SHA="$(sha256sum "$OUTPUT_KPART" | awk '{print $1}')"
echo "SUCCESS: $OUTPUT_KPART"
echo "  Size   : $KPART_SIZE bytes ($(( KPART_SIZE / 1024 / 1024 )) MiB)"
echo "  SHA256 : $KPART_SHA"
echo "  Cmdline: $FINAL_CMDLINE"
