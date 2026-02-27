clear; 
clc; 
close all;

%% Serial Port
try
    device = serialport("COM3", 115200); 
    configureTerminator(device, "LF");
    disp('System Ready');
catch
    error('Serial port connection failed. Please check COM port and cable.');
end

%% Parameter Settings
fs = 25;               
windowSize = 300;      
irBuffer = zeros(1, windowSize);
t = (1:windowSize) / fs;
smoothBPM = 0;

% Pulse & Shape Variables
lastBeatTime = tic; 
theta = linspace(0, 2*pi, 100);
heartX = 16*sin(theta).^3;
heartY = 13*cos(theta)-5*cos(2*theta)-2*cos(3*theta)-cos(4*theta);

% 2nd Order Bandpass Filter (0.5 - 4 Hz)
[b, a] = butter(2, [0.5, 4] / (fs/2), 'bandpass');

%% UI
fig = figure('Name', 'ExPulse', 'Color', 'w', 'Position', [100, 100, 900, 650]);
hAx = subplot('Position', [0.1, 0.1, 0.8, 0.45]); 
hLineFiltered = plot(t, irBuffer, 'r', 'LineWidth', 2);
hold on; 

% Blue X for peak detection 
hDebugPeaks = plot(NaN, NaN, 'bx', 'MarkerSize', 12, 'LineWidth', 2); 

grid on;
title('Real-time PPG Signal (Blue X = Detected Peak)');
xlabel('Time (s)');
ylabel('Amplitude');

% Heart Visualization 
hAxHeart = axes('Position', [0.05, 0.65, 0.2, 0.25]);
hHeart = fill(heartX, heartY, 'r', 'EdgeColor', 'none', 'FaceAlpha', 0.2);
set(hAxHeart, 'Visible', 'off'); axis equal;

% Annotations
txtBPM = annotation('textbox', [0.3, 0.75, 0.3, 0.15], 'String', '-- BPM', 'FontSize', 45, 'FontWeight', 'bold', 'EdgeColor', 'none', 'Color', 'r');
txtStatus = annotation('textbox', [0.3, 0.68, 0.5, 0.1], 'String', 'Status: Scanning...', 'FontSize', 22, 'FontWeight', 'bold', 'EdgeColor', 'none');

%% Main Loop
while ishandle(fig)
    line = readline(device);
    if isempty(line), continue; end
    parts = str2double(strsplit(strtrim(line), '\t'));
    
    if ~isnan(parts(1))
        irBuffer = [irBuffer(2:end), parts(1)];
        
        % Filtering
        detrended = irBuffer - mean(irBuffer);
        bandpassed = filter(b, a, detrended);
        filteredData = movmean(bandpassed, 5); % Smoothing high-freq noise
        set(hLineFiltered, 'YData', filteredData);
        
        % Dynamic Y-Axis Scaling
        fMax = max(filteredData); fMin = min(filteredData);
        if fMax > fMin, set(hAx, 'YLim', [fMin*1.6, fMax*1.6]); end
        
        % BPM Calculation & Blue X Update
        rangeVal = max(filteredData) - min(filteredData);
        [pks, locs] = findpeaks(filteredData, ...
            'MinPeakDistance', round(0.5 * fs), ... 
            'MinPeakProminence', rangeVal * 0.25); 
        
        if ~isempty(locs)
            set(hDebugPeaks, 'XData', t(locs), 'YData', pks);
        else
            set(hDebugPeaks, 'XData', NaN, 'YData', NaN);
        end

        if length(locs) >= 3
            intervals = diff(locs) / fs; 
            currentInstBPM = 60 ./ intervals(end);
            
            % Anti-jitter Logic (Rate Limiter)
            if smoothBPM > 0 && abs(currentInstBPM - smoothBPM) > smoothBPM * 0.20
                smoothBPM = smoothBPM * 0.99 + currentInstBPM * 0.01;
            else
                if smoothBPM == 0, smoothBPM = currentInstBPM;
                else, smoothBPM = smoothBPM * 0.92 + currentInstBPM * 0.08; end
            end

            % Exercise Zone Classification
            if smoothBPM < 100
                stStr = 'Resting'; stColor = [0, 0.7, 0]; % Green
            elseif smoothBPM < 130
                stStr = 'Warm-up'; stColor = [1, 0.6, 0]; % Orange
            elseif smoothBPM < 155
                stStr = 'Fat Burn / Aerobic'; stColor = [1, 0.3, 0]; % Deep Orange
            else
                stStr = 'Anaerobic / Peak'; stColor = [1, 0, 0]; % Red
            end
            
            set(txtBPM, 'String', sprintf('%.0f BPM', smoothBPM));
            set(txtStatus, 'String', ['Status: ', stStr], 'Color', stColor);
        end
        
        % Dynamic Heart Pulse Logic
        if smoothBPM > 40
            beatDuration = 60 / smoothBPM; 
            elapsed = toc(lastBeatTime);
            if elapsed > beatDuration
                lastBeatTime = tic;
                elapsed = 0;
            end
            
            if elapsed < beatDuration * 0.3 % Systole (Contraction)
                scale = 1 + 0.15 * sin((elapsed/(beatDuration*0.3)) * pi);
                alpha = 0.8;
            else % Diastole (Relaxation)
                scale = 1.0;
                alpha = 0.2;
            end
            set(hHeart, 'XData', heartX * scale, 'YData', heartY * scale, 'FaceAlpha', alpha);
        end
    end
    drawnow limitrate;
end