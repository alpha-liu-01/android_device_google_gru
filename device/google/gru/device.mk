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
TARGET_AUDIO_HAL := default-aidl
TARGET_AUDIO_POLICY := custom
TARGET_BLUETOOTH_HAL := default-aidl
TARGET_GRAPHICS := mesa
TARGET_GRAPHICS_VULKAN := none
TARGET_GRAPHICS_ALLOCATOR_HAL := minigbm-upstream
TARGET_MINIGBM_PLATFORM := generic
# external/drm_hwcomposer-upstream has no Android.bp in this tree.
# The AIDL HWC3 APEX is external/drm_hwcomposer.
TARGET_DRM_HWCOMPOSER_VARIANT := aosp
# The panel cannot be tapped yet. adb must not wait for a confirmation dialog.
TARGET_HOSTAPD_AND_WPA_SUPPLICANT_FORM := legacy
TARGET_USB_INIT_SCRIPT := none
include device/mainline/common/optional/options.mk
SUPPORTS_INLINE_KERNEL_BUILDING := false

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/mainline/common/mainline_common.mk)

DEVICE_PACKAGE_OVERLAYS := \
    $(LOCAL_PATH)/overlay \
    $(DEVICE_PACKAGE_OVERLAYS)

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_SHIPPING_API_LEVEL := 36
PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/qcom/wlan \
    hardware/qcom/wlan/legacy

PRODUCT_CHARACTERISTICS := tablet

# The panel cannot be tapped yet. adb must not wait for a confirmation dialog.
PRODUCT_PRODUCT_PROPERTIES += \
    ro.adb.secure=0 \
    ro.sf.lcd_density=260 \
    persist.sys.usb.config=adb \
    sys.brightness.disable_gamma_conversion=true \
    wifi.interface=wlan0 \
    wifi.direct.interface=p2p-dev-wlan0 \
    wifi.supplicant_scan_interval=15 \
    persist.bluetooth.a2dp_aac.vbr_supported=true \
    bluetooth.device.class_of_device=90,2,12 \
    bluetooth.le.disable_apcf_extended_features=1 \
    bluetooth.profile.asha.central.enabled=true \
    bluetooth.profile.a2dp.source.enabled=true \
    bluetooth.profile.avrcp.target.enabled=true \
    bluetooth.profile.gatt.enabled=true \
    bluetooth.profile.hfp.ag.enabled=true \
    bluetooth.profile.hid.device.enabled=true \
    bluetooth.profile.hid.host.enabled=true \
    bluetooth.profile.map.server.enabled=true \
    bluetooth.profile.mcp.server.enabled=true \
    bluetooth.profile.opp.enabled=true \
    bluetooth.profile.pan.nap.enabled=true \
    bluetooth.profile.pan.panu.enabled=true \
    bluetooth.profile.pbap.server.enabled=true \
    bluetooth.profile.sap.server.enabled=true \
    bluetooth.profile.bap.broadcast.assist.enabled=false \
    bluetooth.profile.bap.unicast.client.enabled=false \
    bluetooth.profile.bas.client.enabled=false \
    bluetooth.profile.ccp.server.enabled=false \
    bluetooth.profile.csip.set_coordinator.enabled=false \
    bluetooth.profile.hap.client.enabled=false \
    bluetooth.profile.vcp.controller.enabled=false

PRODUCT_VENDOR_PROPERTIES += \
    persist.sys.zram_enabled=1 \
    service.adb.tcp.port=5555 \
    ro.opengles.version=196609 \
    vendor.hwc.drm.device=/dev/dri/card0 \
    vendor.minigbm.device=/dev/dri/card0 \
    debug.renderengine.backend=skiaglthreaded \
    debug.hwui.renderer=skiagl \
    ro.surface_flinger.supports_background_blur=0

FORCE_USE_ANDROIDMK_FOR_WPA_CONF := true
PRODUCT_PACKAGES += \
    hwservicemanager \
    android.hardware.bluetooth-service.default \
    android.hardware.sensors-service.multihal \
    android.hardware.sensors@2.1-gru-subhal \
    android.hardware.wifi-service \
    hostapd \
    libcld80211 \
    libwpa_client \
    wpa_supplicant \
    wpa_supplicant.conf \
    wificond

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    $(LOCAL_PATH)/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    $(LOCAL_PATH)/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf \
    $(LOCAL_PATH)/etc/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration_7_0.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_with_le_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_with_le_audio_policy_configuration_7_0.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    $(LOCAL_PATH)/etc/sensors/hals.conf:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/hals.conf \
    $(LOCAL_PATH)/etc/sensors/sensor_hal_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/sensors/sensor_hal_configuration.xml \
    $(LOCAL_PATH)/idc/Elan_Touchscreen.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Elan_Touchscreen.idc \
    $(LOCAL_PATH)/idc/Vendor_04f3_Product_0b03.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_04f3_Product_0b03.idc \
    $(LOCAL_PATH)/idc/Vendor_2d1f_Product_0036.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_2d1f_Product_0036.idc \
    $(LOCAL_PATH)/keylayout/cros_ec.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/cros_ec.kl

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
    $(LOCAL_PATH)/firmware/ath10k/QCA6174/hw3.0/board-2.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/ath10k/QCA6174/hw3.0/board-2.bin \
    $(LOCAL_PATH)/firmware/ath10k/QCA6174/hw3.0/board.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/ath10k/QCA6174/hw3.0/board.bin \
    $(LOCAL_PATH)/firmware/ath10k/QCA6174/hw3.0/firmware-4.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/ath10k/QCA6174/hw3.0/firmware-4.bin \
    $(LOCAL_PATH)/firmware/ath10k/QCA6174/hw3.0/firmware-6.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/ath10k/QCA6174/hw3.0/firmware-6.bin \
    $(LOCAL_PATH)/firmware/qca/nvm_usb_00000200.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/nvm_usb_00000200.bin \
    $(LOCAL_PATH)/firmware/qca/nvm_usb_00000201.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/nvm_usb_00000201.bin \
    $(LOCAL_PATH)/firmware/qca/nvm_usb_00000300.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/nvm_usb_00000300.bin \
    $(LOCAL_PATH)/firmware/qca/nvm_usb_00000302.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/nvm_usb_00000302.bin \
    $(LOCAL_PATH)/firmware/qca/nvm_usb_00000302_eu.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/nvm_usb_00000302_eu.bin \
    $(LOCAL_PATH)/firmware/qca/rampatch_usb_00000200.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/rampatch_usb_00000200.bin \
    $(LOCAL_PATH)/firmware/qca/rampatch_usb_00000201.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/rampatch_usb_00000201.bin \
    $(LOCAL_PATH)/firmware/qca/rampatch_usb_00000300.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/rampatch_usb_00000300.bin \
    $(LOCAL_PATH)/firmware/qca/rampatch_usb_00000302.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qca/rampatch_usb_00000302.bin \
    $(LOCAL_PATH)/modules/aes-ce-blk.ko:$(TARGET_COPY_OUT_VENDOR)/lib/aes-ce-blk.ko \
    $(LOCAL_PATH)/modules/aes-ce-ccm.ko:$(TARGET_COPY_OUT_VENDOR)/lib/aes-ce-ccm.ko \
    $(LOCAL_PATH)/modules/aes-ce-cipher.ko:$(TARGET_COPY_OUT_VENDOR)/lib/aes-ce-cipher.ko \
    $(LOCAL_PATH)/modules/af_key.ko:$(TARGET_COPY_OUT_VENDOR)/lib/af_key.ko \
    $(LOCAL_PATH)/modules/arc4.ko:$(TARGET_COPY_OUT_VENDOR)/lib/arc4.ko \
    $(LOCAL_PATH)/modules/ath.ko:$(TARGET_COPY_OUT_VENDOR)/lib/ath.ko \
    $(LOCAL_PATH)/modules/ath10k_core.ko:$(TARGET_COPY_OUT_VENDOR)/lib/ath10k_core.ko \
    $(LOCAL_PATH)/modules/ath10k_pci.ko:$(TARGET_COPY_OUT_VENDOR)/lib/ath10k_pci.ko \
    $(LOCAL_PATH)/modules/bluetooth.ko:$(TARGET_COPY_OUT_VENDOR)/lib/bluetooth.ko \
    $(LOCAL_PATH)/modules/bnep.ko:$(TARGET_COPY_OUT_VENDOR)/lib/bnep.ko \
    $(LOCAL_PATH)/modules/btbcm.ko:$(TARGET_COPY_OUT_VENDOR)/lib/btbcm.ko \
    $(LOCAL_PATH)/modules/btintel.ko:$(TARGET_COPY_OUT_VENDOR)/lib/btintel.ko \
    $(LOCAL_PATH)/modules/btmtk.ko:$(TARGET_COPY_OUT_VENDOR)/lib/btmtk.ko \
    $(LOCAL_PATH)/modules/btqca.ko:$(TARGET_COPY_OUT_VENDOR)/lib/btqca.ko \
    $(LOCAL_PATH)/modules/btrtl.ko:$(TARGET_COPY_OUT_VENDOR)/lib/btrtl.ko \
    $(LOCAL_PATH)/modules/btusb.ko:$(TARGET_COPY_OUT_VENDOR)/lib/btusb.ko \
    $(LOCAL_PATH)/modules/ccm.ko:$(TARGET_COPY_OUT_VENDOR)/lib/ccm.ko \
    $(LOCAL_PATH)/modules/cfg80211.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cfg80211.ko \
    $(LOCAL_PATH)/modules/cmac.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cmac.ko \
    $(LOCAL_PATH)/modules/cpufreq-dt.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cpufreq-dt.ko \
    $(LOCAL_PATH)/modules/cros-ec-sensorhub.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros-ec-sensorhub.ko \
    $(LOCAL_PATH)/modules/cros_ec_sensors.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros_ec_sensors.ko \
    $(LOCAL_PATH)/modules/cros_ec_sensors_core.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros_ec_sensors_core.ko \
    $(LOCAL_PATH)/modules/cros_usbpd-charger.ko:$(TARGET_COPY_OUT_VENDOR)/lib/cros_usbpd-charger.ko \
    $(LOCAL_PATH)/modules/drm_shmem_helper.ko:$(TARGET_COPY_OUT_VENDOR)/lib/drm_shmem_helper.ko \
    $(LOCAL_PATH)/modules/ecc.ko:$(TARGET_COPY_OUT_VENDOR)/lib/ecc.ko \
    $(LOCAL_PATH)/modules/ecdh_generic.ko:$(TARGET_COPY_OUT_VENDOR)/lib/ecdh_generic.ko \
    $(LOCAL_PATH)/modules/fuse.ko:$(TARGET_COPY_OUT_VENDOR)/lib/fuse.ko \
    $(LOCAL_PATH)/modules/gpio_keys.ko:$(TARGET_COPY_OUT_VENDOR)/lib/gpio_keys.ko \
    $(LOCAL_PATH)/modules/gpu-sched.ko:$(TARGET_COPY_OUT_VENDOR)/lib/gpu-sched.ko \
    $(LOCAL_PATH)/modules/hidp.ko:$(TARGET_COPY_OUT_VENDOR)/lib/hidp.ko \
    $(LOCAL_PATH)/modules/i2c-hid-of.ko:$(TARGET_COPY_OUT_VENDOR)/lib/i2c-hid-of.ko \
    $(LOCAL_PATH)/modules/i2c-hid.ko:$(TARGET_COPY_OUT_VENDOR)/lib/i2c-hid.ko \
    $(LOCAL_PATH)/modules/industrialio-triggered-buffer.ko:$(TARGET_COPY_OUT_VENDOR)/lib/industrialio-triggered-buffer.ko \
    $(LOCAL_PATH)/modules/kfifo_buf.ko:$(TARGET_COPY_OUT_VENDOR)/lib/kfifo_buf.ko \
    $(LOCAL_PATH)/modules/libarc4.ko:$(TARGET_COPY_OUT_VENDOR)/lib/libarc4.ko \
    $(LOCAL_PATH)/modules/lz4.ko:$(TARGET_COPY_OUT_VENDOR)/lib/lz4.ko \
    $(LOCAL_PATH)/modules/mac80211.ko:$(TARGET_COPY_OUT_VENDOR)/lib/mac80211.ko \
    $(LOCAL_PATH)/modules/panfrost.ko:$(TARGET_COPY_OUT_VENDOR)/lib/panfrost.ko \
    $(LOCAL_PATH)/modules/rfcomm.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rfcomm.ko \
    $(LOCAL_PATH)/modules/rfkill.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rfkill.ko \
    $(LOCAL_PATH)/modules/rk3399_dmc.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rk3399_dmc.ko \
    $(LOCAL_PATH)/modules/rockchip-dfi.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rockchip-dfi.ko \
    $(LOCAL_PATH)/modules/rockchip_thermal.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rockchip_thermal.ko \
    $(LOCAL_PATH)/modules/rtc-cros-ec.ko:$(TARGET_COPY_OUT_VENDOR)/lib/rtc-cros-ec.ko \
    $(LOCAL_PATH)/modules/snd-pcm-dmaengine.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-pcm-dmaengine.ko \
    $(LOCAL_PATH)/modules/snd-pcm.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-pcm.ko \
    $(LOCAL_PATH)/modules/snd-soc-core.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-core.ko \
    $(LOCAL_PATH)/modules/snd-soc-da7219.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-da7219.ko \
    $(LOCAL_PATH)/modules/snd-soc-dmic.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-dmic.ko \
    $(LOCAL_PATH)/modules/snd-soc-hdmi-codec.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-hdmi-codec.ko \
    $(LOCAL_PATH)/modules/snd-soc-max98357a.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-max98357a.ko \
    $(LOCAL_PATH)/modules/snd-soc-rk3399-gru-sound.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-rk3399-gru-sound.ko \
    $(LOCAL_PATH)/modules/snd-soc-rl6231.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-rl6231.ko \
    $(LOCAL_PATH)/modules/snd-soc-rockchip-i2s.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-rockchip-i2s.ko \
    $(LOCAL_PATH)/modules/snd-soc-rockchip-spdif.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-rockchip-spdif.ko \
    $(LOCAL_PATH)/modules/snd-soc-rt5514-spi.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-rt5514-spi.ko \
    $(LOCAL_PATH)/modules/snd-soc-rt5514.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-soc-rt5514.ko \
    $(LOCAL_PATH)/modules/snd-timer.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd-timer.ko \
    $(LOCAL_PATH)/modules/snd.ko:$(TARGET_COPY_OUT_VENDOR)/lib/snd.ko \
    $(LOCAL_PATH)/modules/soundcore.ko:$(TARGET_COPY_OUT_VENDOR)/lib/soundcore.ko \
    $(LOCAL_PATH)/modules/uhid.ko:$(TARGET_COPY_OUT_VENDOR)/lib/uhid.ko \
    $(LOCAL_PATH)/modules/zram.ko:$(TARGET_COPY_OUT_VENDOR)/lib/zram.ko

include $(LOCAL_PATH)/modules.mk
