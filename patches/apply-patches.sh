#!/usr/bin/env bash
# Synchronizes device/google/gru into a LineageOS 23.2 source tree and applies
# all required LineageOS (and optionally Linux 6.6.34 kernel) patches.
#
# Usage:
#   ./patches/apply-patches.sh /path/to/lineage-23.2 [/path/to/linux-6.6.34]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_DIR="${REPO_ROOT}/patches"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <lineage-23.2-root> [linux-6.6.34-root]" >&2
    exit 1
fi

LINEAGE_ROOT="$(cd "$1" && pwd)"
KERNEL_ROOT="${2:-}"

echo "=== Installing local_manifests/gru.xml ==="
mkdir -p "${LINEAGE_ROOT}/.repo/local_manifests"
cp -v "${REPO_ROOT}/local_manifests/gru.xml" "${LINEAGE_ROOT}/.repo/local_manifests/gru.xml"

# Remove external/drm_hwcomposer-upstream Android.bp if a legacy manifest fetched it.
if [[ -f "${LINEAGE_ROOT}/external/drm_hwcomposer-upstream/Android.bp" ]]; then
    echo "Disabling duplicate external/drm_hwcomposer-upstream/Android.bp..."
    mv "${LINEAGE_ROOT}/external/drm_hwcomposer-upstream/Android.bp" \
       "${LINEAGE_ROOT}/external/drm_hwcomposer-upstream/Android.bp.disabled"
    [[ -f "${LINEAGE_ROOT}/external/drm_hwcomposer-upstream/tests/Android.bp" ]] && \
        mv "${LINEAGE_ROOT}/external/drm_hwcomposer-upstream/tests/Android.bp" \
           "${LINEAGE_ROOT}/external/drm_hwcomposer-upstream/tests/Android.bp.disabled"
fi

echo "=== Syncing device/google/gru ==="
mkdir -p "${LINEAGE_ROOT}/device/google/gru"
rsync -a --delete "${REPO_ROOT}/device/google/gru/" "${LINEAGE_ROOT}/device/google/gru/"

apply_patch() {
    local target_dir="$1"
    local patch_file="$2"
    local patch_name
    patch_name="$(basename "${patch_file}")"

    if [[ ! -d "${target_dir}" ]]; then
        echo "[ERROR] Target directory missing: ${target_dir} (for ${patch_name})" >&2
        echo "        Did you run 'repo sync' after installing local_manifests/gru.xml?" >&2
        exit 1
    fi

    if patch -d "${target_dir}" -p1 -R --dry-run -s < "${patch_file}" >/dev/null 2>&1; then
        echo "[SKIP]  ${patch_name} (already applied in ${target_dir})"
    elif patch -d "${target_dir}" -p1 --dry-run -s < "${patch_file}" >/dev/null 2>&1; then
        patch -d "${target_dir}" -p1 < "${patch_file}" >/dev/null
        echo "[OK]    ${patch_name} -> ${target_dir}"
    else
        echo "[FAIL]  ${patch_name} failed to apply cleanly to ${target_dir}" >&2
        exit 1
    fi
}

echo "=== Applying LineageOS 23.2 patches ==="
LINEAGE_PATCH_MAP=(
    "device/mainline/common:device_mainline_common_mesa_board_mk.patch"
    "device/mainline/common:device_mainline_common_v4l2_codec2_seccomp.patch"
    "external/XMP-Toolkit-SDK:external_XMP-Toolkit-SDK_vendor_available.patch"
    "external/drm_hwcomposer:external_drm_hwcomposer_plane_scaling.patch"
    "external/google-highway:external_google-highway_vendor_available.patch"
    "external/libcamera:external_libcamera_rkisp1_camera_hal.patch"
    "external/minigbm:external_minigbm_rkvdec_nv12.patch"
    "external/minigbm-upstream:external_minigbm-upstream_rkvdec_nv12.patch"
    "external/rust/crates/v4l2r:external_rust_crates_v4l2r_h264_control_drop.patch"
    "external/skia:external_skia_vendor_available.patch"
    "external/v4l2_codec2:external_v4l2_codec2_stateless_cros_codecs_decoder.patch"
    "frameworks/av:frameworks_av_codec2_ion_fallback.patch"
    "frameworks/base:frameworks_base_brightness_and_settingslib.patch"
    "hardware/interfaces:hardware_interfaces_audio_usb_alsa_sync_io.patch"
    "packages/apps/Settings:packages_apps_Settings_hearing_aid_null_check.patch"
    "packages/modules/Connectivity:packages_modules_Connectivity_netlink_monitor_einval.patch"
    "packages/modules/NetworkStack:packages_modules_NetworkStack_restart_netlink_monitor.patch"
    "system/core:system_core_healthd_battery_monitor.patch"
    "system/core:system_core_libcutils_memfd_isolated_app.patch"
    "system/cros-codecs:system_cros-codecs_v4l2_stateless_fixes_and_ffi.patch"
)

for entry in "${LINEAGE_PATCH_MAP[@]}"; do
    rel_dir="${entry%%:*}"
    patch_file="${PATCH_DIR}/${entry#*:}"
    apply_patch "${LINEAGE_ROOT}/${rel_dir}" "${patch_file}"
done

if [[ -n "${KERNEL_ROOT}" ]]; then
    KERNEL_ROOT="$(cd "${KERNEL_ROOT}" && pwd)"
    echo "=== Applying Linux 6.6.34 kernel patches to ${KERNEL_ROOT} ==="
    KERNEL_PATCHES=(
        "kernel_6.6.34_cros_ec_keyb_s3_power_button_wakeup.patch"
        "kernel_6.6.34_cros_usbpd_charger_online_notify.patch"
        "kernel_6.6.34_drm_master_and_fbdev_emulation.patch"
        "kernel_6.6.34_rkisp1_min_buffers_needed.patch"
        "kernel_6.6.34_rockchip_i2s_s3_mclk.patch"
    )
    for kp in "${KERNEL_PATCHES[@]}"; do
        apply_patch "${KERNEL_ROOT}" "${PATCH_DIR}/${kp}"
    done
    if [[ ! -f "${KERNEL_ROOT}/.config" ]]; then
        cp -v "${REPO_ROOT}/kernel/config-6.6.34-phase2" "${KERNEL_ROOT}/.config"
    fi
fi

echo "=== All patches verified and applied ==="
