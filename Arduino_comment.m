clear; clc;

device = serialport("COM3", 115200); % Connect to the sensor via COM3 NOTE the baud rate
configureTerminator(device, "LF"); % Set end of line
%% 
windowSize = 500; % Show 500 points on graph
% Prefetch
irData = zeros(1, windowSize); % IR
redData = zeros(1, windowSize);% Red light

%% Create the plot windows
figure('Name', 'ExPulse Raw Data Plotter');
h1 = subplot(2,1,1); hLineIR = plot(irData, 'r'); title('IR Channel'); grid on;
h2 = subplot(2,1,2); hLineRed = plot(redData, 'b'); title('Red Channel'); grid on;

while true
    line = readline(device);% Read one line from serial
    if isempty(line), continue; end
    
    parts = str2double(strsplit(strtrim(line), '\t')); % Split text into numbers
    
    if length(parts) == 2 % Slide the window (Add new data)
        irData = [irData(2:end), parts(1)];
        redData = [redData(2:end), parts(2)];
        
        set(hLineIR, 'YData', irData - mean(irData));% Center the wave
        set(hLineRed, 'YData', redData - mean(redData));% Center the wave
        
        subplot(h1); ylim([min(irData-mean(irData))-50, max(irData-mean(irData))+50]);
        subplot(h2); ylim([min(redData-mean(redData))-50, max(redData-mean(redData))+50]);
    end
    %Refresh 
    drawnow limitrate;
end