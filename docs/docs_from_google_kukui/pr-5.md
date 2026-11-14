# Pull request 5

2026-11-13 对照本地 `ef09a94` 看过 [alpha-liu-01/android_device_google_kukui#5](https://github.com/alpha-liu-01/android_device_google_kukui/pull/5)。作者 krecks，分支 `krane-bringup-fixes`，从 `a0f8aab` 拉出，中间用 `8ceb40f` 合并了 `ef09a94`。29 个提交。他在 Krane sku0 上从 U 盘和 eMMC 启动过，内核从 6.18.28 换到 6.18.62，再换到 6.18.63。这份文档只记录判断，没有合并，也没有拿他的镜像启动。

整份 pull request 一次合进来会换掉内核版本、菜单里的版本字符串、Android FIT 的命令行，以及一批 6.18.63 的 `.ko`。按下面每一笔挑。预编译模块用自己的内核重编，不收仓库里的二进制。

`patches/system_cros_codecs_mdp3.patch`、`patches/external_drm_hwcomposer_mdp3_rotation.patch`、`patches/frameworks_base_hwui_gl_prerotation.patch`、`patches/frameworks_base_lid_wake.patch` 在当前 Lineage 23.2 树上正向试打通过。前一份 MDP3 补丁叠在已经打上的 `system_cros_codecs.patch` 上面。

每一节的「事件」留给以后填写。

## 索引

| 提交 | 结论 |
|---|---|
| `b9175a8` | 应该合并 |
| `12eb743` | 应该合并 |
| `386f27b` | 功能要留，这份补丁先不合并 |
| `7465cfb` | 应该合并 |
| `249ab61` | 应该合并 |
| `6526f4b` | 应该合并 |
| `73c4903` | 应该合并，和后面三笔内核补丁一起 |
| `2f60951` | 应该合并，和 SVS 一组 |
| `ac44fef` | 功能要，脚本重做后再合并 |
| `b7ed7de` | 应该合并，和 SVS 一组 |
| `b94297e` | 应该合并，和 SVS 一组 |
| `736d92a` | 随功能一起改写后合并 |
| `d9cbef0` | 应该合并 |
| `b53e50e` | 先不单独合并 |
| `2815d72` | 模块名单要，二进制不要 |
| `5e0cc3f` | 应该合并，排在 MDP3 模块之后 |
| `c91f3e0` | 应该合并，排在 MDP3 模块之后 |
| `be4af95` | 不合并 |
| `8b99860` | 先不合并 |
| `8ceb40f` | 不合并 |
| `3b51904` | 补丁和配置应该合并，二进制不要 |
| `a9706cd` | 拆开合并 |
| `bcc64e1` | 拆开合并 |
| `7f6d160` | 应该合并，二进制不要 |
| `7814fe5` | 内核版本先不合并，模块名单要 |
| `5067807` | 功能要，和安装器上一笔一起重做 |
| `fc5ee05` | 拆开合并 |
| `fccfd18` | 不作为我们的构建说明合并 |
| `174c947` | 应该合并 |

## b9175a8 Add the pm_set_mem_sleep() helper the USB suspend patch calls

内容：新增 `bringup/kernel/pm-set-mem-sleep.patch`。`mt8183-usb-suspend-power.patch` 调用 `pm_set_mem_sleep()`，主线和 postmarketOS 的 mt81 补丁里都没有这个函数，干净的内核编不过 `mtu3_plat.c`。补丁在 `kernel/power/suspend.c` 里按写 `/sys/power/mem_sleep` 的方式设置 `mem_sleep_current`。要排在 USB 睡眠补丁前面。

可行性：仓库里的 USB 睡眠补丁已经在调用这个符号。从源码重编内核时缺这一笔就会停。补丁本身只提供助手，不改默认睡眠模式。

是否应该合并：应该合并。

合并需要的修改：把应用顺序写进内核构建说明。对照现在能启动的那棵内核，确认这个函数和现有行为一致。

事件：

2026-11-13 正在运行的 `6.18.28-mt81-kukui2` 的 kallsyms 里已有 `pm_set_mem_sleep`。`/sys/power/mem_sleep` 读到 `s2idle [deep]`。源码里的实现用 `lock_system_sleep()` 写 `mem_sleep_current`，和 krecks 补丁里的 `WRITE_ONCE` 不是同一份。入库的是和这棵已启动源码一致的补丁。干净的 6.18.28 正向试打通过，已打过的树上反向试打通过。`docs/build.md` 写了它必须排在 USB 睡眠补丁前面。没有重编内核，没有重启。

## 12eb743 Ship APEXes uncompressed

内容：`device.mk` 设置 `PRODUCT_COMPRESSED_APEX := false`。压缩的 APEX 第一次启动会在 `/data/apex/decompressed` 解开。他从 USB 2.0 U 盘启动时，这一步大约两分钟。25 个 APEX 从 131 MiB 涨到 174 MiB。

可行性：增加的体积落在 8 GiB 的 super 里，他量过能放下。只影响 Kukui 的 product。第一次启动变快，super 变大约 42 MiB。

是否应该合并：应该合并。

合并需要的修改：编出来的 super 展开后仍要正好 8589934592 字节。看动态分区组还有没有被撑满。

事件：

2026-11-13 `device.mk` 加了 `PRODUCT_COMPRESSED_APEX := false`。`com.android.tethering.apex` 里的 `apex_payload.img` 是 Stored。system 分区从 586403840 字节增到 627113984 字节。六个逻辑分区合计 1355194368 字节，动态分区组 8585740288 字节，占用 15.8%。super 展开后 8589934592 字节，sha256 `f85a31c85c75298f35a738081a565c62a8faeee03ddee8cf8fbafd4a02a49a3f`。三份 FIT 与 `20261108f` 相同。zip 是 `work/release/lineage-23.2-kukui-20261113.zip`，1112350386 字节，sha256 `476cea2465d4fa193623a155355a8a2f5c20df37c546dcc8db94598de9a2c624`。用户从 U 盘启动，`ro.boot.boot_devices` 是 `soc/11201000.usb/11200000.usb`，`ro.build.date` 是 Fri Nov 13 14:28:27 EST 2026，`sys.boot_completed` 是 1，开机动画已停，zygote 在跑。`/data/apex/decompressed` 是空的，`/apex` 下有 89 个已激活的 APEX。

## 386f27b Add the DRM SET_MASTER takeover patch the display needs

内容：新增 `bringup/kernel/drm-setmaster-takeover.patch`。`DRM_IOCTL_SET_MASTER` 不再检查 `CAP_SYS_ADMIN`，已经有 master 时直接接手，而不是返回 `-EBUSY`。他写明这是按 `docs/phase-3.md` 重写的，不是原来的那份代码。没有它时，minigbm 先打开 `/dev/dri/card0`，drm_hwcomposer 拿不到 master，屏幕不亮。

可行性：这个行为是出画需要的，当前能用的内核里已经有一份本地修改。他的补丁把权限检查整段拿掉，和本地那份是否逐行一致还没有对过。用错版本有可能把已经能出画的路径换掉。

是否应该合并：功能要留在内核里。这份重写的补丁先不合并。

合并需要的修改：用现在能出画的 `drm_auth.c` 重新导出补丁再入库。菜单 FIT 继续用已经能画出选项的那颗内核，不因为这一笔换成新 Image。

事件：

2026-11-13 补丁已按正在运行的 `drm_auth.c` 写出，没有采用 krecks 那份重写。干净的 6.18.28 正向试打通过，已打过的树上反向试打通过。U 盘上的系统 SurfaceFlinger 有 HWC display 0。用户确认画面正常。这一笔不换内核，也不需要新的刷机包。

## 7465cfb Enable the system DMA-BUF heap in the camera config fragment

内容：`bringup/camera/config.fragment` 打开 `CONFIG_DMABUF_HEAPS_SYSTEM=y`。`docs/camera.md` 和 `ueventd.kukui.rc` 都依赖 `/dev/dma_heap/system`，已提交的 fragment 没有打开它。缺了以后相机采集返回 -38，Codec2 软解返回 `NO_MEMORY`。

可行性：一行配置。按文档从零编内核时确实会漏。正在运行的系统已经有这个节点，说明当前内核是打开的，仓库 fragment 落后于实际内核。

是否应该合并：应该合并。

合并需要的修改：重编内核之后确认节点仍在。这一笔不单独更换菜单内核。

事件：

2026-11-13 正在运行的 `6.18.28-mt81-kukui2`（11 月 8 日 08:47）kallsyms 里有 `system_heap_allocate`，`/dev/dma_heap/system` 是 `system:system` 0666。`/proc/config.gz` 写着 `CONFIG_DMABUF_HEAPS_SYSTEM` 未设置，内核树里的 `.config` 则是 `=y`。片段原先没写这一行，从零编内核时会丢掉它。已补进 `bringup/camera/config.fragment`。没有重编内核，菜单内核不动。

## 249ab61 Add the EC ambient light sensor and adaptive brightness

内容：传感器 HAL 原来只有加速度和陀螺。新增 `LightSensor`，因为 `cros-ec-light` 没有 IIO buffer，只有 `in_illuminance_input`，不能走 `HWSensorBase`。它以 5 Hz 读 lux，上报成 on-change 的 LIGHT。overlay 打开自动亮度，并给了一条 lux 到背光的曲线。`device.mk` 声明 `android.hardware.sensor.light`。他在 Krane sku0 上看到约 21 lux 对应背光 224/1023。

可行性：HAL 和 overlay 都在 Kukui 设备树里。EC 光线传感器在 sku0 上存在。sku176 和 Kodama 没有在这笔记里测过。这一笔不带 `.ko`，节点要靠内核模块，模块在后面的预编译包里。

是否应该合并：应该合并。

合并需要的修改：模块用自己的内核编，不拿 6.18.63 的 `cros_ec_light_prox.ko`。sku176 和 Kodama 各确认一次是否有这个 sysfs。亮度曲线是按 sku0 的房间灯光写的，另外两块面板分开看。

事件：

2026-11-13 当前 U 盘系统已有 `cros-ec-light`，`in_illuminance_input` 读到 260 lux，`cros_ec_light_prox.ko` 已在 vendor 里。HAL、overlay 和 `android.hardware.sensor.light` 已放进树，新文件补了 Soong 符号链接。`android.hardware.sensors@2.1-kukui-subhal.so` 含 `cros-ec-light`。super 展开后 8589934592 字节，sha256 `f550f18cab5e6e4c3d546648ef46dd54a0ae4fbd3b6bf51a14d823e465833711`。三份 FIT 与 `20261108f` 相同。zip 是 `work/release/lineage-23.2-kukui-20261113b.zip`，1112360370 字节，sha256 `bc5a88684ebaafc8a573184cbd10ffd00c97ee2b1de7f5b2da0070b71ad9fae9`。2026-11-13 15:40 整盘写入读卡器序列号 `000000002959` 的 `/dev/sda`（119.1G USB，分区仍是 pmOS_boot / 8G super / metadata / userdata）。写入 11756634112 字节，读回 sha256 `1d67ae5cd125babad783d79843de5e6a32e4fbba5c410365a626d9df376dee8e`，super 读回 `f550f18cab5e6e4c3d546648ef46dd54a0ae4fbd3b6bf51a14d823e465833711`。没有写 eMMC。用户从 U 盘启动，`ro.build.date` 是 Fri Nov 13 15:25:39 EST 2026，`ro.boot.boot_devices` 是 `soc/11201000.usb/11200000.usb`，`sys.boot_completed` 是 1。`cros-ec-light` 在 sensorservice 里是 `android.sensor.light`，`AutomaticBrightnessController` 以 250 ms 订阅，事件在 0 到 51 lux 之间变化。`screen_brightness_mode` 是 1，overlay 曲线已进显示配置，策略是 `AutomaticBrightnessStrategy`。用户确认自动亮度看起来正常。

## 6526f4b Pre-rotate HWUI's GL rendering so planes can scan out app layers

内容：新增 `patches/frameworks_base_hwui_gl_prerotation.patch`，`apply-patches.sh` 会打上。面板是竖屏扫描，界面是 `ORIENTATION_270`。MT8183 的 OVL 只能做 0/180 和镜像，HWUI 的 GL 路径忽略窗口变换提示，图层带着 `ROT_270` 进合成器，全部落到 GPU。补丁让 GL 走和 Vulkan 一样的预旋转：缓冲按面板方向分配，用逆变换绘制，损伤区域换算到缓冲坐标。旋转时重建 EGL surface。多留一块缓冲，给还被平面占着的上一帧。属性 `debug.hwui.gl_prerotation` 不设置就关闭。`init.kukui.rc` 设成 true。他在 sku0 上把平面上的图层从 0/5 变成 3/5，SurfaceFlinger 的 CPU 时间从 19.96 s 降到 11.60 s。

可行性：补丁在当前 `frameworks/base` 上能打上。默认关闭，别的设备不设这个属性就保持原样。合成器继续用 GLES，和现在的选择一致。改动在 HWUI 里，范围不小。

是否应该合并：应该合并。

合并需要的修改：属性未设置时，绘制结果要和现在一致。四个方向和相机预览再看一次。保持 GLES，不打开 Vulkan。

事件：

2026-11-13 正在运行的 `20261113b` 合成器是 `skiagl` / `skiaglthreaded`，GLES 是 Mesa Mali-G72。显示 0 的图层 `bufferTransform` 都是 `ROT_270`，`usesClientComposition=true`，`usesDeviceComposition=false`。补丁已进 `patches/frameworks_base_hwui_gl_prerotation.patch`，`apply-patches.sh` 打上，反向试打通过。`init.kukui.rc` 设 `debug.hwui.gl_prerotation true`，`debug.hwui.renderer` 仍是 `skiagl`。编出的 `system/lib64/libhwui.so` 含这个属性名，vendor 镜像里的 init 也有。system 分区 627118080 字节。super 展开后 8589934592 字节，sha256 `83be14748cc121c20034f8f1f53b0ed9da13f98f376611435fd4c284568c31d2`。三份 FIT 与 `20261108f` 相同。zip 是 `work/release/lineage-23.2-kukui-20261113c.zip`，1112365728 字节，sha256 `298026e083fd661c6e9c212308d0062ccf5a6d947a18aadf8d12e09c503f057b`。2026-11-13 15:58 整盘写入读卡器序列号 `000000002959` 的 `/dev/sda`。写入 11756634112 字节，读回 sha256 `8b0f50b2c69bd2034cf87a732a0fcc05fab735f278add17d96b1487d8d0be437`，super 读回 `83be14748cc121c20034f8f1f53b0ed9da13f98f376611435fd4c284568c31d2`。没有写 eMMC。用户从 U 盘启动，`ro.build.date` 是 Fri Nov 13 15:48:32 EST 2026，`ro.boot.boot_devices` 是 `soc/11201000.usb/11200000.usb`，`sys.boot_completed` 是 1。`debug.hwui.gl_prerotation` 是 true，`debug.hwui.renderer` 仍是 `skiagl`，GLES 仍是 Mesa Mali-G72。图层 `bufferTransform` 从 `ROT_270` 变成 0，源矩形按 1200×1920 的面板方向。设置界面这一帧五层都是 CLIENT，plane 0 扫的是这块 1200×1920 的合成缓冲；更早一帧 `usesDeviceComposition=true`。没有 tombstone，也没有 SurfaceFlinger 的 FATAL。用户确认四个方向和相机取景都正常。

## 73c4903 Kernel: CCI devfreq for SVS, CAP_SYS_NICE for cgroup v1 moves

内容：`bringup/phase2/config.fragment` 打开 `CONFIG_ARM_MEDIATEK_CCI_DEVFREQ=y`。mtk-svs 的第三组是 CCI，驱动关闭时它停在 deferred probe，SVS 电压不会生效。另一份新补丁 `cgroup-v1-cap-sys-nice.patch` 让持有 `CAP_SYS_NICE` 的进程可以写 cgroup v1 的 tasks 文件。没有它时 system_server 每次在 top-app、foreground、background 之间移线程都会 `Permission denied`。

可行性：两处都是主线内核相对 Android 通用内核的缺口。只合这一笔时 SVS 还会在后面的温区和 OPP 上停住，他后面的提交就是在补这些。cgroup 放宽的是写 tasks 的权限。

是否应该合并：应该合并，和 `2f60951`、`b7ed7de`、`b94297e` 一起。

合并需要的修改：四份补丁先在 6.18.28 上试打。确认 `CAP_SYS_NICE` 只覆盖 Android 需要的那次迁移。

事件：

2026-11-13 四份补丁在已打过的 6.18.28 上正向试打通过，没有改内容。`.config` 只多了 `CONFIG_ARM_MEDIATEK_CCI_DEVFREQ=y`。正在运行的 11 月 8 日内核里 SVS 停在 `failed to get OPP device for bank 2`，`AddTidToCgroup` 对 top-app、foreground、background 都是 `Permission denied`，温区只有 `cpu-thermal`、两块板温和电池，没有 `gpu-thermal`。新内核仍是 `6.18.28-mt81-kukui2`，`#1-kukui-phase2`，编译时间 Fri Nov 13 16:17:50 EST 2026。USB 和 eMMC FIT 的内核 lzma crc32 是 `d4016293`，三份 DTB 和原来的 ramdisk 没换，命令行仍有 `drm_client_lib.active=none`。菜单 FIT 仍是 10 月 31 日那份，lzma crc32 `f3ea1c10`，sha256 `653bb1a80043f3dd11f97d4059fc5f52335a50a99e8bf3ca4b8a8c0791d0a7ff`，命令行仍是 `console=ttynull`。super 与 `20261113c` 相同，sha256 `83be14748cc121c20034f8f1f53b0ed9da13f98f376611435fd4c284568c31d2`。zip 是 `work/release/lineage-23.2-kukui-20261113d.zip`，1112379450 字节，sha256 `ed1bd5bf2a94c3ae996704447b036f99057db53b1bc50c58cab83907902a57b0`。2026-11-13 17:49 整盘写入读卡器序列号 `000000002959` 的 `/dev/sda`。写入 11756634112 字节，读回 sha256 `629f05d9315c0fa25f3de9814cfb978c7a820afb8929a3412eb85f7dc6edfdf4`，super 读回 `83be14748cc121c20034f8f1f53b0ed9da13f98f376611435fd4c284568c31d2`。没有写 eMMC。用户从 U 盘启动，`/proc/version` 是 Fri Nov 13 16:17:50 EST 2026，`ro.boot.boot_devices` 是 `soc/11201000.usb/11200000.usb`，`sys.boot_completed` 是 1。`cpu-thermal` 仍在，另有 `soc-thermal`、`gpu-thermal`、`md1-thermal`、`cpu-little-thermal`、`cpu-big-thermal`、`tsabb-thermal`。`/sys/class/devfreq/cci` 绑在 `mtk-ccifreq`，passive，273–1196 MHz。`SVSB_CPU_LITTLE`、`SVSB_CPU_BIG`、`SVSB_CCI`、`SVSB_GPU` 都完成了 init01 和 init02，没有 `svs start fail`。`AddTidToCgroup failed` 是 0。合成器仍是 `skiagl`，有 HWC display 0。用户确认画面正常。`/proc/config.gz` 来自 ramdisk 里的旧 `configs.ko`，仍写着 CCI 未设置；正在运行的是 `mtk-ccifreq`。

## 2f60951 Kernel: register the per-sensor thermal zones mtk-svs needs

内容：新增 `bringup/kernel/auxadc-thermal-sensor-zones.patch`。CCI 通了之后，mtk-svs 停在 GPU：找不到 `gpu-thermal`。auxadc 驱动原来只注册 zone 0。补丁保留每个传感器的读数，并注册设备树里已有的温区。zone 0 不变。没有这些温区的设备树会跳过。

可行性：这是 SVS 的第二步，和他描述的启动日志对得上。改的是热区注册，不是调温策略。

是否应该合并：应该合并，作为 SVS 一组。

合并需要的修改：在 6.18.28 上试打。启动后看 `gpu-thermal` 是否出现，zone 0 的读数是否还在。

事件：

2026-11-13 和 SVS 一组打进 6.18.28，没有改补丁。`20261113d` 从 U 盘启动后，四组都完成了 init02，见上面 `73c4903` 的事件。用户确认画面正常。

## ac44fef Installer: update an Android only eMMC without formatting userdata

内容：安装器的「更新系统」原来要求 `android_kernel` 和 `menu_kernel`，那是 Android 加 Linux 的布局。只装 Android 时内核在 `pmOS_kernel`（p1），没有菜单，更新会停在找不到 `android_kernel`，只能再走一遍会格式化 userdata 的安装。这一笔让更新也接受 p1 是 `pmOS_kernel`、p3 是 super、p6 是 userdata、没有 `pmOS_root`、并且 p1 里已经是 eMMC 用的 Android 内核。然后复制 super，把 `android.kpart` 写到 p1，userdata、metadata、分区表和启动优先级不动。界面增加英文和中文状态。他在 Krane 上做了 dry-run，`state=dry_ok`。

可行性：缺口是真的。当前仓库里的 `kukui-installd.sh` 在这之后又有只装 Android、ChromeOS 大分区跳过备份和 dry-run，和他的基线不是同一份脚本。整文件拿过来会盖掉这些路径。

是否应该合并：功能要。这一笔先不直接合并。

合并需要的修改：在当前 `kukui-installd.sh` 上重做。保留只装 Android、ChromeOS 备份规则和 dry-run。更新不得格式化 userdata，不得改 GPT 优先级。先 dry-run，再写盘。

事件：

2026-11-13 当前 `kukui-installd.sh` 和两份 `strings.xml` 与 `ac44fef` 的父提交逐字节相同。ChromeOS 备份和 dry-run 已经在这份脚本里，摘这一笔不会盖掉它们。这一台的 eMMC 不是仅 Android 布局：p1 `pmOS_kernel`，p3 `pmOS_root`，p4 `menu_kernel`，p5 `android_kernel`（65536 扇区），p7 `super`（16777216 扇区），p10 `userdata` 是 f2fs。分区都没有挂载。新路径只在没有名为 `android_kernel` 的分区时才会走到。这张盘有 `android_kernel`，所以更新仍走原来的双系统路径。仅 Android 那条路径在这张盘上没有可测的布局。按用户要求把 `ac44fef` 原样合进当前脚本、字符串和 `MainActivity`。双系统路径的代码没有改写。没有写 eMMC，也没有在仅 Android 的盘上做 dry-run。

内容：新增 `bringup/kernel/mtk-cci-devfreq-opp-disable.patch`。温区注册之后，SVS 的 init01 失败：小核 buck 停在 893750 µV，期望 vboot 800000 µV。小核和 CCI 共用 vproc12。cpufreq 会离开被关掉的 OPP，CCI devfreq 原来只处理调压，于是 CCI 留在 845 MHz，把电压撑住。补丁在当前 OPP 被禁用时重新 `update_devfreq()`，并让目标频率用 `devfreq_recommended_opp()` 找到的那档，避免频率高于电压。他当时写的是编过、还没启动。后面的镜像包含这一笔并且启动了。

可行性：和前两笔是一条链。单独看日志是说得通的。要在我们的板上看到 buck 电压掉到 vboot，才算这一笔生效。

是否应该合并：应该合并，和 SVS 一组。

合并需要的修改：在 6.18.28 上试打。启动日志里看 SVS init01 是否还报电压不符。

事件：

2026-11-13 和 SVS 一组打进 6.18.28，没有改补丁。`20261113d` 从 U 盘启动后，四组都完成了 init02，见上面 `73c4903` 的事件。用户确认画面正常。

## b94297e Kernel: let panfrost devfreq follow OPP changes for SVS

内容：新增 `bringup/kernel/panfrost-devfreq-opp-notifier.patch`。GPU 那一组 SVS 调 OPP 时，panfrost 的 devfreq 要跟着离开被禁用的档，否则 GPU 电压和频率会对不上。

可行性：和 CCI 那笔是同一类问题，换到 GPU 驱动上。后面的性能提交在 sku0 上跑过持续负载，温度到 76°C，80°C 才开始降温。他在更后面的记录里写过第一次启动后有过一阵 panfrost 缺页，之后没有再出现。

是否应该合并：应该合并，和 SVS 一组。

合并需要的修改：在 6.18.28 上试打。看 GPU devfreq 是否跟着 SVS 的 OPP 走。

事件：

2026-11-13 和 SVS 一组打进 6.18.28，没有改补丁。`20261113d` 从 U 盘启动后，四组都完成了 init02，见上面 `73c4903` 的事件。用户确认画面正常。

## 736d92a Docs: kernel patch order, Android only update

内容：`docs/build.md` 和 `docs/install.md` 补了内核补丁顺序，以及只装 Android 的 eMMC 可以更新、不格式化 userdata。

可行性：文档跟着前面的提交走。那些提交还没按我们的脚本重做之前，这段说明会和仓库里的安装器不一致。后面的内核版本提交还会再改这些路径。

是否应该合并：随对应功能一起改写后再合并。

合并需要的修改：补丁顺序按最终决定的内核版本重写。安装器一节按重做后的脚本写。当前内核仍是 6.18.28 时，文档里的源码路径保持 6.18.28。

事件：

2026-11-13 名单里的补丁和配置片段都在。`docs/build.md` 写成 6.18.28 上的十步顺序，并写明菜单 FIT 仍用 10 月 31 日的内核。`docs/install.md` 写明仅 Android 的盘更新的是 super 和 `pmOS_kernel`，双系统的盘还会更新菜单。仅 Android 那条路径还没有在这台机器上跑过。

## d9cbef0 Send only scaled layers to the GPU in drm_hwcomposer

内容：`device.mk` 设置 `vendor.hwc.drm.scale_with_gpu=true`。drm_hwcomposer 认为列出 YUV 格式的平面就能缩放。MT8183 的 OVL 列了 YUYV 和 UYVY，但不能缩放。壁纸以 1.1 倍裁切显示时，测试提交返回 `ERANGE`，整帧落到 GPU。这个属性让需要缩放或亚像素裁切的图层走 GPU，其余仍试平面。他在 sku0 上把失败的测试提交从大约 170/650 降到 0。42 像素宽的状态栏仍然进 GPU，因为 mediatek-drm 把 MT8183 的 `min_width` 留在 64，那一笔在 `bcc64e1`。

可行性：只加一个厂商属性，不改合成器源码。和现有的 GLES 合成可以并存。

是否应该合并：应该合并。

合并需要的修改：合入后看主屏和打开应用的缩放动画，缩放图层进 GPU，其余图层还能上平面。

事件：

2026-11-13 当前合成器里 `ForcedScalingWithGpu()` 会在图层需要缩放或亚像素裁切时把它送去 GPU。正在运行的系统没有这个属性，内核日志里 `Test-only seamless=0 ret=-34 errno=34` 在刷。`device.mk` 已设 `vendor.hwc.drm.scale_with_gpu=true`，编进 `vendor/build.prop`。super 展开后 8589934592 字节，sha256 `04bbfa0a6d843b39b745afb256d19de9dab21f788537208b964d016b7f964ddc`。三份 FIT 与 `20261113d` 相同，菜单仍是 10 月 31 日那份。zip 是 `work/release/lineage-23.2-kukui-20261113e.zip`，1112363546 字节，sha256 `3136ca0415f8d46a529dbc4722c1ceed0ffdae3bd45a7f081ac748ddaa57777a`。2026-11-13 18:16 写入 `/dev/sda`（序列号 `000000002959`）。整盘回读 sha256 `837274b52f97b98f332a1617de2f1fabeb61f92ff5fb1699590074b2dfc63472`，super 回读与上面一致。2026-11-13 18:27 从 U 盘开机，`ro.build.date` 为 Fri Nov 13 18:10:10 EST 2026，内核仍是 16:17 那份 SVS。`vendor.hwc.drm.scale_with_gpu=true`，渲染器仍是 skiagl，预旋转仍开。日志里 `ret=-34` 和 `ERANGE` 都是 0。壁纸源裁切是 1125×1799 进 1200×1920，走 CLIENT。同一帧里 175 像素宽的任务栏曾走 DEVICE。当前画面整帧由 plane-0 扫描 1200×1920 的 AB24 客户端目标。打开应用时有 5 次 `could not create drm fb -22`，没有崩溃，也没有 tombstone。主屏壁纸和开关应用的画面看起来正常。42 像素宽的状态栏仍进 GPU，留给 `bcc64e1`。这份 super 同时带上了已经提交的安装器更新。

## b53e50e Kernel: make MDP3 work with the MT8183 SCP firmware

内容：新增 `bringup/kernel/mtk-mdp3-mt8183-scp-abi.patch`，大约 610 行。MT8183 的 SCP 固件和主线 MDP3 驱动的 ABI 对不上，补丁让 `mtk-mdp3` 能用这块固件。`docs/build.md` 记了它的位置。

可行性：这是后面旋转和 MM21 转换的前提。改动大，并且绑在我们正在用的那份 `scp.img` 上。他后面的系统能打开 MDP3，说明在他的 6.18.62/63 和那份固件上是通的。节点顺序被后面的 ueventd 写成固定的：camsv 0–1，解码 2，编码 3，mdp3 4。

是否应该合并：先不单独合并。和模块、合成器补丁、解码补丁、`/dev/video4` 权限一起，等内核编出来并且节点名字核对过再合。

合并需要的修改：先在 6.18.28 上试打。继续用现有的 `scp.img`。启动后读 `/sys/class/video4linux/video4/name`，确认是 mdp3，再写 ueventd。相机和解码节点的编号不能被挤乱。

事件：

2026-11-13 补丁在 6.18.28 上原样打上。2026-11-13 18:57 从 U 盘开机，`ro.build.date` 为 Fri Nov 13 18:33:01 EST 2026，内核仍是 16:17 那份。`video0` 和 `video1` 仍是 camsv，`video2` 是 `mtk-vcodec-dec`，`video3` 是 `mtk-vcodec-enc`，`video4` 是 `mtk-mdp3:m2m`。`/dev/video4` 仍是 `0660 media camera`，`ueventd` 没改。没有 `VPU MDP failure`。同一次休眠里 EC 报了 sleep transition timeout，ov02a10 和 ov8856 在关掉电源时打了时钟和稳压器的不平衡警告，调用栈不在 mdp3。

## 2815d72 Ship mtk-mdp3.ko in vendor_dlkm

内容：`device.mk` 把 `mtk-mdp3.ko` 放进 vendor_dlkm，并改了 `modules.dep` 和 `modules.load`。仓库里同时带上编好的 `.ko`。

可行性：模块要进镜像，否则用户态打不开节点。他提交里的 `.ko` 是他那棵内核的产物，和 6.18.28 的 vermagic 对不上就不能加载。

是否应该合并：模块名单应该合并。二进制不合并。

合并需要的修改：在选定的内核上自己编 `mtk-mdp3.ko`，再写入 `device.mk` 和模块清单。

事件：

2026-11-13 自己编的 `mtk-mdp3.ko` 是 136168 字节，vermagic `6.18.28-mt81-kukui2 SMP preempt mod_unload aarch64`。没有收他的 138704 字节二进制。`device.mk`、`modules.load`、`modules.dep` 已加上，排在编码器模块后面。内核 Image 时间仍是 16:17:59。三份 FIT 与 `20261113e` 相同，菜单仍是 10 月 31 日那份。super 展开后 8589934592 字节，sha256 `8e49d0b1c5855f4a6cf3055a0c164bccff71d1084f8c681f2208ff574438b01e`。zip 是 `work/release/lineage-23.2-kukui-20261113f.zip`，1112400638 字节，sha256 `c7ec8056432c70056b61a83441b1ac4f6d9eb38b02bec799eb1cb0753fa7957b`。2026-11-13 18:38 写入 `/dev/sda`（序列号 `000000002959`）。整盘回读 sha256 `9a8e9e0bc340d1750801d80dc3dd18922075afb7ee023ebeaa7c10025a4ef742`，super 回读与上面一致。模块已加载，`mtk_scp` 的引用计数是 2。主屏看起来正常。旋转和 MM21 转换还没放进这份镜像。

## 5e0cc3f Rotate 90/270 degree layers with MDP3 in drm_hwcomposer

内容：新增 `patches/external_drm_hwcomposer_mdp3_rotation.patch` 和 `sepolicy/vendor/hal_graphics_composer_default.te`。90/270 度的图层，包括 Firefox 的内容，提前一帧交给 MDP3 旋转，再放到平面上。没有 mtk-mdp3 节点，或者 `vendor.hwc.drm.mdp3_rotation=0` 时，这些图层仍走 GPU。

可行性：补丁在当前 `external/drm_hwcomposer` 上能打上。没有节点时的退路写在补丁说明里。真正旋转要等内核模块和 `/dev/video4` 的权限，权限在 `fc5ee05` 才加上。SELinux 仍是 permissive，策略可以先放进树里。

是否应该合并：应该合并，排在 MDP3 模块和节点权限之后。

合并需要的修改：先在没有 mdp3 节点的当前镜像上确认合成结果不变。节点出现之后再打开旋转。

事件：

2026-11-13 `20261113f` 已经在有 `video4`、没有这份合成器补丁时画面正常。补丁在当前 `external/drm_hwcomposer` 上原样打上，属性默认开。打不开节点或旋转失败时，90/270 度的图层仍走 GPU。`/dev/video4` 改为 `0660 media graphics`，因为合成器是 `system:graphics`；`video0` 到 `video3` 仍是 `media camera`。`fc5ee05` 里其余改动没有拿。super 展开后 8589934592 字节，sha256 `551eec93597fb597c4e91352cc6d84fbf21f35819bb53b3e6e86619559d6564c`。三份 FIT 与 `20261113f` 相同。zip 是 `work/release/lineage-23.2-kukui-20261113g.zip`，1112423484 字节，sha256 `d42dc7ce277b7f9ec5fb81bba111c14563c2aab3a3ad0980dad93460063e750e`。2026-11-13 19:12 写入 `/dev/sda`（序列号 `000000002959`）。整盘回读 sha256 `2f19ddd20b296d9f1e745de120ac67843f03bd5f29841e8fc51dae5ebf007842`，super 回读与上面一致。2026-11-13 19:29 从 U 盘开机，`ro.build.date` 为 Fri Nov 13 19:05:54 EST 2026。`video4` 仍是 `mtk-mdp3:m2m`，权限是 `media graphics`，前四个节点没变。属性为空，代码默认开。日志里有 `1920x1200 pitch 7680 rotate 270`，没有 `cannot open`、`rotation off` 或 `VPU MDP failure`。主屏和应用方向看起来正常。

## c91f3e0 Convert MM21 to NV12 with MDP3 in the V4L2 decoder

内容：新增 `patches/system_cros_codecs_mdp3.patch` 和 `sepolicy/vendor/mediacodec.te`。MDP3 把解码器缓冲里的 MM21 转成线性 NV12，直接写入客户端缓冲。没有 mtk-mdp3 节点，或者 `vendor.cros_codecs.mdp3=0` 时，仍走现有的 CPU 反块。`--reverse` 时先撤这一份，再撤原来的解码补丁。

可行性：补丁能叠在当前已经打上的 `system_cros_codecs.patch` 上。CPU 路径还在，所以模块没就绪时解码不应消失。不要用 `git diff` 重新生成原来的三份解码补丁。

是否应该合并：应该合并，排在 MDP3 模块之后。

合并需要的修改：`vendor.cros_codecs.mdp3=0` 时确认仍是现在的 CPU 反块。`/dev/video*` 保持 `media:camera`，只有确认是 mdp3 的那个节点另给 graphics 组。

事件：

2026-11-13 补丁叠在已经打上的 `system_cros_codecs.patch` 上，原来的三份解码补丁没有重新生成。属性为空时默认开，设成 `0` 或转换失败时仍走 CPU 反块。解码服务是 `media` 用户，能打开已经改成 `media graphics` 的 `video4`。`libcros_codecs_ffi.so` 里有 `MDP3 converts MM21 to NV12`。super 展开后 8589934592 字节，sha256 `2af18a36e5598ea90fc69d120bc864f784f6e5de5ec577859ef36a287255069a`。三份 FIT 与 `20261113g` 相同。zip 是 `work/release/lineage-23.2-kukui-20261113h.zip`，1112446451 字节，sha256 `8925b92a063a69ceec1433ce0d29ebbed34770c8172870fdc4001361f7ae0447`。2026-11-13 19:49 写入 `/dev/sda`（序列号 `000000002959`）。整盘回读 sha256 `53b42db816f8ecf6ab5113f1438717076f78eb65e67646c386228c8e3f3a71cd`，super 回读与上面一致。2026-11-13 20:18 从 U 盘开机，`ro.build.date` 为 Fri Nov 13 19:40:08 EST 2026。720p H.264 走 `/dev/video2`，对齐后的尺寸是 1280x768。日志有 `MDP3 converts MM21 to NV12 (/dev/video4)`，1200 帧平均 4.42 ms，没有关掉转换，也没有失败后退回 CPU。`video4` 仍是 `mtk-mdp3:m2m`，权限是 `media graphics`，前四个节点没变。没有 tombstone。内核警告仍是 EC 睡眠超时和摄像头时钟、稳压器，不是 mdp3。VP8 和 VP9 仍走软件解码。

## be4af95 Rebuild the kernel modules with the MDP3 patch

内容：按带 MDP3 补丁的内核重新放了一套 `.ko` 和模块清单。没有源码改动。

可行性：二进制只和他的那次构建匹配。

是否应该合并：不合并。

合并需要的修改：没有。模块在我们自己的内核构建里产生。

事件：

## 8b99860 Kernel: move to Linux 6.18.62

内容：内核换成 kernel.org 的 6.18.62。版本字符串改到 `6.18.62-mt81-kukui2`。`kukui-keep.c`、`kukui-menu.c`、`wrap-ramdisk.sh`、`pack-install-fits.sh`、`build-dtb.sh`、`pack-android-kpart.sh`、`setup-resukisu.sh`、`NOTICE`、`README` 和文档里的 6.18.28 路径一起改掉。`prebuilt/6.18.28-mt81-kukui2` 的模块清单换成 6.18.62。

可行性：他在 Krane sku0 的 eMMC 上启动过这个版本。我们这边菜单 FIT 固定用 2026-10-31 的 6.18.28 Image，后一次同版本内核放进菜单后再没有画出选项。换稳定版是另一次决定，不是这一批功能补丁的附带结果。Kodama 的 DTB 也从这棵新内核编。

是否应该合并：先不合并。

合并需要的修改：真要升级时，菜单 FIT 先保持能画出选项的那颗内核，单独验证新 Image 能画出 Android / Linux 之后再换。三份 FIT 配置（sku176、sku0、kodama sku16）保持原样。6.18.28 的模块清单留到新清单替换它为止。

事件：

## 8ceb40f Merge upstream main (one image for three devices)

内容：把 `ef09a94` 合并进他的分支。冲突在 `docs/fixes.md` 的末尾，以及两处 6.18.28 路径被改到 6.18.62：`pack-install-fits.sh` 的 `LINUX_SRC` 默认值，和 `docs/kodama.md` 里编 Kodama DTB 的步骤。

可行性：这是他追上我们主分支的 merge commit。我们这一侧就是 `ef09a94`。cherry-pick 这个合并没有新功能，还会把路径改到 6.18.62。

是否应该合并：不合并。

合并需要的修改：没有。从他的分支拿提交时跳过这一笔，源码路径留在 6.18.28，直到内核版本那一笔单独决定。

事件：

## 3b51904 Kernel: suspend debugging, pstore, TPM, RTC, Type-C, wakeup reasons

内容：`config.fragment` 打开 `CONFIG_PM_DEBUG`、`CONFIG_PM_SLEEP_DEBUG`、pstore ramoops、`CONFIG_LOG_BUF_SHIFT=21`、LRU_GEN、透明大页改为 madvise，并关掉 `CONFIG_RTC_HCTOSYS`。MT6358 的 RTC 会读成 2086 年，打开 HCTOSYS 会把系统时间设到那一年。新增三份补丁：相机传感器在系统睡眠时的电源、`sbs-battery` 对 time-to-empty 的 `ENODATA`、唤醒原因的 sysfs。`device.mk` 和模块清单加入对应 `.ko`，包括 TPM、RTC、Type-C。`init.kukui.rc` 有配套改动。`docs/build.md` 和 `docs/fixes.md` 记了他的测量。

可行性：RTC 那条是实打实的启动问题。pstore 用的是 coreboot 已经留好的 ramoops。`PM_DEBUG` 会多一些睡眠日志。这一笔没有打开喂狗。`.ko` 仍是他的构建产物。

是否应该合并：三份补丁和这些配置应该合并。二进制不合并。

合并需要的修改：三份补丁先在 6.18.28 上试打。模块清单按我们的构建重写。USB 启动看新的唤醒源会不会让睡眠立刻失败。系统时间确认不再跳到 2086。

事件：

2026-11-13 三份补丁打在 6.18.28 上：相机传感器在系统睡眠时的电源、`sbs-battery` 对 time-to-empty 的 `ENODATA`、唤醒原因 sysfs。配置打开 `PM_DEBUG`、`PM_SLEEP_DEBUG`、pstore ramoops、`LOG_BUF_SHIFT=21`、`LRU_GEN`，透明大页改为 madvise，`RTC_HCTOSYS` 保持关闭。`vendor_dlkm` 用这次内核重编，并加入 `rtc-mt6397`、`tpm_tis_core`、`tpm_tis_spi`、`cros-ec-typec`。没有用他的 `.ko`，没有打开喂狗。`vendor.dlkm.modules.ready` 之后重启 `prng_seeder`。USB 和 eMMC 的 FIT 用这颗内核，lzma crc `776b895f`，版本仍是 `6.18.28-mt81-kukui2`。菜单 FIT 与 `20261113h` 相同，10514432 字节，sha256 `653bb1a80043f3dd11f97d4059fc5f52335a50a99e8bf3ca4b8a8c0791d0a7ff`，lzma crc 仍是 `f3ea1c10`。super 展开后 8589934592 字节，sha256 `2befbe268e8280ff39dd587107b1c70ac04ee489270a6cbf5486c822646391b0`。zip 是 `work/release/lineage-23.2-kukui-20261113i.zip`，1116309444 字节，sha256 `3270c0b9484dc5bd78380f93cbee6fa36b6b749210860c8c9623d57cc9369efa`。img 11756634112 字节，sha256 `b39327df3093d7e03b32e6ab30b5bf6e1e3247c0313c70f5601ac966d9801d8b`。2026-11-13 21:00 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读 sha256 与 img 一致，super 回读与上面一致。这次开机只有背光，没有开机动画。`android.hardware.power-service.lineage-libperfmgr` 反复以 `Invalid config: /vendor/etc/powerhint.json` 退出，`system_server` 停在 `PowerManagerService` 等这个 HAL。原因和替换包记在 `fc5ee05`。开机核对记在 `20261113k`。`20261113h` 的 zip 没有改，仍是 1112446451 字节，sha256 `8925b92a063a69ceec1433ce0d29ebbed34770c8172870fdc4001361f7ae0447`。

## a9706cd Boot log on the panel, lid, deep sleep by default, lens power

内容：四件事情放在一笔里。

开机日志：USB 和 eMMC 的 Android FIT 去掉 `drm_client_lib.active=none`，改成 `loglevel=7` 和 `fbcon=font:TER16x32`。内核日志打在面板上，直到开机动画。`init.kukui.rc` 再解开 vtcon。他的前提是 SET_MASTER 已经让 drm_hwcomposer 能拿到 master。

盖子：键盘盖上的触摸板算外部设备，合盖后手还放在上面会在 26–124 ms 内把屏幕重新唤醒。`patches/frameworks_base_lid_wake.patch` 在合盖且 `lid_behavior` 为睡眠时，忽略触摸板和除电源、唤醒键以外的按键。开盖仍然唤醒。补丁在当前 `frameworks/base` 上能打上。

深睡：没有保存过选择时，eMMC 启动把 `suspend_power_off` 设为 1，于是 `mem_sleep` 用 deep。他量到睡眠电流大约 10 mA，s2idle 大约 53 mA，30 次 WoW 都能回来，键盘坞也能恢复。U 盘启动保持 0，避免关掉正在使用的 USB 口。

镜头：`bringup/kernel/dw9768-power-while-streaming.patch`。DW9768 在出流期间保持供电。

可行性：盖子补丁和镜头补丁可以分开落地。去掉 `drm_client_lib.active=none` 和我们现在的 Android FIT 相反：当前 U 盘和 eMMC 的 Android 内核带这个参数，让合成器独占显示。他是在自己的新内核上拿掉的。菜单 FIT 必须继续用 `console=ttynull`，不能带 `loglevel=7` 和 fbcon。深睡默认值只在没有保存选择时改 eMMC，和设置里的开关方向一致，但会改变没动过开关的机器。

是否应该合并：拆开。盖子补丁应该合并。镜头补丁应该合并，先在 6.18.28 上试打。eMMC 默认深睡可以合并，条件是已经保存的选择不动，U 盘启动保持不断电。去掉 `drm_client_lib.active=none` 和把开机日志打到面板上，先不合并。

合并需要的修改：Android 和 U 盘 FIT 继续带 `drm_client_lib.active=none` 与 `mem_sleep_default=s2idle`，直到在当前内核上证明拿掉之后仍然出画。菜单命令行保持 `console=ttynull` 和 `loglevel=1`。

事件：

2026-11-13 盖子补丁和 `dw9768` 出流期间保持供电的补丁已打上。没有保存过选择时，只有 `ro.boot.boot_devices` 是 `soc/11230000.mmc` 才把 `suspend_power_off` 设为 1，否则为 0。开机写 `pm_debug_messages=1`。没有去掉 `drm_client_lib.active=none`，没有改成 `loglevel=7` 或 fbcon，没有把开机日志打到面板上。菜单命令行仍是 `console=ttynull` 和 `loglevel=1`。放进上面的 `20261113i`。2026-11-13 21:00 已写入。那一版没有进到开机动画，替换包是 `20261113j`。开机核对记在 `20261113k`。

2026-11-13 U 盘和 eMMC 的 Android FIT 去掉 `drm_client_lib.active=none`，`loglevel` 改为 7。这颗内核只编了 `FONT_8x16`，没有 `TER16x32`，所以没有写 `fbcon=font:TER16x32`。`post-fs` 里解开 vtcon 的动作没动。内核 lzma crc 仍是 `8bc47106`，USB ramdisk crc `2e38f1e4`，eMMC ramdisk crc `1276030d`，三份 DTB 的 crc 仍是 sku176 `d92fe442`、sku0 `5d3e47c2`、Kodama `0e71f555`。菜单 FIT 仍是 `653bb1a80043f3dd11f97d4059fc5f52335a50a99e8bf3ca4b8a8c0791d0a7ff`，命令行仍是 `console=ttynull` 和 `loglevel=1`。super 仍是 `1635ad8d7faeb37f15b49faff9147750bc748160d28accabbec817b7d1d95b63`。USB FIT sha256 `c3d6503396dc8fbad33132627da05c179e1e132c7d8f79402f479f17ec20c515`，eMMC FIT sha256 `1731c418880b4241c49f4ad4a259980e3c264b4d68689e65e5b888953cf3b110`，都是 14290944 字节。zip 是 `work/release/lineage-23.2-kukui-20261113o.zip`，1116320185 字节，sha256 `09422400a1a37a6baf6598fe985ca3b55e1a42e8b7a0b06e616b5c8dbba92d26`。img sha256 `8d8cc4e378812d09b2c108ed1786a38d6c87cd1294f0d3fb68a999a83f253596`。2026-11-14 00:07 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读与 img 一致，super 回读与上面一致。2026-11-14 00:13 用户确认面板上能看到内核日志，并且进到了桌面。

## bcc64e1 Status bar on a plane, kernel version, SELinux labels, two decoders

内容：新增 `bringup/kernel/mtk-drm-mt8183-min-fb-size.patch`，把 MT8183 的最小 framebuffer 宽度从 64 降到能放下大约 42 像素的状态栏，否则 AddFB2 返回 -22，状态栏只能进 GPU。`media_codecs_c2.xml` 里 H.264 解码的 `concurrent-instances` 从 1 改成 2。他用 Firefox 同时播了两路视频。新增一批 SELinux 标签：灯、传感器、vendor_init，以及 genfs。`init.kukui.rc` 去掉开机动画阶段再解一次 vtcon 的动作，因为 post-fs 已经解过 vtcon0 和 vtcon1。SELinux 仍是 permissive。

可行性：状态栏宽度是 `d9cbef0` 留下的具体限制，补丁小。两路解码在他的镜像上跑过，我们这边单路硬解刚恢复，还没有在同一棵用户态上试过第二路。策略文件可以在 permissive 下先入库。

是否应该合并：最小宽度补丁和 SELinux 标签应该合并。并发实例先留在 1。

合并需要的修改：最小宽度只改到状态栏能过 AddFB2。两路解码等单路在我们自己的镜像上确认之后再改 xml。vtcon 解绑只留 post-fs 那一处。

事件：

2026-11-13 最小 framebuffer 补丁打进 Image。SELinux 增加灯、传感器、vendor_init 和 genfs。`concurrent-instances` 留在 1。没有改 `KBUILD_BUILD_VERSION`。vtcon 解绑仍只在 post-fs。放进 `20261113i`，修正电源配置后的 `20261113j` 仍带着它。`20261113j` 开机向导前进时整屏闪。当时状态栏是 42x1920，合成类型是 DEVICE；上一份没有这个补丁的镜像里 AddFB2 拒绝这个宽度，状态栏留在 GPU。这颗内核已撤掉 `.min_width` 和 `.min_height`，64 的默认值还在。DTB 和 ramdisk 与 `20261113j` 相同，super 也相同，sha256 `bf5896c2c6e114165d04fe335336582103bc8ef91b24a1c7a8c0c3fb7f75b940`。新内核 lzma crc `8bc47106`。zip 是 `work/release/lineage-23.2-kukui-20261113k.zip`，1116318614 字节，sha256 `d5c56c29df24f662e31d70a661a4eb73af012d1f47e2dd6eeffcfe66d379c8fb`。img sha256 `02dfc0b69c267e47c8bd5399719bc493db8dfb92b6f774538c7c922eea03909a`。菜单 FIT 仍是 `653bb1a80043f3dd11f97d4059fc5f52335a50a99e8bf3ca4b8a8c0791d0a7ff`。2026-11-13 21:52 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读与 img 一致，super 回读与上面一致。

2026-11-13 22:06 在 `10.0.0.120:5555` 上核对这张 `20261113k`。状态栏仍是 42×1920，合成类型是 CLIENT。电源 HAL 在跑，`/vendor/etc/powerhint.json` 是 1924 字节的普通文件，没有 tombstone。序列号 `HA16SW5Q`，硬件版本 `rev6 sku176`，系统时间是当天。U 盘 `suspend_power_off` 是 0，`mem_sleep` 停在 s2idle。ondemand 的 `up_threshold` 是 80，`io_is_busy` 是 1，background 和 system-background 在 0–3。`/proc/config.gz` 里有 `LRU_GEN`、pstore、BTF、`INET_DIAG_DESTROY`、`FS_VERITY`，`RTC_HCTOSYS` 关闭。Firefox 在前台。

这张 FIT 的 sku176 DTB 是从内核树重新编译的，没有接上 `bringup/camera` 里的摄像头节点。和 `20261113h` 的 sku176 相比，除了 `/firmware` 的 `#address-cells` 和 `#size-cells`，摄像头节点也没了。传感器和 CAMSV 没有绑定，视频节点只剩 video0 解码、video1 编码、video2 `mtk-mdp3:m2m`，属组是 camera。

摄像头片段已接回 `20261113k` 的 sku176，再导出 sku0。Kodama 的 DTB、内核、ramdisk、super 和菜单 FIT 都没换。内核 lzma crc 仍是 `8bc47106`。sku176 crc `d92fe442`，sku0 crc `5d3e47c2`，Kodama crc 仍是 `0e71f555`。USB ramdisk crc `2e38f1e4`，eMMC ramdisk crc `1276030d`。菜单 FIT 仍是 `653bb1a80043f3dd11f97d4059fc5f52335a50a99e8bf3ca4b8a8c0791d0a7ff`，lzma crc `f3ea1c10`。super 仍是 `bf5896c2c6e114165d04fe335336582103bc8ef91b24a1c7a8c0c3fb7f75b940`。zip 是 `work/release/lineage-23.2-kukui-20261113l.zip`，1116316682 字节，sha256 `12b8fe6046695143d0c2abb4d5de886affb047441f0155f6f2f9104f9fd020d8`。img sha256 `d1de068c7cc990902cec4b4aab7fc51b03b138524407553bdccfa1b746b108a9`。2026-11-13 22:29 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读与 img 一致，super 回读与上面一致。

2026-11-13 22:38 在 `10.0.0.120:5555` 上核对，用户确认相机正常。video0 和 video1 是 CAMSV，属组 camera；video2 是 `mtk-vcodec-dec`，video3 是 `mtk-vcodec-enc`，属组都是 camera；video4 是 `mtk-mdp3:m2m`，属组 graphics。后摄 `ov8856 2-0010`、对焦 `dw9768 2-000c`、前摄 `ov02a10 4-003d` 都绑上了。内核仍是 `6.18.28-mt81-kukui2`，编译时间 Fri Nov 13 21:46:27 EST 2026。

单路硬解已经在更早的镜像上确认过。H.264 解码的 `concurrent-instances` 和 `ro.vendor.v4l2_codec2.decode_concurrent_instances` 改成 2，编码仍是 1。和壁纸缩放放在同一张 `20261113m` 里，shader cache 仍关着，安装器没有放进去。内核、三份 FIT 与 `20261113l` 相同。super 展开后 8589934592 字节，sha256 `54e94a774494bdff6b765646ec79c3b7fdbd4b6774f6e5119b2fd04f5826fe67`。zip 是 `work/release/lineage-23.2-kukui-20261113m.zip`，1116315528 字节，sha256 `3bea3e24d345f7da0ad19fa65a6e8a03dd87c75b0aeb4689f84abd2a33522810`。img sha256 `26955868831c566c7c1f087c46d987802ff0c3f07ad82195bf30d4590516cada`。2026-11-13 22:58 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读与 img 一致，super 回读与上面一致。

2026-11-13 23:20 在 `10.0.0.120:5555` 上核对。`decode_concurrent_instances` 是 2，解码器 xml 的上限是 2，编码仍是 1。MX Player 和 Just Player 都开了 `c2.v4l2.avc.decoder`，codec2 服务里同时有两路 H.264（stream 2 和之后的 stream 3）。互相暂停是音频焦点：两边都申请 `AUDIOFOCUS_GAIN`，大约两秒淡出后输的一方收到 loss 并自己停掉。不是解码器拒绝第二路。

## 7f6d160 Serial number, kernel BTF, socket destroy, SELinux labels part 2

内容：设置里的序列号原来是 unknown。序列号在只读 VPD 里，需要 `coreboot_table` 和 vpd-sysfs。6.18 起 `of_bus_default_match()` 要求父节点有 `#address-cells`，depthcharge 创建的 `/firmware` 只有空的 `ranges`，`coreboot_table` 返回 `-EINVAL`。`bringup/kernel/mt8183-kukui-firmware-cells.patch` 在 `mt8183-kukui.dtsi` 里声明 2/2，由 depthcharge 填进去。`kukui-ids.sh` 从 VPD 写 `ro.serialno`，从 coreboot 的板号和 SKU 写 `ro.boot.hardware.revision`。配置打开 BTF（编译机要有 pahole）、`CONFIG_INET_DIAG_DESTROY`、`CONFIG_INET_UDP_DIAG=m`、`CONFIG_FS_VERITY`。没有 BTF 时，电量统计用的 cputimeinstate BPF 对象会被 libbpf 丢掉。没有 `INET_DIAG_DESTROY` 时，system_server 每销毁一个套接字都记 `ENOTSUP`。SELinux 再补触控笔电池、wakeup、extcon、IIO、video 节点和相机 HAL 的若干权限。他在 eMMC 上看到了序列号和硬件版本。

可行性：固件节点和序列号脚本是设备树里的小改动，不依赖换内核版本，但固件补丁要在 6.18.28 的 dtsi 上对得上。BTF 让内核构建依赖 dwarves，Image 多一个 `.BTF` 段。fs-verity 要 userdata 带这个特性才会被用到，现有数据分区不会因为这一行就启用。

是否应该合并：应该合并。二进制模块不合并。

合并需要的修改：编译机安装 dwarves。固件补丁在 6.18.28 上试打。`kukui-ids.sh` 只在属性还空的时候写入。SELinux 保持 permissive。

事件：

2026-11-13 固件 `#address-cells` 补丁进三份 DTB。`kukui-ids.sh` 只在属性为空时写序列号和硬件版本。配置打开 BTF、`INET_DIAG_DESTROY`、`INET_UDP_DIAG=m`、`FS_VERITY`。vendor 加入 `coreboot_table`、`vpd-sysfs`。ramdisk 加入 `iptable_nat`、`ip6table_nat`、`xt_MASQUERADE`、`udp_diag`。SELinux 补触控笔电池、wakeup、extcon、IIO、`/dev/media*` 和 `/dev/v4l-subdev*`。没有用他的二进制。放进上面的 `20261113i`。2026-11-13 21:00 已写入。那一版没有进到开机动画，替换包是 `20261113j`。开机核对记在 `20261113k`。

## 7814fe5 Kernel: move to Linux 6.18.63; netd modules for tether stats

内容：内核再换到 6.18.63，版本字符串 `6.18.63-mt81-kukui2`，`KBUILD_BUILD_VERSION=5`。他说相对 6.18.62 只多了下面三个网络选项，其余补丁能用偏移打上。netd 在同一批 iptables-restore 里带 `-j TCPMSS`，ramdisk 里没有 `xt_TCPMSS`，整批失败，`tetherctrl_counters` 不存在，NetworkStats 每次轮询都报取不到热点统计。ramdisk 增加 `xt_TCPMSS`、`xt_NFLOG`、`sch_ingress`、`cls_bpf`、`act_bpf`。quota2 仍然没有，主线内核没有这个 Android 模块。健康 HAL 重新允许读触控笔电池。文档和 Kodama 的路径改到 6.18.63。预编译模块清单从 6.18.62 改名到 6.18.63。

可行性：热点统计这一段可以落在当前内核的模块清单上，不必等版本升级。6.18.63 本身和 `8b99860` 是同一种版本决定。他在 eMMC 上确认计数链出现、没有热点统计错误。

是否应该合并：内核版本先不合并。网络模块名单应该合并。

合并需要的修改：版本字符串保持 `6.18.28-mt81-kukui2`。`xt_TCPMSS` 等放进我们自己的 ramdisk 清单并重编。看 netd 日志里 quota2 仍然缺失时，其余规则是否已经能建起来。

事件：

2026-11-13 内核版本没有升。ramdisk 增加 `xt_TCPMSS`、`xt_NFLOG`、`sch_ingress`、`cls_bpf`、`act_bpf`。健康 HAL 允许读触控笔电池。quota2 仍然没有。放进上面的 `20261113i`。2026-11-13 21:00 已写入。那一版没有进到开机动画，替换包是 `20261113j`。开机核对记在 `20261113k`。

## 5067807 Installer: copy and check only the used parts of super, show steps

内容：更新系统原来复制并回读全部 8 GiB。U 盘在板载 USB 2.0 集线器后面，大约 35–40 MB/s，时间大多花在读零上。Android 实际用的是 LP 元数据和六个逻辑分区，大约 1.3 GiB。`kukui-installd` 用 `lpdump` 读 extent，丢掉 eMMC 上的 super，只复制元数据区和分区 extent，元数据区最后写，避免写到一半时分区表已经指向半份数据。复制时用 tee 算 sha256，U 盘只读一遍；丢掉页缓存后再从 eMMC 读回比较。界面列出步骤和进度，中英文都有。他在 Krane 上更新过，每一步不到一分钟，之后从 eMMC 启动。

可行性：方向对，而且依赖 `ac44fef` 的更新布局。我们的发布镜像里是展开后的 raw super，不是他 U 盘写入器用的 sparse 文件。只要 GPT 里的 super 带合法的 LP 元数据，`lpdump` 就能列出 extent。安装器进程里要有 `lpdump`。当前脚本和他的脚本已经分叉。

是否应该合并：功能要。和 `ac44fef` 一起在当前脚本上重做，不直接合并。

合并需要的修改：安装器里带上 `lpdump`。中断后不能留下指向半份数据的元数据。回读前丢掉页缓存。只装 Android 和 Android 加 Linux 都做 dry-run。继续接受展开后的 raw super。

事件：

2026-11-13 只复制 LP 元数据和六个逻辑分区，元数据放在最后。`lpdump` 本来就在 `/system/bin`。只装 Android 和 Android 加 Linux 走同一段复制，目标分区仍分别是 `mmcblk0p3` 和 `mmcblk0p7`。更新系统也走这一段。主机上对 `20261113n` 的 raw super 做了 dry-run：1297 MiB，不是 8192 MiB，区域不重叠，元数据在最后，复制到另一个文件后每个区域的 sha256 和 `lpdump` 的分区表都和源一致。没有写 eMMC，没有新的 U 盘镜像。

## fc5ee05 Performance: power HAL boosts, MDP3 for the composer, wallpaper on a plane, AOT after updates

内容：一笔里放了多件已经在 sku0 上量过的事。

电源：`TARGET_POWER_HAL := perfmgr-lineage`，新增 `power/powerhint.json`。触摸时小核 1248 MHz、大核 1716 MHz、GPU 653 MHz；启动时拉满最多 3 秒；省电把大核限在 1508 MHz、GPU 限在 500 MHz。AOSP 的示例 HAL 会忽略这些提示。

CPU：`init.kukui.rc` 把 ondemand 的 `up_threshold` 设为 80，`io_is_busy` 设为 1，background 和 system-background 留在 A53 上。

合成：MDP3 旋转以前没跑起来，因为 drm_hwcomposer 是 `system:graphics`，打不开 `0660 media camera` 的 `/dev/video4`。ueventd 给这个节点加上 graphics 组，属主仍是 media。播视频时 SurfaceFlinger 的 CPU 从 41% 降到 21%。

壁纸：`config_wallpaperMaxScale` 改成 1.0。1.1 倍时壁纸永远要缩放，平面做不到，连同它和上面活动图层之间的东西都进 GPU。主屏和通知栏因此上了平面，壁纸的缩放动画没有了。

AOT：更新系统走 OTA 那条启动，`pm.dexopt.boot-after-ota` 原来是 verify，`/data` 里的应用要等充电空闲才编译。改成 speed-profile 之后，Firefox 的启动时间大约减半。

另外重新打开 SurfaceFlinger 的 shader cache，把 `tun.ko` 放进 vendor_dlkm 以提供 `/dev/tun`，并补了 GPU、显示、音频和memfd 的 SELinux 类型。他试过但没有收益的项：GPU devfreq 16 ms 轮询、eMMC read-ahead 512 KB、Mesa glthread。第一次更新后的启动有过一阵 panfrost 缺页，加压之后没有再出现。

可行性：电源 HAL、ondemand、tun 和 AOT 都在设备树里，可以单独合。`/dev/video4` 那一行建立在节点顺序不变的前提下；顺序变了就会把 graphics 组套到解码器或编码器上。壁纸 1.0 会去掉缩放动画。shader cache 早期关过，是因为 RenderEngine 崩过，重新打开要再看一次。

是否应该合并：拆开。电源 HAL、ondemand、`tun.ko` 的名单、AOT 应该合并。`/dev/video4` 在确认节点名字之后合并。壁纸缩放和 shader cache 单独决定。

合并需要的修改：启动后确认 `video4` 的名字是 mdp3，再加 `0660 media graphics`。`/dev/video*`、`/dev/media*`、`/dev/v4l-subdev*` 继续是 `0660 media camera`。电源 HAL 只写在 Kukui 的 `BoardConfig.mk` 和 `device.mk`。要保留壁纸缩放动画就不改 `config_wallpaperMaxScale`。`tun.ko` 用自己的内核编。

事件：

2026-11-13 `TARGET_POWER_HAL` 改为 `perfmgr-lineage`，带上 `powerhint.json`。ondemand 的 `up_threshold` 为 80，`io_is_busy` 为 1，background 和 system-background 留在 0–3。`pm.dexopt.boot-after-ota=speed-profile`。`tun.ko` 进 `vendor_dlkm`。SELinux 补了 GPU、显示、音频和 mediacodec 的类型，原来的 MDP3 允许保留。壁纸缩放没有改，shader cache 仍是关闭。`/dev/video4` 的属主在更早的提交里已经是 `media graphics`，这一批没有再改。放进 `20261113i` 并在 21:00 写入。那一版没有进到开机动画。`/vendor/etc/powerhint.json` 在镜像里是指向编译机路径的符号链接，HAL 读不到，于是 `Invalid config` 退出。`system_server` 停在 `PowerManagerService` 等这个服务，开机动画没有出来。`link_device_tree` 把源文件做成符号链接，`prebuilt_etc` 原样装进了 vendor。现在先把内容复制成普通文件再安装，节点改用 `Paths`。内核和三份 FIT 与 `20261113i` 相同。super 展开后 8589934592 字节，sha256 `bf5896c2c6e114165d04fe335336582103bc8ef91b24a1c7a8c0c3fb7f75b940`。zip 是 `work/release/lineage-23.2-kukui-20261113j.zip`，1116313512 字节，sha256 `c6159f4632f8fbeb9930cfed6164ba0a5585f338e8c5ff6d045e847359046d26`。img sha256 `915d2c282b2403d7c8d75b667a8b1a585eceffd30b8fd48c5d5fe8dde88c0ab6`。2026-11-13 21:28 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读与 img 一致，super 回读与上面一致。开机核对记在 `20261113k`。`/dev/video4` 在 `20261113l` 上是 `mtk-mdp3:m2m`，属组 graphics。

壁纸 `config_wallpaperMaxScale` 改成 1.0。shader cache 仍是关闭。和两路 H.264 解码放在同一张 `20261113m` 里。2026-11-13 22:58 已写入。两路硬解的核对记在 `bcc64e1`。

`service.sf.prime_shader_cache=false` 已去掉，启动时按 SurfaceFlinger 的默认去预热 shader cache。安装器没有放进这张镜像。内核、三份 FIT 与 `20261113m` 相同。super 展开后 8589934592 字节，sha256 `1635ad8d7faeb37f15b49faff9147750bc748160d28accabbec817b7d1d95b63`。zip 是 `work/release/lineage-23.2-kukui-20261113n.zip`，1116315333 字节，sha256 `fe36c5526feca0046373d6cf1724d50b8bed4f00690106257bbfe8ec37bfa113`。img sha256 `9242eb64aacebcfd84e8d4f96f936a8f4ba142543807a8f3a415350918891b54`。2026-11-13 23:38 写入 `/dev/sda`（序列号 `000000002959`）。清缓存后整盘回读与 img 一致，super 回读与上面一致。

## fccfd18 docs: the USB kernel command line of the tested images

内容：`docs/build.md` 写下他 Build 1 到 7 的 U 盘内核命令行：`loglevel=7`、`fbcon=font:TER16x32`，没有 `drm_client_lib.active=none`。`pack-install-fits.sh` 写的是 eMMC 命令行，U 盘 FIT 沿用被打包的那份 FIT 自带的命令行，仓库里原先没有记下这一份。

可行性：这是他测过的镜像的记录，不是我们 `20261108f` 和 `20261108g` 的命令行。我们的 U 盘内核带 `androidboot.boot_devices=soc/11201000.usb/11200000.usb` 和 `drm_client_lib.active=none`。

是否应该合并：不把这段写成当前构建说明。

合并需要的修改：若以后要记，单独标明是 krecks Build 1–7 的 U 盘内核。当前发布包的命令行保持现有 FIT。

事件：

## 174c947 Use the legacy MessageQueue so Firefox can start

内容：Firefox 159 的界面能起来，Gecko 马上退出。`trunk_staging` 把 `RELEASE_PACKAGE_MESSAGEQUEUE_IMPLEMENTATION` 设成 `CombinedDeliMessageQueue`，它的 `next()` 没有 `@UnsupportedAppUsage`，ART 对 targetSdk 37 的 JNI 调用直接拒绝。随 Android 16 发布的配置用 `CombinedMessageQueue`，也只放到 targetSdk 36。这一笔在设备树里把 Kukui 的 trunk_staging 覆盖成 `LegacyMessageQueue`，也就是这个 flag 的默认值，Android 15 及更早使用的队列。`next()` 仍带普通的 `@UnsupportedAppUsage`。隐藏 API 的执行策略本身没有放宽。三个文件都在 `device/google/kukui/release/`。

可行性：只影响 `lineage_kukui-trunk_staging` 这一次 lunch。别的设备和别的 release 配置不读这些 textproto。当前构建就是这个 lunch。

是否应该合并：应该合并。

合并需要的修改：合入后看 Firefox 能进入主界面，并且没有放宽别的隐藏 API。

事件：

2026-11-13 `device/google/kukui/release` 整目录链到仓库，`trunk_staging` 标明 `RELEASE_CONFIG`，flag 覆盖成 `LegacyMessageQueue/MessageQueue.java`。第二次编 super 时构建读到了这个值。放进上面的 `20261113i`。2026-11-13 21:00 已写入。那一版没有进到开机动画，替换包是 `20261113j`。开机核对记在 `20261113k`。
