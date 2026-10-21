# V4L2 Stateless 硬件视频解码调查与修复计划

返回 [总路线](roadmap.md) | 对照 [阶段 4](phase-4.md) | 对照 [USB 与外接显示修复](usb.md)

本文档记录 Google Scarlet（`rk3399-gru-scarlet-kd`，运行基于主线 `6.6.34-phase2` 内核的 LineageOS 23.2 / Android 16）在阶段 4.5 中针对 **V4L2 Stateless 硬件视频解码（`hantro_vpu` + `rockchip_vdec` -> Android `MediaCodec` / Codec2）** 的完整硬件探测、源码级根因分析与分步实现方案。

---

## 1. 背景与路线边界

### 1.1 为什么剔除 `rkmpp` 路线？
- 瑞芯微私有 `rkmpp`（Rockchip Media Process Platform）及其 Android `c2_rk` 组件强依赖下游 BSP 内核专有的 `/dev/mpp_service`（`rk_vcodec` 字符设备与私有 ioctl）。
- 本项目运行在主线 Linux `6.6.34` 内核上，内核不提供 `/dev/mpp_service`，而是通过标准的上游 **V4L2 Stateless Request API**（`v4l2-mem2mem` + Media Controller `/dev/media*`）暴露 RK3399 的两个硬件编解码引擎。
- 在桌面 Linux（如 PostmarketOS / Debian）下，MPV / FFmpeg 之所以能在主线内核上硬解，走的正是由内核 `hantro-vpu` 与 `rockchip-vdec` 提供的 `v4l2_request` 管线。因此 Android 侧同样必须走 **V4L2 Stateless Codec2 HAL** 路线。

### 1.2 RK3399 双硬件视频引擎实机探测结果
在 `6.6.34-phase2` 内核中，V4L2 与 VPU 驱动已编译为内核模块（`.ko`）。经实机加载全部 11 个模块并扫描 `/dev/video*` 与 `/dev/media*`，硬件拓扑与能力如下：

| 硬件引擎 | 设备树节点 | 内核驱动模块 | V4L2 节点 | Media 节点 | 硬件支持的格式（主线 6.6.34 实测） |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hantro G1 / VPU2** (`vdpu2` / `vepu2`) | `ff650000.video-codec` (`iommu group 0`) | `hantro-vpu.ko` | `/dev/video0` (enc)<br>`/dev/video1` (dec) | `/dev/media0` | **解码 (`/dev/video1`)**：<br>• `VP8F` (`V4L2_PIX_FMT_VP8_FRAME`)：`48x48` ～ `3840x2160`（UHD 4K）<br>• `MG2S` (`V4L2_PIX_FMT_MPEG2_SLICE`)：`48x48` ～ `1920x1088`<br>*(注：`rk3399_vpu_variant` 故意禁用了 Hantro 的 H.264，交由性能更强的 `rkvdec` 处理)*<br>**编码 (`/dev/video0`)**：<br>• `JPEG` (`V4L2_PIX_FMT_JPEG`)<br>**解码输出 (CAPTURE_MPLANE)**：<br>• `NV12` (`V4L2_PIX_FMT_NV12`，单 FD 连续内存 Y/UV 4:2:0) |
| **Rockchip VDEC** (`rkvdec`) | `ff660000.video-codec` (`iommu group 1`) | `rockchip-vdec.ko` | `/dev/video2` (dec) | `/dev/media1` | **解码 (`/dev/video2`)**：<br>• `S264` (`V4L2_PIX_FMT_H264_SLICE`)：`48x48` ～ `4096x2560`（4K，High Profile L5.1，Frame-based + Annex-B）<br>• `VP9F` (`V4L2_PIX_FMT_VP9_FRAME`)：`64x64` ～ `4096x2304`（4K，VP9 Profile 0 8-bit）<br>*(注：主线 6.6 `drivers/staging/media/rkvdec/` 仅含 `rkvdec-h264.c` 与 `rkvdec-vp9.c`，尚未合入 `rkvdec-hevc.c`；HEVC 在 6.6 主线下保持由 `c2.android.hevc.decoder` CPU 软解，或后续视需求从上游 backport `rkvdec-hevc.c`)*<br>**解码输出 (CAPTURE_MPLANE)**：<br>• `NV12` (`V4L2_PIX_FMT_NV12`，单 FD 连续内存 Y/UV 4:2:0) |

---

## 2. 深度根因调查：为什么现有组件不能「开箱即用」？

我们对内核模块、Android 源码树中的 `external/v4l2_codec2`、`system/cros-codecs`、`external/rust/crates/v4l2r` 以及 `external/minigbm-upstream` 进行了逐行源码审查，定位出阻断硬解码工作的 **4 个核心症结**：

### 2.1 症结一：10 个 V4L2 / VPU 内核模块尚未打包进 `vendor` 镜像，且未在 `init.gru.rc` 加载
- 内核编译目录 `/home/alpha/src/gru-phase2/linux-6.6.34` 已生成全套 `.ko`，但 `device/google/gru/modules/` 中此前仅因 USB Audio 放入了 `mc.ko`。
- 缺失的 10 个模块及其严格拓扑依赖顺序为：
  1. `mc.ko`（已存在）
  2. `videodev.ko`（依赖：`mc`）
  3. `videobuf2-common.ko`（依赖：`mc`）
  4. `videobuf2-memops.ko`（依赖：`videobuf2-common`）
  5. `videobuf2-dma-contig.ko`（依赖：`videobuf2-memops`, `videobuf2-common`）
  6. `videobuf2-v4l2.ko`（依赖：`videobuf2-common`, `videodev`, `mc`）
  7. `v4l2-mem2mem.ko`（依赖：`videobuf2-common`, `mc`, `videodev`, `videobuf2-v4l2`）
  8. `v4l2-h264.ko`（无外部模块依赖）
  9. `v4l2-vp9.ko`（无外部模块依赖）
  10. `hantro-vpu.ko`（依赖：`v4l2-mem2mem`, `videobuf2-v4l2`, `videodev`, `mc`, `v4l2-h264`, `videobuf2-dma-contig`, `v4l2-vp9`, `videobuf2-common`）
  11. `rockchip-vdec.ko`（依赖同上）
- **实机验证**：通过 `adb push` 手动按上述顺序 `insmod` 后，`dmesg` 确认两个引擎全部成功绑定到各自 IOMMU Group 并生成 `/dev/video0..2` 与 `/dev/media0..1`，且 `ueventd` 自动赋予了 `media:camera 0660` 权限。

### 2.2 症结二：AOSP `external/v4l2_codec2` 的 `V4L2Decoder` 仅实现了 V4L2 Stateful（有状态）协议，不支持 V4L2 Stateless Request API
- 在 `external/v4l2_codec2/v4l2/V4L2Decoder.cpp:139` 中：
  ```cpp
  const uint32_t inputPixelFormat = V4L2Device::videoCodecToPixFmt(codec);
  ```
  其默认参数 `sliceBased = false`，因此只会向 `/dev/video*` 请求有状态格式（`V4L2_PIX_FMT_H264` `'H264'`、`V4L2_PIX_FMT_VP8` `'VP80'`、`V4L2_PIX_FMT_VP9` `'VP90'`），而 RK3399 的 `hantro-vpu` 和 `rockchip-vdec` 只暴露无状态格式（`S264`、`VP8F`、`VP9F`）。
- 更关键的是，即便把 `sliceBased` 改为 `true`，`external/v4l2_codec2` 内部**完全没有**打开 `/dev/media*`、没有调用 `MEDIA_IOC_REQUEST_ALLOC`、没有在用户空间解析 H.264 SPS/PPS/DPB 或 VP8/VP9 帧头并通过 `VIDIOC_S_EXT_CTRLS(V4L2_CTRL_WHICH_REQUEST_VAL)` 提交控制结构体、也没有调用 `MEDIA_IOC_REQUEST_QUEUE`！
- **好消息**：在当前 LineageOS 23.2 (Android 16) 源码树中，Google / ChromiumOS 团队已经在 **`system/cros-codecs`** 中用 Rust 完整实现了 **V4L2 Stateless 解码器后端**：
  - `system/cros-codecs/src/decoder/stateless/{h264,vp8,vp9,h265,av1}/v4l2.rs`：包含全套 H.264 (`S264`)、VP8 (`VP8F`)、VP9 (`VP9F`) 码流解析器（SPS/PPS/Slice/DPB 管理、VP8/VP9 帧头与参考帧槽位管理）。
  - `system/cros-codecs/src/device/v4l2/stateless/{device,queue,request}.rs`：自动扫描 `/dev/video*` 并通过 `bus_info`（`platform:ff650000.video-codec` / `platform:ff660000.video-codec`）精确匹配对应的 `/dev/media0`（Hantro）与 `/dev/media1`（rkvdec），自动分配 `ioctl::Request`、写入 `SafeExtControl` 并在 `OUTPUT` 队列与 `CAPTURE` 队列之间完成解码同步！
  - `system/cros-codecs/src/c2_wrapper/c2_v4l2_decoder.rs` 与 `c2_decoder.rs`：甚至已经写好了 `C2Wrapper` 工作线程状态机（`C2DecoderWorker`）！
  - 但是，Google 在 25Q4 快照中只提交了 `system/cros-codecs` 的 Rust 库（`libcros_codecs`）和 CLI 工具（`ccdec`），**尚未提交将 `external/v4l2_codec2` 的 `DecodeComponent` 与 `libcros_codecs` 粘合起来的 C FFI 桥接层**。

### 2.3 症结三：V4L2 单平面 `V4L2_PIX_FMT_NV12`（1 个メモリ Plane）与 DRM/Gralloc `DRM_FORMAT_NV12`（2 个逻辑色彩 Plane）的 `num_planes` 冲突
这是在 `system/cros-codecs` + `v4l2r` 中隐藏得最深的一个底层 Bug，若不修复，零拷贝 `DMABUF` 队列导入必定报错 `NumPlanesMismatch(2, 1)`：
1. **内核 V4L2 侧**：
   - `hantro-vpu` 与 `rockchip-vdec` 虽然使用的是 `V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE` 队列，但它们暴露的像素格式是单缓冲区连续的 **`V4L2_PIX_FMT_NV12`**（`NV12`），而不是双独立缓冲区 `V4L2_PIX_FMT_NV12M`（`NM12`）。
   - 在 V4L2 规范中，`V4L2_PIX_FMT_NV12` 的 **`v4l2_format.fmt.pix_mp.num_planes` 为 `1`**（Y 和 UV 连续存放在同一个 `v4l2_plane[0]` 中，`sizeimage` 包含 Y+UV 总大小）。
2. **Gralloc / `minigbm-upstream` 侧**：
   - `minigbm-upstream`（`dumb_driver.c` / `drv_helpers.c`）分配 `DRM_FORMAT_NV12` 时，底层只调用一次 `DRM_IOCTL_MODE_CREATE_DUMB` 创建一个连续 GEM/dumb buffer，但 `drv_bo_from_format()` 会按 `biplanar_yuv_420_layout` 设置 `bo->meta.num_planes = 2`（Plane 0 偏移 `0`，Plane 1 偏移 `stride * aligned_height`），并通过 `drv_prime_bo_export` 导出 2 个指向同一个底层 DMA-BUF 的 FD。
3. **`cros-codecs` / `v4l2r` 侧的冲突点**：
   - 在 `system/cros-codecs/src/video_frame.rs:159` 中，`VideoFrame::num_planes()` 对 `DecodedFormat::NV12` 返回 **`2`**。
   - 而 `V4l2VideoFrame<V>::len()`（第 370 行）直接返回 `self.0.num_planes()`（即 `2`）。
   - 当 `v4l2r` 的 `QBuffer::queue_with_handles()`（`external/rust/crates/v4l2r/lib/src/device/queue/qbuf.rs:188`）将 `GenericDmaVideoFrame` 或 `V4l2MmapVideoFrame` 送入 `CAPTURE_MPLANE` 队列时，它会检查：
     ```rust
     if handles.len() != self.num_expected_planes() {
         return Err(QueueError {
             error: QBufIoctlError::NumPlanesMismatch(handles.len(), self.num_expected_planes()).into(),
             ...
         });
     }
     ```
     其中 `handles.len()` 为 `2`，而内核 `REQBUFS` / `QUERYBUF` 返回给 `self.num_expected_planes()` 的 `num_planes` 为 **`1`**！直接触发 `NumPlanesMismatch(2, 1)`！
   - 同样地，在 `V4l2MmapVideoFrame::new()`（`v4l2_mmap_video_frame.rs:72`）中，作者甚至留了一行未完成代码：
     ```rust
     if ret.is_contiguous() {
         todo!("Contiguous formats are not currently supported for MMAP!");
     }
     ```
- **修复方法**：
  - 在 `system/cros-codecs` 中修正 `V4l2VideoFrame` 的 V4L2 平面数量语义：当 `self.0.is_contiguous()` 为 `true`（如连续 `NV12`，区别于非连续 `NM12`/`MM21`）时，V4L2 侧的 `BufferHandles::len()` 应当为 **`1`**（只填充 `v4l2_plane[0]`，其 `fd = dma_handles[0]`，`length` 为总大小），同时保留色彩空间层面的 `num_planes() == 2`（Y 平面 + UV 平面偏移）供映射与渲染使用！
  - 并补全 `V4l2MmapVideoFrame` 对单平面连续 `NV12` 的 `mmap` 支持（映射 `v4l2_planes()[0]` 后按 Y 平面大小切分 Y 与 UV 切片），使 CLI 测试工具 `ccdec` 也能直接在平板上运行。

### 2.4 症结四：`minigbm-upstream` 的 `dumb_driver` 分配 `NV12` 时的宏块对齐与 `rkvdec` 运动矢量（MV）额外空间要求
对比 `external/minigbm-upstream/rockchip.c:131` 与 `dumb_driver.c` / `drv_helpers.c:370`：
1. 在 `rockchip.c:131` 中，针对 Rockchip 硬件视频解码器分配 `DRM_FORMAT_NV12` 时有两项关键硬件要求：
   - 宽高必须按宏块（16 像素，VP9 为 64 像素，而 `dumb_driver` 的 `MESA_LLVMPIPE_TILE_SIZE` 恰好将 `aligned_width` 与 `aligned_height` 对齐到了 64 的倍数）对齐。
   - **关键点**：`rockchip-vdec`（以及 Hantro）在硬件解码时，或者通过驱动内部分配的辅助 buffer 存储 MV，或者要求 `CAPTURE` buffer 的 `sizeimage` 满足 `v4l2_format.fmt.pix_mp.plane_fmt[0].sizeimage`（即 `aligned_width * aligned_height * 3 / 2`）。
   - 而在 `drv_helpers.c:400`（`drv_dumb_bo_create_ex`）中：
     ```c
     drv_bo_from_format(bo, create_dumb.pitch, 1, height, format);
     ```
     注意这里传入的第 4 个参数是未对齐的 `height`（例如 `1080`），而不是 16/64 对齐后的 `height`（例如 `1088`）！
     这会导致：
     - 当视频高度为 `1080` 时，V4L2 解码器要求 `coded_height = 1088`，UV 平面的起始偏移在 `pitch * 1088` 处，且总大小至少为 `pitch * 1088 * 3 / 2`。
     - 如果客户端用 `1080` 高度去请求 Gralloc 分配，或者 `drv_dumb_bo_create_ex` 用未对齐的 `height` 计算 `offsets[1]`，UV 平面偏移就会变成 `pitch * 1080`（与硬件写入的 `pitch * 1088` 错位 8 行，导致底部绿边或色彩错位）！
   - 而在 `VideoFramePool` 中，只要解码器以 V4L2 协商后的 **`coded_size`**（如 `1920x1088`）去请求 `fetchGraphicBlock(coded_size.width, coded_size.height, HalPixelFormat::NV12, ...)`，并通过 `frame->setVisibleRect(visibleRect)` 设置可视区域（`1920x1080`），`height` 本身就已经是 16 对齐的 `1088`，`offsets[1]` 与 `sizeimage` 就能与 V4L2 硬件严丝合缝！

---

## 3. 架构设计与分步实施方案

为了以最清晰、最稳健、可逐层验证的方式打通 RK3399 V4L2 Stateless 硬解码，我们将工程拆分为 **3 个递进阶段**：

### 阶段 A：内核模块固化与 CLI 独立硬解验证（`ccdec` on `/dev/video1` & `/dev/video2`）
1. **打包并自动加载 11 个 V4L2 / VPU 内核模块**：
   - 将 `videodev.ko`、`videobuf2-common.ko`、`videobuf2-memops.ko`、`videobuf2-dma-contig.ko`、`videobuf2-v4l2.ko`、`v4l2-mem2mem.ko`、`v4l2-h264.ko`、`v4l2-vp9.ko`、`hantro-vpu.ko`、`rockchip-vdec.ko` 拷入 `device/google/gru/modules/`。
   - 更新 `device/google/gru/device.mk` 的 `PRODUCT_COPY_FILES` 与 `device/google/gru/init.gru.rc` 的 `on init` 模块加载序列。
   - 在 `device/google/gru/ueventd.gru.rc` 中确认 `/dev/video*` 与 `/dev/media*` 权限为 `0660 media camera`（以及 `mediacodec` 所属的 `media` / `camera` 组）。
2. **修复 `system/cros-codecs` 单平面 `NV12` (`V4L2_PIX_FMT_NV12`) 支持并编译 `ccdec`**：
   - 修复 `system/cros-codecs/src/video_frame.rs` 与 `v4l2_mmap_video_frame.rs` 中针对单平面连续 `NV12` 的 `BufferHandles::len()`（返回 `1`）及 `mmap` 映射逻辑。
   - 编译 `/vendor/bin/ccdec`，推送到平板上直接对 H.264 (`S264` -> `/dev/video2` `rkvdec`)、VP8 (`VP8F` -> `/dev/video1` `hantro-vpu`)、VP9 (`VP9F` -> `/dev/video2` `rkvdec`) 测试码流执行硬件解码并校验输出帧 MD5 / YUV 数据，100% 独立验证内核 V4L2 Stateless + IOMMU + `cros-codecs` 状态机工作正常。

### 阶段 B：打通 `external/v4l2_codec2` 与 `system/cros-codecs` 的 Codec2 V4L2 Stateless 后端
1. **为 `system/cros-codecs` 暴露轻量 C FFI 接口（或直接在 `v4l2_codec2` 中集成 `CrosCodecsDecoder`）**：
   - `external/v4l2_codec2` 的架构非常模块化：`V4L2DecodeComponent` 只依赖抽象基类 `android::VideoDecoder`（仅 3 个纯虚函数：`decode()`、`drain()`、`flush()`，以及通过 `GetPoolCB` 获取 `VideoFramePool` 的 `C2GraphicBlock` DMA-BUF FD）。
   - 我们在 `system/cros-codecs` 中提供 C FFI 封装，并在 `external/v4l2_codec2` 中实现 `StatelessV4L2Decoder : public VideoDecoder`（或在 `V4L2Device::queryDecodingCapabilities` 中同時识别 `V4L2_PIX_FMT_H264_SLICE` / `V4L2_PIX_FMT_VP8_FRAME` / `V4L2_PIX_FMT_VP9_FRAME`）：
     - **零拷贝缓冲区链路**：
       - 当 `cros-codecs` 解析出序列头触发格式变更时，以对齐后的 `coded_resolution` 调用 `GetPoolCB` 从 `C2BlockPool`（底层为 `minigbm-upstream` 分配的 `HalPixelFormat::NV12` / `YCBCR_420_888` `C2GraphicBlock`）分配 graphic block。
       - 提取 `C2GraphicBlock` 的 DMA-BUF `fd` 封装为 `GenericDmaVideoFrame`，直接通过 `V4L2_MEMORY_DMABUF` 送入 `/dev/video1` 或 `/dev/video2` 的 `CAPTURE_MPLANE` 队列由 VPU/VDEC 硬件 DMA 直接写入。
       - 解码完成后，附带 `visible_rect` 直接将 `C2ConstGraphicBlock` 交还给 `DecodeComponent::onOutputFrameReady()` -> `SurfaceFlinger` / GPU 零拷贝渲染！
     - **ByteBuffer 模式兼容**：当客户端（或 CTS 测试）使用非 Surface 的 `GRALLOC` ByteBuffer 模式时，`C2BlockPool` 同样通过 `minigbm-upstream` 分配带 `CPU_READ` 标志的线性 `NV12` DMA-BUF，无需额外拷贝即可直接映射读取。

### 阶段 C：配置 Android MediaCodec XML、VINTF、SELinux/Seccomp 并实机验证
1. **服务与组件打包（`device/google/gru/device.mk`）**：
   - 加入 `android.hardware.media.c2-service-v4l2`、`libv4l2_codec2_components`、`libv4l2_codec2_v4l2`、`libv4l2_codec2_common`、`libv4l2_codec2_store`。
   - 配置系统属性：
     - `ro.vendor.v4l2_codec2.decoder.supported.h264=true`
     - `ro.vendor.v4l2_codec2.decoder.supported.vp8=true`
     - `ro.vendor.v4l2_codec2.decoder.supported.vp9=true`
     - `ro.vendor.v4l2_codec2.decode_concurrent_instances=8`
2. **VINTF 与 Init RC**：
   - 在 `device/google/gru/manifest.xml`（或 `vintf_fragments`）注册 `android.hardware.media.c2` (`IComponentStore/default`)。
   - 检查 `android.hardware.media.c2-service-v4l2.rc` 的用户组权限：默认 RC 中 `group mediadrm drmrpc` **缺少 `camera` 和 `media` 组**，而 `/dev/video*` 和 `/dev/media*` 属组为 `camera`、`/dev/dri/card0` 属组为 `graphics`！必须将服务属组扩展为 `group camera media mediadrm drmrpc graphics`，并检查 seccomp 策略是否放行 `ioctl` / `dup` / `ppoll` / `mmap`。
3. **MediaCodecs XML 配置**：
   - 编写 `media_codecs_c2.xml` 与 `media_codecs_performance_c2.xml` 并在 `media_codecs.xml` 中引入：
     - `c2.v4l2.avc.decoder` (`video/avc`，`48x48` ～ `4096x2560`)
     - `c2.v4l2.vp8.decoder` (`video/x-vnd.on2.vp8`，`48x48` ～ `3840x2160`)
     - `c2.v4l2.vp9.decoder` (`video/x-vnd.on2.vp9`，`64x64` ～ `4096x2304`)
4. **实机端到端验证**：
   - 检查 `dumpsys media.player` / `cmd media.metrics` 确认 `c2.v4l2.avc.decoder`、`c2.v4l2.vp8.decoder`、`c2.v4l2.vp9.decoder` 已注册且排在软件解码器之前（rank `0x80` = 128 < SW rank `0x200`）。
   - 使用系统播放器与第三方客户端（如 PiliPlus 选择 `auto / mediacodec`）播放 1080p/4K H.264 与 VP9 视频，通过 `logcat` 和 `/proc/interrupts`（`ff650000.video-codec` / `ff660000.video-codec` 中断计数增长）验证硬解码零拷贝工作。

---

## 4. 事件与进度追踪日志

| 日期 | 阶段 | 事件与进展记录 |
| :--- | :--- | :--- |
| 2026-10-20 | 外部显示收尾 | 用户实机确认：刷入包含 `external/drm_hwcomposer/drm/DrmPlane.cpp` 缩放检查修复与 Desktop Experience 配置的 `super.img`（`282b8f271a7039768dec97f5006802b360491ecd00f40b9e68ad135accd10d7f`）后，USB-C 外接屏镜像模式与扩展模式（桌面模式）均完全正常，问题彻底解决。 |
| 2026-10-20 | 硬解码立项与调查 | 1. 核查内核 `6.6.34-phase2` 编译产物，理清 11 个 V4L2 / VPU 模块依赖链，并在实机（`10.0.0.109:5555`）动态加载验证通过：`hantro-vpu` 注册为 `/dev/video0`（JPEG enc）、`/dev/video1`（VP8/MPEG2 dec）与 `/dev/media0`；`rockchip-vdec` 注册为 `/dev/video2`（H.264/VP9 dec）与 `/dev/media1`。两个引擎均成功挂入各自 IOMMU Group。<br>2. 实机通过 ioctl 探针完整导出 `/dev/video0..2` 的 Capabilities 与支持的 Coded/Decoded 像素格式及分辨率范围。<br>3. 完成了对 `external/v4l2_codec2`、`system/cros-codecs`、`external/rust/crates/v4l2r`、`external/minigbm-upstream` 的源码级调查，定位出 4 个核心症结（缺内核模块打包、`v4l2_codec2` 默认仅支持 Stateful 需桥接 `cros-codecs` Stateless 后端、单平面 `V4L2_PIX_FMT_NV12` 与双逻辑平面 `DRM_FORMAT_NV12` 的 `num_planes` 冲突、`android.hardware.media.c2-service-v4l2.rc` 缺 `camera`/`graphics` 权限组），制定分步修复方案并建立本文档。 |
| 2026-10-20 | 阶段 A 完成 | 1. **内核模块固化**：将 `videodev.ko`、`videobuf2-{common,memops,dma-contig,v4l2}.ko`、`v4l2-{mem2mem,h264,vp9}.ko`、`hantro-vpu.ko`、`rockchip-vdec.ko` 共 10 个模块拷入 `device/google/gru/modules/`，并更新 `device.mk`、`init.gru.rc`（在 `mc.ko` 后按拓扑顺序自动加载）与 `ueventd.gru.rc`（`/dev/video*` 与 `/dev/media*` 权限 `0660 media camera`）。<br>2. **修复 `system/cros-codecs` 与 `minigbm` 单平面 `NV12` / `rkvdec` MV 空间问题**：<br>• `system/cros-codecs/src/video_frame.rs`：修正 `V4l2VideoFrame<V>::len()` 在 `self.0.is_contiguous()` 时返回 `1`（匹配 V4L2 `V4L2_PIX_FMT_NV12` 单内存 Plane，解决 `NumPlanesMismatch(2, 1)`）。<br>• `system/cros-codecs/src/video_frame/v4l2_mmap_video_frame.rs`：实现单平面连续 `NV12` 的 `V4l2MmapVideoFrame` 映射、双色彩平面尺寸与跨距切分。<br>• `system/cros-codecs/src/c2_wrapper/c2_decoder.rs`：修复 `ImportingDecoder` 在 `decoder_modifier == DrmModifier::Linear` 时误触发 `Linear -> Linear` modifier 转换的 Bug。<br>• `external/minigbm-upstream` & `external/minigbm`（`dumb_driver.c` / `drv_helpers.c`）：在 `dumb_bo_create_with_modifiers` 中透传 `bo->meta.use_flags`；当分配带 `BO_USE_HW_VIDEO_DECODER` 的 `DRM_FORMAT_NV12` 时，保持 16 字节宏块跨距对齐并追加 `rkvdec` 所需的运动矢量（Colocated MV，`128 * MB_w * MB_h`）空间，解决 `rkvdec_buf_prepare` 因 `vb2_plane_size < sizeimage` 拒绝入队的问题；同时为 `DRM_FORMAT_YVU420_ANDROID` 补齐 `BO_USE_CAMERA_WRITE` 支持。<br>3. **实机 CLI 硬解与 Golden MD5 100% 验证通过**：编译 `/vendor/bin/ccdec` 与 `libgbm.so` 推送至实机测试：<br>• **H.264 (`/dev/video2` `rockchip-vdec`)**：250 帧全部硬解通过，逐帧与全流 Golden MD5 (`3af866863225b956001252ebeccdb71d`) **100% 吻合**；零拷贝 DMABUF (`--output-format nv12`) 250 帧全部硬解通过 (`c220d3dcaa6001a569b82abb42657910`)。<br>• **VP8 (`/dev/video1` `hantro-vpu`)**：250 帧全部硬解通过，逐帧与全流 Golden MD5 (`b21d050af9f7532bd15fe56cbb63c2db`) **100% 吻合**；零拷贝 DMABUF (`--output-format nv12`) 250 帧全部硬解通过 (`cfda1feb4743c9f7626ffa0f47c38411`)。<br>• **VP9 (`/dev/video2` `rockchip-vdec`)**：硬件解码管线与中断跑通（注：`cros-codecs` 尚缺 `V4L2_CID_STATELESS_VP9_COMPRESSED_HDR` 概率增量表解析，而 `rkvdec` 硬件强依赖该表计算后续帧，故 Codec2 阶段优先暴露 100% bit-exact 的 H.264 与 VP8 硬解，VP9 保持 `c2.android.vp9.decoder` 或后续补齐压缩头解析）。<br>• `/proc/interrupts` 实测确认 `ff650000.video-codec`（GICv3 145，`1005` 次中断）与 `ff660000.video-codec`（GICv3 148，`1293` 次中断）硬件中断正常触发。 |
