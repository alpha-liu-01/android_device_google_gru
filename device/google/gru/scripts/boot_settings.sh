#!/system/bin/sh
# 86400000 ms is 24 hours. The Display timeout list stops at 30 minutes, so
# that value shows up as unset. 60000 ms is the platform default.
v=$(/system/bin/settings get system screen_off_timeout)
if [ "$v" = "86400000" ]; then
    /system/bin/settings put system screen_off_timeout 60000
fi
