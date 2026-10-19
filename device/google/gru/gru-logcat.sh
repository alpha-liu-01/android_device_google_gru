#!/system/bin/sh
# Filtered log of the system_server death. One copy stays on userdata.
# The other is one kmsg line at a time so gru-keep can store it.
logcat -b crash -b system -b main -f /data/gru-logcat.txt -r 2048 -n 2 \
    Zygote:I AndroidRuntime:E SystemServer:E Watchdog:E ActivityManager:E DEBUG:F libc:F drmhwc:I SurfaceFlinger:E '*:S' &
logcat -b crash -b system -b main \
    Zygote:I AndroidRuntime:E SystemServer:E Watchdog:E ActivityManager:E DEBUG:F libc:F drmhwc:I SurfaceFlinger:E '*:S' |
while IFS= read -r line; do
    printf 'GRU_LOG %s\n' "$line" > /dev/kmsg || true
done
