% Fig3.7B：比较 TH 抑制组 vs 对照组 的 P(T|L)
%
% 参考：Fig3.6G。
% - Active@1s: NTATS(1s) > mean(-3~0s) + 3*std(-3~0s)
% - P(T|L)=P(TransferLight active@1s | LearnedAudio active@1s)
% - Layer: MOp2/3 与 MOp5 分开统计
%
% Output:
% - SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig37.B_PTgivenLA_vs_PTgivenF

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_7b_THInhibitVsCtrl_PTgivenL_Reuse_1s.svg";

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
THDS   = TransferLearning.THInhibit();

RCtrl = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer('DataSet', CtrlDS, 'Source', "AudioLightBaseline");
RTH   = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer('DataSet', THDS,   'Source', "THInhibit");
if isempty(RCtrl) || isempty(RTH)
	error('Fig3_7b:EmptyBuild', 'Empty rows from P(T|L) builder.');
end

RCtrl.Group = repmat("Ctrl", height(RCtrl), 1);
RTH.Group   = repmat("TH",   height(RTH),   1);

R = [RCtrl; RTH];
R.Mouse = string(R.Mouse);

% Exclude yqn1130：信号差且缺少5层（会导致 MOp5 子图不可比）
try
	R = R(R.Mouse ~= "yqn1130", :);
catch
end

rows = table(R.Group, R.Mouse, R.DateTimeTransfer, R.Prob23, R.Prob5, ...
	'VariableNames', {'Group','Mouse','DateTimeTransfer','Prob23','Prob5'});

rows.ZKey = repmat("MOp23", height(rows), 1);
rows.PTgivenL = double(rows.Prob23);
rows2 = rows;
rows2.ZKey = repmat("MOp5", height(rows), 1);
rows2.PTgivenL = double(rows2.Prob5);
rows = [rows; rows2];
rows = rows(:, {'Group','Mouse','DateTimeTransfer','ZKey','PTgivenL'});

assignin('base','Fig3_7b_THInhibitVsCtrl_Rows', rows);

Stats = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), 'VariableNames', {'ZKey','NCtrl','NTH','P_Ranksum_PTgivenL'});
for zKey = ["MOp23","MOp5"]
	A = rows(rows.Group=="Ctrl" & rows.ZKey==zKey, :);
	B = rows(rows.Group=="TH" & rows.ZKey==zKey, :);
	y1 = double(A.PTgivenL); y2 = double(B.PTgivenL);
	p = iRanksumSafe(y1, y2);
	Stats = [Stats; table(string(zKey), double(nnz(isfinite(y1))), double(nnz(isfinite(y2))), double(p), 'VariableNames', Stats.Properties.VariableNames)]; %#ok<AGROW>
end
assignin('base','Fig3_7b_THInhibitVsCtrl_Stats', Stats);

% --- Plot
f = figure('Color','w', 'Name','Fig3.7B THInhibit vs Ctrl Reuse');
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
	hold(ax,'on');
	grid(ax,'on');
	try
		ax.YGrid = 'off';
		ax.YMinorGrid = 'off';
	catch
	end
	box(ax,'off');

	A = rows(rows.Group=="Ctrl" & rows.ZKey==zKey, :);
	B = rows(rows.Group=="TH" & rows.ZKey==zKey, :);
	y1 = double(A.PTgivenL); y2 = double(B.PTgivenL);
	y1 = y1(isfinite(y1)); y2 = y2(isfinite(y2));

	iJitterScatter(ax, 1, y1, [0.25 0.25 0.25]);
	iJitterScatter(ax, 2, y2, [0.8 0.2 0.2]);
	try
		boxchart(ax, ones(size(y1)), y1, 'BoxFaceColor',[0.85 0.85 0.85], 'MarkerStyle','none', 'BoxWidth',0.4);
		boxchart(ax, 2*ones(size(y2)), y2, 'BoxFaceColor',[1.0 0.75 0.75], 'MarkerStyle','none', 'BoxWidth',0.4);
	catch
	end

	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('Ctrl'), sprintf('TH')};
	ylabel(ax, 'P(T|L) @1 s', 'Interpreter','none');
	title(ax, zLabels(iZ), 'Interpreter','none');

	st = Stats(Stats.ZKey==zKey, :);
	if ~isempty(st)
		[ln, tx] = iPLineRanksum(ax, y1, y2, st.P_Ranksum_PTgivenL);
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
sgtitle(tl, 'TH vs Ctrl: P(T|L) @1s', 'Interpreter','none');

% ensure all text uses automatic font sizing
iSetFontSizeAuto(f);

% Export
outDir = iSelectOutDir(outDirUNC);
svgPath = fullfile(outDir, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% local helpers

function outDir = iSelectOutDir(outDirUNC)
	outDir = outDirUNC;
	try
		if ~isfolder(outDir)
			mkdir(outDir);
		end
	catch ME
		error('Fig3_7b:UNCUnreachable', 'UNC path not accessible: %s\n%s', outDirUNC, ME.message);
	end
end

function p = iRanksumSafe(x, y)
p = NaN;
try
	x = double(x(:)); y = double(y(:));
	x = x(isfinite(x)); y = y(isfinite(y));
	if numel(x) >= 3 && numel(y) >= 3
		p = ranksum(x, y);
	end
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
scatter(ax, x, y, 26, 'filled', 'MarkerFaceColor', color, 'MarkerFaceAlpha', 0.65);
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

function iSetFontSizeAuto(fig)
try
	objs = findall(fig, '-property', 'FontSizeMode');
	set(objs, 'FontSizeMode', 'auto');
catch
end
end

