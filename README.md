# LineageOS 23.2 (Android 16) for Google Gru (`rk3399-gru-scarlet` / `kevin` / `bob`)

Device tree, mainline Linux `6.6.34-phase2` kernel configuration/modules, source patches, and host-side SD card image packaging tools for running **LineageOS 23.2 (Android 16)** on Google Gru (Rockchip RK3399) Chromebooks and tablets using the stock ChromeOS **Depthcharge** bootloader.

> **100% Non-Destructive to Internal Storage (`eMMC`)**:
> This image boots strictly from an external microSD card (`fe320000.mmc`) via ChromeOS Depthcharge (`Ctrl + U` or the external disk boot menu). It **never touches or modifies** the internal eMMC (`fe330000.sdhci`). Simply remove the microSD card or choose Internal Disk at boot to return to ChromeOS or postmarketOS on internal storage.

---

## Supported Devices & Hardware Status

The Depthcharge FIT kernel image (`vmlinuz.kpart`) bundles all 5 mainline `rk3399-gru-*` Device Trees so the stock firmware automatically selects the matching board:

| Device | Codename / DTB | Status |
| :--- | :--- | :--- |
| **Acer Chromebook Tab 10** / **ASUS Chromebook Tablet CT100** | `scarlet` (`rk3399-gru-scarlet-kd` [default], `scarlet-inx`, `scarlet-dumo`) | **Verified & Daily-Drivable** (tested on `scarlet-kd`) |
| **Samsung Chromebook Plus (v1)** | `kevin` (`rk3399-gru-kevin`) | DTB bundled in FIT (untested on hardware) |
| **ASUS Chromebook Flip C101PA** | `bob` (`rk3399-gru-bob`) | DTB bundled in FIT (untested on hardware) |

### What Works on `scarlet` (`Acer Chromebook Tab 10`)

| Subsystem | Status | Implementation Details |
| :--- | :---: | :--- |
| **Boot & Storage** | Working | Stock Depthcharge FIT (`KERN-A`), EROFS dynamic partitions (`super`), F2FS `userdata` with **automatic first-boot expansion** to fill any 16 GB+ microSD card |
| **Display & GPU** | Working | `1536x2048@60Hz` Kingdisplay MIPI-DSI panel, `rockchip-drm` + AIDL `drm_hwcomposer`, **Mesa 3D Panfrost** (`Mali-T860` GLES hardware acceleration) |
| **Touchscreen & Stylus** | Working | Elan `ekth3500` touchscreen (`ff130000.i2c`) + Wacom EMR stylus (`2D1F:0036`) with pressure/tilt support |
| **Auto-Rotation & Sensors** | Working | ChromeOS EC IIO accelerometer & gyroscope (`cros-ec-accel`, `cros-ec-gyro`) via AIDL Sensors Multihal |
| **Backlight** | Working | 4096-step linear PWM backlight control (`/sys/class/backlight/backlight`) |
| **Wi-Fi & Wireless ADB** | Working | Qualcomm QCA6174 (`ath10k_pci`, 2.4 GHz / 5 GHz) with `wpa_supplicant` (`nl80211`) |
| **Bluetooth** | Working | QCA6174 USB (`btusb`, `0cf3:e300`) via `libbt-vendor` + `btlinux` AIDL Bluetooth HAL |
| **Audio Out & In** | Working | Built-in Speaker (`MAX98357A`), Built-in Digital Mic (`ADAU7002` DMIC), 3.5mm Headset Jack (`DA7219`), and USB Type-C Audio DACs |
| **Cameras (Photo & Video)** | Working | Rear 5MP (`OV5695`) & Front 2MP (`OV2685`) via `rkisp1` + `libcamera` HAL with calibrated ISP (`BLS`/`CCM`/`GOC`/`LSC`) and H.264 + AAC video recording in Aperture |
| **Hardware Video Decode** | Working | H.264 / VP8 / VP9 hardware decoding via `hantro-vpu` & `rockchip-vdec` V4L2 Stateless Request API (`c2.v4l2.*`) |
| **USB-C Host & DP Alt Mode** | Working | USB 3.0 Type-C Host (hubs, keyboards, mice, flash drives, DACs) + **4K@60Hz DisplayPort Alt Mode** (`cdn-dp`) with Android 16 Desktop Mode |
| **Battery, USB-PD & Sleep** | Working | `sbs-battery` + `cros_usbpd-charger` AIDL Health HAL, `zram` (75% LZ4), and stable S3 `deep` suspend/resume (`dw_wdt` watchdog keeper) |

---

## User Installation Guide (Flashing to microSD Card)

### Prerequisites

1. A **Google Gru** device (such as the Acer Chromebook Tab 10 / `scarlet`) with **Developer Mode** enabled.
2. External USB / microSD boot enabled in ChromeOS or postmarketOS:
   - From a root shell in ChromeOS VT2 (`Ctrl + Alt + F2`) or postmarketOS / Linux on internal eMMC, run:
     ```bash
     sudo crossystem dev_boot_usb=1
     ```
3. A **16 GB or larger** microSD card (UHS-I U3 / A1 or A2 recommended; 32 GB / 64 GB / 128 GB cards are automatically expanded on first boot).

### Step 1: Download & Verify the Release Archive

Download the latest release `.zip` and `.zip.sha256` files from the GitHub Releases page (or from `out/target/product/gru/` if built locally):

- **Release Archive**: `lineage-23.2-gru-20261022.zip` (`990 MiB` compressed / `10.5 GiB` unpacked)
- **SHA-256 Checksum**:
  ```text
  00c03b5ac10bd3a9d55d47f943e24c1bde627d671a87742afef027c680feef1f  lineage-23.2-gru-20261022.zip
  ```

Verify the checksum before flashing:
- **Linux / macOS**:
  ```bash
  sha256sum -c lineage-23.2-gru-20261022.zip.sha256
  ```
- **Windows (PowerShell)**:
  ```powershell
  Get-FileHash .\lineage-23.2-gru-20261022.zip -Algorithm SHA256
  ```

### Step 2: Flash the Image to the microSD Card

You can flash `lineage-23.2-gru-YYYYMMDD.zip` directly without manually extracting it:

- **Option A — Windows (Rufus)**:
  1. Open [Rufus](https://rufus.ie/), select your microSD card under **Device**.
  2. Click **SELECT** and choose `lineage-23.2-gru-YYYYMMDD.zip` (or the extracted `.img` file).
  3. Click **START** to write the raw GPT disk image to the microSD card.
- **Option B — Windows / macOS / Linux (BalenaEtcher)**:
  1. Open [BalenaEtcher](https://etcher.balena.io/).
  2. Click **Flash from file** and select `lineage-23.2-gru-YYYYMMDD.zip`.
  3. Select your microSD card target and click **Flash!**.
- **Option C — Linux / macOS (`unzip` + `dd`)**:
  ```bash
  unzip -p lineage-23.2-gru-20261022.zip | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
  ```
  *(Replace `/dev/sdX` or `/dev/mmcblkX` with your microSD card reader device).*

### Step 3: Boot into LineageOS 23.2

1. Insert the flashed microSD card into the tablet/Chromebook and power it on.
2. At the ChromeOS Developer Mode boot screen:
   - Press **`Ctrl + U`**, **or**
   - On tablets without a keyboard attached, use the Volume buttons to open **Boot Options** -> select **Boot from External Disk (SD/USB)**.
3. **First Boot Notes**:
   - During the first ~10 seconds before the display panel initializes, the screen will remain black while `gru-keep` loads early kernel modules.
   - On the very first boot, `expand_userdata.sh` automatically relocates the backup GPT header to the end of your microSD card and expands the F2FS `/data` partition (`p6`) to utilize 100% of the card's remaining capacity without requiring an extra reboot.
   - Complete the LineageOS Setup Wizard to enter the Android 16 desktop.

---

## Building from Source & Packaging a Release Image

### Repository Layout

- `device/google/gru/` — Android device tree (`lineage_gru`), init scripts, audio/display/camera/media configurations, prebuilt `6.6.34-phase2` kernel (`vmlinuz`), all 5 `rk3399-gru-*.dtb` files, and kernel modules (`.ko`).
- `device/google/gru/tools/pack_kpart.sh` — Host-side script that wraps `ramdisk.img` with `gru-keep`, compresses `vmlinuz` with LZMA, packs the 5-DTB Flattened Image Tree (`image.itb`), and signs `vmlinuz.kpart` with `futility-host`.
- `device/google/gru/tools/pack_release_image.sh` — Host-side script that unsparses `super.img`, formats `bootlog`/`metadata`/`userdata`, creates a 10.5 GiB ChromeOS GPT disk image, and packages the flashable `.zip` and `.sha256`.
- `local_manifests/gru.xml` — Additional LineageOS 23.2 repositories required for mainline DRM/Mesa/Gralloc/libcamera/V4L2 Codec2 support.
- `patches/` — Source patches against LineageOS 23.2 sub-repositories and the mainline Linux `6.6.34` kernel, plus `apply-patches.sh`.
- `kernel/` — Linux `6.6.34-phase2` kernel configuration (`config-6.6.34-phase2`).
- `docs/` — Detailed engineering documentation ([`roadmap.md`](docs/roadmap.md), [`phase-1.md`](docs/phase-1.md) through [`phase-5.md`](docs/phase-5.md), [`usb.md`](docs/usb.md), [`video-decode.md`](docs/video-decode.md), [`camera.md`](docs/camera.md)).

### 1. Initialize LineageOS 23.2 and Sync Sources

```bash
mkdir -p ~/lineage-23.2 && cd ~/lineage-23.2
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

# Clone this repository
git clone https://github.com/alpha-liu-01/android_device_google_gru.git ~/android_device_google_gru

# Install the local manifest for mainline dependencies
mkdir -p .repo/local_manifests
cp ~/android_device_google_gru/local_manifests/gru.xml .repo/local_manifests/gru.xml

# Sync the LineageOS source tree
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags
```

### 2. Apply Device Tree and Source Patches

Run the idempotent setup script to install `device/google/gru` into the LineageOS tree and apply all LineageOS patches:

```bash
~/android_device_google_gru/patches/apply-patches.sh ~/lineage-23.2
```

### 3. Build Android Images & Host Packaging Tools

```bash
cd ~/lineage-23.2
source build/envsetup.sh
breakfast gru    # same as: lunch lineage_gru-bp4a-userdebug
m superimage ramdisk-nodeps futility-host sgdisk simg2img mke2fs make_f2fs fsck.f2fs
```

Always build with the `bp4a` release (what `breakfast` selects). `trunk_staging` sets `RELEASE_SM_OPEN_DECLARED_PASSTHROUGH_HAL=true`, which drops the standalone `/vendor/lib64/hw/mapper.minigbm_upstream.so` and its VINTF fragment; SurfaceFlinger then aborts with `gralloc-mapper is missing` and the device never lights the backlight. Switching between the two releases in one `out/` also triggers an `installclean`, so rebuild all images after switching.

### 4. Package the Bootable SD Card Image (`.img` & `.zip`)

Run the one-step release packaging script on the build host:

```bash
./device/google/gru/tools/pack_release_image.sh
```

This generates in `out/target/product/gru/`:
- `vmlinuz.kpart` — Signed ChromeOS Depthcharge FIT kernel image (`KERN-A`).
- `lineage-23.2-gru-YYYYMMDD.img` — 10.5 GiB raw GPT disk image (`KERN-A`, `bootlog`, `metadata`, `misc`, `super`, `userdata`).
- `lineage-23.2-gru-YYYYMMDD.zip` — Compressed flashable archive ready for Rufus / BalenaEtcher.
- `lineage-23.2-gru-YYYYMMDD.zip.sha256` — SHA-256 checksum file.

---

## Rebuilding the Linux `6.6.34-phase2` Kernel (Optional)

Prebuilt kernel image (`vmlinuz`), DTBs, and modules matching `6.6.34-phase2` are already included in `device/google/gru/prebuilt/` and `device/google/gru/modules/`. To rebuild the kernel from vanilla `linux-6.6.34`:

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.34.tar.xz
tar -xf linux-6.6.34.tar.xz

# Apply the 3 kernel patches and install kernel/config-6.6.34-phase2 as .config
~/android_device_google_gru/patches/apply-patches.sh ~/lineage-23.2 ./linux-6.6.34

cd linux-6.6.34
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image modules dtbs
```

---

## License

- Device tree configs, build files, and packaging scripts in this repository are licensed under the **Apache License 2.0** (see [`LICENSE`](LICENSE)).
- Prebuilt Linux kernel image, DTBs, modules (`.ko`), and kernel patches are licensed under **GPL-2.0-only**.
- Redistributed hardware firmware blobs under `device/google/gru/firmware/` are governed by their respective `linux-firmware` licenses.
