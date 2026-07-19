% 场景 2：复现 HE Extended-Range Single-User 单包对比实验。
% 生成使用相同 PSDU 的标准 HE-SU 和 HE-EXT-SU 波形，展示扩展范围
% 波形的上 106-tone RU 频谱占用以及 L-STF/L-LTF 约 3 dB 功率增强。

clear;
clc;
close all;

scenarioDirectory = fileparts(mfilename('fullpath'));
projectDirectory = fileparts(scenarioDirectory);
sourceDirectory = fullfile(projectDirectory, 'src');
outputDirectory = fullfile(projectDirectory, 'output');

addpath(sourceDirectory);

[txSUWaveform, txExtSUWaveform, comparisonInfo] = ...
    runHEExtendedRangeScenario();

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

[widebandIQ, scenarioInfo] = runHEExtendedRangeTrafficScenario( ...
    fullfile(outputDirectory, ...
    'wifi6_scenario2_he_extended_range_su.mat'));
scenarioInfo.Comparison = comparisonInfo;
