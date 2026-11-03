# Porcelain Clock 青花陶窑专注计时器

> An FPGA focus timer that turns every undisturbed Pomodoro session into a unique piece of blue-and-white porcelain.
> 一台把每一次专注"烧"成青花像素瓷器的 FPGA 计时器：点火计时，暂停即停火，到点开窑，器物入架。

## 1. Overview 项目简介

使用者在阅读或写作前按下点火键，屏幕上的砖窑随有效专注时间逐渐变亮；中途暂停，计时与火焰一同停下；到点后按键开窑，作品架上便多一件像素瓷器。器物借鉴景德镇青花瓷的白地蓝纹，由时长、暂停次数和开窑次序决定成品款式。

- Track 赛道：AMD 3.3 自主选题赛道 - 初级组
- Application 应用方向：桌面专注计时 / 番茄工作法可视化
- Keywords 关键词：专注计时、青花陶窑、像素成器

## 2. Platform and Tool Declaration 平台与工具声明

| Item 项目 | Value 内容 |
| --- | --- |
| Board 板卡 | 征战 V3 CORE 核心板 + Cam_Vga_V1 VGA 扩展板 |
| Device 器件型号 | XC7A35T-FGG484-2（Artix-7） |
| EDA tool 工具 | Vivado 2025.2 |
| Design language 设计语言 | Verilog（RTL）+ SystemVerilog（testbench） |
| Top module 顶层模块 | `top_kiln` |
| Display 显示 | 640 × 480 @ 60 Hz，RGB565，VGA |
| Clock 时钟 | 50 MHz 板载晶振，MMCM 生成 25.2 MHz 像素时钟 |

## 3. Features 功能与交互

| 按键 | 功能 |
| --- | --- |
| SW1 | 选择时长（30 秒演示；5 / 15 / 25 分钟） |
| SW2 | 点火 / 暂停 / 继续 |
| SW3 | 翻看本次通电最近完成的四件作品 |
| SW4 | 到点开窑；暂停时长按约 2 秒可放弃本炉 |

- 计时以 1 秒为单位显示，暂停时保留秒内余量，恢复后从冻结位置继续。
- 状态机依次经历准备（READY）、烧制（FIRING）、暂停（PAUSED）、待开窑（DONE）四种状态。
- 绘图模块按扫描坐标直接生成火焰、器物与文字，无需存储整帧图像。
- 作品架最多保留最近 4 件，第五件入架时最早一件移出；重新上电清空。

## 4. Repository Structure 目录结构

```
porcelain-clock/
├── src/                  # RTL 源码与约束
│   ├── top_kiln.v        # 顶层：MMCM、按键同步、VGA 时序
│   ├── kiln_core.v       # 计时状态机、款式编号、作品架
│   ├── kiln_video.v      # VGA 像素绘制：火焰、青花器形、纹带、文字
│   └── board.xdc         # 引脚、时钟与接口时序约束
├── sim/                  # SystemVerilog 仿真
│   ├── tb_kiln_core.sv   # 核心状态机：四档时长、暂停边界、258 次开窑轮换
│   ├── tb_kiln_board.sv  # 板级顶层：物理低电平按键、消抖
│   └── tb_kiln_preview.sv# 像素/显示预览验证
├── build/
│   └── build.tcl         # 可复现构建脚本（综合→实现→bit/mcs→报告）
├── board/
│   ├── porcelain_clock.bit  # JTAG 临时配置位流
│   ├── porcelain_clock.mcs  # SPI x4 Flash 启动镜像
│   └── demo.mp4             # 上板演示视频（1 分 32 秒）
├── data/                 # 数据说明（本项目激励由 testbench 生成）
├── skill/                # 可复用技能包
├── report/
│   └── design_report.docx   # 作品说明书
├── README.md
├── LICENSE               # MIT
└── .gitignore
```

## 5. Reproduce Steps 复现步骤

### 5.1 Build bitstream 构建位流

在已安装 Vivado 2025.2 并配置好环境的终端中执行：

```bash
git clone https://github.com/AnYao070605/2026-enbedded-fpga-FPGA-VGA-
cd porcelain-clock
vivado -mode batch -source build/build.tcl
```

脚本会自动完成：创建工程 → 添加源码与约束 → 综合 → 实现 → 生成 bitstream 与 SPI mcs 镜像 → 导出资源/时钟/IO/时序/DRC 报告，并执行 DRC 与时序检查。生成的位流与镜像发布到 `board/`，报告位于 `build/reports/`。

### 5.2 Program device 下载验证

- JTAG 临时运行：在 Vivado Hardware Manager 中打开 `board/porcelain_clock.bit`，Program Device。
- 上电启动：将 `board/porcelain_clock.mcs` 写入板载 SPI Flash，断电重启后自动加载。

### 5.3 Demo video 演示视频

完整上板演示见 `board/demo.mp4`（时长 1 分 32 秒），展示点火、暂停/继续、到点开窑与作品入架的完整流程。

### 5.4 Run simulation 运行仿真

在 Vivado 中将 `sim/` 下 testbench 设为仿真顶层（仿真文件已加入 `sim_1` fileset），运行 Behavioral Simulation；核心测试会在通过时打印 `PASS` 并自动结束。

## 6. Measured Results 实测结果

### 6.1 资源与时序（Vivado 2025.2 布线后）

| 指标 | 结果 |
| --- | --- |
| LUT | 1428 |
| 寄存器 FF | 169 |
| DSP | 0 |
| 建立时间裕量 WNS | +12.448 ns |
| 保持时间裕量 WHS | +0.130 ns |
| DRC | 零违规 |

### 6.2 可复现成品实例

| 时长 | 暂停次数 | 款式编号 | 成品 |
| --- | --- | --- | --- |
| 30 秒 | 0 | 6 | 青花双环纹碗 |
| 30 秒 | 1 | 4 | 青花折波纹圆罐 |
| 25 分钟 | 0 | 9 | 青花双环纹细颈瓶 |

## 7. Innovation 创新点

1. 将计时过程写进器物：固定首炉和时长，仅改变一次暂停，双环纹碗即可变为折波纹罐，差别可复现。
2. 用器形半径和少量像素规则绘制白瓷留地、钴蓝纹带与口沿，同一套硬件可生成多款器物。

## 8. LLM Collaboration 大模型协作记录

- Model 使用模型：GPT（OpenAI）
- Usage 用途：开发过程中使用 GPT 辅助两类工作：
  1. 代码优化：对 Verilog 模块写法、时序与资源使用提供优化建议；
  2. 错误排查：针对综合/实现报错与逻辑问题，协助定位原因并给出修改方向。
- Workflow 协作方式：GPT 仅提供建议与排查思路，所有改动均由作者判断并手工修改，在 Vivado 中重新编译、上板验证通过后才采纳；最终设计与代码由作者负责。
- Note 说明：未保留完整逐字对话，相关结论已落实到设计与本说明中。

## 9. License 开源协议

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 10. References 参考文献

1. 国家文物局考古研究中心，江西省文物考古研究院，景德镇市陶瓷考古研究所. 2024年度景德镇观音阁窑址发掘简报[J]. 故宫博物院院刊，2024(11): 4–40.
2. CIRILLO F. The Pomodoro Technique[M]. New York: Currency, 2018.
