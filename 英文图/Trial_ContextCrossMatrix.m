% Trial figure (no figure number yet): the English Fig3D cue pre/post decoder
% laid out as a complete 4x4 cross-context matrix. Rows = training context,
% columns = read-out context; the diagonal is the decoder's own 5-fold
% out-of-fold self-test, every off-diagonal tile is the SAME decoder read out on
% a held-out context it was never trained on.
%
% Mimics 英文图/Fig3D_GapDecoderTransfer.m tile-for-tile (same decoder output,
% same shading, same permutation null, same axis limits), extended to sixteen
% tiles of one cohort (AudioLightBaseline, no gap; n = 10 mice in every tile
% because all four contexts share the registered cell set).
%
% Per tile: mean +/- s.e.m. P(post) over mice, grey dashed line = 95th
% percentile of the label-shuffled permutation null (200 shuffles, averaged over
% mice), filled markers = time points where the group mean exceeds that null.
% Line colour encodes the TRAINING context, so a row can be followed across its
% read-outs. The AW -> LW tile is the Fig3D direction with the whole initial
% learning phase as the AudioWater training pool; the AO -> LW tile asks how much
% of that light-water signal the audio calibration trials alone already carry,
% and the AO <-> LO pair (both cue-only, interleaved in the same calibration
% blocks) how much of the cue response is shared between the two cue identities.
%
% Labelling: the CONTEXT NAMES live on the tiles (read-out context in the
% first-row titles, training context in the first-column ylabels, each written
% once because it repeats along that dimension); the Layout-level xlabel/ylabel
% carry the axis quantity plus which dimension runs along that axis (read-out vs
% training), not the names again.
%
% Water is delivered at cue + 1 s, so the post window (0..1 s) ends exactly at
% water delivery in every context.
%
% Input: 信息编码/CueModel_ContextCrossMatrix_Results.mat
%
% Output (SVG):
%   - Trial_ContextCrossMatrix.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

matPath = fullfile(thisDir, '..', '信息编码', 'CueModel_ContextCrossMatrix_Results.mat');
if ~isfile(matPath)
	error('Trial_ContextCrossMatrix:NoResults', ...
		'Missing %s - run CueModel_ContextCrossMatrix.m first.', matPath);
end
S = load(matPath);
tVec = S.tVec;
nT = numel(tVec);
nCtx = numel(S.ctxLabel);
curves = S.curves;
nulls = S.nulls;
accM = S.accM;
mouseNames = S.mouseNames;
% line colour = training context (rows); Light only adds a blue so each of the
% four contexts keeps its own colour (AO purple, LO blue, AW green, LW orange)
ctxBlue = [0.13, 0.44, 0.80];
rowColors = [TransferLearning.NaiveColor; ctxBlue; TransferLearning.ColorB; TransferLearning.TransferColor];

fprintf('=== Trial: 4x4 context cross matrix of the cue pre/post decoder (%s) ===\n', S.dsName);
fprintf('n = %d mice in every tile: %s\n', numel(mouseNames), strjoin(reshape(mouseNames, 1, []), ', '));
fprintf('\n%-14s', 'train \ read');
for c = 1:nCtx
	fprintf('%-31s', S.ctxLabel(c));
end
fprintf('\n');
for r = 1:nCtx
	fprintf('%-14s', char(S.ctxLabel(r)));
	for c = 1:nCtx
		v = squeeze(accM(r, c, :));
		v = v(isfinite(v));
		mn = mean(curves{r, c}, 1, 'omitnan');
		mn95 = mean(nulls{r, c}, 1, 'omitnan');
		nSig = sum(v > 0.5);
		fprintf('%-31s', sprintf('%.3f ± %.3f, %d/%d*, %d/%dt', mean(v), iSem(v), nSig, numel(v), ...
			sum(mn > mn95), nT));
	end
	fprintf('\n');
end
fprintf('(k/m* = mice with accuracy > 0.5; k/mt = time points above the null 95%%)\n');
%% 

% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'Trial: cue decoder 4x4 context cross matrix');
f.Units = 'centimeters';
% 与 3x3 版逐 tile 同尺寸（tile 5.3 x 4.3 cm），行数 x 列数 3 -> 4
f.Position(3:4) = [21.3, 17.3];
f.PaperUnits = 'centimeters';
f.PaperSize = [21.3, 17.3];
f.PaperPositionMode = 'auto';
Layout = tiledlayout(f, nCtx, nCtx, 'TileSpacing', 'tight', 'Padding', 'tight');

Ax = gobjects(nCtx, nCtx);
for r = 1:nCtx
	for c = 1:nCtx
		ax = nexttile(Layout);
		hold(ax, 'on');
		V = curves{r, c};
		mn = mean(V, 1, 'omitnan');
		se = zeros(1, nT);
		for iT = 1:nT
			se(iT) = iSem(V(:, iT));
		end
		n95 = mean(nulls{r, c}, 1, 'omitnan');
		iShadedError(ax, tVec, mn, se, rowColors(r, :), 1.2, 'P(post)');
		plot(ax, tVec, n95, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1, 'DisplayName', 'null 95%');
		% 超过置换 null 95% 的时间点
		sig = mn > n95;
		if any(sig)
			plot(ax, tVec(sig), mn(sig), 'o', 'MarkerSize', 5, 'LineWidth', 1, ...
				'Color', rowColors(r, :), 'MarkerFaceColor', rowColors(r, :), 'HandleVisibility', 'off');
		end
		yline(ax, 0.5, ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
		ylim(ax, [0 1]);
		% 规范：列重复信息（读出上下文）只写在第一行标题；行重复信息（训练上下文）
		% 写在第一列 ylabel；维度名（哪一行是训练、哪一列是测试）写在 Layout 级
		if r == 1
			title(ax, S.ctxLabel(c), 'FontSize', 8, 'FontWeight', 'normal');
		end
		if c == 1
			ylabel(ax, S.ctxLabel(r), 'FontSize', 8);
			ax.YAxis.Visible = 'on';
		else
			ax.YAxis.Visible = 'off';
		end
		if r == nCtx
			ax.XAxis.Visible = 'on';
		else
			ax.XAxis.Visible = 'off';
		end
		legend(ax, 'off');
		ax.Color = 'none';
		box(ax, 'off');
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
		Ax(r, c) = ax;
	end
end
% 规范：Layout 级只写轴量与该轴上的维度名（读出/训练），不重复 tile 上已有的组名
xlabel(Layout, sprintf('Time from cue onset (s)\nRead-out context'));
ylabel(Layout, sprintf('P(post)\nTraining context'));
% 规范：先结算标准样式与 padding，再统一各 tile 轴限，否则 padding 会拆掉统一的轴限
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax(:), @xlim, @ylim);

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'Trial_ContextCrossMatrix.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Trial_ContextCrossMatrixStats', struct('accM', accM, 'curves', curves, ...
	'nulls', nulls, 'tVec', tVec, 'mice', mouseNames, 'ctxLabel', S.ctxLabel));

%% ========== local functions ==========
function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

function iShadedError(ax, x, mn, se, col, lw, dn)
x = x(:)';
mn = mn(:)';
se = se(:)';
ok = isfinite(mn) & isfinite(se);
x = x(ok);
mn = mn(ok);
se = se(ok);
if isempty(x)
	return;
end
fill(ax, [x fliplr(x)], [mn + se fliplr(mn - se)], col, ...
	'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
end
