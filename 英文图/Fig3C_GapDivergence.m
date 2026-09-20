% English Fig3C: population divergence at cue +1 s in the first transfer
% light-water block, Control (no gap) vs 7-day gap
%
% Divergence uses the Figure 1 definition (inter-trial divergence at cue +1 s:
% sqrt(sum across cells of trial-to-trial variance / sum of squared trial
% means)), computed per mouse within its first transfer light-water block.
% Groups compared with rank-sum (unpaired, different mice).
%
% Outputs (SVG):
%   - English_Fig3C_GapDivergence.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

sampleRate = 8;
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[~, idx1s] = min(abs(xsSec - 1));

CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

colorCtrl = TransferLearning.TransferColor;
colorGap = TransferLearning.ColorB;

divCtrl = iGroupDivergence(CtrlDS, idx1s);
divV7 = iGroupDivergence(V7DS, idx1s);

[pDiv, ~] = ranksum(divCtrl, divV7);
fprintf('=== Fig3C population divergence (first transfer light-water block) ===\n');
fprintf('Control:   %.3f +/- %.3f (n = %d mice)\n', mean(divCtrl), std(divCtrl) / sqrt(numel(divCtrl)), numel(divCtrl));
fprintf('7-day gap: %.3f +/- %.3f (n = %d mice)\n', mean(divV7), std(divV7) / sqrt(numel(divV7)), numel(divV7));
fprintf('ranksum p = %.4g\n', pDiv);
%% 

% 规范：只有 2 个 bar 的条形图宽度 ≤3 cm、高 4 cm
f = figure('Color', 'w', 'Name', 'English Fig3C gap divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperSize = [3, 4];
f.PaperPositionMode = 'auto';
ax = axes(f);
DataCell = {double(divCtrl(:)), double(divV7(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
% 两组为不同鼠（非配对），BarScatterCompare 内部 anova/multcompare 口径即为非配对，
% 但为统一报告 rank-sum，PText 覆盖为 ranksum p
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax.XTick = 1:2;
% 3 cm 宽下两标签会相接：加前导空格触发 MATLAB 自动旋转标签，免手工旋转
ax.XTickLabel = {'   No gap', '   7-day gap'};
ax.Color = 'none';
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	Bars.CData = repmat([colorCtrl; colorGap], ceil(nB / 2), 1);
	Bars.CData = Bars.CData(1:nB, :);
else
	Bars(1).FaceColor = colorCtrl;
	Bars(2).FaceColor = colorGap;
end
for kB = 1:numel(Bars)
	Bars(kB).BarWidth = 0.5;
	Bars(kB).EdgeColor = 'none';
	Bars(kB).FaceAlpha = 1;
end
if istable(ErrorBars) && ~isempty(ErrorBars) && ismember('Object', ErrorBars.Properties.VariableNames)
	barColors = [colorCtrl; colorGap];
	for kE = 1:height(ErrorBars)
		eb = ErrorBars.Object(kE);
		if isgraphics(eb) && kE <= size(barColors, 1)
			eb.Color = barColors(kE, :);
		end
	end
end
if isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare)
	mc = Optional.MultiCompare;
	if ismember('PText', mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pt = mc.PText(ip);
			if isgraphics(pt)
				pt.String = TransferLearning.Style.iFormatPText(pDiv);
				pt.Tag = 'PText';
			end
		end
	end
	if ismember('PLine', mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pl = mc.PLine(ip);
			if isgraphics(pl)
				pl.Tag = 'PLine';
			end
		end
	end
end
ylabel(ax, 'Divergence');
legend(ax, 'off');
box(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_Fig3C_GapDivergence.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3C_GapDivergenceStats', struct('divCtrl', divCtrl, 'divV7', divV7, 'pDiv', pDiv));

%% ========== local functions ==========
function div = iGroupDivergence(DS, idx1s)
% 每鼠首个 transfer light-water block 的群体 divergence（Fig1 定义）
T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex"], ...
	Phase = "Transfer", Stimulus = "LightWater");
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
mice = unique(T.Mouse);
div = nan(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	dt1 = min(Tm.DateTime);
	Tm = sortrows(Tm(Tm.DateTime == dt1, :), "TrialIndex");
	trialUIDs = unique(uint64(Tm.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		parts = nts(~cellfun(@isempty, nts));
		if isempty(parts)
			continue;
		end
		nts = vertcat(parts{:});
	end
	if isempty(nts)
		continue;
	end
	X = iBuildCellTrialMatrix(nts, trialUIDs, idx1s);
	if isempty(X) || size(X, 1) < 3 || size(X, 2) < 2
		continue;
	end
	sig = sum(mean(X, 2).^2);
	noi = sum(var(X, [], 2));
	if sig > 0
		div(i) = sqrt(noi / sig);
	end
end
div = div(isfinite(div));
end

function X = iBuildCellTrialMatrix(nts, trialUIDs, idx1s)
% cells x trials 矩阵，元素 = 该细胞在该 trial 的 z@cue+1s
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
cellUIDs = unique(nts.CellUID, 'stable');
X = nan(numel(cellUIDs), numel(trialUIDs));
for iT = 1:numel(trialUIDs)
	rT = nts(nts.TrialUID == trialUIDs(iT), :);
	for iC = 1:numel(cellUIDs)
		rC = rT(rT.CellUID == cellUIDs(iC), :);
		if height(rC) == 1
			sig = double(rC.TrialSignal);
			X(iC, iT) = sig(idx1s);
		end
	end
end
end
