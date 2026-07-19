function frameIQ = generateFrameIQ( ...
        frameBits, phyConfig, outputSampleRate, frequencyOffset)
% 生成一个 WLAN PPDU
% WLAN PPDU 是 Wi‑Fi 在物理层实际发送的一整个无线数据包

    nativeSampleRate = wlanSampleRate(phyConfig);
    oversamplingFactor = outputSampleRate / nativeSampleRate;

    basebandIQ = wlanWaveformGenerator( ...
        frameBits, ...
        phyConfig, ...
        'WindowTransitionTime', 1e-7, ...
        'OversamplingFactor', oversamplingFactor);

    basebandIQ = single(basebandIQ);
    sampleIndex = single((0:numel(basebandIQ) - 1).');
    phaseIncrement = single(2 * pi * frequencyOffset / outputSampleRate);
    frequencyShift = exp(1j * phaseIncrement * sampleIndex);

    frameIQ = basebandIQ .* frequencyShift;
end
