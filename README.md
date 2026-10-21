# LineageOS 23.2 (Android 16) for Google Gru (`rk3399-gru-scarlet`)

Device tree, kernel configurations, and source patches for running LineageOS 23.2 on Google Gru Chromebooks / tablets (specifically tested on the **Acer Chromebook Tab 10 / `scarlet`** with a mainline Linux `6.6.34-phase2` kernel).

---

## Repository Layout

- `device/google/gru/` — Android device tree (`lineage_gru`), init scripts, audio/display/media configurations, and prebuilt `6.6.34-phase2` kernel modules (`.ko`).
- `local_manifests/gru.xml` — Additional LineageOS 23.2 repositories required for mainline DRM/Mesa/Gralloc/V4L2 Codec2 support.
- `patches/` — All patches against upstream LineageOS 23.2 sub-repositories and the vanilla Linux `6.6.34` kernel, plus `apply-patches.sh` to apply them automatically.
- `kernel/` — Linux `6.6.34-phase2` kernel configuration (`config-6.6.34-phase2`), base postmarketOS config (`config-postmarketos-rockchip.aarch64`), and Android config fragment (`phase2.fragment`).
- `docs/` — Architecture, hardware bring-up notes, and debugging logs (`roadmap.md`, `phase-4.md`, `video-decode.md`, etc.).

---

## Reproducing the Build from Scratch

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

Run the idempotent setup script to copy `device/google/gru` into the LineageOS tree and apply all 19 LineageOS patches:

```bash
~/android_device_google_gru/patches/apply-patches.sh ~/lineage-23.2
```

### 3. Build `super.img`

```bash
cd ~/lineage-23.2
source build/envsetup.sh
lunch lineage_gru-bp4a-userdebug
m superimage
```

The resulting image is written to `out/target/product/gru/super.img`.

---

## Rebuilding the Linux `6.6.34-phase2` Kernel (Optional)

Prebuilt kernel modules matching `6.6.34-phase2` are already included in `device/google/gru/modules/`. To rebuild the kernel `Image` and modules from vanilla `linux-6.6.34`:

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.34.tar.xz
tar -xf linux-6.6.34.tar.xz

# Apply the 3 kernel patches and install kernel/config-6.6.34-phase2 as .config
~/android_device_google_gru/patches/apply-patches.sh ~/lineage-23.2 ./linux-6.6.34

cd linux-6.6.34
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image modules dtbs
```
