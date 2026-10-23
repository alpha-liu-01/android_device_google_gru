# 已知问题

实机是 Scarlet（Acer Chromebook Tab 10），系统是 microSD 上的 LineageOS 23.2。这里只记已经复现过的问题。USB 音频走的是另一块 `snd-usb-audio` 控制器，下面这条和它无关。

| 编号 | 状态 | 现象 |
| :--- | :--- | :--- |
| 1 | 已在本次启动中验证，重启后要靠新的 `vendor` 镜像才保留 | 睡眠唤醒后内置扬声器没声音 |
| 2 | 已修复，2026-10-22 实机验证 | 滑动被锁在 30 fps |
| 3 | 已修复，2026-10-23 实机验证 | 早上第一次起来后自动旋转停住，加速度和陀螺仪不再出数 |
| 4 | 已修复，2026-10-23 实机验证 | USB-C 接显示器或电视时，画面正常，声音仍从内置扬声器出来 |
| 5 | 已修复，2026-10-23 实机验证 | 每次开机后「设置 → 显示 → 自动熄屏」变成未设置 |
| 6 | 已修复，2026-10-23 实机验证 | 开机没有 LineageOS 标志，先黑屏无背光，再黑屏有背光 |
| 7 | 已修复，2026-10-23 实机验证 | 720p 竖屏（720×1280）硬解画面全是横线和竖线 |
| 8 | 已修复，2026-10-23 实机验证 | SELinux 停在 permissive |

## 1. 睡眠唤醒后内置扬声器没声音

- **现象**：开机后内置扬声器正常。进入 S3 再唤醒，按键音、媒体音都没有。USB 耳机（`card 1`）仍然正常。
- **日志与实测（`10.0.0.110`，2026-10-21）**：
  - `AudioFlinger` 的内置输出线程 `AudioOut_D`（`AUDIO_DEVICE_OUT_SPEAKER`，`CARD_0_DEV_0`）在唤醒后仍然按实时速度写出有幅度的 PCM。这不能证明喇叭在响：`StreamPrimary` 用 `usleep` 自己节流，硬件时钟停了界面也还是按秒走。
  - 直接 `tinyplay2` 播 3 秒 48 kHz 立体声，唤醒后大约 **0.53 秒**就写完。按采样点算大约是 48 kHz 的 6.5 倍，等于 `80000000 / (4 × 64)`。RK3399 的小数分频器在分母没有按「分子的 20 倍」锁住时，硬件会退回 `parent/20`，`clk_i2s0_div` 的 1.6 GHz 父时钟除以 20 就是 **80 MHz**。
  - `/sys/kernel/debug/clk` 里 `clk_i2s0` 仍显示 `12288000`，`CLKSEL_CON(96)` 读出来的分子/分母也还是休眠前的 `24/3125`。时钟框架认为速率没变，`clk_set_rate()` 同一个值是空操作，不会把 CRU 的锁存再写一遍。I2S 的 `CKR` 按 12.288 MHz 配了 `div 4 / 64`，实际主时钟却是 80 MHz，所以 LRCK 变成大约 312.5 kHz，喇叭等于听不到。
  - 停流时 `I2S_CLR` 要等主时钟自己清掉。主时钟不对时轮询 200 µs 超时（`-110`，`fail to clear` / `lrclk update failed`）。这个错误原来会让 `soc_dai_trigger` 失败，之后每次打开都还是静音。
- **修复**（`patches/kernel_6.6.34_rockchip_i2s_s3_mclk.patch`，模块 `snd-soc-rockchip-i2s.ko`）：
  1. `runtime_resume` 里先把 mclk 设成一半再设回原来的速率，强迫 CRU 重新锁存；同时 `disable`/`enable` 一次，把被 S3 复位的门控写回去。设备如果休眠时还处于 runtime active，走 `SET_SYSTEM_SLEEP_PM_OPS` 的 resume 做同样的事。
  2. 先停 `XFER` 再清 FIFO，轮询放宽到 5 ms。超时只打警告，不再让 DAI trigger 失败。BCLK 引脚改到清 FIFO 之后再切成 GPIO。resume 时写一次 `I2S_CLR = 0`，清掉已经卡住的清除位。
- **实机**：新模块载入后，`suspend_stats/success` 从 2 增到 3 的那次唤醒之后，连续两次 `tinyplay2` 都是 **3.05 秒 / 3.04 秒**，没有新的 `fail to clear`。当前这次启动已经在用新模块，可以直接再睡一次试喇叭。重启后要靠下面这份镜像，旧的 `/vendor/lib/snd-soc-rockchip-i2s.ko` 还是坏的。
- **新发布包**：`lineage-23.2-gru-20261022.zip`，`1,038,696,275` 字节，SHA-256 `00c03b5ac10bd3a9d55d47f943e24c1bde627d671a87742afef027c680feef1f`。里面的 `super` 是实机验证过的 `d42fde74ce7b878b92c39c313a36809d9de80e3178e4b5d15c3621ee4ae01924`（61 Hz、大 VOP、AFBC，以及这次的扬声器修复）。

## 2. 滑动被锁在 30 fps

- **现象**：设置这类普通二维界面滑动也只有大约 30–45 fps。CPU、GPU、内存控制器的频率已经拉满，Panfrost 也在做硬件渲染。
- **原因**：面板时序是 `1536x2048 @ 229 MHz`，实际刷新率 **60.01552 Hz**。`config_defaultRefreshRate` 原来是整数 **60**，DisplayModeDirector 把渲染区间投票成 `[0, 60.00]`。SurfaceFlinger 判定帧率是否落在区间内的容差只有 **0.001 Hz**，`60.02` 被排除，只剩下整除得到的 **30.01 Hz**。触摸加速选的是区间里的最高值，所以滑动也出不了 30 fps。
- **修复前（2026-10-22 凌晨，`dumpsys SurfaceFlinger`）**：
  - `render=[0.00 Hz, 60.00 Hz]`，`renderRate=30.01 Hz`，`app duration=33.32 ms`。
  - 开机后 `60.02 Hz` 只累计了 **29.250 秒**，其余 **1 小时 18 分钟**都在 `30.01 Hz`。一次 2 秒滑动更新了 PowerManager 的 interaction boost，60 Hz 累计时间没有增加。
  - `dumpsys gfxinfo com.android.settings`：帧时间中位数 **22 ms**，GPU 中位数 **7 ms**。相对 33 ms 的 deadline 只有 **4.14%** 掉帧。
- **修复**：`device/google/gru/overlay/frameworks/base/core/res/res/values/config.xml` 把 `config_defaultRefreshRate` 设为 **61**。这个值打进 vendor 静态 overlay `framework-res__lineage_gru__auto_generated_rro_vendor.apk`，随 `super` 分区刷入。镜像 `/run/media/alpha/YMTC/lineage-23.2/out/target/product/gru/super.img`，`1,262,412,180` 字节，SHA-256 `d72d0824edbcc7f62b44dcc739a4fef38d31e93fd96581e07ef9345421f786e8`。
- **实机（同一台，`10.0.0.110`，2026-10-22，设置停留在前台）**：
  - `mDefaultRefreshRate=61.0`，`render=[0.00 Hz, 61.00 Hz]`，`renderRate=60.02 Hz`，`presDeadline=16.66 ms`，`app duration=16.66 ms`。
  - 这次开机亮屏 **5 分 52 秒**全部记在 `60.02 Hz`，没有 `30.01 Hz` 这一档。
  - 设置的 `gfxinfo`：帧时间中位数 **17 ms**，90 分位 **34 ms**，相对 16.6 ms deadline 掉帧 **10.56%**（2624 帧里 277 帧）。GPU 中位数 **3 ms**，90 分位 **9 ms**。
- **还没解决的掉帧**：图层仍全部是 `CLIENT` + `ROT_90`，合成效率大约 **1.4%**。VOP 不能做 90° 旋转。设置的中位数已经落在一帧以内，更重的界面仍会越过 16.6 ms。
- **PiliPlus（`com.example.piliplus`，2026-10-22，60.02 Hz 已生效）**：Flutter 的 SurfaceView 在一次滑动里，SurfaceFlinger 收到的生产间隔中位数 **32.5 ms**，送上屏幕的间隔中位数 **33.4 ms**。同一段时间 A72 到 **2.016 GHz**，GPU 到 **800 MHz**，内存控制器到 **928 MHz**。帧是应用自己大约 30 fps 画出来的，不是又被锁回 30.01 Hz。两张全屏缓冲（应用 2048×1536，framebuffer 1536×2048）都是线性、未压缩，各约 **12.6 MiB**。
- **AFBC 第一次镜像没有生效（2026-10-22，`10.0.0.110:43509`，PiliPlus 在前台）**：`/vendor/lib64/libminigbm_gralloc_upstream.so` 已是新文件（135200 字节，含 `rockchip AFBC` 字符串），但分配器日志是 `no matching backend, using dumb backend as fallback`，随后 `Loaded driver dumb_generic on path /dev/dri/card0`。`drv_get_backend()` 只按名字匹配 `is_generic_backend == false` 的后端，rockchip 这份被标成 generic，所以 AFBC 的 `bo_create` 根本没被调用。PiliPlus 和 framebuffer 的 `fourcc/mod` 仍是 `875708993/0`，`compressed: false`。同一次滑动的生产间隔中位数 **33.1 ms**，上屏间隔中位数 **33.4 ms**，和刷之前一样。
- **第二次镜像把屏刷黑了（SHA-256 `180a226ad74dde07547ace0d0891b91a4f58f619e020d1dc696345edae79514e`）**：后端这次选中了，日志是 `Loaded driver rockchip`。全屏缓冲变成 `fourcc/mod 875708993/576460752303423569`（`0x0800000000000051`，即 `AFBC 16x16|SPARSE|YTR`），`compressed: true`，1536×2048 从 12288 KiB 变成 12480 KiB。`drm_hwcomposer` 对 DSI-1 的 atomic commit 一直返回 `-EINVAL`，画面不出来，只剩背光。这个补丁先从 `apply-patches.sh` 里拿掉，文件还留在 `patches/external_minigbm-upstream_rockchip_afbc.patch`。
- **当场恢复**：`setprop vendor.minigbm.debug nocompression` 后重启 allocator 和 surfaceflinger，framebuffer 回到 `mod 0`、`compressed: false`。这个属性重启就丢。回退镜像另存在 `super-linear.img`，`1,262,412,180` 字节，SHA-256 `23b6268974f2c25e312b66a03bf19e404667701b08defa7d886daf1214f50bcc`。
- **大 VOP + AFBC 已生效，体感没有变化（2026-10-22，`10.0.0.110:5555`，PiliPlus 在前台）**：镜像 SHA-256 `d42fde74ce7b878b92c39c313a36809d9de80e3178e4b5d15c3621ee4ae01924`。日志是 `Preferring CRTC 44 (4 planes) for DSI-1`，分配器是 `Loaded driver rockchip`。PiliPlus 的 SurfaceView 和 framebuffer 都是 `fourcc/mod 875708993/576460752303423569`（`0x0800000000000051`），`compressed: true`，大小 **12491 KiB**。同一次滑动里，生产间隔中位数从 **32.5 ms** 降到 **29.3 ms**，上屏间隔中位数仍是 **33.4 ms**（62 帧里 45 帧落在 20–40 ms）。帧还是隔一个 vsync 才送上去，所以看起来仍是 30 fps。
- **竖屏对照，平面合成仍然没接上（2026-10-22，同一镜像）**：机器当时停在竖屏，自动旋转开着。PiliPlus 的 SurfaceView 是 `1536x2048`、变换是 0，图层仍全部是 `CLIENT`。生产间隔中位数 **31.6 ms**，上屏间隔中位数 **33.4 ms**。滑动时内核打出 `AFBC does not support offset display`，壁纸的源坐标不是 0。`vop_crtc_atomic_check` 还要求一帧最多一个 AFBC 平面。测试提交失败后，hwcomposer 把整帧退回 CLIENT。横屏图层带 90° 旋转，这块 VOP 的 AFBC 不能转，所以平面合成接不住现在的滑动。文档里其余还没做的项（关掉 HW overlay、HWUI dirty region）改不了这个大约 30 ms 的生产间隔。

## 3. 早上第一次起来后加速度和陀螺仪不再出数

- **现象**：每天早上第一次起来，自动旋转停住。AIDA64 里加速度、陀螺仪以及由它们算出来的重力、线性加速度、旋转矢量都没有新读数。温度还在变，温度走的是 SoC 的 thermal zone。锁屏无关：`Sensor Privacy: disabled`，`WindowOrientationListener` 已经订着 `cros-ec-accel`，`has sensor access: true`，只是一个事件都没送到。同一天再关机开机就不再出现。2026-10-22 早上是这样，2026-10-23 早上又是这样。
- **2026-10-23 09:35 抓到的现场（`10.0.0.114`，开机约 7 分钟，还没重启）**：`dumpsys sensorservice` 的 Recent events 是空的。`iio:device0`（`cros-ec-accel`）的 buffer 已经 `enable=1`。内核从 `09:33:12` 起不停打 `cros-ec-sensorhub.1.auto: Sensor 1: lost N samples when spreading`，两分钟里 N 从 **22219** 涨到 **49353**，抓 dmesg 时已经到 **69149**，一共一万七千多行。Sensor 0 同时在丢，只是慢一些（同一时刻大约 3480）。这些警告把内核环形缓冲盖满了，更早的 suspend 行已经不在 dmesg 里。
- **原因**：`cros_ec_sensor_ring_spread_add()`（`cros_ec_sensorhub_ring.c`）要靠上一批的 `last_len` 把同一时间戳上的一串样本摊开。过夜之后 FIFO 溢出，resume 和 `total_lost` 都会把 `last_len` 清成 0（`tight_timestamps`）。EC 接着送来的样本时间戳不往前走，全挤在同一个时间点。`last_len == 0` 时函数算不出周期，整批丢掉，并且把 `penul_len` 留成 0。后面每个新样本的时间戳仍然不大于 `last_ts`，代码又退回 `penul_len == 0`，继续整批丢掉。计数因此一直涨，HAL 侧永远没有新事件。重启把 `batch_state` 清掉，FIFO 里也不再有这一夜的堆积，时间戳重新往前走，同一天后面的开关机就正常。
- **2026-10-22 下午那次短睡眠没有卡住**：电源键睡眠大约 4 秒，内核是 `Sensor 0: lost: 6362 out of 6362`，16 秒后加速度恢复到 Z 轴约 9.8 m/s²。短睡眠的时间戳还能往前走，摊开逻辑能重新算周期。过夜之后时间戳停住，才会卡死。
- **修复**（`patches/kernel_6.6.34_cros_ec_sensorhub_spread_stall.patch`，模块 `cros-ec-sensorhub.ko`，vermagic 仍是 `6.6.34-phase2`，不用换内核）：
  1. 比上一笔样本早超过 1 秒的，当成断档。不再把它的时间戳改成 `last_ts`，同时把 `last_len`、`penul_len` 清掉，让这一笔按新的一批重新开始。
  2. 时间戳不往前走，或者 `last_len == 0` 时，不再整批丢掉。只把这一批里最新的一笔按 10 ms 往前送，并把锚点收成一笔（`last_len = 1`，`penul_len = 1`）。算出来的周期如果是 0 或负数，也按 10 ms。
  3. 丢掉的样本仍打 `lost N samples when spreading`，改成限速，不再把 dmesg 刷满。
- **镜像**：`/run/media/alpha/YMTC/lineage-23.2/out/target/product/gru/super.img`，`1,262,416,276` 字节，SHA-256 `c789abb06c4a134a0df142077ee905b7231782b60311c5a5f994e6a3a81fe8a4`。里面的 `/vendor/lib/cros-ec-sensorhub.ko` 是新模块（SHA-256 `b6f2ae8e876ff86dac42a4b67b2f6c7d16c02518c53929599cd00e79847ca79a`）。vermagic 仍是 `6.6.34-phase2`，不用换内核分区。
- **实机（2026-10-23）**：刷入上面这份 super 之后，早上第一次开机的自动旋转恢复。

## 4. USB-C 接显示器或电视时没有声音

- **现象**：USB-C 转 HDMI、USB-C 转 DP 都一样。画面正常，所有声音仍从内置扬声器出来，播放设备列表里只有内置这一项。同一条 HDMI 转接线在运行 Android 15 的任天堂 Switch 上有声音。音量条 0–10% 才有效是 postmarketOS 上的问题，这套 Android 上没有。
- **不是上游缺 HDMI codec**。postmarketOS wiki 写的 “HDMI codec is currently not supported” 对这台机器的内核已经不成立：`snd-soc-hdmi-codec` 已加载，ALSA 有 `card 0` 的 `pcmC0D3p`（`DP PCM` / `spdif-hifi-3`），声卡上也有 `DP Jack`。SPDIF 在设备树里接到 cdn-dp，和喇叭用的 i2s0 不是同一条 DAI。
- **原因**：
  1. 上游把 DP 插拔报成 `SND_JACK_LINEOUT`。Android 的 `WiredAccessoryManager` 只在同时看到 `SW_LINEOUT_INSERT` 和 `SW_VIDEOOUT_INSERT` 时才当成 HDMI；只有 LINEOUT 会被当成模拟线路输出，打开的是耳机那路（`pcmC0D2`），不是 DP。
  2. `config_useDevInputEventForAudioJack` 是关的，插拔事件到不了 AudioService。
  3. `audio_policy_configuration.xml` 没有 `AUDIO_DEVICE_OUT_HDMI` 端口，策略里可选的输出只有扬声器。
- **修复**：
  1. `patches/kernel_6.6.34_dp_audio_avout_jack.patch`：`hdmi-codec.c` 和 `rk3399_gru_sound.c` 把 DP jack 改成 `SND_JACK_AVOUT`（LINEOUT|VIDEOOUT）。模块 `snd-soc-hdmi-codec.ko`（SHA-256 `46d642583be1dfc34407308b18b10b5e89c923e00db79113d44955e0b642bab9`）、`snd-soc-rk3399-gru-sound.ko`（SHA-256 `3f84954ea097f643b862513709c1932cf6b113abd202d8f5085a2fc94853b8fe`）。vermagic 仍是 `6.6.34-phase2`，不用换内核。
  2. overlay 打开 `config_useDevInputEventForAudioJack`。耳机插拔本来就走这套开关，一起打开。
  3. 音频策略增加 `HDMI Out`（`AUDIO_DEVICE_OUT_HDMI`，48 kHz 立体声，不放进 `attachedDevices`）。`StreamPrimary` 遇到 HDMI 时打开 `pcmC0D3p`（`ro.vendor.audio.hdmi.alsa_device`，默认 3）。
- **第一次镜像没接上（2026-10-23 11:15，`10.0.0.114:5555`，SHA-256 `e85325df337ed0bbb31e7e64ca7162a22979251e861c56307b9a91f161c8ac52`）**：HDMI 和 DP 插上后画面正常，播放设备仍只有本机。DP Jack 的开关已经是 `SW 140`（LINEOUT|VIDEOOUT）。`WiredAccessoryManager` 收到插拔，策略也找到了 `AUDIO_DEVICE_OUT_HDMI`。接着 `AHAL_Module` 打 `populateConnectedDevicePort: module implementation must override 'populateConnectedDevicePort'`，`setDeviceConnectionState` 返回 **-38**（`EX_ILLEGAL_STATE`），端口没有变成可用设备。默认实现拒绝一切外部设备，XML 里写好的静态 profile 也不够。
- **接着补的一处**：`ModulePrimary::populateConnectedDevicePort` 对已经声明了 profile 的外部端口直接返回成功，沿用策略里的 48 kHz 立体声。补丁在 `patches/hardware_interfaces_audio_usb_alsa_sync_io.patch`。
- **验证用的镜像** SHA-256 `47fbb4fcd3e31bc416c17b8933fa95a99a004b00b38acd80adeb1c80acfb245b`，`1,262,416,276` 字节。vermagic 仍是 `6.6.34-phase2`，不用换内核分区。这份文件后来被第 5、6 节的 super 盖掉了。
- **实机（2026-10-23 11:30–11:32，`10.0.0.114:5555`，上面这份 super）**：HDMI 和 DP 各插了一次，日志里两条线都是 `cdn-dp`，分不出哪次是哪根线。第一次 `11:30:11` `Connected, not enabled. Enabling cdn`，`11:31:01` 主输出关掉 PCM，`11:31:03` 释放已经配好的 HDMI 端口 23（48 kHz、立体声、`INT_16_BIT`）。这次的连接行已经滚出 logcat。第二次 `11:31:56` 再次 `Enabling cdn`，`11:31:57` `populateConnectedDevicePort: keeping declared profiles`，`connected port ID 25`，没有再出现 `-38`。`11:32:07` 主输出（mix handle 13）的 patch 落到这个 HDMI 端口，`setConnectedDevices` 是 `connection: hdmi`。从这时起到 `11:32:24` 拔掉，可观察帧数从 **7643136** 涨到 **8470528**，差 **827392** 帧，按 48 kHz 是 **17.24 秒**，和墙上时间 **17.28 秒** 一致。`11:32:30` 主输出回到 `CARD_0_DEV_0`。查日志时线已经拔了，`dumpsys media.audio_policy` 的可用输出只剩扬声器。

## 5. 每次开机后自动熄屏变成未设置

- **现象**：开机后「设置 → 显示 → 自动熄屏」没有选中任何一项。
- **原因**：阶段 3 在 `sys.boot_completed=1` 里执行 `settings put system screen_off_timeout 86400000`（24 小时），每次开机都写一遍。设置列表只到 30 分钟（`1800000`），`86400000` 对不上任何一项，下拉框就是空的。平台默认是 `60000`（1 分钟）。
- **修复**：`init.gru.rc` 不再每次写入这个值。`/vendor/bin/boot_settings.sh` 只在读到 `86400000` 时改回 `60000`。用户另外选过的超时保留。

## 6. 开机没有 LineageOS 标志

- **现象**：开机先是一段黑屏、背光不亮，然后一段黑屏、背光亮着，没有 LineageOS 标志。系统本身能进桌面。
- **原因**：
  1. 阶段 3 在 early-init 设置 `debug.sf.nobootanimation 1`。当时 bootanim 和 SwiftShader 一起占 CPU，SystemUI 启动超时。镜像里的 `bootanimation.zip` 一直都在（`1536×512`，60 fps，Lineage 标志），只是没被播放。SwiftShader 后来已经从镜像里拿掉，合成走 Panfrost。
  2. 背光不亮的那一段是 SurfaceFlinger 接手面板之前。命令行有 `drm_kms_helper.fbdev_emulation=0`，post-fs 又把帧缓冲控制台解开，免得控制台占着主平面让合成器变成 headless。这段不能靠打开 bootanim 补上。
- **修复**：去掉 `debug.sf.nobootanimation`。背光亮起来之后应出现 Lineage 标志，直到桌面。背光亮之前仍是黑的。
- **镜像**：`/run/media/alpha/YMTC/lineage-23.2/out/target/product/gru/super.img`，`1,262,416,276` 字节，SHA-256 `c870421b3317bc37ca25d728b6cde904c5aeaa2deed10a7a441e722a6cfdf2b8`。vermagic 仍是 `6.6.34-phase2`，不用换内核分区。第 5 节和第 6 节都在这份里。
- **实机（2026-10-23）**：刷入上面这份 super 之后，自动熄屏有了选中项，开机背光亮起后出现 Lineage 标志。这份文件后来被第 7 节的 super 盖掉了。

## 7. 720p 竖屏硬解画面全是横线和竖线

- **现象**：H.264 720×1280 用 `c2.v4l2.avc.decoder` 硬解时，画面分辨不出内容，全是横线和竖线。1280×720 和 1080p 竖屏正常。
- **现场（2026-10-23 11:53，`10.0.0.114:5555`，正在播这段视频）**：`StatelessV4L2Decoder` 打出 `Format changed: coded 720x1280, visible (0,0)-(720,1280)`，接着 `Output buffer layout: Y offset 0 stride 768, UV offset 983040 stride 768`。`983040 = 768 × 1280`。CCodec 的 `raw.size` 和 `raw.crop` 都是 720×1280。
- **原因**：`rkvdec-h264.c` 的 `hor_virstride` 是 `(bit_depth + 8) × width / 8`。8-bit、宽 720 时跨距是 **720**，UV 从 `720 × 1280 = 921600` 开始写。分配器走 dumb 缓冲，`rockchip_gem_dumb_create` 把 pitch 对齐到 64 字节，720 变成 **768**，gralloc 把这个 pitch 报成平面跨距。合成器按 768 读、硬件按 720 写，每一行错 48 字节，整帧就散成横线和竖线。1280 能被 64 整除。1080 竖屏经 V4L2 的 16 像素步进变成编码宽 1088，1088 也能被 64 整除。这两种的 dumb pitch 和硬件跨距相同。
- **修复**：`external/minigbm` 和 `external/minigbm-upstream` 的 `drv_helpers.c` 里，`DRM_FORMAT_NV12` 且带 `BO_USE_HW_VIDEO_DECODER` 时，报给合成器的跨距改成 `ALIGN(width, 16)`，不再用 dumb pitch。缓冲本身仍按 dumb pitch 分配，大小够放下画面和运动矢量。补丁加在 `patches/external_minigbm_rkvdec_nv12.patch` 和 `patches/external_minigbm-upstream_rkvdec_nv12.patch`。
- **镜像**：`/run/media/alpha/YMTC/lineage-23.2/out/target/product/gru/super.img`，`1,262,420,372` 字节，SHA-256 `7250c915af383b7c4c230fe9f74255a7bf40349bcf2bcc7a6d70a57596ade8d7`。vermagic 仍是 `6.6.34-phase2`，不用换内核分区。刷入后重播这段 720×1280，日志里的布局应变成 `Y offset 0 stride 720, UV offset 921600 stride 720`。
- **实机（2026-10-23）**：刷入上面这份 super 之后，720×1280 硬解画面正常。这份文件后来被第 8 节的 super 盖掉了。

## 8. SELinux 停在 permissive

- **现象**：`getenforce` 是 Permissive，`ro.boot.selinux=permissive`。FIT 命令行写着 `androidboot.selinux=permissive`。内核开了 `CONFIG_SECURITY_SELINUX_DEVELOP`，启动时是 permissive，要等 init 按命令行调用 setenforce。命令行必须写成 `enforcing`，拿掉这个词仍然是 permissive。
- **这次启动（permissive，播过 720×1280）里，enforcing 会挡住启动或现有功能的拒绝，以及对应的策略**：
  1. 节点没有类型。genfs 按真实 sysfs 路径匹配，`/sys/class` 的符号链接不算。背光 `/devices/platform/backlight` 标成 `vendor_sysfs_backlight`，`hal_light` 可以写亮度。电池 `sbs-9-000b` 下面的 `wakeup` 仍是 `sysfs_wakeup`，它的 `power_supply` 和 `cros-usbpd-charger` 的 `power_supply` 是 `sysfs_batteryinfo`。IIO 总线和 `cros-ec-sensorhub` 是 `vendor_sysfs_iio`，`vendor_init` 可以改这些节点的属主。`display-subsystem` 是 `sysfs_gpu`。`/bus/media`、`/class/video4linux` 和两个 `video-codec` 是 `sysfs_v4l`。`/dev/media*`、`/dev/v4l-subdev*` 是 `video_device`。外置卡 `fe320000.mmc` 是 `sysfs_devices_block`。
  2. 外置卡分区：`mmcblk0p3` metadata、`p4` misc、`p5` super、`p6` userdata，整盘是 `gru_sd_device`。内置 eMMC（`mmcblk1`）不贴这些标签。`kcmdlinectrl` 和 `misctrl` 本来就能读写 `misc_block_device`；p4 之前是 `block_device`，enforcing 下不能打开。
  3. 这块 6.6 内核用 devtmpfs。策略加载之后 `kdevtmpfs` 还要创建 loop 和 dm 节点，创建时类型是 `device`。`coredomain` 禁止 `kernel` 对 `device:blk_file` 做 `create`。补丁 `patches/system_sepolicy_devtmpfs_kernel_device.patch` 在这条 neverallow 里把 `kernel` 除外。允许的只有 `create`、`setattr`、`unlink`，没有 `open`、`read`、`write`。节点随后由 ueventd restorecon。
  4. 开机把 `Out DAIR Mux` 设成 0 的那条 `tinymix2`，原来经 `/system/bin/sh` 进入 `shell`。`shell` 是 appdomain，不能打开 `audio_device`。现在直接执行 `/system/bin/tinymix2`，进入 `gru_mixer`。
  5. `expand_userdata` 去掉了 `seclabel u:r:init:s0`。init 不能 `execute_no_trans` 任意文件。脚本进入 `gru_expand`，可以读几何、读写外置卡和 userdata 分区，并在本域执行 `sgdisk` 和 `resize.f2fs`。不能卸载或挂载 `/data`。这张卡已经扩过，脚本在那一步之前就退出。
  6. memfd 出生时是 `tmpfs`，libcutils 随后改标签。音频、传感器、codec、`system_server` 在改标签之前要读写或映射这块内存。
- **编译期 neverallow 删掉、enforcing 下仍会拒绝的几条**：`surfaceflinger` 读未单独声明的 `vendor_default_prop`；`vendor_init` 读 `init.svc.usbd`，所以那条 `stop usbd` 的触发可能不生效；`shell` 读内核 syslog。`gru-logcat` 去掉 `seclabel` 后停在 `shell`，kmsg 还能写，logcat 到 kmsg 的镜像不一定还能转进 `logpersist`。应用的 RenderThread 读 `display-subsystem` 的 uevent 仍会被拒绝，surfaceflinger 可以读。
- **策略**：`m selinux_policy` 已通过。
- **第一次 enforcing 镜像**（两条都刷过）：
  - super `1,262,428,564` 字节，SHA-256 `78f30d44382b43eea470fea028447d2d8637015c2d7d778a0f11b17130aa0ebc`。
  - `vmlinuz.kpart` `14,417,920` 字节，SHA-256 `e8a1fff77bc9a1a2e2f373acbd8a5253ccc700a02d8d16752013dc3e85d00014`。命令行含 `androidboot.selinux=enforcing`。内核仍是 `6.6.34-phase2`。
- **实机（2026-10-23）**：刷入后没有进到界面。`gru-phase3.log` 的命令行是 enforcing，第一阶段已经建出 `dm-0` 到 `dm-5`，并挂上 system、vendor、system_ext。日志停在这里，是因为 setenforce 之后 `gru-keep` 再读 `/dev/kmsg` 被拒绝，不是启动停在这一行。`/metadata/expand_userdata` 末尾是 `1970-01-01 00:00:08 UTC` 的一次运行，几何读完后打印已经扩过。`/metadata/bootstat` 是空目录，没有 `persist.sys.boot.reason`，所以不是 `vold` 或 `apexd` 的 `reboot_on_failure`。
- **第一次判断**：`kdevtmpfs` 的 `vfs_mknod()` 要 `CAP_MKNOD`，平台策略只有 `dontaudit`。补了 `allow kernel self:global_capability_class_set mknod;`。编进 precompiled policy 的是 `kernel self:capability { mknod }`，另外还有 `device:blk_file create`。
- **第二次实机（2026-10-23，super `0da049f6025a4dcee8012adf1edbe486ff290c0592849e1ae831b90ab8ce52e0`）**：背光仍然不亮。`expand_userdata` 又多了一条 `1970-01-01 00:00:08 UTC`，说明 `post-fs` 又跑完了。`post-fs` 里会解开 vtconsole，背光要等 `on boot` 里的 `class hal`（lights HAL），那在 zygote 之后。`bootstat` 仍是空的。这次 `gru-phase3.log` 只有 `51,856` 字节，停在建出 `dm-2`。上一次停在 system_ext 挂载成功。两次都是 setenforce 时 `gru-keep` 丢掉了 `/dev/kmsg`，停的位置差十几行，不是启动停得更早。
- **日志为什么断**：`gru-keep` 在 devtmpfs 盖住 `/dev` 之前，在 rootfs 上建了 `/dev/kmsg`。启动日志在没有标签的 ext4 上。setenforce 之后，`kernel` 读 `rootfs:chr_file`、写 `unlabeled:file` 都被拒绝，后面的 init 输出和 AVC 都没记下来。`CAP_MKNOD` 那条已经在第二次刷进去的策略里，单靠它没有把背光点亮。
- **第三次实机（2026-10-23，super `9b8e5d854dd03c97364f6f20334022c8ee80de96394e1c1e68fa19402936c499`）**：背光仍然不亮。这次日志有 `1,685,961` 字节。`apexd.status=activated` 等了 2574ms 之后继续。zygote、surfaceflinger 都起来了。surfaceflinger 找到 `mapper/minigbm_upstream` 后立刻 `SIGABRT`，init 判定 updatable component 在开机完成前退出 4 次，然后不停重启它。
- **原因**：`init.gru.rc` 的 `early-init` 在 `vendor_init` 里 `insmod /vendor/lib/*.ko`。enforcing 拒绝 `vendor_init` 的 `sys_module`，`finit_module` 返回 `EPERM`。`panfrost.ko`、声卡、传感器、解码器都没装上。审计在前 7 次之后限速，后面的失败不再打 AVC，但 init 仍记下 `Operation not permitted`。没有 GPU，surfaceflinger 起不来，背光也就不亮。`sys.use_memfd` 也设不进去，因为 `vendor_init` 不能写这个 system 属性；`device.mk` 里它本来就该进 system 的 `build.prop`。`sys.brightness.disable_gamma_conversion` 已经在 `PRODUCT_PRODUCT_PROPERTIES` 里。
- **修复**：`vendor_init` 增加 `sys_module`、`vendor_file:system module_load` 和 `kernel:key search`。`PRODUCT_SYSTEM_PROPERTIES` 写入 `sys.use_memfd=true`。内核分区不用换。
- **第四次实机（2026-10-23，super `0029be8333846283c5bac89368dad46958a7e4a142826c80f63e905e632fba69`）**：背光仍然不亮。`expand_userdata` 这次的时间是 `2026-10-23 18:24:34 UTC`，时钟已经走起来。第一阶段在 setenforce 之前装进 89 个模块，`panfrost ff9a0000.gpu` 完成初始化，`rockchip-drm` 绑上了 DSI。`apexd.status=activated` 之后 surfaceflinger 找到 `mapper/minigbm_upstream`，接着 `SIGABRT`，init 继续按 updatable component 重启它。
- **原因**：libdrm 在 surfaceflinger 里读 `/sys/devices/platform/display-subsystem/uevent`，要拿 `OF_FULLNAME`。读失败后再读 `MODALIAS`，同一 inode 上共 4 次 `{ read }`，`tcontext` 是 `sysfs`，`permissive=0`。策略里的 genfscon 会把 `/devices/platform/display-subsystem` 标成 `sysfs_gpu`，surfaceflinger 也能读 `sysfs_gpu`。这个 uevent 在策略加载前就已经存在，跑起来的类型仍是 `sysfs`。`coredomain` 禁止读未单独标注的 `sysfs:file`，所以这次读取失败，surfaceflinger 退出，背光不亮。
- **修复**：`patches/system_sepolicy_surfaceflinger_sysfs_uevent.patch` 把 surfaceflinger 从这条 neverallow 的读权限里除外，并允许 `surfaceflinger sysfs:file r_file_perms`。写 `sysfs` 仍然禁止。`ff9a0000.gpu` 补了 `sysfs_gpu`。`kdevtmpfs` 建 `/dev/snd` 目录被拒绝的那条，补了 `kernel device:dir create`。内核分区不用换。
- **第五次实机（2026-10-23，super `2417ddb26cecebbf30e22d39bb8b1337df4c68e68e8fe8e3fc0806c41026bf1a`）**：进到桌面。设置里 SELinux 显示正在运行，`getenforce` 是 Enforcing。内核分区仍是 `e8a1fff77bc9a1a2e2f373acbd8a5253ccc700a02d8d16752013dc3e85d00014`，命令行 `loglevel=7`。
- **这次启动里不该进发布包的调试**：`gru-keep` 在看门狗移交并执行 `/init.android` 之后仍留着一个 `SCHED_FIFO` 进程（pid 1069），每 200 ms 读 `/dev/kmsg`，并以 `O_SYNC` 写 `/bootlog/gru-phase3.log`。`init.svc.gru_logcat` 是空的，这条服务没跑起来，但 `init.gru.rc` 里还定义着，会把 logcat 镜像到 `/data/gru-logcat.txt` 和 `/dev/kmsg`。
- **打包前从源码拿掉的**：`gru-keep` 只在执行 Android init 之前把当时的 kmsg 写进 bootlog，然后卸掉 bootlog、关掉日志、执行 `/init.android`，不再留常驻进程。`gru_logcat` 服务和 `gru-logcat.sh` 不再装进镜像。FIT 命令行改成 `loglevel=4`，界面起来之后仍把控制台降到 `3 4 1 3`。`printk.devkmsg=on` 留着，避免扩容脚本写 kmsg 被限速。`debug.renderengine.backend=skiaglthreaded`、`debug.hwui.renderer=skiagl`、`debug.stagefright.c2-poolmask=0x70000`、无线 adb（`ro.adb.secure=0`，端口 5555）和桌面模式那条属性都是功能设置，继续留着。
- **清理后的镜像（还没刷）**：super 仍是 `1,262,428,564` 字节，SHA-256 `437a56cda05720f693c446e9fdbba350cad76b7b598a80881ace4e95e7a80b91`。`vmlinuz.kpart` `13,746,176` 字节，SHA-256 `6583c6480079801f6b9edd27830d95251dae40c1b9820185ba54b47504f94a5d`，命令行是 `loglevel=4` 和 `androidboot.selinux=enforcing`。`prebuilt/gru-keep` 这次用 ramdisk 的 bionic 静态链接并去掉了调试符号，还没在实机上跑过。只刷 super 的话，卡上的旧 FIT 仍会留下常驻日志进程和 `loglevel=7`。回退仍是 permissive FIT `920f638358c36c85800bd48f4b9ae12bc528af8242d096557c3f03a65cd6e5ae` 配 super `7250c915af383b7c4c230fe9f74255a7bf40349bcf2bcc7a6d70a57596ade8d7`。只换回旧 super、留下 enforcing 的 FIT，还会停在同一处。
