#
# Copyright (C) 2026 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

DEVICE_PATH := device/google/gru
MAINLINE_COMMON_PATH := device/mainline/common

# Do not set TARGET_INITIAL_BRINGUP. That selects HIDL drmfb-composer.
AB_OTA_UPDATER := false
TARGET_GRAPHICS := mesa
TARGET_GRAPHICS_VULKAN := none
TARGET_GRAPHICS_ALLOCATOR_HAL := minigbm-upstream
# minigbm-upstream has no rockchip soong platform. generic uses the dumb
# rockchip backend. The DRV_ROCKCHIP ioctl backend needs a downstream GEM
# ioctl this 6.6 kernel does not implement. msm pulls the Qualcomm backend.
TARGET_MINIGBM_PLATFORM := generic
BOARD_MESA3D_GALLIUM_DRIVERS := panfrost
include $(MAINLINE_COMMON_PATH)/optional/options.mk
SUPPORTS_INLINE_KERNEL_BUILDING := false

include $(MAINLINE_COMMON_PATH)/BoardConfigMainlineCommon.mk

# The kernel is the existing 6.6.34-phase2 image. Do not build one here.
TARGET_NO_KERNEL := true
TARGET_KERNEL_MIXED_MODE := false

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_SUPPORTS_64_BIT_APPS := true

TARGET_BOOTLOADER_BOARD_NAME := gru
TARGET_BOARD_PLATFORM := gru
TARGET_NO_RADIOIMAGE := true
TARGET_NO_BOOTLOADER := true

# Kernel modules copied into the ramdisk are ELF objects, not shared libraries.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Depthcharge has no bootconfig. The FIT cmdline is cmdline.txt.
# Mainline common adds binder.impl=rust; this kernel does not have it.
BOARD_KERNEL_CMDLINE := console=tty0 loglevel=7 deferred_probe_timeout=30 security=selinux androidboot.selinux=permissive androidboot.hardware=gru androidboot.boot_devices=fe320000.mmc printk.devkmsg=on
BOARD_BOOTCONFIG :=

DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/fstab.gru

# Dynamic super. Sizes match the SD layout in partition-table.txt.
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_F2FS_BLOCKSIZE := 4096
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
BOARD_USES_METADATA_PARTITION := true
BOARD_FLASH_BLOCK_SIZE := 4096

BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
BOARD_SUPER_PARTITION_SIZE := 8589934592
BOARD_GRU_DYNAMIC_PARTITIONS_SIZE := 8585740288
BOARD_SUPER_PARTITION_GROUPS := gru_dynamic_partitions
BOARD_GRU_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor system_ext product system_dlkm vendor_dlkm

# The GPT userdata partition is larger. This image is a placeholder; the
# write step formats the whole partition.
BOARD_USERDATAIMAGE_PARTITION_SIZE := 4294967296
