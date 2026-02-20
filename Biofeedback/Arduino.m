% 针对官方库 RawValues 示例的 MATLAB 绘图
clear; clc;

device = serialport("COM3", 115200); % 确认 COM 号
configureTerminator(device, "LF");

windowSize = 500;
irData = zeros(1, windowSize);
redData = zeros(1, windowSize);

figure('Name', 'ExPulse Raw Data Plotter');
h1 = subplot(2,1,1); hLineIR = plot(irData, 'r'); title('IR Channel'); grid on;
h2 = subplot(2,1,2); hLineRed = plot(redData, 'b'); title('Red Channel'); grid on;

while true
    line = readline(device);
    if isempty(line), continue; end
    
    % 解析 IR 和 RED (按 Tab 分割)
    parts = str2double(strsplit(strtrim(line), '\t'));
    
    if length(parts) == 2
        irData = [irData(2:end), parts(1)];
        redData = [redData(2:end), parts(2)];
        
        % 只画波动部分（去直流），让波形更明显
        set(hLineIR, 'YData', irData - mean(irData));
        set(hLineRed, 'YData', redData - mean(redData));
        
        % 动态调整坐标轴
        subplot(h1); ylim([min(irData-mean(irData))-50, max(irData-mean(irData))+50]);
        subplot(h2); ylim([min(redData-mean(redData))-50, max(redData-mean(redData))+50]);
    end
    drawnow limitrate;
end