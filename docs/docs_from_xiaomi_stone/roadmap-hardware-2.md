# Hardware, part 2

All items here are done or recorded (2026-11-11). The next stage (recovery, updates, the installer, publishing, the device list) is `docs/roadmap-release.md`.

`docs/roadmap-hardware.md` items 1 to 7 are done:
- storage;
- vendor modules;
- sound;
- Wi-Fi;
- SIM, data, calls and MMS;
- Bluetooth and wired headsets;
- camera.

This document covers the hardware that is still missing or untested after that. It follows the same rules:
- Fixes go into the repository (`boot/ut-init/rootfs-overlay/`, `boot/ut-init/stone-vendor-fixups.py`, `kernel/patches/`, `tools/`).
- Live tests run on the phone first, through scripts in `tools/phone-debug/`.
- The user flashes and commits.
- Do not reflash `vendor_boot`, `dtbo`, `vbmeta`, or `super`.

The phone has no passwordless sudo. Anything that needs root has to be run by the user with `adb shell -t 'sudo …'` (exit code 129 after it finishes is the SIGHUP from `-t`, not a failure). Push single files with adb, never a directory (a directory push drops the USB connection until it is replugged).

State at the start (2026-11-10):
- `boot_b`: `e1554638…` (kernel `#13`).
- Current image (2026-11-12, written and confirmed): `69b9f797…` (`out/halium14/boot-ut-69b9f797.img`; kernel `#20`). It leaves the second Wi-Fi interface `wlan1` to the driver, so each network is listed once (item 12). Before it: `3cdee49b…` (`out/halium14/boot-ut-3cdee49b.img`; kernel `#20`), which adds the flashlight toggle (item 5) and the tested versions after the first `apt full-upgrade` (`docs/roadmap-release.md` item 7 step 2). Before it: `82f5c1d5…` (`out/halium14/boot-ut-82f5c1d5.img`; kernel `#20`), which makes `apt` upgrades safe (`docs/roadmap-release.md` item 7 step 1): the telephony handler copy and the APN database are generated on the phone, and an apt hook lifts the display bind mounts around dpkg. Before it: `ca678721…` (`out/halium14/boot-ut-ca678721.img`; kernel `#20`), which adds AppArmor D-Bus and unix-socket mediation (kernel patches `0011`–`0015`) and runs the stock media-hub again (`docs/roadmap-release.md` item 12; the test image `9f0b20f2…` came first). Before it: `16bfa7b0…` (`out/halium14/boot-ut-16bfa7b0.img`; kernel `#18`), which adds, in `docs/roadmap-release.md`: the logcat wrapper and the logd watchdog (item 15, `92c0d49f…`, never written); the display cutout settings (item 16, `2edde0c6…`, never written); and the USB gadget serial from `androidboot.serialno` (item 3). Before it: `663a4d80…` (`out/halium14/boot-ut-test-clock.img`; kernel `#18`), which adds, in `docs/roadmap-release.md`: the clock fix (item 14); Bluetooth off/on and reconnect (item 13, `d9184e3c…`); and USB at boot, adb after charger mode, and the boot-mode log (item 2, `983f1711…` and `7593d35c…`). Before it: `2708ccaf…` (adds the UBports recovery, `docs/roadmap-release.md` item 1; the first recovery build `e8ff055e…` was replaced by it). Before it: `fced82d0…` (SIM 2 call audio, item 9), kept as `out/halium14/boot-ut-fced82d0.img`. Before it: `45e50e0d…` (the NFC presence check and `stone-ir`, item 9; it superseded `07ce6de3…`, which was never written), written and booted on 2026-11-11 at 15:56, kept as `out/halium14/boot-ut-45e50e0d.img`. Before that: `c57e8b19…` (the incoming-call SLIMbus rate fix for wideband Bluetooth calls, item 9). Before it: `9a9590c4…` (kernel `#17`, wideband Bluetooth calls), written 2026-11-11, kept as `out/halium14/boot-ut-9a9590c4.img`. That one includes `f4a9cf05…` (the in-call volume fix, item 9), which was built but never written, kept as `out/halium14/boot-ut-f4a9cf05.img`. Before it: `d302d1a1…` (the fingerprint fix, item 8), written and booted on 2026-11-11 at 13:53, kept as `out/halium14/boot-ut-d302d1a1.img`. Before it: `0ea13aae…` (the refresh rate setting in System Settings > Brightness, item 11), written and running on 2026-11-11 (the Settings page is bind-mounted at boot), kept as `out/halium14/boot-ut-0ea13aae.img`. Before it: `675fd590…` (kernel `#15` with the 60 Hz panel command fix, plus `stone-display-setup.service` and `stone-refresh-rate`), written and confirmed on 2026-11-11, kept as `out/halium14/boot-ut-675fd590.img`. `065ee6e5…` is kept as `out/halium14/boot-ut-065ee6e5.img`.
- Current `boot_b` (updated 2026-11-11): `065ee6e5…` (kernel `#14`; USB MTP, the media log levels, the microSD mount options and the GNSS service), written and confirmed on 2026-11-11. Earlier: `a706816c…` (log levels). Before it: `7d432e5d…` (USB MTP), kept as `out/halium14/boot-ut-7d432e5d.img`. Before it: `e3d83362…` (MMS over Wi-Fi and the sensors fixes of item 1), kept as `out/halium14/boot-ut-e3d83362.img`. `15c0d147…` (MMS only) is kept as `out/halium14/boot-ut-15c0d147.img`.
- Ubuntu Touch 24.04-2.x, Halium 14, crDroid 14 vendor.
- The deferred system update work is at the end of `docs/roadmap-hardware.md`.

## Already confirmed working

See `docs/roadmap-hardware.md`, "Already confirmed working". In short:
- display, touch, GPU, brightness, charging, vibration;
- speaker, Wi-Fi;
- SIM, 5G data, calls (3G and IMS), MMS (also on Wi-Fi);
- Bluetooth audio and calls, wired headsets (3.5 mm and USB);
- rear and front camera photos and video.

Done here: rotation and all sensors (item 1), USB MTP with adb alongside (item 2), hardware video decoding in the Media Player (item 3, it already worked), microSD card (item 4), location (item 7).

## Fix order

1. Rotation and sensors. Nothing turns the screen, and no app gets an accelerometer, light, proximity or compass reading. Proximity during calls (screen off at the ear), automatic brightness, and photo orientation in the camera all depend on it.
2. USB file transfer (MTP). Done 2026-11-10 (kernel patch 0007). Before the fix, turning on MTP in Settings turned developer mode off, adb disappears, USB falls back to charging only, and the PC never shows the phone. Added on 2026-11-10, ahead of the decoders.
3. Hardware video and audio decoding. Checked 2026-11-10: already working. H.264, VP9 and HEVC (also the camera's own recordings) play in the Media Player on Qualcomm's Codec2 hardware decoders, with zero-copy output to `hybrissink`. Video in Morph (QtWebEngine) is software-decoded, with no hardware path on this stack (2026-11-11). media-hub's own CPU use: per-frame debug logging from Halium's media compat layer was turned off (about 8 % of a core saved at 30 fps); the rest is inherent.
4. MicroSD card. Added and done 2026-11-11. Detection, mount, MTP, the media scanner, speed and integrity were already fine. Fixed: a fixed 100 ms per written file on FAT cards (udisks' vfat `flush`), now 6.6 ms per file including sync.
5. Camera leftovers. Skipped 2026-11-11: already working (user). Flash and torch, tap-to-focus, zoom, and the barcode reader have not been tested (`docs/roadmap-hardware.md` item 7, "Still open or untested"). Flashlight toggle in the battery indicator: added 2026-11-12 (`stone-torch.service`, the camera HAL's torch mode).
6. Power. Skipped 2026-11-11: already working (user). Suspend and deep sleep, standby battery drain, and the battery level and health readings in Settings. Not checked yet.
7. Location (GNSS). Pure Maps found no position (2026-11-11). The engine was fine but always cold-started: Qualcomm's `xtra-daemon` was not enabled, and the HAL was never told about the network, so there was no time or XTRA data. Fixed with `stone-gnss-netstate.service` (an indoor fix in about 30 s, 4 m accuracy). Done 2026-11-11: confirmed in Pure Maps. SUPL is left out (unimplemented upstream).
8. Fingerprint reader. Done 2026-11-11: the vendor HAL was up, but the packaged biometryd 0.4.0 aborted on every D-Bus request (an Ubuntu-only dbus method that fails here). Fixed with biometryd main plus a patch for this kernel's missing D-Bus label, replacing only the daemon. Enrollment and lock-screen unlock work (user, confirmed in the logs).
9. Smaller items:
   - the second SIM slot: done 2026-11-11 (data, VoLTE and calls worked; call audio needed the SIM 2 DSP voice session, `VoiceMMode2`);
   - call volume keys (they changed the media volume): done 2026-11-11, now the codec gain of the call route (earpiece, speaker, 3.5 mm);
   - wideband Bluetooth calls (mSBC): done 2026-11-11 (kernel patch 0009, the router's SLIMbus rate, `enable_msbc=true`);
   - the IR emitter and NFC, if the hardware has them. NFC: this unit (`sunstone_cn`) has none; nfcd is gated on the chip being present (done 2026-11-11). IR: done (`stone-ir` over standard LIRC; a Samsung TV switched off and on).
10. GPU and graphics APIs. Checked 2026-11-11: the UI uses the intended path (Mir `graphics-android2` with Adreno GLES 3.2 through libhybris), and Vulkan 1.1 works through `libvulkan1-hybris`. Desktop OpenGL is software only (Mesa llvmpipe). No fix needed for the system; options for hardware desktop GL are recorded.
11. 120 Hz display. Added 2026-11-11: the panel ran at 120 Hz, but the UI never got past 60 fps. Two causes: the system compositor waited for the previous frame's present fence after every frame (two vsyncs per frame), and the GPU governor kept the GPU at 266 MHz while scrolling. Fixed with `stone-display-setup.service` and kernel `#15` (the 60 Hz panel command). The 60/120 Hz choice is in System Settings > Brightness (and `stone-refresh-rate`). Done 2026-11-11.

12. Wi-Fi network list. Added 2026-11-12: every network appeared twice in the network indicator and in System Settings, because NetworkManager also managed the driver's second station interface `wlan1`. Fixed by leaving `wlan1` unmanaged. Done 2026-11-12.

   None of these has been checked yet.

## 1. Rotation and sensors

Goal: the screen rotates with the phone. Apps get the accelerometer, gyroscope, magnetometer, light and proximity sensors through sensorfw, and the services built on them work: proximity during calls, and automatic brightness when it is turned on.

What is seen: the screen never rotates. `sensorfwd.service` never comes up. It hangs in `activating (start)` until systemd's 90 s start timeout kills it, and then it is restarted (restart counter 11 after about 15 minutes). The camera app logs "There is no sensor manager yet". Item 7 of `docs/roadmap-hardware.md` read that, and init's lookups for HIDL `android.hardware.sensors@2.x/1.0`, as "there is no sensors HAL". That was wrong (see below).

### Planned steps

1. Find out what the vendor provides for sensors and why sensorfwd does not finish starting.
2. Fix it in the image (rootfs overlay), and first as a live install.
3. Check that readings arrive. Then the user checks rotation, proximity in a call, and automatic brightness.

### Sensors: what fixed it

- The vendor sensors HAL is running. It is the **AIDL** `android.hardware.sensors-service.xiaomi-multihal` (`vendor.sensors-hal-multihal`), registered as `android.hardware.sensors.ISensors/default` on `/dev/binder`. The supporting services `vendor.sensors`, `vendor.sensors.qti` and `sensorscal-hal-1-0` are running. There is no HIDL sensors HAL, which explains the HIDL lookups.
- UBports' sensorfw (`sensorfw-qt5` and `libsensorfw-qt5-hidl` 0.15.1) supports AIDL: the gbinder-based "hidl" adaptor library has `Connected to sensor AIDL service`. `/etc/sensorfw/sensord.conf.d/30-hidl.conf` already selects the `hidl*adaptor` plugins, so the configuration was right.
- The cause is libgbinder's configuration:
  - `/etc/gbinder.conf` contains only comments, there is no `/etc/gbinder.d/`, and nothing sets `ApiLevel`.
  - libgbinder therefore falls back to its default `aidl` protocol on `/dev/binder` (Android 9/10 era).
  - Android 14's servicemanager does not understand that. Measured as phablet with python3-gbinder (`/dev/binder` is mode 666):

    | service manager / RPC protocol | services listed | `ISensors/default` |
    | --- | --- | --- |
    | `aidl` / `aidl` (default) | 0 | not found |
    | `aidl3` / `aidl3` | 49 | found |
    | `aidl4` / `aidl3` | 49 | found |
    | `aidl5` or `aidl6` / `aidl3` | 0 | not found |

    sensorfwd therefore waited forever for the HAL and never sent systemd `READY=1`.
  - libgbinder 1.1.52's `ApiLevel = 34` uses its API 33 preset: `aidl3` and `aidl3` on `/dev/binder` and `/dev/vndbinder`, and `hidl` on `/dev/hwbinder`. That matches the working row.
- The HIDL users of gbinder were never affected, because `/dev/hwbinder` is `hidl` in every preset: ofono's binder plugin, the netd stub, and bluebinder.
- Checked before changing anything: sensorfwd was run by hand in an unprivileged user and mount namespace (`unshare -rm`, `gbinder.conf` bind-mounted, a private `/run`). It connected to the AIDL service and initialized the HAL. It found every sensor, then stopped as expected at the D-Bus registration that the private `/run` hid:

  | Type | Sensor |
  | --- | --- |
  | Accelerometer, gyroscope (plus uncalibrated) | `icm4x6xx` |
  | Magnetometer (plus uncalibrated) | `qmc630x` |
  | Light, proximity (sensorfw takes the wakeup proximity) | `tmd2755` |
  | Fused | gravity, linear acceleration, rotation vector, game rotation vector, geomagnetic rotation vector |
  | Screen orientation | `Device Orientation` (type 27, which `hidlorientationadaptor` uses) |
  | Others | step detector and counter, significant motion, tilt, pick-up, stationary/motion detect, Xiaomi private `Aod` and `Touch Sensor` |

Fix:
- `boot/ut-init/rootfs-overlay/usr/share/stone/gbinder-api34.conf`: `[General] ApiLevel = 34`.
- `boot/ut-init/rootfs-overlay/etc/systemd/system/sensorfwd.service.d/zz-stone-gbinder.conf`: `BindReadOnlyPaths=/usr/share/stone/gbinder-api34.conf:/etc/gbinder.conf` and `After=lxc-android-config.service`. Only sensorfwd sees this config.

Why the config is not global: `audiosystem-passthrough` also uses gbinder and registers `media.audio_flinger` on `/dev/binder`. With the default protocol that registration fails today. With a global `ApiLevel` it would succeed, and camera_service's libaudioclient would start talking to it. Changing that is a separate decision with its own tests (calls and camera recording).

Live install without a flash: `tools/phone-debug/stone-sensors-install.sh` (sudo). Readings without the UI: `QT_QPA_PLATFORM=minimal QT_SELECT=qt5 qmlscene /home/phablet/sensors-monitor.qml` (`tools/phone-debug/sensors-monitor.qml`) prints orientation, accelerometer, light, proximity, gyroscope and magnetometer once a second for 6 s, through QtSensors' sensorfw backend.

### Proximity during calls and automatic brightness: what fixed it

After the sensorfwd fix, the user confirmed rotation works. Proximity at the ear did nothing, and Settings → Brightness & Display had no "Adjust automatically" switch (the Nothing phone on 24.04-1.x has one). Both come from repowerd (`repowerd 2025.09`), not from Lomiri:

- **Proximity and the light sensor.** repowerd creates `SensorfwProximitySensor` and `SensorfwLightSensor` once, at start. If that fails, it logs "Failed to create Sensorfw…" and keeps a `NullProximitySensor`/`NullLightSensor` until it is restarted. At this boot, repowerd started at 12.2 s, while sensorfwd was still broken, and only became active at 32.5 s, apparently after about 20 s of trying sensorfw. Fixing sensorfwd later does not help the running repowerd.
  - Fix: `etc/systemd/system/repowerd.service.d/zz-stone-sensorfw.conf` (`Wants=`/`After=sensorfwd.service`). sensorfwd is `Type=notify` and reports ready once the HAL answers. The HAL registers at about 13.3 s (`ro.boottime.vendor.sensors-hal-multihal`), so the wait is short. The sensorfwd drop-in caps `TimeoutStartSec` at 30 s so that a missing HAL cannot hold repowerd (screen power) for 90 s. graphical.target and `keep-display-on-during-boot` depend on repowerd.
- **The switch in Settings and the curve.** repowerd reads `/usr/share/repowerd/device-configs/config-default.xml` and then `config-<deviceinfo Name>.xml` (`stone`). The default has `config_automatic_brightness_available=false` and no curve. repowerd reports `autobrightness_supported` from that flag, and builds its lux → brightness spline from `autoBrightnessLevels` and `autoBrightnessLcdBacklightValues` (integers, N levels and N+1 values, at most 255, in units of `screenBrightnessSettingMaximum`, which is 255).
  - Fix: `usr/share/repowerd/device-configs/config-stone.xml`, generated by `tools/repowerd-config-from-overlay.py` from the vendor's `/vendor/overlay/FrameworksResOverlayStone.apk` (the same values Android uses):
    - `config_automatic_brightness_available=true`;
    - 107 `config_autoBrightnessLevels` (1 to 100000 lux);
    - 108 `config_autoBrightnessDisplayValuesNits` (3.5 to 1000 nits), converted to 1..255 through the overlay's `config_screenBrightnessNits [4.5, 1000]` ↔ `config_screenBrightnessBacklight [1, 255]` (piecewise linear; checked to be monotone, from 1 to 255);
    - `config_screenBrightnessDim=13`.
  - The script has its own small `resources.arsc` parser, because androguard 4.1.2 fails on Android 14 aapt2 output (16-bit entry offsets, type flags `0x2`).
  - The panel is `/sys/class/backlight/panel0-backlight` (`max_brightness` 2047). repowerd scales value/255 onto it.

Readings checked over adb through QtSensors (sensorfw backend), phone lying flat: orientation `5` (face up), accelerometer `-0.06, 0.10, 9.92` m/s², gyroscope about 0, magnetometer about `-18, 3, 5` µT, proximity `near=false`. Light read `0.0` lux; not judged yet (dark room, or the sensor only reports on change).

### Status (2026-11-10)

| Part | State |
| --- | --- |
| sensorfwd | Working (live install, 22:07) |
| Screen rotation | Working (user confirmed) |
| Proximity in calls | Working (user confirmed): the screen turns off at the ear |
| Automatic brightness | Working (user confirmed): "Adjust automatically" is there and follows the light |
| Light sensor readings | Working (the `0.0` in the first reading was the light at that moment, not a fault) |
| Compass | Readings arrive; direction against a real compass not checked |
| Photo orientation (camera) | Not tested |
| In the image | `e3d83362…`, written and booted on 2026-11-10 (the user rebooted after flashing it) |

### Still open (sensors)

- Lomiri picked up sensorfwd without a restart (rotation worked right after the live install). repowerd does not (see above). The camera app has not been checked.
- The automatic brightness curve is Android's, without Android's per-user adjustment. If it is too dim or too bright indoors, `config_autoBrightnessLcdBacklightValues` can be scaled in the generator.
- Axis orientation: `30-hidl.conf` sets an identity matrix for the accelerometer and `-1,0,0,0,1,0,0,0,1` for the magnetometer. The compass direction still has to be checked against a real compass.
- Android's own `sensorservice` (Halium system) is also a client of the same HAL. Whether the multihal serves both clients, or the last `initialize()` wins, has not been checked. Only sensorfw matters here.
- Which process made the once-a-second HIDL `sensors@2.x/1.0` lookups has not been traced. Check after the fix whether they stop.

### Events

- 2026-11-10: `sensorfwd` was timing out on every start (restart counter 11). The vendor HAL is AIDL and runs fine. python3-gbinder showed that servicemanager answers only with the `aidl3` protocols, while libgbinder had no `ApiLevel` and used `aidl`. A hand-run sensorfwd with `ApiLevel = 34` found all sensors. The fix (an API 34 `gbinder.conf` bind-mounted for sensorfwd only) was written to the overlay. `stone-sensors-install.sh`, `sensors-monitor.qml`, `gbinder-api34.conf` and `zz-stone-gbinder.conf` were pushed to `/home/phablet`. Then the user ran `stone-sensors-install.sh`: `sensorfwd: active`, "Hybris sensor manager initialized".
- The user: auto-rotation works perfectly. Proximity at the ear in a call does not turn the screen off. There is no "Adjust automatically" switch under Brightness & Display, and automatic brightness does not work by default. Under Android the sensors work.
- Cause for both: repowerd (see "Proximity during calls and automatic brightness: what fixed it"). Added the repowerd drop-in, the 30 s sensorfwd start timeout, `config-stone.xml` and `tools/repowerd-config-from-overlay.py`. `stone-sensors-install.sh` now installs these too and restarts sensorfwd and then repowerd. Pushed.
- The user ran the new install and confirmed all three tests: the screen turns off at the ear in a call, Settings now has "Adjust automatically", and automatic brightness follows the light.
- New `boot-ut.img` SHA256 `e3d83362742ffbb39b97201f6e3509055d24bcde1af08cc2bed9cdd2c1afea9e` (kernel `#13`, unchanged; everything in `15c0d147…` plus `usr/share/stone/gbinder-api34.conf`, `sensorfwd.service.d/zz-stone-gbinder.conf`, `repowerd.service.d/zz-stone-sensorfw.conf` and `usr/share/repowerd/device-configs/config-stone.xml`). The ramdisk was checked: all of them are in it, with no `__pycache__`. The files installed live on the phone are byte-identical to the repository's. Not yet written. Writing it changes nothing on this phone, because the live install already put the same files in place. A clean boot with it is the remaining check that repowerd gets the sensors from boot.

## 2. USB file transfer (MTP)

Goal: with MTP on, the PC's file manager shows the phone and can copy files both ways. Developer mode (adb) keeps working alongside it (`mtp_adb`).

What is seen (user, 2026-11-10, image `e3d83362…`):
- Turning on USB MTP in Settings turns developer mode off, and adb disappears.
- Turning developer mode back on leaves USB in charging only.
- With MTP on, the PC never shows the phone.

### USB MTP: what fixed it

- usb-moded (`0.86.0+mer69`, `usb-moded-ubports-config`) builds its modes from configfs functions. `/etc/usb-moded/10-ubports-defaults.ini` has `function_mtp = mtp.mtp` and `function_adb = ffs.adb`. The `mtp` mode uses `sysfs_value = mtp`, and `mtp_adb` uses `mtp,adb` (it also restarts `adbd`).
- `mtp-server` (`0.1.0`, user unit, started by `mtp-server-usb-moded-watcher` when the mode is `mtp` or `mtp_adb`) only knows `/dev/mtp_usb`: its strings are `/dev/mtp_usb` and "Error opening /dev/mtp_usb, aborting now". It has no FunctionFS backend.
- `/dev/mtp_usb` and the `mtp` configfs function come from Android's kernel gadget `f_mtp` (`CONFIG_USB_CONFIGFS_F_MTP`). This kernel had no such option and no `f_mtp.c`. The Android common kernel removed `f_mtp` around 4.14/4.19, when Android moved MTP into userspace over FunctionFS. Of ACK's branches, only `deprecated/android-4.9*` still has it, and UBports' generic `android12-5.4-halium` kernel does not have it either. In `/sys/kernel/config/usb_gadget/g1/functions` there were only `ffs.adb`, `mass_storage.usb0` and `rndis.usb0`.
- So `mkdir functions/mtp.mtp` fails, usb-moded cannot enter `mtp` or `mtp_adb`, and it falls back. That fallback is what turned developer mode off and left USB on charging only (the mode afterwards was `charging_only_adb`).

Fix (kernel `#14 SMP PREEMPT Tue Nov 10 22:52:30 EST 2026`, `kernel/patches/0007-usb-gadget-add-f_mtp-for-ubuntu-touch.patch`):
- Qualcomm's msm-4.19 `f_mtp.c` and `include/{linux,uapi/linux}/usb/f_mtp.h` (CodeLinaro `clo/la/kernel/msm-4.19`, `kernel.lnx.4.19.r32-rel`), the closest relative of this msm-5.4 tree.
- Kconfig gains `USB_F_MTP` (tristate) and `USB_CONFIGFS_F_MTP` (bool, `select USB_F_MTP`, `depends on USB_CONFIGFS`). The function Makefile gains `usb_f_mtp`.
- One source change: the ChipIdea 16K Tx limit (`gadget->is_chipidea`, a msm-4.19-only field) was removed; this SoC's controller is DWC3 (`4e00000.dwc3`).
- PTP (`f_ptp.c`) is not added.
- The driver is self-contained: it answers its own control requests (`f->setup` = `mtp_ctrlreq_configfs`), so `configfs.c` needs no hook. It uses `vfs_read`/`vfs_write` on kernel buffers from its workqueue, which is still fine on 5.4 (workers run with `KERNEL_DS`).
- `kernel/config/halium-sunstone.fragment` gains `CONFIG_USB_CONFIGFS_F_MTP=y`. On `build-14/.config` it was turned on with `scripts/config --enable USB_CONFIGFS_F_MTP` plus `olddefconfig`. The only `.config` changes are `CONFIG_USB_CONFIGFS_F_MTP=y` and `CONFIG_USB_F_MTP=y`.
- The build had no errors. The only warning is the existing one in `drivers/bluetooth/btfm_slim.c`. `git apply --check -R` of patch 0007 on the tree is clean.

Already in place on the rootfs (nothing new needed): `85-android.rules` gives `/dev/mtp_usb` to `root:plugdev 0660`, and phablet is in `plugdev`. The usb-moded function names match the new kernel function, `mtp`.

New image: `boot-ut.img` SHA256 `7d432e5dd15411b69863850e0b84d52cb48eebf1d6c185220a2846c586897709`. It contains the `#14` Image (`418e3063…`, byte-identical to `kernel/build-14/arch/arm64/boot/Image`), and its rootfs overlay is the same as `e3d83362…` (kept as `out/halium14/boot-ut-e3d83362.img`; the `#13` Image as `out/halium14/Image-13`).

### Status (2026-11-10)

| Part | State |
| --- | --- |
| Kernel `f_mtp` | `#14`, in `7d432e5d…`, written and booted |
| `mtp` / `mtp_adb` mode switch | Working (user confirmed): developer mode stays on and adb works alongside MTP |
| PC file manager sees the phone | Working (user confirmed) |
| Copy both ways | Working (user confirmed) |

### Events

- 2026-11-10: the user reported the symptoms above. The usb-moded config, the mode files and the gadget functions were read on the phone (mode `charging_only_adb`; no `mtp.mtp`; no `/dev/mtp_usb`). The kernel config has no `F_MTP`, and the tree has no `f_mtp.c`. Ported `f_mtp` from msm-4.19 as patch 0007, built `#14`, and built `boot-ut.img` `7d432e5d…`. Waiting for the user: flash, then test MTP, MTP with developer mode, and file copies from the PC.
- The user flashed `7d432e5d…` and confirmed: MTP file transfer works both ways, and adb works alongside MTP. Item 2 is done.

## 3. Hardware video and audio decoding

Goal: videos (the camera's own recordings, files, and web video) play smoothly, using the Android codecs through the hybris media stack rather than software decoding.

What is seen: nothing was known before the test. Known from earlier items:
- media-hub runs as a patched copy (`/usr/lib/stone/media-hub-server`, `docs/roadmap-hardware.md` item 3).
- The camera records through `camera_service`/`minimedia` in the container.
- `mediaextractor` aborts on every boot (tombstones).

### Result (2026-11-10): hardware decoding already works, no fix needed

Test files (the user's, in `~/Videos`): the same clip, 226 s, once as 720p H.264 (`…_AVC_720P.mp4`, 18 MB) and once as 1080p VP9 in MP4 (38 MB). Both have AAC audio.

The decoders: when the `gsthybris` plugin first built its registry (`~/.cache/gstreamer-1.0/registry.aarch64.bin`), Android's MediaCodec list reported Qualcomm's Codec2 hardware decoders. GStreamer created `amcviddec-*` elements from them:
- `c2.qti.avc.decoder` (plus `.low_latency`);
- `c2.qti.hevc.decoder` (plus `.low_latency`);
- `c2.qti.vp9.decoder`.

The vendor service behind them is `media.hwcodec` (`/vendor/bin/hw/vendor.qti.media.c2@1.0-service`). The software fallbacks `openh264dec` (`libgstopenh264`) and `vp9dec` (`libgstvpx`) are also installed.

Direct test over adb, `tools/phone-debug/gst-decode-test.py` (ctypes on libgstreamer, because the rootfs has no `gst-launch-1.0` and no Gst typelib), to `fakesink sync=false`:

| Pipeline | Result | Speed | CPU |
| --- | --- | --- | --- |
| `h264parse ! amcviddec-c2qtiavcdecoder` | whole file to EOS, 6792 frames | 197 fps | client 15 s user + 9.3 s sys, `media.hwcodec` 16.8 s, in 20 s |
| `vp9parse ! amcviddec-c2qtivp9decoder` | whole file to EOS, 6787 frames | 112 fps | |
| `h264parse ! openh264dec` (software) | | 194 fps | 19.8 s user, `media.hwcodec` 0.01 s, in 20 s |
| `vp9parse ! vp9dec` (software) | | 90 fps | |

Without a sink surface, gst-amc copies every frame out of the decoder, so the hardware path costs as much CPU here as software decoding. Speed alone does not tell them apart on these cores. `media.hwcodec` doing the work does.

Gotcha for test tools: the hybris plugin loads libhybris's Android linker (`/usr/lib/aarch64-linux-gnu/libhybris/linker/q.so`) with `dlopen`, which needs static TLS. A Python process fails with "Failed to load hybris linker for Android SDK version 29: … cannot allocate memory in static TLS block", even with `LD_PRELOAD=libtls-padding.so`, which is what media-hub uses. `GLIBC_TUNABLES=glibc.rtld.optional_static_tls=65536` fixes it for the test.

Real playback: the user played each file for about 50 s in the Media Player app (`lomiri-mediaplayer-app` → media-hub): smooth, sound present and in sync, correct picture. A temporary user drop-in for media-hub (`GST_DEBUG=…amc*:4,hybris*:4,decodebin*:4,GST_ELEMENT_FACTORY:4`, removed afterwards) showed:
- playbin built `qtdemux → h264parse → amcviddec-c2qtiavcdecoder` and `qtdemux → vp9parse → amcviddec-c2qtivp9decoder`;
- the video sink was `hybrissink`, which gives the decoder an Android surface (`SurfaceTextureClientHybris`; the decoder waits for its texture id), so frames are not copied;
- audio was `aacparse → faad → pulsesink`;
- no software video decoder was created. The only errors, "Downstream returned flushing", fall at the moments playback was stopped.

CPU during playback (`tools/phone-debug/media-cpu-sample.sh`, ms of CPU per second):

| File | media-hub | `media.hwcodec` | player app | all 8 CPUs |
| --- | --- | --- | --- | --- |
| 720p H.264, 44 s | 451 | 146 | 243 | 2198 |
| 1080p VP9, 49 s | 504 | 174 | 259 | 2253 |

1080p VP9 (2.25× the pixels of 720p) costs about the same as 720p H.264, which fits the hardware doing the decoding. Logs: `out/halium14/logs/media-hw-decode/` (gitignored).

Second round, the same day: HEVC and the camera's own recordings.
- Files:
  - `2026-11-10 23-41-08_1080p60_HEVC.mp4`: `hev1`, 1920x1080, 216 s, 60 fps, AAC.
  - A new camera recording, `camera.ubports/video20261110_234703163.mp4`: `avc1`, 1920x1080, 12.1 s, 286 frames (just under 24 fps), AAC.
- Direct decodes, both to EOS:
  - `h265parse ! amcviddec-c2qtihevcdecoder`: 12951 frames in 110.5 s (119 fps, twice real time for 60 fps);
  - `h264parse ! amcviddec-c2qtiavcdecoder`: 286 frames (114 fps).
- The user played the HEVC file for over a minute, and the recording to its end, in Media Player: smooth, no issues. In the media-hub log, playbin built `h265parse → amcviddec-c2qtihevcdecoder` and `h264parse → amcviddec-c2qtiavcdecoder`, both into `hybrissink` with a `SurfaceTextureClientHybris` pool. No software video decoder was created.
- At the end of the recording, gst-amc logs `ERROR … Unexpected condition output buffer index 0` and then `dec_loop, flow_error, EOS`. That is Codec2's final buffer with the end-of-stream flag. The loop stops with `GST_FLOW_EOS`, and playback ends normally; the direct decodes end in a clean EOS too. Media Player then rebuilds the pipeline at the start of the clip, as it does after every finished video. Cosmetic.

| File | media-hub | `media.hwcodec` | player app | all 8 CPUs |
| --- | --- | --- | --- | --- |
| 1080p60 HEVC, 92 s | 592 | 269 | 411 | 2665 |
| camera 1080p H.264, 11 s | 428 | 147 | 198 | 2069 |

HEVC at 60 fps costs more mostly because it delivers twice the frames. Logs: `gst-hevc-camera.log`, `cpu-hevc-camera.log` in the same directory.

Morph browser (2026-11-11): YouTube "Never Gonna Give You Up", 1080p VP9, looping. **Software decoding.**
- Morph uses QtWebEngine (`libQt6WebEngineCore.so.6.10.2`, Chromium). It does not use GStreamer or media-hub, so it never reaches the Codec2 decoders.
- 10 s CPU sample during playback:
  - renderer (`QtWebEngineProcess --type=renderer`): about 1.8 cores. Four `ThreadPoolForeground` workers run at about 300 ms/s each, `Media` at about 85, `VideoFrameCompositor` at about 40.
  - `morph-browser`, where the GPU compositing runs (no separate GPU process; Adreno EGL through libhybris): about 0.5 core.
  - Audio utility process: about 27 ms/s.
  - lomiri and lomiri-system-compositor: about 0.1 core each.
  - `media.hwcodec`: 0. media-hub: 0.
- The renderer has `/usr/lib/aarch64-linux-gnu/libvpx.so.9.0.0` and `libopenh264.so.2.4.1` loaded: Ubuntu's QtWebEngine decodes with the system libvpx and openh264. No process has `libva` or a V4L2 decoder loaded.
- Why: on Linux, Chromium's only hardware video decode path is VA-API (its V4L2 decoder is built for ChromeOS only). There is no VA-API driver for this Adreno/Android (hybris) stack, so there is nothing to turn on. Getting Morph onto the hardware decoders would need either a VA-API driver that wraps Android's Codec2/MediaCodec through libhybris, or a QtWebEngine build with Chromium's V4L2 decoder pointed at the vendor `msm_vidc` V4L2 devices (UBWC/ION buffers, not a mainline venus driver). Neither exists; both are large projects outside this port.
- In practice: 1080p VP9 plays in software at about 1.8 cores in the renderer, on top of compositing. A lower YouTube resolution reduces this. Forcing H.264 does not help, because that is software (openh264) too.

### Still open (media)

- media-hub's own CPU use (about 45 to 50 % of one core during playback): investigated on 2026-11-11, see "media-hub CPU during playback" below. One real waste was found and fixed (per-frame debug logging); the rest is how this path works.
- Video in Morph is software-decoded (see above). Not fixable within the port.
- Not tested:
  - hardware audio decoding. AAC is decoded in software (`faad`), which is normal and cheap.
- `mediaextractor` still aborts at every boot. Playback goes through GStreamer's `qtdemux`, so nothing has been seen to depend on it.

### media-hub CPU during playback

Profile (`tools/phone-debug/media-hub-profile.sh`, as phablet; no perf or gdb on the phone). It waits for `media.hwcodec` to start decoding, then records per-thread CPU over 20 s, `strace -c -f` for 10 s, and `strace -tt` of the busiest thread. The user played the 720p H.264 file in Media Player.

- media-hub: 515 ms/s, spread over about 15 threads:
  - `ALooper` 91 (MediaCodec's message loop);
  - `vqueue:src` 70;
  - two `multiqueue4:src` threads, 70 and 46;
  - `HwBinder` 48;
  - `threaded-ml` 46 (PulseAudio mainloop);
  - `amcvideodec-c2q…` 44;
  - `aqueue:src` 34;
  - `qtdemux0:sink` 15;
  - `CodecLooper` 12.
- The player app took 263 ms/s (`QSGRenderThread` 192), `media.hwcodec` 168, and all CPUs about 2.2 cores.
- No single thread runs away. The `ALooper` trace is `futex`/`clock_gettime`/binder `ioctl` (Android's own looper).
- The syscall profile stood out: in 10 s, 10,581 `writev`, 10,583 `getuid`, 10,582 `gettid` and 9,639 `getpid`. That is Android liblog writing about 1,000 lines/s.

What the log lines are (`strace -e writev` of the same decode in `gst-decode-test.py`):
- Halium's `libmedia_compat_layer` (the MediaCodec bridge that `amcviddec` uses) logs every call at DEBUG/VERBOSE under the tags `MediaCodecLayer` and `MediaFormatLayer`: about 23 lines per decoded frame (`media_codec_dequeue_output_buffer…`, `Dequeued output buffer:`, `size: 1382400`, `info->flags: 0`, …). In 12 s there were 2043 D and 1057 V lines from `MediaCodecLayer`.
- Each line is written twice: to the logd socket, and with the `lg` header to pmsg.
- liblog drops lines below `log.tag.<TAG>`, and nothing set it (`log.tag` and `persist.log.tag` are empty, `ro.debuggable=1`). phablet can set these properties with `/usr/bin/setprop`.
- With `log.tag.MediaCodecLayer=I` and `log.tag.MediaFormatLayer=I`: 147 log writes in 12 s (one-off Codec2 start-up messages) instead of 3259.

A/B, real-time decode (`sync=true`, 30 fps, 20 s, two rounds each):

| Codec logging | Decoding process user + sys | `logd` | All CPUs |
| --- | --- | --- | --- |
| DEBUG/VERBOSE (as shipped) | 8.3 s, 8.0 s | 690 ms, 680 ms | 1060, 1067 ms/s |
| `I` | 7.4 s, 7.2 s | 130 ms, 110 ms | 987, 966 ms/s |

That saves about 85 ms of CPU per second of 720p30 playback (about 8 % of a core), mostly kernel time in the decoding process plus logd. It scales with the frame rate (twice as much at 60 fps).

Fix: `stone-android-log-levels.service` (oneshot, `After=lxc-android-config.service`), which runs `usr/lib/stone/android-log-levels.sh`. The script waits up to 120 s for Android's property service, then sets `log.tag.MediaCodecLayer=I` and `log.tag.MediaFormatLayer=I`. INFO, WARN and ERROR lines of those tags are kept. Only these two tags are changed. A global `log.tag=I` would save more, but it would also hide every DEBUG line in the container (camera and radio debugging used them).

The rest of media-hub's cost (`fakesink` decodes in `gst-decode-test.py` cost about the same, so it is not media-hub itself):
- GStreamer's queues and demuxer;
- MediaCodec's looper;
- per-buffer binder IPC to the Codec2 service;
- PulseAudio.

Reducing that would mean changing the hybris GStreamer plugin or Android's MediaCodec. Not pursued.

Image: `boot-ut.img` SHA256 `a706816cfcdcbc2f6b2277ac805d0e991e626731a3cb11617264fc14153a7ca0` (kernel `#14`, unchanged; adds the service). `7d432e5d…` is kept as `out/halium14/boot-ut-7d432e5d.img`. Written and confirmed after a reboot on 2026-11-11.

### Events

- 2026-11-10: the user put the two test files on the phone. The registry listed the `c2.qti` decoders. Direct decodes worked for both files on the hardware decoders, and `media.hwcodec` did the work. The user played both files in Media Player (smooth, in sync, correct picture), and the GStreamer log showed `amcviddec-c2qti{avc,vp9}decoder` into `hybrissink` with no software video decoder. No fix was needed. The debug drop-in, the sampler and the temporary links were removed afterwards. `gst-decode-test.py` and `media-cpu-sample.sh` are in `tools/phone-debug/`, with copies in `/home/phablet`.
- 2026-11-10: second round. A 1080p60 HEVC file and a new 1080p camera recording decode in hardware, both directly and in Media Player (`amcviddec-c2qtihevcdecoder` and `amcviddec-c2qtiavcdecoder` into `hybrissink`). The user confirmed smooth playback. The gst-amc error at the recording's end is the EOS buffer and is harmless. The debug drop-in and the sampler were removed again.
- 2026-11-11: Morph and YouTube 1080p VP9 (looping): software, libvpx in the renderer (about 1.8 cores), with `media.hwcodec` idle. QtWebEngine has no hardware decode path here (Chromium on Linux would need VA-API).
- 2026-11-11: profiled media-hub during 720p playback (user played the file). Found about 1,000 Android log lines/s from `MediaCodecLayer` (DEBUG/VERBOSE, per frame). `log.tag.MediaCodecLayer=I` and `log.tag.MediaFormatLayer=I` save about 85 ms/s (A/B measured). Added `stone-android-log-levels.service` and built `a706816c…`. Not yet written.
- 2026-11-11: the user wrote `a706816c…` and rebooted. Kernel `#14`. `stone-android-log-levels.service` was `active (exited)`, status 0, at 12.7 s (lxc-android-config at 12.1 s). `log.tag.MediaCodecLayer=I` and `log.tag.MediaFormatLayer=I`. The installed files are byte-identical to the overlay. A traced 12 s decode right after the boot: 290 log writes (both copies), 8 of them `MediaCodecLayer` INFO lines, instead of about 6500 before. Fix confirmed.

## 4. MicroSD card

Goal: a card in the slot is mounted for phablet, works over MTP and in the apps (media scanner), reads and writes at the card's speed, and keeps its data intact.

What is seen (user, 2026-11-11): the user put a card in and formatted it with the built-in tools. It was detected and was reachable over MTP.

### Checked (2026-11-11, image `a706816c…`)

| Part | Result |
| --- | --- |
| Card | `SD64G`, SD, manfid `0x9f`, oemid `0x5449`, made 09/2022, 62.5 GB (122167296 sectors). SSR: Class 10, UHS U1, V10 |
| Controller | `4784000.sdhci` (`mmc1`), block device `/dev/mmcblk1` (`brw-rw---- root disk`), scheduler bfq |
| Filesystem | FAT32, label empty, UUID `A0F3-F9B7`, on the whole device (no partition table) |
| Mount | udisks2 2.10.1, `/media/phablet/A0F3-F9B7`, `vfat rw,nosuid,nodev,relatime,uid=32011,gid=32011,fmask=0022,dmask=0022,shortname=mixed,showexec,utf8,flush,errors=remount-ro`. 59 GB free |
| MTP | Works (user) |
| Media scanner | `mediascanner-service-2.0` indexes the card: a video copied to `…/Videos/` was in `~/.cache/mediascanner-2.0/mediastore.db` within 8 s, so Music, Gallery and Videos see card media |
| Sequential write | 18.8 MB/s (512 MiB random data, `dd oflag=direct conv=fsync`, bs 4M). U1 is rated for at least 10 MB/s |
| Sequential read | 45.7 MB/s (`iflag=direct`). That is above the about 23 MB/s ceiling of 4-bit High Speed, so the card runs in a UHS-I mode. The SSR's first byte (bus width 0) was a false alarm |
| Data integrity | SHA256 of the 512 MiB read back with direct I/O matches the source |
| Small files | **Slow: 101.6 ms per file** (200 × 64 KB in one process: 20.30 s in write+close, 0.02 s in sync). Internal ext4 takes 0.9 ms per file |
| Filesystems | Kernel has `vfat` and `exfat` (`CONFIG_EXFAT_FS=y`), plus `fuse`. No NTFS. `dosfstools` is installed, `exfatprogs` is not |

### Small files: what is wrong, and the fix

- The 100 ms is the vfat `flush` mount option. On every `close()` of a file opened for writing, `fat_file_release()` writes the file out and then sleeps `HZ/10`. The time all goes into close, not sync, and it is a fixed 100 ms, independent of the 64 KB size.
- Copying a folder of 1000 photos or songs to the card (MTP or a file manager) would spend at least 100 s just sleeping. Upstream Linux still has this sleep.
- `flush` comes from udisks 2.10's built-in `vfat_defaults=uid=$UID,gid=$GID,shortname=mixed,utf8=1,showexec,flush`. There was no `/etc/udisks2/mount_options.conf`. udisks' exFAT defaults have no `flush`.
- Android's vold mounts FAT cards without `flush`.
- Fix: `boot/ut-init/rootfs-overlay/etc/udisks2/mount_options.conf`, `[defaults] vfat_defaults=uid=$UID,gid=$GID,shortname=mixed,utf8=1,showexec`. That is udisks' default without `flush`. It applies at the next mount (reboot, or take the card out and back in).
- Trade-off: without `flush`, written data goes out with normal writeback (about 30 s) instead of at close, so pulling the card straight after copying can lose the most recent writes. The rule is to unmount (eject) first, as on Android.
- It also applies to FAT USB sticks on OTG.
- Live install: `tools/phone-debug/stone-sdcard-install.sh` (sudo), which installs the file from `/home/phablet/mount_options.conf`.

Result after the live install and re-inserting the card: the mount options are `…,shortname=mixed,showexec,utf8,errors=remount-ro`, without `flush`.

| Test | Before (`flush`) | After |
| --- | --- | --- |
| 200 × 64 KB, one process | write+close 20.30 s, sync 0.02 s: 101.6 ms/file | write+close 0.04 s, sync 1.29 s: **6.6 ms/file**, contents verified |
| Same on internal ext4 (reference) | 0.9 ms/file | 0.8 ms/file |
| 512 MiB `dd oflag=direct` write | 18.8 MB/s | 15.9 MB/s (direct I/O does not use `flush`; the card's own variation) |
| 512 MiB `dd iflag=direct` read | 45.7 MB/s | 45.7 MB/s |
| 512 MiB `cp` + `sync` (how a file manager copies) | — | 35.9 s (15 MB/s) |
| SHA256 of the 512 MiB on the card | matches | matches |

The real cost of a small file is now the card's own write time, flushed at `sync` (6.4 ms/file), instead of a sleep.

Image: `boot-ut.img` SHA256 `ec969650b803d156409dad34bd97e3a97508fc0fe32bdcad59af45e97136459e` (kernel `#14`, unchanged; adds `etc/udisks2/mount_options.conf`). The previous image is kept as `out/halium14/boot-ut-a706816c.img`. The live-installed `/etc/udisks2/mount_options.conf` is byte-identical to the overlay's, so writing the image changes nothing on this phone.

### Other findings (no change)

- The built-in formatter made FAT32, probably because `exfatprogs` (`mkfs.exfat`) is not installed. FAT32 cannot hold files of 4 GiB or more: long camera videos or large downloads to the card will fail at 4 GiB.
- Cards over 32 GB come formatted as exFAT from the factory. The kernel's exFAT driver and udisks' `exfat_defaults` mean such cards should mount, but this has not been tested with a real exFAT card. Without `exfatprogs`, the phone cannot check or repair exFAT, and its formatter cannot make it.
- The card has no partition table (a "superfloppy"). Linux, Android and Windows 10+ read that. Some cameras and older systems want an MBR partition.

### Status (2026-11-11)

| Part | State |
| --- | --- |
| Detection, mount, MTP, media scanner | Working |
| Sequential speed, integrity | Working (18.8 MB/s write, 45.7 MB/s read, checksum matches) |
| Small files | Fixed: 101.6 → 6.6 ms per file (live install, confirmed after re-inserting the card) |
| exFAT cards | Kernel support present; not tested with a real card |

### Events

- 2026-11-11: the user reported the card works (detected, MTP). Checked the device, the mount, the media scanner, speed and integrity (all fine) and small files (100 ms each, from vfat `flush`). Wrote `etc/udisks2/mount_options.conf` and `stone-sdcard-install.sh`, and pushed `mount_options.conf` and the script to `/home/phablet`. The test files on the card (`sdtest.bin`, `Videos/sdtest-video.mp4`) were removed; `/home/phablet/sdtest.src` (512 MiB random data) is kept for the re-test.
- 2026-11-11: the user ran `stone-sdcard-install.sh`. The script finished, but `adb shell -t` with sudo did not return; it was safe to kill. The user took the card out and put it back in: mounted without `flush`. Small files went from 101.6 to 6.6 ms/file, and the sequential tests and checksums are as before. Built `ec969650…`. Removed `mount_options.conf`, `stone-sdcard-install.sh` and `sdtest.src` from `/home/phablet`.

## 5. Camera leftovers

Goal: flash and torch, tap-to-focus, zoom and the barcode reader work.

What is seen: not tested (`docs/roadmap-hardware.md` item 7). The flash shares TLMM pin 38 with the camera sensors (kernel patch 0005). Photo orientation depends on item 1.

Skipped (2026-11-11): the user reports these already work well. No changes.

### Flashlight toggle (2026-11-12)

User report: the battery indicator has no Flashlight switch (a Nothing Phone on 24.04 has one there); the flash works in the camera app.

What is seen:
- `ayatana-indicator-power` 24.5.2 shows the switch only when one of its backends finds a torch:
  - **sysfs:** a list of LED class paths (`/sys/class/leds/torch-light/brightness`, `led:torch_0`, …), or the deviceinfo key `FlashlightSysfsPath` (plus `FlashlightSimpleEnableValue`/`DisableValue`);
  - **camera HAL** (`FlashlightBackend: camera-hal`, `flashlight-binder.c`): the AIDL camera provider `android.hardware.camera.provider.ICameraProvider/internal/0` on `/dev/binder`.
- **Neither fits this phone.**
  - `/sys/class/leds` has only `mmc0::`, `mmc1::` and `vibrator`. The flash is an I2C LED driver on the camera control bus (`qcom,cci0:qcom,camera-flash@0..2`), driven only through the camera stack.
  - The vendor's manifest has only the HIDL provider, `android.hardware.camera.provider@2.4::ICameraProvider/legacy/0` (`vendor.camera-provider-2-4`).
- The HIDL provider works from the Ubuntu side (python-gbinder on `/dev/hwbinder`, even as phablet):
  - `isSetTorchModeSupported()` (code 4) returns true;
  - `getCameraIdList()` (3) returns `device@3.5/legacy/0` and `…/1`;
  - `getCameraDeviceInterface_V3_x()` (6), then `ICameraDevice@3.2::setTorchMode()` (3) on camera 0, returns OK for on and off.

Fix: a bridge from the indicator's file backend to the HAL's torch mode.
- `stone.yaml`: `FlashlightSysfsPath: /run/stone-torch/torch`, `FlashlightSimpleEnableValue: "1"`, `FlashlightSimpleDisableValue: "0"`. The indicator `fopen()`s the file, writes the value and closes it.
- `usr/lib/stone/torch.py`, `stone-torch.service` (root, before lightdm):
  - creates the file (0664 root:phablet, the indicator runs as phablet);
  - watches its directory with inotify (`IN_CLOSE_WRITE`);
  - calls `setTorchMode` on the first camera that accepts it, remembers that camera, and reconnects to the provider on errors;
  - logs every refusal with its status (`CAMERA_IN_USE` while the camera app is open);
  - turns the torch off when stopped.
- First live test: the switch appeared but did nothing ("no camera accepted setTorchMode"). python-gbinder's `read_hidl_string_vec()` returns the list itself, not `(ok, value)` like the other readers, so the service iterated over a camera name's characters. Fixed. Run directly, the fixed code switched camera 0 on and off (OK, OK).
- Second live test (`tools/phone-debug/stone-torch-install.sh`, runtime unit): the user confirmed the Flashlight switch turns the torch on and off.

## 6. Power

Goal: the phone suspends when the screen is off, standby drain is reasonable, and Settings shows the battery level and health.

What is seen: not checked yet.

Skipped (2026-11-11): the user reports this already works well. No changes.

## 7. Location (GNSS)

Goal: a position fix in a maps app, through the Android GNSS HAL.

What is seen (user, 2026-11-11): Pure Maps (OpenStore, `pure-maps.jonnius` 3.5.0) could not find the position.

### Checked so far (2026-11-11, indoors)

- The stack:
  - `lomiri-location-service` 3.4.1, started through lxc-android-config's `lomiri-location-serviced-wrapper` with `--provider gps::Provider --provider remote::Provider`;
  - the GPS provider (`providers::gps::android::HardwareAbstractionLayer`) calls Halium's `libubuntu_platform_hardware_api` (`u_hardware_gps_*`), which reaches the vendor's HIDL `android.hardware.gnss@2.1-service-qti` (`gnss_service`, running) through `libubuntu_application_api.so` and the `gnss@1.0`–`@2.1` interfaces in the Halium system image;
  - `loc_launcher` is running.
- Service state over D-Bus (`busctl get-property com.lomiri.location.Service`): `State=enabled`, `DoesSatelliteBasedPositioning=true`, `IsOnline=true`, `DoesReportCellAndWifiIds=false`.
- Permission: `~/.local/share/LomiriLocationService/trust.db` has `pure-maps.jonnius_pure-maps`, answer 1 (granted).
- The HAL delivers satellite status: `VisibleSpaceVehicles` had 26 GPS entries after Pure Maps' attempt. Two had signal (PRN 11 at 29 dB-Hz, PRN 21 at 27), one had ephemeris, none was used in a fix. The chain from the Qualcomm engine to lomiri-location-service works, and the RF front end receives satellites. Indoors, with a cold start, no fix is expected.
- Assistance data:
  - UT's `/etc/gps.conf` (from `liblomiri-location-service3`) points XTRA at `http://xtra{1,2,3}.gpsonextra.net/xtra2.bin`. All three still serve data (200, 27 to 62 KB), and so does `path1.xtracloud.net`. The phone resolves them. The service downloads XTRA only when the HAL asks.
  - The vendor's `izat.conf` enables `xtra-daemon` and `slim_daemon`, but neither is running under `loc_launcher` and neither has a tombstone. `lowi-server` and the `xtwifi-*` agents are disabled. Without XTRA, a cold first fix outdoors can take minutes.
  - The vendor `gps.conf` has `SUPL_MODE=3`, `NTP_SERVER=time.xtracloud.net`, `XTRA_SYSTEM_TIME_INJECT=1`.
- Not related: `vndservicemanager` aborts on `selinux_status_open` (`selinux=0`). Its 19 tombstones are all from early boots; this boot it runs with a stable pid.
- Logging gaps:
  - lomiri-location-service uses glog without file output, so nothing it logs reaches the journal or `/tmp`. `GLOG_logtostderr=1` fixes that: the provider's start-up line (`android_hardware_abstraction_layer.cpp:276 … on_set_capabilities`) then appears in the journal.
  - Android logcat needs root (`lxc-attach`).
  - `lomiri-location-serviced-cli --test` refuses to run without root. **Do not use it with the service running**: its fixture (`runtime_tests.cpp`) runs `service lomiri-location-service stop` and only starts the service again when the test ends. The test does `delete_all_aiding_data()`, a standalone cold start, and waits up to 15 minutes for a fix, three times.

### First outdoor test (2026-11-11, invalid)

- The first `stone-gnss-debug.sh start` ran `cli --test` in the background. The test stopped lomiri-location-service at 09:28:02, 4 s after the debug restart, and nothing started it again until `stop` at 09:36:55. During the user's walk there was no service, so Pure Maps could not get a position. The logcat capture was empty because the script's `pkill -f` pattern matched its own `sh -c`. Both are fixed in the script.
- What the walk did show: the CLI test drove the HAL directly in standalone mode. Its output has 6 satellite reports, all empty, all at 09:28 (the file was last written then). For the remaining 8 minutes outdoors, the engine reported nothing to it.
- Indoors afterwards, as phablet, with `tools/phone-debug/gnss-monitor.qml` (a QtPositioning session through the `lomiri` plugin, like Pure Maps; `sourceError` 3 = `NoError`) for 2 minutes, plus `gdbus monitor` on the service:
  - the service went `active` with `ClientApplications=['unconfined']`;
  - in 2 minutes it published only 2 `VisibleSpaceVehicles` changes, each with one satellite (keys 163 and 80, about 29 dB-Hz, no ephemeris), and no position;
  - a running Qualcomm engine reports its whole satellite list every second. Either the engine barely runs, or the HAL → platform API → service path delivers only some reports. That is the next thing to find.

### Next: outdoor test with logging

`tools/phone-debug/stone-gnss-debug.sh` (sudo):
- `start` adds a runtime drop-in for lomiri-location-service (`GLOG_logtostderr=1 GLOG_v=1`) and restarts it, captures Android logcat in the container, runs `lomiri-location-serviced-cli --test` in the background (positions as they arrive, up to 30 min), and saves a snapshot of the processes, properties and satellites.
- `stop` saves everything to `~/gnss-debug/` and removes the drop-in. The drop-in lives in `/run` and is gone after a reboot anyway.

`run [SECONDS]` does `start`, holds `gnss-monitor.qml` as phablet for SECONDS (180), then `stop`. It can be run indoors, because the question now is what the HAL reports per second, not whether there is a fix.

### Indoor captures with logging (2026-11-11)

`stone-gnss-debug.sh run 180` twice, as root and indoors. The logcat capture was changed to `logcat -d` at stop: a background `logcat -f` started through `lxc-attach` does not survive it returning. Logs are in `out/halium14/logs/gnss-2/` and `gnss-3/` (gitignored).

- **The engine is healthy.** With `GLOG_v=200` the service logs every NMEA sentence: 181 `$GPRMC` in 180 s, and 180 `on_sv_status_update` calls (up to 12 satellites). Halium's bridge (`ubuntu_application_gps_for_hybris`) reports "AIDL IGnss service not declared, skipping AIDL backend", then "HIDL GNSS backend initialized successfully", and passes `gnssNmeaCb`, `gnssSvStatusCb`, `gnssStatusCb` and `gnssSetCapabilitesCb`.
- The sparse `VisibleSpaceVehicles` changes seen before come from the service. Its satellite handler is GPS-only and legacy (PRN 1 to 32 used as bit positions; every satellite typed `gps`; GLONASS 65 to 96 and BeiDou keys mislabelled), and the property only notifies on change. Cosmetic.
- **But it starts cold every time.** It tracked GPS 25 and 28 and GLONASS 69, 79 and 80 at 22 to 33 dB-Hz, all with elevation 00 and azimuth 000 (no almanac, ephemeris or XTRA). The NMEA showed `$GPRMC,,V`, `$GPGGA` quality 0 and `$GPGSA,A,1`: no fix. Nobody asked UT for time or XTRA either: `on_request_utc_time` and `on_xtra_download_request` were never called.
- SUPL: `LocSvc_Agps: NULL AGNSS NIF ! / No AGPS State Machine for agpsType: 1 apnTypeMask: 0x10`. The HAL wanted a SUPL data connection, but nothing registered the AGNSS callbacks Android's framework would register. Not fixed; see below.

### GNSS: what fixed it

1. **`xtra-daemon` was not running.** It is Qualcomm's assistance agent: it fetches NTP time (`time.xtracloud.net`) and XTRA orbit data (`https://path{1,2,3}.xtracloud.net/xtra3grej.bin`) and injects both into the modem's GNSS engine.
   - The vendor `init.qcom.rc` has `on property:persist.sys.xtra-daemon.enabled=*` → `restart loc_launcher`, and `loc_launcher` only starts it when that property is set. On Android, Qualcomm's framework apps set it; here it was unset.
   - `setprop persist.sys.xtra-daemon.enabled true` (phablet may set it): `loc_launcher` restarted, `xtra-daemon` (uid 1021) started at once, and `/data/vendor/location/xtra/` and `nvparam.sqlite` appeared.
2. **The HAL believed there was no network.** The next capture had `xtra-daemon: onRequestXtraData … isCon:0 isNonMetered:0 isGpsEnabled:1` and then `XTRA download result status:4 starting timer for 300 sec`.
   - On Android, the framework (`GnssNetworkConnectivityHandler`) reports every connectivity change to the HAL through `IAGnssRil::updateNetworkState`. Nothing on UT did that.
   - python3-gbinder as phablet, on `/dev/hwbinder`: `android.hardware.gnss@1.0::IGnss/default` → `getExtensionAGnssRil()` (transaction 9) → `IAGnssRil::updateNetworkState(true, WIFI, false)` (transaction 4) returned `true`. `updateNetworkAvailability` (transaction 5) returned `false` (not implemented in QTI's HAL; harmless).
   - Within 5 s, `xtra-daemon` connected to `18.164.96.40:443` (`path1.xtracloud.net`). DNS inside the container works; only the network state was missing.
3. **Result:** a 60 s QtPositioning session (`gnss-monitor.qml`) indoors:
   - first valid position at about 30 s, accuracy 4 m;
   - 115 updates in the minute;
   - `VisibleSpaceVehicles` had 16 satellites, 9 with signal, 14 with predicted azimuth/elevation, 4 with ephemeris and 4 used in the fix.

   (The coordinates are not recorded here.)

Made permanent: `stone-gnss-netstate.service` (`User=radio`, `Restart=always`), which runs `usr/lib/stone/gnss-netstate.py`:
- sets `persist.sys.xtra-daemon.enabled=true` if it is not `true` (fresh installs; on this phone the persist property already survives reboots);
- calls `updateNetworkState(connected, WIFI|MOBILE, roaming=false)` and `updateNetworkAvailability`. It does that at start, on every NetworkManager `StateChanged`/`PropertiesChanged` (connected when `State` ≥ 60; WIFI for `802-11-wireless` and Ethernet, otherwise MOBILE), whenever hwservicemanager reports `IGnss/default` registered (HAL restarts, and once at start), and every 10 minutes.
- It only uses the `IAGnssRil` extension and does not touch the IGnss callbacks that lomiri-location-service owns.

python-gbinder details: the readers return `(ok, value)`. `ServiceManager.add_registration_handler(name, func)` stores `func` as an instance attribute, which only works on a Python subclass of the Cython class.

Live install: `tools/phone-debug/stone-gnss-install.sh` (sudo). Image: `boot-ut.img` SHA256 `065ee6e561d036d5ba4c48c227b189b74d8dbba73102370f6f122fe81c0d5b81` (kernel `#14`, unchanged; adds the service). The previous image is kept as `out/halium14/boot-ut-ec969650.img`.

### Still open (location)

- SUPL / A-GNSS over the mobile network (`NULL AGNSS NIF`): **not implemented, by decision (2026-11-11).**
  - Halium's bridge (`libubuntu_application_api.so`) supports HIDL AGNSS: `IAGnssCallback`, `dataConnOpen`/`dataConnClosed`/`dataConnFailed`, `setServer`, IPv4 status ("AgnssStatusIpV6 not implemented").
  - lomiri-location-service 3.4.1 stops there. `on_agps_status_update()` only stores and logs the status, and nothing in the service ever calls `SuplAssistant::set_server` or `notify_data_connection_*`. SUPL is unimplemented upstream, on every device.
  - Adding it would mean a new component: a SUPL server (AOSP's default is `supl.google.com:7275`) and answering the HAL's data-connection requests. SUPL also sends the SIM identity and the serving cell to that server.
  - With XTRA and NTP time now working, the gain is small: a first fix in seconds instead of under a minute, and assistance without Wi-Fi or mobile data. XTRA files cover several days, so assistance also lasts through short offline periods.
- The service's satellite list is GPS-only and mislabels other constellations (upstream lomiri-location-service).
- In the third capture my unconfined test client got "Client lacks permissions to access the service with the given criteria" when started with `runuser` from the root script. The same client started from an adb shell was allowed. Only this test tool is affected; the apps (Pure Maps, uNav) have their trust entries (granted).
- Network-based location (Wi-Fi/cell, no GPS): `DoesReportCellAndWifiIds=false`, and no remote provider is installed. 24.04 ships none since the HERE provider and Mozilla Location Service went away. Out of scope.

### Result (2026-11-11)

Confirmed by the user: Pure Maps finds the position. The user flashed `065ee6e5…` and rebooted. Checked over adb:
- `stone-gnss-netstate` is active, the installed `gnss-netstate.py` is byte-identical to the overlay's, and `xtra-daemon` has run since boot;
- the user's network switches were followed: at 254 s `gsm/70 → updateNetworkState(connected=True, type=MOBILE) = True`, at 362 s back to `802-11-wireless/70 → … WIFI = True`.

The location item is done. What remains is optional or upstream (SUPL, satellite labelling).

### Events

- 2026-11-11: the user reported Pure Maps cannot find the position. Checked the stack, the service state, the permission, the satellite status (the HAL works: 26 satellites, 2 with signal indoors, no fix), the XTRA servers (alive) and the Qualcomm daemons (`xtra-daemon` enabled but not running). Wrote and pushed `stone-gnss-debug.sh`.
- 2026-11-11: outdoor walk, no position, but the test was invalid: `cli --test` had stopped the service (see "First outdoor test"). The script was fixed (no `--test`, logcat pattern, new `run` mode), and `gnss-monitor.qml` was added. Indoors: only two one-satellite reports in 2 minutes. Waiting for the user to run `stone-gnss-debug.sh run` indoors.
- 2026-11-11: indoor captures 2 and 3 (see above). Engine healthy, but a cold start with no time or XTRA. Set `persist.sys.xtra-daemon.enabled=true` (xtra-daemon started). Found `isCon:0`, and called `IAGnssRil::updateNetworkState` by hand: XTRA downloaded, and a first fix came indoors in about 30 s with 4 m accuracy. Wrote `stone-gnss-netstate.service`, tested it as phablet (start push, HAL registration push, keeps running), and built `065ee6e5…`.
- 2026-11-11: the user flashed `065ee6e5…`: Pure Maps finds the position. The service was active from boot and followed Wi-Fi → mobile → Wi-Fi. SUPL was looked at and left out (unimplemented upstream; privacy cost, small gain). Logs of the three captures are in `out/halium14/logs/gnss-{1,2,3}/`. The debug output and install copies were removed from `/home/phablet`; `stone-gnss-debug.sh` and `gnss-monitor.qml` are still there.

## 8. Fingerprint reader

Goal: enrolling a fingerprint and unlocking with it in Lomiri, if the vendor's fingerprint HAL can be reached. The sensor is in the power button.

### Checked (2026-11-11, image `0ea13aae…`)

- **Vendor side: fine.**
  - `/vendor/bin/hw/android.hardware.biometrics.fingerprint@2.3-service.xiaomi` (`vendor.fps_hal`, `class late_start`, user `system`) runs, registered on hwbinder as `android.hardware.biometrics.fingerprint@2.1/2.2/2.3::IBiometricsFingerprint/default`.
  - `android.hardware.gatekeeper@1.0::IGatekeeper/default` is there too; it issues the auth token that enrollment needs.
  - Xiaomi's `vendor.xiaomi.hardware.mlipay` is also registered (payments, not needed).
- **Ubuntu Touch side:**
  - biometryd `0.4.0+0~20260423213326.36` (the 24.04-2.x release branch) is running.
  - Its `android` device uses the old route: the Halium bridge `/system/lib64/libbiometry_fp_api.so` through libhybris.
  - System Settings shows "Fingerprint" under Lock security when `Biometryd.available` is true, and it is.
- **The first D-Bus request kills biometryd.** A QML client doing what Settings does (`Biometryd.defaultDevice.templateStore.size(user)`, `tools/phone-debug/fp-probe.qml`) gets `NoReply`. The daemon aborts with "boost::optional … Assertion `this->is_initialized()' failed" and systemd restarts it.
  - 0.4.0 identifies the caller with `org.freedesktop.DBus.GetConnectionAppArmorSecurityContext`. That is an Ubuntu-only dbus method; here it fails with `AppArmorSecurityContextUnknown`.
  - `DaemonCredentialsResolver` then calls `label.get()` on the empty optional before checking it.
  - So enrolling in Settings, and fingerprint unlock, could never have worked.
- **biometryd main fixes the crash, but not on this kernel.**
  - Main (0.4.1, commit "dbus: Replace deprecated GetConnectionAppArmorSecurityContext") reads `LinuxSecurityLabel` from `GetConnectionCredentials`.
  - On this phone that key is missing. AppArmor itself works (profiles load, apps are confined, the kernel log has denials). But the 5.4 vendor kernel has no Ubuntu AppArmor socket and D-Bus mediation: there is no `/sys/kernel/security/apparmor/features/dbus`, and `SO_PEERSEC` gives D-Bus no label.
  - Without a label, main refuses every request.
  - (Side note: for the same reason, dbus-daemon does not mediate D-Bus for confined apps on this kernel. That is a separate, wider issue.)
- **Fix:** biometryd main plus one patch, `tools/biometryd/biometryd-0001-dbus-fall-back-to-apparmor-label-by-pid.patch`. When `LinuxSecurityLabel` is missing, it reads the caller's confinement from the kernel by `ProcessID` (`aa_gettaskcon`).
  - The verifier's policy is unchanged: only `unconfined` callers are trusted (Lomiri, System Settings), and a confined app still reports its own profile.
  - Main also replaces the libhybris bridge with direct hwbinder access (libgbinder: HIDL 2.1 and 2.3, or AIDL), with the gatekeeper auth token for enrollment and the template store at `/data/vendor_de/0/fpdata/`.
- **The D-Bus protocol is unchanged** between 0.4.0 and main (no diff under `src/biometry/dbus` apart from the credentials resolver). So only the daemon is replaced; clients (Settings, Lomiri, the QML module) keep the packaged `libbiometry.so.2`.
  - `usr/lib/stone/biometryd/biometryd` and `libbiometry.so.2` in the overlay;
  - `etc/systemd/system/biometryd.service.d/zz-stone-biometryd.conf` (`ExecStart=` the new daemon, `LD_LIBRARY_PATH=/usr/lib/stone/biometryd`).
- **Build:** `tools/biometryd/build.sh` (Docker, Ubuntu 24.04 with arm64 multiarch, the UBports 24.04-2.x repository, a CMake cross-build of biometryd main at `1005154b`, stripped).
  - Output: `biometryd` sha256 `55975e1c…`, `libbiometry.so.2` `7792ee8e…`.
  - On the phone, `biometryd list-devices` reports "android … connecting to the android fp hal using libgbinder".
- Live install: `tools/phone-debug/stone-fingerprint-install.sh`, which also runs the query that crashed the old daemon.
- Side finding: `biometryd enroll` in 0.4.0 binds `--user` to the `--device` variable; use it without `--user`. In-process, as phablet, it did start an enrollment on the HAL through the old bridge (`on_started`).

### Result (2026-11-11)

Live install (`stone-fingerprint-install.sh`, 13:49), then the user enrolled a finger in System Settings and turned on fingerprint unlock. User: "fingerprint works first try". Checked afterwards:
- the new daemon (`ExecStart=/usr/lib/stone/biometryd/biometryd run`) has run since the install with `NRestarts=0`;
- `fp-probe.qml` (as phablet, through D-Bus): `size OK: 1 enrolled fingerprint(s)`;
- AccountsService `com.lomiri.AccountsService.SecurityPrivacy.EnableFingerprintIdentification` is `true`;
- Lomiri on the lock screen:
  - 13:50:50 "Identified user by fingerprint: 32011";
  - 13:50:56 "Failed to identify user by fingerprint: FINGER_NOT_RECOGNIZED" (a wrong finger, refused);
  - 13:50:59 identified again.

Harmless log lines:
- biometryd prints "dbus: Attempted to unregister path … which isn't registered" once per finished request (dbus-cpp).
- Settings' stock `BioMetrics.qml` warns "Cannot anchor to an item that isn't a parent or sibling".

Image `d302d1a1c34dd57005797b85f0f72e446ec25cc2df982f8624eb6d0fa713940c`: the `#15` kernel (byte-identical) plus the biometryd files (checksums as above) and the drop-in. Not yet written.

### Still open (fingerprint)

- Upstream: the label fallback patch (`tools/biometryd/`) and a 24.04-2.x release of biometryd main. When the packaged biometryd gets these, the drop-in and the two files can go.
- After a reboot with the new image, a quick check that unlock still works. The templates live in the vendor HAL's store (`/data/vendor_de/0/fpdata/`), so they should survive.
- Not checked: fingerprint for app authentication prompts (only the lock screen was tested).

## 9. Smaller items

- ~~The second SIM slot~~: done 2026-11-11, see "SIM 2 calls" below.
- ~~Call volume keys controlling the call volume instead of the media volume~~ (`docs/roadmap-hardware.md` item 6): done, see "In-call volume" below.
- ~~Wideband Bluetooth calls (mSBC)~~: done 2026-11-11, see "Wideband Bluetooth calls" below.
- The IR emitter and NFC: first check whether this model has them. NFC: see "NFC" below (this unit has none; nfcd now runs only where a chip answers; live test pending). IR: done, see "IR emitter" below (the vendor HAL speaks a Xiaomi-only driver protocol; `stone-ir` uses the kernel's standard LIRC and drives a Samsung TV).

### SIM 2 calls (2026-11-11)

User test with the Fizz SIM moved to slot 2:
- data, VoLTE and placing and receiving calls all work;
- **no audio in either direction**, on any output (earpiece, speaker, Bluetooth);
- SIM 1 right after was fine.

Cause:
- Each SIM has its own voice session in the DSP, and the modem uses the one of the SIM the call is on: SIM 1 `VoiceMMode1` (vsid `0x11C05000`), SIM 2 `VoiceMMode2` (`0x11DC5000`).
- `call-audio.sh` always held the `VoiceMMode1` PCM (device 2), and the UCM profile routed only `VoiceMMode1` (23 `cset`s: the RX voice mixers per output, the `VoiceMMode1_Tx` mixers per mic). So a SIM 2 call had no running session.
- `audiosystem-passthrough-qti` receives qcril's vsid parameters but does not log them, and nothing on this stack consumes them.

Fix:
- **`HiFi.conf`:** every `VoiceMMode1` route has its `VoiceMMode2` twin next to it (`…_Voice Mixer VoiceMMode2`, `VoiceMMode2_Tx Mixer …_MMode2`; all exist on this card). A route alone starts no session, so both are set.
- **`call-audio.sh on [muted] [sub2]`:** `sub2` holds `VoiceMMode2` (device 15) instead of device 2. The mute controls already address all sessions (`0xFFFFFFFF`).
- **`call-audio-router.py`:** `voice_sub()` takes the subscription from the ofono call path (`/ril_1/…` = SIM 2) of the calls in a voice state. The session is restarted when that changes, and the log reads "call audio on: <port>, SIM n".

Checked without a call:
- `voice-pcm-hold.py hw:holiqrdsku1sndc,15` on the old profile fails with "ASoC: no backend DAIs enabled for VoiceMMode2", as expected.
- With `RX_CDC_DMA_RX_1_Voice Mixer VoiceMMode2` and `VoiceMMode2_Tx Mixer TX_CDC_DMA_TX_3_MMode2` set by hand, it starts ("started (both)"), and the routes were cleared afterwards.
- The new profile parses (`alsaucm` lists the verb and its devices).

Live install: `tools/phone-debug/stone-sim2-voice-install.sh` (sudo; it restarts PulseAudio to reload the profile, so not during a call).

Live test (2026-11-11, user: "the fix works"). The router logged:
- incoming SIM 2 call: "call audio on: [Out] Earpiece, SIM 2", then Speaker and back to Earpiece (each restart on SIM 2);
- outgoing SIM 2 call: Earpiece, SIM 2;
- then a SIM 1 call: "Earpiece, SIM 1".

The live-installed files were byte-identical to the repository's.

Image `fced82d049d8cb29e281f38933d133604ead80d69f733752eeec84986dfe8c81`: kernel `#17` (byte-identical), plus the new `HiFi.conf`, `call-audio.sh` and router (byte-identical to the tested ones). Not yet written.

Not covered: calls on both SIMs at once (one held while the other is active). `voice_sub()` picks SIM 2 only when every call in a voice state is on SIM 2, and SIM 1 otherwise; untested.

### NFC (2026-11-11)

The stone family is three models on one device tree and one vendor image: one SM6375 and two SM4375. Only some SKUs have NFC. This unit is `androidboot.product.hardware.sku=sunstone_cn` and has no NFC (user, and checked below). The st21nfc driver has a commented-out Xiaomi check that names the NFC SKUs: `moonstone_p_global` and `sunstone_global`.

What runs on this unit:
- **Device tree:** `st21nfc@8` on `i2c@4a80000` (`st,st21nfc`, status `ok`, with irq/reset/clkreq GPIOs 9/6/7, pinctrl and `nfc_ref_clk`), the same on every SKU.
- **Kernel:** I2C device `0-0008` exists but no driver is bound and there is no `/dev/st21nfc`.
  - The probe (`st21nfc_probe`) does not fail on GPIOs or the device tree. It resets the chip and waits for the NCI `CORE_RESET_NTF` (`st21nfc_ping`), and fails without it: no chip answered.
  - The boot messages were already gone (the 256K kernel log wraps, and journald does not keep kernel messages here), but the device is not waiting for a supplier.
- **Vendor:**
  - `android.hardware.nfc@1.2-service.st` runs (uid `nfc`, steady, CPU use negligible).
  - The vendor declares `android.hardware.nfc*.xml` unconditionally (no per-SKU permission folders), so crDroid does not tell the SKUs apart either.
- **Ubuntu Touch:**
  - `nfcd` (`/usr/sbin/nfcd -p /usr/lib/nfcd/plugins`, binder plugin) publishes `/nfc0` through that HAL as enabled, powered, modes 15, even without a chip.
  - System Settings shows its NFC page whenever `GetAdapters` is non-empty (`NfcDbusHelper::hasAdapter()`), so it showed a switch that does nothing.
- **Permissions:** `/dev/st21nfc` (and `nq-nci`, `nfc-nci`) are already given to `nfc:nfc 0660` by `70-sunstone.rules`, generated from the vendor `ueventd.rc`.

Fix: `etc/systemd/system/nfcd.service.d/zz-stone-nfc-hw.conf`.
- It runs nfcd only if `/dev/st21nfc`, `/dev/nq-nci` or `/dev/nfc-nci` exists. The node only appears when a chip answered the reset; the NQ nodes cover a variant with Qualcomm's controller (`CONFIG_NFC_QTI_I2C` is built).
- **This unit:** no nfcd, so no adapter, and Settings hides NFC. Nothing D-Bus-activates nfcd; without it `hasAdapter()` gets an invalid reply and returns false.
- **NFC SKUs:** nfcd runs as before, on the vendor HAL. Untested: there is no such unit here.
- The vendor HAL keeps running in the container on every SKU, as on Android; it is idle without a client.

Live install: `tools/phone-debug/stone-nfc-install.sh` (sudo).

Result (2026-11-11): the user confirmed the NFC entry is gone from System Settings. `nfcd.service`: `ConditionResult=no`, inactive, and no `org.sailfishos.nfc.daemon` on the bus. Image `07ce6de313351c0785fab5f388ca14911357405b8600506ec0bff9fd708607a0` (kernel `#17`, plus the drop-in), kept as `out/halium14/boot-ut-07ce6de3.img`. It was not written: the phone rebooted at 15:34 with the live-installed drop-in (15:33 timestamp, not the overlay's boot-time one), so `c57e8b19…` is what runs (kept as `out/halium14/boot-ut-c57e8b19.img`). It is superseded by `45e50e0d…` (IR emitter section).

### IR emitter (2026-11-11)

This unit has one (as does Android: `android.hardware.consumerir`).
- **Kernel:** the mainline `ir-spi` driver (`drivers/media/rc/ir-spi.c`, `CONFIG_IR_SPI`, LIRC) on SPI bus `4a88000.spi`: `/sys/class/rc/rc0` ("IR SPI") and `/dev/lirc0` (`root:video 0660`; phablet is in `video`).
- **Vendor:** `android.hardware.ir@1.0-service` (user `system`) with Xiaomi's `consumerir.holi.so`, registered as `android.hardware.ir@1.0::IConsumerIr/default`.
- **Over hwbinder as phablet:**
  - `getCarrierFreqs` → 30, 33, 36, 38, 40 and 56 kHz;
  - `transmit(38000, [500, 500, 500])` → **false**.
- **First guess, permissions — wrong.** `init.xiaomi.rc` gives `/dev/lirc0` to `system` with mode 0666, which does not happen here. A live udev rule doing the same changed nothing; transmit still failed (user, with `stone-ir samsung-tv power`). The rule was dropped. (Debian's `80-debian-compat.rules` also re-sets `GROUP="video"` after it.)
- **Real cause:** `consumerir.holi.so` is written for Xiaomi's own variant of the driver (disassembly of its transmit).
  - It modulates the carrier itself into a raw SPI bitstream (bits at a fixed clock; the buffer is rounded up to 1024 bytes).
  - It then calls `ioctl(fd, 0x40046911 = LIRC_SET_SEND_MODE, &length)` ("ir-spi set length error") and `write()`s the bitstream.
  - Mainline LIRC accepts only `LIRC_MODE_PULSE` there, so the vendor HAL can never transmit on this kernel.
- **The standard interface works.** On `/dev/lirc0` as phablet: features `0x302` (send pulses, set carrier, set duty cycle), send mode `LIRC_MODE_PULSE`; `LIRC_SET_SEND_CARRIER` 38000 and `LIRC_SET_SEND_DUTY_CYCLE` 50 succeed, and writing `[500, 500, 500]` returns 12 bytes. Ubuntu Touch has no Android consumer of the HAL anyway.
- **Fix: `usr/bin/stone-ir`**, which drives `/dev/lirc0` directly in pulse mode (carrier, 33 % duty cycle, durations in µs):
  - `info`;
  - `samsung ADDR CMD`, plus a `samsung-tv` key table (address 0x07; `power` = 0x02 = the well-known `E0E040BF`);
  - `nec ADDR CMD` (8- and 16-bit addresses);
  - `raw FREQ durations…`;
  - `-r N` repeats.

  Encodings checked on the host: Samsung 0x07/0x02 → `E0E040BF`, NEC 0x04/0x08 → `20DF10EF` (the well-known LG power code).
- Ubuntu Touch has no consumer-IR API or remote app; `stone-ir` is the test, and a user-facing remote would be a separate app. Making the vendor HAL work would need Xiaomi's driver variant (its "set length" protocol) in the kernel; not needed for Linux tools.

Result (2026-11-11): `stone-ir samsung-tv power` turned the user's Samsung TV off and on again. Done.
- On the phone, `/dev/lirc0` stays `system`, mode 0666, until the next reboot (the dropped rule's leftovers); `root:video 0660` is all `stone-ir` needs.
- Image `45e50e0d2ad6ea301c427d46f8097067fba50d8e4a75820f164466c210d3f69c`: kernel `#17` (byte-identical), plus `usr/bin/stone-ir` (byte-identical to the tested one) and the NFC drop-in. No udev rule for IR. Not yet written.
- A first build had a host-side `usr/bin/__pycache__` (from loading `stone-ir` to check its encodings); it was removed and the image rebuilt.
- Not done: a user-facing remote app (Ubuntu Touch has none). Other TV brands need their codes (`nec`/`raw`); Hisense not tried.

### Wideband Bluetooth calls (mSBC, 2026-11-11)

How Bluetooth call audio flows here (`docs/roadmap-hardware.md` item 6):
- PulseAudio's ofono backend with UBports' "SCO over PCM" patch (`0911-bluetooth-bluez5-bring-back-SCO-over-PCM-support.patch`). PulseAudio only *acquires* the transport: ofono opens the SCO socket, and holding `source.fake.sco` keeps the link up.
- The audio itself goes chip ↔ SLIMbus (`SLIMBUS_7`, btfmslim) ↔ DSP voice session, never over HCI.
- `enable_msbc=false` kept the link CVSD at 8 kHz.

What wideband needs, and what was there:
- **The parts support it.**
  - Headset: the Moondrop Nekocake HFP record has `SupportedFeatures 0x0035`, which includes wideband speech (bit 5).
  - Controller: the supported-commands octet 29 = `0xfe`, which includes Enhanced Setup (bit 3) and Enhanced Accept Synchronous Connection (bit 4).
  - ofono 1.30: AG codec negotiation (`ofono_emulator_start_codec_negotiation`, `+BCS`); it offers it when the audio agent registers mSBC.
  - PulseAudio 16.1's ofono backend registers mSBC with `enable_msbc`.
  - DSP: `BT SampleRate`/`RX`/`TX` offer `KHZ_16` for `SLIMBUS_7`.
- **The missing piece was the kernel.**
  - For mSBC, ofono sets `BT_VOICE_TRANSPARENT`. Linux 5.4 then sends the legacy Setup Synchronous Connection with transparent air coding, where the controller expects ready-made mSBC frames.
  - On this device those come from the PCM side, where the DSP delivers linear PCM, so the result would be noise.
  - Android instead uses Enhanced Setup with the codec in the controller (`esco_parameters.cc`, mSBC T2/T1 with offload): mSBC on air, 16 kHz 16-bit linear PCM on the PCM data path.
  - Linux only gained Enhanced Setup and codec offload in 5.14.

Fix:
- **`kernel/patches/0009-bluetooth-msbc-sco-offload-via-enhanced-setup.patch`** (kernel `#17`):
  - `hci.h`: `HCI_OP_ENHANCED_SETUP_SYNC_CONN` (0x043d) and `HCI_OP_ENHANCED_ACCEPT_SYNC_CONN_REQ` (0x043e), with the 57-byte parameter block (size-checked: 59/63 bytes per the Core spec).
  - `hci_setup_sync()`: transparent links use Enhanced Setup when the controller supports it and `bluetooth.sco_offload_msbc` is on (default; writable at runtime). The values are Android's:
    - air: mSBC (0x05), 8000 B/s, frame size 60;
    - PCM side: linear PCM, 32000 B/s, 16-bit two's complement, data path PCM (1);
    - packet types, latency and retransmission from the existing T2/T1 table, so its retry logic still applies.
  - `sco_conn_defer_accept()`: Enhanced Accept for a link the headset initiates.
  - Command-status cleanup for the new command.
  - CVSD links are unchanged.
  - `bluetooth.sco_offload_msbc_active` (read-only) counts the connected offloaded links.
  - Kernel log lines: "mSBC: enhanced setup…", "mSBC: offloaded link up (N active)".
- **`etc/pulse/stone-touch.pa`:** `enable_msbc=true`.
- **`call-audio-router.py`, `bt_rate()`:** before it starts the voice session on `[Out] Bluetooth`, it waits up to 3 s for the (e)SCO link (`hcitool con`), then sets `BT SampleRate`/`RX`/`TX`:
  - `KHZ_16` if `sco_offload_msbc_active` > 0;
  - `KHZ_8` otherwise (the UCM default for CVSD).

  It logs which. PulseAudio and ofono do not report the negotiated codec in SCO-over-PCM mode (the card's `bluetooth.codec` is set before the link exists), so the router reads it from the kernel.

Test image `9a9590c4ddfda1dee229ed235eeef8337091c00383252ce758c947b1c0d5d11a`: kernel `#17` (`9ef719cd…`; `#15` kept as `out/halium14/Image-15`; `#16` was an intermediate build without the counter), plus the in-call volume fix, since `f4a9cf05…` was never flashed (kept as `out/halium14/boot-ut-f4a9cf05.img`).

Fallback without a reflash: `pactl unload-module module-bluez5-discover` and load it again with `enable_msbc=false` (as phablet). New links are then CVSD as before.

First live test (image `9a9590c4…`, kernel `#17`, 2026-11-11): **Bluetooth calls completely silent**, both directions; earpiece and speaker fine. Two incoming calls, both routed to the earbuds.
- **ofono:** negotiated mSBC at the first ring (`+BCS: 2`, `AT+BCS=2`, 98.8 s).
- **Kernel:** never sent the setup (no "mSBC:" line), and no (e)SCO link came up. The router logged "no SCO link, SLIMBUS_7 KHZ_8".
- **PulseAudio:** every later Acquire got `org.ofono.Error.InProgress`, also when switching the card to `handsfree_head_unit` long after the calls. ofono's card was stuck with a pending connect:
  - `bcs_cb()` → `connect_sco()` → `ofono_handsfree_card_connect_sco()` returned 0 (else it would have fallen back to CVSD with `+BCS: 1`);
  - so a non-blocking SCO `connect()` was started that never completed or failed;
  - ofono sets no timeout on it.
- **After reconnecting the earbuds** (`bluetoothctl disconnect` / `connect`, which resets ofono's card), the same chain worked twice without a call: card to `handsfree_head_unit`, `source.fake.sco` opened. Each time:
  - "mSBC: enhanced setup, controller codec, PCM path (attempt 1)";
  - then "offloaded link up (1 active)" 65–85 ms later;
  - `hcitool con` showed the eSCO link, and `sco_offload_msbc_active` was 1.
  - The second run was several minutes after the first, with the codec already negotiated (no `+BCS`).

  So the kernel patch and the negotiation work; the stall is specific to the call.
- **Candidate cause, unconfirmed:** an existing SCO `hci_conn` that is neither open nor closed (for example a link the earbuds tried to open at the ring). `hci_connect_sco()` then returns without calling `hci_setup_sync()`, and the socket waits forever.
- **Next:** a call with an HCI trace (`tools/phone-debug/stone-bt-call-debug.sh`, sudo: `btmon` plus the kernel, ofono, PulseAudio and router logs).
- **Traced test** (`stone-bt-call-debug.sh`, output in `out/halium14/logs/bt-call-msbc/`): the outgoing call worked, with sound both ways; the **incoming call was still silent**.
  - ofono did not hang this time. Both calls got an mSBC link: the HCI trace shows Enhanced Setup with mSBC on air, linear PCM 16-bit, data path 0x01, packet type `0x0380`, latency 13, retransmission 2. The completion reported eSCO, air mode Transparent, 60-byte packets, interval 12 slots. The kernel logged "offloaded link up", and the router chose `KHZ_16` for both calls.
  - The difference is in the SLIMbus channels. Incoming call:
    - RX (port 16, downlink to the chip) opened at 1148.07 s at **8000 Hz**;
    - TX opened at 1150.15 s at 16000 Hz.

    Outgoing call: both at 16000 Hz.
  - Cause: on an incoming call, telephony-service moves the route to Bluetooth while the ringtone plays. PulseAudio's media stream (MultiMedia5 → `SLIMBUS_7_RX`) then starts the back end at the UCM default of 8 kHz, before the router sets the rate. The voice session joins the back end at 8 kHz while the chip expects 16 kHz PCM.
  - Fix in `bt_rate()`: `pactl suspend-sink sink.primary 1` and `suspend-source source.primary 1` (which closes PulseAudio's side of the back end), set the rate, resume both, then start the voice session.
  - The first test's ofono hang has not come back; if it does, the HCI trace will show it.
- **Live test of the fix** (router live-installed, 2026-11-11, user: "both calls worked"):
  - Incoming call: the ringtone again opened SLIMbus RX at 8000 Hz (1485.56 s); the router suspended and reopened it at 16000 Hz (1490.87 s), and TX at 16000 Hz (1491.02 s), before the voice session.
  - Outgoing call: 16000 Hz throughout.
  - Both links were mSBC ("offloaded link up").
- Image `c57e8b19f92b477041c5b9e176568a29000ea28672175782a454a0cb59ffb524`: kernel `#17` (byte-identical), and the router byte-identical to the tested one. Not yet written.
- Still open:
  - The ofono hang from the first test (a pending SCO connect, `InProgress` until the earbuds reconnect) has not come back. If it does, `stone-bt-call-debug.sh` captures the HCI trace.
  - Only the Moondrop Nekocake was tested; a headset without wideband speech should negotiate CVSD and get `KHZ_8`.
- Unrelated observation: after this boot hciconfig shows the adapter address byte-reversed relative to the earlier reading; the paired earbuds still connect.

### In-call volume (2026-11-11)

User report: during an earpiece call, the volume keys change the speaker (media) volume and not the call.

What happens:
- **The keys.** Lomiri's volume keys go to ayatana-indicator-sound (`24.5.3`, UBports patch `0001-phone-volume-step.patch`). It controls the `phone` media role (through module-stream-restore) whenever a sink input with `media.role=phone` exists, corked or not. Otherwise it controls the playing stream, or the `alert`/`multimedia` role.
  - On Halium devices that phone stream is pulseaudio-modules-droid's voice-call stream, and its volume goes to the audio HAL.
  - Our calls bypass the HAL (`docs/roadmap-hardware.md` item 6), so there was no phone stream, and the keys changed media.
- **The DSP volume cannot be used.** The HAL's way in is `Voice Rx Gain` → `voc_set_rx_vol_step()` → `VSS_IVOLUME_CMD_SET_STEP`, which needs the ACDB volume calibration table. Without ACDB the kernel logs, at every call start:
  - `voice_send_cvp_register_vol_cal_cmd: Voice_get_cal failed for cal 3`;
  - `voice_send_vol_step_cmd: DSP returned error[ADSP_EFAILED]`;
  - `voice volume failed`.

  So a volume step is rejected.
- **The codec is the place.** The downlink reaches the output through the codec's RX interpolators, which have plain digital gains (0–124, 1 dB per step, 84 = 0 dB, all at 84). The UCM profile defines no hardware volume (PulseAudio scales in software), so these controls are free to use:
  - Earpiece: `RX INT0` (`RX_RX0 Digital Volume`);
  - Speaker: `RX INT2` (`RX_RX2`);
  - 3.5 mm headphones: `RX INT0` and `INT1`.

  USB and Bluetooth calls leave the DSP for the device without passing the codec.

Fix: `usr/lib/stone/call_volume.py`, used by `call-audio-router.py`.
- **The stream.** While ofono has a call in `dialing`/`alerting`/`active`/`held`, it keeps a **corked** playback stream with `media.role=phone` ("Call volume", 8 kHz mono, created with `PA_STREAM_START_CORKED`).
  - Corked, it never plays: it neither wakes the sink nor triggers `module-role-cork`, so media behaves during calls as before.
  - libpulse runs through ctypes on the router's GLib loop (`libpulse-mainloop-glib`), subscribed to sink-input events.
- **The mapping.** The stream's volume (the indicator's slider *f* = volume / `PA_VOLUME_NORM`) sets the active route's codec gain:
  - -15 dB (`f` = 0.562, the phone role default in `touch-stream-restore.table`) = 0 dB, the old fixed level;
  - below that, PulseAudio's cubic curve relative to the default, down to -40 dB; 0 or muted = silent (control value 0);
  - above it, linear up to `~/.config/stone/call-volume-max-db` (default +6 dB).

  With the indicator's 1/6 steps, starting from the default: up +2, +5, +6 dB; down -9, -23, -40 dB, then silent.
- **The route.** On a route change the old route's controls go back to 84, and the new route gets the gain. At the end of the call everything goes back to 84.
- **The saved volume.** The phone role volume saved on the test phone was 23 % (-38 dB, origin unknown). So the first time the stream appears, the role is set once to the default and `~/.config/stone/call-volume-initialized` is written; after that the user's choice persists from call to call.

Checked without a call (as phablet):
- the stream appears; the role volume at 90 % gave `RX_RX0` 89 (+5 dB), at 30 % 68 (-16 dB);
- a route switch to the speaker moved the gain to `RX_RX2`;
- disabling it removed the stream and put both controls back to 84.

Live install: `tools/phone-debug/stone-call-volume-install.sh` (not during a call).

Live test (2026-11-11, user: "all tests passed"). Router log of the test call:
- Earpiece: the keys stepped `RX_RX0` through 0 (silent), 52 (-32 dB), 70 (-14 dB), 81 (-3 dB), 85 (+1 dB), 88 (+4 dB) and 90 (+6 dB), and back. The indicator moves the slider on its 1/6 grid (0, 17, 33, 50, 67, 83, 100 %).
- Speaker: after the switch the gain moved to `RX_RX2` and followed the keys there.
- After the call both controls were 84 again, and media volume behaved as before.

After the test, the "PulseAudio connection closed" log line is printed only for an unexpected disconnect, not for the router's own close at the end of a call. That is the only change from the tested file.

Image `f4a9cf05483cc630e520d4e3581651c0a1acd134a5d0200807b543a4d6152e6e`: the `#15` kernel (byte-identical), plus `call_volume.py` and the router. Not yet written.

Still open: USB and Bluetooth calls keep the device's own volume (the keys still change the phone role, which has no effect there). For Bluetooth, the matching control would be the headset speaker volume over HFP (`+VGS`); not done.

## 10. GPU and graphics APIs

Goal: know which GPU path the system uses, whether that is the intended one, and which APIs (OpenGL ES, OpenGL, Vulkan) have hardware acceleration.

What is seen: hardware acceleration seemed to work since the first boot (smooth UI), but it was never tested.

### Current state (2026-11-11, image `065ee6e5…`)

**The path in use is the intended one.**
- UBports' Mir 1.8.3 fork (`mir1`) has a single server platform, `/usr/lib/aarch64-linux-gnu/mir1/server-platform/graphics-android2.so.16`. It composes through hwcomposer, as on any Halium device.
- Lomiri (`lomiri --mode=full-greeter`) has these mapped:
  - glvnd `libEGL.so.1` → `libEGL_libhybris` → Android `libEGL` (META-EGL) → `/vendor/lib64/egl/libEGL_adreno.so`, `libGLESv2_adreno.so`, `libgsl.so` (the KGSL client) and `libllvm-glnext.so` (Adreno shader compiler);
  - the QTI gralloc mapper 4.0, `graphics-android2.so.16` and `eglplatform_null`.

  `libEGL_mesa` is mapped too, because glvnd loads every vendor (`/usr/share/glvnd/egl_vendor.d/10_libhybris.json` before `50_mesa.json`), but it is not what renders.
- Apps (morph-browser, for example) map the same Adreno libraries.

Device nodes: `/dev/kgsl-3d0` (`system:system 0666`, the GPU) and `/dev/dri/card0` + `renderD128` (`root:android_graphics 0666`), which belong to the msm display (SDE) driver. That DRM device has no GPU behind it: the Adreno is only reachable through KGSL.

GPU: `Adreno619v2`, 266/390/490/650/700 MHz, devfreq governor `msm-adreno-tz`, scaling as expected (390 MHz, 38 % busy right after the tests), `thermal_pwrlevel` 0. Correction (item 11): while Lomiri scrolls, the governor stays at 266 MHz at ~60 % busy, which caps scrolling at 60 fps on the 120 Hz panel.

Measured with `tools/phone-debug/gpu-probe.py`: ctypes probes, because the rootfs has no eglinfo, glxinfo or vulkaninfo. They run as phablet, headless (pbuffer), with `GLIBC_TUNABLES=glibc.rtld.optional_static_tls=65536` for libhybris in Python (see item 3).

| API | Path | Result |
| --- | --- | --- |
| OpenGL ES 2.0/3.x | libhybris → Adreno (`EGL_PLATFORM=null`, pbuffer) | **Hardware.** `Qualcomm` / `Adreno (TM) 619` / `OpenGL ES 3.2 V@0530.0 (GIT@c263890aed, Ifb496a9c37, 1656315076) (Date:06/27/22)`, GLSL ES 3.20, 98 GL extensions, EGL 1.5 "Android META-EGL" with 45 extensions. glClear + glReadPixels read back exactly `[64, 128, 191, 255]` |
| OpenGL (desktop) | libhybris → Adreno | **Not available.** `EGL_CLIENT_APIS` is only `OpenGL_ES`; a GL config fails with `EGL_BAD_ATTRIBUTE` |
| OpenGL (desktop) and GLES | Mesa 24.0.9 (`EGL_PLATFORM=surfaceless`, Mesa vendor only) | **Software:** `llvmpipe (LLVM 17.0.6, 128 bits)`, OpenGL 4.5 Compatibility / GLES 3.2. The same with `MESA_LOADER_DRIVER_OVERRIDE=kgsl` or `msm`: surfaceless only opens DRM render nodes, `renderD128` is display-only, and Mesa 24.0's Gallium freedreno has no KGSL backend (`kgsl_dri.so` exists but is not reached) |
| Vulkan | `libvulkan1-hybris` (`/usr/lib/aarch64-linux-gnu/libvulkan.so.1.2.183`, libhybris's own loader; no Khronos ICDs installed) → `/vendor/lib64/hw/vulkan.adreno.so` | **Hardware.** 13 instance extensions including `VK_KHR_wayland_surface`. One device: `Adreno (TM) 619`, integrated, API **1.1.128**, driver `0x80212000` (512.530.0), vendor `0x5143`, 63 device extensions including `VK_KHR_swapchain` and `VK_ANDROID_external_memory_android_hardware_buffer`. `vkCreateDevice`, a queue and `vkDeviceWaitIdle` all succeed |
| Vulkan on screen | libhybris `test_vulkan` (Wayland client on Lomiri's `wayland-0`: surface, swapchain, render loop) | Runs: past 1140 frames in 12 s, clean exit. The screen was off, so presentation was not throttled and nobody saw the window |

Lomiri itself (Qt Quick on GLES through Mir) is proof of on-screen GLES. "`dlopen failed: library "libadreno_app_profiles.so" not found`" is printed by the Adreno driver at start. This vendor does not ship that library (per-app tuning profiles), so it is harmless.

### Recommendations

Nothing needs fixing for the system. The UI, Qt apps, QtWebEngine and Vulkan apps all get the GPU. Options, if they are ever wanted:

1. **Hardware desktop OpenGL** (Libertine/X11 desktop apps, some games). Today these fall back to llvmpipe on the CPU.
   - Lowest risk: **gl4es** (OpenGL 1.x/2.1 → GLES 2 translation, as a library or `LD_PRELOAD`) on top of the hybris GLES. It covers older GL apps and games. It is not in Ubuntu's archive, so it would need building and shipping.
   - Research only: **turnip (Mesa Vulkan) with its KGSL backend, plus zink** (Mesa OpenGL on Vulkan), which would give OpenGL 4.6 and Vulkan 1.3 in hardware with open drivers. It needs Mesa built with `-Dfreedreno-kmds=kgsl` (Ubuntu builds only `msm`), a Vulkan loader that coexists with `libvulkan1-hybris`, and buffer sharing with the hybris/Mir compositor. That is a large project.
   - zink on the vendor Vulkan through libhybris is not recommended: Vulkan 1.1.128 lacks much of what zink needs, and zink expects Mesa's winsys.
2. **Vulkan 1.1 → 1.3** would need newer Adreno blobs than this vendor's 2022 `V@0530` (the A619 hardware gets 1.3 from newer drivers). Replacing GPU blobs under a vendor is risky. Not recommended unless an app needs it.
3. Optional check: run libhybris' `test_vulkan` with the screen on and unlocked (`XDG_RUNTIME_DIR=/run/user/32011 WAYLAND_DISPLAY=wayland-0 test_vulkan`) to see its window. Headless and off-screen presentation already work.

### Events

- 2026-11-11: the user reports acceleration has seemed fine since the first boot. Checked the compositor path, the device nodes and the GPU clocks. Probed GLES (hardware), desktop GL (Adreno: none; Mesa: llvmpipe, also with the kgsl/msm overrides) and Vulkan (hardware, device creation, and `test_vulkan` presenting on Lomiri's Wayland). Wrote `tools/phone-debug/gpu-probe.py`. No changes to the image.


## 11. 120 Hz display

The panel (`1080x2400`, DSI video mode) has a 120 Hz and a 60 Hz mode, each in two pixel-clock variants (`1080x2400x120x183275vid`, `…x184666vid`, `1080x2400x60x…`). It worked at 120 Hz on Android. On Ubuntu Touch there was no 60/120 switch, and scrolling did not feel like 120 Hz (user, 2026-11-11).

### What the display stack does

- **Mode.** Qualcomm's composer starts in config `#0`, 120 Hz. Mir's Android platform (the hwc2 compat layer, `libhwc2_compat_layer.so`) only reads the active config: there is no call to list or set configs. Mir builds one mode from its vsync period, and `mirout` shows `1080x2400 120.00`. Lomiri's Qt Quick animation driver uses 8.33 ms. So nothing was set to 60.
- **Two compositors.** `lomiri-system-compositor` (started by lightdm through `lsc-wrapper`) owns hwcomposer. Lomiri is a nested Mir server (`MIR_SERVER_HOST_SOCKET=/run/mir_socket`) that renders with Qt Quick's threaded render loop into a mirclient surface of the system compositor. Apps are mirclient clients of Lomiri (`QT_QPA_PLATFORM=ubuntumirclient` for Qt 5).
- **The system compositor** composes every frame with GL into its framebuffer target (HWC2 overlays are not used), presents it to HWC, and then waits.

### Measurements

Tools (no root needed unless noted):
- `tools/phone-debug/fps-panel.py`, once a second:
  - the real panel vsync period, from `/sys/class/drm/sde-crtc-0/vsync_event`, which is notified on every vsync;
  - frames committed to the panel (`measured_fps`);
  - GPU load and clock (kgsl);
  - CPU cluster clocks.
- `tools/phone-debug/fps-probe.qml`: a full-screen animating test app.
- `tools/phone-debug/fps-test.sh`: the phases, plus Lomiri's per-frame render-loop timing (`QSG_RENDER_TIMING=1`), turned on through a runtime drop-in with `lomiri-report-on`.
  - `sudo … clocks` compares clock settings.

Results (2026-11-11):

| Case | Panel vsync | Frames to the panel | Notes |
| --- | --- | --- | --- |
| Stock, scrolling the app drawer or Settings | 8.35 ms (119.7 Hz) | 55–62 fps | Lomiri: 6 ms render, then 9 ms blocked in `eglSwapBuffers` |
| Compositor wait removed, test app | 8.35 ms | 104–116 fps | the app renders 120 fps; Lomiri 1 ms render |
| Compositor wait removed, app drawer, stock governors | 8.35 ms | 57 fps | GPU 266 MHz at ~60 % busy |
| … GPU governor `mod_percent=200` | 8.35 ms | **96–100 fps** | GPU ramps itself to 700 MHz |
| … GPU floor 490 MHz | 8.35 ms | 84–89 fps | |
| … CPU clusters at max, GPU stock | 8.35 ms | 61–70 fps | the CPU is not the limit |
| … GPU and CPU at max | 8.35 ms | 104–107 fps | Lomiri 4 ms render + 4 ms swap |

Notes:
- The test app's own QML `frameSwapped` counter under-counted by half. The app rendered 119–120 frames a second, counted from Qt's render-timing log. Apps are not capped at 60.
- With everything at max, about 105 fps is the ceiling for the app drawer through the two compositors (the CPU, the GPU and both compositors work one after another per frame). Simpler scenes reach 115.

### 120 Hz: what fixed it

1. **The system compositor's present-fence wait.**
   - In `mir-android2-platform`, `RealHwc2Wrapper::set()` (`real_hwc2_wrapper.cpp`) presents frame N, then calls `sync_wait(last_present_fence, -1)` on frame N-1's fence. It carries the comment "FIXME: is needed at all?". With Qualcomm's composer that wait costs a whole extra vsync per frame, so the system compositor never passed 60 fps, and Lomiri sat blocked in swap.
   - Without the wait, back pressure still comes from Mir's three framebuffers, each guarded by the present fence of the frame after it (`update_usage()`).
   - The fix: at boot, `/usr/lib/stone/display-setup.sh` copies `graphics-android2.so.16` to `/run/stone-display/`, changes that one call's timeout from -1 to 0 (`mov w1,#-1` → `mov w1,#0` at file offset `0x3c834`), and bind-mounts the copy over the original. It does this only when the installed file is the exact build it was made for:
     - package `mir1-platform-graphics-android2-16` `1.8.0~20260320103600.20~72f96d2+ubports24.04.2`;
     - stock sha256 `146cf674…`, patched `bc58bdfd…`.

     Any other build is left alone and logged, so a package update falls back to 60 fps pacing and nothing breaks.
   - The proper source fix, for upstream: `tools/upstream/mir-android2-platform-0001-hwc2-dont-block-on-previous-present-fence.patch`.
2. **The GPU governor.**
   - `msm-adreno-tz` saw ~60 % busy while Lomiri scrolled, because each frame is serialized (Lomiri on the CPU, its GPU work, then the system compositor), and kept the GPU at 266 MHz. At that clock a frame takes ~16 ms.
   - The governor's `mod_percent` (`/sys/class/kgsl/kgsl-3d0/devfreq/mod_percent`, 10–1000, default 100, kept across suspend) scales the busy time it sees. The fix sets it to 200 at boot. The GPU then ramps to 700 MHz under scrolling and drops back when idle.
   - On Android, Qualcomm's perf HAL raises the clock floors on touch instead.
3. **Refresh rate choice.**
   - `/usr/lib/stone/display-mode.py` talks to the composer's own `vendor.display.config@2.0::IDisplayConfig` (hwbinder): `registerClient` with a local callback object, then `perform()` with the opcodes and packed structs of Qualcomm's display-commonsys.
   - `list`, `get` and `set 60|120` work as phablet. A set is applied at the composer's next commit: switching to 60 measured a vsync of 16.71 ms and 60 committed frames, and back at 120, 8.35 ms.
   - Mir reads the rate only when it starts, so running clients keep their old pacing after a live switch.
   - Hence `stone-refresh-rate`:
     - `sudo stone-refresh-rate 60|120` saves the choice in `/etc/stone/refresh-rate` and switches now;
     - `--restart-display` also restarts lightdm;
     - `display-setup.sh` applies a saved 60 before lightdm at boot. The default is 120 (no file).

Files: `etc/systemd/system/stone-display-setup.service` (oneshot, `Before=lightdm.service`, enabled through `multi-user.target.wants`), `usr/lib/stone/display-setup.sh`, `usr/lib/stone/display-mode.py`, `usr/bin/stone-refresh-rate`. Live install: `tools/phone-debug/stone-display-install.sh`, then reboot.

### Reboot test (2026-11-11)

- **120 Hz boot**, with both fixes from `stone-display-setup.service`, user confirmed:
  - test app: 101–114 fps on the panel, the app rendering 120;
  - app drawer: 95–103 fps, the GPU ramping to 700 MHz by itself;
  - System Settings: up to 103 fps.
- **60 Hz boot** (`sudo stone-refresh-rate 60`, reboot): the composer kept the config when the system compositor connected.
  - Panel vsync 16.5 ms; the test app paced itself at exactly 60 fps, because Mir read 60 at start; the app drawer ran at 60.
  - **But the screen flashed constantly** (user).

### 60 Hz flicker: cause and fix

- The panel (`qcom,mdss_dsi_m17_38_0c_0a_fhdp_dsc_vid`, Samsung DDIC, DSC, video mode) has a single 120 Hz timing. Its 60 Hz modes are Qualcomm dynamic FPS:
  - `qcom,dsi-supported-dfps-list = 120 60`, `dfps_immediate_porch_mode_vfp`: the same timing with a longer vertical front porch;
  - two DSI bit clocks (`qcom,dsi-dyn-clk-list`), which give the two variants of each mode.
- The DDIC must also be told the rate. Xiaomi's per-timing commands `qcom,mdss-dsi-dispparam-bc-60hz-command` (`f0 5a 5a`, `60 21`, `f7 0b`) and `bc-120hz-command` (`60 01`) set register `0x60`.
- The kernel sends them in two places:
  - `dsi_panel_enable()`, for the current mode;
  - `dsi_set_backlight_control()`, called from `sde_encoder_kickoff()` on every frame, which sends one when `cur_mode` refresh differs from `panel->dsi_refresh_flag`.
- `dsi_refresh_flag` starts at **60** (`dsi_panel.c`). With continuous splash (this phone: "cont_splash enabled"), the bootloader leaves the DDIC in its 120 Hz setting, and `dsi_display_enable()` returns early (`panel_initialized = true`, no `dsi_panel_enable()`).
  - On Android, and on a 120 Hz boot here, the first frame is 120 ≠ 60, so `BC_120HZ` is sent; a later switch to 60 sends `BC_60HZ`.
  - A boot straight into 60 Hz: 60 = 60, so nothing is sent. The DDIC stays in its 120 Hz setting while frames arrive at 60. The kernel log shows no `refresh_rate =` line from `dsi_set_backlight_control()` on that boot.
- Fix: `kernel/patches/0008-dsi-send-refresh-rate-command-on-first-frame.patch` starts `dsi_refresh_flag` at 0, so the first frame always sends the command for its rate. Kernel `#15 SMP PREEMPT Wed Nov 11 12:58:15 EST 2026`: `kernel/build-14/arch/arm64/boot/Image`, 48130560 bytes, SHA256 `5f9853f45a07d99372131a8a4ae7e5319aaef5d26fb48cfc868c5c1397971a1c`. `#14` is kept at `out/halium14/Image-14`.
- Check without the new kernel: turning the screen off and on runs `dsi_panel_enable()`, which sends `BC_60HZ`, so the flicker should stop until the next reboot.

### Still open (120 Hz)

- 60 Hz boot with kernel `#15`: no flicker (user, image `675fd590…`). Earlier, confirmed without the new kernel: after a screen off/on at 60 Hz (which sends `BC_60HZ` through `dsi_panel_enable()`), the flashing stopped (user, 2026-11-11).
- Image `675fd59048e4c2581ab28124bdb7b4ba7ad8f93f99c36b73f105871d6f8fe0d7`: the `#15` Image (byte-identical), with the item 11 files in the overlay. Written 2026-11-11 (user): it works as expected; the phone was set back to 120 Hz.
- Power: 120 Hz scanout costs more than 60 Hz even when nothing changes (video mode, no panel self-refresh), and the GPU now clocks higher while drawing. Battery drain at 60 vs 120 has not been measured.
- Not done: Android-style dynamic switching (60 Hz when idle, 120 Hz on touch). Mir paces clients by the rate it read at start, so it would need Mir changes.

### Refresh rate in System Settings

System Settings > Brightness has a **Refresh rate** section under "Adjust automatically":
- **Standard (60 Hz)** or **Smooth (120 Hz)**;
- a caption: 120 Hz is smoother and uses more battery. When the saved rate differs from the panel's current one, the caption says so ("Now 60 Hz; 120 Hz after the display restarts").
- Choosing the other rate opens a dialog:
  - **Restart display now:** saves, switches the panel and restarts lightdm. Open apps close, and the phone locks.
  - **At next restart:** saves only.
  - **Cancel**

How it is built:
- **The page.** The stock page is `/usr/share/lomiri-system-settings/qml-plugins/brightness/PageComponent.qml` (lomiri-system-settings `1.3.2+0~20260808143253.1`, sha256 `c7bd6ca8…`).
  - `/usr/share/stone/settings/brightness-PageComponent.qml` is that page plus one `Loader` for `/usr/share/stone/settings/RefreshRate.qml`.
  - `display-setup.sh` bind-mounts the copy over the stock page at boot, only when the checksum matches. After a package update the section is simply missing, and the journal says why.
- **The backend.** `RefreshRate.qml` uses pyotherside (`qml-module-io-thp-pyotherside`, installed system-wide) with `/usr/share/stone/settings/refresh_rate.py`.
  - The helper reads `/etc/stone/refresh-rate`, and the panel's current mode through `display-mode.py get`.
  - It writes requests (`<60|120> <save|restart>`) to `/run/stone-refresh-rate/request`. The directory is `0770 root:phablet`, from `usr/lib/tmpfiles.d/stone-refresh-rate.conf`.
- **The root side.** `stone-refresh-rate.path` (`PathChanged=`) starts `stone-refresh-rate-request.service`, which runs `/usr/lib/stone/refresh-rate-request.sh` as root. The script checks the request, then saves it or runs `stone-refresh-rate <rate> --restart-display`.
- lomiri-system-settings runs unconfined (no AppArmor profile), and the section is in its own file.

Live test (2026-11-11, user):
- The section appears.
- 60 Hz with "Restart display now" works, without flicker.
- Back to 120 Hz with "At next restart": the caption showed the pending change, and the reboot came up at 120 Hz.
- **After that reboot the section was gone.**
  - Cause: init installs the overlay with `cp -R /stone-rootfs/. /newroot/` on every boot. The flashed image (`675fd590…`) still carried the older `display-setup.sh`, which overwrote the live-installed one and has no Settings step.
  - All the section's files are in the new image (`0ea13aae…`), so it now persists.

### Events

- 2026-11-11: user report (no 60/120 switch, not 120 Hz smooth). Measured: panel at 120 Hz, frames at 60.
  - Found the system compositor's present-fence wait and tested it removed (runtime bind mount, `tools/phone-debug/stone-fps-nowait.sh`): 104–116 fps for a test app, the app drawer still at 60.
  - Clock A/B and comparison: the GPU governor is the second limit (`mod_percent=200`: 96–100 fps).
  - Wrote the display-config client, the switch and the boot fix; the live install is ready (`stone-display-install.sh`).
  - Live install and reboot: 120 Hz works (user). A 60 Hz boot flickers: the panel's 60 Hz command is never sent after continuous splash. Kernel patch 0008 written; kernel `#15` built. Image `675fd590…` written: 60 Hz without flicker, 120 Hz fine (user).
  - Added the refresh rate section to System Settings > Brightness. Live test passed, except that it disappeared after a reboot (the older image's overlay replaced the setup script). Image `0ea13aae…` built with all of it.

## 12. Wi-Fi network list

Goal: each Wi-Fi network appears once in the network indicator and in System Settings > Wi-Fi.

User report (2026-11-12): the list of available networks repeats itself, in both places; connecting works. The Nothing Phone (1) on 24.04 shows each network once.

What is seen:
- NetworkManager managed two Wi-Fi devices, `wlan0` (connected) and `wlan1` (disconnected), plus their Wi-Fi Direct devices `p2p-dev-wlan0` and `p2p-dev-wlan1`. `nmcli dev wifi list` returned the same scan results, BSSID for BSSID, once per device.
- `wlan1` comes from the vendor's `/vendor/etc/wifi/WCNSS_qcom_cfg.ini`: `gEnableConcurrentSTA=wlan1`. qcacld creates a second station interface for Android's dual-STA feature (also present since kernel `#9`: `wlan0`, `wlan1`, `p2p0`, `wifi-aware0`; `docs/roadmap-hardware.md`).
- The indicator and Settings list access points per device, hence the duplicates.
- No NetworkManager configuration set `unmanaged-devices` (`NetworkManager --print-config`), so a `[keyfile]` entry does not override anything.

Fix: `etc/NetworkManager/conf.d/stone-wlan1-unmanaged.conf`, `[keyfile] unmanaged-devices=interface-name:wlan1`.
- Changing the ini instead would mean overriding a vendor file that the driver loads through the kernel's firmware loader, outside the container's overlay.
- Ubuntu Touch uses one Wi-Fi interface. The hotspot (not yet tested, `docs/roadmap-release.md` item 11) runs on `wlan0` through NetworkManager.

Live test (2026-11-12): the file was installed and NetworkManager reloaded (`systemctl reload NetworkManager`, no disconnect).
- `wlan1` became `unmanaged`, the scan list came only from `wlan0`, and `wlan0` stayed connected.
- The user confirmed each network shows once in the indicator and in Settings.
- `p2p-dev-wlan1` stayed as "unavailable" until the next boot; it is not listed as a network.

Image `out/halium14/boot-ut.img` SHA256 `69b9f797631eae7d3b1dae005aafcb09c9d2918a4414b4801a63bb91825ba75a` (copy `boot-ut-69b9f797.img`), kernel `#20`. It is `3cdee49b…` plus this file, byte-identical to the tested one; kernel and recovery identical. Written and confirmed on 2026-11-12 (user): each network shows once.
