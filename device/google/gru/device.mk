#
# Copyright (C) 2026 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

LOCAL_PATH := device/google/gru

AB_OTA_UPDATER := false
# No controller. Advertising android.hardware.bluetooth makes SystemServer
# construct BluetoothService, which aborts when com.android.bluetooth is disabled.
TARGET_BLUETOOTH_HAL := none
TARGET_GRAPHICS := mesa
TARGET_GRAPHICS_VULKAN := none
TARGET_GRAPHICS_ALLOCATOR_HAL := minigbm-upstream
TARGET_MINIGBM_PLATFORM := generic
# external/drm_hwcomposer-upstream has no Android.bp in this tree.
# The AIDL HWC3 APEX is external/drm_hwcomposer.
TARGET_DRM_HWCOMPOSER_VARIANT := aosp
include device/mainline/common/optional/options.mk
SUPPORTS_INLINE_KERNEL_BUILDING := false

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/mainline/common/mainline_common.mk)

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

PRODUCT_CHARACTERISTICS := tablet

# The panel cannot be tapped yet. adb must not wait for a confirmation dialog.
PRODUCT_PRODUCT_PROPERTIES += \
    ro.adb.secure=0 \
    ro.sf.lcd_density=260 \
    persist.sys.usb.config=adb

PRODUCT_VENDOR_PROPERTIES += \
    persist.sys.zram_enabled=1 \
    ro.opengles.version=196609 \
    vendor.hwc.drm.device=/dev/dri/card0 \
    vendor.minigbm.device=/dev/dri/card0 \
    debug.renderengine.backend=skiaglthreaded \
    debug.hwui.renderer=skiagl \
    ro.surface_flinger.supports_background_blur=0

PRODUCT_PACKAGES += \
    hwservicemanager \
    android.hardware.sensors-service.multihal \
    android.hardware.sensors@2.1-gru-subhal

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/etc/sensors/hals.conf:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/hals.conf \
    $(LOCAL_PATH)/etc/sensors/sensor_hal_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/sensor_hal_configuration.xml \
    $(LOCAL_PATH)/idc/Vendor_04f3_Product_0b03.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_04f3_Product_0b03.idc \
    $(LOCAL_PATH)/idc/Vendor_2d1f_Product_0036.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_2d1f_Product_0036.idc

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/etc/permissions/android.software.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.xml \
    frameworks/native/data/etc/android.software.cts.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.cts.xml \
    frameworks/native/data/etc/android.software.app_widgets.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.app_widgets.xml \
    frameworks/native/data/etc/android.software.backup.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.backup.xml \
    frameworks/native/data/etc/android.software.voice_recognizers.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.voice_recognizers.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.software.print.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.print.xml \
    frameworks/native/data/etc/android.software.device_admin.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_admin.xml \
    frameworks/native/data/etc/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fstab.gru:$(TARGET_COPY_OUT_RAMDISK)/fstab.gru \
    $(LOCAL_PATH)/fstab.gru:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.gru \
    $(LOCAL_PATH)/init.gru.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.gru.rc \
    $(LOCAL_PATH)/ueventd.gru.rc:$(TARGET_COPY_OUT_VENDOR)/etc/ueventd.gru.rc \
    $(LOCAL_PATH)/gru-logcat.sh:$(TARGET_COPY_OUT_VENDOR)/bin/gru-logcat.sh \
    $(LOCAL_PATH)/firmware/rockchip/dptx.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/rockchip/dptx.bin \
    $(LOCAL_PATH)/modules/af_key.ko:$(TARGET_COPY_OUT_VENDOR)/lib/af_key.ko \
    $(LOCAL_PATH)/modules/cpufreq-dt.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cpufreq-dt.ko \
    $(LOCAL_PATH)/modules/cros-ec-sensorhub.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros-ec-sensorhub.ko \
    $(LOCAL_PATH)/modules/cros_ec_sensors.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros_ec_sensors.ko \
    $(LOCAL_PATH)/modules/cros_ec_sensors_core.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros_ec_sensors_core.ko \
    $(LOCAL_PATH)/modules/drm_shmem_helper.ko:$(TARGET_COPY_OUT_VENDOR)/lib/drm_shmem_helper.ko \
    $(LOCAL_PATH)/modules/fuse.ko:$(TARGET_COPY_OUT_VENDOR)/lib/fuse.ko \
    $(LOCAL_PATH)/modules/gpio_keys.ko:$(TARGET_COPY_OUT_VENDOR)/lib/gpio_keys.ko \
    $(LOCAL_PATH)/modules/gpu-sched.ko:$(TARGET_COPY_OUT_VENDOR)/lib/gpu-sched.ko \
    $(LOCAL_PATH)/modules/i2c-hid-of.ko:$(TARGET_COPY_OUT_VENDOR)/lib/i2c-hid-of.ko \
    $(LOCAL_PATH)/modules/i2c-hid.ko:$(TARGET_COPY_OUT_VENDOR)/lib/i2c-hid.ko \
    $(LOCAL_PATH)/modules/industrialio-triggered-buffer.ko:$(TARGET_COPY_OUT_VENDOR)/lib/industrialio-triggered-buffer.ko \
    $(LOCAL_PATH)/modules/kfifo_buf.ko:$(TARGET_COPY_OUT_VENDOR)/lib/kfifo_buf.ko \
    $(LOCAL_PATH)/modules/lz4.ko:$(TARGET_COPY_OUT_VENDOR)/lib/lz4.ko \
    $(LOCAL_PATH)/modules/panfrost.ko:$(TARGET_COPY_OUT_VENDOR)/lib/panfrost.ko \
    $(LOCAL_PATH)/modules/rk3399_dmc.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rk3399_dmc.ko \
    $(LOCAL_PATH)/modules/rockchip-dfi.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rockchip-dfi.ko \
    $(LOCAL_PATH)/modules/rockchip_thermal.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rockchip_thermal.ko \
    $(LOCAL_PATH)/modules/zram.ko:$(TARGET_COPY_OUT_VENDOR)/lib/zram.ko

include $(LOCAL_PATH)/modules.mk
