% 场景 3：生成 20 MHz、2 至 9 用户的 HE-MU OFDMA 下行场景。
% 输出为 100 MS/s、100 ms 的连续宽带 IQ；一次采集内用户数保持固定。

clear;
clc;
close all;

rng('shuffle');

scenarioDirectory = fileparts(mfilename('fullpath'));
projectDirectory = fileparts(scenarioDirectory);
sourceDirectory = fullfile(projectDirectory, 'src');
outputDirectory = fullfile(projectDirectory, 'output');

addpath(sourceDirectory);

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

[widebandIQ, scenarioInfo] = runHEMUOFDMA20MHzScenario( ...
    fullfile(outputDirectory, 'wifi6_scenario3_he_mu_ofdma.mat'));
