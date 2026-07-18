function frameIQ = generateFrameIQ( ...
        frameBits, phyConfig, outputSampleRate, frequencyOffset)
%generateFrameIQ Generate and place a WLAN frame in a wideband IQ channel.

    basebandIQ = wlanWaveformGenerator( ...
        frameBits, ...
        phyConfig, ...
        'WindowTransitionTime', 1e-7);

    nativeSampleRate = wlanSampleRate(phyConfig);

    if nativeSampleRate ~= outputSampleRate
        [resampleNumerator, resampleDenominator] = rat( ...
            outputSampleRate / nativeSampleRate);
        basebandIQ = resample( ...
            basebandIQ, ...
            resampleNumerator, ...
            resampleDenominator);
    end

    basebandIQ = single(basebandIQ(:, 1));
    sampleIndex = single((0:numel(basebandIQ) - 1).');
    phaseIncrement = single(2 * pi * frequencyOffset / outputSampleRate);
    frequencyShift = exp(1j * phaseIncrement * sampleIndex);

    frameIQ = basebandIQ .* frequencyShift;
end
