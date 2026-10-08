% Trial figure (no figure number yet): the English Fig3D cue-response decoder,
% but trained ONLY on AudioOnly calibration trials, and read out on two held-out
% trial sets of the SAME no-gap cohort.
%
% Mimics 英文图/Fig3D_GapDecoderTransfer.m tile-for-tile (same decoder output,
% same shading, same permutation null, same axis limits), with a single row for
% the no-gap cohort (AudioLightBaseline) and three tiles:
%   tile 1 = Stage1, AudioOnly self-test (5-fold trial-aware CV, out-of-fold)
%   tile 2 = Stage2, the AudioOnly-trained decoder read out on the pooled
%            initial-learning AudioWater trials (every Naive / Learned /
%            unannotated AudioWater block as ONE database, Recall excluded;
%            60-180 trials per mouse, spanning the whole learning period)
%   tile 3 = Stage2, the same decoder on the FIRST LightWater block only (its
%            Transfer block, 30 trials) - the very first exposure to the new
%            task, so nothing but the audio cue response can carry information
%            here. Mice whose first LightWater block carries a quality flag are
%            skipped (vtf0353, "2/5层亮度反相"), so this tile has one mouse fewer.
% Grey dashed line = 95th percentile of the label-shuffled permutation null
% (200 shuffles, averaged over mice); filled markers = time points where the
% group mean exceeds that null.
%
% Why: Fig3D asks whether a task-learned cue ensemble transfers to a new task.
% Here the decoder never sees a task trial, so tile 3 asks the cleaner question:
% how much of the Fig3D light-water transfer could be carried by the audio cue
% response alone, before any light-water learning.
%
% Water is delivered at cue + 1 s, so the post window (0..1 s) ends exactly at
% water delivery and contains no water/lick response in any context.
%
% Input: 信息编码/CueModel_TransferAudioOnlyToAudioWater_Results.mat
%
% Output (SVG):
%   - Trial_AudioOnlyCueDecoderTransfer.svg
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

matPath = fullfile(thisDir, '..', '信息编码', 'CueModel_TransferAudioOnlyToAudioWater_Results.mat');
if ~isfile(matPath)
	error('Trial_AudioOnly:NoResults', ...
		'Missing %s - run CueModel_TransferAudioOnlyToAudioWater.m first.', matPath);
end
S = load(matPath);
res = S.res;
tVec = S.tVec;
nT = numel(tVec);

% ---------- collect per-mouse curves (one row per mouse, as in Fig3D) ----------
% tile 1 = AudioOnly self-test, tiles 2-3 = the held-out test sets in .mat order
pS1 = cellfun(@(R) R.pPostS1T, res, 'UniformOutput', false);
n95S1 = cellfun(@(R) R.null95S1, res, 'UniformOutput', false);
accS1 = cellfun(@(R) R.s1Acc, res);
mice = string(cellfun(@(R) R.Mouse, res, 'UniformOutput', false));
V = {vertcat(pS1{:})};
N = {vertcat(n95S1{:})};
A = {accS1};
MN = {mice};
testLabels = S.testLabels;
tileHead = ["Audio-only self", "→ Audio-water", "→ Light-water"];
tileSub = ["(n = %d mice)", "(n = %d mice)", "(1st block, n = %d mice)"];
for k = 1:numel(testLabels)
	[V{k + 1}, N{k + 1}, A{k + 1}, MN{k + 1}] = iCollectTest(res, testLabels(k));
end
nTile = numel(V);
tileTitles = strings(1, nTile);
for c = 1:nTile
	tileTitles(c) = string(sprintf(tileHead(c) + newline + tileSub(c), size(V{c}, 1)));
end
groupColor = TransferLearning.TransferColor;   % Fig3D no-gap row colour

fprintf('=== Trial: cue pre/post decoder trained on AudioOnly only (no-gap cohort) ===\n');
fprintf('%d decodable mice: %s\n', numel(res), strjoin(reshape(mice, 1, []), ', '));
for k = 1:nTile
	fprintf('tile %d (%s): n = %d mice, accuracy %.3f +/- %.3f, peak P(post) %.3f, above null 95%% at %d/%d time points; sign test > 0.5: %d/%d p = %.4f\n', ...
		k, strrep(char(tileTitles(k)), newline, ' '), size(V{k}, 1), mean(A{k}), iSem(A{k}), ...
		max(mean(V{k}, 1, 'omitnan')), sum(mean(V{k}, 1, 'omitnan') > mean(N{k}, 1, 'omitnan')), nT, ...
		sum(A{k} > 0.5), numel(A{k}), 1 - binocdf(sum(A{k} > 0.5) - 1, numel(A{k}), 0.5));
	if size(V{k}, 1) < numel(res)
		fprintf('  mice: %s\n', strjoin(reshape(MN{k}, 1, []), ', '));
	end
end
% paired comparisons on the mice that carry both read-outs
pSR = nan(nTile, nTile);
for k = 2:nTile
	pSR(1, k) = iPaired(A{1}, MN{1}, A{k}, MN{k}, 'AudioOnly self', ...
		strrep(char(tileTitles(k)), newline, ' '));
	pSR(k, 1) = pSR(1, k);
end
if nTile > 2
	pSR(2, 3) = iPaired(A{2}, MN{2}, A{3}, MN{3}, ...
		strrep(char(tileTitles(2)), newline, ' '), strrep(char(tileTitles(3)), newline, ' '));
	pSR(3, 2) = pSR(2, 3);
end
%% 

% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'Trial: audio-only decoder read out on audio-water and light-water');
f.Units = 'centimeters';
f.Position(3:4) = [18, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [18, 8];
f.PaperPositionMode = 'auto';
Layout = tiledlayout(f, 1, nTile, 'TileSpacing', 'tight', 'Padding', 'tight');

Ax = gobjects(1, nTile);
for c = 1:nTile
	ax = nexttile(Layout);
	hold(ax, 'on');
	mn = mean(V{c}, 1, 'omitnan');
	se = zeros(1, nT);
	for iT = 1:nT
		se(iT) = iSem(V{c}(:, iT));
	end
	n95 = mean(N{c}, 1, 'omitnan');
	iShadedError(ax, tVec, mn, se, groupColor, 1.2, 'P(post)');
	plot(ax, tVec, n95, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1, 'DisplayName', 'null 95%');
	% 超过置换 null 95% 的时间点
	sig = mn > n95;
	if any(sig)
		plot(ax, tVec(sig), mn(sig), 'o', 'MarkerSize', 5, 'LineWidth', 1, ...
			'Color', groupColor, 'MarkerFaceColor', groupColor, 'HandleVisibility', 'off');
	end
	yline(ax, 0.5, ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
	xline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
	ylim(ax, [0 1]);
	title(ax, tileTitles(c), 'FontSize', 8, 'FontWeight', 'normal');
	if c == 1
		ylabel(ax, 'No gap', 'FontSize', 8);
	else
		ax.YAxis.Visible = 'off';
	end
	legend(ax, 'off');
	ax.Color = 'none';
	box(ax, 'off');
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	Ax(c) = ax;
end
% 规范：所有 tile 的 X/Y 轴含义相同，ylabel/xlabel 写在 Layout 级别
ylabel(Layout, 'P(post)');
xlabel(Layout, 'Time from cue onset (s)');
% 规范：先结算标准样式与 padding，再统一各 tile 轴限，否则 padding 会拆掉统一的轴限
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax(:), @xlim, @ylim);

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'Trial_AudioOnlyCueDecoderTransfer.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Trial_AudioOnlyDecoderStats', struct('acc', A, 'mice', MN, 'curves', V, ...
	'tVec', tVec, 'pSignRank', pSR, 'tileTitles', tileTitles));

%% ========== local functions ==========
function [V, N, A, M] = iCollectTest(res, label)
% Per-mouse Stage2 curves of one test set: rows = mice that have that test set
% (a mouse whose block was skipped by a quality flag drops out of the tile).
	pv = {};
	pn = {};
	pa = [];
	pm = strings(0, 1);
	for i = 1:numel(res)
		R = res{i};
		j = find(string({R.Tests.name}) == label, 1);
		if isempty(j)
			continue;
		end
		pv{end + 1} = R.Tests(j).pPostByT(:)'; %#ok<AGROW>
		pn{end + 1} = R.Tests(j).null95(:)'; %#ok<AGROW>
		pa(end + 1) = R.Tests(j).acc; %#ok<AGROW>
		pm(end + 1) = string(R.Mouse); %#ok<AGROW>
	end
	if isempty(pv)
		V = zeros(0, 1);
		N = zeros(0, 1);
	else
		V = vertcat(pv{:});
		N = vertcat(pn{:});
	end
	A = pa;
	M = pm;
end

function p = iPaired(a, ma, b, mb, nameA, nameB)
% Two-sided signed-rank test of two accuracy vectors on their shared mice
% (signrank is order-independent, so one p value covers both directions).
	[~, ia, ib] = intersect(ma, mb);
	if numel(ia) < 2
		fprintf('%s vs %s: fewer than 2 shared mice (%d), test skipped\n', nameA, nameB, numel(ia));
		p = NaN;
		return;
	end
	[p, h] = signrank(a(ia), b(ib));
	fprintf('%s vs %s (paired, n = %d mice): %.3f vs %.3f, signed-rank p = %.4f\n', ...
		nameA, nameB, numel(ia), mean(a(ia)), mean(b(ib)), p);
	if h == 1
		fprintf('  -> the two read-outs differ.\n');
	else
		fprintf('  -> no difference between the two read-outs.\n');
	end
end

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
