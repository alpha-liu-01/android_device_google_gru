# 已知问题

实机是 Scarlet（Acer Chromebook Tab 10），系统是 microSD 上的 LineageOS 23.2。这里只记已经复现过的问题。USB 音频走的是另一块 `snd-usb-audio` 控制器，下面这条和它无关。

| 编号 | 状态 | 现象 |
| :--- | :--- | :--- |
| 1 | 已在本次启动中验证，重启后要靠新的 `vendor` 镜像才保留 | 睡眠唤醒后内置扬声器没声音 |
| 2 | 已修复，2026-10-22 实机验证 | 滑动被锁在 30 fps |

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
