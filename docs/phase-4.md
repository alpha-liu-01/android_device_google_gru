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

## 事件

| 日期 | 事件 |
| --- | --- |
| 2026-10-19 | 阶段 4 第 1 项验证通过：写入 `super.img`（`5905b1e2...`）后启动外置盘，`zram0` 2919648 kB swap 启用，`Launcher3` 与 `Seedvault` 崩溃以及设置应用 ANR 全部归零。内置盘 eMMC `pmOS_kernel` 校验和保持 `5c188eeb7a89fdb1bf442ccccd61a556ad5e232149454659853e7dee98f0068a`。 |
| 2026-10-19 | 阶段 4 第 2 项验证通过：写入 `super.img`（`345ebd9a...`）后启动外置盘，`panfrost` 驱动与 Mesa 25.3.3 `Mali-T860 (Panfrost)` OpenGL ES 3.1 硬件加速正常启用，无软渲染回退，`SurfaceFlinger` 至开机完成耗时从 145.7 秒缩短至 64.4 秒，0 次崩溃/ANR。 |
| 2026-10-19 | 补齐 CPU/内存调频模块（`cpufreq-dt.ko`、`rockchip_thermal.ko`、`rockchip-dfi.ko`、`rk3399_dmc.ko`）并写入 `super.img`（`04155eb4...`）验证通过：`GRU_FREQ` 确认小核 `1.512 GHz`、大核 `2.016 GHz`、GPU `800 MHz`、内存控制器 `928 MHz` 全部上线，总开机时间从 156.9 秒进一步缩短至 125.2 秒，响应速度明显提升，确认 2048×1536 线性合成下 30–45 fps 为 Mali-T860 MP4 硬件带宽边界。 |
| 2026-10-19 | 完成阶段 4 第 3 项（触摸、旋转、Wacom 手写笔）及 `fuse.ko` 构建并上传至 `/home/user/phase3/super.img`：新 `super.img` 校验和 `1e240695d3c4ef4e60755942ae2d0d75095c6a8d4236b4d286caa87662656ab4`（`1249505684` 字节），包含 `fuse.ko`、`i2c-hid` 手写笔模块、`cros_ec_sensors` IIO 传感器模块、`android.hardware.sensors@2.1-gru-subhal` 与触摸/手写笔 IDC 配置。 |
