%% FigS4E_PreVsPostDistance.m
% English FigS4E: correlation between pre-cue and post-cue trajectory distance
% （仿 Nature 2026 s41586-026-11174-3 Extended Data Fig.3d：检验 pre-activity
%   是否为独立测量——若 d(pre) 与 d(post) 高度相关，则线索前距离只是线索后
%   距离的泄漏，不能视为独立的状态变量）
% 两个 panel：Learned / Transfer，pooled 散点（鼠内 z），标 pooled Pearson r 与
% 逐鼠 r 的中位数；逐鼠 Wilcoxon 检验 r>0。
%
% Outputs (SVG): English_FigS4E_PreVsPostDistance.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

phaseName = ["Learned (🔊💧)", "Transfer (💡💧)"];
phaseColor = [TransferLearning.LearnedColor; TransferLearning.TransferColor];
rMouse = nan(numel(M), 2);
stats = struct('r', nan(1,2), 'p', nan(1,2), 'medPerMouse', nan(1,2), 'pW', nan(1,2));
for ip = 1:2
	X = []; Yb = [];
	for i = 1:numel(M)
		if ip == 1
			dPre = M(i).dPreLz; dPost = M(i).dPostLz;
		else
			dPre = M(i).dPreTz; dPost = M(i).dPostTz;
		end
		o = isfinite(dPre) & isfinite(dPost);
		if sum(o) < 12 || std(dPre(o)) == 0 || std(dPost(o)) == 0, continue; end
		rMouse(i, ip) = corr(dPre(o), dPost(o));
		X = [X; dPre(o)]; Yb = [Yb; dPost(o)]; %#ok<AGROW>
	end
	[r, p] = corr(X, Yb);
	rm = rMouse(:, ip); rm = rm(isfinite(rm));
	[pW, ~] = signrank(rm);
	stats.r(ip) = r; stats.p(ip) = p; stats.medPerMouse(ip) = median(rm); stats.pW(ip) = pW;
	fprintf('%s：pooled r=%+.3f p=%.3g；逐鼠中位 r=%+.3f（%d/%d>0，Wilcoxon p=%.3g）\n', ...
		phaseName(ip), r, p, median(rm), sum(rm > 0), numel(rm), pW);
end

f = figure('Color', 'w', 'Name', 'English FigS4E PreVsPostDistance');
f.Units = 'centimeters';
f.Position(3:4) = [15, 8];
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for ip = 1:2
	X = []; Yb = [];
	for i = 1:numel(M)
		if ip == 1, dPre = M(i).dPreLz; dPost = M(i).dPostLz;
		else, dPre = M(i).dPreTz; dPost = M(i).dPostTz; end
		o = isfinite(dPre) & isfinite(dPost);
		if sum(o) < 12 || std(dPre(o)) == 0, continue; end
		X = [X; dPre(o)]; Yb = [Yb; dPost(o)]; %#ok<AGROW>
	end
	ax = nexttile(tl);
	hold(ax, 'on'); box(ax, 'off');
	ax.FontSize = 12; ax.FontName = 'Segoe UI Emoji'; ax.LineWidth = 2;
	scatter(ax, X, Yb, 6, phaseColor(ip,:), 'o', 'filled', 'LineWidth', 0.2, 'MarkerFaceAlpha', 0.3);
	b = polyfit(X, Yb, 1);
	xF = [min(X); max(X)];
	plot(ax, xF, polyval(b, xF), 'k-', 'LineWidth', 2);
	text(ax, 0.04, 0.96, sprintf('r = %+.2f, p = %.2g\nper-mouse median r = %+.2f', ...
		stats.r(ip), stats.p(ip), stats.medPerMouse(ip)), 'Units', 'normalized', ...
		'VerticalAlignment', 'top', 'FontSize', 10);
	xlabel(ax, 'Pre-cue distance (z)');
	ylabel(ax, 'Post-cue distance (z)');
	title(ax, phaseName(ip), 'Color', phaseColor(ip,:), 'FontSize', 12, 'FontWeight', 'bold');
	ax.Toolbar.Visible = 'off';
end
ttl = title(tl, 'Pre-cue vs post-cue distance (independence check)');
ttl.FontSize = 12;

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS4E_PreVsPostDistance.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4E_Stats', stats);
