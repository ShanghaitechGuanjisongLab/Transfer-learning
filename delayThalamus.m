% delay thalamus 行为学学习曲线：yqn2400 的声水（AudioLearnWater）与光水（LightLearnWater）各一张图，
% 每张图都含一条来自延迟范式对照组的 control 曲线。
%
% 数据来源：\\Data-Server-2\个人数据\杨青宁\202610\delayTh\yqn2400.AudioLearnWater.行为.mat
%           \\Data-Server-2\个人数据\杨青宁\202610\delayTh\yqn2400.LightLearnWater.行为.mat
%
% 口径（与同目录已有的 yqn2400.*.行为.fig 图线一致，已逐一核对到每一位小数）：
%   每个 session 为 100 试次，命中率 = 该 session 的"命中"事件数 / 该 session 试次数。
%   这两个行为文件只记录 EventLog，没有 Trial 级 Behavior 列，故用
%   TransferLearning.DelayComparison.EventLogSessionTable 解析。
%   按用户要求，两个 mat 的最后一个 session 均舍弃（Audio 7/13、Light 7/12）。
%
% 对照组（都是含延迟的范式）：
%   声水 control = CohortBlocks("DelayedAudioWater")，即 TransferLearning.ALDelayed 的声水学习阶段
%                  （4 只鼠 yqn2200~2203，AudioPreTrain 不计入）。
%   光水 control = CohortBlocks("DelayedTransfer")，即同一批鼠的延迟光水迁移阶段。
%
% 作图：只画散点+折线（不做 sigmoid 拟合）；横轴为 session 序号，纵轴为命中率（0-1）；
%   对照曲线为每块鼠间均值±SEM，声水对照只画块 1-5（该区间才有 ≥2 只鼠）。
%   颜色：delay 曲线用 TH 组绿色（TransferLearning.ColorB，
%   同中文图 Fig62A / 英文图 Fig4C 的 TH 曲线），control 曲线用 TransferLearning.TransferColor（橙色）。
%
% 导出：SVG 写到上述 delayTh 目录。ExportStandardFigure 只接受文件名并把图写进当月目录，
%   无法指定子目录，故此处用 ApplyStandardExportStyle + print 直接写到 delayTh。
%
% 执行方式（硬性要求）：本文件保持为脚本，在 MATLAB 编辑器（Editor）中直接 Run/F5。

%% --- 0) 项目加载 ---
if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

%% --- 1) 数据读取（每个 mat 去掉最后一个 session） ---
DataDir = "\\Data-Server-2\个人数据\杨青宁\202610\delayTh";
DesignNames = ["AudioLearnWater", "LightLearnWater"];
Stimuli = {["AudioLearnWater", "AudioLearnWaterAlways"], ...
	["LightLearnWater", "LightLearnWaterAlways"]};
ControlCohorts = ["DelayedAudioWater", "DelayedTransfer"];
% control 曲线显示到第几个 block：声水只在 1-5 块有 ≥2 只鼠（6-8 块仅 yqn2200），故只画 1-5
ControlShowBlocks = [5, inf];

Sessions = cell(1, numel(DesignNames));
for iDesign = 1:numel(DesignNames)
	matPath = fullfile(DataDir, "yqn2400." + DesignNames(iDesign) + ".行为.mat");
	DS = UniExp.DataSet(matPath);
	T = TransferLearning.DelayComparison.EventLogSessionTable(DS, Stimuli{iDesign});
	T = iDropLastSession(T);
	Sessions{iDesign} = TransferLearning.DelayComparison.AddBlockIndex(T);
	fprintf('%s: %s, %d sessions, hit rate %s\n', DesignNames(iDesign), ...
		string(T.Mouse(1)), height(T), mat2str(T.Performance.', 3));
end

%% --- 2) 两张图：对照组 + delay ---
ColorDelay = TransferLearning.ColorB;
ColorControl = TransferLearning.TransferColor;
DesignTables = cell(1, numel(DesignNames));
ControlTables = cell(1, numel(DesignNames));
for iDesign = 1:numel(DesignNames)
	Delay = Sessions{iDesign};

	Control = TransferLearning.DelayComparison.CohortBlocks(ControlCohorts(iDesign));
	Control = TransferLearning.DelayComparison.AddBlockIndex(Control);
	lastBlock = min(max(Control.Block), ControlShowBlocks(iDesign));
	XControl = (1:lastBlock).';
	[MeanControl, SemControl, NControl] = TransferLearning.DelayComparison.CurveSummary(Control, XControl);
	NMiceControl = numel(unique(Control.Mouse));
	fprintf('%s control (%s): %d mice, %d sessions, blocks 1-%d, block 1 hit rate %.3f\n', ...
		DesignNames(iDesign), ControlCohorts(iDesign), NMiceControl, height(Control), ...
		lastBlock, MeanControl(1));
	Delay = Delay(Delay.Block <= lastBlock, :);

	DesignTables{iDesign} = Delay;
	ControlTables{iDesign} = table(XControl, MeanControl, SemControl, NControl, ...
		'VariableNames', {'Block','MeanHitRate','SemHitRate','NMice'});

	f = iNewFigure([9, 8]);
	ax = axes(f);
	hControl = iPlotSeries(ax, XControl, MeanControl, SemControl, ColorControl);
	hDelay = iPlotSeries(ax, double(Delay.Block), double(Delay.Performance), [], ColorDelay);
	iStyleAxes(ax, max([XControl; Delay.Block]));
	lgd = legend(ax, [hControl, hDelay], ...
		{sprintf('Control (n=%d)', NMiceControl), ...
		sprintf('Delay (n=%d)', numel(unique(Delay.Mouse)))}, ...
		'Location', 'southeast');
	lgd.Box = 'off';
	lgd.AutoUpdate = 'off';

	SvgPath = iExport(f, "DelayThalamus_yqn2400_" + DesignNames(iDesign) + ".svg", DataDir);
	fprintf('Wrote: %s\n', SvgPath);
end

%% --- 3) 结果导出到工作区 ---
assignin('base', 'DelayThalamusAudio', DesignTables{1});
assignin('base', 'DelayThalamusLight', DesignTables{2});
assignin('base', 'DelayThalamusControlAudio', ControlTables{1});
assignin('base', 'DelayThalamusControlLight', ControlTables{2});

%% --- 局部函数 ---
function T = iDropLastSession(T)
T = sortrows(T, {'Mouse', 'DateTime'});
keep = true(height(T), 1);
for mouse = unique(T.Mouse).'
	rows = find(T.Mouse == mouse);
	keep(rows(end)) = false;
end
T = T(keep, :);
end

function f = iNewFigure(SizeCm)
f = figure('Color', 'w');
f.Units = 'centimeters';
f.Position(3:4) = SizeCm;
f.PaperUnits = 'centimeters';
f.PaperSize = SizeCm;
f.PaperPositionMode = 'auto';
end

function h = iPlotSeries(ax, X, Y, Err, Color)
hold(ax, 'on');
if isempty(Err)
	h = plot(ax, X, Y, '-o', 'Color', Color, 'MarkerFaceColor', Color, ...
		'MarkerEdgeColor', Color, 'MarkerSize', 5, 'LineWidth', 1);
else
	h = errorbar(ax, X, Y, Err, '-o', 'Color', Color, 'MarkerFaceColor', Color, ...
		'MarkerEdgeColor', Color, 'MarkerSize', 5, 'LineWidth', 1, 'CapSize', 4);
end
end

function iStyleAxes(ax, XMax)
ax.FontSize = 12;
ax.LineWidth = 1;
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');
xlim(ax, [0.5, XMax + 0.5]);
xticks(ax, 1:XMax);
ylim(ax, [0, 1]);
yticks(ax, 0:0.5:1);
xlabel(ax, 'Session');
ylabel(ax, 'Hit rate');
end

function SvgPath = iExport(f, SvgName, OutDir)
TransferLearning.ApplyStandardExportStyle(f, 2);
SvgPath = fullfile(OutDir, SvgName);
print(f, SvgPath, '-dsvg');
end
