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
TARGET_GRAPHICS := swiftshader
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

PRODUCT_CHARACTERISTICS := tablet

# The panel cannot be tapped yet. adb must not wait for a confirmation dialog.
PRODUCT_PRODUCT_PROPERTIES += \
    ro.adb.secure=0 \
    ro.sf.lcd_density=260 \
    persist.sys.usb.config=adb

PRODUCT_VENDOR_PROPERTIES += \
    persist.sys.zram_enabled=1

PRODUCT_PACKAGES += hwservicemanager

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/etc/permissions/android.software.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.xml \
    frameworks/native/data/etc/android.software.cts.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.cts.xml \
    frameworks/native/data/etc/android.software.app_widgets.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.app_widgets.xml \
    frameworks/native/data/etc/android.software.backup.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.backup.xml \
    frameworks/native/data/etc/android.software.voice_recognizers.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.voice_recognizers.xml \
    frameworks/native/data/etc/android.software.print.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.print.xml \
    frameworks/native/data/etc/android.software.device_admin.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_admin.xml \
    frameworks/native/data/etc/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fstab.gru:$(TARGET_COPY_OUT_RAMDISK)/fstab.gru \
    $(LOCAL_PATH)/fstab.gru:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.gru \
    $(LOCAL_PATH)/init.gru.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.gru.rc \
    $(LOCAL_PATH)/gru-logcat.sh:$(TARGET_COPY_OUT_VENDOR)/bin/gru-logcat.sh \
    $(LOCAL_PATH)/firmware/rockchip/dptx.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/rockchip/dptx.bin \
    $(LOCAL_PATH)/modules/af_key.ko:$(TARGET_COPY_OUT_VENDOR)/lib/af_key.ko \
    $(LOCAL_PATH)/modules/lz4.ko:$(TARGET_COPY_OUT_VENDOR)/lib/lz4.ko \
    $(LOCAL_PATH)/modules/zram.ko:$(TARGET_COPY_OUT_VENDOR)/lib/zram.ko

include $(LOCAL_PATH)/modules.mk
