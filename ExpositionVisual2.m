clear;
clc;

% Reset any stale CloseRequestFcn from a previous run before closing figures
existingFigs = findall(0, 'Type', 'figure');
for fi_ = 1:length(existingFigs)
    set(existingFigs(fi_), 'CloseRequestFcn', 'closereq');
end
close all;

% Clear any leftover audio objects from previous runs
clear sound;
try
    objs = findall(0);
    for i_ = 1:length(objs)
        try, release(objs(i_)); catch, end
    end
catch
end

%% ── Serial Port ───────────────────────────────────────────────────────────
try
    if ~isempty(serialportfind("Port", "COM3"))
        delete(serialportfind("Port", "COM3"));
    end
    device = serialport("COM4", 115200);
    configureTerminator(device, "LF");
    flush(device);
    disp('System Ready');
catch
    error('Serial port connection failed. Please check COM port and cable.');
end

%% ── Signal Processing ─────────────────────────────────────────────────────
fs          = 25;
windowSize  = 300;
calcWindow  = 125;
irBuffer    = zeros(1, windowSize);
smoothBPM   = 70;
calcCounter = 0;
nullCount   = 0;          % track consecutive bad reads
MAX_NULLS   = 50;         % frames before showing "Signal Lost"
[b, a] = butter(2, [0.5, 4] / (fs/2), 'bandpass');

%% ── Audio Setup (audioplayer -- no device locking issues) ─────────────
fsAudio  = 44100;
zenTrack = [];
player   = [];
try
    [data, fsAudio] = audioread('zen.wav');
    if size(data,2) > 1, data = mean(data,2); end
    zenTrack = data * 0.5;   % apply gain here once
    % audioplayer loops automatically when we set up StopFcn to restart
    player = audioplayer(zenTrack, fsAudio);
    set(player, 'StopFcn', @(p,~) play(p));  % seamless loop on stop
    play(player);
    disp('zen.wav loaded and playing');
catch
    warning('zen.wav not found or audio error. No audio will play.');
end


%% ── Canvas ────────────────────────────────────────────────────────────────
W = 900;  H = 600;
fig = figure('Color',[0.53 0.80 0.96], 'Position',[60 60 W H], ...
    'Name','ExPulse - Flower Field', 'NumberTitle','off', ...
    'MenuBar','none', 'ToolBar','none');
ax = axes('Parent',fig, 'Position',[0 0 1 1], ...
    'XLim',[0 W], 'YLim',[0 H], ...
    'Color',[0.53 0.80 0.96], 'XTick',[], 'YTick',[], 'YDir','reverse');
hold(ax,'on');  axis(ax,'off');

th  = linspace(0, 2*pi, 60);

%% ── Static background (drawn ONCE, never redrawn) ─────────────────────────
% Sky gradient -- static image painted once
nBands = 30;
for i = 1:nBands
    y0 = H*(i-1)/nBands;  y1 = H*i/nBands;
    t2 = (i-1)/(nBands-1);
    c  = min([0.38+0.20*t2, 0.60+0.22*t2, 0.86+0.10*t2], 1);
    fill(ax, [0 W W 0], [y0 y0 y1 y1], c, 'EdgeColor','none');
end

% Atmospheric haze
fill(ax,[0 W W 0],[H*0.60 H*0.60 H*0.84 H*0.84],[0.80 0.88 1.00],...
    'EdgeColor','none','FaceAlpha',0.14);

%% ── Sun (position driven by session state) ───────────────────────────
SX        = W*0.50;           % horizontal centre of arc
SY_start  = H*0.78;           % just above horizon
SY_top    = H*0.10;           % top of sky
SY_curr   = SY_start;         % current Y (updated each frame)
sunGlow   = 0.35;             % starts dim during measure phase
hSunHalos = gobjects(4,1);
for hi = 1:4
    r = 34 + hi*22;
    hSunHalos(hi) = fill(ax, SX+r*cos(th), SY_start+r*sin(th), ...
        [1 0.97 0.82], 'EdgeColor','none', 'FaceAlpha', max(0.10-hi*0.02,0));
end
hSunDisc = fill(ax, SX+32*cos(th), SY_start+32*sin(th), ...
    [1 0.91 0.28], 'EdgeColor','none');

%% ── Rolling hill ──────────────────────────────────────────────────────────
hillX = linspace(0, W, 300);
hillY = H*0.76 + 22*sin(hillX/W*pi) - 14*sin(hillX/W*2*pi);
fill(ax, [hillX, W, 0], [hillY, H, H], [0.30 0.60 0.16], 'EdgeColor','none');

%% ── Flower Definitions (7 flowers) ───────────────────────────────────────
% [x, yBase, scale, R, G, B, nPetals]
flowerDefs = [
  W*0.10,  0,  0.55,   0.95, 0.85, 0.05,  5;   % yellow
  W*0.26,  0,  0.68,   1.00, 0.40, 0.60,  8;   % pink
  W*0.42,  0,  0.60,   0.70, 0.15, 0.80,  6;   % purple
  W*0.55,  0,  0.92,   0.85, 0.06, 0.08,  8;   % red (hero)
  W*0.67,  0,  0.65,   0.20, 0.75, 0.30,  6;   % green
  W*0.80,  0,  0.70,   0.80, 0.10, 0.70,  7;   % violet
  W*0.92,  0,  0.52,   0.10, 0.50, 0.85,  6;   % blue
];
nFlowers = size(flowerDefs,1);

% Snap yBase to hill surface
for fi = 1:nFlowers
    [~, idx] = min(abs(hillX - flowerDefs(fi,1)));
    flowerDefs(fi,2) = hillY(idx);
end

%% ── Pre-allocate Flower Graphics ──────────────────────────────────────────
nStem     = 30;            % reduced from 40 -- still smooth, faster
stem_t    = linspace(0,1,nStem);
nPP       = 22;            % petal polygon points -- reduced from 28
tp2       = linspace(0,2*pi,nPP);
maxPetals = 8;
NUM_STAMENS = 10;          % reduced from 18 -- big speed win

fStemS  = gobjects(nFlowers,1);
fStem   = gobjects(nFlowers,1);
fLeaf1  = gobjects(nFlowers,1);
fLeaf2  = gobjects(nFlowers,1);
fCalyx  = gobjects(nFlowers,5);
fPetalS = gobjects(nFlowers,maxPetals);
fPetal  = gobjects(nFlowers,maxPetals);
fStamenL= gobjects(nFlowers,NUM_STAMENS);
fStamenA= gobjects(nFlowers,NUM_STAMENS);
fCenter = gobjects(nFlowers,1);
flowerAngles = cell(nFlowers,1);

for fi = 1:nFlowers
    fx = flowerDefs(fi,1);  fy = flowerDefs(fi,2);
    nP = flowerDefs(fi,7);  fc = flowerDefs(fi,4:6);

    fStemS(fi) = plot(ax,zeros(1,nStem),zeros(1,nStem),'Color',[0 0.15 0 0.18],'LineWidth',6);
    fStem(fi)  = plot(ax,zeros(1,nStem),zeros(1,nStem),'Color',[0.18 0.48 0.06],'LineWidth',4);
    fLeaf1(fi) = fill(ax,fx,fy,[0.14 0.52 0.10],'EdgeColor','none');
    fLeaf2(fi) = fill(ax,fx,fy,[0.16 0.55 0.12],'EdgeColor','none');
    for ci2 = 1:5
        fCalyx(fi,ci2) = fill(ax,fx,fy,[0.18 0.48 0.06],'EdgeColor','none');
    end
    pa = linspace(0,2*pi,nP+1);  pa(end)=[];
    flowerAngles{fi} = pa;
    for p = 1:maxPetals
        fPetalS(fi,p) = fill(ax,fx,fy,fc*0.6,'EdgeColor','none','FaceAlpha',0.12);
        fPetal(fi,p)  = fill(ax,fx,fy,fc,'EdgeColor',fc*0.65,'LineWidth',0.5);
        if p > nP
            set(fPetalS(fi,p),'Visible','off');
            set(fPetal(fi,p), 'Visible','off');
        end
    end
    for s = 1:NUM_STAMENS
        fStamenL(fi,s) = plot(ax,[fx fx],[fy fy],'Color',[0.86 0.70 0.04],'LineWidth',0.8);
        fStamenA(fi,s) = fill(ax,fx+cos(th),fy+sin(th),[0.94 0.78 0.08],'EdgeColor','none');
    end
    fCenter(fi) = fill(ax,fx+5*cos(th),fy+5*sin(th),[0.88 0.56 0.04],...
        'EdgeColor',[0.50 0.28 0],'LineWidth',0.8);
end

%% ── Volumetric Clouds (fewer blobs per cloud for speed) ───────────────────
cloudData = [
  W*0.18, H*0.18, 0.70, 0.22, 10, 0.60;
  W*0.72, H*0.12, 0.55, 0.18, 20, 0.58;
  W*0.52, H*0.23, 1.00, 0.28, 30, 0.88;
  W*1.10, H*0.16, 0.85, 0.32, 40, 0.85;
  W*0.88, H*0.08, 1.15, 0.40, 60, 0.92;
];
nClouds    = size(cloudData,1);
cloud_x    = cloudData(:,1);
cloud_y    = cloudData(:,2);
cloud_s    = cloudData(:,3);
cloud_sp   = cloudData(:,4);
cloud_seed = cloudData(:,5);
cloud_alpha= cloudData(:,6);

% Fewer blobs (5 instead of 9) -- still looks volumetric
blobOff = [0 0; 55 22; -55 18; 25 -12; -25 -10];
blobRx  = [50  38  36  30  30];
blobRy  = [35  27  25  21  21];
nBlobs  = size(blobOff,1);

cShadow = gobjects(nClouds,nBlobs);
cBody   = gobjects(nClouds,nBlobs);
cHigh   = gobjects(nClouds,nBlobs);
for ci2 = 1:nClouds
    for bi = 1:nBlobs
        cShadow(ci2,bi)=fill(ax,0,0,[0.72 0.78 0.86],'EdgeColor','none','FaceAlpha',0.10);
        cBody(ci2,bi)  =fill(ax,0,0,[0.96 0.97 1.00],'EdgeColor','none','FaceAlpha',0.85);
        cHigh(ci2,bi)  =fill(ax,0,0,[1.00 1.00 1.00],'EdgeColor','none','FaceAlpha',0.45);
    end
end

%% ── Session UI Overlays ──────────────────────────────────────────────────
hPhaseMsg = text(ax, W*0.5, H*0.12, 'Measuring resting heart rate...', ...
    'HorizontalAlignment','center','FontSize',18,...
    'FontWeight','bold','Color',[1 1 1],...
    'BackgroundColor',[0 0 0.35],'Margin',10,'Visible','on');
hRestInfo = text(ax, W*0.5, H*0.21, '', ...
    'HorizontalAlignment','center','FontSize',14,...
    'Color',[1 1 0.7],'Visible','off');
hCompleteMsg = text(ax, W*0.5, H*0.45, '', ...
    'HorizontalAlignment','center','FontSize',26,...
    'FontWeight','bold','Color',[1 1 1],...
    'BackgroundColor',[0 0.35 0],'Margin',16,'Visible','off');

%% ── Status / Signal Lost overlay ──────────────────────────────────────────
hStatusTxt = text(ax, W*0.5, H*0.97, 'Scanning...', ...
    'HorizontalAlignment','center','FontSize',13,...
    'FontWeight','bold','Color',[0.95 0.95 0.95],'FontAngle','italic');
hSignalLost = text(ax, W*0.5, H*0.50, '', ...
    'HorizontalAlignment','center','FontSize',22,...
    'FontWeight','bold','Color',[1 0.3 0.3],...
    'BackgroundColor',[0 0 0],'Margin',8,'Visible','off');

%% ── Animation State ───────────────────────────────────────────────────────
bloomPhase = zeros(1,nFlowers);
windPhase  = 0;
frameIdx   = 0;
stormFrac  = 0;

%% ── Session State Machine ────────────────────────────────────────────────
%  measure  -> 15s collect resting BPM
%  pause    -> 15s rest before session
%  rising   -> sun rises if BPM within restBPM+15
%  frozen   -> sun holds if BPM > restBPM+15
%  falling  -> sun reached top, descending
%  done     -> show completion message
sessionPhase = 'measure';
sessionTimer = tic;
restBPM      = 0;
restSamples  = [];
sunProgress  = 0.0;       % 0=horizon  1=peak
SUN_SPEED    = 0.0010;    % arc fraction per frame


%% ── Main Loop ─────────────────────────────────────────────────────────────
while ishandle(fig)

    %% ── Serial Read with full null/error handling ─────────────────────────
    rawLine = '';
    try
        rawLine = readline(device);
    catch
        % Serial timeout or disconnect
        nullCount = nullCount + 1;
        if nullCount >= MAX_NULLS
            set(hSignalLost,'String','!! Serial Disconnected','Visible','on');
        end
        drawnow limitrate nocallbacks;
        continue;
    end

    % readline can return a missing/non-string on timeout -- guard against it
    if ~ischar(rawLine) && ~isstring(rawLine)
        nullCount = nullCount + 1;
        if nullCount >= MAX_NULLS
            set(hSignalLost,'String','!! No Signal','Visible','on');
        end
        drawnow limitrate nocallbacks;
        continue;
    end

    % Check for empty or whitespace-only line
    rawLine = strtrim(char(rawLine));   % char() ensures string→char safe conversion
    if isempty(rawLine)
        nullCount = nullCount + 1;
        if nullCount >= MAX_NULLS
            set(hSignalLost,'String','!! No Signal','Visible','on');
        end
        drawnow limitrate nocallbacks;
        continue;
    end

    % Parse numeric value
    parts = str2double(strsplit(rawLine, '\t'));
    sensorVal = parts(1);

    % Check for NaN (non-numeric string), zero, or negative (invalid reads)
    if isnan(sensorVal) || sensorVal <= 0
        nullCount = nullCount + 1;
        if nullCount >= MAX_NULLS
            set(hSignalLost,'String','!! Invalid Sensor Data','Visible','on');
        end
        drawnow limitrate nocallbacks;
        continue;
    end

    % Valid read -- reset null counter and hide warning
    nullCount = 0;
    set(hSignalLost,'Visible','off');

    %% ── Buffer & Filter ───────────────────────────────────────────────────
    irBuffer = [irBuffer(2:end), sensorVal];
    frameIdx = frameIdx + 1;
    windPhase = windPhase + 0.022;

    firstValIdx = find(irBuffer > 0, 1, 'first');
    if isempty(firstValIdx), continue; end
    activeSignal = irBuffer(firstValIdx:end);
    currentLen   = length(activeSignal);

    detrended = activeSignal - mean(activeSignal);
    if length(detrended) > 6
        bandpassed   = filter(b, a, detrended);
        filteredData = movmean(bandpassed, 5);
    else
        continue;
    end

    %% ── BPM Calculation ───────────────────────────────────────────────────
    calcCounter = calcCounter + 1;
    if calcCounter >= 5 && currentLen > 2*fs
        calcCounter = 0;
        segmentLen  = min(currentLen, calcWindow);
        calcData    = filteredData(end-segmentLen+1:end);
        rangeVal    = max(calcData) - min(calcData);

        [~, locs] = findpeaks(calcData, ...
            'MinPeakDistance',   round(0.4*fs), ...
            'MinPeakProminence', rangeVal*0.20);

        if length(locs) >= 2
            intervals = diff(locs) / fs;
            if length(locs) < 4
                currentInstBPM = 60 / intervals(end);  weight = 0.3;
            else
                avgInterval    = mean(intervals(max(1,end-3):end));
                currentInstBPM = 60 / avgInterval;     weight = 0.04;
            end
            if smoothBPM == 0
                smoothBPM = currentInstBPM;
            else
                smoothBPM = smoothBPM*(1-weight) + currentInstBPM*weight;
            end

            bpmC = max(40, min(180, smoothBPM));
            stormFrac = (bpmC - 40) / 140;

            if smoothBPM < 70
                stStr = sprintf('%.0f BPM  |  Zen', smoothBPM);       stCol = [0.85 1.0 0.85];
            elseif smoothBPM < 100
                stStr = sprintf('%.0f BPM  |  Resting', smoothBPM);   stCol = [0.75 0.90 1.00];
            elseif smoothBPM < 130
                stStr = sprintf('%.0f BPM  |  Warm-up', smoothBPM);   stCol = [1.00 0.88 0.65];
            else
                stStr = sprintf('%.0f BPM  |  High Stress', smoothBPM); stCol = [1.00 0.70 0.70];
            end
            set(hStatusTxt,'String',stStr,'Color',stCol);

            % Bloom speed: SLOW at high BPM, FAST at low BPM
            bpmC = max(40, min(180, smoothBPM));
            bloomSpeedVal = 0.055 - (bpmC-40)/140 * 0.047;
        else
            bloomSpeedVal = 0.030;
        end
    else
        bloomSpeedVal = 0.030;
    end

    bloomPhase = bloomPhase + bloomSpeedVal;

    %% ── Session State Machine + Sun ──────────────────────────────────────
    elapsed = toc(sessionTimer);

    switch sessionPhase
        case 'measure'
            remaining = max(0, ceil(15 - elapsed));
            set(hPhaseMsg,'String', ...
                sprintf('Measuring resting heart rate...  %ds', remaining),'Visible','on');
            if smoothBPM > 30
                restSamples(end+1) = smoothBPM; %#ok<AGROW>
            end
            if elapsed >= 15
                restBPM = median(restSamples);
                set(hRestInfo,'String', ...
                    sprintf('Resting BPM: %.0f  |  Stay within: %.0f - %.0f', ...
                    restBPM, restBPM-15, restBPM+15),'Visible','on');
                sessionPhase = 'pause';
                sessionTimer = tic;
                disp(sprintf('Resting BPM: %.1f', restBPM));
            end

        case 'pause'
            remaining = max(0, ceil(15 - elapsed));
            set(hPhaseMsg,'String', ...
                sprintf('Raise your heart rate now!  %ds remaining', remaining),'Visible','on');
            if elapsed >= 15
                sessionPhase = 'rising';
                set(hPhaseMsg,'String','<3 Now calm down -- bring your heart rate back','Visible','on');
                disp('Rising phase started.');
            end

        case 'rising'
            if smoothBPM <= restBPM + 15
                sunProgress = min(1.0, sunProgress + SUN_SPEED);
                set(hPhaseMsg,'String','<3 Breathe -- keep your heart calm','Visible','on');
            else
                sessionPhase = 'frozen';
                set(hPhaseMsg,'String', ...
                    sprintf('!! Heart rate too high (%.0f BPM) -- relax to resume', smoothBPM),'Visible','on');
            end
            if sunProgress >= 1.0
                sessionPhase = 'falling';
                set(hPhaseMsg,'String','<3 Perfect! Now gently let go...','Visible','on');
            end

        case 'frozen'
            % Sun froze during rising - wait for BPM to drop
            set(hPhaseMsg,'String', ...
                sprintf('!! Relax -- %.0f BPM  (target <= %.0f)', smoothBPM, restBPM+15),'Visible','on');
            if smoothBPM <= restBPM + 15
                sessionPhase = 'rising';
            end

        case 'falling'
            if smoothBPM <= restBPM + 15
                sunProgress = max(0.0, sunProgress - SUN_SPEED);
                set(hPhaseMsg,'String','<3 Wonderful -- keep it calm, almost done...','Visible','on');
                if sunProgress <= 0
                    sessionPhase = 'done';
                    set(hPhaseMsg,'Visible','off');
                    set(hRestInfo,'Visible','off');
                    set(hCompleteMsg,'String', ...
                        sprintf('%s  Session Complete  %s\nResting BPM: %.0f\nWell done!', char(9829), char(9829), restBPM), ...
                        'Visible','on');
                    disp('Session complete.');
                end
            else
                % BPM too high during descent - freeze sun
                set(hPhaseMsg,'String', ...
                    sprintf('!! Stay calm -- %.0f BPM  (target <= %.0f)', smoothBPM, restBPM+15),'Visible','on');
            end

        case 'done'
            % Session finished, display stays open
    end

    %% ── Sun position & brightness ──────────────────────────────────────────
    SY_curr = SY_start + sunProgress * (SY_top - SY_start);

    if strcmp(sessionPhase,'measure') || strcmp(sessionPhase,'pause')
        sunGlow = sunGlow*0.97 + 0.30*0.03;
    elseif strcmp(sessionPhase,'frozen')
        sunGlow = sunGlow*0.97 + 0.45*0.03;
    else
        sunTarget = 1.0 - stormFrac*0.55;
        sunGlow   = sunGlow*0.94 + sunTarget*0.06;
    end

    sunDiscCol = min(1, [1.0 0.91 0.28]*sunGlow + [0.55 0.55 0.55]*(1-sunGlow));
    set(hSunDisc, 'FaceColor', sunDiscCol, ...
        'XData', SX+32*cos(th), 'YData', SY_curr+32*sin(th));
    for hi = 1:4
        r2 = 34 + hi*22;
        set(hSunHalos(hi), 'XData', SX+r2*cos(th), 'YData', SY_curr+r2*sin(th), ...
            'FaceAlpha', max(0,(0.10-hi*0.02)*sunGlow));
    end


    %% ── Clouds ────────────────────────────────────────────────────────────
    cloudBright = 1.0 - stormFrac*0.60;
    cloudAlpMul = 0.85 + stormFrac*0.15;
    cloudCol    = [cloudBright, cloudBright, min(1,cloudBright+0.03)];

    for ci2 = 1:nClouds
        cloud_x(ci2) = cloud_x(ci2) - cloud_sp(ci2);
        if cloud_x(ci2) < -180
            cloud_x(ci2) = W + 80 + rand()*120;
            cloud_y(ci2) = H*(0.05 + rand()*0.28);
        end
        cloud_y(ci2) = cloud_y(ci2) + sin(frameIdx*0.008+cloud_seed(ci2))*0.08;
        cx2=cloud_x(ci2); cy2=cloud_y(ci2); cs=cloud_s(ci2);
        alp2=cloud_alpha(ci2)*cloudAlpMul;
        for bi = 1:nBlobs
            bx2=cx2+blobOff(bi,1)*cs; by2=cy2+blobOff(bi,2)*cs;
            rx2=blobRx(bi)*cs;         ry2=blobRy(bi)*cs;
            [ex2,ey2]=localEllipse(bx2,by2+ry2*0.30,rx2*1.1,ry2*0.45,18);
            set(cShadow(ci2,bi),'XData',ex2,'YData',ey2);
            [ex2,ey2]=localEllipse(bx2,by2,rx2,ry2,18);
            bc=min(cloudCol+0.06*(1-bi/nBlobs),1);
            set(cBody(ci2,bi),'XData',ex2,'YData',ey2,'FaceColor',bc,'FaceAlpha',0.80*alp2);
            [ex2,ey2]=localEllipse(bx2-rx2*0.08,by2-ry2*0.15,rx2*0.62,ry2*0.58,18);
            set(cHigh(ci2,bi),'XData',ex2,'YData',ey2,'FaceAlpha',0.38*alp2*sunGlow);
        end
    end

    %% ── Flowers ───────────────────────────────────────────────────────────
    for fi = 1:nFlowers
        fx   = flowerDefs(fi,1);
        fBase= flowerDefs(fi,2);
        fsc  = flowerDefs(fi,3);
        fc   = min(flowerDefs(fi,4:6),1);
        nP   = flowerDefs(fi,7);

        bloom  = 0.5 + 0.5*sin(bloomPhase(fi));
        fTipY  = fBase - 260*fsc;
        sway   = sin(windPhase*0.7 + fi*0.8)*5*fsc*bloom;
        cTipX  = fx + sway;
        cTipY  = fTipY;

        % Bezier stem
        c1=[fx+sin(windPhase*0.5+fi)*3*fsc,  fBase-60*fsc];
        c2=[cTipX-6*fsc,                      cTipY+50*fsc];
        sX=zeros(1,nStem); sY=zeros(1,nStem);
        for si=1:nStem
            tt=stem_t(si); mt=1-tt;
            sX(si)=mt^3*fx   +3*mt^2*tt*c1(1)+3*mt*tt^2*c2(1)+tt^3*cTipX;
            sY(si)=mt^3*fBase+3*mt^2*tt*c1(2)+3*mt*tt^2*c2(2)+tt^3*cTipY;
        end
        set(fStemS(fi),'XData',sX+2,'YData',sY+2);
        set(fStem(fi), 'XData',sX,  'YData',sY);

        % Leaves
        leafT = min(bloom*1.5,1);
        if leafT > 0.01
            wl=sin(windPhase*0.8+fi)*3*leafT;
            [l1x,l1y]=localLeaf(fx-1,fBase-60*fsc,38*fsc*leafT,13*fsc*leafT,-0.6+wl*0.05);
            [l2x,l2y]=localLeaf(fx+1,fBase-90*fsc,38*fsc*leafT,13*fsc*leafT, 0.5+wl*0.05);
            set(fLeaf1(fi),'XData',l1x,'YData',l1y);
            set(fLeaf2(fi),'XData',l2x,'YData',l2y);
        end

        % Calyx
        calyxT=min(bloom*3,1);
        for ci2=1:5
            ca=(ci2-1)/5*2*pi-pi/2; sl=10*fsc*calyxT;
            cpx=[cTipX,cTipX+cos(ca+0.25)*sl*0.5,cTipX+cos(ca)*sl,cTipX+cos(ca-0.25)*sl*0.5,cTipX];
            cpy=[cTipY,cTipY+sin(ca+0.25)*sl*0.5,cTipY+sin(ca)*sl,cTipY+sin(ca-0.25)*sl*0.5,cTipY];
            set(fCalyx(fi,ci2),'XData',cpx,'YData',cpy);
        end

        % Petals
        pa=flowerAngles{fi};
        for p=1:nP
            ang2=pa(p)+sin(windPhase*0.9+p*0.7+fi*1.1)*0.04*bloom;
            pLen=(6+42*bloom)*fsc; pWid=(2+16*bloom)*fsc;
            curv=0.55-0.48*bloom;
            ex2=pLen*(1-curv)*cos(tp2); ey2=pWid*sin(tp2);
            px2=ex2*cos(ang2)-ey2*sin(ang2)+cTipX+pLen*0.5*cos(ang2);
            py2=ex2*sin(ang2)+ey2*cos(ang2)+cTipY+pLen*0.5*sin(ang2);
            set(fPetalS(fi,p),'XData',px2+2,'YData',py2+2);
            set(fPetal(fi,p), 'XData',px2,  'YData',py2,...
                'FaceColor',fc,'FaceAlpha',0.45+0.50*bloom);
        end

        % Stamens
        stT=max(0,(bloom-0.55)/0.45);
        for s=1:NUM_STAMENS
            sa=(s-1)/NUM_STAMENS*2*pi;
            sd=(4+mod(s*1.7,4))*fsc*stT;
            sx1=cTipX+cos(sa)*2*fsc; sy1=cTipY+sin(sa)*2*fsc;
            sx2=cTipX+cos(sa)*(sd+3*fsc); sy2=cTipY+sin(sa)*(sd+3*fsc);
            set(fStamenL(fi,s),'XData',[sx1 sx2],'YData',[sy1 sy2],...
                'Color',[0.86 0.70 0.04 stT*0.75]);
            ar=1.5*fsc*stT;
            set(fStamenA(fi,s),'XData',sx2+ar*cos(th),'YData',sy2+ar*sin(th));
        end

        % Center
        cr=8*fsc*min(bloom*2,1);
        set(fCenter(fi),'XData',cTipX+cr*cos(th),'YData',cTipY+cr*sin(th));
    end

    %% Audio plays via audioplayer in background -- nothing to do here

    drawnow limitrate nocallbacks;
end




%% Cleanup when figure is closed
% Stop audio player cleanly
if ~isempty(player) && isvalid(player)
    stop(player);
end

function [lx,ly] = localLeaf(baseX,baseY,len,wid,angle)
    n=16; tv=linspace(0,1,n);
    rx1=baseX+wid*0.8*sin(angle); ry1=baseY-len*0.4*cos(angle);
    rx2=baseX+wid*0.5*sin(angle); ry2=baseY-len*0.85*cos(angle);
    tipX=baseX; tipY=baseY-len;
    lxR=zeros(1,n); lyR=zeros(1,n);
    for ti=1:n
        tt=tv(ti); mt=1-tt;
        lxR(ti)=mt^3*baseX+3*mt^2*tt*rx1+3*mt*tt^2*rx2+tt^3*tipX;
        lyR(ti)=mt^3*baseY+3*mt^2*tt*ry1+3*mt*tt^2*ry2+tt^3*tipY;
    end
    lx1=baseX-wid*0.3*sin(angle); ly1=baseY-len*0.7*cos(angle);
    lx2=baseX-wid*0.1*sin(angle); ly2=baseY-len*0.3*cos(angle);
    lxL=zeros(1,n); lyL=zeros(1,n);
    for ti=1:n
        tt=tv(ti); mt=1-tt;
        lxL(ti)=mt^3*tipX+3*mt^2*tt*lx1+3*mt*tt^2*lx2+tt^3*baseX;
        lyL(ti)=mt^3*tipY+3*mt^2*tt*ly1+3*mt*tt^2*ly2+tt^3*baseY;
    end
    lx=[lxR,lxL]; ly=[lyR,lyL];
end

function [ex,ey] = localEllipse(cx,cy,rx,ry,n)
    t2=linspace(0,2*pi,n);
    ex=cx+rx*cos(t2); ey=cy+ry*sin(t2);
end