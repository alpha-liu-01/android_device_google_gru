# Kukui PR #5 里哪些能用在 Gru 上

来源是 [pr-5.md](pr-5.md)，krecks 在 `android_device_google_kukui` 的 #5，共 29 个提交。那台机器是 MT8183、内核 6.18、Mali-G72、mtk-mdp3、mtk-vcodec。Gru 这边是 RK3399（Scarlet）、内核 6.6.34-phase2、Panfrost Mali-T860、rockchip VOP、rkvdec。lunch 是 `lineage_gru-bp4a-userdebug`。系统从外部 microSD 启动，不往内部 eMMC 写。

2026-11-14 在当前系统上看过：`mem_sleep` 已经是 `s2idle [deep]`；`/dev/dma_heap` 里有 `system` 和 `reserved`；cpu0 和 cpu4 都是 `schedutil`；传感器只有 `cros-ec-accel` 和 `cros-ec-gyro`；`ro.serialno` 是空的；`/dev/tun` 不存在，`/dev/net/tun` 指到一个不存在的节点；`pm.dexopt.boot-after-ota` 是 `verify`；`debug.hwui.renderer` 是 `skiagl`。同一段 logcat 里有 `AddTidToCgroup failed to write ... Permission denied`。

下面「拿来」是改动可以直接落到这棵设备树，频率、节点和补丁目标都对得上。「借鉴」是现象同类，补丁本身不能原样打。「已有」是这台机器现在已经是那个状态。「不用」是另一套硬件、另一套安装方式，或者当前 lunch 根本走不到。

## 索引

| 提交 | 在 Kukui 上做什么 | 对 Gru |
|---|---|---|
| `b9175a8` | 导出 `pm_set_mem_sleep`，给 USB 睡眠补丁用 | 不用 |
| `12eb743` | 关掉压缩 APEX | 拿来 |
| `386f27b` | 重写 DRM `SET_MASTER` | 已有 |
| `7465cfb` | 打开 `CONFIG_DMABUF_HEAPS_SYSTEM` | 已有 |
| `249ab61` | EC 光线传感器 HAL | 不用 |
| `6526f4b` | HWUI 在 GL 上预旋转，属性默认关 | 拿来 |
| `73c4903` | CCI 频率接口，以及 cgroup v1 写进程需要 `CAP_SYS_NICE` | CCI 不用，cgroup 借鉴 |
| `2f60951` | SVS 在 auxadc 校准前先关掉 OPP | 不用 |
| `ac44fef` | 安装器：分区按已用范围写入 | 不用 |
| `b7ed7de` | CCI 的 OPP 也进 SVS 温区 | 不用 |
| `b94297e` | Panfrost 跟着 SVS 的 OPP 开关走 | 不用 |
| `736d92a` | Kukui 的编译和安装说明 | 不用 |
| `d9cbef0` | `vendor.hwc.drm.scale_with_gpu=true` | 拿来 |
| `b53e50e` | MDP3 旋转、MM21、OVL 带宽 | 不用 |
| `2815d72` | 把 `mtk-mdp3.ko` 编进内核 | 不用 |
| `5e0cc3f` | 解码器输出改成 MM21 | 不用 |
| `c91f3e0` | MDP3 补上 270° 旋转 | 不用 |
| `be4af95` | 放进编好的 `mtk-mdp3.ko` | 不用 |
| `8b99860` | 内核换到 6.18.62 | 不用 |
| `8ceb40f` | 合并提交 | 不用 |
| `3b51904` | 调试、RTC、镜头电源、电池、Type-C | 不用 |
| `a9706cd` | 合盖唤醒、深睡、镜头、开机日志 | 不用 |
| `bcc64e1` | OVL 最小宽度、H.264 两路、SELinux | 最小宽度不用，两路借鉴 |
| `7f6d160` | 序列号、BTF、`INET_DIAG_DESTROY`、SELinux | 序列号借鉴，诊断销毁已有 |
| `7814fe5` | 内核 6.18.63，以及热点统计用的 netfilter 模块 | 版本不用，模块名单借鉴 |
| `5067807` | 安装器：写 eMMC 前先备份 | 不用 |
| `fc5ee05` | 电源、ondemand、壁纸缩放、AOT、tun、着色器缓存 | 拆开，见下文 |
| `fccfd18` | 他们的 USB 睡眠和 cmdline 记录 | 不用 |
| `174c947` | `trunk_staging` 上 Firefox 的 MessageQueue | 不用 |

## 建议拿来

显示和 `tun` 各自做一个 `super`，刷卡看完再做下一项。内核分区先不动。压缩 APEX 和 `boot-after-ota` 不单独占一次写卡：当前没有 OTA，写卡要拔下来在 PC 上写，或者从 eMMC 里的 postmarketOS 写。

### 1. HWUI 在 GL 上预旋转（`6526f4b`）

补丁打在 `frameworks/base`，属性 `debug.hwui.gl_prerotation` 默认关。Kukui 打开之后，图层的 `bufferTransform` 从 `270` 变成 `0`，OVL 才能直接扫出。Gru 的面板是竖屏 `1536x2048`，VOP 做不了 90°，`bugs.md` 里记录的图层是 `CLIENT + ROT_90`，合成落在 GPU 上。预旋转要解决的就是这一层：缓冲先转成和面板扫描方向一致，VOP 只做 0° 扫出。

补丁可以打到同一棵 Lineage 树上。属性名是 `debug.hwui.gl_prerotation`，不设置就是关。补丁跟着窗口的 transform hint 走，90° 和 270° 都有对应矩阵。这次先关着编进去，刷卡后看当前方向，再打开。渲染器保持 `skiagl`。AFBC 和源矩形不在原点的问题还在，预旋转只拿掉旋转这一项。

实现笔记：

2026-11-14。补丁是 `patches/frameworks_base_hwui_gl_prerotation.patch`，`apply-patches.sh` 会打到 `frameworks/base`。`init.gru.rc` 不设置 `debug.hwui.gl_prerotation`，源码里的默认值是 false。

Kukui 刚编过这棵共享树。编 Gru 之前先 `--reverse` 了 Kukui 的音频、MDP3 色彩转换、解码器、v4l2r、codec2、healthd 和 codec2 flush。healthd 和亮度那两份补丁与 Gru 自己的是同一份，留着。MDP3 旋转、合盖唤醒、panvk 的 HOST_CACHED 也撤了。Kukui 的 DSI CRTC 补丁比 Gru 的宽 VOP 选择多一段 RGB 平面拒绝缩放，整份撤掉后把 `external_drm_hwcomposer_prefer_wide_crtc.patch` 重新打上。`last_picture` 还在。`external_libcamera_rkisp1_camera_hal.patch` 正向检查没有缺的 hunk，28 处都是已经在树上；它上面的预览帧率和热机补丁可以整份反向核对。`hardware_interfaces_audio_usb_alsa_sync_io.patch` 里 USB 和 ALSA 那几份已经在，`StreamPrimary.cpp` 上的 3 个 hunk 和 `ModulePrimary.h` 对不上，是因为耳机孔、麦克风、HDMI 这三份后来的补丁改过同一处，而且这三份可以整份反向核对。两份都没有强打。

lunch 是 `lineage_gru-bp4a-userdebug`。`m superimage` 在 2026-11-14 01:46 完成。`super.img` 1,285,599,636 字节，SHA-256 `3fada7848d4b313a185b6e86defb610f05774f68673d582f49e02b23783df7d4`。`lpmake` 的 super 设备大小是 8,589,934,592。`system/lib64/libhwui.so` 里有 `debug.hwui.gl_prerotation`。vendor 里的 `init.gru.rc` 只有注释，没有把它设成 true。`mapper.minigbm_upstream.so` 还在。内核分区没有换。

刷进去之后行为应和现在一样。看过方向之后，用 `setprop debug.hwui.gl_prerotation true` 再重启 zygote 才能打开；这个属性不进 init，重启整机会回到关闭。

事件：

2026-11-14 02:00，`10.0.0.116`，`ro.build.date` 是 Sat Nov 14 01:12:33 EST 2026。属性为空，`debug.hwui.renderer=skiagl`，`user_rotation=1`。显示 `ROTATION_90`，壁纸、桌面、状态栏、任务栏的 `bufferTransform` 都是 `ROT_90`，`usesClientComposition=true`，`usesDeviceComposition=false`。和关着预旋转时的预期一致。

随后 `adb root`，`setprop debug.hwui.gl_prerotation true`，`stop`/`start`。logcat 里没有 `GL pre-rotation` 失败。四个方向都转过，最后停回 `user_rotation=1`。桌面、状态栏、任务栏在 0/90/180/270 的 `bufferTransform` 都是 0，缓冲尺寸换成了面板方向。壁纸没有跟着走：0° 是 0，90° 是 `ROT_90`，180° 是 `ROT_180`，270° 是 `ROT_270`，源矩形也不在原点。四个方向都仍然是整帧 `CLIENT`，没有 `DEVICE` 平面。这次开机属性还是 true，重启整机会关掉。

### 2. 缩放图层走 GPU（`d9cbef0`）

`vendor.hwc.drm.scale_with_gpu=true`。一行属性。合成器在 `ResourceManager` 构造时读一次。Kukui 上需要缩放的图层走 GPU 之后，失败的测试提交从大约 170 降到 0，任务栏进过平面。

实现笔记：

2026-11-14。没有改 `device.mk`，也没有新的 `super`。正在运行的 `drm_hwcomposer` 已经会读这个属性，默认是 0。`setprop vendor.hwc.drm.scale_with_gpu true` 之后重启了 `vendor.hwcomposer-3`（pid 8976），预旋转仍是 true。

事件：

2026-11-14 02:19，`10.0.0.116`，锁屏已关，焦点是桌面，`user_rotation=3`（`ROTATION_270`）。属性打开后，壁纸仍是 `ROT_270`、源矩形 `[93, 325, 1955, 1722]`，桌面、状态栏、任务栏的 `bufferTransform` 是 0。四层都是 `CLIENT`，`usesDeviceComposition=false`。桌面和壁纸的缓冲是 AFBC（modifier `576460752303423569`），状态栏 `46x2048` 和任务栏 `167x2048` 是未压缩的 AB24。

这次 composer 启动之后，logcat 里 `Test-only` 有 276 次 `ret=-22`（EINVAL），没有 `ret=-34`（ERANGE），另有 11 次 `Failed to create DrmKmsPlan`。把属性设回 false 并再次重启 composer 之后，同样是整帧 `CLIENT`，3 秒内没有新的 `drmhwc` 测试提交日志。属性现为 false。预旋转的 `setprop` 还在，重启整机会关掉。没有写卡。

四个方向的 `bufferTransform` 已经量过。下一份镜像在 `init.gru.rc` 里把 `debug.hwui.gl_prerotation` 设成 true。

### 一帧一块 AFBC

VOP 一次只能扫一块 AFBC。原先的打算是带 `HW_TEXTURE` 的窗口保持线性，只有帧缓冲走 AFBC。量过之后没有平面，补丁已退回，不进下一份镜像。

实现笔记：

2026-11-14。在 `rockchip_afbc_ok` 里看到 `BO_USE_TEXTURE` 就分配线性缓冲。`cros_gralloc_driver::allocate` 只在驱动名是 `rockchip`、usage 含 `GRALLOC_USAGE_HW_FB` 且不含 `GRALLOC_USAGE_HW_TEXTURE` 时清掉 `BO_USE_TEXTURE`。库编出来之后 bind 到正在运行的 `libminigbm_gralloc_upstream.so` 上，分配器进程实际映射的是 apex 里的那份，两处都换过，然后重启了 `vendor.graphics.allocator.minigbm_upstream`。没有新的 `super`。测完把 bind 卸掉，补丁文件退回这次测试之前。

事件：

2026-11-14 02:40，`10.0.0.116`，预旋转 true，`scale_with_gpu` false，焦点是桌面。桌面 usage `0xb00`，从 AFBC 12491 KiB 变成线性 12299 KiB，modifier 0。壁纸 `2048x2048` 同样变成线性。帧缓冲 usage 是 `0x1b00`，里面已经带 `HW_TEXTURE`，所以「没有 TEXTURE 才压缩」这条没有选中它，帧缓冲也变成线性，12299 KiB。四层仍是 `CLIENT`，`usesDeviceComposition=false`。壁纸仍是 `ROT_270`，源矩形 `[93, 325, 1955, 1722]`。

`drm_hwcomposer` 的 `Backend::IsClientLayer` 不看旋转。壁纸带着 `ROT_270` 去参加平面分配，`DrmPlane::IsValidForLayer` 在 VOP 上拒掉旋转，`CreateDrmKmsPlan` 返回空，然后整帧被压成客户端。这和缓冲是不是 AFBC 无关。壁纸 `config_wallpaperMaxScale=1.0` 去不掉 90° 和 270° 的旋转，所以不再接着做那一项。

同一天稍后把规则改成：usage 带 `GRALLOC_USAGE_HW_FB` 就清掉 `BO_USE_TEXTURE`，窗口保持线性，只有帧缓冲走 AFBC。合成器在 `vendor.hwc.drm.client_unsupported_transform=true` 时，把平面扫不了的旋转图层交给 GPU。设置页当时已经是 `DEVICE`：那几层高度不对齐 16，本来就是线性的，壁纸也不在输出里。往正在运行的系统上覆盖合成器并重启 `vendor.hwcomposer-3`，机器两次离开网络，电源短按没有反应。覆盖的做法停用。这两项改动放进下一份 `super`，属性在 `init.gru.rc` 里打开。

实现笔记：

2026-11-14 09:04。`m superimage` 完成。`super.img` 1,285,599,636 字节，SHA-256 `8bc6496f00b6bbcf543ebfc4d896204efcd3288f7709bbd7c0fd5cab65e3093a`。`lpmake` 的 super 设备大小是 8,589,934,592。`init.gru.rc` 设置 `debug.hwui.gl_prerotation true` 和 `vendor.hwc.drm.client_unsupported_transform true`。`scale_with_gpu` 没有设置。上一份 `super` 留在 `super.img.3fada784`。全量包是 `lineage-23.2-gru-20261114.zip`，1,059,857,274 字节，SHA-256 `57cd0e9354579e31dad7d952be27722fa7493204fb8c4ca2aee488b567c51e00`。包里的 `vmlinuz.kpart` 是同一份 6.6.34-phase2 重新打包，SHA-256 `fd04d96656d5ba822ce8f480bce9d31b1d8d3a078d737db5d93a5ce6e36d6e3e`。从 postmarketOS 写卡只换 `super`。

事件：

2026-11-14 09:12 起，`10.0.0.110`，`ro.build.date` 是 Sat Nov 14 09:02:50 EST 2026。`debug.hwui.gl_prerotation=true`，`user_rotation=3`。`vendor.hwc.drm.client_unsupported_transform` 不在 `property_contexts` 里（那里只有 `vendor.hwc.drm.device` 一条精确匹配），所以它落在 `vendor_default_prop`。普通 shell 读它会 `Access denied finding property`，`getprop` 是空的。`adb root` 之后能读到 `true`。合成器域可以读 `vendor_default_prop`，开关由它生效。

分配结果：壁纸 `2048x2048` 线性 16395.11 KiB，modifier 0。桌面 `1536x2048` usage `0xb00`，线性 12299.11 KiB。状态栏 `46x2048` 线性 523.11 KiB，任务栏 `167x2048` 线性 1547.11 KiB。`FramebufferSurface` usage `0x1b00`，AFBC 12491.11 KiB，modifier `576460752303423569`。

停在桌面超过一秒时，`FlatteningController` 把整帧收成 `CLIENT`，`usesDeviceComposition=false`。这是空闲后的那一帧，测试提交失败计数停在 43。切到设置再回桌面，画面还在更新时：壁纸 `ROT_270`、源矩形 `[93, 325, 1955, 1722]`，`CLIENT`；桌面 `bufferTransform=0`，也是 `CLIENT`；状态栏和任务栏是 `DEVICE`。`usesDeviceComposition=true`。RK3399 大 VOP 是 1 个 primary、2 个 overlay、1 个 cursor。可用平面是前三个，客户帧缓冲占一个，剩下两个给状态栏和任务栏。壁纸必须进客户范围，客户范围又要按 z 序连在一起，所以夹在中间的桌面跟着进 GPU。设置页没有壁纸，窗口、状态栏都是 `DEVICE`。

把属性设成 false 再走一遍，桌面四层都是 `CLIENT`，主屏测试提交失败计数从 43 增到 71。设回 true 之后，更新中的桌面又是壁纸和桌面 `CLIENT`、状态栏和任务栏 `DEVICE`。属性留在 true，`init.gru.rc` 里也是 true，重启后由 init 再设。没有换内核分区。画面内容要人看。

### 3. 把 tun 放进 vendor（`fc5ee05` 里的模块，用 6.6 自己编）

`.config` 里 `CONFIG_TUN=m`，模块没有打进镜像。`/dev/tun` 不存在，`/dev/net/tun` 是断的符号链接，VPN 起不来。用 6.6.34-phase2 编出来的 `tun.ko`，按 `ath10k` 的方式放进 `modules.mk` 并在 `init.gru.rc` 里 `insmod`。不要用 Kukui 那个 6.18 的 `.ko`。

`modinfo` 的 vermagic 必须是 `6.6.34-phase2`。加载后再看 `/dev/tun` 是否出现。

实现笔记：

2026-11-14。运行中的内核是 6.6.34-phase2，`/proc/config.gz` 里 `CONFIG_TUN=m`。`tun.ko` 用 `/home/alpha/src/gru-phase2/linux-6.6.34` 重新编，vermagic 是 `6.6.34-phase2 SMP preempt mod_unload modversions aarch64`，SHA-256 `6085b34bcdb13b141906da25e8e4264b36e3767e856ef3ac8b00f413ece580de`。在当前系统上 `insmod` 之后，dmesg 是 `tun: Universal TUN/TAP device driver, 1.6`。`/dev/tun` 是 `10,200`，属主 `system:vpn`，标签 `u:object_r:tun_device:s0`，打开成功。`/dev/net/tun` 仍指向 `../tun`。模块放在 `/vendor/lib/tun.ko`，`device.mk` 按 `af_key.ko` 拷贝，`init.gru.rc` 在 early-init 里 `insmod`。ramdisk 的 `modules.mk` 会进内核分区，这次没有改它。`super.img` 1,285,661,076 字节，SHA-256 `fb66d2e04ebce9a9acfba36f92b6a0e5d376a9732057db927ca714b08f9faf4d`。镜像里的两个 `.ko` 和上面的哈希一致。内核分区没有换。

事件：

2026-11-14 13:50，`10.0.0.103`，`ro.build.date` 是 Sat Nov 14 13:21:38 EST 2026。`/vendor/lib/tun.ko` 的 SHA-256 与上面一致。开机后 6.3 秒 dmesg 是 `tun: Universal TUN/TAP device driver, 1.6`。`/dev/tun` 是 `10,200`，属主 `system:vpn`，标签 `u:object_r:tun_device:s0`。v2rayNG 连上一个香港节点。13:44:06 内核记录 `tun0` 在传 TCP。13:44:49 `DnsManager` 把 `1.1.1.1` 配到 `tun0`，netId 101。13:49:16 VPN 关掉，`tun0` 被删除。无线 adb 还在。

### 4. 关掉压缩 APEX（`12eb743`）

`device/google/gru/device.mk` 加 `PRODUCT_COMPRESSED_APEX := false`。Kukui 上第一次开机要在 microSD 上解压 14 个 APEX，解压完系统才起来。Gru 也是从外部卡启动，`super` 同样是 8 GiB、不稀疏化。Kukui 关掉之后分组占用从 22.6% 降到 15.8%，离 4 GiB 上限还远。

这项只在清空 userdata 之后的第一次开机省时间。平时写卡只换 `super`，已经起来的系统看不出差别，不值得单独拔卡。等到某次本来就要重做 userdata，或者打包分发镜像时再带上。带上之后看第一次开机的时间，以及 `super.img` 仍是 `8,589,934,592` 字节。`/data/apex/decompressed` 应保持为空。

实现笔记：

事件：

### 5. 更新后用 speed-profile（`fc5ee05` 里的这一行）

`PRODUCT_SYSTEM_PROPERTIES += pm.dexopt.boot-after-ota=speed-profile`。现在这台是 `verify`。当前没有 OTA，写卡也不会走 `boot-after-ota`，所以单独做这一项没有可测的结果。属性可以以后和某次 `super` 一起放进去，不单独写卡。

实现笔记：

事件：

## 建议借鉴

这些不要把 Kukui 的补丁或 JSON 原样打进来。

### cgroup v1 写进程需要 `CAP_SYS_NICE`（`73c4903` 的后半）

2026-11-14 00:45 的 logcat：

```
libprocessgroup: AddTidToCgroup failed to write '3519'; path=foreground; process: Permission denied
```

`/dev/cpuset` 已经挂着，里面有 `foreground` 和 `background`。Kukui 的补丁是 6.18 的 `kernel/cgroup/cgroup.c`：cgroup v1 的 `tasks` 文件允许持有 `CAP_SYS_NICE` 的进程把别的线程移进去。6.6.34 要对照同一处再写，不能直接打那一版。这一项要动内核镜像，放在上面几项用户空间改动都看过之后。`Module.symvers` 的 CRC 不能变。

同一笔提交里的 `mtk-cci` 频率接口是 MT8183 的，不要带过来。

实现笔记：

2026-11-14。6.6.34 的检查在 `kernel/cgroup/cgroup-v1.c` 的 `__cgroup1_procs_write`。补丁是 `patches/kernel_6.6.34_cgroup_v1_cap_sys_nice.patch`：root、任务自己的 uid、suid 之外，持有 `CAP_SYS_NICE` 也可以写。`mtk-cci` 没带。新 `Image` SHA-256 `0c89417d14fe44582a644148dfed962b8e4c11da0186f0b1e8590f1bc836d7e2`，版本字符串仍是 `6.6.34-phase2`。对照新 `vmlinux` 里的 `__crc_*`，原有 12062 个导出 CRC 没有变，多出来的只有 `coreboot_driver_register` 和 `coreboot_driver_unregister`。`panfrost.ko`、`tun.ko`、`sch_ingress.ko` 的哈希没变。`vmlinuz.kpart` 14,090,240 字节，SHA-256 `55cb9c5309157a0b0ed12412f08000a8751842b2002e0a31b999d713a3c64668`。

事件：

2026-11-14 14:16，`10.0.0.110`。`/proc/version` 是 `6.6.34-phase2 #6 SMP PREEMPT Sat Nov 14 14:02:27 EST 2026`。`ro.build.date` 仍是 Sat Nov 14 13:21:38 EST 2026，`super` 没换。开机 3 分钟的 logcat 里 `AddTidToCgroup failed` 是 0 条。`system_server`（pid 3319）在 `cpuset:/foreground`，桌面（pid 3872）也在 `cpuset:/foreground`。`panfrost`、`tun`、`sch_ingress`、`ath10k_pci` 都已加载。`wlan0` 是 UP。`/dev/tun` 仍在。

### 电源提示按 RK3399 重写（`fc5ee05` 的 perfmgr，不是那份频率表）

Kukui 的 `powerhint.json` 是 A73/A53 的 1248/1716 MHz 和 Mali-G72 的 653 MHz，还有 CCI。Gru 是 A72/A53 和 Mali-T860，频率表不能抄。他们还把调速器改成 `ondemand` 并设 `up_threshold=80`、`io_is_busy=1`。这台现在是 `schedutil`，保持它。

值得做的是 `android.hardware.power-service-gru` 加上一份按 RK3399 时钟写的 `powerhint.json`，让交互、启动和相机能抬频率。`powerhint.json` 必须是普通文件。Kukui 曾经把它做成符号链接，`prebuilt_etc` 跟到了宿主机路径，电源 HAL 读到空配置就退出，`system_server` 卡在 `PowerManagerService`，开机动画都没有。

cgroup 迁移修好之前，后台绑小核的提示不会生效。

实现笔记：

2026-11-14。`device.mk` 和 `BoardConfig.mk` 在 `options.mk` 之前设 `TARGET_POWER_HAL := perfmgr-lineage`。公共 makefile 还会装名为 `powerhint.json` 的模块，那个名字已经是 Kukui 的表，`mainline_common.mk` 在 `device.mk` 里的过滤之后才把它加回来，两份文件不能占同一个安装路径。Gru 的表拷成 `/vendor/etc/powerhint-gru.json` 普通文件。`init.gru.rc` 在 `early-init` 写 `vendor.powerhal.config=powerhint-gru.json`，电源 HAL 在 `late-fs` 才启动，读的是这个名字。Kukui 那份文件仍会留在 `/vendor/etc/powerhint.json`，HAL 不读它。调速器仍是 `schedutil`，不改 `scaling_governor`，也不改最高频率。当前这台的表：小核 policy0（CPU 0–3）600000–1512000，大核 policy4（CPU 4–5）816000–2016000，GPU `ff9a0000.gpu` 200000000–800000000。默认索引是空闲最低值，`ResetOnInit` 为真，提示结束会写回去。`INTERACTION` 把小核最低抬到 1200000、大核 1608000、GPU 500000000，时长 0，用框架给的时长。`LAUNCH` 维持 3000 ms，小核 1512000、大核 2016000、GPU 800000000。`CAMERA_STREAMING_MID` 和 `CAMERA_STREAMING_HIGH` 把小核最低抬到 1200000、大核 1800000、GPU 600000000，直到模式结束。后台和 system-background 的 cpuset 写成 `0-3`，`AllowFailure` 为真。前台和 top-app 仍是 `0-5`。同一条 adb 上先写过再恢复：小核 1200000 回到 600000，大核 1608000 回到 816000，GPU 500000000 回到 200000000，background cpuset `0-3` 回到 `0-5`。GPU 节点已经是 `sysfs_gpu`，libperfmgr 的策略已经允许电源 HAL 写它和 CPU sysfs、cgroup。内存控制器的频率没有写进这份表。`super.img` 1,285,489,044 字节，SHA-256 `dfe965c36f1cd8f90317303f51ac40dd694effcba463be03d2ae1a9da9baaa1e`。`ro.build.date` 是 Sat Nov 14 14:31:17 EST 2026。已写入。

事件：

2026-11-14 14:51，`10.0.0.110`，`ro.build.date` 是 Sat Nov 14 14:31:17 EST 2026。`vendor.power-hal-aidl` 从 `late-fs` 起一直在跑，pid 2729，域 `hal_power_default`。`vendor.powerhal.config` 是 `powerhint-gru.json`，这个文件是普通文件，2263 字节。`dumpsys` 里四个节点的当前值是小核 600000、大核 816000、GPU 200000000、后台 cpuset `0-3`。`schedutil` 没变。`setBoost(INTERACTION, 1500)` 期间是 1200000、1608000、500000000，两秒后回到 600000、816000、200000000。`setMode(LAUNCH)` 期间是 1512000、2016000、800000000，关掉后回到同样的空闲值。`setMode(CAMERA_STREAMING_HIGH)` 期间是 1200000、1800000、600000000，关掉后也回到空闲值。background 里有 553 个任务，其中一个的 `Cpus_allowed_list` 是 `0-3`。system-background 有 48 个任务，其中一个也是 `0-3`。foreground 里抽到的任务是 `0-5`。top-app 的掩码仍是 `0-5`。

### 壁纸最大缩放改成 1.0（`fc5ee05`）

默认 `config_wallpaperMaxScale` 是 1.1，壁纸动画会把这一层放大。放大后的图层进不了平面，整帧更容易退回 GPU。Gru 的 AFBC 还要求源矩形从原点开始，壁纸经常不是。平面已经能扫出之后，再把 overlay 里的这个值改成 `1.0`，看壁纸层是不是不再挡住别的平面。这个动画会消失，要单独看一眼。

实现笔记：

2026-11-14。`overlay/frameworks/base/core/res/res/values/config.xml` 把 `config_wallpaperMaxScale` 设成 1.0。`super.img` 1,285,599,636 字节，SHA-256 `814c709fd7dc2c43e834934e6db44da9d7b5b3be904fa4bf416a97a8809d105e`。已写入卡。开机后的测量见下面的事件。

事件：

2026-11-14 10:19，`10.0.0.110`，`ro.build.date` 是 Sat Nov 14 10:07:44 EST 2026。`framework-res.apk` 里这个值仍是 1.1。生效的是 `/vendor/overlay/framework-res__lineage_gru__auto_generated_rro_vendor.apk`，`cmd overlay` 显示已启用，`dimen/config_wallpaperMaxScale` 映射到 1。应用抽屉划出时 `mLastWallpaperZoomOut` 一直是 0，壁纸缩放没有参与这段动画。划出过程中完成时间 43–105 ms，GPU 完成 15–63 ms，当时 GPU 已经在 800 MHz。划入只有少数帧超过 40 ms。体感没有明显变化和这个测量一致。

### GPU 忙闲时间按 200% 报给调速器

`simple_ondemand` 只有忙闲比超过 45% 才去 800 MHz。一帧里 CPU、GPU、合成器串着走，滑动时这个比例不够，频率掉回 200 MHz。`patches/kernel_6.6.34_panfrost_devfreq_busy_scale.patch` 在交给调速器之前把 `busy_time` 乘 `busy_scale / 100`，默认 200，封顶不超过整个采样窗口。没有作业时仍是 0。参数在 `/sys/module/panfrost/parameters/busy_scale`。vermagic 仍是 `6.6.34-phase2`，`Module.symvers` 的 CRC 没变。`panfrost.ko` SHA-256 `67feeee0fae57f18d5a52d10322eaf1cd303ad71100337f97717a62f8624c9f4`。

`super.img` 1,285,599,636 字节，SHA-256 `3afc75c7816926d7d81e0efaea5f71dbd0380d06845e0de0a7e6c722604c3330`。`lpmake` 的 super 设备大小是 8,589,934,592。内核分区没有换。

事件：

2026-11-14 10:03，`10.0.0.110`，`ro.build.date` 是 Sat Nov 14 09:53:34 EST 2026。`busy_scale=200`。桌面横滑时 GPU 从 200 MHz 升到 800 MHz，并在整段滑动里停在 800 MHz。这一滑的帧完成时间中位数 77 ms（改之前同一滑法是 97 ms），GPU 完成时间中位数 20 ms（改之前 41 ms），和当时把最低频率钉在 800 MHz 的 21 ms 一致。画命令中位数 19 ms，取缓冲中位数 11 ms。停下之后频率会回到 200 MHz，桌面上还有周期性的 GPU 工作时又会升回 800 MHz。画面内容要人看。

### 热点统计用的 netfilter 模块（`7814fe5` 的名单）

`netd` 为热点计数会加载 `xt_TCPMSS`、`xt_NFLOG`、`sch_ingress`、`cls_bpf`、`act_bpf`。Gru 的 `modules.mk` 里没有这些。主线上也没有 Android 的 `xt_quota2`，和 Kukui 一样，配额计数不用指望。用 6.6.34 把名单里有的模块编出来放进 ramdisk，再看热点的流量统计。内核版本号不要跟着他们升。

实现笔记：

2026-11-14。运行内核的 `/proc/config.gz`：`CONFIG_NETFILTER_XT_TARGET_TCPMSS=y`，`CONFIG_NETFILTER_XT_TARGET_NFLOG=y`，`CONFIG_NET_CLS_BPF=y`，`CONFIG_NET_ACT_BPF=y`，`CONFIG_NET_SCH_INGRESS=m`。前四个已经在 11 月 5 日的内核镜像里。`iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1400` 和随后的 `-D` 都返回 0。`sch_ingress.ko` 用同一棵 6.6.34 树编，vermagic 与 `tun.ko` 相同，SHA-256 `a4e38bc14e1343691304388f97ee89e5d2153e66871404b1bad463c8345b123b`。`insmod` 之后 `tc qdisc add dev lo ingress` 能看到 `qdisc ingress`，随后删掉。`modprobe sch_ingress` 仍然失败，它去扫 `/lib/modules`，这个根文件系统没有这个目录。所以和 `tun.ko` 一样放进 `/vendor/lib`，由 `init.gru.rc` 提前加载。qdisc 已经注册时，内核找得到它，不会再调 `modprobe`。主线上没有 `xt_quota2`。和 `tun` 进同一份 `super`。

事件：

2026-11-14 13:50，同一台、同一份 `super`。`/vendor/lib/sch_ingress.ko` 的 SHA-256 与上面一致。`wlan0` 上已经挂着 `qdisc clsact`，模块引用计数是 1。开机 13:38 `/sys/fs/bpf/tethering` 里就钉着 `map_offload_tether_stats_map` 以及上下行的 `schedcls` 程序，`/sys/fs/bpf/netd_shared` 里有 `prog_netd_schedact_ingress_account`。临时链上 `NFLOG` 和 `TCPMSS --set-mss 1400` 都能加上再删掉。没有接客户端去数共享流量。

这台没有基带。ath10k 的接口组合里，AP 和 station 同时存在的一组要求 `#channels <= 1`。设置里的热点用的是同一块网卡，打开会停掉正在用的 Wi-Fi。没有为了这项去打开热点。USB 或蓝牙共享仍可以用 Wi-Fi 当上游，这次没测。

### 序列号从 VPD 读出来（`7f6d160` 的设备树部分）

这台的 `ro.serialno` 是空的。Kukui 的改动是 `mt8183-kukui.dtsi` 里固件节点的 `#address-cells` 和 `#size-cells`，让 `coreboot_table` 能读 VPD。Gru 要改的是 RK3399 的固件节点，不能打那份 dtsi。`INET_DIAG_DESTROY` 在当前 `.config` 里已经是 `y`。BTF 和 fs-verity 先不动。

实现笔记：

2026-11-14。6.6 上 `/firmware` 没有 `#address-cells`，子节点的 `reg` 仍然按根节点的 2/2 解析出来了。平台设备是 `f7eda000.coreboot`。`System RAM` 收到 `f7dfffff`，PCIe 从 `f8000000` 开始，这 2 MB 的空隙里没有别的映射。表头签名是 `LBIO`，`header_bytes` 24，`table_bytes` 876，一共 900 字节，和 `reg` 的第一段一样大。VPD 在 `0xf7ffe940`，magic `0x43524f53`，只读 275 字节，可写 348 字节，结尾 `0xf7ffebbf`，还在 PCIe 窗口下面。没有改设备树的 cell。`CONFIG_GOOGLE_FIRMWARE`、`CONFIG_GOOGLE_COREBOOT_TABLE`、`CONFIG_GOOGLE_VPD` 编进内核。`CBMEM`、memconsole、coreboot framebuffer 没开。当前这次启动上用模块加载过，`/sys/firmware/vpd/ro/serial_number` 是 `NXH0BAA0018300CD207600`。`board-id` 是 5，`sku-id` 是 7。`scripts/gru-ids.sh` 在属性还空的时候写 `ro.serialno`。这次启动上手动跑过，两个属性变成 `NXH0BAA0018300CD207600` 和 `rev5 sku7`。那次是 root 直接 `setprop`。脚本在随后的 `super` 里，不在这份 `kpart` 里。

2026-11-14。脚本改成只写 `ro.serialno`，不再调用 `getprop`。`ro.boot.hardware.revision` 是 `exported_default_prop`，策略只允许 `init` 和 `vendor_init` 设置。`serialno_prop` 的文件读取也只允许 `adbd`、`shell`、`system_server`、`vendor_init` 等少数域。`set_prop` 宏会带上这次读取，所以只留了属性套接字和 `property_service set`。`setprop` 对还没写过的 `ro.*` 可以成功一次。服务改成直接执行 `/vendor/bin/gru-ids.sh`，域是 `gru_ids`。`genfscon` 只标 `/sys/firmware/vpd/ro/serial_number` 为 `vendor_sysfs_vpd_serial`，VPD 里其余文件仍是普通 `sysfs`。`file_contexts` 把脚本标成 `gru_ids_exec`。之前那次手动 `setprop` 是 root，重启后没有留下来。和电源提示进同一份 `super`，哈希见上一节。已写入。

事件：

2026-11-14 14:16，同一台、同一份内核。`f7eda000.coreboot` 绑在 `coreboot_table` 上。root 读 `/sys/firmware/vpd/ro/serial_number` 是 `NXH0BAA0018300CD207600`。普通 shell 读这个节点会被 SELinux 拒绝。`ro.serialno` 和 `ro.boot.hardware.revision` 仍是空的，`gru-ids.sh` 还没进当前的 `super`。

2026-11-14 14:51，同一台、上面那份 `super`。`gru-ids` 在 14:48:15 启动，pid 2718，0.082 秒后以状态 0 退出。`ro.serialno` 是 `NXH0BAA0018300CD207600`。`ro.boot.hardware.revision` 仍是空的。`serial_number` 的标签是 `vendor_sysfs_vpd_serial`，VPD 里其余文件仍是 `sysfs`。shell 读序列号和其余 VPD 文件都被拒绝。没有 `gru_ids` 的拒绝记录。

### H.264 同时两路（`bcc64e1` 里的 XML）

`media_codecs_c2_cros.xml` 把 H.264 的 `concurrent-instances` 从 1 改成 2。Kukui 测过两个软件解码器可以同时跑。Gru 的解码器是 rkvdec，一路 720p60 的 VP9 刚修过 `last_picture`。两路要等单路稳定之后再改，并且只改实例数，不改输出格式。同一笔提交里把 MT8183 OVL 最小帧缓冲从 64 改成状态栏宽度，那是另一块显示控制器，不要带。

实现笔记：

2026-11-14。`device/google/gru/etc/media_codecs_c2.xml` 里 `c2.v4l2.avc.decoder`、`c2.v4l2.vp8.decoder`、`c2.v4l2.vp9.decoder` 的 `concurrent-instances` 已经是 8。Kukui 那一笔是从 1 改成 2。这次没有改这份 XML，`last_picture` 也没动。两路解码还没跑。

事件：

## 不用

这些和 RK3399、Scarlet、或者当前的启动方式对不上。

- `b9175a8`：`pm_set_mem_sleep` 只被他们的 `mtu3` 睡眠补丁调用。Gru 的 6.6 里没有这处调用，`mem_sleep` 已经是 `deep`。
- `386f27b`：Gru 已经有 `patches/kernel_6.6.34_drm_master_and_fbdev_emulation.patch`，画面在用。不要换成他重写的那一版。
- `7465cfb`：`.config` 里 `CONFIG_DMABUF_HEAPS_SYSTEM=y`，`/dev/dma_heap/system` 已经是设备节点。
- `249ab61`：Scarlet 的设备树没有光线传感器，`sensorservice` 里也没有。Krane 的 lux 曲线和 HAL 都不要搬。
- `73c4903` 的 CCI、`2f60951`、`b7ed7de`、`b94297e`：整条链是 MT8183 的 SVS、auxadc 和 CCI OPP。Panfrost 跟着 SVS 开关 OPP 的通知，在没有这块调压硬件时没有对象。
- `b53e50e`、`2815d72`、`5e0cc3f`、`c91f3e0`、`be4af95`：MDP3 和 MM21。Gru 没有 `mtk-mdp3`，解码是 rkvdec 的 NV12。90° 旋转的问题用上面的 HWUI 预旋转，不靠这块 IP。
- `8b99860`、`7814fe5` 的版本、`8ceb40f`：内核停在 6.6.34-phase2。升到 6.18 不在这次范围里。
- `736d92a`、`fccfd18`：路径、安装步骤和 cmdline 都是 Kukui 的。
- `ac44fef`、`5067807`：安装器把系统写进内部 eMMC。Gru 只刷外部 SD，不写 `fe330000.mmc`。
- `3b51904`：RTC 被设回 1970 是 MT6358 的。Gru 用的是 `rtc-cros-ec`。镜头挂起掉电是 `dw9768`。电池是 `cros_usbpd-charger`，不是 `sbs-battery`。pstore 和 `PM_DEBUG` 是调试开关，不放进日常内核。
- `a9706cd`：Scarlet 没有盖子。深睡已经是默认。镜头节点对不上。他们拿掉 `drm_client_lib.active=none`、把 `loglevel` 改成 7，是为了在面板上看到内核日志。Gru 的 cmdline 是 `loglevel=4` 和 `drm_kms_helper.fbdev_emulation=0`，开机动画是按这个修的。
- `174c947`：`LegacyMessageQueue` 只在 `trunk_staging` 上默认打开。Gru 的 lunch 是 `bp4a`，Firefox 走不到那条路径。
- `bcc64e1` 和 `7f6d160` 里整份 SELinux 标签：那是 Kukui 的节点和策略。Gru 已经是 enforcing，按自己的 audit 补，不整份搬。
- `fc5ee05` 里关掉 `video4`、以及着色器缓存：`video4` 是他们的测试节点。Gru 没有把 `debug.hwui.use_gpu_shader_cache` 或 `debug.hwui.prime_shader_cache` 设成 false，缓存按系统默认开着。

## 实现和测试顺序

当前没有 OTA。写卡要拔下来在 PC 上写，或者从 eMMC 里的 postmarketOS 写，所以先做刷进去就能在现有 userdata 上看见的项。压缩 APEX 只影响清空数据后的第一次开机，`boot-after-ota` 现在没有触发机会，这两项放到最后，不单独占一次写卡。

一次只进一个 `super`。显示和 `tun` 不动内核分区。cgroup 那一项要换内核镜像，单独做，并先核对 `Module.symvers`。

1. HWUI 预旋转。属性先关着编进去，确认方向后再打开。看 `dumpsys SurfaceFlinger` 里 `bufferTransform` 是否变成 0，以及四个方向和相机预览。
2. `scale_with_gpu`。2026-11-14 在现有系统上试过，没有产生平面，不写进镜像。见上面的事件。
3. 一帧只留一块 AFBC，并且平面扫不了的旋转交给 GPU。第一次在线试验把帧缓冲也变成了线性，没有平面。随后改成只压缩带 `HW_FB` 的帧缓冲，合成器由 `vendor.hwc.drm.client_unsupported_transform` 打开。在线覆盖合成器会让机器离开网络，这两项放进同一份 `super`。2026-11-14 刷卡后量过：更新中的桌面是壁纸和桌面走 GPU，状态栏和任务栏走平面，帧缓冲是唯一的 AFBC。见上面的事件。
4. 壁纸 `config_wallpaperMaxScale=1.0`。拿掉 1.1 倍放大。90° 和 270° 上壁纸自己的旋转还在，所以这一项不是为了让壁纸进平面。`busy_scale` 量过之后，桌面滑动的 GPU 完成时间已经和钉在 800 MHz 时一样，剩下的时间在 UI 线程画命令上。1.1 倍缩放每次重画壁纸都要在 GPU 上做。overlay 改成 1.0，进下一份 `super`。
5. 6.6 的 `tun.ko`。看 `/dev/tun`，再看一个 VPN 能不能起来。
6. cgroup v1 的 `CAP_SYS_NICE`，按 6.6 重写。看 `AddTidToCgroup` 的 Permission denied 是否消失。
7. 按 RK3399 写的 `powerhint.json`，调速器保持 `schedutil`。看交互时大核和 GPU 频率是否抬起来。
8. 热点用的 netfilter 模块。看共享网络的流量统计。
9. 序列号的固件节点。改之前确认不会让 `coreboot_table` 扫到坏内存。
10. H.264 `concurrent-instances=2`。单路 VP9 和 H.264 保持现在的结果，再试两路。
11. 关掉压缩 APEX。跟某次本来就要重做 userdata 或打包分发镜像一起做。看第一次开机时间和 `super` 大小。
12. `boot-after-ota=speed-profile`。有 OTA 之后再测。属性可以夹进别的 `super`，不单独写卡。

2026-11-14 这一批把第 5 项和第 8 项放进同一份 `super`，SHA-256 `fb66d2e04ebce9a9acfba36f92b6a0e5d376a9732057db927ca714b08f9faf4d`。第 10 项的实例数已经是 8，没有改 XML。第 6、7、9、11、12 项这次没做。已写入卡。VPN 见第 3 节的事件，热点模块见对应事件。

2026-11-14 下一批是内核分区：第 6 项的 cgroup，和第 9 项的 `coreboot_table` / VPD。`vmlinuz.kpart` SHA-256 `55cb9c5309157a0b0ed12412f08000a8751842b2002e0a31b999d713a3c64668`。已写入。cgroup 迁移和 VPD 见上面的事件。第 7 项的 `powerhint` 和 `gru-ids.sh` 在随后的 `super`：1,285,489,044 字节，SHA-256 `dfe965c36f1cd8f90317303f51ac40dd694effcba463be03d2ae1a9da9baaa1e`，`ro.build.date` 是 Sat Nov 14 14:31:17 EST 2026。内核分区没有换。已写入。频率、后台 cpuset 和 `ro.serialno` 见上面两节的事件。

2026-11-14 15:00 的分发包是 `lineage-23.2-gru-20261114-2.zip`，1,059,710,397 字节，SHA-256 `076351246a53871f79dcbf055a14f82398a9b699261b1547aa86a2ad932b1998`。原始镜像 11,274,289,152 字节。包里的 `super` 就是上面这份。内核分区重新签名后是 `f04dd6e42ca700170effd69a339f15f07a4be0d471c231b4be7a43251834f542`（14,090,240 字节）。内核 Image 仍是 `0c89417d14fe44582a644148dfed962b8e4c11da0186f0b1e8590f1bc836d7e2`，命令行仍是 `loglevel=4` 和 `androidboot.selinux=enforcing`。上午的 `lineage-23.2-gru-20261114.zip`（`57cd0e93`）还在，那一份对应 09:04 的 super。第 11、12 项留到有 OTA 和 recovery 之后。

显示这条线量到这里。壁纸的 `ROT_90` 仍进 GPU，状态栏和任务栏在画面更新时是平面，帧缓冲是唯一的 AFBC。桌面夹在壁纸和这两条栏中间，客户范围按 z 序连在一起，大 VOP 又只有三个非 cursor 窗口，所以桌面留在 GPU 里。空闲一秒后 `FlatteningController` 仍会把整帧收成一块帧缓冲。壁纸缩放去不掉这个旋转。Rockchip 闭源合成器那条 RGA 旋转路径不接进这棵主线 `drm_hwcomposer`。

2026-11-14 10:28，同一台、壁纸缩放已经是 1.0。应用抽屉划出时用 `atrace gfx` 按线程对过。启动器 UI 线程的 `traversal` 中位数 19 ms，`measure` 和 `layout` 都不到 0.2 ms，`Record View#draw()` 中位数 0.4 ms。真正占时间的是 UI 线程等 RenderThread 的 `postAndWait`（中位数 7 ms），以及 RenderThread 画整块 2048×1536 桌面缓冲（中位数 9 ms）。12 帧里 RenderThread 还在 `waitForBufferRelease` 上等了中位数 10 ms。SurfaceFlinger 的 `drawLayersInternal` 中位数 1.7 ms，`present` 中位数 4 ms。合成器后台的 `AsyncWaitForBuffersSwap` 中位数 14 ms，不在这次 `present` 的调用栈里。抽屉划出时桌面帧开始间隔中位数 22 ms，上屏的 `present` 间隔中位数 33 ms。第 5 项往后的 `tun`、cgroup、`powerhint` 不动这条路径。

同一条轨迹里，慢的一帧 `dequeueBuffer` 停在 `waitForBufferRelease`，12 到 20 ms，上一帧 `present` 结束才返回。那一帧真正画 2048×1536 大约 4 ms。预旋转原来多留 1 块缓冲，盖不住平面上的一块，再加合成后要等到上屏的一块。`CanvasContext::setBufferCount` 在 `debug.hwui.gl_prerotation` 打开时改成多留 2 块。每个 HWUI 窗口多一块缓冲，桌面这一块大约 12 MB。`super.img` 1,285,599,636 字节，SHA-256 `9c5e35128bb90a29ba8f7535340afa01ba73c37f62a32b2422319220e0fd40c5`。已写入卡。

2026-11-14 10:58，`10.0.0.110`，`ro.build.date` 是 Sat Nov 14 10:43:03 EST 2026，屏幕是 `ROTATION_0`。手指拖着应用抽屉走的 786 ms 里，`doFrame` 和 `present` 间隔中位数都是 16.7 ms，90 分位 17.0 ms。这段 `waitForBufferRelease` 没有出现。`LauncherAllAppsContainerView` 的层只画了 1 次，整块 1536×2048 的 `Drawing` 中位数 3.9 ms。手指松开、抽屉自己弹开的大约 300 ms 里，这一层又画了 13 次，`Drawing` 中位数 11 ms，`present` 90 分位 33.6 ms。弹回的短滑也有 10 次重画这一层，`present` 90 分位 33 ms。一直滑到底再松开、让它收回去，`present` 仍是 16.7 ms。松手弹开时 `onDragEnd` 对 `ALL_APPS` 调用 `addSpringFromFlingUpdateListener`，里面 `absorbSwipeUpVelocity` 让 `EdgeEffect` 吸收速度并 `invalidate()` 整块 `SpringRelativeLayout`。拖动过程只改位移，不走这一段。

2026-11-14。`packages/apps/Launcher3/src/com/android/launcher3/views/SpringRelativeLayout.java` 里，`absorbSwipeUpVelocity`、`absorbPullDeltaDistance` 和 `onRelease` 改为结束已经在画的光效，不再 `onAbsorb` / `onPull`。抽屉的位移动画不动。补丁是 `patches/packages_apps_Launcher3_all_apps_edge_glow.patch`，只写在 Gru 的 `patches/apply-patches.sh` 里。Kukui 的 `apply-patches.sh` 不读 Gru 的补丁。类里再用 `Build.DEVICE` 等于 `gru` 才走这条路径，别的设备仍是原来的 `onAbsorb` / `onPull`。`super.img` 1,285,599,636 字节，SHA-256 `a55e94a01047228f897068ba1c9a2bdaf30c37ac806b24e0350ddbd18f4a1511`，`ro.build.date` 是 Sat Nov 14 11:07:20 EST 2026。已写入卡。这份镜像里的判断还没有 `Build.DEVICE` 这一层，机器本身是 gru。

2026-11-14 11:22，`10.0.0.110`，`ro.build.date` 对得上，屏幕是 `ROTATION_90`，2048×1536。从停靠栏上方划出抽屉，松手后的 500 ms 里启动器 `Choreographer#doFrame` 间隔中位数 16.7 ms，90 分位 16.9 ms。`traversal` 中位数 11.9 ms，整块 `Drawing` 中位数 3.6 ms，`waitForBufferRelease` 中位数 1.2 ms。没有再出现 `LauncherAllAppsContainerView` 的 `drawLayer`。短滑弹回后的 450 ms 同样是 16.7 ms，90 分位 17.1 ms，`traversal` 中位数 11.5 ms，也没有重画这一层。一直滑到底的收回，拖动过程 `doFrame` 间隔中位数 16.7 ms。桌面翻页的拖动和松手都在 16.6 到 16.9 ms。

同一份轨迹里，抽屉已经打开之后滑动应用列表，`AllAppsRecyclerView` 1394×1365 在拖动和松手后的惯性里每帧都重画。松手后 `doFrame` 90 分位 40.3 ms，`traversal` 中位数 20.0 ms，`waitForBufferRelease` 中位数 20.9 ms。这不是抽屉位移动画那条光效。列表顶边的 `EdgeEffectProxy` 仍会 `invalidate()` 整块 `SpringRelativeLayout`，Gru 上改为不再转发。应用列表自己的整层重画还没改。这份带 `Build.DEVICE` 判断的 `super.img` 1,285,599,636 字节，SHA-256 `6b33031c0b8e0bd4d7935431ecbdeb871069515687ab8e01c21fa655bf2ff250`，`ro.build.date` 是 Sat Nov 14 11:34:51 EST 2026。2026-11-14 11:42 已传到 `10.0.0.123:/home/user/phase3/super.img`，上一张留成 `super.img.a55e94a0`。`kernel.kpart` 仍是 11 月 5 日那份。已写入卡。

2026-11-14 12:05，`10.0.0.110`，`ro.build.date` 是 Sat Nov 14 11:34:51 EST 2026，`ro.product.device` 是 gru，屏幕是 `ROTATION_0`，1536×2048。从 y=1300 划到 y=450 打开抽屉，松手后的 450 ms 里 `doFrame` 间隔中位数 16.7 ms，90 分位 16.9 ms。`traversal` 中位数 11.5 ms，`Drawing` 中位数 5.6 ms，`waitForBufferRelease` 没有出现，也没有 `LauncherAllAppsContainerView` 的 `drawLayer`。拖动开始有一帧 54.6 ms。

接着在同一张卡上批量看别的滑动，没有再写镜像。`animator_duration_scale` 设成 0 时，`EdgeEffect` 走 `TYPE_NONE`，测完已删掉这个设置，恢复成默认。抽屉刚打开后滑应用列表，有一次 `AllAppsRecyclerView` 1232×1877 重画了 20 次，拖动 `doFrame` 90 分位 42.9 ms，松手后 `traversal` 中位数 29.8 ms。动画关掉后再滑，这一层没有出现。隔 1 秒再滑列表中间，动画开着也没有这一层。再做一次刚打开就滑，动画开和关都没有这一层。设置列表滑到底，动画开着时松手 `doFrame` 中位数 16.6 ms，90 分位 19.6 ms，没有整块列表层。所以没有把整个系统的边缘特效都关掉。应用列表拖动里仍有大约 33 ms 的帧和 21 ms 的 `waitForBufferRelease`，和这次光效不是同一条路径。

2026-11-14 12:16。测试里把 `animator_duration_scale` 设成 0。`settings delete` 之后设置项没了，但 `WindowManagerService.getAnimatorDurationScaleSetting()` 在读不到这项时用当前内存里的倍率当默认值，所以内存里一直停在 0，窗口动画和属性动画都不跑了。这不是要保留的改动。12:17 把这项写回 1。`window_animation_scale` 和 `transition_animation_scale` 一直是 1.0。写回之后，从图标打开应用的轨迹里能看到 `animation` 和 `notifyAnimEnd`。

2026-11-14 12:18，`10.0.0.110`，竖屏，点主屏上的 PiliPlus。启动器 `doFrame` 间隔 44 帧里 28 帧不超过 18 ms，90 分位 45.8 ms，最长 81.9 ms。`present` 间隔中位数 17.3 ms，90 分位 35.0 ms。名叫 `animation` 的片段中位数 2.8 ms。慢的是启动器 `traversal` 最长 48.6 ms，任务栏 `draw-VRI` 有 3 帧到 30 ms，启动画面那一帧 `traversal` 99.7 ms，应用自己的第一帧 71.0 ms。`Workspace` 的层只画了 1 次。

同一台，从 y=2024 按住向上滑，进了 `overview_panel`。松手后的 700 ms 里启动器 `doFrame` 中位数 16.6 ms，90 分位 32.7 ms，最长 75.0 ms。中间有一帧 `traversal` 63.5 ms，同时任务栏 `draw-VRI` 53.0 ms，整块 1536×2048 的 `Drawing` 50.2 ms。这一帧旁边的整屏 `Drawing` 是 13 到 14 ms。没有连续重画最近任务的层。

2026-11-14 12:25 起，掉帧最重的是在最近任务里点一张卡片进应用，从图标打开应用是同一类卡顿。点 PiliPlus 那张卡片（`[789,238][1305,926]`，点在 1047,582）。启动器 `doFrame` 48 个间隔，中位数 16.6 ms，90 分位 43.7 ms，最长 58.2 ms。`present` 间隔 28 个，中位数 20.5 ms，90 分位 33.9 ms。`animation` 片段中位数 0.8 ms。整屏 `Drawing` 21 次，中位数 9.1 ms，其中 20 次是 1536×2048。没有 `drawLayer`。从点击后 0.32 s 起，RenderThread 的 `waitForBufferRelease` 连续是 20.0、25.6、15.5、25.4、20.1、25.0、27.1、24.5 ms。GPU 在这段已经是 800 MHz。

图标打开的前 350 ms 是 `CONTENT_SCALE_DURATION`。这段 `dequeueBuffer` 经常不到 0.2 ms，缓冲是空的，但整屏 `Drawing` 有 13 到 16 ms，`composite` 间隔多在 33 ms。`Workspace` 的 `drawLayer` 只在大约 0.38 s 出现一次，1536×2048。层画完之后的 `Drawing` 降到 1.5 到 4.8 ms，`composite` 回到 16.7 ms。层出现之前，窗口每一帧都在重放桌面图标的显示列表。

这两段的动画数值都不贵。贵的是启动器每一帧都重画整块 1536×2048，而这块缓冲又和旋转过的壁纸一起被 SurfaceFlinger 用 GPU 合成。卡片放大的后半段，`present` 自己要 13 到 16 ms，里面 `HwcPresentDisplay` 大约 10 ms，有一帧 `drawLayersInternal` 是 8.2 ms。启动器的 `doFrame` 仍多在 16.7 ms，画完的缓冲赶不上下一个 vsync，上屏就落在 33 ms。缓冲队列是在这之后才被填满，所以后面才出现 20 到 27 ms 的 `waitForBufferRelease`。

在线把预旋转多留的缓冲从 2 块改成 3 块，再改成 5 块，只换了 `libhwui.so` 并重启了 zygote，没有写卡。3 块时卡片放大在大约 0.29 到 0.34 s 有一段 16.7 ms，随后仍是 33 ms，`waitForBufferRelease` 从 0.42 s 起仍是 21 到 27 ms。5 块时卡片的 `composite` 30 帧里 17 帧在 33 ms 左右，整屏 `Drawing` 中位数 10.3 ms。图标打开在缓冲还空着的时候就已经是 33 ms。多留的缓冲盖不住这次合成超时。源码和补丁已改回多留 2 块，和现在卡上的 11:34 镜像一致。

图标这边试过在缩放开始前 `buildLayer()`。层仍在大约 0.46 s 才出现，有一帧 `panfrost_bo_munmap` 花了 16 ms，整屏 `Drawing` 到了 36 ms。没有留下。卡片这边试过只做 `SCALE_X` / `SCALE_Y` 的硬件层，并去掉缩略图 splash。这次概览没有走进 `zoomInTaskView`，轨迹里没有 `drawLayer`。去掉 splash 之后整屏 `Drawing` 中位数仍是 8.9 ms，`composite` 30 帧里 16 帧在 33 ms。这两处启动器改动都已从源码和 `apply-patches.sh` 里撤掉。

试验用的 bind mount 已卸掉，zygote 已重启。`/system/lib64/libhwui.so` 回到闪存上的 inode，`ro.build.date` 仍是 Sat Nov 14 11:34:51 EST 2026，`animator_duration_scale` 是 1。没有新的 `super`。
