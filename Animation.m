% =========================================================
%  Realistic Cloud & Blooming Flower Animation
%  Volumetric clouds with parallax, red flower with
%  staggered petal unfurl, wind sway, grass, sun halo.
%  Run in MATLAB R2019b or later.
% =========================================================

fig = figure('Color',[0.53 0.80 0.96], 'Position',[80 80 860 540], ...
    'Name','Cloud & Flower Scene','NumberTitle','off','MenuBar','none');
ax = axes('Parent',fig,'Position',[0 0 1 1], ...
    'XLim',[0 860],'YLim',[0 540], ...
    'Color',[0.53 0.80 0.96],'XTick',[],'YTick',[],'YDir','reverse');
hold(ax,'on'); axis(ax,'off');
W = 860; H = 540;

% =========================================================
%  HELPER FUNCTIONS (defined at end as local functions)
% =========================================================

% ---- Sky gradient (static coloured bands) ---------------
nBands = 30;
for i = 1:nBands
    y0 = H*(i-1)/nBands;  y1 = H*i/nBands;
    t  = (i-1)/(nBands-1);
    c  = min([0.38+0.20*t, 0.60+0.22*t, 0.86+0.10*t], 1);
    fill(ax,[0 W W 0],[y0 y0 y1 y1],c,'EdgeColor','none');
end

% ---- Sun + halo -----------------------------------------
th  = linspace(0,2*pi,80);
SX  = W*0.82; SY = H*0.25;
for hi = 1:10
    r   = 34 + hi*22;
    alp = max(0.12 - hi*0.01, 0);
    fill(ax, SX+r*cos(th), SY+r*sin(th), [1 0.97 0.82], ...
        'EdgeColor','none','FaceAlpha',alp);
end
fill(ax, SX+32*cos(th), SY+32*sin(th), [1 0.91 0.28],'EdgeColor','none');

% ---- Ground / rolling hill ------------------------------
hillX = linspace(0,W,200);
hillY = H*0.78 + 22*sin(hillX/W*pi) - 14*sin(hillX/W*2*pi);
gndX  = [hillX, W, 0];
gndY  = [hillY, H, H];
fill(ax, gndX, gndY, [0.30 0.60 0.16],'EdgeColor','none');

% ---- Stem (shadow + stem) --------------------------------
stemBaseX = W*0.5;  stemBaseY = H*0.80;
stemTipY  = H*0.52;
nStem     = 40;
stem_t    = linspace(0,1,nStem);
stemS_h   = plot(ax, zeros(1,nStem), zeros(1,nStem), ...
    'Color',[0 0.15 0 0.18], 'LineWidth',9);
stem_h    = plot(ax, zeros(1,nStem), zeros(1,nStem), ...
    'Color',[0.18 0.48 0.06], 'LineWidth',7);

% ---- Leaves ----------------------------------------------
leaf1_h  = fill(ax, stemBaseX, stemBaseY, [0.14 0.52 0.10],'EdgeColor','none');
leaf2_h  = fill(ax, stemBaseX, stemBaseY, [0.16 0.55 0.12],'EdgeColor','none');
leaf1v_h = plot(ax, [stemBaseX stemBaseX],[stemBaseY stemBaseY], ...
    'Color',[0.08 0.34 0.04],'LineWidth',0.8);
leaf2v_h = plot(ax, [stemBaseX stemBaseX],[stemBaseY stemBaseY], ...
    'Color',[0.08 0.34 0.04],'LineWidth',0.8);

% ---- Calyx -----------------------------------------------
nCalyx  = 5;
calyx_h = gobjects(nCalyx,1);
for ci = 1:nCalyx
    calyx_h(ci) = fill(ax, stemBaseX, stemBaseY, [0.18 0.48 0.06],'EdgeColor','none');
end

% ---- Petals ----------------------------------------------
nPetals     = 8;
petalAngles = linspace(0, 2*pi, nPetals+1); petalAngles(end)=[];
petalS_h    = gobjects(nPetals,1);
petal_h     = gobjects(nPetals,1);
for p = 1:nPetals
    petalS_h(p) = fill(ax, stemBaseX, stemBaseY, [0.50 0 0.02], ...
        'EdgeColor','none','FaceAlpha',0.15);
    petal_h(p)  = fill(ax, stemBaseX, stemBaseY, [0.85 0.06 0.08], ...
        'EdgeColor',[0.55 0 0.05],'LineWidth',0.6);
end

% ---- Stamens --------------------------------------------
nStamen  = 18;
stamen_h = gobjects(nStamen,1);
anther_h = gobjects(nStamen,1);
for s = 1:nStamen
    stamen_h(s) = plot(ax, [stemBaseX stemBaseX],[stemBaseY stemBaseY], ...
        'Color',[0.86 0.70 0.04],'LineWidth',0.9);
    anther_h(s) = fill(ax, stemBaseX, stemBaseY, [0.94 0.78 0.08],'EdgeColor','none');
end

% ---- Center disc ----------------------------------------
center_h = fill(ax, stemBaseX+10*cos(th), stemBaseY+10*sin(th), ...
    [0.88 0.56 0.04],'EdgeColor',[0.50 0.28 0],'LineWidth',1);

% ---- Clouds (7 total, 3 layers) -------------------------
% columns: x, y, scale, speed, layer, seed, alpha
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
cloud_x    = cloudData(:,1);
cloud_y    = cloudData(:,2);
cloud_s    = cloudData(:,3);
cloud_sp   = cloudData(:,4);
cloud_layer= cloudData(:,5);
cloud_seed = cloudData(:,6);
cloud_alpha= cloudData(:,7);

% Blob layout inside each cloud (offsets + radii, unscaled)
blobOff = [0 0;58 24;-58 20;28 -14;-28 -12;20 30;-20 32;38 10;-38 12];
blobRx  = [52 40 38 32 32 28 28 30 30];
blobRy  = [37 29 27 23 23 20 20 22 22];
nBlobs  = size(blobOff,1);

cShadow = gobjects(nClouds, nBlobs);
cBody   = gobjects(nClouds, nBlobs);
cHigh   = gobjects(nClouds, nBlobs);
for ci = 1:nClouds
    for bi = 1:nBlobs
        cShadow(ci,bi) = fill(ax,0,0,[0.72 0.78 0.86],'EdgeColor','none','FaceAlpha',0.10);
        cBody(ci,bi)   = fill(ax,0,0,[0.96 0.97 1.00],'EdgeColor','none','FaceAlpha',0.85);
        cHigh(ci,bi)   = fill(ax,0,0,[1.00 1.00 1.00],'EdgeColor','none','FaceAlpha',0.45);
    end
end

% ---- Haze overlay ----------------------------------------
fill(ax,[0 W W 0],[H*0.60 H*0.60 H*0.84 H*0.84], ...
    [0.80 0.88 1.00],'EdgeColor','none','FaceAlpha',0.14);

% =========================================================
%  ANIMATION LOOP
% =========================================================
nFrames = 420;
for f = 1:nFrames

    bloom     = min(f / 280, 1);
    windPhase = f * 0.022;

    % -- Stem bezier --------------------------------------
    sway  = sin(windPhase*0.7) * 6 * bloom;
    cTipX = stemBaseX + sway;
    cTipY = stemTipY;
    c1    = [stemBaseX + sin(windPhase*0.5)*4,  stemBaseY - 60];
    c2    = [cTipX - 8,                          cTipY + 60];
    p0    = [stemBaseX, stemBaseY];
    p3    = [cTipX,     cTipY];
    stemX = zeros(1,nStem); stemY = zeros(1,nStem);
    for si = 1:nStem
        tt = stem_t(si); mt = 1-tt;
        stemX(si) = mt^3*p0(1)+3*mt^2*tt*c1(1)+3*mt*tt^2*c2(1)+tt^3*p3(1);
        stemY(si) = mt^3*p0(2)+3*mt^2*tt*c1(2)+3*mt*tt^2*c2(2)+tt^3*p3(2);
    end
    set(stemS_h,'XData',stemX+3,'YData',stemY+3);
    set(stem_h, 'XData',stemX,  'YData',stemY);

    % -- Leaves -------------------------------------------
    leafT = min(bloom * 1.6, 1);
    if leafT > 0.01
        windLean = sin(windPhase*0.8) * 4 * leafT;
        l1ang = -0.6 + windLean*0.05;
        l2ang =  0.5 + windLean*0.05;
        [l1x,l1y] = localLeaf(stemBaseX-2, stemBaseY-85,  52*leafT, 18*leafT, l1ang);
        [l2x,l2y] = localLeaf(stemBaseX+2, stemBaseY-125, 52*leafT, 18*leafT, l2ang);
        set(leaf1_h,'XData',l1x,'YData',l1y);
        set(leaf2_h,'XData',l2x,'YData',l2y);
        set(leaf1v_h,'XData',[stemBaseX-2, stemBaseX-2+sin(l1ang)*8], ...
                     'YData',[stemBaseY-85, stemBaseY-85-52*leafT]);
        set(leaf2v_h,'XData',[stemBaseX+2, stemBaseX+2+sin(l2ang)*8], ...
                     'YData',[stemBaseY-125, stemBaseY-125-52*leafT]);
    end

    % -- Calyx --------------------------------------------
    calyxT = min(bloom * 3, 1);
    for ci = 1:nCalyx
        ca  = (ci-1)/nCalyx * 2*pi - pi/2;
        sl  = 14 * calyxT;
        % simple triangle petal
        cpx = [cTipX, cTipX + cos(ca+0.25)*sl*0.5, cTipX + cos(ca)*sl, ...
               cTipX + cos(ca-0.25)*sl*0.5, cTipX];
        cpy = [cTipY, cTipY + sin(ca+0.25)*sl*0.5, cTipY + sin(ca)*sl, ...
               cTipY + sin(ca-0.25)*sl*0.5, cTipY];
        set(calyx_h(ci),'XData',cpx,'YData',cpy);
    end

    % -- Petals -------------------------------------------
    nPP = 24;
    tp2 = linspace(0, 2*pi, nPP);
    for p = 1:nPetals
        stagger  = (p-1)/nPetals * 0.28;
        pb       = max(0, min((bloom - stagger)/(1 - max(stagger,1e-9)), 1));
        ang2     = petalAngles(p) + sin(windPhase*0.9 + p*0.7)*0.04*bloom;
        pLen     = 8 + 50*pb;
        pWid     = 3 + 19*pb;
        curv     = 0.60 - 0.52*pb;
        % Rotated ellipse, offset along ang2
        ex2 = pLen*(1-curv)*cos(tp2);
        ey2 = pWid*sin(tp2);
        px2 = ex2*cos(ang2) - ey2*sin(ang2) + cTipX + (pLen*0.5)*cos(ang2);
        py2 = ex2*sin(ang2) + ey2*cos(ang2) + cTipY + (pLen*0.5)*sin(ang2);
        rc  = [min(0.82+0.08*pb,1), 0.05+0.04*pb, 0.07+0.03*pb];
        set(petalS_h(p),'XData',px2+3,'YData',py2+3);
        set(petal_h(p), 'XData',px2,  'YData',py2, ...
            'FaceColor',rc,'FaceAlpha',0.5+0.45*pb);
    end

    % -- Stamens ------------------------------------------
    stamenT2 = max(0,(bloom-0.60)/0.40);
    for s = 1:nStamen
        sa    = (s-1)/nStamen * 2*pi;
        sdist = (6 + mod(s*1.7,5)) * stamenT2;
        sx1   = cTipX + cos(sa)*3;   sy1 = cTipY + sin(sa)*3;
        sx2   = cTipX + cos(sa)*(sdist+4); sy2 = cTipY + sin(sa)*(sdist+4);
        set(stamen_h(s),'XData',[sx1 sx2],'YData',[sy1 sy2], ...
            'Color',[0.86 0.70 0.04 stamenT2*0.75]);
        ar = 1.8 * stamenT2;
        set(anther_h(s),'XData', sx2+ar*cos(th), 'YData', sy2+ar*sin(th));
    end

    % -- Center disc --------------------------------------
    cr = 10 * min(bloom*2,1);
    set(center_h,'XData',cTipX+cr*cos(th),'YData',cTipY+cr*sin(th));

    % -- Clouds -------------------------------------------
    for ci = 1:nClouds
        cloud_x(ci) = cloud_x(ci) - cloud_sp(ci);
        if cloud_x(ci) < -180
            cloud_x(ci) = W + 80 + rand()*120;
            cloud_y(ci) = H*(0.05 + rand()*0.28);
        end
        cloud_y(ci) = cloud_y(ci) + sin(f*0.008 + cloud_seed(ci))*0.08;

        cx2  = cloud_x(ci);
        cy2  = cloud_y(ci);
        cs   = cloud_s(ci);
        alp2 = cloud_alpha(ci) * (0.55 + 0.45*(cloud_layer(ci)>0));

        for bi = 1:nBlobs
            bx2 = cx2 + blobOff(bi,1)*cs;
            by2 = cy2 + blobOff(bi,2)*cs;
            rx2 = blobRx(bi)*cs;
            ry2 = blobRy(bi)*cs;
            [ex2,ey2] = localEllipse(bx2, by2+ry2*0.30, rx2*1.1, ry2*0.45, 22);
            set(cShadow(ci,bi),'XData',ex2,'YData',ey2,'FaceAlpha',0.10*alp2);
            [ex2,ey2] = localEllipse(bx2, by2, rx2, ry2, 22);
            bc = min([0.90+0.06*(1-bi/nBlobs), 0.93+0.04*(1-bi/nBlobs), 1.00],1);
            set(cBody(ci,bi),'XData',ex2,'YData',ey2,'FaceColor',bc,'FaceAlpha',0.80*alp2);
            [ex2,ey2] = localEllipse(bx2-rx2*0.08, by2-ry2*0.15, rx2*0.62, ry2*0.58, 22);
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
function [lx,ly] = localLeaf(baseX, baseY, len, wid, angle)
    n   = 20;
    tv  = linspace(0,1,n);
    % right bezier edge
    rx1 = baseX + wid*0.8*sin(angle);  ry1 = baseY - len*0.4*cos(angle);
    rx2 = baseX + wid*0.5*sin(angle);  ry2 = baseY - len*0.85*cos(angle);
    tipX = baseX;                        tipY = baseY - len;
    lxR = zeros(1,n); lyR = zeros(1,n);
    for ti = 1:n
        tt=tv(ti); mt=1-tt;
        lxR(ti)=mt^3*baseX+3*mt^2*tt*rx1+3*mt*tt^2*rx2+tt^3*tipX;
        lyR(ti)=mt^3*baseY+3*mt^2*tt*ry1+3*mt*tt^2*ry2+tt^3*tipY;
    end
    % left bezier edge (tip back to base)
    lx1 = baseX - wid*0.3*sin(angle);  ly1 = baseY - len*0.7*cos(angle);
    lx2 = baseX - wid*0.1*sin(angle);  ly2 = baseY - len*0.3*cos(angle);
    lxL = zeros(1,n); lyL = zeros(1,n);
    for ti = 1:n
        tt=tv(ti); mt=1-tt;
        lxL(ti)=mt^3*tipX+3*mt^2*tt*lx1+3*mt*tt^2*lx2+tt^3*baseX;
        lyL(ti)=mt^3*tipY+3*mt^2*tt*ly1+3*mt*tt^2*ly2+tt^3*baseY;
    end
    lx = [lxR, lxL];
    ly = [lyR, lyL];
end

function [ex,ey] = localEllipse(cx, cy, rx, ry, n)
    t2 = linspace(0, 2*pi, n);
    ex = cx + rx*cos(t2);
    ey = cy + ry*sin(t2);
end