clear; clc;

device = serialport("COM4", 115200);
configureTerminator(device, "LF");

Fs = 100;
windowSize = 500;

bpFilt = designfilt('bandpassiir', 'FilterOrder', 4, ...
    'HalfPowerFrequency1', 0.5, 'HalfPowerFrequency2', 3.5, ...
    'SampleRate', Fs);

irData  = zeros(1, windowSize);
redData = zeros(1, windowSize);

bpmBufSize = Fs * 10;
irBPMBuf = zeros(1, bpmBufSize);

figure('Name', 'ExPulse');

h1 = subplot(2,1,1);
hFilt = plot(zeros(1, windowSize), 'r'); 
title('IR Filtered'); grid on;
hold on;
hPeaks = plot(nan, nan, 'bv', 'MarkerFaceColor', 'b');
hold off;

h2 = subplot(2,1,2);
hBPM = text(0.5, 0.5, 'BPM: --', 'Units', 'normalized', ...
    'FontSize', 32, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
axis off;

currentBPM = NaN;
sampleCount = 0;
minPeakDist = round(0.4 * Fs);

while ishandle(gcf)
    line = readline(device);
    if isempty(line), continue; end

    parts = str2double(strsplit(strtrim(line), '\t'));
    if length(parts) == 2
        sampleCount = sampleCount + 1;

        irData = [irData(2:end), parts(1)];
        redData = [redData(2:end), parts(2)];

        irAC = irData - mean(irData);
        irSmooth = movmean(filtfilt(bpFilt, irAC), 5);

        irBPMBuf = [irBPMBuf(2:end), irSmooth(end)];

        if sampleCount > bpmBufSize
            prom = 0.3 * (max(irBPMBuf) - min(irBPMBuf));
            [~, locs] = findpeaks(irBPMBuf, 'MinPeakDistance', minPeakDist, ...
                'MinPeakProminence', max(prom, 0.01));
            if length(locs) >= 2
                currentBPM = round(60 / mean(diff(locs) / Fs));
                currentBPM = max(30, min(220, currentBPM));
            end
        end

        prom2 = 0.3 * (max(irSmooth) - min(irSmooth));
        [~, visLocs] = findpeaks(irSmooth, 'MinPeakDistance', minPeakDist, ...
            'MinPeakProminence', max(prom2, 0.01));

        set(hFilt, 'YData', irSmooth);
        if ~isempty(visLocs)
            set(hPeaks, 'XData', visLocs, 'YData', irSmooth(visLocs));
        else
            set(hPeaks, 'XData', nan, 'YData', nan);
        end

        subplot(h1); ylim([min(irSmooth)-0.1, max(irSmooth)+0.1]);

        if ~isnan(currentBPM)
            set(hBPM, 'String', sprintf('BPM: %d', currentBPM));
        end
    end

    drawnow limitrate;
end