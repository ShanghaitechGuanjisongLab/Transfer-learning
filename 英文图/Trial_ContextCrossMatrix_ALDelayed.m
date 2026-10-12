% Trial figure (ALDelayed): cue pre/post decoder context cross matrix (2x2),
% mimicking the style of Trial_ContextCrossMatrix.m.
%
% Data source:
% - 信息编码/CueModel_ContextCrossMatrix_ALDelayed_Results.mat
%   (if missing, this script auto-runs 信息编码/CueModel_ContextCrossMatrix_ALDelayed.m)
%
% Time range:
% - Fixed display window: [-1.5, 1.5] s
%
% Output (SVG):
% - Trial_ContextCrossMatrix_ALDelayed.svg
%
% Execution:
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

matPath = fullfile(thisDir, '..', '信息编码', 'CueModel_ContextCrossMatrix_ALDelayed_Results.mat');
genScript = fullfile(thisDir, '..', '信息编码', 'CueModel_ContextCrossMatrix_ALDelayed.m');
if ~isfile(matPath)
	fprintf('Results cache missing (%s)\nGenerating it now via %s ...\n', matPath, genScript);
	iRunGeneratorScript(genScript);
end
if ~isfile(matPath)
	error('Trial_ContextCrossMatrix_ALDelayed:NoResults', ...
		'%s still missing after running %s.', matPath, genScript);
end
S = load(matPath);
tVec = S.tVec;
nT = numel(tVec);
nCtx = numel(S.ctxLabel);
curves = S.curves;
nulls = S.nulls;
accM = S.accM;
mouseNames = S.mouseNames;
rowColors = [TransferLearning.ColorB; TransferLearning.TransferColor];

fprintf('=== Trial: ALDelayed 2x2 context cross matrix (%s) ===\n', S.dsName);
fprintf('n = %d mice in every tile: %s\n', numel(mouseNames), strjoin(reshape(mouseNames, 1, []), ', '));
fprintf('\n%-18s', 'train \ read');
for c = 1:nCtx
	fprintf('%-44s', S.ctxLabel(c));
end
fprintf('\n');
for r = 1:nCtx
	fprintf('%-18s', char(S.ctxLabel(r)));
	for c = 1:nCtx
		v = squeeze(accM(r, c, :));
		v = v(isfinite(v));
		mn = mean(curves{r, c}, 1, 'omitnan');
		mn95 = mean(nulls{r, c}, 1, 'omitnan');
		nSig = sum(v > 0.5);
		pR = iRegionP(curves{r, c}, nulls{r, c}, mn > mn95);
		if isfinite(pR)
			pStr = sprintf('p=%.3g', pR);
		else
			pStr = 'p=n.a.';
		end
		fprintf('%-44s', sprintf('%.3f ± %.3f, %d/%d*, %d/%dt, %s', mean(v), iSem(v), nSig, numel(v), ...
			sum(mn > mn95), nT, pStr));
	end
	fprintf('\n');
end

%% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'Trial: ALDelayed cue decoder 2x2 context matrix');
f.Units = 'centimeters';
f.Position(3:4) = [8, 7];
f.PaperUnits = 'centimeters';
f.PaperSize = [8, 7];
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
		yline(ax, 0.5, ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
		ylim(ax, [0 1.15]);
		xlim(ax, [-1.5 1.5]);
		sig = mn > n95;
		if any(sig)
			iSigBar(ax, tVec, sig, mn, iRegionP(V, nulls{r, c}, sig));
		end
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
xlabel(Layout, sprintf('Time from cue onset (s)\nRead-out context'));
ylabel(Layout, sprintf('P(post)\nTraining context'));
TransferLearning.ApplyStandardExportStyle(f, 2);
MATLAB.Graphics.UnifyAxesLims(Ax(:), @xlim, @ylim);
for iA = 1:numel(Ax)
	xlim(Ax(iA), [-1.5 1.5]);
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'Trial_ContextCrossMatrix_ALDelayed.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Trial_ContextCrossMatrix_ALDelayed_Stats', struct('accM', accM, 'curves', curves, ...
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

function p = iRegionP(V, N, sig)
dd = mean(V(:, sig), 2, 'omitnan') - mean(N(:, sig), 2, 'omitnan');
dd = dd(isfinite(dd));
if isempty(dd) || all(dd == 0)
	p = NaN;
	return;
end
p = signrank(dd);
end

function iSigBar(ax, tVec, sig, mn, p)
tVec = tVec(:)';
sig = logical(sig(:)');
yrange = diff(ylim(ax));
dt = median(diff(tVec));
yTop = max(mn(sig), [], 'omitnan');
yBar = yTop + 0.05 * yrange;
dEdge = diff([0, sig, 0]);
runStart = find(dEdge == 1);
runEnd = find(dEdge == -1) - 1;
for k = 1:numel(runStart)
	x1 = tVec(runStart(k)) - dt / 2;
	x2 = tVec(runEnd(k)) + dt / 2;
	line(ax, [x1, x2], [yBar, yBar], 'Color', 'k', 'LineWidth', 1, 'HandleVisibility', 'off');
end
if ~isfinite(p)
	starStr = 'n.s.';
elseif p < 0.001
	starStr = '＊＊＊＊';
else
	starStr = TransferLearning.Style.iFormatPText(p);
end
xMid = (tVec(find(sig, 1, 'first')) + tVec(find(sig, 1, 'last'))) / 2;
text(ax, xMid, yBar + 0.02 * yrange, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
	'FontSize', 7, 'HandleVisibility', 'off');
end

function iRunGeneratorScript(genScript)
if ~isfile(genScript)
	error('Trial_ContextCrossMatrix_ALDelayed:NoGenerator', 'Missing generator script: %s', genScript);
end
iEnsureParallelPool;
oldDir = pwd;
cleaner = onCleanup(@() cd(oldDir)); %#ok<NASGU>
run(genScript);
end

function iEnsureParallelPool
if ~isempty(gcp('nocreate'))
	return;
end
for nW = unique([min(24, feature('numcores')), 16, 8], 'stable')
	try
		parpool('Processes', nW);
		return;
	catch
	end
end
warning('Trial_ContextCrossMatrix_ALDelayed:NoPool', ...
	'Parallel pool unavailable; the generator will run serially (much slower).');
ps = parallel.Settings;
ps.Pool.AutoCreate = false;
end
