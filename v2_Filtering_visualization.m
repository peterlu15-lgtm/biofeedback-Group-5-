clear; 
clc; 
close all;

%% serial port 
try
    delete(serialportfind("Port", "COM3")); 
    device = serialport("COM3", 115200); 
    configureTerminator(device, "LF");
    flush(device);
    disp('System Ready');
catch
    error('Serial port connection failed. Please check COM port and cable.');
end

%% parameter pettings
fs = 25;               % Sampling frequency (Hz)
windowSize = 300;      % 12-second window for visualization
irBuffer = zeros(1, windowSize);
t = (1:windowSize) / fs;
smoothBPM = 0;

% 2nd Order Bandpass Filter (0.5 - 4 Hz) 
[b, a] = butter(2, [0.5, 4] / (fs/2), 'bandpass');

% heart bisualization variables
lastBeatTime = tic; 
theta = linspace(0, 2*pi, 100);
heartX = 16*sin(theta).^3;
heartY = 13*cos(theta)-5*cos(2*theta)-2*cos(3*theta)-cos(4*theta);

%% Audio Setup
audioFiles = {'zen.wav', 'resting.wav', 'stress.wav'};  % Ensure these files exist in your current directory
audioData = cell(1,3);
fsAudio = 44100; 

for i = 1:3
    try
        [data, f] = audioread(audioFiles{i});
        if size(data, 2) > 1, data = mean(data, 2); end % Convert Stereo to Mono
        audioData{i} = data;
        fsAudio = f; 
    catch
        warning('Audio file %s not found. Please check your folder.', audioFiles{i});
    end
end

deviceWriter = audioDeviceWriter('SampleRate', fsAudio);
currentTrackIdx = 1; 
audioPtr = 1;        
frameSize = 1024;    
globalGain = 0.5; % Adjust master volume (0.0 - 1.0)

%% UI
fig = figure('Name', 'ExPulse - Stabilized with Zen Audio', 'Color', 'w', 'Position', [100, 100, 900, 650]);
hAx = subplot('Position', [0.1, 0.1, 0.8, 0.45]); 
hLineFiltered = plot(t, irBuffer, 'r', 'LineWidth', 2);
hold on; 
hDebugPeaks = plot(NaN, NaN, 'bx', 'MarkerSize', 12, 'LineWidth', 2); % Blue X for peak detection 
grid on;
title('Real-time PPG Signal (Blue X = Detected Peak)');
xlabel('Time (s)');
ylabel('Amplitude');

% heart axes
hAxHeart = axes('Position', [0.05, 0.65, 0.2, 0.25]);
hHeart = fill(heartX, heartY, 'r', 'EdgeColor', 'none', 'FaceAlpha', 0.2);
set(hAxHeart, 'Visible', 'off'); axis equal;

% Annotations
txtBPM = annotation('textbox', [0.3, 0.75, 0.3, 0.15], 'String', '-- BPM', 'FontSize', 45, 'FontWeight', 'bold', 'EdgeColor', 'none', 'Color', 'r');
txtStatus = annotation('textbox', [0.3, 0.68, 0.5, 0.1], 'String', 'Status: Scanning...', 'FontSize', 22, 'FontWeight', 'bold', 'EdgeColor', 'none');

%% Main Loop
while ishandle(fig)
    % read data line from serial port
    line = readline(device);
    if isempty(line), continue; end
    parts = str2double(strsplit(strtrim(line), '\t'));
    
    if ~isnan(parts(1))
        % update buffer with raw data
        irBuffer = [irBuffer(2:end), parts(1)];
        
        % process active data
        firstValIdx = find(irBuffer > 0, 1, 'first');
        if isempty(firstValIdx), continue; end
        
        activeSignal = irBuffer(firstValIdx:end);
        currentLen = length(activeSignal);
        
        % filtering
        detrended = activeSignal - mean(activeSignal);
        if length(detrended) > 6  
            bandpassed = filter(b, a, detrended);
            filteredData = movmean(bandpassed, 5);
            
            % Plot display
            displayData = zeros(1, windowSize);
            displayData(end-currentLen+1:end) = filteredData;
            set(hLineFiltered, 'YData', displayData);
            
            % yaxis Scaling 
            fMax = max(filteredData); fMin = min(filteredData);
            if fMax > fMin, set(hAx, 'YLim', [fMin*1.6, fMax*1.6]); end
        else
            continue;
        end
        
        % Peak Detection (> 2 seconds of data)
        if currentLen > 2 * fs
            rangeVal = max(filteredData) - min(filteredData);
            [pks, locs] = findpeaks(filteredData, ...
                'MinPeakDistance', round(0.4 * fs), ... 
                'MinPeakProminence', rangeVal * 0.20); 
            
            if ~isempty(locs)
                % Map local peak
                globalLocs = locs + (windowSize - currentLen);
                set(hDebugPeaks, 'XData', t(globalLocs), 'YData', pks);
                
                % BPM Calculation
                if length(locs) >= 2
                    intervals = diff(locs) / fs;
                    
                    %Fast response initially, stable later
                    if length(locs) < 4
                        currentInstBPM = 60 / intervals(end);
                        weight = 0.3; 
                    else
                        avgInterval = mean(intervals(max(1, end-3):end));
                        currentInstBPM = 60 / avgInterval;
                        weight = 0.04; 
                    end
                    
                    if smoothBPM == 0
                        smoothBPM = currentInstBPM;
                    else
                        smoothBPM = smoothBPM * (1-weight) + currentInstBPM * weight;
                    end
                    
                    %  Status and color
                    if smoothBPM < 75
                        stStr = 'Zen Mode'; stColor = [0, 0.7, 0];
                    elseif smoothBPM < 100
                        stStr = 'Resting'; stColor = [0, 0.5, 0.8];
                    elseif smoothBPM < 130
                        stStr = 'Warm-up'; stColor = [1, 0.6, 0];
                    else
                        stStr = 'High Stress'; stColor = [1, 0, 0];
                    end
                    set(txtBPM, 'String', sprintf('%.0f BPM', smoothBPM));
                    set(txtStatus, 'String', ['Status: ', stStr], 'Color', stColor);
                end
            end
        end
        
        % Heartbeat Animation
        if smoothBPM > 40
            beatDuration = 60 / smoothBPM; 
            elapsed = toc(lastBeatTime);
            if elapsed > beatDuration
                lastBeatTime = tic;
                elapsed = 0;
            end
            scale = 1 + (elapsed < beatDuration*0.3) * 0.15 * sin((elapsed/(beatDuration*0.3))*pi);
            set(hHeart, 'XData', heartX * max(1, scale), 'YData', heartY * max(1, scale));
        end

%% Audio
        if smoothBPM < 75
            targetTrackIdx = 1; 
        elseif smoothBPM < 100
            targetTrackIdx = 2; 
        else
            targetTrackIdx = 3; 
        end
        
        if targetTrackIdx ~= currentTrackIdx
            currentTrackIdx = targetTrackIdx;
        end

        currentTrack = audioData{currentTrackIdx};
        if ~isempty(currentTrack)
            % Write 2 frames per sensor update to stay ahead of the hardware buffer
            for frameCount = 1:2
                endIndex = audioPtr + frameSize - 1;
                
                if endIndex <= length(currentTrack)
                    audioFrame = currentTrack(audioPtr:endIndex);
                    audioPtr = endIndex + 1;
                else
                    % Loop back to start
                    audioFrame = [currentTrack(audioPtr:end); currentTrack(1:(frameSize - (length(currentTrack)-audioPtr+1)))];
                    audioPtr = frameSize - (length(currentTrack)-audioPtr+1) + 1;
                end
                
                % Standard call to deviceWriter
                deviceWriter(audioFrame * globalGain);
            end
        end
    end
    drawnow limitrate nocallbacks;
end

% Cleanup resources
release(deviceWriter);