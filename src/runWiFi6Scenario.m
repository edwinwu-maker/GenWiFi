function [widebandIQ, info] = runWiFi6Scenario(outputFilename)
%runWiFi6Scenario Simulate associated AP-to-station Wi-Fi 6 traffic.

    rng('shuffle');

    p.sampleRate = 100e6;
    p.receiverCenterFrequency = 2440e6;
    p.channelNumber = 7;
    p.channelCenterFrequency = 2442e6;
    p.channelBandwidth = 'CBW20';
    p.targetSamples = 10e6;

    p.mcs = 5;
    p.payloadLength = 1200;
    p.guardInterval = 0.8;
    p.heLTFType = 2;

    p.sifs = 16e-6;
    p.slotTime = 9e-6;
    p.difs = p.sifs + 2 * p.slotTime;
    p.contentionWindowMinimum = 15;

    p.apAddress = '001122334455';
    p.stationAddress = '66778899AABB';
    p.bssid = p.apAddress;

    frequencyOffset = ...
        p.channelCenterFrequency - p.receiverCenterFrequency;
    sifsSamples = round(p.sifs * p.sampleRate);
    difsSamples = round(p.difs * p.sampleRate);
    slotSamples = round(p.slotTime * p.sampleRate);

    fprintf('\nWi-Fi 6 AP 下行场景\n');
    fprintf('宽带采样率：%.2f MHz\n', p.sampleRate / 1e6);
    fprintf('接收机中心频率：%.3f GHz\n', ...
        p.receiverCenterFrequency / 1e9);
    fprintf('Wi-Fi 信道：%d（中心频率 %.3f GHz）\n', ...
        p.channelNumber, p.channelCenterFrequency / 1e9);
    fprintf('目标样本数：%d\n\n', p.targetSamples);

    widebandIQ = complex( ...
        zeros(p.targetSamples, 1, 'single'), ...
        zeros(p.targetSamples, 1, 'single'));

    cfgHE = wlanHESUConfig( ...
        'ChannelBandwidth', p.channelBandwidth, ...
        'NumTransmitAntennas', 1, ...
        'NumSpaceTimeStreams', 1, ...
        'MCS', p.mcs, ...
        'ChannelCoding', 'LDPC', ...
        'APEPLength', p.payloadLength, ...
        'GuardInterval', p.guardInterval, ...
        'HELTFType', p.heLTFType);

    cfgAckMAC = wlanMACFrameConfig( ...
        'FrameType', 'ACK', ...
        'Address1', p.apAddress);
    [ackBits, ackLength] = wlanMACFrame( ...
        cfgAckMAC, ...
        'OutputFormat', 'bits');

    cfgAckPHY = wlanNonHTConfig( ...
        'Modulation', 'OFDM', ...
        'ChannelBandwidth', p.channelBandwidth, ...
        'MCS', 0, ...
        'PSDULength', ackLength);
    ackIQ = generateFrameIQ( ...
        ackBits, cfgAckPHY, p.sampleRate, frequencyOffset);

    minimumExchangeSpacing = difsSamples + sifsSamples + 2;
    maximumEvents = ceil(p.targetSamples / minimumExchangeSpacing);
    eventStartSamples = zeros(maximumEvents, 1);
    dataStartSamples = zeros(maximumEvents, 1);
    dataEndSamples = zeros(maximumEvents, 1);
    ackStartSamples = zeros(maximumEvents, 1);
    ackEndSamples = zeros(maximumEvents, 1);
    backoffSlotsHistory = zeros(maximumEvents, 1);
    sequenceNumbers = zeros(maximumEvents, 1);
    frameLengths = zeros(maximumEvents, 1);

    eventCount = 0;
    currentSample = 1;

    while true
        sequenceNumber = mod(eventCount, 4096);
        payload = randi([0, 255], 1, p.payloadLength, 'uint8');

        cfgDataMAC = wlanMACFrameConfig( ...
            'FrameType', 'QoS Data', ...
            'FrameFormat', 'HE-SU', ...
            'Address1', p.stationAddress, ...
            'Address2', p.apAddress, ...
            'Address3', p.bssid, ...
            'SequenceNumber', sequenceNumber);

        [dataBits, frameLength] = wlanMACFrame( ...
            payload, ...
            cfgDataMAC, ...
            cfgHE, ...
            'OutputFormat', 'bits');
        cfgHE.APEPLength = frameLength;

        dataIQ = generateFrameIQ( ...
            dataBits, cfgHE, p.sampleRate, frequencyOffset);

        backoffSlots = randi([0, p.contentionWindowMinimum]);
        dataStart = currentSample + difsSamples + ...
            backoffSlots * slotSamples;
        dataEnd = dataStart + numel(dataIQ) - 1;
        ackStart = dataEnd + 1 + sifsSamples;
        ackEnd = ackStart + numel(ackIQ) - 1;

        if ackEnd > p.targetSamples
            break;
        end

        eventCount = eventCount + 1;

        if eventCount > maximumEvents
            error( ...
                'runWiFi6Scenario:EventCapacity', ...
                'Event preallocation is too small.');
        end

        widebandIQ(dataStart:dataEnd) = dataIQ;
        widebandIQ(ackStart:ackEnd) = ackIQ;

        eventStartSamples(eventCount) = currentSample;
        dataStartSamples(eventCount) = dataStart;
        dataEndSamples(eventCount) = dataEnd;
        ackStartSamples(eventCount) = ackStart;
        ackEndSamples(eventCount) = ackEnd;
        backoffSlotsHistory(eventCount) = backoffSlots;
        sequenceNumbers(eventCount) = sequenceNumber;
        frameLengths(eventCount) = frameLength;

        fprintf([ ...
            '交换 %3d：退避 %2d 时隙，HE-SU %.3f~%.3f ms，' ...
            'ACK %.3f~%.3f ms\n'], ...
            eventCount, ...
            backoffSlots, ...
            (dataStart - 1) / p.sampleRate * 1e3, ...
            (dataEnd - 1) / p.sampleRate * 1e3, ...
            (ackStart - 1) / p.sampleRate * 1e3, ...
            (ackEnd - 1) / p.sampleRate * 1e3);

        currentSample = ackEnd + 1;
    end

    info.ScenarioType = 'apDownlink';
    info.ScenarioTitle = 'Wi-Fi 6 AP 下行数据场景';
    info.SampleRate = p.sampleRate;
    info.TargetSamples = p.targetSamples;
    info.ReceiverCenterFrequency = p.receiverCenterFrequency;
    info.ChannelNumber = p.channelNumber;
    info.ChannelCenterFrequency = p.channelCenterFrequency;
    info.ChannelBandwidth = p.channelBandwidth;
    info.MCS = p.mcs;
    info.PayloadLength = p.payloadLength;
    info.GuardInterval = p.guardInterval;
    info.HELTFType = p.heLTFType;
    info.DataFrameType = 'QoS Data';
    info.DataFrameFormat = 'HE-SU';
    info.AckFrameType = 'ACK';
    info.AckFrameFormat = 'Non-HT';
    info.APAddress = p.apAddress;
    info.StationAddress = p.stationAddress;
    info.ContentionWindowMinimum = p.contentionWindowMinimum;
    info.SIFSSamples = sifsSamples;
    info.DIFSSamples = difsSamples;
    info.SlotSamples = slotSamples;
    info.EventCount = eventCount;
    info.EventStartSamples = eventStartSamples(1:eventCount);
    info.DataStartSamples = dataStartSamples(1:eventCount);
    info.DataEndSamples = dataEndSamples(1:eventCount);
    info.AckStartSamples = ackStartSamples(1:eventCount);
    info.AckEndSamples = ackEndSamples(1:eventCount);
    info.BackoffSlots = backoffSlotsHistory(1:eventCount);
    info.SequenceNumbers = sequenceNumbers(1:eventCount);
    info.FrameLengths = frameLengths(1:eventCount);

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

    fprintf('\n交换次数：%d\n', eventCount);
    fprintf('总样本数：%d\n', numel(widebandIQ));
    fprintf('总时长：%.3f ms\n', numel(widebandIQ) / p.sampleRate * 1e3);
    fprintf('数据已保存至：%s\n', outputFilename);
end
