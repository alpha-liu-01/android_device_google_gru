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
- **实机验证（`/tmp/bootlog18.txt`，7818 行）**：
  - `zram` 在 `on fs` 阶段成功挂载：`zram: Added device: zram0`、`Adding 2919648k swap on /dev/block/zram0`（约 2.78 GiB，占 `MemTotal` 75%），`GRU_SWAP /dev/block/zram0 partition 2919648 0 -2`。（`sys-boot-completed-set` 里的第二次 `swapon_all` 因 `zram0` 已初始化返回 `Cannot change disksize for initialized device`，已在 `init.gru.rc` 中移除重复触发，只保留 `on fs` 的一次 `swapon_all`。）
  - 崩溃与 ANR 清零：`com.android.launcher3`（PID 3832）和 `com.stevesoltys.seedvault`（PID 4544）各只启动 1 次，0 次崩溃；整份日志 `FATAL EXCEPTION` 为 0 次，`E AndroidRuntime` 为 0 次，`ANR in` 为 0 次。约 535 秒正常关机（`sys.powerctl='shutdown,userrequested'`）。关机末尾 `libprocessgroup: Failed to write 1 to .../cgroup.kill: No such file or directory` 是收到 `SIGTERM` 的服务已先行退出、内核回收了对应 `pid_*` cgroup 目录所致。

### 2. Panfrost 硬件加速（2026-10-19）

- **内核模块与加载时序**：`6.6.34-phase2` 中 GPU 电源域（`CONFIG_ROCKCHIP_PM_DOMAINS=y`）、IOMMU（`CONFIG_ROCKCHIP_IOMMU=y`）、调压器（`CONFIG_REGULATOR_VCTRL=y`、`CONFIG_REGULATOR_PWM=y`）与 devfreq 调速器（`CONFIG_PM_DEVFREQ=y`、`CONFIG_DEVFREQ_GOV_SIMPLE_ONDEMAND=y`）均已内建；`panfrost.ko` 仅依赖 `drm_shmem_helper.ko` 与 `gpu-sched.ko`。从 `modinstall/lib/modules/6.6.34-phase2` 解压这 3 个模块放入 `device/google/gru/modules/` 并拷入 `/vendor/lib/`，在 `init.gru.rc` 的 `on early-init` 按顺序 `insmod`（在 `surfaceflinger` / `allocator` / `hwcomposer` 启动前生成 `/dev/dri/renderD128` 与 `/dev/dri/card1`，而内建 `rockchip-drm` 固定为 `/dev/dri/card0`）。
- **Mesa（Panfrost）与 Gralloc / HWC 节点分离**：
  - 将 `BoardConfig.mk` 和 `device.mk` 的 `TARGET_GRAPHICS` 切换为 `mesa`，设 `TARGET_GRAPHICS_VULKAN := none`（Mali-T860 为 Midgard v5，仅支持 OpenGL ES 3.1，不支持 PanVK）、`BOARD_MESA3D_GALLIUM_DRIVERS := panfrost`、`TARGET_GRAPHICS_ALLOCATOR_HAL := minigbm-upstream`、`TARGET_MINIGBM_PLATFORM := generic`。
  - 关键防坑：`minigbm-upstream` 的 `init_try_nodes()` 默认优先打开 `/dev/dri/renderD128`，且 `drv_get_backend()` 在找不到 `panfrost` 后端时会回退到 `backend_dumb_generic` 并返回成功，导致后续在 `renderD128` 上调用 `DRM_IOCTL_MODE_CREATE_DUMB` 失败。为此在 `device.mk` 设置 `vendor.minigbm.device=/dev/dri/card0` 与 `vendor.hwc.drm.device=/dev/dri/card0`，使 `minigbm-upstream` 和 `drm_hwcomposer` 固定打开 `/dev/dri/card0`（`rockchip`），而 Mesa（`libEGL_mesa.so` + `libgallium_dri.so`）通过 `DRM_NODE_RENDER` 打开 `/dev/dri/renderD128`（`panfrost`）并通过 PRIME dma-buf 导入 `rockchip` 线性 buffer 进行硬件渲染。
  - 设置 `ro.opengles.version=196609`（OpenGL ES 3.1）、`debug.renderengine.backend=skiaglthreaded`、`debug.hwui.renderer=skiagl`、`ro.surface_flinger.supports_background_blur=0`。
- **构建产物**：
  - 初版（仅 Panfrost）：`out/target/product/gru/super.img` 大小 `1248559508` 字节，sha256 `345ebd9a63dd4d4ed9cb0faf7d65a2c6dd76c37e4e3dad7ff16768381dacf146`。
  - 补齐调频模块版（含 `cpufreq-dt.ko`、`rockchip_thermal.ko`、`rockchip-dfi.ko`、`rk3399_dmc.ko`）：`out/target/product/gru/super.img` 大小 `1248600468` 字节，sha256 `04155eb44d30f74ba84dfc6f3de15d62add9720afd4e971dd7fabab17755e416`，已上传至 `/home/user/phase3/super.img` 并校验一致。
- **实机验证与性能分析（`/tmp/bootlog19.txt`，7542 行）**：
  - **内核驱动上线（`9.96s`，`on early-init`）**：`drm_shmem_helper.ko`、`gpu-sched.ko`、`panfrost.ko` 按序加载成功，`panfrost ff9a0000.gpu: mali-t860 id 0x860 major 0x2 minor 0x0 status 0x0`、`shader_present=0xf l2_present=0x1`（4 核 Mali-T860 MP4 全部就绪，初始频率 500 MHz，OPP 表上限 800 MHz），注册为 `minor 1`（`/dev/dri/renderD128` 与 `/dev/dri/card1`）。
  - **SurfaceFlinger 与 Mesa 硬件渲染确认（`95.47s`，无任何软渲染回退）**：
    - `SurfaceFlinger` 输出 `vendor: Mesa`、`renderer: Mali-T860 (Panfrost)`、`version: OpenGL ES 3.1 Mesa 25.3.3`、`GL_MAX_TEXTURE_SIZE = 16384`。
    - 编译 `libgallium_dri.so` 时仅启用了 `-Dgallium-drivers=panfrost`（未编译 `llvmpipe`/`softpipe`/`swrast`），且移除了 `com.android.hardware.graphics.allocator.minigbm_dmabuf` 与 SwiftShader APEX，从构建产物与日志两方面确认 100% 走 Panfrost 硬件管线，不存在 fallback 到软件渲染或低效模式的情况。
    - `drmhwc`（`hwc3-drm`）成功绑定 `/dev/dri/card0`（`Backend 'generic' for 'DSI-1' and driver 'rockchip' was successfully set`）。
  - **启动耗时与稳定性**：从 `starting service 'surfaceflinger'` 到 `sys.boot_completed=1` 耗时从 SwiftShader 的 `145.71s` 缩短至 `64.36s`（提速 2.26 倍），总开机时间从 `320.06s` 降至 `156.92s`。整次运行至 `220.6s` 用户请求正常关机期间，`FATAL EXCEPTION` 为 0 次，`ANR` 为 0 次，GPU 报错/超时为 0 次。
  - **划屏 30–45 fps 体感原因分析与调频补齐**：
    1. **CPU 调频与内存控制器调频模块补齐与实机验证（`/tmp/bootlog20.txt`，7799 行）**：
       - 排查 `6.6.34-phase2` 内核配置与内置盘 `lsmod`/`dmesg` 发现，`CONFIG_CPUFREQ_DT=m`（`cpufreq-dt.ko`）、`CONFIG_ROCKCHIP_THERMAL=m`（`rockchip_thermal.ko`）、`CONFIG_DEVFREQ_EVENT_ROCKCHIP_DFI=m`（`rockchip-dfi.ko`）与 `CONFIG_ARM_RK3399_DMC_DEVFREQ=m`（`rk3399_dmc.ko`）均为零外部依赖的模块。未加载 `cpufreq-dt.ko` 时，RK3399（OP1）的 4×A53 与 2×A72 锁死在 bootloader 初始频率 `600000 KHz`（600 MHz），无法升频至 `1512000 KHz`（1.512 GHz）/ `2016000 KHz`（2.016 GHz），内存控制器也停留在 `400000000 Hz`（400 MHz）而非上限 `928000000 Hz`（928 MHz）。
       - 从 `modinstall/lib/modules/6.6.34-phase2` 提取这 4 个模块放入 `device/google/gru/modules/` 并拷入 `/vendor/lib/`，在 `init.gru.rc` 的 `on early-init` 按序 `insmod`，同时在 `gru-logcat.sh` 增加 `GRU_FREQ` 输出。
       - **实机验证（`bootlog20.txt`）**：
         - `7.79s` 内核打印 `cpufreq: cpufreq_online: CPU4: Running at unlisted initial frequency: 600000 KHz, changing to: 816000 KHz`，确认解除了 600 MHz 锁频。
         - `73.7s` `GRU_FREQ` 读数确认所有调频器与频率上限全部就位：
           - `policy0`（4×Cortex-A53）：`cur=1512000 max=1512000 gov=schedutil`（满频 1.512 GHz）
           - `policy4`（2×Cortex-A72）：`cur=2016000 max=2016000 gov=schedutil`（满频 2.016 GHz）
           - `ff9a0000.gpu`（Mali-T860 MP4）：`cur=500000000 max=800000000 gov=simple_ondemand`（上限 800 MHz）
           - `memory-controller`（LPDDR3 DMC）：`cur=400000000 max=928000000 gov=simple_ondemand`（上限 928 MHz）
         - **启动耗时三连降**：`surfaceflinger` 启动时间从 `92.56s` 提前至 `73.55s`（提早 19.0 秒），`sys.boot_completed=1` 从 `156.92s` 提前至 `125.21s`（再缩短 31.7 秒，对比 SwiftShader 的 `320.06s` 总计快了 194.8 秒），上次关机前的 `Failed to create DrmKmsPlan` 也降为 0 次。
         - **附带发现（Emulated Storage / `fuse.ko`）**：`bootlog20.txt` 中用户在打开「设置 -> 存储」时触发 1 次 `IllegalArgumentException: Volume external_primary not found`（`StorageAsyncLoader`），排查确认 `CONFIG_FUSE_FS=m`（`kernel/fs/fuse/fuse.ko.xz`，零外部依赖）尚未加载导致 `/dev/fuse` 缺失、`/storage/emulated/0` 未挂载，将在下一轮构建中一并加载 `fuse.ko`。
    2. **2048×1536 高分屏与线性 Buffer 带宽上限（30–45 fps 客观硬件边界）**：在 CPU（1.51 / 2.02 GHz）、GPU（800 MHz）、内存（928 MHz）全部满血工作后，应用打开与触控响应速度明显提升，但桌面划屏帧率仍稳定在 30–45 fps。这确认该帧率是 RK3399 的硬件边界：Scarlet 面板为 2048×1536（314.5 万像素，比 1920×1200 多 36.5%），且 `minigbm-upstream` generic 后端在 `rockchip` VOP 上分配的是未压缩线性 buffer（`DRM_FORMAT_MOD_LINEAR`，单帧 32-bit RGBA 约 12.6 MB），2016 年 Midgard 架构的 4 核 Mali-T860 MP4 在双通道 LPDDR3 共享内存带宽下推动 2K 视网膜屏合成的吞吐上限即在 30–45 fps 区间。

### 3. 触摸、旋转与手写笔（含 `fuse.ko` 补齐）

- **当前实机基线状态记录（2026-10-19）**：
  1. **触摸屏（`Elan Touchscreen`，`elants_i2c 3-0010`）**：在默认方向（竖屏）下基本触控正常（已由第一阶段 ramdisk 加载 `elants_i2c.ko` 注册为 `input0`），待后续进一步核对边缘/多点触控与横竖屏坐标映射等隐性边界情况。
  2. **屏幕旋转**：
     - 在内置盘 postmarketOS v25.06（运行 `kwin_wayland`）上点击自动旋转会直接导致整机卡死；排查内置盘发现 `iio-sensor-proxy` 在后台早已开启 `iio:device0/buffer/enable=1` 正常读取传感器而未卡死。在 Android 下，90°/270° 旋转因 `rockchip` VOP plane 的 `transform_enum_mask_` 不包含 `DRM_MODE_ROTATE_270`，`drm_hwcomposer`（`DrmPlane::IsValidForLayer`）会安全回退到 `SurfaceFlinger` GPU Client 合成。
     - 在外置盘 LineageOS 23.2 上点击自动旋转不会卡死，但旋转无任何效果；手动旋转入口暂未测试。
     - 日志与系统排查：`bootlog19.txt` / `bootlog20.txt` 中 `system_server` 报错 `Could not find android.hardware.sensors.ISensors/default in the VINTF manifest`，且内核 IIO 传感器模块（`kfifo_buf.ko`、`industrialio-triggered-buffer.ko`、`cros-ec-sensorhub.ko`、`cros_ec_sensors_core.ko`、`cros_ec_sensors.ko`）尚未在 Android 下加载。
  3. **Wacom 电磁笔（`2D1F:0036`）**：
     - 在 LineageOS 23.2 下完全无反应（即使已在开发者选项开启“使用手写笔”）。
     - 日志与系统排查：对比内置盘 `/proc/bus/input/devices` 发现，Scarlet 的 Wacom 电磁笔挂在 `/devices/platform/ff120000.i2c/i2c-2/2-0009/0018:2D1F:0036.0001`（`hid-over-i2c 2D1F:0036 Stylus`），驱动模块为 `i2c-hid.ko` 与 `i2c-hid-of.ko`（`CONFIG_I2C_HID_CORE=m`、`CONFIG_I2C_HID_OF=m`，而 `CONFIG_HID_GENERIC=y` 已内建），此外笔槽插拔检测 `switch-pen-insert`（`SW_PEN_INSERTED`）在 `gpio_keys.ko` 中；外置盘 Android 尚未加载这几个模块，因此内核根本未注册 Stylus input 节点。
- **修改与实施方案**：
  1. **补齐内核模块（`device/google/gru/modules/` 与 `init.gru.rc` `on early-init`）**：
     - 存储挂载：`fuse.ko`（`kernel/fs/fuse/fuse.ko.xz`，解决 `/dev/fuse` 缺失导致 `external_primary` 模拟存储未挂载的问题）。
     - Wacom 电磁笔与笔槽开关：`i2c-hid.ko`、`i2c-hid-of.ko`、`gpio_keys.ko`。
     - ChromeOS EC IIO 传感器栈：`kfifo_buf.ko`、`industrialio-triggered-buffer.ko`、`cros-ec-sensorhub.ko`、`cros_ec_sensors_core.ko`、`cros_ec_sensors.ko`（注册 `iio:device0` `cros-ec-accel` 与 `iio:device1` `cros-ec-gyro`）。
  2. **输入设备 IDC 配置（`device/google/gru/idc/`）**：
     - `Vendor_04f3_Product_0b03.idc`（`Elan Touchscreen`，`1856x2496` 原生竖屏）与 `Vendor_2d1f_Product_0036.idc`（`hid-over-i2c 2D1F:0036 Stylus`，`14746x19661` 原生竖屏）：均配置 `device.internal = 1`、`touch.deviceType = touchScreen`、`touch.orientationAware = 1`，使触摸与手写笔坐标在横竖屏切换时自动跟随屏幕方向。
  3. **接入 ChromeOS EC IIO 传感器 HAL（`device/google/gru/hal/sensors/`）**：
     - 参照 `third_party/android_device_google_trogdor-lineage-24/hal/sensors/` 移植 `android.hardware.sensors@2.1-gru-subhal`（配合 `android.hardware.sensors-service.multihal` 及自带 VINTF fragment `android.hardware.sensors-multihal.xml`），在 `scan_elements` 前先确保 `enable_sensor(..., false)` 关闭 buffer。
     - 配置 `/vendor/etc/sensors/hals.conf` 与 `/vendor/etc/sensors/sensor_hal_configuration.xml`（ChromeOS EC 已将 `lid_accel` 校正为面板自然方向，平放时实测 `in_accel_z_raw = +8130` 即 `+9.73 m/s²`，与 Android 标准坐标系一致，故 `x/y/z` 采用 `0/1/2` 恒等映射）。
     - 添加 `/vendor/etc/ueventd.gru.rc` 并在 `init.gru.rc` `on post-fs` 双重设置 `/dev/iio:device0..1` 与 `/sys/bus/iio/devices/iio:device0..1` 下 `buffer/*`、`sampling_frequency`、`scan_elements/*_en` 的 `0660 system system` 权限；补齐 `android.hardware.sensor.accelerometer.xml` 与 `android.hardware.sensor.gyroscope.xml` 权限声明。
- **构建产物**：
  - `out/target/product/gru/super.img` 大小 `1249505684` 字节，sha256 `1e240695d3c4ef4e60755942ae2d0d75095c6a8d4236b4d286caa87662656ab4`。
- **实机验证与日志对照分析（`/tmp/bootlog21.txt`，8231 行）**：
  - **启动耗时与调频复核**：`surfaceflinger` 在 `72.90s` 启动，`sys.boot_completed=1` 在 `124.53s` 完成（比上一轮 `125.21s` 再快 0.68 秒）；`GRU_FREQ` 确认小核 `1.512 GHz`、大核 `2.016 GHz`、GPU `800 MHz`、内存控制器 `cur=928000000 max=928000000` 全程生效；内置盘 eMMC `mmcblk1p1` 校验和保持 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。
  - **本轮验证通过的 3 项功能**：
    1. **Wacom 手写笔（`hid-over-i2c 2D1F:0036 Stylus`）**：`7.45s` `i2c-hid-of` 探测成功并注册 `/dev/input/event3`（`Stylus`）与 `/dev/input/event4`，`EventHub` 加载 `/vendor/usr/idc/Vendor_2d1f_Product_0036.idc` 并绑定至 `display id 0`（`mode DIRECT`）。实测全部 4 个方向点击与悬停（Hover）完全正常，无任何方向错位（手写与压感暂缺测试软件条件）。同时 `gpio_keys.ko` 成功注册 `/dev/input/event5`（`SW_PEN_INSERTED`）。
    2. **自动旋转与四向帧率一致性**：`74.3s` `GoogleIIOSensorSubHal` 成功发现并初始化 `/sys/bus/iio/devices/iio:device0`（`cros-ec-accel`）与 `iio:device1`（`cros-ec-gyro`）。实测自动旋转完全正常，且全部 4 个方向的帧率一致，**未出现** Debian XFCE 下横屏远比竖屏卡顿的问题（原因：Debian XFCE 下 Xorg 使用 CPU 软旋转，而 Android 下当 `rockchip` VOP 硬件平面不支持 90°/270° 时，`drm_hwcomposer` 自动回退由 `Mali-T860 (Panfrost)` 在 GPU 硬件合成阶段直接完成旋转纹理渲染）。
    3. **「设置 -> 存储」（`fuse.ko`）**：`7.26s` `fuse: init (API version 7.39)` 初始化成功，`external_primary`（`/storage/emulated/0`）正常挂载，「设置 -> 存储」打开完全正常，上一轮的 `Volume external_primary not found` 异常彻底消失。
  - **本轮实测新发现的问题与 `bootlog21.txt` 根因定位及修复排期**：
    1. **缺少虚拟导航栏（三键导航 / 手势导航均不显示，且设置中无入口或打不开）**：
       - **根因**：`device/google/gru` 尚未像 `third_party/android_device_google_trogdor-lineage-24` 一样配置 `DEVICE_PACKAGE_OVERLAYS := $(LOCAL_PATH)/overlay`。AOSP 默认 `config_showNavigationBar = false`（假定机身带实体 Home/Back 按键），导致 `WindowManagerService.hasNavigationBar()` 返回 `false`，`SystemUI` 不渲染导航栏，且「设置 -> 系统 -> 导航模式」隐藏入口。
       - **修复排期**：**放入第 4 步（背光调节）一并修复**——参照 Trogdor 补齐 `device/google/gru/overlay/frameworks/base/core/res/res/values/config.xml`（开启 `<bool name="config_showNavigationBar">true</bool>`，并声明 `config_voice_capable=false`、`config_sms_capable=false`）。
    2. **点击搜索框时屏幕虚拟键盘（IME）不弹出**：
       - **根因（见 `bootlog21.txt` 第 6550 行）**：`rk3399-gru.dtsi` 默认 `#include <arm/cros-ec-keyboard.dtsi>`（`compatible = "google,cros-ec-keyb"`，含完整笔记本 8×13 矩阵键盘映射），而纯平板 `rk3399-gru-scarlet.dtsi` 未将其覆写为仅按键的 `google,cros-ec-keyb-switches`。因此 `cros_ec_keyb.ko` 除了注册音量/电源键的 `cros_ec_buttons`（`/dev/input/event2`）外，还额外注册了一个名为 `cros_ec`（`/dev/input/event1`）的全尺寸键盘设备；`EventHub` 检测到其包含 `AKEYCODE_Q` 且 `builtinKeyboard=false`，将其归类为外接全键盘（`classes=KEYBOARD | ALPHAKEY`），Android 默认在外接硬键盘连接时隐藏屏幕软键盘（`show_ime_with_hard_keyboard=0`）。
       - **修复排期**：**放入第 4 步（背光调节）一并修复**——① 新增 `/vendor/usr/keylayout/cros_ec.kl`（仅保留功能键、不映射字母键 `Q`，使 `EventHub` 不把 `cros_ec` 虚报为外接 `ALPHAKEY` 硬键盘）；② 同时在 `overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml` 中配置 `<bool name="def_show_ime_with_hard_keyboard">true</bool>`（并在 `init.gru.rc` `on property:sys.boot_completed=1` 执行 `settings put secure show_ime_with_hard_keyboard 1` 以覆盖旧 `userdata`），即使未来真接上实体键盘也默认允许弹出软键盘。
    3. **「设置 -> 声音」与「设置 -> 无障碍（Accessibility）」闪退**：
       - **根因（见 `bootlog21.txt` 第 7572 行与第 7868 行）**：两处崩溃均由「系统尚未声明蓝牙支持（`android.hardware.bluetooth`），导致 `LocalBluetoothManager.getInstance()` 返回 `null`」引发：
         - 打开「设置 -> 声音」时：`LocalMediaManager` 构造函数（`LocalMediaManager.java:160`）发现 `mLocalBluetoothManager == null` 后打印 `Bluetooth is not supported on this device` 并提前 `return`，导致成员变量 `mInfoMediaManager` 保持 `null`；随后 `MediaOutputPreferenceController.onStart()` 调用 `LocalMediaManager.registerCallback()` 时触发 `mInfoMediaManager.registerCallback()` 空指针（NPE）。
         - 打开「设置 -> 无障碍」时：因未启用蓝牙助听器支持，`use(AccessibilityHearingAidPreferenceController.class)` 返回 `null`，`AccessibilitySettings.onAttach(AccessibilitySettings.java:196)` 直接调用 `.setFragmentManager()` 触发空指针（NPE）。
       - **与 `docs/phase-3.md` 蓝牙无法开机记录的核对与安全修复方案**：
         - 核对 [阶段 3](phase-3.md) 第 148～159 行记录可知：在阶段 3 中，`init.gru.rc` 曾执行 `pm disable com.android.bluetooth`，并将该禁用状态持久化写入了外置盘 `userdata`（`/data/system/users/0/package-restrictions.xml`）；而在我们未格式化的同一份 `userdata` 上，若此时在第 4 步贸然恢复 `/vendor/etc/permissions/android.hardware.bluetooth.xml` 权限声明，`SystemServer` 启动 `BluetoothService` 时就会立即重现阶段 3 第 157 行的致命异常 `No service can handle intent { act=android.bluetooth.IAdapter pkg=com.android.bluetooth }`，再次导致 `system_server` 崩溃无法开机！（且在未放入 `btusb.ko` 前恢复蓝牙 HAL 也会重现 `FD_SET: file descriptor -1` 反复 abort。）
         - **100% 零风险修复**：在第 4 步中**绝不提前开启** `android.hardware.bluetooth` 声明（保持 `TARGET_BLUETOOTH_HAL := none` 直至第 6 步蓝牙硬件模块就绪，且第 6 步开启前必须先在 `init.gru.rc` 执行 `pm enable com.android.bluetooth`），而是直接在 `SettingsLib`（`LocalMediaManager.java`）和 `Settings`（`AccessibilitySettings.java`、`AccessibilityHearingAidPreferenceController.java`、`HearingAidHelper.java`）中补齐对 `mInfoMediaManager` / `hearingAidPreferenceController` / `mLocalBluetoothManager` / `mBluetoothAdapter` 的空指针保护。这样既彻底消除了「设置 -> 声音」与「设置 -> 无障碍」的闪退，又从根源上保证 0% 概率触发阶段 3 的蓝牙死循环。
  - **日志中未在表面显现的隐性问题排查（`bootlog21.txt`）**：
    1. **`Elan Touchscreen` 的 IDC 文件名匹配（第 2187、6546 行）**：`6.6.34-phase2` 的 `elants_i2c` 驱动上报 `Vendor=0000 Product=0000`、`Name="Elan Touchscreen"`，因此 `EventHub` 未匹配按 VID/PID 命名的 `Vendor_04f3_Product_0b03.idc`（日志显示 `configuration=''`），而是靠内置启发式规则识别为 `TOUCH | TOUCH_MT`。在第 4 步中增加按设备名匹配的 `/vendor/usr/idc/Elan_Touchscreen.idc` 以确保显式加载 IDC。
    2. **横屏/倒置时 `drmhwc: Failed to create DrmKmsPlan`（第 7886、7920、7937 行）**：仅在屏幕处于 90°/180°/270° 旋转方向且有界面刷新时打印。这是因为 `rockchip` VOP 硬件图层仅暴露 `DRM_MODE_ROTATE_0`，`drm_hwcomposer` 尝试为旋转后的图层建立硬件 KMS plane 计划失败后，按设计安全回退给 `SurfaceFlinger`（Panfrost GPU）合成，属于正常回退日志，不影响稳定性或帧率。
    3. **`BpfLoader-rs: Failed to read fuse prog type`（第 1950 行）**：主线 `6.6.34` 内核不包含 Android common kernel 私有的 `CONFIG_FUSE_BPF` 补丁，因此 `fuse` 自动走标准内核 FUSE 通道，功能完全正常。

### 4. 背光曲线校正与第 3 步遗留 UI 修复（2026-10-19）

- **背光手动调节现状与指数曲线根因定位**：
  - `device/mainline/common` 自带的 `vendor.light-default`（`hardware/lineage/interfaces/light`）已默认运行并控制 `/sys/class/backlight/backlight/brightness`（`max_brightness = 4095`），下拉菜单亮度滑块手动调节本身已打通；Scarlet 机身无环境光传感器（ALS），自动亮度在硬件上不支持，直接跳过。
  - **为什么亮度滑块只有后一小段才明显变亮（双重非线性/指数叠加）**：
    1. 在内核设备树 `rk3399-gru-scarlet.dtsi` 中，`backlight`（`pwm-backlight`）未定义 `brightness-levels` 数组。内核驱动 `drivers/video/backlight/pwm_bl.c` 的 `pwm_backlight_brightness_default()` 因此自动按 **CIE 1931 三次方感知曲线**（`retval *= retval * retval`）生成了 4096 级查找表——也就是说，内核暴露的 `/sys/class/backlight/backlight/brightness`（`0..4095`）本身**已经是人眼感知线性的**（例如滑到 50% 即 `2048` 时，内核对应的物理 PWM 占空比约为 \(0.5^3 = 12.5\%\)）。
    2. 然而 Android 的 `BrightnessUtils`（`com.android.settingslib.display.BrightnessUtils` 与 `com.android.internal.display.BrightnessUtils`）假定底层背光值是物理线性的，默认在滑块上又叠加了一层 **Hybrid Log Gamma (HLG) 指数曲线**（`MathUtils.exp((normalizedVal - C) / A) + B`）：当滑块在 50% 时，Android 只向内核输出约 `8.3%`（`340 / 4095`），再经内核 CIE 三次方后物理占空比仅剩 **0.14%**（`6 / 4095`）；即使滑到 75%，物理占空比也仅有 **2.3%**，直到最后 25% 才陡然升亮。
  - **校正方案**：
    - `com.android.settingslib.display.BrightnessUtils` 原生预留了系统属性开关 `sys.brightness.disable_gamma_conversion`（当设为 `true` 时，`convertGammaToLinearFloat` 与 `convertLinearToGammaFloat` 直接使用线性插值 `MathUtils.lerp`）。
    - 同步在 `frameworks/base/core/java/com/android/internal/display/BrightnessUtils.java`（供 `system_server` `RampAnimator` 亮度过渡动画使用）中接入同一个 `sys.brightness.disable_gamma_conversion` 开关，并在 `device/google/gru/device.mk` 与 `init.gru.rc` 中设置 `sys.brightness.disable_gamma_conversion=true`，消除双重 Gamma 叠加，使下拉菜单亮度滑块直接线性映射到内核的 CIE 1931 感知曲线。
- **同轮一并执行的 3 项修复**：
  1. **虚拟导航栏（三键导航 / 手势导航）与设备 Overlay**：在 `device.mk` 启用 `DEVICE_PACKAGE_OVERLAYS := $(LOCAL_PATH)/overlay`，新增 `overlay/frameworks/base/core/res/res/values/config.xml`（开启 `config_showNavigationBar=true`，设 `config_voice_capable=false`、`config_sms_capable=false`）与 `overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml`（`def_auto_time_zone=false`、`def_accelerometer_rotation=true`、`def_show_ime_with_hard_keyboard=true`）。
  2. **屏幕虚拟键盘（IME）自动弹出与触摸屏 IDC 显式匹配**：新增 `device/google/gru/keylayout/cros_ec.kl`（拷入 `/vendor/usr/keylayout/cros_ec.kl`），仅映射 `VOLUME_DOWN`、`VOLUME_UP`、`POWER` 而不映射字母键，使 `EventHub` 将 `cros_ec` 识别为纯按键（不再带 `ALPHAKEY` 外接硬键盘标志），并配合 `init.gru.rc` 的 `settings put secure show_ime_with_hard_keyboard 1` 恢复点击输入框弹出软键盘；同时新增 `/vendor/usr/idc/Elan_Touchscreen.idc` 按设备名显式匹配触摸屏。
  3. **「设置 -> 声音」与「设置 -> 无障碍」空指针修复（不触碰蓝牙开关）**：在 `LocalMediaManager.java`、`AccessibilitySettings.java`、`AccessibilityHearingAidPreferenceController.java` 与 `HearingAidHelper.java` 中加入空指针判空，在不开启 `android.hardware.bluetooth` 的前提下彻底修复两处设置页崩溃。
- **构建产物**：
  - `out/target/product/gru/super.img` 大小 `1249522068` 字节，sha256 `0d9351346989a5326707f5fb777c5c34a04c1c01ebae156badbb682e6f5e5146`，已上传至 `10.0.0.133:/home/user/phase3/super.img` 并校验一致。
- **实机验证与日志对照分析（`/tmp/bootlog22.txt`，8130 行）**：
  - **启动耗时与调频复核**：`zram0` swap（`2919648 kB`）在 `76.15s` 启用，`surfaceflinger` 在 `76.20s` 启动，`sys.boot_completed=1` 在 `128.54s` 完成（`surfaceflinger` 至 `boot_completed` 耗时 `52.3s`）；`GRU_FREQ` 确认小核 `1.512 GHz`、大核 `2.016 GHz`、GPU `800 MHz`、内存控制器 `928 MHz` 全程生效；内置盘 eMMC `mmcblk1p1` 校验和保持 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。
  - **本轮验证通过的 4 项功能**：
    1. **背光滑块线性化校正（`sys.brightness.disable_gamma_conversion=true`）**：消除 Android HLG 曲线与内核 `pwm-backlight` CIE 1931 三次方曲线的双重非线性叠加，下拉菜单亮度滑块全程均匀线性调节。
    2. **虚拟导航栏（`config_showNavigationBar=true`）**：三键导航与手势导航均正常显示与切换。
    3. **屏幕虚拟键盘（IME）自动弹出（`cros_ec.kl` + `show_ime_with_hard_keyboard=1`）**：`EventHub`（`bootlog22.txt` 第 6129 行）显式加载 `/vendor/usr/keylayout/cros_ec.kl`，将 `cros_ec` 识别为纯 `classes=KEYBOARD`（不再携带 `ALPHAKEY` 外接硬键盘标志），同时 `Elan Touchscreen`（第 6135 行）显式加载 `/vendor/usr/idc/Elan_Touchscreen.idc`；点击输入框时屏幕软键盘正常弹出。
    4. **「设置 -> 隐私（Privacy）」与「设置 -> 无障碍（Accessibility）」不再闪退**：此前闪退的两个页面现均正常打开，`bootlog22.txt` 中 `AccessibilitySettings` 崩溃次数为 0。
  - **尚存预期内现象（待第 6/7 步蓝牙与音频启用后自然消解）**：
    - 「设置 -> 已连接的设备（Connected devices）」与「设置 -> 声音（Sound）」在蓝牙模块（第 6 步）与音频（第 7 步）尚未启用前仍会因 `BluetoothAdapter.getDefaultAdapter() == null`（`BluetoothUtils.isAudioSharingSupported:736`）及 `mInfoMediaManager == null`（`LocalMediaManager.getRemoteRoutingSessions:548`）触发空指针退出，待第 6 步启用蓝牙后复核。
  - **日志中未在表面显现的隐性问题排查（`bootlog22.txt`，直接关系第 5 步 Wi-Fi）**：
    1. **VINTF 缺少 `android.hardware.wifi.IWifi/default`（第 6592 行）**：`bootlog22.txt` 记录 `servicemanager: Caller(pid=3414,uid=1000,sid=u:r:system_server:s0) Could not find android.hardware.wifi.IWifi/default in the VINTF manifest`，而仅找到了 `ISupplicant/default`。原因是 `device/mainline/common` 默认只打包了 `com.android.hardware.wpa_supplicant` APEX，**没有包含 `android.hardware.wifi-service`（AIDL Vendor Wi-Fi HAL）**，且 APEX 版的 `wpa_supplicant` 只从 `/apex/com.android.hardware.wpa_supplicant/etc/wifi/` 读取配置而忽略 `/vendor/etc/wifi/wpa_supplicant_overlay.conf`。若不参照 Trogdor 切换为 `legacy` 形态并补齐 `android.hardware.wifi-service`、`BOARD_WLAN_DEVICE := qcwcn` 与 `libcld80211`，即使内核加载了 `ath10k_pci.ko` 生成 `wlan0`，Android 框架也无法打开 Wi-Fi 开关。
    2. **恢复 `adbd` 时必须隔离 `/dev/usb-ffs/adb`（避免无 UDC 空转刷屏）**：Scarlet 的两路 Type-C 控制器在 `rk3399-gru.dtsi` / `rk3399-gru-chromebook.dtsi` 中均硬编码为 `dr_mode = "host"`，内核中无 UDC。`adbd`（`packages/modules/adb/daemon/main.cpp:259`）只要检测到 `/dev/usb-ffs/adb/ep0` 存在就会启动 `usb_init()` 线程死循环写入 functionfs 描述符（每秒刷屏 `read descriptors` / `bcdVersion`）。`init.mainline.usb.rc` 会在 `on early-boot` 无条件挂载 `/dev/usb-ffs/adb`；因此在第 5 步恢复 `adbd` 监听 TCP `5555` 端口的同时，必须设 `TARGET_USB_INIT_SCRIPT := none` 阻止挂载 `/dev/usb-ffs/adb`，使 `adbd` 纯净运行在 TCP/IP 模式。

### 5. Wi-Fi（QCA6174 `ath10k_pci`）与无线 `adb`（2026-10-19，已完成并验证）

- **固件与内核模块清单**：
  - 从机身 postmarketOS `/lib/firmware/ath10k/QCA6174/hw3.0/` 提取并解压 4 个固件文件放入 `device/google/gru/firmware/ath10k/QCA6174/hw3.0/`（安装至 `/vendor/firmware/ath10k/QCA6174/hw3.0/`）：`board-2.bin`（723 KB）、`board.bin`（8 KB）、`firmware-6.bin`（690 KB，`WLAN.RM.4.4.1-00309` API 6）、`firmware-4.bin`（717 KB）；配合 `wireless-regdb` 已安装的 `/vendor/firmware/regulatory.db` 与 `regulatory.db.p7s`。
  - 从 `6.6.34-phase2` `modinstall` 提取 `ath10k` 依赖链及 WPA2/WPA3（CCMP/AES-CMAC）硬件加密模块共 13 个 `.ko` 放入 `/vendor/lib/`：
    - 无线协议栈与驱动：`rfkill.ko`、`libarc4.ko`、`cfg80211.ko`、`mac80211.ko`、`ath.ko`、`ath10k_core.ko`、`ath10k_pci.ko`。
    - 802.11i / WPA2 / WPA3 加密模块（内核配置为 `=m`）：`arc4.ko`、`ccm.ko`、`cmac.ko`、`aes-ce-cipher.ko`、`aes-ce-ccm.ko`、`aes-ce-blk.ko`。
  - 在 `init.gru.rc` 的 `on early-init` 最开头执行 `write /sys/module/firmware_class/parameters/path /vendor/firmware`（确保在 `insmod ath10k_pci.ko` 触发 PCIe `0000:01:00.0` 异步请求固件前固件路径已生效），随后按依赖拓扑顺序加载上述模块。
- **Wi-Fi HAL 与 `wpa_supplicant`（参照 `third_party/android_device_google_trogdor-lineage-24`）**：
  - 在 `BoardConfig.mk` 与 `device.mk` 中设 `TARGET_HOSTAPD_AND_WPA_SUPPLICANT_FORM := legacy`、`BOARD_WLAN_DEVICE := qcwcn`、`WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := false`，加入 `hardware/qcom/wlan` 与 `hardware/qcom/wlan/legacy` Soong 命名空间。
  - 打包 `android.hardware.wifi-service`（提供 `android.hardware.wifi.IWifi/default` VINTF AIDL 服务，静态链接 `libwifi-hal-qcom`）、`libcld80211`、`wpa_supplicant`、`wpa_supplicant.conf`、`hostapd`、`wificond`、`libwpa_client`。
  - 拷入 `wpa_supplicant_overlay.conf`（`disable_scan_offload=1`、`p2p_disabled=1`、`tdls_external_control=1`）与 `p2p_supplicant_overlay.conf` 至 `/vendor/etc/wifi/`，以及 `android.hardware.wifi.xml`、`android.hardware.wifi.direct.xml`、`android.hardware.wifi.passpoint.xml` 权限声明；配置 `wifi.interface=wlan0`。
  - 在 `init.gru.rc` 中添加 `on zygote-start` 创建 `/data/vendor/wifi/wpa/sockets` 与 `/data/vendor/wifi/hostapd/sockets`（`0770 wifi wifi`），并定义 `wpa_supplicant` 服务（`-O/data/vendor/wifi/wpa/sockets -Dnl80211 -g@android:wpa_wlan0`）。
- **无线 `adb`（TCP/IP 端口 `5555`）与 Type-C 角色核对**：
  - 核对 `rk3399-gru.dtsi` 与 `rk3399-gru-chromebook.dtsi`：两路 `usbdrd_dwc3_0` / `usbdrd_dwc3_1` 在设备树中均为 `dr_mode = "host"`，无 peripheral/otg UDC。
  - 设置 `TARGET_USB_INIT_SCRIPT := none` 排除 `init.mainline.usb.rc`（不挂载 `/dev/usb-ffs/adb`，避免 `adbd` 启动 USB functionfs 线程触发内核每秒刷屏），移除 `init.gru.rc` 中旧的 `on property:init.svc.adbd=running stop adbd`，改为设置 `service.adb.tcp.port=5555` 并在 `on boot && property:service.adb.tcp.port=5555` 启动 `adbd`，连上局域网后可直接 `adb connect <平板IP>:5555`。
- **构建产物**：
  - `out/target/product/gru/super.img` 大小 `1251934612` 字节，sha256 `00a872f695f2ee091496a310e8294d95ad4e82b7389fa3ec51dc2f476e1ea6fb`，已上传至 `10.0.0.133:/home/user/phase3/super.img` 并校验一致。
- **实机无线 `adb` 直连验证与日志排查（`/tmp/adb_dmesg_step5.txt` 2022 行、`/tmp/adb_logcat_step5.txt` 23575 行）**：
  - **无线 `adb` 双通道直连成功**：平板在 LineageOS 23.2 下同时支持 Android 16 原生 TLS 无线调试配对连接（`10.0.0.119:43583`，`TlsServer: Handshake succeeded` -> `adbd_wifi_secure_connect: connected`）与 `init.gru.rc` 预设的 TCP `5555` 端口 root 连接（`10.0.0.119:5555`），从此可直接在运行中的 Android 系统内抓取完整 `dmesg`、`logcat` 与 `dumpsys`，无需切回 postmarketOS 导出日志。由于 `TARGET_USB_INIT_SCRIPT := none` 阻止挂载 `/dev/usb-ffs/adb`，`dmesg` 中 USB `functionfs` / `bcdVersion` 报错为 **0 条**。
  - **QCA6174 `ath10k_pci` 固件、驱动与硬件加密验证**：
    - `early-init` 阶段 `ath10k_pci 0000:01:00.0` 一次成功加载 `/vendor/firmware/ath10k/QCA6174/hw3.0/` 下的 `firmware-6.bin`（`WLAN.RM.4.4.1-00309- api 6 features wowlan,ignore-otp,mfp crc32 0793bcf2`）与 `board-2.bin`（`board_file api 2 bmi_id N/A crc32 d2863f91`），启用 `hwcrypto 1`（`htt-ver 3.87 wmi-op 4 htt-op 3`）。
    - `lsmod` 确认 `aes_ce_ccm`（`Used by 2`）与 `aes_ce_cipher`（`Used by 2`）被 `mac80211` 实际绑定并承载 ARMv8 硬件加速 WPA2-CCMP 加解密。
  - **Wi-Fi AIDL HAL、`wpa_supplicant` 与 802.11ac 5 GHz 链路验证**：
    - `servicemanager` 成功解析 `android.hardware.wifi.IWifi/default` 与 `android.hardware.wifi.supplicant.ISupplicant/default`；`WifiVendorHal`（`Vendor Hal started successfully`）与 `WifiNative`（`Successfully setup Iface:{Name=wlan0,Id=0,Type=STA_CONNECTIVITY}`）顺利拉起 `wlan0`。
    - `cmd wifi status` 确认已关联 5 GHz 802.11ac AP（`SSID: "Not 6GHz"`, `Frequency: 5765MHz`, `RSSI: -22 dBm`, `Tx/Max Link speed: 866Mbps`, `retriedTxPackets: 0`, `lostTxPackets: 0`），同时拿到 IPv4（`10.0.0.119/24`）与 IPv6 地址，网络能力通过 `INTERNET & VALIDATED` 校验。
  - **内置盘安全核对**：在 Android root shell 下直接执行 `sha256sum /dev/block/mmcblk1p1`，返回值仍为 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`，eMMC 分毫未动。
  - **日志中发现并顺手修掉的 2 处隐性问题**：
    1. **`android.hardware.sensors-service.multihal` 启动瞬间纯虚函数竞态（`Pure virtual function called!`）**：`adb_logcat_step5.txt` 第 2296–2328 行记录 `vendor.sensors-hal-multihal`（`pid 3048`）在开机早期 `19:01:17.425` 触发了一次 `SIGABRT`（`Abort message: 'Pure virtual function called!'`），随后在 `19:01:20.853` 被 `init` 自动拉起（`pid 3416`）并正常工作（因此用户侧无感知，`dumpsys sensorservice` 中陀螺仪和加速度计均正常输出事件）。定位 `device/google/gru/hal/sensors/Sensor.cpp` 发现基类构造函数 `SensorBase::SensorBase()` 在第 65 行直接调用了 `mSensorThread.start()`，此时派生类 `HWSensorBase::HWSensorBase()` 尚未执行完毕、对象 `vptr` 仍指向 `SensorBase`（其中 `pollSensor()` 为纯虚函数 `__cxa_pure_virtual`），一旦新线程在派生类构造完成前被调度就会触发纯虚函数调用。已将 `mSensorThread.start()` 移至派生类构造函数 `HWSensorBase::HWSensorBase()` 末尾（完成 `mPollFdIio.fd` 打开与 `mSensorRawData.resize()` 之后），彻底消除该竞态。
    2. **`gru-logcat.sh` 将 `HalDevMgr:I` 与 `WifiHAL:I` 镜像至 `/dev/kmsg` 导致 `dmesg` 周期性刷屏**：主线 `ath10k` 驱动仅声明单 `STA` 接口且不支持高通私有 logger nl80211 命令；Android 框架每 3 秒扫描检查是否可创建第二 `STA` 接口时，`HalDevMgr` 会打印 `I HalDevMgr: bestIfaceCreationProposal is null, requestIface=STA, existingIface=[name=wlan0 type=STA]`，`WifiHAL` 打印 `E WifiHAL : wifi_get_logger_supported_feature_set: Error -3 happened`。这两条日志本身不影响 Wi-Fi 功能，但 `gru-logcat.sh` 将它们实时写入 `/dev/kmsg` 会冲刷内核 `dmesg` 缓冲区。已在 `gru-logcat.sh` 中将过滤级别调整为 `HalDevMgr:W WifiHAL:S`。

### 6. 蓝牙（QCA6174A USB `0cf3:e300` `btusb` 与 AIDL Bluetooth HAL）（2026-10-20）

- **固件与内核模块清单**：
  - 通过无线 `adb` 在运行中的 Android 平板上直接探测 USB 总线确认内置蓝牙控制器为 `1-1: 0cf3:e300`（QCA6174A Rome 3.2 USB），并从只读挂载的内置盘 `/lib/firmware/qca/` 提取并解压 QCA Rome USB 蓝牙固件放入 `device/google/gru/firmware/qca/`（安装至 `/vendor/firmware/qca/`）：`rampatch_usb_00000302.bin`（68 KB，`rome 0x302 build 0x3e8`）、`nvm_usb_00000302.bin`（2 KB）、`nvm_usb_00000302_eu.bin` 及同系列 `00000200` / `00000201` / `00000300` 固件。
  - 从 `6.6.34-phase2` `modinstall` 提取蓝牙协议栈、控制器驱动及 BLE/HID 依赖模块共 13 个 `.ko` 放入 `/vendor/lib/`：`ecc.ko`、`ecdh_generic.ko`、`uhid.ko`、`bluetooth.ko`、`rfcomm.ko`、`bnep.ko`、`hidp.ko`、`btbcm.ko`、`btintel.ko`、`btrtl.ko`、`btmtk.ko`、`btqca.ko`、`btusb.ko`。
  - 在实机上通过无线 `adb` 预演加载模块：`btusb` 一次成功匹配 `0cf3:e300` 并加载 `qca/rampatch_usb_00000302.bin` 与 `qca/nvm_usb_00000302.bin`，生成 `/sys/class/bluetooth/hci0`（硬件自带 OTP 公网 MAC `30:D1:6B:79:6B:36`，与 `wlan0` 的 `30:D1:6B:79:6B:35` 相邻）与 `rfkill1`（`type=bluetooth state=1`）。
- **AIDL Bluetooth HAL、设备节点权限与 `com.android.bluetooth` 恢复**：
  - 对照 `third_party/android_device_google_trogdor-lineage-24` 与 `device/mainline/common`：在 `device.mk` 中将 `TARGET_BLUETOOTH_HAL` 从 `none` 切换为 `default-aidl`，打包 `android.hardware.bluetooth-service.default`（提供 `android.hardware.bluetooth.IBluetoothHci/default` VINTF AIDL 服务，通过 `NetBluetoothMgmt` 管理 `rfkill` 与 `HCI_CHANNEL_USER` 套接字）、`bdaddr`（含 `set_bdaddr.sh`），并安装 `android.hardware.bluetooth.xml` 与 `android.hardware.bluetooth_le.xml` 权限声明。
  - **修复 `/dev/rfkill` 与 `/dev/uhid` 权限隐患**：`vendor.bluetooth-default` 以 `uid=bluetooth (1002)` 运行并在 `openHci()` 中打开 `/dev/rfkill` 解除蓝牙软屏蔽，而内核 `rfkill.ko` 作为模块在 `early-init` 加载时 `/dev/rfkill` 默认是 `0600 root:root`；同时蓝牙键鼠/手柄 HID 协议栈需要读写 `/dev/uhid`（`uhid.ko`）。已在 `ueventd.gru.rc` 与 `init.gru.rc` 的 `on post-fs` 中双保险设置 `/dev/rfkill` 为 `0660 bluetooth:bluetooth`、`/dev/uhid` 为 `0660 uhid:uhid`。
  - 在 `init.gru.rc` 中移除阶段 3 为无控制器状态临时添加的 `on property:init.svc.vendor.bluetooth-default=running stop vendor.bluetooth-default`，并在 `on property:sys.boot_completed=1` 中执行 `pm enable com.android.bluetooth`，自动解除保留 `userdata` 分区上此前持久化的 `com.android.bluetooth` 禁用状态。
- **构建产物**：
  - `out/target/product/gru/super.img` 大小 `1253228948` 字节，sha256 `439a268e8ddba98942b7b9414b233df2f18491bee382a300642738907a6e7a85`。

## 事件

| 日期 | 事件 |
| --- | --- |
| 2026-10-19 | 阶段 4 第 1 项验证通过：写入 `super.img`（`5905b1e2...`）后启动外置盘，`zram0` 2919648 kB swap 启用，`Launcher3` 与 `Seedvault` 崩溃以及设置应用 ANR 全部归零。内置盘 eMMC `pmOS_kernel` 校验和保持 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。 |
| 2026-10-19 | 阶段 4 第 2 项验证通过：写入 `super.img`（`345ebd9a...`）后启动外置盘，`panfrost` 驱动与 Mesa 25.3.3 `Mali-T860 (Panfrost)` OpenGL ES 3.1 硬件加速正常启用，无软渲染回退，`SurfaceFlinger` 至开机完成耗时从 145.7 秒缩短至 64.4 秒，0 次崩溃/ANR。 |
| 2026-10-19 | 补齐 CPU/内存调频模块（`cpufreq-dt.ko`、`rockchip_thermal.ko`、`rockchip-dfi.ko`、`rk3399_dmc.ko`）并写入 `super.img`（`04155eb4...`）验证通过：`GRU_FREQ` 确认小核 `1.512 GHz`、大核 `2.016 GHz`、GPU `800 MHz`、内存控制器 `928 MHz` 全部上线，总开机时间从 156.9 秒进一步缩短至 125.2 秒，响应速度明显提升，确认 2048×1536 线性合成下 30–45 fps 为 Mali-T860 MP4 硬件带宽边界。 |
| 2026-10-19 | 完成阶段 4 第 3 项（触摸、旋转、Wacom 手写笔）及 `fuse.ko` 构建并上传至 `/home/user/phase3/super.img`：新 `super.img` 校验和 `1e240695d3c4ef4e60755942ae2d0d75095c6a8d4236b4d286caa87662656ab4`（`1249505684` 字节），包含 `fuse.ko`、`i2c-hid` 手写笔模块、`cros_ec_sensors` IIO 传感器模块、`android.hardware.sensors@2.1-gru-subhal` 与触摸/手写笔 IDC 配置。 |
| 2026-10-19 | 阶段 4 第 3 项实机验证通过（`bootlog21.txt`）：Wacom 手写笔四个方向点击与悬停全部正常、自动旋转四个方向流畅且帧率一致、「设置 -> 存储」正常打开；同时定位了缺少虚拟导航栏、软键盘不弹出、「设置 -> 声音 / 无障碍」因缺蓝牙声明触发 NPE 等问题，排入第 4 步（背光调节）一并修复。 |
| 2026-10-19 | 完成阶段 4 第 4 项（背光滑块线性化校正、虚拟导航栏 Overlay、软键盘 `cros_ec.kl` 修复、「设置 -> 声音 / 无障碍」NPE 修复）构建并上传至 `/home/user/phase3/super.img`：新 `super.img` 校验和 `0d9351346989a5326707f5fb777c5c34a04c1c01ebae156badbb682e6f5e5146`（`1249522068` 字节）。 |
| 2026-10-19 | 阶段 4 第 4 项实机验证通过（`bootlog22.txt`）：下拉菜单亮度滑块全程线性调节、三键与手势虚拟导航栏正常、屏幕虚拟键盘正常弹出、「设置 -> 隐私」与「设置 -> 无障碍」不再闪退；同时从日志发现 VINTF 缺少 `IWifi/default` 及 `adbd` 需隔离 `/dev/usb-ffs/adb`，并完成阶段 4 第 5 项（QCA6174 `ath10k_pci` 固件与 13 个无线/加密模块、`android.hardware.wifi-service`、nl80211 `wpa_supplicant`、TCP `5555` 无线 `adb`）构建与上传（新 `super.img` 校验和 `00a872f695f2ee091496a310e8294d95ad4e82b7389fa3ec51dc2f476e1ea6fb`，`1251934612` 字节）。 |
| 2026-10-19 | 阶段 4 第 5 项实机验证通过（通过无线 `adb` 直接拉取 `adb_dmesg_step5.txt` 与 `adb_logcat_step5.txt`）：QCA6174 `ath10k_pci` 802.11ac 5 GHz 联网满速（866 Mbps，0 丢包，IPv4/IPv6 双栈 `INTERNET & VALIDATED`），无线 `adb`（TLS 端口与 TCP `5555` root 端口）直连稳定且无 USB functionfs 报错；同时从日志排查并修复了 `SensorBase` 构造函数过早启动线程导致的开机单次纯虚函数崩溃竞态与 `gru-logcat.sh` 中 `HalDevMgr` 刷屏 `dmesg` 的问题。 |
| 2026-10-20 | 完成阶段 4 第 6 项（蓝牙：QCA6174A USB `0cf3:e300` `qca/rampatch_usb_00000302.bin` 与 `nvm_usb_00000302.bin` 固件、`btusb.ko` 等 13 个蓝牙/加密/UHID 模块、`android.hardware.bluetooth-service.default` AIDL HAL、`/dev/rfkill` 与 `/dev/uhid` 权限及 `pm enable com.android.bluetooth`）构建：新 `super.img` 校验和 `439a268e8ddba98942b7b9414b233df2f18491bee382a300642738907a6e7a85`（`1253228948` 字节）。 |
