#!/bin/sh
# Put gru-keep in front of Android's init and leave an uncompressed cpio.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
RAMDISK=${1:-/run/media/alpha/YMTC/lineage-23.2/out/target/product/gru/ramdisk.img}
WORKDIR=${2:-/tmp/gru-ramdisk}
KEEP=$ROOT/prebuilt/gru-keep
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/root"
cd "$WORKDIR"
if xz -t "$RAMDISK" 2>/dev/null; then
    xz -dc "$RAMDISK" > ramdisk.cpio
elif gzip -t "$RAMDISK" 2>/dev/null; then
    gzip -dc "$RAMDISK" > ramdisk.cpio
elif lz4 -t "$RAMDISK" 2>/dev/null; then
    lz4 -dc "$RAMDISK" > ramdisk.cpio
else
    cp "$RAMDISK" ramdisk.cpio
fi
cd root
# Device nodes in the ramdisk cannot be created by an unprivileged user.
# The archive is repacked from the files that did extract.
cpio -id < ../ramdisk.cpio || true
if [ ! -f init ]; then
    echo "ramdisk has no init" >&2
    exit 1
fi
mv init init.android
cp "$KEEP" init
cp "$ROOT/prebuilt/watchdog.ko" "$ROOT/prebuilt/dw_wdt.ko" .
cp "$ROOT/prebuilt/6.6.34-phase2/"*.ko \
    "$ROOT/prebuilt/6.6.34-phase2/modules.dep" \
    "$ROOT/prebuilt/6.6.34-phase2/modules.load" \
    lib/modules/6.6.34-phase2/
chmod 755 init init.android
find . -print0 | cpio --null -o -H newc > "$WORKDIR/ramdisk-wrapped.cpio"
echo "$WORKDIR/ramdisk-wrapped.cpio"
