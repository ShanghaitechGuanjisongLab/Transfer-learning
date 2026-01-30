% 图3.6f：三组学习曲线对比（RSPd / RSPd+M1 / mCherry，LightWater）
%
% 要求：与 \\Data-Server-2\个人数据\张天夫\202512\WTMulti.m 的分组、纳入标准、n 统计保持一致。
% 因此本脚本直接使用 WTMulti.m 相同的数据源与 UniExp.LearningSummarize 流程。
%
% 每脚本一张子图（F），SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.F_LearningCurve_RSPd_RSPdPlusM1_mCherry

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6f_LearningCurve_RSPd_RSPdPlusM1_mCherry.svg";

% --- Ensure project loaded (for UniExp)
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

mchPath = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat";
% --- 1) Load datasets (match WTMulti.m)
rspPath     = "\\Data-Server-2\个人数据\张天夫\202505\RSP-Gi 化学遗传学抑制 声转光.v2.mat";
mopCtrlPath = "\\Data-Server-2\个人数据\张天夫\202409\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.mat";
rspMoPath   = "\\data-server-2\个人数据\张天夫\202507\MOP+RSP化学遗传学抑制.v1.mat";

RSPd = UniExp.DataSet(rspPath);
RSPdTable = RSPd.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
RSPdTable.Group(:) = "RSPd";

MOpControl = UniExp.DataSet(mopCtrlPath);
MOpControlTable = MOpControl.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");

% mCherry: 仅使用 MOpControl（按你的要求去掉 POControl）
ControlTable = MOpControlTable;
ControlTable.Group(:) = "mCherry";

RSPdMo = UniExp.DataSet(rspMoPath);
RSPdMoTable = RSPdMo.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater");
RSPdMoTable.Group(:) = "RSPd+MOp";

% Summarize (match WTMulti.m)
Summary = UniExp.LearningSummarize(MATLAB.DataTypes.MergeTables(RSPdTable, ControlTable, RSPdMoTable));
Summary.Properties.RowNames = replace(Summary.Properties.RowNames, 'MOp', 'M1');
Colors = GlobalOptimization.ColorAllocate(height(Summary), [1,1,1;1,1,1]);

% --- 2) Plot (match WTMulti.m style, keep first 10 blocks)
f = figure('Color','w', 'Name', 'Fig3.6f learning curve (WTMulti-matched)');
try
	MATLAB.Graphics.FigureAspectRatio(3, 2, 3/4);
catch
end
ax = axes(f);
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

hold(ax,'on');
box(ax,'off');
grid(ax,'on');

meanCells = cellfun(@(C) C(1:min(10, numel(C))), Summary.MeanCurve, UniformOutput=false);
semCells  = cellfun(@(C) C(1:min(10, numel(C))), Summary.SemCurve,  UniformOutput=false);
h = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(height(Summary)+1), EdgeColors=Colors);

nEach = cellfun(@height, Summary.LearnedSessions);
labels = Summary.Properties.RowNames + " n=" + string(nEach);

try
	lg = legend(h, labels, Location='southeast');
	lg.Box = 'off';
	if isgraphics(lg) && isprop(lg, 'Interpreter')
		lg.Interpreter = 'none';
	end
catch
	lg = legend(labels, Location='southeast');
	lg.Box = 'off';
	if isgraphics(lg) && isprop(lg, 'Interpreter')
		lg.Interpreter = 'none';
	end
end

title(ax, 'Learning curve (WTMulti-matched)', 'Interpreter','none');
ylabel(ax, 'Hit rate', 'Interpreter','none');
xlabel(ax, 'Block', 'Interpreter','none');
ylim(ax, [0, 1]);

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

try
	Tn = table(Summary.Properties.RowNames, nEach(:), 'VariableNames', {'Group','N'});
	disp(Tn);
catch
end
