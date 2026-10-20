#!/system/bin/sh
# Filtered log of the system_server death. One copy stays on userdata.
# The other is one kmsg line at a time so gru-keep can store it.
while IFS= read -r sline; do
    printf 'GRU_SWAP %s\n' "$sline" > /dev/kmsg || true
done < /proc/swaps
for p in /sys/devices/system/cpu/cpufreq/policy* /sys/class/devfreq/*; do
    [ -e "$p" ] || continue
    cur=$(cat "$p/scaling_cur_freq" "$p/cur_freq" 2>/dev/null | head -n 1)
    max=$(cat "$p/scaling_max_freq" "$p/max_freq" 2>/dev/null | head -n 1)
    gov=$(cat "$p/scaling_governor" "$p/governor" 2>/dev/null | head -n 1)
    printf 'GRU_FREQ %s cur=%s max=%s gov=%s\n' "$p" "$cur" "$max" "$gov" > /dev/kmsg || true
done
for iio in /sys/bus/iio/devices/iio:device*; do
    [ -e "$iio" ] || continue
    iname=$(cat "$iio/name" 2>/dev/null)
    ien=$(cat "$iio/buffer/enable" 2>/dev/null)
    ifreq=$(cat "$iio/sampling_frequency" 2>/dev/null)
    printf 'GRU_IIO %s name=%s enable=%s freq=%s\n' "$iio" "$iname" "$ien" "$ifreq" > /dev/kmsg || true
done
grep -E '^(I:|N:|H:|B: PROP=)' /proc/bus/input/devices 2>/dev/null | while IFS= read -r iline; do
    printf 'GRU_INPUT %s\n' "$iline" > /dev/kmsg || true
done
logcat -b crash -b system -b main -f /data/gru-logcat.txt -r 2048 -n 2 \
    Zygote:I AndroidRuntime:E SystemServer:E Watchdog:E ActivityManager:E DEBUG:F libc:F drmhwc:I SurfaceFlinger:I RenderEngine:I libEGL:I minigbm:I GoogleIIOSensorSubHal:I EventHub:I InputReader:I '*:S' &
logcat -b crash -b system -b main \
    Zygote:I AndroidRuntime:E SystemServer:E Watchdog:E ActivityManager:E DEBUG:F libc:F drmhwc:I SurfaceFlinger:I RenderEngine:I libEGL:I minigbm:I GoogleIIOSensorSubHal:I EventHub:I InputReader:I '*:S' |
while IFS= read -r line; do
    printf 'GRU_LOG %s\n' "$line" > /dev/kmsg || true
done
