%% FigS4E_PreVsPostDistance.m
% English FigS4E: correlation between pre-cue and post-cue trajectory distance。
% 样式对应 Fig.4c / ED Fig.9b：Transfer 在上、Learned 在下，散点+拟合线。
% pre=[-0.5,0] s，post=[0,1] s（文献口径）；两阶段 pooled 散点使用鼠内 z。
% pooled Pearson 与逐鼠统计只在命令行报告，不在图内添加文献没有的统计文本。
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

phaseName = ["Learned", "Transfer"];
phaseColor = [0.55, 0.55, 0.55; 0.66, 0.32, 0.50];
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
f.Position(3:4) = [5, 8];
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'loose', 'Padding', 'compact');
for ip = 1:2
	X = []; Yb = [];
	for i = 1:numel(M)
		if ip == 1, dPre = M(i).dPreLz; dPost = M(i).dPostLz;
		else, dPre = M(i).dPreTz; dPost = M(i).dPostTz; end
		o = isfinite(dPre) & isfinite(dPost);
		if sum(o) < 12 || std(dPre(o)) == 0, continue; end
		X = [X; dPre(o)]; Yb = [Yb; dPost(o)]; %#ok<AGROW>
	end
	ax = nexttile(tl, 3-ip);  % 文献 Fig.4c：Transfer/opto 在上，Learned/voluntary 在下
	hold(ax, 'on');
	c = phaseColor(ip, :);
	scatter(ax, X, Yb, 6, 0.65*c+0.35, 'o', 'filled', 'MarkerEdgeColor', 'none');
	b = polyfit(X, Yb, 1);
	xF = linspace(min(X), max(X), 100);
	plot(ax, xF, polyval(b, xF), '-', 'Color', c, 'LineWidth', 0.75);
	text(ax, 0.96, 0.06, phaseName(ip), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
		'VerticalAlignment', 'bottom', 'FontName', 'Arial', 'FontSize', 6, 'Color', c);
	xlabel(ax, {'Pre-cue population activity', 'distance (z)'});
	ylabel(ax, {'Post-cue population activity', 'distance (z)'});
	iStyleAxes(ax);
end

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS4E_PreVsPostDistance.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4E_Stats', stats);

function iStyleAxes(ax)
box(ax, 'off');
ax.FontName = 'Arial'; ax.FontSize = 6; ax.LineWidth = 0.5;
ax.XColor = 'k'; ax.YColor = 'k'; ax.TickDir = 'out'; ax.TickLength = [0.025, 0.025];
ax.LabelFontSizeMultiplier = 1; ax.TitleFontSizeMultiplier = 1;
if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end
