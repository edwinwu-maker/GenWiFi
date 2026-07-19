function [widebandIQ, info] = ...
    runHEExtendedRangeTrafficScenario(outputFilename)
%runHEExtendedRangeTrafficScenario Generate mixed HE-EXT-SU traffic.

    rng('shuffle');

    p.sampleRate = 100e6;
    p.receiverCenterFrequency = 2440e6;
    p.channelNumber = 7;
    p.channelCenterFrequency = 2442e6;
    p.channelBandwidth = 'CBW20';
    p.targetSamples = 10e6;

    p.payloadLength = 1000;
    p.mcs = 0;
    p.guardInterval = 3.2;
    p.heLTFType = 4;

    p.sifs = 16e-6;
    p.slotTime = 9e-6;
    p.difs = p.sifs + 2 * p.slotTime;
    p.contentionWindowMinimum = 15;
    p.minimumIdleMultiplier = 3;
    p.maximumIdleMultiplier = 8;

    p.apAddress = '001122334455';
    p.stationAddress = '66778899AABB';
    p.bssid = p.apAddress;

    frequencyOffset = ...
        p.channelCenterFrequency - p.receiverCenterFrequency;
    sifsSamples = round(p.sifs * p.sampleRate);
    difsSamples = round(p.difs * p.sampleRate);
    slotSamples = round(p.slotTime * p.sampleRate);

    cfgExtSU = wlanHESUConfig( ...
        'ChannelBandwidth', p.channelBandwidth, ...
        'ExtendedRange', true, ...
        'Upper106ToneRU', true, ...
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
        cfgAckMAC, 'OutputFormat', 'bits');
    cfgAckPHY = wlanNonHTConfig( ...
        'Modulation', 'OFDM', ...
        'ChannelBandwidth', p.channelBandwidth, ...
        'MCS', 0, ...
        'PSDULength', ackLength);
    ackIQ = generateFrameIQ( ...
        ackBits, cfgAckPHY, p.sampleRate, frequencyOffset);

    widebandIQ = complex( ...
        zeros(p.targetSamples, 1, 'single'), ...
        zeros(p.targetSamples, 1, 'single'));

    minimumExchangeSpacing = difsSamples + sifsSamples + 2;
    maximumEvents = ceil(p.targetSamples / minimumExchangeSpacing);
    dataStartSamples = zeros(maximumEvents, 1);
    dataEndSamples = zeros(maximumEvents, 1);
    ackStartSamples = zeros(maximumEvents, 1);
    ackEndSamples = zeros(maximumEvents, 1);
    backoffSlotsHistory = zeros(maximumEvents, 1);
    applicationIdleAfterSamples = zeros(maximumEvents, 1);
    frameLengths = zeros(maximumEvents, 1);

    eventCount = 0;
    currentSample = 1;

    while true
        sequenceNumber = mod(eventCount, 4096);
        payload = randi([0, 255], 1, p.payloadLength, 'uint8');
        cfgDataMAC = wlanMACFrameConfig( ...
            'FrameType', 'QoS Data', ...
            'FrameFormat', 'HE-EXT-SU', ...
            'Address1', p.stationAddress, ...
            'Address2', p.apAddress, ...
            'Address3', p.bssid, ...
            'SequenceNumber', sequenceNumber);
        [dataBits, frameLength] = wlanMACFrame( ...
            payload, cfgDataMAC, cfgExtSU, 'OutputFormat', 'bits');
        cfgExtSU.APEPLength = frameLength;
        dataIQ = generateFrameIQ( ...
            dataBits, cfgExtSU, p.sampleRate, frequencyOffset);

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
        widebandIQ(dataStart:dataEnd) = dataIQ;
        widebandIQ(ackStart:ackEnd) = ackIQ;

        dataStartSamples(eventCount) = dataStart;
        dataEndSamples(eventCount) = dataEnd;
        ackStartSamples(eventCount) = ackStart;
        ackEndSamples(eventCount) = ackEnd;
        backoffSlotsHistory(eventCount) = backoffSlots;
        frameLengths(eventCount) = frameLength;

        transmittedSamples = numel(dataIQ) + numel(ackIQ);
        idleMultiplier = randi([ ...
            p.minimumIdleMultiplier, p.maximumIdleMultiplier]);
        applicationIdleSamples = transmittedSamples * idleMultiplier;
        applicationIdleAfterSamples(eventCount) = ...
            applicationIdleSamples;
        currentSample = ackEnd + 1 + applicationIdleSamples;
    end

    if eventCount == 0
        error('runHEExtendedRangeTrafficScenario:NoEvents', ...
            'No HE-EXT-SU exchange fits in the requested capture.');
    end

    info.ScenarioType = 'heExtendedRangeSUTraffic';
    info.ScenarioTitle = 'Wi-Fi 6 HE-EXT-SU daily mixed traffic';
    info.SampleRate = p.sampleRate;
    info.TargetSamples = p.targetSamples;
    info.ReceiverCenterFrequency = p.receiverCenterFrequency;
    info.ChannelNumber = p.channelNumber;
    info.ChannelCenterFrequency = p.channelCenterFrequency;
    info.ChannelBandwidth = p.channelBandwidth;
    info.TrafficModel = 'dailyMixedProportionalIdle';
    info.ApplicationIdleMultiplierRange = [ ...
        p.minimumIdleMultiplier, p.maximumIdleMultiplier];
    info.DataFrameType = 'QoS Data';
    info.DataFrameFormat = 'HE-EXT-SU';
    info.AckFrameType = 'ACK';
    info.AckFrameFormat = 'Non-HT';
    info.PayloadLength = p.payloadLength;
    info.MCS = p.mcs;
    info.GuardInterval = p.guardInterval;
    info.HELTFType = p.heLTFType;
    info.Upper106ToneRU = true;
    info.SIFSSamples = sifsSamples;
    info.DIFSSamples = difsSamples;
    info.SlotSamples = slotSamples;
    info.ContentionWindowMinimum = p.contentionWindowMinimum;
    info.EventCount = eventCount;
    info.DataStartSamples = dataStartSamples(1:eventCount);
    info.DataEndSamples = dataEndSamples(1:eventCount);
    info.AckStartSamples = ackStartSamples(1:eventCount);
    info.AckEndSamples = ackEndSamples(1:eventCount);
    info.BackoffSlots = backoffSlotsHistory(1:eventCount);
    info.ApplicationIdleAfterSamples = ...
        applicationIdleAfterSamples(1:eventCount);
    info.FrameLengths = frameLengths(1:eventCount);
    transmittedSamples = sum( ...
        info.DataEndSamples - info.DataStartSamples + 1) + sum( ...
        info.AckEndSamples - info.AckStartSamples + 1);
    info.TransmissionDutyCycle = transmittedSamples / p.targetSamples;
    info.Config = cfgExtSU;

    plotSpectrogram( ...
        widebandIQ, p.sampleRate, p.receiverCenterFrequency, ...
        2048, 1024, 2048, info.ScenarioTitle);

    I = real(widebandIQ);
    Q = imag(widebandIQ);
    save(outputFilename, 'I', 'Q', '-v7.3');

    fprintf('\nHE-EXT-SU continuous traffic\n');
    fprintf('Exchanges: %d\n', eventCount);
    fprintf('Transmission duty cycle: %.2f%%\n', ...
        100 * info.TransmissionDutyCycle);
    fprintf('Data saved to: %s\n', outputFilename);
end
