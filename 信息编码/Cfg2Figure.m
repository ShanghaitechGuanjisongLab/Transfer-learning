%% Cfg2Figure.m
% 用 MATLAB 直接绘制 2x3 图：行1 = Cue cfg2 (AO+LO)，行2 = Choice cfg2 (AudioWater)
% 列 = [MI (train CV), Stage1 prob-tendency, Stage2 prob-tendency]
% 数据来自 CompareCueTrainData.m / CompareChoiceTrainData.m 导出的 .mat（保证与原图一致）
prjRoot = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(prjRoot, '信息编码', '_figcheck');

% ---------- 加载数据 ----------
S = load(fullfile(figDir, 'Cue_cfg2data.mat'));    % miCV, pSt1(4), pSt2(2), tVec
T = load(fullfile(figDir, 'Choice_cfg2data.mat')); % miCV, pCal(2), pSt1(2), pSt2(2), tVec
tVec = S.tVec;
cfg = 2;   % cfg2

stN1 = {'audio only','light only','audio hit','audio miss'};
stN2 = {'light hit','light miss'};
stC1 = {[0.30 0.60 0.20], [0.70 0.30 0.70], [0.85 0.33 0.10], [0.10 0.45 0.70]};
stC2 = {[0.85 0.33 0.10], [0.10 0.45 0.70]};

f = figure('Name','Cfg2: Cue(AO+LO) vs Choice(AudioWater)','Color','w','Position',[60 60 1100 640]);
axGrid = gobjects(2,3);
rowTag = {'Cue','Choice'};

for r = 1:2
    for c = 1:3
        ax = subplot(2,3,(r-1)*3+c); hold(ax,'on');
        axGrid(r,c) = ax;
        if c == 1   % MI
            if r==1; v = S.miCV(:,cfg,:); else; v = T.miCV(:,cfg,:); end
            mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
            iShadedError(ax, tVec, mn, se, [0 0 0], 1.6, 'glm');
            ylabel(ax,'MI (bits)'); set(ax,'YLim',[0 0.5]);
        elseif c == 2   % Stage1
            if r == 1
                P = S.pSt1(:,cfg,:,:);
                for s = 1:4
                    v = squeeze(P(:,1,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC1{s}, 1.4, stN1{s});
                end
                iSigStars(ax, tVec, squeeze(P(:,1,1,:)), squeeze(P(:,1,2,:)), 0.02, stC1{1});
                iSigStars(ax, tVec, squeeze(P(:,1,3,:)), squeeze(P(:,1,4,:)), 0.02, stC1{3});
            else
                Pc = T.pCal(:,cfg,:,:);
                Ps = T.pSt1(:,cfg,:,:);
                for s = 1:2
                    v = squeeze(Pc(:,1,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC1{s}, 1.4, stN1{s});
                end
                for s = 1:2
                    v = squeeze(Ps(:,1,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC1{s+2}, 1.4, stN1{s+2});
                end
                iSigStars(ax, tVec, squeeze(Pc(:,1,1,:)), squeeze(Pc(:,1,2,:)), 0.02, stC1{1});
                iSigStars(ax, tVec, squeeze(Ps(:,1,1,:)), squeeze(Ps(:,1,2,:)), 0.02, stC1{3});
            end
            if r==1; ylabel(ax,'P(audio) tendency (0=light,1=audio)'); else; ylabel(ax,'P tendency (0=miss,1=hit)'); end
            set(ax,'YLim',[0 1]);
        else   % Stage2
            if r==1; P = S.pSt2(:,cfg,:,:); else; P = T.pSt2(:,cfg,:,:); end
            for s = 1:2
                v = squeeze(P(:,1,s,:));
                if all(isnan(v(:))); continue; end
                mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                iShadedError(ax, tVec, mn, se, stC2{s}, 1.4, stN2{s});
            end
            iSigStars(ax, tVec, squeeze(P(:,1,1,:)), squeeze(P(:,1,2,:)), 0.02, stC2{1});
            if r==1; ylabel(ax,'P(audio) tendency (0=light,1=audio)'); else; ylabel(ax,'P tendency (0=miss,1=hit)'); end
            set(ax,'YLim',[0 1]);
        end
        if c > 1; yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off'); end
        xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        if r==2; xlabel(ax,'Time from stimulus (s)'); end
        if c>1
            legend(ax,'Location','northwest','Box','off','FontSize',8);
        end
        box(ax,'off'); ax.FontSize = 7;
    end
end
% 列标题
subCol = {'MI (train CV)','Stage1 prob-tendency','Stage2 prob-tendency'};
for c = 1:3
    text(axGrid(1,c), 0.5, 1.16, subCol{c}, 'Units','normalized','HorizontalAlignment','center', ...
        'FontWeight','bold','FontSize',10);
end
% 行标签
text(axGrid(1,1), -0.3, 0.5, 'Cue (AudioOnly+LightOnly)', 'Units','normalized','Rotation',90, ...
    'HorizontalAlignment','center','FontWeight','bold','FontSize',9);
text(axGrid(2,1), -0.3, 0.5, 'Choice (AudioWater)', 'Units','normalized','Rotation',90, ...
    'HorizontalAlignment','center','FontWeight','bold','FontSize',9);

if ~exist(figDir,'dir'); mkdir(figDir); end
outfile = fullfile(figDir, 'Cfg2_Compare_CueChoice.png');
exportgraphics(f, outfile, 'Resolution', 200);
fprintf('Saved: %s\n', outfile);

% ==================== Local Functions ====================
function iSigStars(ax, tVec, v1, v2, yoff, col)
hold(ax,'on');
m1 = mean(v1,1,'omitnan'); m2 = mean(v2,1,'omitnan');
for iT = 1:numel(tVec)
    a = v1(:,iT); b = v2(:,iT);
    ok = ~isnan(a) & ~isnan(b);
    if sum(ok) < 4; continue; end
    [~, pp] = ttest(a(ok), b(ok));
    if pp < 0.05
        y = max(m1(iT), m2(iT)) + yoff;
        text(ax, tVec(iT), y, '*', 'Color', col, 'FontSize', 9, ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','HandleVisibility','off');
    end
end
end

function iShadedError(ax, x, mn, se, col, lw, dn)
x = x(:)'; mn = mn(:)'; se = se(:)';
ok = ~isnan(mn) & ~isnan(se);
x = x(ok); mn = mn(ok); se = se(ok);
if isempty(x); return; end
hold(ax,'on');
fill(ax, [x fliplr(x)], [mn+se fliplr(mn-se)], col, ...
    'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
end
