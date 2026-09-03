%% Cfg2Figure_Simple.m
% 简版 2x2 图：行1 = Cue cfg2 (AudioOnly+LightOnly)，行2 = Choice cfg2 (AudioWater)
% 列 = [Stage1 prob-tendency, Stage2 prob-tendency]（去掉 MI 列）
%   Cue 行 Stage1 只保留 audio only / light only；
%   Choice 行 Stage1 只保留 audio hit / audio miss；
%   Stage2 保留 light hit / light miss。
% 数据来自 CompareCueTrainData.m / CompareChoiceTrainData.m 导出的 .mat
prjRoot = fileparts(fileparts(mfilename('fullpath')));
figDir = fullfile(prjRoot, '信息编码', '_figcheck');

S = load(fullfile(figDir, 'Cue_cfg2data.mat'));    % miCV, pSt1(4), pSt2(2), tVec
T = load(fullfile(figDir, 'Choice_cfg2data.mat')); % miCV, pCal(2), pSt1(2), pSt2(2), tVec
tVec = S.tVec;
cfg = 2;   % cfg2

f = figure('Name','Cfg2 simple: Cue vs Choice','Color','w','Position',[60 60 900 640]);
axGrid = gobjects(2,2);
for r = 1:2
    for c = 1:2   % c=1 Stage1, c=2 Stage2
        ax = subplot(2,2,(r-1)*2+c); hold(ax,'on');
        axGrid(r,c) = ax;
        if c == 1   % Stage1
            if r == 1   % Cue: audio only / light only
                P = S.pSt1(:,cfg,1:2,:);
                stN = {'audio only','light only'};
                stC = {[0.30 0.60 0.20], [0.70 0.30 0.70]};
                for s = 1:2
                    v = squeeze(P(:,1,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
                end
                iSigStars(ax, tVec, squeeze(P(:,1,1,:)), squeeze(P(:,1,2,:)), 0.02, stC{1});
                ylabel(ax,'P(audio) tendency (0=light,1=audio)');
            else   % Choice: audio hit / audio miss
                P = T.pSt1(:,cfg,1:2,:);
                stN = {'audio hit','audio miss'};
                stC = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
                for s = 1:2
                    v = squeeze(P(:,1,s,:));
                    if all(isnan(v(:))); continue; end
                    mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                    iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
                end
                iSigStars(ax, tVec, squeeze(P(:,1,1,:)), squeeze(P(:,1,2,:)), 0.02, stC{1});
                ylabel(ax,'P tendency (0=miss,1=hit)');
            end
            set(ax,'YLim',[0 1]);
        else   % Stage2: light hit / light miss
            if r==1; P = S.pSt2(:,cfg,:,:); else; P = T.pSt2(:,cfg,:,:); end
            stN = {'light hit','light miss'};
            stC = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
            for s = 1:2
                v = squeeze(P(:,1,s,:));
                if all(isnan(v(:))); continue; end
                mn = mean(v,1,'omitnan'); se = std(v,0,1,'omitnan')/sqrt(sum(~isnan(v(:,1))));
                iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
            end
            iSigStars(ax, tVec, squeeze(P(:,1,1,:)), squeeze(P(:,1,2,:)), 0.02, stC{1});
            if r==1; ylabel(ax,'P(audio) tendency (0=light,1=audio)'); else; ylabel(ax,'P tendency (0=miss,1=hit)'); end
            set(ax,'YLim',[0 1]);
        end
        yline(ax,0.5,':','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        xline(ax,0,'--','Color',[0.5 0.5 0.5],'LineWidth',0.6,'HandleVisibility','off');
        if r==2; xlabel(ax,'Time from stimulus (s)'); end
        legend(ax,'Location','northwest','Box','off','FontSize',8);
        box(ax,'off'); ax.FontSize = 7;
    end
end
% 列标题
text(axGrid(1,1), 0.5, 1.16, 'Stage1 prob-tendency', 'Units','normalized','HorizontalAlignment','center', ...
    'FontWeight','bold','FontSize',10);
text(axGrid(1,2), 0.5, 1.16, 'Stage2 prob-tendency', 'Units','normalized','HorizontalAlignment','center', ...
    'FontWeight','bold','FontSize',10);
% 行标题
text(axGrid(1,1), -0.3, 0.5, 'Cue (AudioOnly+LightOnly)', 'Units','normalized','Rotation',90, ...
    'HorizontalAlignment','center','FontWeight','bold','FontSize',9);
text(axGrid(2,1), -0.3, 0.5, 'Choice (AudioWater)', 'Units','normalized','Rotation',90, ...
    'HorizontalAlignment','center','FontWeight','bold','FontSize',9);

if ~exist(figDir,'dir'); mkdir(figDir); end
outfile = fullfile(figDir, 'Cfg2_Compare_CueChoice_simple.png');
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
