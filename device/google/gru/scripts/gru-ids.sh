#!/system/bin/sh
# Depthcharge does not put androidboot.serialno on the command line.
# The serial is in the read-only VPD. coreboot_table and vpd are built in,
# so the node exists before post-fs. An unset ro.serialno can still be set
# once. This runs as gru_ids, which can read that one node. The rest of
# the VPD, including the device secret, stays unlabeled sysfs.
VPD=/sys/firmware/vpd/ro/serial_number
if [ -r "$VPD" ]; then
    serial=$(tr -cd 'A-Za-z0-9-' < "$VPD")
    # ro.serialno can be set once. A later boot leaves the value alone.
    [ -n "$serial" ] && setprop ro.serialno "$serial"
fi
exit 0
