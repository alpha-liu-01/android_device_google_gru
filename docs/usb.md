# 全功能 Type-C USB 与 DP Alt Mode 调查与修复计划

返回 [总路线](roadmap.md) | 对照 [阶段 4](phase-4.md)

本文档记录 Google Scarlet（`rk3399-gru-scarlet-kd`，运行基于主线 `6.6.34-phase2` 内核的 LineageOS 23.2 / Android 16）在阶段 4.5 中针对单口全功能 Type-C 接口（`usbc_extcon0` / `usbdrd3_0` / `fe800000.usb` / `cdn-dp` / `CROS_USBPD_CHARGER0`）四项实机测试现象的日志取证、源码级根因分析与分步修复方案。

---

## 1. 实机测试现象总览

| 序号 | 测试场景 | 实机表现 | 当前状态 |
| :--- | :--- | :--- | :--- |
| **1** | **USB PD 快充（9V）** | 插拔 9V PD 充电器识别迅速，电压/电流正常，状态栏充电指示与断电恢复均正常。 | **已正常** |
| **2** | **DP Alt Mode（USB-C 一线通便携屏）** | 插入 USB-C 便携屏能够成功握手并弹出「镜像显示」确认框，甚至短暂点亮外接屏；但开始投屏后几秒钟立刻断开，随后系统再次弹出连接提示，陷入「连接 -> 几秒后断开 -> 重连」死循环。 | **链路已通，存在 VBUS 过流复位与 VOP 缩放报错** |
| **3** | **连接 PC（有线 adb / MTP / PTP）** | 插入电脑无 `adb`、无 MTP、无 USB 模式选择通知，仅触发充电动画；且**拔下连接电脑的数据线后，平板上的充电状态会一直常驻（卡死）**，必须用一根纯充电线（PD/DCP）插上再拔下才能解除。 | **缺 UDC（写死 `dr_mode="host"`），且 `cros_usbpd-charger` 存在拔线漏发 uevent 缺陷** |
| **4** | **USB-C 音频（Type-C 转 3.5mm DAC 声卡）** | 插入在 Windows / Linux PC 上免驱即插即用的 USB-C DAC（`06cb:1595 NICEHCK HiFi Audio`）完全无反应，音频输出仍走内置扬声器，系统未切换至 USB 耳机。 | **USB 枚举已通，缺 `snd-usb-audio.ko`、音频策略与 VINTF 声明** |

---

## 2. 逐项日志核实与根因分析

### 2.1 现象 1：USB PD 快充（9V）完全正常

- **内核与 sysfs 实测数据**（`/sys/class/power_supply/CROS_USBPD_CHARGER0/uevent` 与 `sbs-9-000b/uevent`）：
  - `POWER_SUPPLY_STATUS=Charging`
  - `POWER_SUPPLY_ONLINE=1`
  - `POWER_SUPPLY_USB_TYPE=C [PD] DCP CDP SDP`（当前激活为 `[PD]`）
  - `POWER_SUPPLY_VOLTAGE_MAX_DESIGN=9000000`（9.0 V 握手成功）、`POWER_SUPPLY_VOLTAGE_NOW=8800000`（8.8 V）
  - `POWER_SUPPLY_CURRENT_MAX=3000000`（3.0 A，最高 27 W）
  - `sbs-9-000b`：`POWER_SUPPLY_STATUS=Charging`、`POWER_SUPPLY_CURRENT_NOW=3215000`（+3.215 A 充入电芯）
- **机制确认**：
  - `cros_usbpd-charger.ko` 通过 ChromeOS EC 的 `EC_CMD_USB_PD_POWER_INFO` 获取 PD 协商电压与电流上限，配合阶段 4 第 8 步打入的 `system/core/healthd/BatteryMonitor.cpp` 补丁（`patches/system_core_healthd_battery_monitor.patch`，将无 `type` 文件但含 `usb_type` 的 `CROS_USBPD_CHARGER*` 归类为 `ANDROID_POWER_SUPPLY_TYPE_AC`），`healthd` 与 `BatteryService` 均能准确识别 `AC powered: true, Max charging current: 3000000, Max charging voltage: 9000000`。

---

### 2.2 现象 2：USB-C 便携屏（DP Alt Mode）成功连接几秒后立即断开并循环重弹提示

在实机测试期间（`13:49:33` 至 `13:52:47`），`dmesg` 与 `logcat` 完整记录了便携屏 **14 次**（`displayId=2` 至 `displayId=15`）连接与断开的全过程。

#### （1）已跑通的部分：DP Alt Mode 握手、固件加载与 4K 链路训练全部成功
- `init.gru.rc` 在 `early-init` 将 `/sys/module/firmware_class/parameters/path` 指向 `/vendor/firmware`，内核 `cdn-dp fec00000.dp` 成功加载 `/vendor/firmware/rockchip/dptx.bin`。
- 当插入便携屏时，`extcon-usbc-cros-ec`（`extcon1`）检测到 `DISP_DP=1`，通知 `phy-rockchip-typec`（`tcphy0`）与 `cdn-dp` 完成 DisplayPort Link Training，并通过 EDID 读出便携屏首选模式为 **`3840x2160@60Hz`**：
  ```
  [  330.678950] cdn-dp fec00000.dp: [drm:cdn_dp_pd_event_work] Connected, not enabled. Enabling cdn
  05-12 13:49:33.296 I drmhwc  : Attaching pipeline 'DP-1' to the display #1
  05-12 13:49:33.307 I DisplayDeviceRepository: Display device added: DisplayDeviceInfo{"外接屏幕": uniqueId="local:4627039422300187648", 3840 x 2160, modeId 2, renderFrameRate 60.000004, ..., type EXTERNAL, address {port=0, model=0x401966a88180a}}
  ```

#### （2）几秒后立刻断开并重连的根因一（物理层主因）：一线通便携屏开启背光瞬间抽走巨额电流，触发 Type-C VBUS 过流保护（OCP）与电压跌落复位
对比 `logcat` 中 `SurfaceFlinger` 开启外接屏镜像的时间戳与 `healthd` 电池电流/电压采样，可以精确还原每一次断开的物理过程：
1. **前 3.5 秒（等待确认 / 尚未输出视频信号，便携屏背光关闭）**：
   - `13:49:33.296` 插入便携屏，系统弹出 `MirrorDisplayConfirmDialog`（「是否镜像显示？」），此时 `DP-1` 尚未执行 modeset 点亮，便携屏背光未开。
   - `13:49:33.597` `healthd` 记录电池放电电流完全正常：`l=69 v=3966 t=28.6 h=2 st=3 c=-867000`（放电电流仅 **0.867 A**，电池电压 **3.966 V**）。
2. **开启投屏瞬间（便携屏点亮 4K 背光，直接从平板 Type-C 口抽电）**：
   - `13:49:37.241` 用户点击确认投屏，`DisplayManagerService` 将 `displayId=2` 设为 `layerStack=0`，`13:49:37.256` `drmhwc` 开始向 `DP-1` 输出 `3840x2160@60Hz` 视频流，便携屏收到视频信号后立即开启面板与背光。
   - 由于便携屏未接独立外部电源，其全部功耗由 Scarlet 的 Type-C 口作为 Source（`power_role=source`，由板载 `pp5000` 5V 升压轨供电，设计限流仅 500mA～1.5A）提供。
   - `healthd` 紧接着在每次点亮外接屏的同一秒采样到了极其惊人的电池端抽电峰值与电压骤降：
     - `13:49:49.555`：`v=3615 c=-4845000`（放电电流飙升至 **4.85 A**，电芯电压跌至 **3.615 V**）
     - `13:49:57.684`：`v=3582 c=-5353000`（放电电流飙升至 **5.35 A**，单节电芯瞬时输出功率达 **19.2 W**！电芯电压跌至 **3.582 V**）
     - `13:50:03.657`：`v=3555 c=-5153000`（放电电流 **5.15 A**，电芯电压跌至 **3.555 V**）
     - `13:50:10.892`：`v=3570 c=-4945000`（放电电流 **4.95 A**）
     - `13:50:38.494`：`v=3572 c=-5029000`（放电电流 **5.03 A**）
3. **EC 触发 VBUS 过流切断 -> 断开 -> 1 秒后重新握手循环**：
   - 便携屏从 5V VBUS 抽取超过 2A～3A 的电流，立即触发 ChromeOS EC 的 Type-C VBUS 过流保护（Over-Current Protection）及 5V 轨欠压保护，EC 硬件切断 VBUS 并复位 PD 端口状态机：
     ```
     [  349.146995] cdn-dp fec00000.dp: [drm:cdn_dp_pd_event_work] Not connected. Disabling cdn
     05-12 13:49:51.766 I drmhwc  : Detaching pipeline 'DP-1' from the display #1
     ```
   - 便携屏断电黑屏后负载消失，约 1.2 秒后 EC 重新检测到 CC 引脚上的 Rd 下拉电阻，再次建立 Type-C 连接并进入 DP Alt Mode（`[350.337] Connected, not enabled. Enabling cdn`），Android 随即把它当作一台新插入的显示器（`display #2`、`display #3`……），再次弹窗、点亮背光、过流断电，形成死循环。
   - **结论**：使用单根 C-to-C 线直连便携屏时，**必须给便携屏接上外接电源**（使其通过 PD Power Role Swap 成为供电方 Sink/Source，或至少不从平板 VBUS 抽背光电流），平板的单节电池与 5V OTG 升压电路在物理上无法拖动一台未外接供电的 4K 便携屏。

#### （3）几秒后异常的根因二（软件层 DRM/HWC 缺陷）：RK3399 VOP 图层缩放限制导致 `drmhwc` 狂刷 `errno=34 (ERANGE)` 与 `Client layer must be always usable by DRM/KMS`
在每次 `DP-1` 连接期间，`logcat` 均高频刷出以下错误：
```
05-12 13:49:37.256 E drmhwc  : Client layer must be always usable by DRM/KMS
05-12 13:49:37.256 E drmhwc  : Failed to create AtomicCommitArgs for frame composition.
05-12 13:49:49.026 W drmhwc  : Test-only seamless=0 ret=-34 errno=34 strerror=Math result not representable
```
经核查内核 `drivers/gpu/drm/rockchip/rockchip_vop_reg.c`、`rockchip_drm_vop.c` 与 `external/drm_hwcomposer`：
1. **为什么报 `errno=34`（`-ERANGE`，`Math result not representable`）**：
   - 内置 DSI 屏幕分辨率为竖屏 `1536x2048`，而便携屏首选模式为横屏 `3840x2160`。当开启镜像模式时，`SurfaceFlinger` 将 `1536x2048` 的应用图层缩放到 `3840x2160` 的显示区域内。
   - 在 `rockchip_vop_reg.c:966`（`rk3399_vop_win_data`）中，VOP Big（`vopb`，支持最高 `4096x2160`）共有 4 个硬件图层（Plane）：
     - `win0`（Primary）与 `win1`（Overlay 0）：绑定 `rk3399_win01_data` / `rk3368_win01_data`，带有硬件缩放器 `.scl = &rk3288_win_full_scl`（支持 `1/8x`～`8x` 缩放）。
     - `win2`（Overlay 1）与 `win3`（Cursor）：绑定 **`rk3368_win23_data`，没有硬件缩放器（`.scl = NULL`）**！
   - 在 `rockchip_drm_vop.c:949`（`vop_plane_atomic_check`）中，当 `win->phy->scl == NULL` 时，`min_scale` 与 `max_scale` 均被设为 `DRM_PLANE_NO_SCALING`（`1.0x`，即 `0x10000`）。
   - 然而 `drm_hwcomposer` 的 `DrmPlane::IsValidForLayer()`（`external/drm_hwcomposer/drm/DrmPlane.cpp:199`）在分配 Plane 时只检查了旋转、Alpha、混合模式和像素格式，**并未知道 `win2` 不支持缩放**，于是将需要缩放（`1536x2048 -> 3840x2160`）的第 3 个图层分给了 `win2`。
   - 当 `drmhwc` 执行 `DRM_MODE_ATOMIC_TEST_ONLY` 时，内核 `drm_atomic_helper_check_plane_state()`（`drivers/gpu/drm/drm_atomic_helper.c:896`）检测到缩放比不为 `1.0` 而 Plane 只允许 `DRM_PLANE_NO_SCALING`，直接返回 **`-ERANGE`（`-34`）**，`drmhwc` 打印警告后回退到 GPU Client Composition。
2. **为什么报 `Client layer must be always usable by DRM/KMS`**：
   - 在 `HwcDisplay.cpp:718`（`CreateModesetCommit`）与 `863`（`CreateFrameUpdateCommit`）中，当 `DP-1` 首次绑定或所有图层需要缩放但 `ValidateDisplay` 首帧尚未拿到 `SurfaceFlinger` 渲染好的 `client_layer_` 缓冲区时，`client_layer_.IsLayerUsableAsDevice()` 返回 `false`，导致首帧原子提交被跳过。

---

### 2.3 现象 3：连接 PC 无 `adb` / MTP / 模式选择，且拔线后充电状态在平板上常驻卡死

这一现象包含两个相互独立但共同作用的问题：**A. 为什么连电脑没有 `adb` / MTP**；**B. 为什么拔下电脑连接线后充电状态会卡死常驻，且必须插拔一次纯充电线才能解除**。

#### A. 为什么连接 PC 没有 `adb`、没有 MTP、也没有 USB 用途通知？
1. **内核设备树将 `fe800000.usb` 写死为 `dr_mode = "host"`，导致 `/sys/class/udc` 为空**：
   - 查看 `/home/alpha/src/gru-phase2/linux-6.6.34/arch/arm64/boot/dts/rockchip/rk3399-gru.dtsi` 第 662～671 行：
     ```dts
     &usbdrd3_0 {
         status = "okay";
         extcon = <&usbc_extcon0>;
     };

     &usbdrd_dwc3_0 {
         status = "okay";
         dr_mode = "host";
     };
     ```
   - 尽管内核编译配置已经完整启用了双角色与 ConfigFS Gadget：
     - `CONFIG_USB_DWC3_DUAL_ROLE=y`
     - `CONFIG_USB_GADGET=y`
     - `CONFIG_USB_CONFIGFS=y`（含 `F_FS=y`、`F_MTP=y`、`F_PTP=y`、`F_RNDIS=y`、`F_MIDI=y`、`F_ACC=y`、`F_AUDIO_SRC=y`）
   - 但由于 `usbdrd_dwc3_0` 被写死为 `dr_mode = "host"`，`drivers/usb/dwc3/core.c` 只将其初始化为 xHCI Host 控制器，从未调用 `dwc3_drd_init()` 或 `dwc3_gadget_init()`，导致系统内 `/sys/class/udc/` 完全为空。
2. **用户空间在阶段 3/4 临时关闭了 USB ConfigFS 与 Gadget 服务**：
   - 当没有 UDC 时，LineageOS 的 `com.android.hardware.usb.gadget.mainline` APEX 服务在启动时会因为 `sys.usb.controller` 为空而调用 `abort()` 崩溃重启，且 `adbd` 若看到 `/dev/usb-ffs/adb` 存在会死循环刷屏。
   - 因此当前代码在 `device/google/gru/BoardConfig.mk` 与 `device.mk` 中设置了 `TARGET_USB_INIT_SCRIPT := none`，并在 `init.gru.rc` 中设置了 `setprop vendor.usb.configfs 0` 与 `stop usbd`。
3. **为什么插上电脑时平板依然会响一声并播放充电动画？**
   - 因为 ChromeOS EC 的 `extcon-usbc-cros-ec`（`extcon1`）和 HIDL `android.hardware.usb@1.3-service.basic` 是正常工作的！
   - `logcat`（`13:54:58.918`）清晰记录了插入电脑时的状态切换：
     ```
     05-12 13:54:58.918 I android.hardware.usb@1.3-service.basic: uevent received change@/devices/platform/soc/ff110000.spi/spi_master/spi1/spi1.0/cros-ec-dev.1.auto/extcon-usbc-cros-ec.4.auto/extcon/extcon1
     05-12 13:54:58.922 I UsbPortManager: ClientCallback V1_2: otg_default: current_mode=ufp, power_role=sink, data_role=device, can_change_mode=true, can_change_power=false, can_change_data=false
     05-12 13:54:58.924 D UsbDeviceManager: kud.onUsbPortChanged: isRoleHost = false, isRoleDevice = true
     ```
   - 也就是说，Android 框架层的 `UsbPortManager` 已经准确知道「现在作为 Device（UFP）连上了电脑」；但因为内核没有 UDC、没有 Gadget 驱动去枚举 USB 端点，内核永远不会发出 `USB_STATE=CONNECTED / CONFIGURED` 的 `android_usb` uevent，`UsbDeviceManager` 也就不会弹出「正在通过 USB 为此设备充电 — 点按即可查看更多选项（文件传输 MTP / PTP）」的系统通知，PC 端自然也看不到任何 USB 设备。

#### B. 为什么从 PC 拔下数据线后，平板上的充电状态会常驻卡死，且必须插拔一次纯充电器才能解除？
在实机 `logcat`（`13:50:20`、`13:54:58`～`13:58:48`）与内核 `drivers/power/supply/cros_usbpd-charger.c` 源码中，我们彻底查清了这个诡异现象的**两条完整证据链**：

##### 证据链 1：`cros_usbpd-charger.c` 在拔出 PC 数据线（SDP）时漏发 `power_supply_changed()` 通知，且 `ONLINE` 属性读取存在缓存短路 Bug
查看 `/home/alpha/src/gru-phase2/linux-6.6.34/drivers/power/supply/cros_usbpd-charger.c` 第 201～304 行（`cros_usbpd_charger_get_power_info`）：
```c
	last_psy_status = port->psy_status;
	last_psy_usb_type = port->psy_usb_type;

	switch (resp.role) {
	case USB_PD_PORT_POWER_DISCONNECTED:
		port->psy_status = POWER_SUPPLY_STATUS_NOT_CHARGING;
		port->psy_online = 0;
		break;
	case USB_PD_PORT_POWER_SINK:
		port->psy_status = POWER_SUPPLY_STATUS_CHARGING;
		port->psy_online = 1;
		break;
	case USB_PD_PORT_POWER_SINK_NOT_CHARGING:
		port->psy_status = POWER_SUPPLY_STATUS_NOT_CHARGING;
		port->psy_online = 1;
		break;
...
	case USB_CHG_TYPE_NONE:
		/*
		 * For dual-role devices when we are a source, the firmware
		 * reports the type as NONE. Report such chargers as type
		 * USB_PD_DRP.
		 */
		if (resp.role == USB_PD_PORT_POWER_SOURCE && resp.dualrole)
			port->psy_usb_type = POWER_SUPPLY_USB_TYPE_PD_DRP;
		else
			port->psy_usb_type = POWER_SUPPLY_USB_TYPE_SDP;
		break;
...
	if (last_psy_usb_type != port->psy_usb_type ||
	    last_psy_status != port->psy_status)
		power_supply_changed(port->psy);
```
仔细看这段主线内核代码在连接 PC 时的状态变迁：
1. **当连接 PC 时**：
   - PC 的 USB 口是标准下行端口（SDP，5V/500mA）。当平板电池电量较高或 PC 口限流不足以充入电芯时（如 `logcat` `13:54:58.946` 所示）：
     ```
     05-12 13:54:58.946 I healthd : battery l=69 v=4073 t=29.3 h=2 st=3 c=-1240000 fc=8113000 cc=27 chg=u
     ```
   - 此时 EC 返回 `USB_PD_PORT_POWER_SINK_NOT_CHARGING`（或状态变为 `NOT_CHARGING`），`port->psy_online = 1`，`port->psy_status = POWER_SUPPLY_STATUS_NOT_CHARGING`，`port->psy_usb_type = POWER_SUPPLY_USB_TYPE_SDP`。
   - Android 的 `healthd` 读到 `CROS_USBPD_CHARGER0/online == 1`，因此上报 `chg=u`（`BATTERY_PLUGGED_USB = 2`），系统认为**已插电（USB 在线）**，锁屏和状态栏保持插电状态。
2. **当从 PC 拔下数据线时**：
   - EC 报告 `resp.role = USB_PD_PORT_POWER_DISCONNECTED` 且 `resp.type = USB_CHG_TYPE_NONE`。
   - 在 `cros_usbpd_charger_get_power_info()` 中：
     - `port->psy_status` 被设为 `POWER_SUPPLY_STATUS_NOT_CHARGING`（**和拔线前一模一样！** `last_psy_status == port->psy_status`）。
     - 在 `case USB_CHG_TYPE_NONE:` 中，因为 `resp.role != USB_PD_PORT_POWER_SOURCE`，它走进了 `else` 分支，把 `port->psy_usb_type` 设为了 **`POWER_SUPPLY_USB_TYPE_SDP`**（**和拔线前连接 PC 时的 SDP 一模一样！** `last_psy_usb_type == port->psy_usb_type`）。
     - 唯一发生变化的是 `port->psy_online`（从 `1` 变成了 `0`）！
   - 然而第 300 行的判断条件是：
     ```c
     if (last_psy_usb_type != port->psy_usb_type ||
         last_psy_status != port->psy_status)
         power_supply_changed(port->psy);
     ```
     **它竟然完全没有检查 `last_psy_online != port->psy_online`！**
   - 结果：当从 PC（SDP）拔下数据线时，`last_psy_usb_type`（SDP == SDP）和 `last_psy_status`（NOT_CHARGING == NOT_CHARGING）全都没变，`cros_usbpd-charger` **根本不会调用 `power_supply_changed(port->psy)` 发送 uevent 通知用户空间 `healthd`**！因此 `healthd` 永远停留在 `chg=u`（插电状态常驻）！
3. **不仅如此，为什么连 `healthd` 定期轮询都没能解除？**
   - 看同文件第 384～386 行（`cros_usbpd_charger_get_prop`）：
     ```c
     case POWER_SUPPLY_PROP_ONLINE:
         /*
          * If mkbp_event_supported, then we can be assured that
          * the driver's state for the online property is consistent
          * with the hardware. However, if we aren't event driven,
          * the optimization to avoid querying the ECbrick_id too
          * Checked only when psy_online is 0.
          */
         if (ec_device->mkbp_event_supported || port->psy_online)
             break;
     ```
   - 当 `healthd` 读取 `/sys/class/power_supply/CROS_USBPD_CHARGER0/online` 时，由于 `case POWER_SUPPLY_PROP_ONLINE:` 直接 `break` 跳过了 `cros_usbpd_charger_get_port_status(port, true)`，一旦拔线时的 MKBP 事件由于 500ms 缓存窗口（`CHARGER_CACHE_UPDATE_DELAY`）未刷新，或 uevent 未发出导致 `healthd` 不重读，`online` 就会一直卡在旧状态！
4. **为什么插上再拔下一根「纯充电线（PD / DCP）」就能解除？**
   - 因为纯充电器的类型是 `POWER_SUPPLY_USB_TYPE_PD` 或 `POWER_SUPPLY_USB_TYPE_DCP`，且状态是 `POWER_SUPPLY_STATUS_CHARGING`。
   - 插上纯充电线时，`psy_usb_type` 从 `SDP` 变成 `PD/DCP`（触发 `power_supply_changed`）；再拔下纯充电线时，`psy_usb_type` 从 `PD/DCP` 变回 `SDP` 且 `psy_status` 从 `CHARGING` 变回 `NOT_CHARGING`，满足了 `last_psy_usb_type != port->psy_usb_type || last_psy_status != port->psy_status`，终于触发了 `power_supply_changed(port->psy)`，从而把卡死的充电状态清掉了！

##### 证据链 2：智能电池 `sbs-9-000b` I2C 状态更新滞后，在拔线瞬间触发「正在无线充电」乌龙状态
在 `logcat`（`13:55:31.296` 与 `13:55:36.055`）中还捕捉到了另一个有趣的现象：
```
05-12 13:55:31.296 I healthd : battery l=69 v=4302 t=29.6 h=2 st=2 c=3308000 fc=8113000 cc=27 chg=
05-12 13:55:31.337 D BatteryBroadcastRcvr: Battery changed: level: 69%| status: 正在无线充电| chargingStatus: 0| health: 2
05-12 13:55:31.347 D BatteryInfo: chargingPolicy = 0, pluggedStatus = 0, batteryStatus = 2
```
- **原因**：当充电器刚拔下时，`CROS_USBPD_CHARGER0/online` 变为 `0`（因此 `chg=`，即 `pluggedStatus = 0`，没有任何有线充电器在线），但走 I2C 总线的智能电池芯片 `sbs-9-000b`（TI BQ40Z50）内部平均电流寄存器尚未归零，其 `/sys/class/power_supply/sbs-9-000b/status` 在拔线后数秒内仍报告 `Charging`（`st=2`）。
- Android 上层（`SettingsLib/BatteryInfo`）看到 `batteryStatus == BATTERY_STATUS_CHARGING (2)` 但有线插头 `pluggedStatus == 0`，便按排除法显示成了 **「正在无线充电」**！如果此时不再有后续的 `power_supply_changed` uevent 触发 `healthd` 重读 `sbs-9-000b/status`，系统就会一直卡在 `batteryStatus = 2`（充电中）！

---

### 2.4 现象 4：USB-C 音频（Type-C 转 3.5mm DAC 声卡）完全无反应

在实机测试期间（`13:47:17`～`13:48:10`），用户插入了一根 USB-C 转 3.5mm 音频转接头。`dmesg` 与 `logcat` 完整记录了设备枚举与音频路由失败的全过程。

#### （1）已跑通的部分：Type-C Host 角色识别、xHCI 枚举与 HID 音量键绑定均成功
- `dmesg`（`[248.020]` / `[300.961]`）显示，xHCI 控制器正常枚举到了该 USB-C 声卡：
  ```
  [  300.961442] usb 2-1: new full-speed USB device number 4 using xhci-hcd
  [  301.148966] usb 2-1: New USB device found, idVendor=06cb, idProduct=1595, bcdDevice= 1.00
  [  301.148996] usb 2-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
  [  301.149013] usb 2-1: Product: NICEHCK HiFi Audio
  [  301.149027] usb 2-1: Manufacturer: TTGK Technology Co.,Ltd
  [  301.174979] input: TTGK Technology Co.,Ltd NICEHCK HiFi Audio as /devices/platform/soc/usb0/fe800000.usb/xhci-hcd.10.auto/usb2/2-1/2-1:1.3/0003:06CB:1595.0004/input/input8
  [  301.212106] hid-generic 0003:06CB:1595.0004: input,hidraw0: USB HID v1.11 Device [TTGK Technology Co.,Ltd NICEHCK HiFi Audio] on usb-xhci-hcd.10.auto-1/input3
  ```
- Android 框架层的 `UsbHostManager` 也成功解析了该设备的 USB Audio Class 描述符（含播放与麦克风接口）：
  ```
  05-12 13:48:10.213 D UsbHostManager: USB device attached: vidpid 06cb:1595 mfg/product/ver/serial TTGK Technology Co.,Ltd/NICEHCK HiFi Audio/1.00/... hasAudio/HID/Storage: true/true/false
  05-12 13:48:10.217 D UsbDeviceDescriptor:   1 configs
  05-12 13:48:10.217 D UsbHostManager: Added device UsbDevice[mName=/dev/bus/usb/002/004,mVendorId=1739,mProductId=5525,...,mHasAudioPlayback=true,mHasAudioCapture=true]
  ```

#### （2）完全没声音的三个精确根因
紧接着 `UsbHostManager` 通知 `UsbAlsaManager` 时，`logcat` 在 `13:48:10.245` 报出了致命错误：
```
05-12 13:48:10.245 E UsbAlsaManager: usbDeviceAdded(): cannot find sound card for /dev/bus/usb/002/004
```
排查内核模块、音频策略 XML 与 VINTF Manifest 后确认，打通 USB 音频共缺失以下三环（缺一不可）：

1. **第一环（内核驱动层）：未打包并加载 `snd-usb-audio.ko` 及其依赖模块**
   - 在 `6.6.34-phase2` 内核中，`CONFIG_SND_USB_AUDIO=m` 编译为模块，但阶段 4 只打包了内置声卡 `rk3399-gru-sound` 所需的 16 个 SoC 音频模块，未包含 USB 音频模块。
   - 因此，当 `NICEHCK HiFi Audio` 插入时，只有インターフェース 3（HID 线控按键）绑定了内置的 `hid-generic`，而インターフェース 0/1/2（USB Audio Control / Streaming）没有任何内核驱动绑定，`/proc/asound/cards` 中始终只有 Card 0（`rk3399grusound`），没有生成 Card 1（`USB-Audio`），导致 `UsbAlsaManager` 报错 `cannot find sound card for /dev/bus/usb/002/004`。
   - 经对 `/home/alpha/src/gru-phase2/modules-out/lib/modules/6.6.34-phase2` 执行 `modinfo` 依赖分析，`snd-usb-audio.ko` 共需按序补充 **6 个内核模块**：
     1. `mc.ko`（`media`，`snd-usb-audio.ko` 的 `depends` 项）
     2. `snd-hwdep.ko`
     3. `snd-seq-device.ko`
     4. `snd-rawmidi.ko`
     5. `snd-usbmidi-lib.ko`
     6. `snd-usb-audio.ko`

2. **第二环（音频策略层）：`device/google/gru/etc/audio_policy_configuration.xml` 未引入 `usb_audio_policy_configuration.xml`**
   - 对比 `third_party/android_device_google_trogdor-lineage-24/etc/audio_policy_configuration.xml:118` 与本仓库 `device/google/gru/etc/audio_policy_configuration.xml:120`：
   - 尽管 `device/google/gru/device.mk:121` 已经将 `usb_audio_policy_configuration.xml` 拷贝到了 `/vendor/etc/usb_audio_policy_configuration.xml`，但 `device/google/gru/etc/audio_policy_configuration.xml` 的 `<modules>` 节点下只写了 `r_submix` 和 `bluetooth`，**漏写了 `<xi:include href="usb_audio_policy_configuration.xml"/>`**！
   - 结果是 AIDL Audio HAL（`android.hardware.audio.service-aidl.example`）在启动解析 XML 时（`AudioPolicyConfigXmlConverter.cpp:180`），根本没有实例化 `ModuleUsb`（`IModule/usb`）。

3. **第三环（VINTF 服务发现层）：`IModule/usb` 未在 VINTF Manifest 中声明**
   - 查看 `/apex/com.android.hardware.audio/etc/vintf/android.hardware.audio.service-aidl.xml`（源自我方编译树 `hardware/interfaces/audio/aidl/default/android.hardware.audio.service-aidl.xml:23`）：AOSP 默认把 `<fqname>IModule/usb</fqname>` 注释掉了（注释写明：`<!-- Uncomment when these modules present in the configuration -->`）。
   - 同时，客户端 `frameworks/av/media/libaudiohal/impl/DevicesFactoryHalAidl.cpp:154` 是通过 `AServiceManager_forEachDeclaredInstance(IModule::descriptor, ...)` 查询 VINTF 声明的实例列表来发现音频模块的！
   - 对照 `third_party/android_device_google_trogdor-lineage-24/manifest.xml:2` 可知，必须在 `device/google/gru/manifest.xml` 中补充声明 `android.hardware.audio.core` 的 `IModule/usb`（版本 `3` 或与 APEX 一致），否则即使 HAL 注册了 `IModule/usb`，`audioserver` 的 `DevicesFactoryHalAidl` 也不会去连接它。

---

## 3. 建议的修复顺序与具体实施方案

结合风险高低、是否需要重编内核/DTB 以及用户日常使用的迫切程度（本机 3.5mm 耳机孔物理损坏，USB-C DAC 声卡与连接 PC 传输/调试优先级最高），建议按以下 **4 个步骤由浅入深推进**：

### 第一步：打通 USB-C 音频（Type-C 转 3.5mm DAC 声卡即插即用）
- **为什么排第一**：改动完全在 `device/google/gru` 与现有编译好的内核模块中（无需重编内核本体），且能直接利用当前在线的无线 `adb` 先行将 `.ko` 和配置文件推送到实机内存/挂载点进行热验证，立竿见影解决本机 3.5mm 耳机孔损坏后的外接耳机需求。
- **具体操作**：
  1. 从 `/home/alpha/src/gru-phase2/modules-out/lib/modules/6.6.34-phase2/` 拷贝 `mc.ko`、`snd-hwdep.ko`、`snd-seq-device.ko`、`snd-rawmidi.ko`、`snd-usbmidi-lib.ko`、`snd-usb-audio.ko` 共 6 个模块到 `device/google/gru/modules/`，并在 `device.mk` 与 `init.gru.rc` 的 `early-init` 中按依赖顺序加载。
  2. 在 `device/google/gru/etc/audio_policy_configuration.xml` 的 `<modules>` 中加入 `<xi:include href="usb_audio_policy_configuration.xml"/>`。
  3. 在 `device/google/gru/manifest.xml` 中声明 `android.hardware.audio.core` 的 `IModule/usb`（注意核对 `/apex/com.android.hardware.audio/etc/vintf/android.hardware.audio.service-aidl.xml` 中的 `<version>3</version>`）。

### 第二步：修复连接 PC 拔线后充电状态常驻卡死与「正在无线充电」乌龙状态
- **为什么排第二**：这是 `cros_usbpd-charger.ko` 驱动与 `healthd` 状态同步的确定性逻辑缺陷，修复后无论是连接 PC 还是拔插各类线缆，状态栏与设置中的充电状态都能做到秒级准确响应。
- **具体操作**：
  1. 修改 `/home/alpha/src/gru-phase2/linux-6.6.34/drivers/power/supply/cros_usbpd-charger.c`：
     - 在 `cros_usbpd_charger_get_power_info()` 中增加 `int last_psy_online = port->psy_online;`，并将末尾的通知判断改为：
       ```c
       if (last_psy_usb_type != port->psy_usb_type ||
           last_psy_status != port->psy_status ||
           last_psy_online != port->psy_online)
           power_supply_changed(port->psy);
       ```
     - 检查 `cros_usbpd_charger_get_prop()` 中 `POWER_SUPPLY_PROP_ONLINE` 的缓存跳过逻辑，避免因 500ms `CHARGER_CACHE_UPDATE_DELAY` 吞掉拔线瞬间的状态更新。
     - 当触发 `cros_usbpd_charger_ec_event()`（PD/电源事件）时，同时通知或触发电池 supply 状态刷新，或者在 `BatteryMonitor.cpp` 补丁中确保当所有外部 Charger（`AC`/`USB`）均 `online=0` 时，若智能电池 `sbs-9-000b` 因 I2C 平均电流滞后仍短暂报告 `CHARGING`，将其状态修正为 `BATTERY_STATUS_DISCHARGING`，彻底消除无充电器在线时的「正在无线充电」及常驻充电图标。
  2. 重新编译 `cros_usbpd-charger.ko` 放入 `device/google/gru/modules/`，可通过无线 `adb` 先行 `rmmod` / `insmod` 实机验证。

### 第三步：开启全功能 Type-C OTG 双角色（`dr_mode = "otg"` + 有线 `adb` / MTP / PTP + OTG Host 自动切换）
- **为什么排第三**：此步需要更新内核设备树（DTB，打包进 FIT `image.fit` 写入 SD 卡 p1）并同步启用用户空间的 USB ConfigFS Gadget HAL。
- **技术可行性验证（已核实内核源码）**：
  - 在 `/home/alpha/src/gru-phase2/linux-6.6.34/drivers/usb/dwc3/drd.c:545`（`dwc3_drd_init`）中，当 `usbdrd_dwc3_0` 设为 `dr_mode = "otg"` 时，`dwc3` 会自动从父节点 `usbdrd3_0` 获取 `extcon = <&usbc_extcon0>`，并注册 `EXTCON_USB_HOST` 通知回调 `dwc3_drd_notifier()`：
    - 当插入 OTG 外设（USB DAC 声卡、U 盘、键鼠、便携屏）时，`extcon-usbc-cros-ec` 置 `EXTCON_USB_HOST=1`，`dwc3` 自动切换为 `DWC3_GCTL_PRTCAP_HOST`（xHCI Host 模式）。
    - 当插入电脑或拔出 OTG 外设时，`EXTCON_USB_HOST=0`，`dwc3` 自动切换为 `DWC3_GCTL_PRTCAP_DEVICE`（Gadget 模式），并在 `/sys/class/udc/` 下注册 **`fe800000.usb`**！
- **具体操作**：
  1. **设备树修改**：将 `rk3399-gru.dtsi:668` 中 `usbdrd_dwc3_0` 的 `dr_mode = "host";` 改为 `dr_mode = "otg";`，重编 `rk3399-gru-scarlet-kd.dtb` 并更新内核 FIT 镜像。
  2. **用户空间 USB Gadget 启用**：
     - 在 `device/google/gru/BoardConfig.mk` 与 `device.mk` 中移除 `TARGET_USB_INIT_SCRIPT := none`（恢复默认的 `TARGET_USB_INIT_SCRIPT := mainline`，打包 `/vendor/etc/init/hw/init.mainline.usb.rc`）。
     - 在 `device/google/gru/init.gru.rc` 中：
       - 移除 `setprop vendor.usb.configfs 0` 和 `on property:init.svc.usbd=running stop usbd`；
       - 设置 `setprop sys.usb.controller fe800000.usb` 与 `setprop vendor.usb.controller fe800000.usb`；
       - 保留 `service.adb.tcp.port=5555`（或支持有线/无线 `adb` 共存），使 `com.android.hardware.usb.gadget.mainline` APEX 服务（`vendor.usb-gadget-hal`）与 `usbd` 正常启动并绑定 `fe800000.usb`。
  3. **验证目标**：插电脑时识别出 `Google Gru`（支持有线 `adb`、状态栏弹出 USB 用途通知并可切换「文件传输 MTP」/「PTP」），拔下电脑换插 USB-C DAC 声卡或扩展坞时自动切回 Host 模式。

### 第四步：完善 USB-C DP Alt Mode 外接显示器（供电角色说明与 VOP 图层缩放修复）
- **为什么排第四**：DP Alt Mode 物理链路已经跑通，只需解决「未接外接电源的便携屏触发 VBUS 过流」与「`drmhwc` 在 `win2` 无缩放器 Plane 上的 `-ERANGE` 报错」。
- **具体操作**：
  1. **供电验证**：给 USB-C 便携屏接上外接 PD 电源后再与平板连接（此时便携屏不从平板 VBUS 抽电，或反向给平板充电），验证是否还会发生 3.5 秒后的 VBUS 过流断连。
  2. **修复 `drmhwc` / VOP 外接屏缩放报错**：
     - 方案 A（推荐，用户空间属性或 `drmhwc` 配置）：在 `drm_hwcomposer` 中针对不支持硬件缩放的 Plane（或通过 `vendor.hwc.drm.scale_with_gpu=1` / 在 `DrmPlane` 中检查 Plane 是否具备缩放能力）避免将需要缩放的镜像层分配给无 `.scl` 的 `win2`，消除 `Test-only seamless=0 ret=-34 (Math result not representable)`。
     - 方案 B（内核驱动层）：核查 `rockchip_drm_vop.c` 与 `rk3399-gru.dtsi` 中 `cdn-dp` 的 `ports` 绑定，确保外接 4K DP 显示器固定优先绑定 `vopb`（VOP Big，最高支持 `4096x2160`），内置 `1536x2048` eDP/MIPI 面板或副屏合理分配 Plane。

---

## 实现笔记

### 第一步：打通 USB-C 音频（Type-C 转 3.5mm DAC 声卡即插即用）

1. **树内持久化修改（已同步至编译树 `/run/media/alpha/YMTC/lineage-23.2/device/google/gru/`）**：
   - **内核模块打包与加载**：
     - 从 `/home/alpha/src/gru-phase2/linux-6.6.34/` 拷贝 6 个 USB 音频依赖模块至 `device/google/gru/modules/`：`mc.ko`、`snd-hwdep.ko`、`snd-seq-device.ko`、`snd-rawmidi.ko`、`snd-usbmidi-lib.ko`、`snd-usb-audio.ko`。
     - 在 `device/google/gru/device.mk` 的 `PRODUCT_COPY_FILES` 中加入上述 6 个 `.ko` 到 `$(TARGET_COPY_OUT_VENDOR)/lib/`。
     - 在 `device/google/gru/init.gru.rc` 的 `on early-init` 阶段（`snd-soc-rk3399-gru-sound.ko` 之后）按拓扑依赖顺序 `insmod` 上述 6 个模块。
   - **Audio Policy 与 VINTF 声明**：
     - 在 `device/google/gru/etc/audio_policy_configuration.xml` 的 `<modules>` 中新增 `<xi:include href="usb_audio_policy_configuration.xml"/>`。
     - 在 `device/google/gru/manifest.xml` 中新增 `android.hardware.audio.core`（`<version>3</version>`，`<fqname>IModule/usb</fqname>`）。

2. **实机免刷机热加载方法与 `servicemanager` VINTF 缓存刷新技巧**：
   - 由于实机 `/vendor` 为只读 `erofs` 文件系统、`init.gru.rc` 位于开机 ramdisk，直接重启机器会还原内存中的 `insmod` 与 `mount -o bind`（除非重新编译并刷写镜像到 SD 卡）。
   - 若在热加载时直接 `setprop ctl.restart servicemanager`，会触发 `servicemanager.rc` 中的 `onrestart class_restart main/hal`，导致整机用户空间重启并触发 watchdog 睡眠重启 bug。
   - 排查 `/run/media/alpha/YMTC/lineage-23.2/system/libvintf/VintfObject.cpp`（第 128–133 行）与 `Apex.cpp`（第 102–119 行）发现：`servicemanager` 内部通过 `VintfObject::getDeviceHalManifest()` 缓存了设备 VINTF 清单，但其缓存失效判据为 `apex::GetModifiedTime()`，即检查 `/apex/apex-info-list.xml` 的 `mtime`！
   - 因此，在实机上将修改后的 `vintf_manifest.xml` 和 `audio_policy_configuration.xml` 通过 `mount -o bind` 挂载到 `/vendor/etc/` 后，只需执行：
     ```bash
     touch /apex/apex-info-list.xml
     stop audioserver && stop vendor.audio-hal-aidl
     start vendor.audio-hal-aidl && start audioserver
     ```
     即可在不重启 `servicemanager` 和 `system_server` 的前提下，让 `servicemanager` 原地重读 `/vendor/etc/vintf/manifest.xml`，成功注册 `android.hardware.audio.core.IModule/usb` 并让 `audioserver` 加载 `"usb"` 硬件模块（Handle 18）。

3. **修复 USB DAC 播放爆音 / 爆电平杂音（`AHAL_StreamAlsa` 非阻塞 `MonoPipe` 溢出丢帧）**：
   - **实机现象与日志定位**：
     - 插入两款不同规格的 Type-C DAC（`NICEHCK HiFi Audio` `192kHz/32-bit` 与 `Generic EarPods` `48kHz/16-bit`）后虽能正常出声，但即使在低音量下也持续伴随「爆电平」一样的噼啪杂音。
     - 抓取实机 `logcat` 发现播放期间 `AHAL_StreamAlsa` 每隔数毫秒即刷屏报错：
       - 192kHz DAC（`mBufferSizeFrames = 1024`）：`W AHAL_StreamAlsa: transfer: sink 0 incomplete data sent, dropping 1024 frames`
       - 48kHz DAC（`mBufferSizeFrames = 240`，`MonoPipe` 2 的幂次向上取整为 `256` 帧）：`W AHAL_StreamAlsa: transfer: sink 0 incomplete data sent, dropping 224 frames` 及 `dropping 240 frames`。
   - **根因链路**：
     1. `ModuleUsb` 未重载 `getNominalLatencyMs()`，使用默认 `kLatencyMs = 5`（1 个 ALSA period = 5ms，48kHz 下 `mFrameCount = 240` 帧）。
     2. 在 `AudioFlinger`（`frameworks/av/services/audioflinger/Threads.cpp:3280`）中，`usb_device output` 属于普通 `MixerThread`（无 `FAST` 标志），`AudioFlinger` 强制要求混音缓冲不少于 `kMinNormalSinkBufferSizeMs`（20ms），因此 `mNormalFrameCount = 4 * mFrameCount`（960 帧 @ 48kHz，4096 帧 @ 192kHz）。每次混音周期结束后，`MixerThread` 会以 `mSleepTimeUs = 0` **连续 4 次**调用 `threadLoop_write()` -> `StreamHalAidl::transfer()`，每次通过 `DataMQ` 发送 1 个 period（240 帧），并依赖底层 HAL 的 `transfer()` 按照硬件 1x 采样率时钟阻塞节流。
     3. 然而在 AOSP 参考实现 `hardware/interfaces/audio/aidl/default/alsa/StreamAlsa.cpp` 中，`StreamAlsa::start()` 为输出流创建了容量仅 1 个 period（`roundup(240) = 256` 帧）且 **`writeCanBlock = false`（非阻塞）** 的 `MonoPipe`！
     4. 之所以 `StreamPrimary`（内置扬声器）没暴露此问题，是因为 `StreamPrimary::transfer()`（`StreamPrimary.cpp:110`）专门为模拟器写了 `usleep(sleepTimeUs)` 软件延时节流；而 **`StreamUsb::transfer()`（`StreamUsb.cpp:61`）没有任何 `usleep` 节流**，直接调用 `StreamAlsa::transfer()` 向非阻塞 `MonoPipe` 写入并耗时 0 微秒立即返回！
     5. 结果：`MixerThread` 在 50 微秒内连续打入 4 个 240 帧的 burst，第 1 个 burst 写入 240 帧后 `MonoPipe` 仅剩 `256 - 240 = 16` 帧空间，第 2 个 burst 仅截断写入 16 帧并直接丢弃剩余 **224 帧**，第 3、4 个 burst 直接丢弃全部 **240 帧**！音频正弦波每隔几毫秒就被强行截断拼接 16 帧残片，在波形上产生垂直阶跃不连续（高频冲激），听感上就是无论音量多小都存在密集的「爆电平」劈啪杂音。
     6. 此外，`libalsautilsv2` 的 `read_alsa_device_config()` 将 USB 声卡 `period_count` 设为了 `pcm_params_get_min(..., PCM_PARAM_PERIODS) = 2`（总缓冲仅 `2 * 5ms = 10ms`，小于 `MixerThread` 20ms 混音周期），且 `StreamUsb` 的 `readWriteRetries` 仅为 `1`。
   - **修复方案（补丁已保存至 `patches/hardware_interfaces_audio_usb_alsa_sync_io.patch`）**：
     1. **`StreamAlsa.cpp`**：当 `device.isExternal == true`（外部 USB 声卡）时，不再创建 `MonoPipe` 和 `outputIoThread`/`inputIoThread` 中转线程，而是在 HAL 实时 worker 线程的 `StreamAlsa::transfer()` 中直接调用 `proxy_write_with_retries()` / `proxy_read_with_retries()` 进行同步阻塞 ALSA 读写。这样每次 `burst` 直接由内核 `snd-usb-audio` 的硬件等时 URB 完成时钟精准节流（0 丢帧、0 线程竞争），同时保持内置扬声器（`!device.isExternal`）原有路径完全不变。
     2. **`alsa/Utils.cpp`**：在 `readAlsaDeviceInfo()` 中确保 `default_config.period_count` 至少为 `DEFAULT_PERIOD_COUNT`（`4`，即 `4 * 5ms = 20ms` 环形缓冲），与 `AudioFlinger` 的 20ms `mNormalFrameCount` 混音周期对齐。
     3. **`usb/StreamUsb.cpp`**：将 `readWriteRetries` 从 `1` 提升至 `3`。
     4. 重新编译 `/apex/com.android.hardware.audio/bin/hw/android.hardware.audio.service-aidl.example` 并通过 `mount --bind` 热替换至实机，两款 Type-C DAC 耳机实测音质清晰无杂音，测试通过。

### 第二步：修复连接 PC 拔线后充电状态常驻卡死与「正在无线充电」乌龙状态

1. **内核驱动 `cros_usbpd-charger.c` 深度修复（补丁已保存至 `patches/kernel_6.6.34_cros_usbpd_charger_online_notify.patch`，更新后的 `cros_usbpd-charger.ko` 已同步至 `device/google/gru/modules/`）**：
   - **补齐 `last_psy_online != port->psy_online` 的 uevent 通知判据**：
     - 在 `cros_usbpd_charger_get_power_info()` 中记录 `last_psy_online = port->psy_online;`，当 `last_psy_online != port->psy_online` 时同样调用 `power_supply_changed(port->psy)`。
   - **实机三次插拔 PC 日志复盘：定位 VBUS 电容放电 43ms 竞态与单次 PD 事件漏检**：
     - 对比实机 `dmesg` 发现：每次拔掉独立 PD 充电器时，EC 会先后发出**两次**相隔 `43～45ms` 的 `EC_HOST_EVENT_PD_MCU` 事件（`3363.352s -> 3363.395s`、`3370.627s -> 3370.672s`：第 1 次为 CC 断开，第 2 次为 43ms 后 VBUS 放电完毕与 PD 合约拆除）；
     - 而连接 PC（5V BC1.2 SDP，无 PD 合约）拔线时，3 次测试中有 2 次（`3315.929s`、`3342.920s`）EC 仅在 CC 断开瞬间（`t = 0ms`）发出了 **1 次** `EC_HOST_EVENT_PD_MCU` 事件！在 `t = 0ms` 时刻，虽然 `EC_CMD_USB_PD_CONTROL`（v1）已立即报告 `!(resp.enabled & PD_CTRL_RESP_ENABLED_CONNECTED)`（即 `extcon` 已立即识别为 `Not connected`），但主板 VBUS 滤波电容尚需约 `43ms` 才能放电至阈值以下，导致 `t = 0ms` 时查询 `EC_CMD_USB_PD_POWER_INFO` 仍返回 `SINK_NOT_CHARGING`（`psy_online = 1`）；而 `43ms` 后 VBUS 跌零时，由于无 PD 合约拆除，EC 不再发送第 2 次中断！
   - **三重根治机制**：
     1. **结合 `EC_CMD_USB_PD_CONTROL`（v1）物理连接位立即判据**：新增 `cros_usbpd_charger_is_port_connected()`（与 `extcon-usbc-cros-ec.c` 一致，查询 `EC_CMD_USB_PD_CONTROL` 的 `PD_CTRL_RESP_ENABLED_CONNECTED` 位）。一旦 CC 物理断开（`!cros_usbpd_charger_is_port_connected(port)`），在 `t = 0ms` 立即将 `resp.role` 置为 `USB_PD_PORT_POWER_DISCONNECTED`（`psy_online = 0`），无视 VBUS 电容残余电压。
     2. **EC 事件后 `100ms × 5` 延迟复核工作队列（`poll_work`）**：每次 `cros_usbpd_charger_ec_event()` 触发时，除立即查询外，自动调度 `poll_work` 在 `+100ms`、`+200ms`、`+300ms`、`+400ms`、`+500ms` 复核端口状态，彻底覆盖拔线时 ~43ms 的 VBUS 泄放窗口与插线时 BC1.2 慢速协商窗口。
     3. **移除 `POWER_SUPPLY_PROP_ONLINE` 缓存短路并将 `CHARGER_CACHE_UPDATE_DELAY` 从 `500ms` 缩短至 `50ms`**：既能合并单次 `healthd` `updateValues()` 内的多个属性读取（耗时 <2ms），又不会在 `healthd` 收到 uevent 后返回陈旧缓存。

2. **用户空间 `healthd`（`BatteryMonitor.cpp`）消除「正在无线充电」乌龙状态（补丁已更新至 `patches/system_core_healthd_battery_monitor.patch`）**：
   - 在 `BatteryMonitor::updateValues()` 末尾以及 `BatteryMonitor::getChargeStatus()` 中增加一致性修正：当所有外部充电器均不在线（`!isChargerOnline()`，即 `AC`/`USB`/`Wireless`/`Dock` 全部为 `false`）时，若智能电池 `sbs-9-000b` 因 TI BQ40Z50 库仑计平均电流寄存器 1～2 秒滞后仍短暂返回 `BatteryStatus::CHARGING`，将其修正为 `BatteryStatus::DISCHARGING`。
   - 彻底消除拔线瞬间因 `batteryStatus == CHARGING && pluggedStatus == 0` 被 Android SettingsLib 误判为「正在无线充电」或卡在充电图标的现象。

3. **实机免重启热加载状态**：
   - 已在实机卸载旧 `cros_usbpd_charger` 并 `insmod` 包含 `EC_CMD_USB_PD_CONTROL` 连接判据与 `poll_work` 延迟复核的 `cros_usbpd-charger.ko`；
   - 已重编 `android.hardware.health-service.example`，通过 `mount --bind` 覆盖 `/vendor/bin/hw/android.hardware.health-service.example` 并重启 `vendor.health-default` 服务。

## 事件

| 日期 | 事件记录 |
| :--- | :--- |
| 2026-10-20 | 完成 USB-C 全功能诊断与四步修复规划文档 `docs/usb.md`。 |
| 2026-10-20 | 完成第一步（USB-C 音频）代码修改并通过 `touch /apex/apex-info-list.xml` 在实机免重启热加载 `snd-usb-audio.ko`、`IModule/usb` 与 `usb_audio_policy_configuration.xml`，进入人工插拔 DAC 声卡测试阶段。 |
| 2026-10-20 | 定位并修复 USB-C DAC 播放爆电平杂音（`AHAL_StreamAlsa` 非阻塞 `MonoPipe` 溢出每秒丢弃数千帧），重编 `android.hardware.audio.service-aidl.example` 并热挂载至实机，人工验证耳机播放正常。 |
| 2026-10-20 | 完成第二步（修复连接 PC 拔线后充电状态常驻卡死与「正在无线充电」乌龙状态），重编并热加载 `cros_usbpd-charger.ko` 与 `android.hardware.health-service.example`，等待人工插拔充电器与 PC 测试。 |
