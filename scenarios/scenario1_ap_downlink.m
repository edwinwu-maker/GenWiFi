% 场景 1：已关联的 AP 向单个终端发送 Wi-Fi 6 HE-SU 下行数据。
% 每次数据发送前执行 DIFS 和随机退避，数据结束后由终端返回 Non-HT ACK。
% 输出为 100 MS/s、100 ms 的宽带复数 IQ，并保存同相和正交分量。

clear;
clc;
close all;

scenarioDirectory = fileparts(mfilename('fullpath'));
projectDirectory = fileparts(scenarioDirectory);
sourceDirectory = fullfile(projectDirectory, 'src');
outputDirectory = fullfile(projectDirectory, 'output');

addpath(sourceDirectory);

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

[widebandIQ, scenarioInfo] = runWiFi6Scenario( ...
    fullfile(outputDirectory, 'wifi6_scenario1_ap_downlink.mat'));
