function [widebandIQ, info] = ...
    runHEMUOFDMA20MHzScenario(outputFilename, userCount)
%runHEMUOFDMA20MHzScenario Generate continuous HE-MU OFDMA traffic.

    rng('shuffle');

    if nargin < 2 || isempty(userCount)
        userCount = randi([2, 9]);
    end

    validateattributes(userCount, {'numeric'}, ...
        {'scalar', 'integer', '>=', 2, '<=', 9}, mfilename, 'userCount');

    p.sampleRate = 100e6;
    p.receiverCenterFrequency = 2440e6;
    p.channelNumber = 7;
    p.channelCenterFrequency = 2442e6;
    p.channelBandwidth = 'CBW20';
    p.targetSamples = 10e6;

    p.guardInterval = 0.8;
    p.heLTFType = 2;
    p.sigBMCS = 2;

    p.sifs = 16e-6;
    p.slotTime = 9e-6;
    p.difs = p.sifs + 2 * p.slotTime;
    p.contentionWindowMinimum = 15;

    allocationByUserCount = [96, 128, 56, 15, 7, 3, 1, 0];
    p.allocationIndex = allocationByUserCount(userCount - 1);
    p.apepLength = [1000, 500, 100, 750, 300, 600, 200, 400, 250];
    p.mcs = [2, 3, 4, 1, 2, 3, 4, 1, 2];
    p.channelCoding = {'LDPC', 'LDPC', 'BCC', 'LDPC', 'BCC', ...
        'LDPC', 'BCC', 'LDPC', 'BCC'};

    frequencyOffset = ...
        p.channelCenterFrequency - p.receiverCenterFrequency;
    difsSamples = round(p.difs * p.sampleRate);
    slotSamples = round(p.slotTime * p.sampleRate);

    cfgMU = wlanHEMUConfig(p.allocationIndex);
    cfgMU.NumTransmitAntennas = 1;
    cfgMU.GuardInterval = p.guardInterval;
    cfgMU.HELTFType = p.heLTFType;
    cfgMU.SIGBMCS = p.sigBMCS;

    for userIdx = 1:userCount
        cfgMU.User{userIdx}.APEPLength = p.apepLength(userIdx);
        cfgMU.User{userIdx}.MCS = p.mcs(userIdx);
        cfgMU.User{userIdx}.NumSpaceTimeStreams = 1;
        cfgMU.User{userIdx}.ChannelCoding = ...
            p.channelCoding{userIdx};
    end

    allocationInfo = ruInfo(cfgMU);
    if allocationInfo.NumUsers ~= userCount || ...
            allocationInfo.NumRUs ~= userCount || ...
            any(allocationInfo.NumUsersPerRU ~= 1)
        error('runHEMUOFDMA20MHzScenario:InvalidAllocation', ...
            'The allocation must contain one user in each RU.');
    end

    psduLengths = getPSDULength(cfgMU);

    fprintf('\nWi-Fi 6 HE-MU OFDMA 下行场景\n');
    fprintf('宽带采样率：%.2f MHz\n', p.sampleRate / 1e6);
    fprintf('接收机中心频率：%.3f GHz\n', ...
        p.receiverCenterFrequency / 1e9);
    fprintf('Wi-Fi 信道：%d（中心频率 %.3f GHz）\n', ...
        p.channelNumber, p.channelCenterFrequency / 1e9);
    fprintf('用户数：%d，RU 分配索引：%d\n', ...
        userCount, p.allocationIndex);
    fprintf('RU 大小：');
    fprintf('%d ', allocationInfo.RUSizes);
    fprintf('tones\n');
    fprintf('目标样本数：%d\n\n', p.targetSamples);

    widebandIQ = complex( ...
        zeros(p.targetSamples, 1, 'single'), ...
        zeros(p.targetSamples, 1, 'single'));

    minimumBurstSpacing = difsSamples + 2;
    maximumEvents = ceil(p.targetSamples / minimumBurstSpacing);
    burstStartSamples = zeros(maximumEvents, 1);
    burstEndSamples = zeros(maximumEvents, 1);
    backoffSlotsHistory = zeros(maximumEvents, 1);

    eventCount = 0;
    currentSample = 1;
    firstNativeWaveform = [];

    while true
        psdu = cell(1, userCount);
        for userIdx = 1:userCount
            psdu{userIdx} = randi( ...
                [0, 1], 8 * psduLengths(userIdx), 1, 'int8');
        end

        burstIQ = generateFrameIQ( ...
            psdu, cfgMU, p.sampleRate, frequencyOffset);

        backoffSlots = randi([0, p.contentionWindowMinimum]);
        burstStart = currentSample + difsSamples + ...
            backoffSlots * slotSamples;
        burstEnd = burstStart + numel(burstIQ) - 1;

        if burstEnd > p.targetSamples
            break;
        end

        eventCount = eventCount + 1;
        if eventCount > maximumEvents
            error('runHEMUOFDMA20MHzScenario:EventCapacity', ...
                'Event preallocation is too small.');
        end

        widebandIQ(burstStart:burstEnd) = burstIQ;
        burstStartSamples(eventCount) = burstStart;
        burstEndSamples(eventCount) = burstEnd;
        backoffSlotsHistory(eventCount) = backoffSlots;

        if eventCount == 1
            firstNativeWaveform = wlanWaveformGenerator( ...
                psdu, cfgMU, 'WindowTransitionTime', 1e-7);
        end

        fprintf('突发 %3d：退避 %2d 时隙，HE-MU %.3f~%.3f ms\n', ...
            eventCount, ...
            backoffSlots, ...
            (burstStart - 1) / p.sampleRate * 1e3, ...
            (burstEnd - 1) / p.sampleRate * 1e3);

        currentSample = burstEnd + 1;
    end

    if eventCount == 0
        error('runHEMUOFDMA20MHzScenario:NoBursts', ...
            'No HE-MU burst fits in the requested capture.');
    end

    [ruFrequenciesMHz, ruMeanPowerDB] = analyzeFirstPPDU( ...
        firstNativeWaveform, cfgMU, allocationInfo);
    showAllocation(cfgMU);

    info.ScenarioType = 'heMultiUserOFDMA';
    info.ScenarioTitle = 'Wi-Fi 6 HE-MU OFDMA 下行场景';
    info.SampleRate = p.sampleRate;
    info.TargetSamples = p.targetSamples;
    info.ReceiverCenterFrequency = p.receiverCenterFrequency;
    info.ChannelNumber = p.channelNumber;
    info.ChannelCenterFrequency = p.channelCenterFrequency;
    info.ChannelBandwidth = p.channelBandwidth;
    info.DataFrameFormat = 'HE-MU';
    info.DataSource = 'Random PSDU bits';
    info.UserCount = userCount;
    info.AllocationIndex = p.allocationIndex;
    info.RUInfo = allocationInfo;
    info.APEPLength = p.apepLength(1:userCount);
    info.MCS = p.mcs(1:userCount);
    info.ChannelCoding = p.channelCoding(1:userCount);
    info.PSDULength = psduLengths;
    info.GuardInterval = p.guardInterval;
    info.HELTFType = p.heLTFType;
    info.SIGBMCS = p.sigBMCS;
    info.ContentionWindowMinimum = p.contentionWindowMinimum;
    info.DIFSSamples = difsSamples;
    info.SlotSamples = slotSamples;
    info.EventCount = eventCount;
    info.BurstStartSamples = burstStartSamples(1:eventCount);
    info.BurstEndSamples = burstEndSamples(1:eventCount);
    info.BackoffSlots = backoffSlotsHistory(1:eventCount);
    info.RUFrequenciesMHz = ruFrequenciesMHz;
    info.RUMeanPowerDB = ruMeanPowerDB;
    info.Config = cfgMU;

    windowLength = 2048;
    overlapLength = windowLength / 2;
    nfft = 2048;

    plotSpectrogram( ...
        widebandIQ, ...
        p.sampleRate, ...
        p.receiverCenterFrequency, ...
        windowLength, ...
        overlapLength, ...
        nfft, ...
        info.ScenarioTitle);

    I = real(widebandIQ);
    Q = imag(widebandIQ);
    save(outputFilename, 'I', 'Q', '-v7.3');

    fprintf('\nHE-MU 突发次数：%d\n', eventCount);
    fprintf('总样本数：%d\n', numel(widebandIQ));
    fprintf('总时长：%.3f ms\n', ...
        numel(widebandIQ) / p.sampleRate * 1e3);
    fprintf('数据已保存至：%s\n', outputFilename);
end

function [ruFrequenciesMHz, ruMeanPowerDB] = ...
        analyzeFirstPPDU(waveform, cfgMU, allocationInfo)

    fieldIndices = wlanFieldIndices(cfgMU);
    heData = waveform(double(fieldIndices.HEData(1)): ...
        double(fieldIndices.HEData(2)), :);
    userCount = allocationInfo.NumUsers;
    ruFrequenciesMHz = cell(1, userCount);
    ruPower = cell(1, userCount);
    allActiveIndices = [];

    for ruNumber = 1:userCount
        ofdmInfo = wlanHEOFDMInfo('HE-Data', cfgMU, ruNumber);
        ruSymbols = wlanHEDemodulate( ...
            heData, 'HE-Data', cfgMU, ruNumber);
        ruPower{ruNumber} = ...
            mean(mean(abs(ruSymbols).^2, 3), 2);
        ruFrequenciesMHz{ruNumber} = ...
            ofdmInfo.ActiveFrequencyIndices * ...
            (ofdmInfo.SampleRate / ofdmInfo.FFTLength) / 1e6;
        allActiveIndices = [allActiveIndices; ...
            ofdmInfo.ActiveFrequencyIndices(:)]; %#ok<AGROW>
    end

    if numel(unique(allActiveIndices)) ~= numel(allActiveIndices) || ...
            any(cellfun(@isempty, ruPower))
        error('runHEMUOFDMA20MHzScenario:InvalidRUAnalysis', ...
            'RU ranges overlap or an RU could not be demodulated.');
    end

    ruMeanPowerDB = cellfun( ...
        @(power) 10 * log10(mean(power) + eps), ruPower);
    plotUserRUSpectra(ruFrequenciesMHz, ruPower, allocationInfo);
end

function plotUserRUSpectra(ruFrequenciesMHz, ruPower, allocationInfo)
    figure('Name', 'HE-MU OFDMA Per-User RU Spectra');
    hold on;

    userCount = numel(ruPower);
    legendText = cell(1, userCount);
    for userIdx = 1:userCount
        plot(ruFrequenciesMHz{userIdx}, ...
            10 * log10(ruPower{userIdx} + eps), '.-');
        legendText{userIdx} = sprintf( ...
            '用户 %d：RU %d，%d-tone', ...
            userIdx, allocationInfo.RUNumbers(userIdx), ...
            allocationInfo.RUSizes(userIdx));
    end

    grid on;
    xlim([-10, 10]);
    xlabel('相对信道中心频率 / MHz');
    ylabel('平均子载波功率 / dB');
    title('首个 HE-MU PPDU 的分用户 RU 频谱');
    legend(legendText, 'Location', 'eastoutside');
end
