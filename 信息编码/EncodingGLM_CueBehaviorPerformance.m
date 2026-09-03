%% EncodingGLM_CueBehaviorPerformance.m
% 全程（声转光迁移）逐细胞逐时点三元编码 GLM
%
% 每个 (cell, time) 拟合：
%   r_i(t) = b0 + b_cue*x_cue + b_beh*x_beh + b_perf*x_perf
%   x_cue ∈ {0=LightWater, 1=AudioWater}
%   x_beh ∈ {0=miss, 1=hit}
%   x_perf ∈ [0,1]（block 级 Performance，z 标准化后入模型）
% 输出三张 beta 热图（细胞 × 时点），按 block 置换检验标显著性。
% 多元 GLM 自动 partialling out 三变量间共享方差（实测 VIF<2）。
%
% 时间窗 [-1,1]s：cue 200ms + 延时 800ms，给水在 t=1.0s 起点，窗口干净。

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile, 'file'); matlab.project.loadProject(prjFile); end
end
rng(42);

%% 1. Load dataset & time axis
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);
tMask = (xs >= -1) & (xs <= 1);
tIdx = find(tMask);
nT = numel(tIdx);
fprintf('Time window [%.2f, %.2f]s, %d pts\n', xs(tIdx(1)), xs(tIdx(end)), nT);

% block-level Performance
Blocks = DS.Blocks(:, ["BlockUID","Performance"]);

%% 2. List mice
TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID","BlockUID"]);
TQ.Mouse = string(TQ.Mouse);
TQ.Stimulus = string(TQ.Stimulus);
TQ = sortrows(TQ, ["Mouse","DateTime"]);
mice = unique(TQ.Mouse);
nMice = numel(mice);
fprintf('=== 3-way encoding GLM, %d mice ===\n\n', nMice);

%% 3. Per-mouse GLM (parfor)
nShuffle = 200;
res = cell(nMice, 1);

parfor iM = 1:nMice
	m = mice(iM);
	R = TransferLearning.EncodingGLMRunMouse(DS, m, Blocks, nTime, tIdx, nShuffle);
	res{iM} = R;
	if isempty(R)
		fprintf('  %s: SKIP\n', m);
	else
		fprintf('  %s: cells=%d trials=%d\n', m, R.NCells, R.NTrials);
	end
end

validIdx = find(~cellfun(@isempty, res));
nValid = numel(validIdx);
fprintf('\nValid mice: %d/%d\n', nValid, nMice);
if nValid == 0
	fprintf('No valid data.\n');
	return;
end

%% 4. Pool across mice (cells concatenated; all mice use same time axis)
betaCue  = vertcat(res{validIdx(1)}.BetaCue);
betaBeh  = vertcat(res{validIdx(1)}.BetaBeh);
betaPerf = vertcat(res{validIdx(1)}.BetaPerf);
sigCue   = vertcat(res{validIdx(1)}.SigCue);
sigBeh   = vertcat(res{validIdx(1)}.SigBeh);
sigPerf  = vertcat(res{validIdx(1)}.SigPerf);
cellMouse = repmat(string(res{validIdx(1)}.Mouse), res{validIdx(1)}.NCells, 1);
for i = 2:nValid
	r = res{validIdx(i)};
	betaCue  = [betaCue;  r.BetaCue];
	betaBeh  = [betaBeh;  r.BetaBeh];
	betaPerf = [betaPerf; r.BetaPerf];
	sigCue   = [sigCue;   r.SigCue];
	sigBeh   = [sigBeh;   r.SigBeh];
	sigPerf  = [sigPerf;  r.SigPerf];
	cellMouse = [cellMouse; repmat(string(r.Mouse), r.NCells, 1)];
end
nCellAll = size(betaCue, 1);
fprintf('Pooled cells: %d\n', nCellAll);

tAxis = xs(tIdx);
postMask = tAxis >= 0 & tAxis <= 1;   % 显著性/排序只看刺激后 0~1s

% 筛选：0~1s 内至少一个时点显著的细胞；排序：0~1s 内 |beta| 峰值时刻
sigWinCue  = any(sigCue(:, postMask), 2);
sigWinBeh  = any(sigBeh(:, postMask), 2);
sigWinPerf = any(sigPerf(:, postMask), 2);

ordCue  = iOrderByPeak(betaCue,  sigWinCue,  postMask);
ordBeh  = iOrderByPeak(betaBeh,  sigWinBeh,  postMask);
ordPerf = iOrderByPeak(betaPerf, sigWinPerf, postMask);

%% 5. Figures: 3 heatmaps with shared symmetric color scale (standardized beta)
clim = max([max(abs(betaCue(:)),[],'omitnan'), ...
            max(abs(betaBeh(:)),[],'omitnan'), ...
            max(abs(betaPerf(:)),[],'omitnan')]);
if ~isfinite(clim) || clim == 0; clim = 1; end

fH = figure('Name','3-way encoding beta','Color','w','Position',[40 40 1080 340]);
tl = tiledlayout(fH, 1, 3, 'TileSpacing','compact','Padding','compact');
cmap = TransferLearning.RedBlueColormap();

ax1 = nexttile(tl, 1);
TransferLearning.EncodingGLMPlotHeat(ax1, tAxis, betaCue(ordCue,:), false(size(betaCue(ordCue,:))), clim, cmap);
title(ax1, sprintf('Cue (Audio>Light), n=%d', nnz(sigWinCue)), 'FontSize', 8, 'FontWeight','normal');
ylabel(ax1, 'Cell (sig in 0-1s)');

ax2 = nexttile(tl, 2);
TransferLearning.EncodingGLMPlotHeat(ax2, tAxis, betaBeh(ordBeh,:), false(size(betaBeh(ordBeh,:))), clim, cmap);
title(ax2, sprintf('Behavior (Hit>Miss), n=%d', nnz(sigWinBeh)), 'FontSize', 8, 'FontWeight','normal');
xlabel(ax2, 'Time from cue (s)');

ax3 = nexttile(tl, 3);
TransferLearning.EncodingGLMPlotHeat(ax3, tAxis, betaPerf(ordPerf,:), false(size(betaPerf(ordPerf,:))), clim, cmap);
title(ax3, sprintf('Block performance, n=%d', nnz(sigWinPerf)), 'FontSize', 8, 'FontWeight','normal');
cb = colorbar(ax3); cb.Label.String = '\beta (s.d. units)';

%% 6. Summary: fraction of cells significant within 0-1s post-cue
fracCue  = nnz(sigWinCue)  / nCellAll;
fracBeh  = nnz(sigWinBeh)  / nCellAll;
fracPerf = nnz(sigWinPerf) / nCellAll;
fprintf('Cells sig in 0-1s: cue=%.1f%% beh=%.1f%% perf=%.1f%%\n', ...
	fracCue*100, fracBeh*100, fracPerf*100);

% population mean |beta| time course + significant-cell fraction
fM = figure('Name','Population encoding strength','Color','w','Position',[80 80 400 560]);
tlM = tiledlayout(fM, 2, 1, 'TileSpacing','compact','Padding','compact');

varData = {betaCue, sigCue, [0.85 0.33 0.10], 'Cue';
           betaBeh, sigBeh, [0 0.45 0.74], 'Behavior';
           betaPerf, sigPerf, [0.47 0.67 0.19], 'Performance'};

axM1 = nexttile(tlM, 1); hold(axM1,'on');
tx = tAxis(:)';   % 强制行向量
for v = 1:3
	B = varData{v,1}; c = varData{v,3}; nm = varData{v,4};
	mn = mean(abs(B), 1, 'omitnan'); mn = mn(:)';
	se = std(abs(B), 0, 1, 'omitnan') ./ sqrt(sum(isfinite(B),1)); se = se(:)';
	se(~isfinite(se)) = 0;
	fill(axM1, [tx fliplr(tx)], [mn-se fliplr(mn+se)], c, 'EdgeColor','none', 'FaceAlpha', 0.18, 'HandleVisibility','off');
	plot(axM1, tx, mn, '-', 'Color', c, 'LineWidth', 1.4, 'DisplayName', nm);
end
hold(axM1,'off');
xl1 = xline(axM1, 0, ':', 'Color',[0.3 0.3 0.3]); xl1.HandleVisibility = 'off';
ylabel(axM1, 'mean |\beta| \pm SEM');
legend(axM1,'Box','off','FontSize',7,'Location','northwest');
title(axM1, sprintf('All cells, n=%d', nCellAll), 'FontSize',8,'FontWeight','normal');
box(axM1,'off'); axM1.FontSize = 7;

axM2 = nexttile(tlM, 2); hold(axM2,'on');
for v = 1:3
	S = varData{v,2}; c = varData{v,3}; nm = varData{v,4};
	frac = mean(S, 1, 'omitnan'); frac = frac(:)';
	plot(axM2, tx, frac*100, '-', 'Color', c, 'LineWidth', 1.4, 'DisplayName', nm);
end
hold(axM2,'off');
xl2 = xline(axM2, 0, ':', 'Color',[0.3 0.3 0.3]); xl2.HandleVisibility = 'off';
xlabel(axM2, 'Time from cue (s)'); ylabel(axM2, 'Significant cells (%)');
title(axM2, 'Fraction with p<0.05 per timepoint', 'FontSize',8,'FontWeight','normal');
box(axM2,'off'); axM2.FontSize = 7;

%% 7. Export
TransferLearning.ExportStandardFigure(fH, 2, 'EncodingGLM_3way_BetaHeatmap.svg');
TransferLearning.ExportStandardFigure(fM, 2, 'EncodingGLM_PopulationStrength.svg');
fprintf('Done.\n');

function ord = iOrderByPeak(B, keep, postMask)
% 在 keep 的细胞内，按 postMask 窗口内 |beta| 峰值时刻升序排列
	idx = find(keep);
	Bsel = B(idx, postMask);
	[~, pk] = max(abs(Bsel), [], 2, 'omitnan');
	[~, srt] = sort(pk);
	ord = idx(srt);
end

