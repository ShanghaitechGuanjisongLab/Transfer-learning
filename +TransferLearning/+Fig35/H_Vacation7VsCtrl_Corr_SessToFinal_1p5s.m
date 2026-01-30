% Fig3.5H：放假7天组 vs 对照组 的“会话 vs 光水最终会话”相关性（NTATS@1.5s）
%
% 口径：
% - correct：Phase=Final, Stimulus=LightWater（每鼠取一个 Final 会话）
% - session pool：LightWater 会话从 Transfer 到 Final（每会话一个点，After100 截断）
% - 指标：对共同细胞的 Pearson 相关（按层 MOp2/3 与 MOp5 分开）
%
% Output:
% - SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.H_Vacation7VsCtrl_Corr_SessToFinal_1p5s

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_5h_Vacation7VsCtrl_Corr_SessToFinal_1p5s.svg";

% --- ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

CtrlDS = TransferLearning.AudioLightBaseline();
ExpDS  = TransferLearning.Vacation7();

targetAtSec = 1.5;
minCommonCells = 5;

T = [
	TransferLearning.Fig37.iBuildCorr_SessionsToFinalLight_ByMouseLayer(CtrlDS, "Ctrl", 'TargetAtSec', targetAtSec, 'MinCommonCells', minCommonCells)
	TransferLearning.Fig37.iBuildCorr_SessionsToFinalLight_ByMouseLayer(ExpDS,  "Vac7", 'TargetAtSec', targetAtSec, 'MinCommonCells', minCommonCells)
];

if isempty(T)
	error('Fig3_5h:Empty', 'No valid mice for correlation analysis.');
end
assignin('base','Fig3_5h_Vac7VsCtrl_ByMouseLayer', T);

% Stats (group compare per layer)
Stats = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), 'VariableNames', {'ZKey','NCtrl','NExp','P_Ranksum_FisherZ'});
for zKey = ["MOp23","MOp5"]
	A = T(T.Group=="Ctrl" & T.ZKey==zKey, :);
	B = T(T.Group=="Vac7" & T.ZKey==zKey, :);
	zA = double(A.FisherZ); zB = double(B.FisherZ);
	zA = zA(isfinite(zA)); zB = zB(isfinite(zB));
	p = NaN;
	if numel(zA) >= 3 && numel(zB) >= 3
		try
			p = ranksum(zA, zB);
		catch
		end
	end
	Stats = [Stats; table(string(zKey), double(numel(zA)), double(numel(zB)), double(p), 'VariableNames', Stats.Properties.VariableNames)]; %#ok<AGROW>
end
assignin('base','Fig3_5h_Vac7VsCtrl_Stats', Stats);

% --- Plot
f = figure('Color','w', 'Name','Fig3.5H Corr(sess, final)@1.5s');
try
	MATLAB.Graphics.FigureAspectRatio(1,1,2/3);
catch
end

tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');

zKeys = ["MOp23","MOp5"]; zLabels = ["MOp2/3","MOp5"];
axList = gobjects(1, numel(zKeys));
pLineAll = matlab.graphics.primitive.Line.empty(0,1);
pTextAll = matlab.graphics.primitive.Text.empty(0,1);
for iZ = 1:numel(zKeys)
	zKey = zKeys(iZ);
	ax = nexttile(tl, iZ);
	axList(iZ) = ax;
	hold(ax,'on'); box(ax,'off');
	grid(ax,'on');
	try
		ax.YGrid = 'off';
		ax.YMinorGrid = 'off';
	catch
	end
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	A = T(T.Group=="Ctrl" & T.ZKey==zKey, :);
	B = T(T.Group=="Vac7" & T.ZKey==zKey, :);
	y1 = double(A.Corr); y2 = double(B.Corr);
	y1 = y1(isfinite(y1)); y2 = y2(isfinite(y2));

	iJitterScatter(ax, 1, y1, [0.2 0.2 0.2]);
	iJitterScatter(ax, 2, y2, [0.2 0.5 0.9]);
	try
		boxchart(ax, ones(size(y1)), y1, 'BoxFaceColor',[0.85 0.85 0.85], 'MarkerStyle','none', 'BoxWidth',0.4);
		boxchart(ax, 2*ones(size(y2)), y2, 'BoxFaceColor',[0.80 0.90 1.00], 'MarkerStyle','none', 'BoxWidth',0.4);
	catch
	end

	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('Ctrl'), sprintf('Vac7')};
	ylabel(ax, 'Corr(session, final) @1.5 s', 'Interpreter','none');
	title(ax, zLabels(iZ), 'Interpreter','none');

	st = Stats(Stats.ZKey==zKey, :);
	if ~isempty(st)
		[ln, tx] = iPLineRanksum(ax, y1, y2, st.P_Ranksum_FisherZ);
		try
			if ~isempty(ln); pLineAll(end+1:end+numel(ln),1) = ln(:); end %#ok<AGROW>
			if ~isempty(tx); pTextAll(end+1:end+numel(tx),1) = tx(:); end %#ok<AGROW>
		catch
		end
	end
end

% If we hide right-panel Y axis, y-lims must be unified across tiles
try
	MATLAB.Graphics.UnifyAxesLims(axList, @ylim);
catch
end

% PLine needs retune after y-lims change
try
	MATLAB.Graphics.PLineRetune(pLineAll, pTextAll);
catch
end

% Hide right-panel Y axis
try
	axs = findobj(f, 'Type','axes');
	if numel(axs) >= 2
		axs = flipud(axs(:));
		axs(2).YTickLabel = [];
		axs(2).YLabel.String = '';
		axs(2).YTick = [];
		axs(2).YAxis.Visible = 'off';
	end
catch
end

sgtitle(tl, 'Vac7 vs Ctrl: Corr(sess, final)', 'Interpreter','none');

iSetFontSizeAuto(f);

% Export
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% --- local helpers

function iSetFontSizeAuto(fig)
	try
		objs = findall(fig, '-property', 'FontSizeMode');
		set(objs, 'FontSizeMode', 'auto');
	catch
	end
end

function iJitterScatter(ax, x0, y, color)
	y = double(y(:));
	use = isfinite(y);
	y = y(use);
	if isempty(y)
		return;
	end

	x = x0 + (rand(size(y)) - 0.5) * 0.18;
	scatter(ax, x, y, 18, 'filled', 'MarkerFaceColor', color, 'MarkerFaceAlpha', 0.65);
end

function [pLines, pTexts] = iPLineRanksum(ax, y1, y2, p)
	pLines = matlab.graphics.primitive.Line.empty(0,1);
	pTexts = matlab.graphics.primitive.Text.empty(0,1);
	if ~isfinite(p)
		return;
	end
	y1 = double(y1(:)); y2 = double(y2(:));
	y1 = y1(isfinite(y1)); y2 = y2(isfinite(y2));
	if isempty(y1) || isempty(y2)
		return;
	end
	try
		X = [ones(numel(y1),1); 2*ones(numel(y2),1)];
		Y = [y1; y2];
		S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		try
			if isprop(S, 'HitTest'); S.HitTest = 'off'; end
			if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
			if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
		catch
		end
		Descriptors = table(S, 0, 0, ("p=" + sprintf('%.3g', p)), 0, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		[pLines, pTexts] = MATLAB.Graphics.PLine(Descriptors);
		try, delete(S); catch, end
	catch
	end
end
