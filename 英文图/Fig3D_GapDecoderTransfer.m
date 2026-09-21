% English Fig3D: the cue-response ensemble does not transfer after 7 days
%
% Decoder = cue-evoked response decoder (LASSO logistic on the mean population
% activity of the pre window -1..0 s vs the post window 0..1 s; label pre = 0 /
% post = 1), trained on learned audio-water blocks and applied, without
% retraining, to the held-out transfer light-water block. Unlike a hit/miss
% decoder it needs no outcome labels, so every mouse of the 7-day gap cohort is
% trainable (in learned audio-water blocks most trials are hits).
%
% Self-test is computed by 5-fold cross-validation with the test fold held out
% of training: each trial contributes its pre and post window sample and both
% samples always go to the SAME fold, so no sample ever appears in both the
% training and the test set of a fold. The plotted Stage1 curve is the
% out-of-fold probability read at every time point (rows not belonging to the
% fold are left NaN and never plotted).
%
% Tile grid: rows = group (no gap = AudioLightBaseline, 7-day gap = Vacation7),
% columns = Stage1 self-train-test (out-of-fold) | Stage2 transfer light-water.
% Grey dashed line = label-shuffled permutation null (200 shuffles, 95th
% percentile over mice), i.e. the level reached by a decoder trained on
% randomized labels read out the same way.
%
% Input: 信息编码/CueModel_TransferAudioToLight_Results.mat (decoded results,
% verified above; this script only plots and re-tests group differences).
%
% Outputs (SVG):
%   - English_Fig3D_GapDecoderTransfer.svg
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

matPath = fullfile(thisDir, '..', '信息编码', 'CueModel_TransferAudioToLight_Results.mat');
if ~isfile(matPath)
	error('English_Fig3D:NoResults', 'Missing %s - run CueModel_TransferAudioToLight.m first.', matPath);
end
S = load(matPath);
res = S.res;
tVec = S.tVec;
nT = numel(tVec);
groupNames = ["No gap", "7-day gap"];
colorCtrl = TransferLearning.TransferColor;
colorGap = TransferLearning.ColorB;
groupColors = [colorCtrl; colorGap];

% ---------- collect per-mouse curves ----------
pS1 = cell(2, 1);
pS2 = cell(2, 1);
n95S1 = cell(2, 1);
n95S2 = cell(2, 1);
accS1 = cell(2, 1);
accS2 = cell(2, 1);
miceName = cell(2, 1);
for iDS = 1:2
	rows = [];
	rows2 = [];
	null1 = [];
	null2 = [];
	a1 = [];
	a2 = [];
	mn = strings(0, 1);
	for i = 1:numel(res)
		R = res{i};
		if R.DS ~= iDS
			continue;
		end
		rows = [rows; R.pPostS1T(:)'];
		null1 = [null1; R.null95S1(:)'];
		rows2 = [rows2; R.pPostByT(:)'];
		null2 = [null2; R.null95(:)'];
		a1(end + 1) = R.s1Acc; %#ok<AGROW>
		a2(end + 1) = R.s2Acc; %#ok<AGROW>
		mn(end + 1) = string(R.Mouse); %#ok<AGROW>
	end
	pS1{iDS} = rows;
	pS2{iDS} = rows2;
	n95S1{iDS} = null1;
	n95S2{iDS} = null2;
	accS1{iDS} = a1;
	accS2{iDS} = a2;
	miceName{iDS} = mn;
end

fprintf('=== Fig3D cue pre/post decoder (learned audio-water -> transfer light-water) ===\n');
for iDS = 1:2
	n = size(pS1{iDS}, 1);
	fprintf('%s: n = %d mice\n', groupNames(iDS), n);
	fprintf('  Stage1 self-test (5-fold CV, out-of-fold): accuracy %.3f +/- %.3f, peak P(post) %.3f, above null 95%% at %d/%d time points\n', ...
		mean(accS1{iDS}), iSem(accS1{iDS}), max(mean(pS1{iDS}, 1, 'omitnan')), ...
		sum(mean(pS1{iDS}, 1, 'omitnan') > mean(n95S1{iDS}, 1, 'omitnan')), nT);
	fprintf('  Stage2 transfer:                        accuracy %.3f +/- %.3f, peak P(post) %.3f, above null 95%% at %d/%d time points\n', ...
		mean(accS2{iDS}), iSem(accS2{iDS}), max(mean(pS2{iDS}, 1, 'omitnan')), ...
		sum(mean(pS2{iDS}, 1, 'omitnan') > mean(n95S2{iDS}, 1, 'omitnan')), nT);
end
pAcc = ranksum(accS2{1}, accS2{2});
fprintf('Stage2 transfer accuracy between groups: no gap %.3f vs 7-day gap %.3f, rank-sum p = %.4g\n', ...
	mean(accS2{1}), mean(accS2{2}), pAcc);

% P(post) at the last time point (+0.96 s, within the post window)
alP = pS2{1}(:, end);
v7P = pS2{2}(:, end);
rng(777);
NREP = 20000;
vAll = [alP; v7P];
nAl = numel(alP);
obsD = mean(vAll(1:nAl)) - mean(vAll(nAl + 1:end));
cHit = 0;
for r = 1:NREP
	q = randperm(numel(vAll));
	if mean(vAll(q(1:nAl))) - mean(vAll(q(nAl + 1:end))) >= obsD
		cHit = cHit + 1;
	end
end
pPerm = (cHit + 1) / (NREP + 1);
fprintf('P(post) at %.2f s: no gap %.3f +/- %.3f vs 7-day gap %.3f +/- %.3f, one-sided permutation p = %.4f\n', ...
	tVec(end), mean(alP), iSem(alP), mean(v7P), iSem(v7P), pPerm);
%% 

% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'English Fig3D gap decoder transfer');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';
Layout = tiledlayout(f, 2, 2, 'TileSpacing', 'tight', 'Padding', 'tight');

Ax = gobjects(2, 2);
for r = 1:2
	for c = 1:2
		ax = nexttile(Layout);
		hold(ax, 'on');
		if c == 1
			V = pS1{r};
			N = n95S1{r};
		else
			V = pS2{r};
			N = n95S2{r};
		end
		mn = mean(V, 1, 'omitnan');
		se = zeros(1, nT);
		for iT = 1:nT
			se(iT) = iSem(V(:, iT));
		end
		n95 = mean(N, 1, 'omitnan');
		iShadedError(ax, tVec, mn, se, groupColors(r, :), 1.2, 'P(post)');
		plot(ax, tVec, n95, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1, 'DisplayName', 'null 95%');
		% 超过置换 null 95% 的时间点
		sig = mn > n95;
		if any(sig)
			plot(ax, tVec(sig), mn(sig), 'o', 'MarkerSize', 5, 'LineWidth', 1, ...
				'Color', groupColors(r, :), 'MarkerFaceColor', groupColors(r, :), 'HandleVisibility', 'off');
		end
		yline(ax, 0.5, ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
		ylim(ax, [0 1]);
		% 规范：列重复信息（Stage）只写在第一行标题；行重复信息（组）写在第一列 ylabel
		if r == 1
			if c == 1
				title(ax, '🔊', 'FontSize', 8, 'FontWeight', 'normal');
			else
				title(ax, '💡', 'FontSize', 8, 'FontWeight', 'normal');
			end
		end
		if c == 1
			ylabel(ax, groupNames(r), 'FontSize', 8);
		else
			ax.YAxis.Visible = 'off';
		end
		if r == 1
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
% 规范：所有 tile 的 X/Y 轴含义相同，ylabel/xlabel 写在 Layout 级别
ylabel(Layout, 'P(post)');
xlabel(Layout, 'Time from cue onset (s)');
% 规范：先结算标准样式与 padding，再统一各 tile 轴限，否则 padding 会拆掉统一的轴限
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax(:), @xlim, @ylim);

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig3D_GapDecoderTransfer.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3D_GapDecoderStats', struct('accS1', accS1, 'accS2', accS2, 'pAcc', pAcc, ...
	'pPostEnd', struct('ctrl', alP, 'v7', v7P, 'pPerm', pPerm), 'tVec', tVec, 'miceName', miceName));

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
