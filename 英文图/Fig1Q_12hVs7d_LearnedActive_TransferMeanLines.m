% 英文图1Q：12 h与7 d各自声水Learned阶段活跃细胞在迁移光水阶段的两条钙活动均值线。
% 复用1P口径：Learned/AudioWater的cue+1 s响应高于cue前基线均值+3σ，细胞只在各自队列内与Transfer/LightWater配准。
% 迁移阶段不筛选Behavior，合并hit/miss后逐细胞取trial中位数，再跨选中细胞计算均值±SEM。
% 时间窗、版式沿用当前1P：cue前1 s至后3 s，12×8 cm，缩放2，图例位于左上角。

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

datasets = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
cohorts = ["12 h", "7 d"];
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

xMask = (xsSec >= -1) & (xsSec <= 3);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig1Q:No1s', '找不到接近cue+1 s的采样点。');
end

qLearnedAudio = struct('Phase', 'Learned', 'Stimulus', 'AudioWater');
qTransfer = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
Y = nan(numel(xsPlot), 2);
E = nan(numel(xsPlot), 2);
transferSignals = cell(2, 1);
activeMasks = cell(2, 1);
sampleCounts = table();
for cohortIndex = 1:numel(datasets)
	DS = datasets{cohortIndex};
	G = struct();
	G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	G.Transfer = DS.QueryNTATS(qTransfer, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	S = UniExp.NtatsCellStrip(G);
	X = iGetNtats3D(S);
	if isempty(X) || size(X, 2) ~= numel(xsSec) || size(X, 3) ~= 2
		error('Fig1Q:InvalidSignals', '%s的Learned/Transfer配准数据为空或维度不匹配。', cohorts(cohortIndex));
	end
	XLearned = X(:, :, 1);
	baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
	baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
	v1 = XLearned(:, idx1s);
	activeMask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
	if ~any(activeMask)
		error('Fig1Q:NoActiveCells', '%s中没有符合声水Learned活跃标准的配准细胞。', cohorts(cohortIndex));
	end
	panelNames = ["Learned"; "Transfer"];
	sampleMasks = false(size(X, 1), 2);
	for panelIndex = 1:2
		panelData = X(:, :, panelIndex);
		sampleMasks(:, panelIndex) = activeMask & any(isfinite(panelData(:, xMask)), 2);
	end
	groupCounts = TransferLearning.PanelSampleCountTable(S, panelNames, sampleMasks, DS.Cells);
	transferCounts = groupCounts(string(groupCounts.Panel) == "Transfer", :);
	sampleCounts = [sampleCounts; table(cohorts(cohortIndex), transferCounts.NMouse, transferCounts.NCell, 'VariableNames', {'Cohort', 'NMouse', 'NCell'})];
	transferData = X(activeMask, xMask, 2);
	transferSignals{cohortIndex} = transferData;
	activeMasks{cohortIndex} = activeMask;
	Y(:, cohortIndex) = mean(transferData, 1, 'omitnan')';
	E(:, cohortIndex) = std(transferData, 0, 1, 'omitnan')' / sqrt(size(transferData, 1));
end
%%

f = figure('Color', 'w', 'Name', 'English Fig1Q 12h vs 7d learned active transfer mean lines');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];

hold('on');

lineColors = [TransferLearning.Color12h; TransferLearning.Color7d] / 255;
Patches = MATLAB.Graphics.MultiShadowedLines(Y, E, 0.2, X=repmat(xsPlot(:), 1, 2), EdgeColors=lineColors);

xline(0, '--');
xline(1, '--');

box('off');
xlabel('Time');
ylabel('z-score');
XTL = string(xticklabels);
[~, Index] = ismember([0, 1], xticks);
XTL(Index) = ["💡", "💧"];
xticklabels(XTL);

lg = legend(Patches, cohorts, Location="northwest");
title('🔊💧 learned active cells');
svgPath = 'English_Fig1Q_12hVs7d_LearnedActive_TransferMeanLines.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== Fig1Q：迁移光水全部回合，不区分hit/miss ===\n');
disp(sampleCounts);

function X = iGetNtats3D(S)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S, 'NTATS')
	nt = S.NTATS;
else
	nt = S;
end
if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end
if isnumeric(nt) && ndims(nt) == 3
	X = nt;
	return;
end
error('Fig1Q:BadNTATS', '不支持的NTATS容器类型：%s。', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[distance, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(distance) && distance <= tolSec;
end