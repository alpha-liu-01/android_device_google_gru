#
# Copyright (C) 2026 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

$(call inherit-product, vendor/lineage/config/common_full_tablet_wifionly.mk)
$(call inherit-product, device/google/gru/device.mk)

PRODUCT_NAME := lineage_gru
PRODUCT_DEVICE := gru
PRODUCT_BRAND := Android
PRODUCT_MODEL := Google Gru
PRODUCT_MANUFACTURER := Google

# Scarlet panel is portrait 1536x2048, about 260 dpi.
TARGET_SCREEN_HEIGHT := 2048
TARGET_SCREEN_WIDTH := 1536
TARGET_SCREEN_DENSITY := 260
