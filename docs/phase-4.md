# 阶段 4：平板日常

在外置盘已经点亮进入桌面的 `6.6.34-phase2` Android 16（LineageOS 23.2）上，按顺序补齐硬件加速与平板日常外设。不换 6.12 或 6.18，不写 eMMC，不重分外置盘 GPT，不格式化 `userdata`。阶段 3 的记录在 [阶段 3](phase-3.md)。

产品形态仍以 `third_party/android_device_google_trogdor-lineage-24` 为准。两边不一致时，跟做完的设备树。镜像保持 vanilla（不装 GApps、Widevine）。耳机插孔是物理损坏，不测。摄像头和 Hantro 硬解码不在这段的完成标准里。

## 完成标准

1. **流畅桌面与应用**：启用 Panfrost（Mesa）硬件加速、启用 zram，并补齐基础软件特性权限后，桌面（Launcher3）和设置应用不再因缺服务崩溃或软渲染卡死。
2. **外设可用**：触摸和旋转、Wacom 手写笔、背光调节、Wi-Fi 联网（含无线 `adb`）、蓝牙、扬声器音频播放、电量和充电指示均正常工作。电量不出现 postmarketOS 上突然掉到 0、插电又回到 60% 到 70% 的跳变。
3. **一次完整日常闭环**：在 4 GB 内存上完成一次「开机、联网、打开网页、安装应用、睡眠、唤醒」。唤醒后仍是同一次启动，而不是被看门狗打进 bootloader。
4. **内置盘完好**：切回内置盘，postmarketOS v25.06 正常进桌面，`uname -r` 仍是 `6.6.34`，根在 `/dev/mmcblk1p3`，eMMC 的分区表和 `pmOS_kernel` 校验和未变。

## 这次做什么

按 `docs/roadmap.md` 定下的顺序推进，每一小步验证通过后再进下一步：

| 顺序 | 模块 | 做什么 |
| --- | --- | --- |
| 1 | 基础软件权限与 zram | 对照做完的 Trogdor 树，在 `device.mk` 补齐 `android.software.xml`、`android.software.app_widgets.xml`、`android.software.backup.xml`、`android.software.print.xml`、`android.software.voice_recognizers.xml`、`android.software.device_admin.xml` 等基础软件权限，修复 `Launcher3`（`AppWidgetManager` 空指针）和 `Seedvault`（`IBackupManager` 空指针）崩溃。在 `fstab.gru` 和 `init.gru.rc` 启用 `zram`（`swapon_all`）。 |
| 2 | Panfrost 硬件加速 | 把 `TARGET_GRAPHICS` 从 `swiftshader` 切到 `mesa`（Panfrost，Mali-T860，`panfrost.ko` 及依赖模块按需加载），渲染走 `skiagl`，替换掉 1～2 秒一帧的 CPU 软渲染。核对 `minigbm` / `gbm` 与 `drm_hwcomposer` 在 Panfrost 下的 buffer 分配与合成。 |
| 3 | 触摸、旋转与手写笔 | 确认 `elants_i2c`（`ekth3500`）、`wacom`（`2D1F:0036`）、`cros_ec_keyb` 的输入设备分类与 IDC 配置；接入 `cros-ec` 传感器（加速度计 / 陀螺仪）subhal 与方向配置，使屏幕旋转正常工作。 |
| 4 | 背光调节 | 打通 `/sys/class/backlight/backlight`（`pwm-backlight`）与 Android light HAL / 框架亮度滑条的读写权限和映射。 |
| 5 | Wi-Fi 与无线 adb | 放入 `ath10k`（QCA6174 `hw3.0`）固件并加载 `ath10k_pci.ko` 及 mac80211/cfg80211 模块，配置 `wpa_supplicant`（nl80211）与 Wi-Fi HAL。连上局域网后恢复 `adbd`，通过 TCP/IP 验证无线 `adb`（若有线 Type-C OTG 角色切换可行则一并核对）。 |
| 6 | 蓝牙 | 放入 `qca` 蓝牙 USB 固件并加载 `btusb.ko` 等模块，恢复 `vendor.bluetooth-default` HAL 与 `android.hardware.bluetooth` 特性声明，并在系统中重新 enable `com.android.bluetooth`。 |
| 7 | 音频播放 | 按 `rk3399-gru-sound`（DA7219 + MAX98357A）编写音频路由（alsa / tinymix）与 `audio_policy_configuration.xml`，打通 AIDL 音频 HAL 的内置扬声器播放。不测已损坏的耳机插孔。 |
| 8 | 电量与充电 | 核对 `sbs-battery`（`sbs-9-000b`）和 `cros_usbpd_charger` 与 health AIDL HAL 的属性读取，处理 `current_avg` / `technology` 返回 `-5` 的兼容，确认充放电状态和百分比稳定。 |
| 9 | 睡眠与唤醒 | 在确认 `dw_wdt` 30 秒看门狗保活正常的前提下，解开阶段 3 为防崩溃加上的 `/sys/power/state` 封锁，排查并验证 6.6 下睡眠与唤醒不掉回 bootloader、唤醒后仍是同一次启动。 |

## 你来做

1. 每次写入前停在内置盘的 postmarketOS（或已打通无线 `adb` / SSH 的环境）。如果地址变了就告诉我。
2. 我准备好新的 `super.img` 或 `kernel.kpart` 并校验无误后，你在机器终端执行对应的 `doas /home/user/phase3/write-super.sh` 或 `doas /home/user/phase3/write-kernel.sh`。看到 `WRITE_OK` 之后再重启。
3. 启动菜单选外置盘进入 Android，按当前步骤验证对应功能（桌面流畅度、触摸/笔、背光、Wi-Fi、蓝牙、外放声音、充电显示、睡眠唤醒），把现象告诉我。
4. 需要读外置盘 `bootlog` 或重刷分区时，重启选回内置盘，执行 `doas /home/user/phase3/readlog.sh`。

## 我来做

1. 每次写入前确认目标只在外置盘 `mmcblk0`（`KernelA` 为 `mmcblk0p1`，`super` 为 `mmcblk0p6`），不改 GPT，不格式化 `userdata`（`mmcblk0p7`），不动 `mmcblk1`。
2. 按上面的 9 个步骤逐项修改 `device/google/gru`（及必要的内核/模块配置），编译并把产物传到 `/home/user/phase3/`，核对远端 sha256 与镜像大小（FIT 小于 32 MiB）。
3. 每次测试后拉取 `/home/user/phase3/bootlog-copy.txt`（或通过已连通的 `adb` 抓取日志），分析并把进展和问题记录到本文的「实现笔记」和「事件」中，并核对 eMMC `pmOS_kernel` 校验和仍是 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。

## 实现顺序

| 步 | 谁 | 做什么 | 通过条件 |
| --- | --- | --- | --- |
| 1 | 我 / 你 | 补齐基础软件权限、启用 zram、切换 Panfrost 硬件加速，写入并启动外置盘 | 桌面与设置流畅，Launcher3 不再反复崩溃 |
| 2 | 我 / 你 | 配好触摸、旋转、手写笔和背光，写入并验证 | 触控、笔、自动旋转、亮度调节正常 |
| 3 | 我 / 你 | 配好 Wi-Fi、蓝牙、扬声器音频、电量和充电，写入并验证 | 能连 Wi-Fi、打开网页、安装应用、外放发声、电量正常 |
| 4 | 我 / 你 | 调试并验证睡眠与唤醒 | 睡眠唤醒后仍是同一次启动，不掉回 bootloader |
| 5 | 你 / 我 | 选回内置盘，读日志并做最终安全核对 | postmarketOS 进桌面，根在 `mmcblk1p3`，eMMC 校验和未变 |

第 1 步到第 5 步全部通过后，阶段 4 结束。

## 实现笔记

### 1. 基础软件权限与 zram（2026-10-19）

- **基础软件权限**：对照 `third_party/android_device_google_trogdor-lineage-24/device.mk`，新增 `device/google/gru/etc/permissions/android.software.xml`，并在 `device/google/gru/device.mk` 中拷贝 `android.software.xml`、`android.software.cts.xml`、`android.software.app_widgets.xml`、`android.software.backup.xml`、`android.software.voice_recognizers.xml`、`android.software.print.xml`、`android.software.device_admin.xml` 与 `android.hardware.keystore.app_attest_key.xml` 到 `/vendor/etc/permissions/`。使 `SystemServer` 正常启动 `AppWidgetService` 与 `BackupManagerService`，修复 `com.android.launcher3`（`AppWidgetManager.getInstalledProvidersForProfile` 空指针）和 `com.stevesoltys.seedvault`（`IBackupManager` 空指针）崩溃。
- **zram 启用**：`6.6.34-phase2` 内核中 `CONFIG_ZRAM=m`、`CONFIG_CRYPTO_LZ4=m`、`CONFIG_ZSMALLOC=y`、`CONFIG_CRYPTO_ZSTD=y`。从内核构建目录取出零外部模块依赖的 `zram.ko`（50792 字节）和 `lz4.ko`（9856 字节）放入 `device/google/gru/modules/` 并拷入 `/vendor/lib/`；在 `device.mk` 设置 `persist.sys.zram_enabled=1`；在 `init.gru.rc` 的 `on early-init` 加载 `lz4.ko` 和 `zram.ko`，`on init` 写 `/sys/block/zram0/comp_algorithm lz4`，`on fs` 和 `on sys-boot-completed-set && property:persist.sys.zram_enabled=1` 执行 `swapon_all /vendor/etc/fstab.${ro.hardware}`（对应 `fstab.gru` 的 `/dev/block/zram0 none swap defaults zramsize=75%`）。同时在 `gru-logcat.sh` 启动时将 `/proc/swaps` 以 `GRU_SWAP` 前缀打印到 `/dev/kmsg` 以便从启动日志核对。
- **构建产物**：`out/target/product/gru/super.img` 大小 `1258664340` 字节，sha256 `5905b1e2a47c7f5f33e4675bad0452451aeeae6c34d774659d856e0f63a81d0a`。

## 事件

| 日期 | 事件 |
| --- | --- |
