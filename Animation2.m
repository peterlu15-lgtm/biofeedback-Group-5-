% =========================================================
%  Realistic Cloud & Field of Flowers Animation
%  - Multiple flowers across the field
%  - All petals open simultaneously (no stagger)
%  - Volumetric clouds with parallax
%  Run in MATLAB R2019b or later
% =========================================================

fig = figure('Color',[0.53 0.80 0.96], 'Position',[80 80 860 540], ...
    'Name','Field of Flowers','NumberTitle','off','MenuBar','none');
ax = axes('Parent',fig,'Position',[0 0 1 1], ...
    'XLim',[0 860],'YLim',[0 540], ...
    'Color',[0.53 0.80 0.96],'XTick',[],'YTick',[],'YDir','reverse');
hold(ax,'on'); axis(ax,'off');
W = 860; H = 540;

% ---- Sky gradient ----------------------------------------
nBands = 30;
for i = 1:nBands
    y0 = H*(i-1)/nBands; y1 = H*i/nBands;
    t  = (i-1)/(nBands-1);
    c  = min([0.38+0.20*t, 0.60+0.22*t, 0.86+0.10*t],1);
    fill(ax,[0 W W 0],[y0 y0 y1 y1],c,'EdgeColor','none');
end

% ---- Sun + halo ------------------------------------------
th = linspace(0,2*pi,80);
SX = W*0.86; SY = H*0.11;
for hi = 1:4
    r   = 34 + hi*22;
    alp = max(0.10 - hi*0.02, 0);
    fill(ax, SX+r*cos(th), SY+r*sin(th), [1 0.97 0.82],'EdgeColor','none','FaceAlpha',alp);
end
fill(ax, SX+32*cos(th), SY+32*sin(th), [1 0.91 0.28],'EdgeColor','none');

% ---- Ground / rolling hill -------------------------------
hillX = linspace(0,W,200);
hillY = H*0.78 + 22*sin(hillX/W*pi) - 14*sin(hillX/W*2*pi);
gndX  = [hillX, W, 0];
gndY  = [hillY, H, H];
fill(ax, gndX, gndY, [0.30 0.60 0.16],'EdgeColor','none');


% =========================================================
%  FLOWER DEFINITIONS
%  Each flower: [x_position, y_base, scale, bloom_delay,
%                r, g, b  (petal colour),  petal_count]
%  bloom_delay: 0=first to open, 1=last (fraction of anim)
% =========================================================
flowerDefs = [
  % x        yBase        scale  delay   R     G     B    nP
  W*0.50,  H*0.80,       1.00,  0.00,  0.85, 0.06, 0.08,  8;   % red centre
  W*0.25,  H*0.82,       0.72,  0.12,  0.90, 0.55, 0.05,  6;   % orange left
  W*0.75,  H*0.81,       0.78,  0.08,  0.80, 0.10, 0.70,  7;   % purple right
  W*0.12,  H*0.83,       0.58,  0.20,  0.95, 0.85, 0.05,  5;   % yellow far-left
  W*0.88,  H*0.82,       0.62,  0.15,  0.10, 0.50, 0.85,  6;   % blue far-right
  W*0.38,  H*0.84,       0.65,  0.18,  1.00, 0.40, 0.60,  8;   % pink mid-left
  W*0.63,  H*0.83,       0.68,  0.10,  0.20, 0.75, 0.30,  6;   % green mid-right
  W*0.06,  H*0.85,       0.48,  0.25,  0.85, 0.06, 0.08,  5;   % tiny red far-left
  W*0.94,  H*0.84,       0.50,  0.22,  0.90, 0.70, 0.10,  5;   % tiny yellow far-right
  W*0.32,  H*0.86,       0.42,  0.30,  0.70, 0.15, 0.80,  6;   % tiny purple back
  W*0.70,  H*0.86,       0.44,  0.28,  1.00, 0.45, 0.10,  6;   % tiny orange back
];
nFlowers = size(flowerDefs,1);

% ---- Pre-allocate all flower graphic handles -------------
nStem    = 40;
stem_t   = linspace(0,1,nStem);
nPP      = 24;
tp2      = linspace(0,2*pi,nPP);
maxPetals = 8;

% Structs via cell arrays for each flower
fStemS  = gobjects(nFlowers,1);
fStem   = gobjects(nFlowers,1);
fLeaf1  = gobjects(nFlowers,1);
fLeaf2  = gobjects(nFlowers,1);
fCalyx  = gobjects(nFlowers, 5);
fPetalS = gobjects(nFlowers, maxPetals);
fPetal  = gobjects(nFlowers, maxPetals);
fStamenL= gobjects(nFlowers, 18);
fStamenA= gobjects(nFlowers, 18);
fCenter = gobjects(nFlowers,1);

flowerAngles = cell(nFlowers,1);

for fi = 1:nFlowers
    fx   = flowerDefs(fi,1);
    fy   = flowerDefs(fi,2);
    nP   = flowerDefs(fi,8);
    fc   = flowerDefs(fi,5:7);

    % Stem
    fStemS(fi) = plot(ax,zeros(1,nStem),zeros(1,nStem),'Color',[0 0.15 0 0.18],'LineWidth',7);
    fStem(fi)  = plot(ax,zeros(1,nStem),zeros(1,nStem),'Color',[0.18 0.48 0.06],'LineWidth',5);

    % Leaves
    fLeaf1(fi) = fill(ax,fx,fy,[0.14 0.52 0.10],'EdgeColor','none');
    fLeaf2(fi) = fill(ax,fx,fy,[0.16 0.55 0.12],'EdgeColor','none');

    % Calyx
    for ci = 1:5
        fCalyx(fi,ci) = fill(ax,fx,fy,[0.18 0.48 0.06],'EdgeColor','none');
    end

    % Petals
    pa = linspace(0,2*pi,nP+1); pa(end)=[];
    flowerAngles{fi} = pa;
    for p = 1:maxPetals
        fPetalS(fi,p) = fill(ax,fx,fy,fc*0.6,'EdgeColor','none','FaceAlpha',0.12);
        fPetal(fi,p)  = fill(ax,fx,fy,fc,'EdgeColor',fc*0.65,'LineWidth',0.5);
        if p > nP
            set(fPetalS(fi,p),'Visible','off');
            set(fPetal(fi,p), 'Visible','off');
        end
    end

    % Stamens
    for s = 1:18
        fStamenL(fi,s) = plot(ax,[fx fx],[fy fy],'Color',[0.86 0.70 0.04],'LineWidth',0.8);
        fStamenA(fi,s) = fill(ax,fx,fy,[0.94 0.78 0.08],'EdgeColor','none');
    end

    % Center
    fCenter(fi) = fill(ax,fx+5*cos(th),fy+5*sin(th),[0.88 0.56 0.04],...
        'EdgeColor',[0.50 0.28 0],'LineWidth',0.8);
end

% ---- Clouds ----------------------------------------------
cloudData = [ ...
    W*0.20, H*0.18, 0.70, 0.22, 0, 10, 0.60; ...
    W*0.75, H*0.12, 0.55, 0.18, 0, 20, 0.58; ...
    W*0.55, H*0.22, 1.00, 0.40, 1, 30, 0.88; ...
    W*1.10, H*0.16, 0.85, 0.35, 1, 40, 0.85; ...
    W*1.50, H*0.28, 0.90, 0.45, 1, 50, 0.87; ...
    W*0.88, H*0.08, 1.15, 0.55, 2, 60, 0.92; ...
    W*1.35, H*0.20, 1.00, 0.50, 2, 70, 0.90  ...
];
nClouds    = size(cloudData,1);
cloud_x    = cloudData(:,1); cloud_y = cloudData(:,2);
cloud_s    = cloudData(:,3); cloud_sp= cloudData(:,4);
cloud_layer= cloudData(:,5); cloud_seed=cloudData(:,6);
cloud_alpha= cloudData(:,7);

blobOff = [0 0;58 24;-58 20;28 -14;-28 -12;20 30;-20 32;38 10;-38 12];
blobRx  = [52 40 38 32 32 28 28 30 30];
blobRy  = [37 29 27 23 23 20 20 22 22];
nBlobs  = size(blobOff,1);

cShadow = gobjects(nClouds,nBlobs);
cBody   = gobjects(nClouds,nBlobs);
cHigh   = gobjects(nClouds,nBlobs);
for ci = 1:nClouds
    for bi = 1:nBlobs
        cShadow(ci,bi)=fill(ax,0,0,[0.72 0.78 0.86],'EdgeColor','none','FaceAlpha',0.10);
        cBody(ci,bi)  =fill(ax,0,0,[0.96 0.97 1.00],'EdgeColor','none','FaceAlpha',0.85);
        cHigh(ci,bi)  =fill(ax,0,0,[1.00 1.00 1.00],'EdgeColor','none','FaceAlpha',0.45);
    end
end

fill(ax,[0 W W 0],[H*0.60 H*0.60 H*0.84 H*0.84],[0.80 0.88 1.00],...
    'EdgeColor','none','FaceAlpha',0.14);

% =========================================================
%  ANIMATION LOOP
% =========================================================
nFrames = 420;
for f = 1:nFrames
    globalBloom = min(f/280, 1);
    windPhase   = f * 0.022;

    % ======================================================
    %  UPDATE EACH FLOWER
    % ======================================================
    for fi = 1:nFlowers
        fx     = flowerDefs(fi,1);
        fBase  = flowerDefs(fi,2);
        fsc    = flowerDefs(fi,3);
        delay  = flowerDefs(fi,4);
        fc     = flowerDefs(fi,5:7);
        nP     = flowerDefs(fi,8);
        fTipY  = fBase - 280*fsc;

        % Per-flower bloom (delayed)
        raw   = max(0, (globalBloom - delay)/(1 - delay + 1e-9));
        bloom = min(raw^2*(3-2*raw), 1);   % smoothstep

        % -- Stem --
        sway  = sin(windPhase*0.7 + fi*0.8) * 5*fsc * bloom;
        cTipX = fx + sway;
        cTipY = fTipY;
        c1    = [fx + sin(windPhase*0.5+fi)*3*fsc,  fBase - 60*fsc];
        c2    = [cTipX - 6*fsc,                      cTipY + 50*fsc];
        p0b   = [fx, fBase]; p3b = [cTipX, cTipY];
        sX = zeros(1,nStem); sY = zeros(1,nStem);
        for si = 1:nStem
            tt=stem_t(si); mt=1-tt;
            sX(si)=mt^3*p0b(1)+3*mt^2*tt*c1(1)+3*mt*tt^2*c2(1)+tt^3*p3b(1);
            sY(si)=mt^3*p0b(2)+3*mt^2*tt*c1(2)+3*mt*tt^2*c2(2)+tt^3*p3b(2);
        end
        set(fStemS(fi),'XData',sX+2,'YData',sY+2);
        set(fStem(fi), 'XData',sX,  'YData',sY);

        % -- Leaves --
        leafT = min(bloom*1.6,1);
        if leafT > 0.01
            wl = sin(windPhase*0.8+fi)*3*leafT;
            [l1x,l1y]=localLeaf(fx-1,fBase-60*fsc, 40*fsc*leafT,14*fsc*leafT,-0.6+wl*0.05);
            [l2x,l2y]=localLeaf(fx+1,fBase-95*fsc, 40*fsc*leafT,14*fsc*leafT, 0.5+wl*0.05);
            set(fLeaf1(fi),'XData',l1x,'YData',l1y);
            set(fLeaf2(fi),'XData',l2x,'YData',l2y);
        end

        % -- Calyx --
        calyxT = min(bloom*3,1);
        for ci = 1:5
            ca  = (ci-1)/5*2*pi - pi/2;
            sl  = 10*fsc*calyxT;
            cpx = [cTipX, cTipX+cos(ca+0.25)*sl*0.5, cTipX+cos(ca)*sl, ...
                   cTipX+cos(ca-0.25)*sl*0.5, cTipX];
            cpy = [cTipY, cTipY+sin(ca+0.25)*sl*0.5, cTipY+sin(ca)*sl, ...
                   cTipY+sin(ca-0.25)*sl*0.5, cTipY];
            set(fCalyx(fi,ci),'XData',cpx,'YData',cpy);
        end

        % -- Petals (ALL open simultaneously, no stagger) --
        pa = flowerAngles{fi};
        for p = 1:nP
            ang2 = pa(p) + sin(windPhase*0.9 + p*0.7 + fi*1.1)*0.04*bloom;
            pLen = (6 + 42*bloom)*fsc;
            pWid = (2 + 16*bloom)*fsc;
            curv = 0.55 - 0.48*bloom;
            ex2  = pLen*(1-curv)*cos(tp2);
            ey2  = pWid*sin(tp2);
            px2  = ex2*cos(ang2) - ey2*sin(ang2) + cTipX + pLen*0.5*cos(ang2);
            py2  = ex2*sin(ang2) + ey2*cos(ang2) + cTipY + pLen*0.5*sin(ang2);
            set(fPetalS(fi,p),'XData',px2+2,'YData',py2+2);
            set(fPetal(fi,p), 'XData',px2,   'YData',py2,...
                'FaceColor',fc,'FaceAlpha',0.45+0.50*bloom);
        end

        % -- Stamens --
        stT = max(0,(bloom-0.60)/0.40);
        for s = 1:18
            sa    = (s-1)/18*2*pi;
            sd    = (4 + mod(s*1.7,4))*fsc*stT;
            sx1   = cTipX+cos(sa)*2*fsc; sy1 = cTipY+sin(sa)*2*fsc;
            sx2   = cTipX+cos(sa)*(sd+3*fsc); sy2 = cTipY+sin(sa)*(sd+3*fsc);
            set(fStamenL(fi,s),'XData',[sx1 sx2],'YData',[sy1 sy2],...
                'Color',[0.86 0.70 0.04 stT*0.75]);
            ar = 1.5*fsc*stT;
            set(fStamenA(fi,s),'XData',sx2+ar*cos(th),'YData',sy2+ar*sin(th));
        end

        % -- Center --
        cr = 8*fsc*min(bloom*2,1);
        set(fCenter(fi),'XData',cTipX+cr*cos(th),'YData',cTipY+cr*sin(th));
    end


    % ======================================================
    %  CLOUDS
    % ======================================================
    for ci = 1:nClouds
        cloud_x(ci) = cloud_x(ci) - cloud_sp(ci);
        if cloud_x(ci) < -180
            cloud_x(ci) = W+80+rand()*120;
            cloud_y(ci) = H*(0.05+rand()*0.28);
        end
        cloud_y(ci) = cloud_y(ci) + sin(f*0.008+cloud_seed(ci))*0.08;
        cx2=cloud_x(ci); cy2=cloud_y(ci); cs=cloud_s(ci);
        alp2=cloud_alpha(ci)*(0.55+0.45*(cloud_layer(ci)>0));
        for bi=1:nBlobs
            bx2=cx2+blobOff(bi,1)*cs; by2=cy2+blobOff(bi,2)*cs;
            rx2=blobRx(bi)*cs; ry2=blobRy(bi)*cs;
            [ex2,ey2]=localEllipse(bx2,by2+ry2*0.30,rx2*1.1,ry2*0.45,22);
            set(cShadow(ci,bi),'XData',ex2,'YData',ey2,'FaceAlpha',0.10*alp2);
            [ex2,ey2]=localEllipse(bx2,by2,rx2,ry2,22);
            bc=min([0.90+0.06*(1-bi/nBlobs),0.93+0.04*(1-bi/nBlobs),1.00],1);
            set(cBody(ci,bi),'XData',ex2,'YData',ey2,'FaceColor',bc,'FaceAlpha',0.80*alp2);
            [ex2,ey2]=localEllipse(bx2-rx2*0.08,by2-ry2*0.15,rx2*0.62,ry2*0.58,22);
            set(cHigh(ci,bi),'XData',ex2,'YData',ey2,'FaceAlpha',0.38*alp2);
        end
    end

    drawnow limitrate;
    pause(0.025);
end
hold(ax,'off');
disp('Animation complete!');

% =========================================================
%  LOCAL HELPER FUNCTIONS
% =========================================================
function [lx,ly] = localLeaf(baseX,baseY,len,wid,angle)
    n=20; tv=linspace(0,1,n);
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