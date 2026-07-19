# Wi-Fi 6 宽带 IQ 场景生成与时频分析

本项目使用 MATLAB 生成 Wi-Fi 6 宽带业务场景和标准物理层波形对比实验。场景 1 模拟具有实际协议时序的 AP 下行业务；场景 2 同时提供 HE Extended-Range Single-User 单包对比和连续业务；场景 3 生成 HE Multi-User OFDMA 波形。

场景 1 每次运行生成 10,000,000 个连续复数 IQ 样本，对应 100 ms 采集时长，并对完整采集结果执行 STFT、绘制时频图。

## 项目结构

```text
WIFI/
├── README.md
├── scenarios/
│   ├── scenario1_ap_downlink.m
│   ├── scenario2_he_extended_range_su.m
│   └── scenario3_he_mu_ofdma.m
├── src/
│   ├── runWiFi6Scenario.m
│   ├── runHEExtendedRangeScenario.m
│   ├── runHEExtendedRangeTrafficScenario.m
│   ├── runHEMUOFDMA20MHzScenario.m
│   ├── generateFrameIQ.m
│   └── plotSpectrogram.m
└── output/
```

## 环境要求

- MATLAB R2023a
- WLAN Toolbox
- Signal Processing Toolbox

## 采样率约定

项目中的 WLAN PHY 均固定为 20 MHz 信道带宽，原生采样率为 20 MS/s。所有对外输出及用于宽带场景拼接的波形统一通过 `wlanWaveformGenerator` 的 `OversamplingFactor=5` 执行 FFT 过采样，直接输出 100 MS/s IQ；不再对生成后的波形调用 `resample`。该约定同时适用于连续宽带业务以及场景 2 的 HE-SU/HE-EXT-SU 单包对比。

## 运行方法

在 MATLAB 中切换到项目根目录，然后运行：

```matlab
run(fullfile('scenarios', 'scenario1_ap_downlink.m'));
```

场景脚本根据自身位置定位项目目录，因此也可以从任意当前目录使用该脚本的绝对路径运行。

运行 HE Extended-Range SU 单包对比及连续业务场景：

```matlab
run(fullfile('scenarios', 'scenario2_he_extended_range_su.m'));
```

## 场景参数

| 参数 | 数值 |
| --- | --- |
| 业务方向 | AP 到单终端下行 |
| PHY | 802.11ax HE-SU，单空间流 |
| 信道 | 2.4 GHz 信道 7 |
| 信道中心频率 | 2.442 GHz |
| 信道带宽 | 20 MHz |
| 接收中心频率 | 2.440 GHz |
| 宽带采样率 | 100 MHz |
| IQ 样本数 | 10,000,000 |
| 采集时长 | 100 ms |
| 数据 MCS | MCS 5，LDPC |
| 数据载荷 | 1200 字节随机数据 |
| HE 保护间隔 | 0.8 μs |
| SIFS | 16 μs |
| DIFS | 34 μs |
| 退避 | 0～15 个 9 μs 时隙 |
| ACK | Non-HT OFDM，6 Mbps |
| 每个业务突发 | 1～4 次数据/ACK 交换 |
| 突发间应用空闲 | 2～10 ms |

## 输出

运行后在 `output/` 中生成 `wifi6_scenario1_ap_downlink.mat`。文件采用 `-v7.3` 格式，只包含：

- `I`：`10,000,000 × 1` 单精度同相分量。
- `Q`：`10,000,000 × 1` 单精度正交分量。

完整复数信号 `widebandIQ` 和事件记录 `scenarioInfo` 保留在 MATLAB 工作区。事件记录包含每次数据与 ACK 的起止样本、退避时隙、序列号和帧长度。

时频图使用 2048 点周期 Hann 窗、1024 点重叠和 2048 点 NFFT，同时输出完整 100 ms 概览和直接由原始 STFT 生成的前 10 ms 局部图。两幅图均规整为 `1024 × 1024`，并使用相同的 60 dB 色标范围。

## HE Extended-Range SU 场景

场景 2 使用相同的随机 PSDU 生成标准 HE-SU 和 HE-EXT-SU 单包：

| 参数 | 数值 |
| --- | --- |
| 信道带宽 | 20 MHz |
| APEP 长度 | 1000 字节 |
| MCS | 0 |
| 信道编码 | LDPC |
| 空间流/发射天线 | 1/1 |
| 保护间隔 | 3.2 μs |
| HE-LTF | 4×HE-LTF |
| 扩展范围 RU | 上 106-tone RU |

入口脚本保留 `txSUWaveform` 和 `txExtSUWaveform` 单包对比，并绘制 HE-EXT-SU 频谱/时频图以及 L-STF/L-LTF 功率对比图。场景会验证扩展范围前导相对标准 HE-SU 增强约 3 dB，并检查 HE-Data 主要占用信道上半部。

同一次运行还会生成 100 MS/s、100 ms 的连续 HE-EXT-SU 业务。每次数据发送后等待 SIFS 并返回 Non-HT ACK，随后加入本轮空口发射时长 3～8 倍的应用空闲，再执行 DIFS 和随机退避。连续信号保存在工作区变量 `widebandIQ`，事件与单包比较结果保存在 `scenarioInfo`，`I`、`Q` 写入 `output/wifi6_scenario2_he_extended_range_su.mat`。

## 简化边界

场景假定 AP 与终端已经完成关联，ACK 始终成功返回。模型不包含扫描、认证、加密、信道衰落、噪声、碰撞和重传，适合用于观察 Wi-Fi 6 基本突发波形、占用带宽及收发时序。
## HE Multi-User OFDMA 场景

场景 3 在 20 MHz 信道中生成连续的 HE-MU 下行 OFDMA 突发。每次采集从 2 至 9 中随机选择一次用户数，此后每个用户固定独占一个 RU。3 用户配置使用原文中的分配索引 128（106-tone、26-tone、106-tone）。

```matlab
run(fullfile('scenarios', 'scenario3_he_mu_ofdma.m'));
```

入口脚本生成 100 MS/s、100 ms、共 10,000,000 个连续复数 IQ 样本，在工作区返回 `widebandIQ` 和 `scenarioInfo`，并将 `I`、`Q` 保存到 `output/wifi6_scenario3_he_mu_ofdma.mat`。场景显示 RU 分配、首包分用户 RU 频谱和完整采集时频图。

每个 HE-MU 突发后，场景为各用户串行生成 Non-HT Block Ack，响应之间使用 SIFS。随后加入本轮空口发射时长 3～8 倍的应用空闲，再执行 DIFS 和随机退避。MATLAB R2023a 的 MAC 帧配置对象不支持 `HE-MU` 数据帧格式，因此数据部分仍为每个用户直接生成随机 PSDU bit；Block Ack 序列是用于体现关键响应时序的简化模型，不代表完整 Trigger/HE-TB MAC 流程。
