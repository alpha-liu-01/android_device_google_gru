# 前后摄像头（`rkisp1` + `ov5695` / `ov2685` + `libcamera`）调查与实现记录

本文档对应 [`docs/roadmap.md`](roadmap.md) 中「阶段 4.5」的第 5 项：**在现有 `6.6.34-phase2` 内核上测试并打通前后摄像头（`rkisp1` + `ov5695` / `ov2685` + `libcamera`）**，记录硬件拓扑、历史问题根因（为何 `6.6.34` 下此前完全检测不到摄像头、为何 postmarketOS edge `7.x` 下画面发灰/发绿无法拍出正常彩色照片）、ChromeOS 原厂 ISP 标定参数提取、分阶段实现方案与事件日志。

---

## 一、背景与两大核心问题调查结论

### 1.1 硬件拓扑（`rk3399-gru-scarlet`）

在 `arch/arm64/boot/dts/rockchip/rk3399-gru-scarlet.dtsi` 中，Acer Chromebook Tab 10（`scarlet`）配备了两颗连接在同一个 I2C 总线（`i2c7` / `ff160000.i2c`）与同一个 MIPI CSI-2 D-PHY 接收器（`mipi_dphy_rx0` -> `isp0@ff910000`）上的 Raw Bayer 传感器：

| 角色 | 设备树节点 | 传感器型号 | I2C 地址 | MIPI 通道 | 最大分辨率与格式 | 镜头参数（源自 ChromeOS `camera3_profiles.xml`） |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **后置主摄（World Camera）** | `wcam: camera@36` | OmniVision `OV5695` (`ovti,ov5695`) | `7-0036` | 2-lane MIPI CSI-2 | `2592x1944` @ 30fps (`SBGGR10_1X10`) | `facing: BACK`，`f/2.0`，焦距 `2.35mm`，像元 `1.4µm` |
| **前置副摄（User Camera）** | `ucam: camera@3c` | OmniVision `OV2685` (`ovti,ov2685`) | `7-003c` | 1-lane MIPI CSI-2 | `1600x1200` @ 30fps (`SBGGR10_1X10`) | `facing: FRONT`，`f/2.4`，焦距 `2.10mm`，像元 `1.75µm` |
| **ISP 硬件管线** | `isp0: isp0@ff910000` | Rockchip ISP1 (`RKISP1_V10`) | MMIO `0xff910000` | 内置 CSI-2 RX + 双缩放输出（`mainpath` / `selfpath`） | 输出 `NV12` / `NV21` / `YUYV` | 支持 `BLS`、`SDG`、`LSC`、`AWB`、`FLT`、`BDM`、`CTK`、`GOC`、`CPROC`、`DPF` |

> **注（同族 Google Gru 机型差异）**：`rk3399-gru-kevin`（Samsung Chromebook Plus）与 `rk3399-gru-bob`（ASUS Chromebook Flip C101PA）的屏幕转轴处采用的是 **USB UVC 摄像头**，并未使用 `rkisp1` MIPI CSI-2 接口；仅 `rk3399-gru-scarlet` 系列（`kd` / `inx` / `dumo`）平板采用 MIPI CSI-2 + `rkisp1` + `ov5695` / `ov2685` 架构。

---

### 1.2 问题一：为什么在 `6.6.34` 内核下此前完全检测不到摄像头、相机应用直接闪退？

经排查内核构建产物、对比 `6.6.34` 与主线 `7.x` 源码并在 `6.6.34-phase2` 实机上进行热加载测试，证实 **`6.6.34-phase2` 内核本身的摄像头驱动与设备树是完全正常的**，此前检测不到摄像头由以下三层原因叠加造成：

1. **Android 侧未打包且未加载 6 个摄像头内核模块**：
   - `6.6.34-phase2` 内核配置中已开启 `CONFIG_PHY_ROCKCHIP_DPHY_RX0=y`（内置），并将 ISP 与传感器编译为模块：`CONFIG_VIDEO_ROCKCHIP_ISP1=m`、`CONFIG_VIDEO_OV5695=m`、`CONFIG_VIDEO_OV2685=m`。
   - 但此前这 6 个 `.ko` 模块（`v4l2-async.ko`、`v4l2-fwnode.ko`、`videobuf2-vmalloc.ko`、`ov5695.ko`、`ov2685.ko`、`rockchip-isp1.ko`）尚未拷入 `device/google/gru/modules/`，也未在 `init.gru.rc` 中加载。
2. **实机验证 `6.6.34-phase2` 内核模块热加载结果（一次性探测成功）**：
   - 将 `/home/alpha/src/gru-phase2/modinstall/lib/modules/6.6.34-phase2/` 下的上述 6 个模块推入运行中的平板并按依赖顺序 `insmod` 后，`dmesg` 立即输出：
     ```text
     [ 1895.386181] ov5695 7-0036: Detected OV005695 sensor
     [ 1895.418107] ov2685 7-003c: Detected OV2685 sensor
     [ 1895.458066] rkisp1 ff910000.isp0: Adding to iommu group 4
     [ 1895.460193] rkisp1: registered rkisp1_mainpath as /dev/video3
     [ 1895.460433] rkisp1: registered rkisp1_selfpath as /dev/video4
     ```
   - 完整生成 `/dev/media2`（`rkisp1`）、`/dev/video3..6`（`mainpath`、`selfpath`、`stats`、`params`）以及 `/dev/v4l-subdev0..5`（含 `ov2685 7-003c` 与 `ov5695 7-0036`）。
   - 同时对比 `6.6.34` 与主线 `7.x` 的 `drivers/media/i2c/ov5695.c`、`ov2685.c`、`rk3399-gru-scarlet.dtsi` 源码，确认两者在 Scarlet 上**没有任何功能性差异**，因此完全不需要冒着破坏 DSI 显示、cgroup 与 S3 休眠的风险去升级 `7.x` 内核。
3. **用户态 `libcamera` 漏注册 `CameraSensorHelperOv5695` 导致 `ov5695` IPA 初始化返回 `-ENODEV`**：
   - 在 `external/libcamera`（以及上游 `libcamera`）中，虽然提交 `0af204067881`（*"ipa: rkisp1: Add tuning files for Google DRU 'Scarlet' sensors"*）添加了 `src/ipa/rkisp1/data/ov5695.yaml` 与 `ov2685.yaml`，但在 `src/ipa/libipa/camera_sensor_helper.cpp` 和 `src/libcamera/camera_sensor_properties.cpp` 中**只注册了 `ov2685`，完全漏掉了 `ov5695`**！
   - 当 `IPARkISP1::init()`（`src/ipa/rkisp1/rkisp1.cpp:152`）执行 `CameraSensorHelperFactoryBase::create("ov5695")` 时返回 `nullptr`，直接报错 `Failed to create camera sensor helper for ov5695` 并返回 `-ENODEV`，导致 `PipelineHandlerRkISP1::createCamera()` 拒绝注册后置摄像头 `ov5695`。
   - 此外，Android 侧 `device/google/gru/` 尚未启用 `libcamera` Camera Provider HAL，且 `external/libcamera/Android.bp` 默认只包含 `virtual` 与 `ipu7` 管线目标，未将 `rkisp1` 管线与 `ipa_rkisp1` 编入 Android 镜像。

---

### 1.3 问题二：为什么 postmarketOS edge（`7.x` 内核）下摄像头画面发灰或发绿、拍不出彩色照片？能否修复？

**结论：完全可以通过软件修复。** 这一现象并非内核驱动或硬件故障，而是因为上游 `libcamera` 的 `src/ipa/rkisp1/data/ov5695.yaml` 与 `ov2685.yaml` **严重残缺**，導致 `rkisp1` ISP 硬件的色彩管线关键模块（黑电平扣除 `BLS`、3×3 色彩校正矩阵 `CTK/CCM`、输出伽马曲线 `GOC`）全部处于关闭状态！

我们从 ChromiumOS 官方仓库（`chromiumos/overlays/board-overlays` 的 `overlay-scarlet/media-libs/cros-camera-hal-configs-scarlet/files/`）提取了 Google/华硕为 Scarlet 出厂标定的原厂 IQ 配置文件：
- 后置主摄 `OV5695`：`IQ/OV5695_lens_CHT-842B-MD.xml`（269 KB）
- 前置副摄 `OV2685`：`IQ/OV2685.xml`（269 KB）
- Android 相机属性：`camera3_profiles.xml`

将原厂标定文件与上游 `libcamera` 的 `ov5695.yaml` / `ov2685.yaml` 逐项比对后，定位出导致画面「发灰、发绿、无彩色」的 **4 个精确根因**：

#### 根因 1：`ov5695.yaml` 与 `ov2685.yaml` 缺失 `BlackLevelCorrection`（黑电平扣除 `BLS`）——导致画面发灰起雾
- 上游 `libcamera` 在提交 `0af204067881` 从 ChromeOS 标定文件转换 `ov5695.yaml` 与 `ov2685.yaml` 时，只转换了 `LensShadingCorrection`（LSC），完全漏掉了 `BlackLevelCorrection`。
- 在 `src/ipa/rkisp1/algorithms/blc.cpp` 中，只有当 `.yaml` 包含 `BlackLevelCorrection` 时才会开启 `RKISP1_CIF_ISP_MODULE_BLS`。
- 查阅 ChromeOS 原厂标定 XML 的 `<BLS>` 节：
  - `OV5695` 的 12-bit ISP 黑电平偏置为 `blsData = [64, 64, 64, 64]`（对应 10-bit 传感器黑电平 `16`）；
  - `OV2685` 在 `1600x1200` 下的 12-bit ISP 黑电平偏置为 `blsData = [80, 80, 80, 80]`（`800x600` 下为 `[64, 64, 65, 65]`）。
- 当 `BLS` 未启用时，每个像素都带着 `64~80` 的正直流底噪进入后续的镜头阴影校正（LSC，边缘放大逾 $2\times$）和白平衡增益放大，导致暗部与中间调被整体抬升，画面像蒙了一层厚厚的**灰雾**。

#### 根因 2：缺失 3×3 色彩校正矩阵（`CTK` / `Ccm`，`RKISP1_CIF_ISP_MODULE_CTK`）——导致严重偏绿、拍不出彩色
- Raw Bayer 传感器的硅光电二极管原始 R、G、B 通道存在强烈的光谱串扰（Spectral Cross-Talk），特别是绿色滤光片与红/蓝通道之间存在大幅能量混叠，未校正的传感器原生 RGB 空间饱和度极低且绿色分量占绝对主导。
- 查阅 ChromeOS 原厂标定 XML 的 `<CC>` 节，在标准日光 `D65`（`saturation = 100`）下，原厂标定的 3×3 色彩校正矩阵（`ccMatrix`）为：
  - **`OV5695` (`D65_100`)**：
    \[
    M_{\text{OV5695, D65}} = \begin{bmatrix}
    1.8053 & -0.5532 & -0.2521 \\
    -0.4283 & 2.0910 & -0.6627 \\
    -0.0743 & -0.5460 & 1.6203
    \end{bmatrix}
    \]
  - **`OV2685` (`D65_100`)**：
    \[
    M_{\text{OV2685, D65}} = \begin{bmatrix}
    2.1173 & -0.8994 & -0.2178 \\
    -0.4967 & 2.5125 & -1.0158 \\
    -0.2391 & -0.9078 & 2.1469
    \end{bmatrix}
    \]
- 可以看到，为了还原真实色彩，主对角线增益必须达到 $1.62 \sim 2.51$，且必须用高达 $-0.55 \sim -1.02$ 的负非对角线系数把串入各通道的绿色/蓝色分量减掉！
- 然而在 `rkisp1` 内核驱动与 `external/libcamera` 中，由于未配置 `CTK` 模块，硬件默认使用单位矩阵 $\operatorname{diag}(1, 1, 1)$。在单位矩阵下，三通道混叠在一起且主对角线色度增益严重不足，拍出的照片自然**严重发绿/发灰、几乎没有任何彩色饱和度**。

#### 根因 3：缺失输出伽马校正（`GOC`，`RKISP1_CIF_ISP_MODULE_GOC`）——导致输出停留在 $\gamma = 1.0$ 线性光空间
- `rkisp1-params.c` 在初始化时默认关闭 `RKISP1_CIF_ISP_CTRL_ISP_GAMMA_OUT_ENA`。
- 在 `external/libcamera/src/ipa/rkisp1/algorithms/`（及上游 `ov5695.yaml` / `ov2685.yaml`）中均未启用 `GOC` 模块，导致 ISP 输出的线性光信号（$\gamma = 1.0$）未经 sRGB 伽马曲线（$\gamma \approx 2.2$）非线性映射就直接转成了 YCbCr。
- ChromeOS 原厂标定 XML 的 `<GOC>` 节给出了 `RKISP1_V10` 的 17 点硬件 Gamma 表：
  - `OV5695`：`gamma_y = [0, 73, 137, 183, 223, 287, 340, 387, 429, 502, 565, 623, 723, 810, 888, 959, 1023]`
  - `OV2685`：`gamma_y = [0, 73, 137, 183, 223, 287, 340, 387, 429, 502, 565, 623, 723, 810, 888, 920, 990]`

#### 根因 4：`Awb`（自动白平衡）统计模式与空统计帧保护缺陷
- 在 `external/libcamera/src/ipa/rkisp1/algorithms/awb.cpp` 中：
  1. `Awb::process()` 未检查 `awb->awb_mean[0].cnt == 0`。当首帧或暗场符合阈值的统计像素数为 `0` 时，`mean_y = 0, mean_cb = 0, mean_cr = 0` 减去 `(16, 128, 128)` 后经逆矩阵计算会得出虚假的 `greenMean = +134.9, redMean = 0, blueMean = 0`，导致白平衡增益瞬间失控。
  2. 默认 `rgbMode_ = false` 使用 YCbCr 窄窗口统计且未对 CCM 做逆矩阵补偿；切换为硬件原生 RGB 均值统计模式（`RKISP1_CIF_ISP_AWB_MODE_RGB`，`rgbMode_ = true`）并加上 `cnt == 0` 保护与合理的增益钳位后，Grey-World AWB 即可稳定收敛到准确的红/蓝白平衡增益（`D65` 下原厂基准约为 $R_{\text{gain}} \approx 1.85\sim 1.98, B_{\text{gain}} \approx 1.33\sim 1.38$）。

---

## 二、分阶段实现与验证方案

为避免每次修改都重新打包刷写 1.3 GB 的 `super.img`，我们沿用硬件视频解码的成功经验，采用 **「阶段 A：实机 `/data/local/tmp` 命令行 `cam` 抓帧与色彩调优 -> 阶段 B：Android Camera HAL v3 与 Provider 服务联调 -> 阶段 C：固化进 `super.img`」** 的三步走方案。

### 阶段 A：内核模块热加载 + `libcamera` (`rkisp1`) + `cam` 实机抓帧与色彩修复验证

1. **内核模块层**：
   - 使用当前 `6.6.34-phase2` 内核已有的 6 个模块（无需重编内核）：
     - `v4l2-async.ko`
     - `v4l2-fwnode.ko`
     - `videobuf2-vmalloc.ko`
     - `ov5695.ko`
     - `ov2685.ko`
     - `rockchip-isp1.ko`
2. **补齐 `external/libcamera` 的传感器支持与 `rkisp1` ISP 色彩算法**：
   - 在 `src/ipa/libipa/camera_sensor_helper.cpp` 中新增 `CameraSensorHelperOv5695`（根据 `drivers/media/i2c/ov5695.c` 的寄存器 `0x3509` 实测增益模型：`AnalogueGainLinear{ 1, 0, 0, 16 }`）。
   - 在 `src/libcamera/camera_sensor_properties.cpp` 中新增 `ov5695` 属性定义（`unitCellSize = { 1400, 1400 }` 及测试图案映射）。
   - 在 `src/ipa/rkisp1/algorithms/` 中：
     - 修复 `awb.cpp`：加入 `awb->awb_mean[0].cnt == 0` 检查，启用 `RKISP1_CIF_ISP_AWB_MODE_RGB`（或带 CCM 补偿的均值统计），并在 `configure()` 中以 D65 典型白平衡增益作为初始值（避免前几帧偏绿）。
     - 新增/完善 `GOC`（Gamma Out Correction）与 `Ccm`（`RKISP1_CIF_ISP_MODULE_CTK` 3×3 色彩校正矩阵，支持根据色温在 ChromeOS 原厂标定的 `A` / `F2_CWF` / `D50` / `D65` 矩阵间自动插值）以及默认启用 `Filter`（去噪与锐化）和 `Dpcc`。
   - 更新 `src/ipa/rkisp1/data/ov5695.yaml` 与 `src/ipa/rkisp1/data/ov2685.yaml`：完整合入 ChromeOS 原厂标定的 `BlackLevelCorrection`、`Ccm`、`GammaOutCorrection`、`Filter` 与 `LensShadingCorrection` 参数。
3. **构建 `libcamera` + `ipa_rkisp1` + `cam` 并实机抓拍验证**：
   - 在 `external/libcamera/Android.bp` 中添加 `rkisp1` pipeline、`ipa_rkisp1.so` 与 `cam` CLI 工具构建目标。
   - 推送至平板 `/data/local/tmp/cam_test/`，直接用 `cam -l` 验证双摄枚举，并用 `cam -c 1 -C10 -F` 和 `cam -c 2 -C10 -F` 实机抓取后置 `ov5695` 与前置 `ov2685` 的画面，拉回主机转换为 PNG 图像核验色彩还原度！

### 阶段 B：Android Camera HAL v3（`camera.libcamera`）与 AIDL Camera Provider 联调（已完成）

1. **编写 Scarlet 专属的 `/vendor/etc/libcamera/camera_hal.yaml`（解决前置摄像头上下颠倒问题）**：
   - **前置 `ov2685` 上下颠倒的几何根因与修复**：
     - 在阶段 A 原生传感器无旋转抓拍测试中，当平板处于横屏姿态（`deviceDegrees = 90`）时，后置主摄 `ov5695`（`/base/i2c@ff160000/camera@36`）原生输出画面为正立（需 `0°` 旋转），而**前置副摄 `ov2685`（`/base/i2c@ff160000/camera@3c`）因传感器物理贴装方向与寄存器 `REG_FORMAT1 (0x3820) = 0x00`（未开启内部翻转）导致原生输出画面上下颠倒（需 `180°` 旋转）**。
     - 根据 Android Camera2 规范：
       - 后置摄像头（`LENS_FACING_BACK`）预览旋转角公式为 \(\text{displayRotation} = (\text{sensorOrientation} - \text{deviceDegrees} + 360) \bmod 360\)。代入 \(\text{deviceDegrees} = 90^\circ, \text{displayRotation} = 0^\circ\)，得后置 `rotation: 90`。
       - 前置摄像头（`LENS_FACING_FRONT`）预览旋转角公式为 \(\text{displayRotation} = (360 - (\text{sensorOrientation} + \text{deviceDegrees}) \bmod 360) \bmod 360\)。若前置传感器未颠倒（\(\text{displayRotation} = 0^\circ\)），原本应填 `270`；但由于 `ov2685` 原生画面上下颠倒（需令 \(\text{displayRotation} = 180^\circ\)），代入公式得 \((360 - (\text{sensorOrientation} + 90)) \bmod 360 = 180 \implies \text{sensorOrientation} = 90^\circ\)！
   - 因此，在 `device/google/gru/etc/camera/camera_hal.yaml`（安装至 `/vendor/etc/libcamera/camera_hal.yaml` 与 `/vendor/etc/camera/libcamera/camera_hal.yaml`）中将前后摄均配置为 `rotation: 90`：
     ```yaml
     cameras:
       "/base/i2c@ff160000/camera@36":
         location: back
         rotation: 90
       "/base/i2c@ff160000/camera@3c":
         location: front
         rotation: 90
     ```
2. **构建 Android Camera HAL v3 与 Camera Provider 服务并修复深层兼容性与拍照稳定性问题**：
   - 在 `external/libcamera/Android.bp` 中新增 `camera.libcamera`（安装并映射为 `/vendor/lib64/hw/camera.gru.so`），链接 `libjpeg` + `libyuv_static` + `libgbm_upstream`，配合 `android.hardware.camera.provider-service.lineage` 注册 `android.hardware.camera.provider.ICameraProvider/internal/0`。
   - **修复 1（相机 ID 顺序固定）**：在 `PipelineHandlerRkISP1::match()`（`src/libcamera/pipeline/rkisp1/rkisp1.cpp`）中对 `ispSink_->links()` 排序，确保后置主摄 `ov5695 7-0036` 始终先注册为 `Camera ID: 0`（`BACK`），前置副摄 `ov2685 7-003c` 注册为 `Camera ID: 1`（`FRONT`）。
   - **修复 2（`cros_gralloc_handle` 与 `minigbm` Buffer 导入）**：
     - 在 `src/android/mm/BufferAdapter.cpp` 中增加对 `cros_gralloc` 原生句柄（`magic == 0xABCDDCBA`）的直接解析，从 `fds[0]`、偏移、步幅和大小填充 plane 信息。
     - 在 `src/android/mm/minigbm_allocator.cpp` 的 `CreateMinigbmAllocator()` 中优先打开 `/dev/dri/card0`（若意外获得 DRM Master 则立即 `drmDropMaster` 以免抢占 `composer`），避免 `minigbm_create_default_device()` 打开 VGEM 导致 `RKISP1` DMA-BUF 分配失败。
     - 在 `src/android/mm/cros_camera_buffer.cpp` 的 `jpegBufferSize()` 中返回 `std::min<size_t>(bufferManager_->GetPlaneSize(handle_, 0), maxJpegBufferSize)`，防止 `Exif`/`PostProcessorJpeg` 写出越界。
     - 在 `src/android/camera_stream.cpp` 中为相机流补充 `GRALLOC_USAGE_HW_CAMERA_WRITE | GRALLOC_USAGE_SW_READ_OFTEN | GRALLOC_USAGE_SW_WRITE_OFTEN`。
   - **修复 3（`RKISP1` 64 字节 DMA 行步幅对齐与纵横比校验）**：
     - `minigbm` 的 `rockchip` 后端将 `NV12` 缓冲区行步幅按 64 字节对齐，而 `rkisp1` V4L2 节点要求 `bytesperline == width`。当配置 `1920x1080`（`1920` 可被 64 整除）与 `1280x720` 时正常，但若枚举出宽度不能被 64 整除的分辨率（如 `2592x1944`、`1440x1080`、`720x480`、`176x144`），`minigbm` 分配的 `stride` 与 `V4L2` 的 `bytesperline` 不一致会导致预览画面斜纹撕裂或 `CameraStream::process()` 拷贝崩溃。在 `src/android/camera_capabilities.cpp` 中过滤 `cameraResolutions` 仅保留 `width % 64 == 0` 的分辨率（后置最高 `2560x1920`，前置最高 `1600x1200`），并在 `RkISP1Path::validate()`（`src/libcamera/pipeline/rkisp1/rkisp1_path.cpp`）中移除 `.boundedToAspectRatio(resolution)` 以免传感器 `2592x1944` 将 `maxResolution_` 截断为非 64 对齐的 `2592x1944`。
   - **修复 4（多路流映射与静态元数据补齐）**：
     - 在 `src/android/camera_capabilities.cpp` 中将硬件级别设为 `ANDROID_INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED`，将 `ANDROID_REQUEST_MAX_NUM_OUTPUT_STREAMS` 设为 `{ rawStreamAvailable_, 2, 1 }`，并补齐 `ANDROID_LENS_INFO_AVAILABLE_APERTURES`（后置 `2.0f` / 前置 `2.4f`）与 `ANDROID_LENS_INFO_AVAILABLE_FOCAL_LENGTHS`（后置 `2.35f` / 前置 `2.1f`）。
     - 在 `src/android/camera_device.cpp` 中使用 `buildStreamConfigsDefault()`（使 `JPEG` 流复用内部/映射 `NV12` 流），当应用请求超过 2 路硬件流时将额外的次级 YUV 流作为 `CameraStream::Type::Mapped` 挂载到主 `Direct` YUV 流上由 `PostProcessorYuv`（`libyuv`）缩放生成。
   - **修复 5（Camera3 快门通知严格保序与请求取消处理）**：
     - Android `Camera3Device` 要求必须在首个输出缓冲区完成前收到 `CAMERA3_MSG_SHUTTER`（`notifyShutter`），且**不同帧的 `notifyShutter` 必须严格按 `frameNumber` 提交顺序且时间戳单调递增**。当后置双路流（`selfPath` 预览 + `mainPath` 拍照）并发时，原本为空队列的 `mainPath`（`/dev/video3`）可能在 `selfPath`（`/dev/video4`）之前几毫秒先完成上一帧的出队，若在 `bufferReady()` 直接发送 `SensorTimestamp` 会导致 `Camera3-Device: notifyShutter: Shutter notification out-of-order`。在 `PipelineHandlerRkISP1` 中新增 `notifyShutterUpTo()`，在 `statReady()`（`/dev/video5` 严格按 FIFO 顺序出队）与 `bufferReady()` 中按 `RkISP1Frames` 的 `frame` 升序补齐并发送单调递增的 `controls::SensorTimestamp`。
     - 在 `PipelineHandlerRkISP1::stopDevice()` 中清理并取消残留在 `data->queuedRequests_` 中的请求（将 `PipelineHandler::cancelRequest` 移至 `protected`），将 `RkISP1Frames::find()`（`src/libcamera/pipeline/rkisp1/rkisp1.cpp`）中未找到帧时的日志级别从 `LOG(RkISP1, Fatal)` 改为 `LOG(RkISP1, Debug)`，并在 `CameraDevice::flushAndStop()` 中先调用 `camera_->stop()` 再等待 `pendingRequestsCv_`，且在 `CameraDevice::completeRequestDescriptor()` 处理 `Cancelled` 状态请求时发送 `CAMERA3_MSG_ERROR_REQUEST` 而非无快门时间戳的 `finalResult_`，彻底消除前后摄来回切换时的崩溃。
   - **修复 6（内核 `rockchip-isp1.ko` 双路流 `min_queued_buffers` 死锁修复）**：
     - **现象**：LineageOS `Aperture` 相机启动时同时配置两路流：Stream 0（`1600x1200 NV12` 实时预览 -> `selfpath` `/dev/video4`）与 Stream 1（`2560x1920 MJPEG` 拍照 -> 内部 `2560x1920 NV12` -> `mainpath` `/dev/video3`）。预览期间 `Aperture` 仅向 `/dev/video4` 入队缓冲区，仅在按下快门的那一帧向 `/dev/video3` 入队 **1 个**缓冲区。
     - **根因**：`6.6.34` 内核的 `drivers/media/platform/rockchip/rkisp1/rkisp1-capture.c` 定义了 `#define RKISP1_MIN_BUFFERS_NEEDED 3`（将 `vb2_queue.min_queued_buffers` 设为 `3`）。尽管 `rkisp1` 驱动本身已经实现了硬件 `dummy buffer`（`cap->buf.dummy`，无用户缓冲区时自动将 DMA 写入 dummy buffer），但 `vb2` 核心因 `queued_count (1) < min_queued_buffers (3)` 拒绝在 `/dev/video3` 上调用 `rkisp1_vb2_start_streaming()`，导致按下快门后拍照流永远无法出帧！
     - **修复**：参照上游 Linux 6.8+ 提交（*"media: rkisp1: Drop RKISP1_MIN_BUFFERS_NEEDED"*），将 `rkisp1-capture.c` 中的 `RKISP1_MIN_BUFFERS_NEEDED` 从 `3` 改为 `0` 并更新 `rockchip-isp1.ko`。修改后 `/dev/video3` 在 `VIDIOC_STREAMON` 时立即以 dummy buffer 启动流，并在按下快门入队单帧缓冲区时当场完成 DMA 采集与 `PostProcessorJpeg` 软件编码！
   - **修复 7（拍照期间 `FCQueue` 环形队列被 V4L2 硬件帧序号跳变覆盖导致的 `Fatal` 崩溃）**：
     - **根因**：`Aperture` 在按下快门准备单帧拍照（`PRE_CAPTURE -> MAIN_CAPTURE`）期间会暂停提交预览请求约 500ms（约 15 个硬件帧），此时 `rkisp1` 硬件仍在通过 `dummy buffer` 递增 V4L2 `buffer->metadata().sequence`。当请求恢复入队后，`PipelineHandlerRkISP1::statReady()` 中的 `if (data->frame_ <= buffer->metadata().sequence) data->frame_ = buffer->metadata().sequence + 1;` 将软件请求帧号 `data->frame_` 直接跳变了 16（恰等于 `kMaxFrameContexts = 16`），使新入队的请求覆盖了仍在飞行中的上一帧 `FCQueue` 槽位（`138 % 16 == 122 % 16`），29ms 后上一帧的 `statReady` 调用 `FCQueue::get()` 触发 `LOG(FCQueue, Fatal)` 直接 `abort()` 杀死 Camera Provider 服务。
     - **修复**：移除 `PipelineHandlerRkISP1::statReady()` 中将 `data->frame_` 同步为硬件 `sequence` 的跳变逻辑（使 `data->frame_` 严格按请求 1:1 递增，而 `delayedCtrls_->get()` 仍使用硬件 `sequence`），将 `src/ipa/rkisp1/rkisp1.cpp` 中的 `kMaxFrameContexts` 从 `16` 扩大至 `64`，并将 `src/ipa/libipa/fc_queue.h` 中槽位冲突的日志级别从 `Fatal` 降为 `Warning`。
   - **修复 8（拍照与预览并发时 `paramBuffers_` / `statBuffers_` 与 `V4L2BufferCache` 槽位耗尽）**：
     - **根因**：拍照帧（1 个内部缓冲区）与后续立即恢复的 4 个预览帧（4 个客户端缓冲区）同时在管线中飞行时，并发请求数达到 `5`，超过了 `RkISP1` 默认分配的 `4` 个参数/统计缓冲区（报错 `Parameters buffer underrun`）以及 `RkISP1Path::start()` 默认 `video_->importBuffers(4)` 的 4 个 V4L2 DMABUF 缓存槽位（前置摄像头预览与拍照共用 `mainPath` 时第 5 个缓冲区报错 `Fail to get buffer from cache. ret = -2` 并导致请求永久挂起）。
     - **修复**：在 `PipelineHandlerRkISP1::allocateBuffers()` 中将 `paramBuffers_` / `statBuffers_` 数量提升至内核上限 `8`（`RKISP1_ISP_PARAMS_REQ_BUFS_MAX`），并在 `RkISP1Path::start()`（`src/libcamera/pipeline/rkisp1/rkisp1_path.cpp`）中将 `video_->importBuffers()` 的 DMABUF 描述符槽位扩大至 `16`。
   - **修复 9（`isp_->frameStart` 信号仅分发给当前活动摄像头）**：
     - `PipelineHandlerRkISP1::createCamera()` 原本将 `isp_->frameStart` 同时连接到前后两个传感器的 `delayedCtrls_`，导致后置工作时每帧也向未流式传输的前置传感器下发寄存器控制。改为在 `match()` 中连接至 `PipelineHandlerRkISP1::frameStart()`，仅转发给当前 `activeCamera_` 的 `delayedCtrls_->applyControls(sequence)`，并在 `start()` 中调用 `delayedCtrls_->reset()`。
   - **注（Vendor 可执行文件启动环境）**：手动拉起 `/vendor/bin/hw/android.hardware.camera.provider-service.lineage` 时**切勿设置 `LD_LIBRARY_PATH=/vendor/lib64`**，否则会破坏 Android Linker Namespace，迫使 LLNDK 的 `/system/lib64/libbinder_ndk.so` 错误加载 `/vendor/lib64/libbinder.so`（默认连接 `/dev/vndbinder` 而非 `/dev/binder`），导致 `ABinderProcess_setThreadPoolMaxThreadCount` 卡在等待 `/dev/vndbinder`。直接运行 `/vendor/bin/hw/android.hardware.camera.provider-service.lineage` 即可正常注册到 `/dev/binder` 的 `servicemanager`。

### 阶段 C：固化打包进 `device/google/gru` 与 `super.img`（已刷入实机验证通过，含相机有声录像修复）

1. **内核模块打包与自动加载**：
   - 将 `6.6.34-phase2` 的 6 个摄像头内核模块（`videobuf2-vmalloc.ko`、`v4l2-async.ko`、`v4l2-fwnode.ko`、`ov5695.ko`、`ov2685.ko` 以及包含 `RKISP1_MIN_BUFFERS_NEEDED = 0` 修复的 `rockchip-isp1.ko`）放入 `device/google/gru/modules/`，并在 `device/google/gru/device.mk` 中配置拷贝至 `/vendor/lib/`。
   - 在 `device/google/gru/init.gru.rc` 的 `on early-init` 阶段按依赖顺序自动加载上述 6 个模块。
2. **V4L2 设备节点权限配置**：
   - 在 `device/google/gru/ueventd.gru.rc` 中新增 `/dev/v4l-subdev* 0660 media camera`，与 `/dev/video*`、`/dev/media*` 保持一致，供以 `cameraserver`（属 `camera` 组）身份运行的 `vendor.camera.provider` 直接访问。
3. **Camera HAL、Provider 服务、ISP 调校与特性声明打包**：
   - 在 `device/google/gru/device.mk` 中设置 `ro.hardware.camera=libcamera`，使 `hw_get_module("camera", ...)` 自动加载 `/vendor/lib64/hw/camera.libcamera.so`。
   - 在 `PRODUCT_PACKAGES` 中加入 `android.hardware.camera.provider-service.lineage`（自动打包服务二进制、`android.hardware.camera.provider-service.lineage.rc` 及 VINTF fragment `android.hardware.camera.provider-service.lineage.xml`）、`camera.libcamera`、`ipa_rkisp1`、`cam`、`libcamera_ipa_rkisp1_ov5695.yaml` 与 `libcamera_ipa_rkisp1_ov2685.yaml`。
   - 在 `PRODUCT_COPY_FILES` 中打包 `device/google/gru/etc/camera/camera_hal.yaml` 至 `/vendor/etc/camera/libcamera/camera_hal.yaml` 与 `/vendor/etc/libcamera/camera_hal.yaml`，并声明 `android.hardware.camera.xml`（包含 `android.hardware.camera.any` 与 `android.hardware.camera`）及 `android.hardware.camera.front.xml` 权限特性。
   - 将 `external/libcamera` 与内核 `rkisp1-capture.c` 的全部改动归档为 `patches/external_libcamera_rkisp1_camera_hal.patch` 与 `patches/kernel_6.6.34_rkisp1_min_buffers_needed.patch`，并更新 `patches/apply-patches.sh`。
4. **相机有声录像（`00:00` 计时卡死与无法保存）根因定位与修复**：
   - **现象**：刷入 `super.img` 开机后，前后摄预览与拍照完全正常，但在 `Aperture` 中切换到录像模式点击快门后，计时器一直停在 `00:00` 且点击停止后无文件保存。
   - **根因**：`c2.android.avc.encoder` 视频编码器本身工作完全正常（`1280x720@30fps` 持续产出 H.264 关键帧），但 CameraX `Recorder` 在有声录像模式下必须等待 `AudioRecord` 送来**第一帧音频采样**以对齐音视频起始时间戳后才启动 `MediaMuxer`。由于（1）`hardware/interfaces/audio/aidl/default/XsdcConversion.cpp` 无条件将 `IN_MICROPHONE` 的地址覆写为 `"bottom"` 导致 `StreamPrimary` 丢失 `CARD_0_DEV_1` 回退打开无录音能力的 `device 0`（`MAX98357A`）；（2）`DA7219` 默认 `Out DAIR Mux = Tone Generator` 激活了 `DAIOUT`，在共享的 `I2S0_SDI_0` 数据线上输出全 `0` 压制了内置 `ADAU7002` DMIC（`pcmC0D1c`）；（3）`MAX98357A` 与 `DMIC` 共用 `ff880000.i2s` 时钟，播放快门/录像提示音（`48000 Hz`）的同时以 `44100 Hz` 打开 `pcmC0D1c` 会被 `rockchip_i2s` 的 `symmetric_rate` 拒绝（`-EINVAL`）。
   - **修复**：修补 `XsdcConversion.cpp`（仅在 XML 未显式指定 `address` 时才填 `"bottom"`）与 `StreamPrimary.cpp`（支持 `CONNECTION_ANALOG -> device 2` 并在 `setConnectedDevices` 时自动切换 ALSA Mixer 的 `Out DAIL/R Mux = ADC`、`Int Mic Switch` / `Headset Mic Switch` 与 `Speakers Switch` / `Headphones Switch`），同时在 `audio_policy_configuration.xml` 中将 `primary input` 与麦克风端口统一固定为 `48000 Hz` + `AUDIO_CHANNEL_IN_STEREO`（由 `AudioFlinger` 自动重采样/下混至应用请求的 `44100 Hz` 单声道）。实机验证 `Aperture` 有声录像计时、落盘与音画同步全部正常，最新 `super.img` SHA-256 为 `3edf21df7fc3fa656fc9c0506abcd34f6caa0e0610254149228a4252560e0ce4`。

---

## 三、事件与验证日志

| 日期 | 阶段 | 事件与结果记录 |
| :--- | :--- | :--- |
| 2026-10-21 | 调查 & 阶段 A.1 | 在运行 `6.6.34-phase2` 内核的 Scarlet 实机（`10.0.0.109:35103`）上提取并热加载 `v4l2-async.ko`、`v4l2-fwnode.ko`、`videobuf2-vmalloc.ko`、`ov5695.ko`、`ov2685.ko`、`rockchip-isp1.ko` 共 6 个模块。内核一次性探测出 `ov5695 7-0036` 与 `ov2685 7-003c` 并注册 `rkisp1`（`/dev/media2`、`/dev/video3..6`、`/dev/v4l-subdev0..5`），证实 `6.6.34-phase2` 内核驱动完全正常。 |
| 2026-10-21 | 调查 | 定位出 `libcamera` 无法识别 `ov5695` 的根因（`camera_sensor_helper.cpp` 缺失 `CameraSensorHelperOv5695`）以及 postmarketOS `7.x` 画面发灰/发绿无彩色的根因（`ov5695.yaml` / `ov2685.yaml` 仅含 LSC，缺失 `BLS` 黑电平扣除、`CTK` 3×3 色彩校正矩阵与 `GOC` 伽马曲线）；从 ChromiumOS `overlay-scarlet` 提取出 `OV5695_lens_CHT-842B-MD.xml` 与 `OV2685.xml` 完整原厂 ISP 标定参数。 |
| 2026-10-21 | 阶段 A.2 & A.3 | 补齐 `CameraSensorHelperOv5695` 与 `ov5695` 传感器属性，在 `ov5695.yaml` / `ov2685.yaml` 中合入 ChromeOS 原厂 `BlackLevelCorrection`、`Ccm`、`GammaOutCorrection`、`Filter`、`Dpcc` 与 `LensShadingCorrection` 参数，修复 `Awb` 空统计帧保护与 RGB 统计模式并修正 `Ccm` 矩阵行主序映射；实机运行 `cam` CLI 抓拍验证前后双摄色彩还原准确，同时发现前置 `ov2685` 原生画面上下颠倒（旋转了 180°）。 |
| 2026-10-21 | 阶段 B | 构建 `camera.libcamera.so` 与 `android.hardware.camera.provider-service.lineage`；在 `camera_hal.yaml` 中将后置 `/base/i2c@ff160000/camera@36`（`back`）与前置 `/base/i2c@ff160000/camera@3c`（`front`）均设为 `rotation: 90` 解决前置上下颠倒问题；修复 `cros_gralloc_handle` 解析、`minigbm` `/dev/dri/card0` 分配、64 字节行步幅对齐、Camera3 快门时间戳顺序、停流请求取消、`rockchip-isp1.ko` 的 `RKISP1_MIN_BUFFERS_NEEDED = 0` 双路流拍照卡死、`FCQueue` 帧序号跳变覆盖、`paramBuffers_`/`V4L2BufferCache` 槽位耗尽以及 `isp_->frameStart` 信号分发问题。实机在 LineageOS `Aperture` 相机应用中成功完成前后摄连续实时预览、前后摄切换及 `2560x1920`（后置）/ `1600x1200`（前置）连续 JPEG 拍照保存验证。 |
| 2026-10-21 | 阶段 C | 将 6 个摄像头内核模块、自动加载规则、`/dev/v4l-subdev*` 权限、`ro.hardware.camera=libcamera`、`camera.libcamera`、`ipa_rkisp1`、`android.hardware.camera.provider-service.lineage`、`camera_hal.yaml`、ISP 调校文件及相机 feature XML 全数集成进 `device/google/gru`，归档补丁并成功编译生成 `super.img`（`d621bf5c1a01589095eab6111fcc8a37f3ba5905a6ae6f0702572af9c799072d`）。 |
| 2026-10-21 | 阶段 C（录像收尾） | 刷入镜像重启回 Android 后验证相机开机即用；进一步定位出 `Aperture` 录像卡在 `00:00` 是因为 CameraX `Recorder` 等待 `AudioRecord` 首帧音频才启动 `MediaMuxer`，而内置 DMIC（`pcmC0D1c`）因 `XsdcConversion.cpp` 覆写 `address="bottom"`、`DA7219` `Out DAIR Mux` 总线竞争与 `I2S0` 48kHz 对称时钟约束导致打开失败。修复 AIDL Audio HAL 与 `audio_policy_configuration.xml` 后，实机系统录音机与 `Aperture` 有声视频录制（`1280x720@30fps` H.264 + AAC）均验证通过，生成新 `super.img`（`3edf21df7fc3fa656fc9c0506abcd34f6caa0e0610254149228a4252560e0ce4`）。 |
