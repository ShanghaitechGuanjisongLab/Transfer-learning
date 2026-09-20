% English Fig2E: hit cells in hit trials are more convergent across trials
% than miss cells in miss trials
%
% Divergence uses the Figure 1 definition (inter-trial divergence at
% cue +1 s: sqrt(sum across cells of trial-to-trial variance / sum of
% squared trial means)), computed within the first transfer light-water
% block of each mouse:
%   - hit divergence : hit-weight cells (choice decoder w > 0) over hit trials
%   - miss divergence: miss-weight cells (choice decoder w < 0) over miss trials
% Paired comparison across mice (sign-rank).
%
% Outputs (SVG):
%   - English_Fig2E_HitMissCellDivergence.svg
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

data = TransferLearning.BuildCueChoiceDecoderData();
DS = TransferLearning.AudioLightBaseline();

divHit = nan(numel(data.choice), 1);
divMiss = nan(numel(data.choice), 1);
miceOut = strings(numel(data.choice), 1);
for i = 1:numel(data.choice)
	m = string(data.choice{i}.Mouse);
	cellUIDs = uint64(data.choice{i}.cellUIDs);
	w1s = data.choice{i}.w1s;
	hitCells = cellUIDs(w1s > 0);
	missCells = cellUIDs(w1s < 0);
	if numel(hitCells) < 3 || numel(missCells) < 3
		continue;
	end
	dt = iFirstTransferLightWaterDateTime(DS, m);
	if isnat(dt)
		continue;
	end
	rows = iQueryFirstBlockRows(DS, m, dt);
	if isempty(rows)
		continue;
	end
	[trialUIDs, behTrial] = iTrialBehavior(rows);
	hitTrials = trialUIDs(behTrial == 1);
	missTrials = trialUIDs(behTrial == 0);
	if numel(hitTrials) < 3 || numel(missTrials) < 3
		continue;
	end
	X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idx1s);
	if isempty(X)
		continue;
	end
	[~, cLoc] = ismember(cellUIDs, cellUIDs); %#ok<ASGLU>
	Xh = X(ismember(cellUIDs, hitCells), behTrial == 1);
	Xm = X(ismember(cellUIDs, missCells), behTrial == 0);
	if size(Xh, 1) < 3 || size(Xh, 2) < 3 || size(Xm, 1) < 3 || size(Xm, 2) < 3
		continue;
	end
	divHit(i) = iDivFromX(Xh);
	divMiss(i) = iDivFromX(Xm);
	miceOut(i) = m;
end
ok = isfinite(divHit) & isfinite(divMiss);
divHit = divHit(ok);
divMiss = divMiss(ok);
miceOut = miceOut(ok);
if numel(divHit) < 4
	error('Fig2E:InsufficientMice', 'Fewer than 4 mice with valid hit/miss divergence.');
end

pPaired = signrank(divHit, divMiss);
fprintf('=== Fig2E divergence (first transfer light-water block) ===\n');
fprintf('hit cells in hit trials:   %.3f +/- %.3f (n = %d mice)\n', mean(divHit), std(divHit) / sqrt(numel(divHit)), numel(divHit));
fprintf('miss cells in miss trials: %.3f +/- %.3f\n', mean(divMiss), std(divMiss) / sqrt(numel(divMiss)));
fprintf('paired signrank p = %.4g\n', pPaired);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

% 无 legend 基础图：高 4 cm，宽 3 cm（1.5 的整倍数）；Scale=1
f = figure('Color', 'w', 'Name', 'English Fig2E hit vs miss cell divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperSize = [3, 4];
f.PaperPositionMode = 'auto';

ax = axes(f);
DataCell = {double(divHit(:)), double(divMiss(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
% IndividualErrorbars 旗帜：每根误差条独立对象，逐根与所属 bar 同色
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
set(ax, 'XTick', [1 2], 'XTickLabel', {'hit', 'miss'});
ylabel(ax, 'Divergence');
% bar 不设透明度：FaceAlpha<1 会冲淡柱色，与全饱和 errorbar 视觉不同色（违反同色规范）
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	barCData = repmat([colorHit; colorMiss], ceil(nB / 2), 1);
	Bars.CData = barCData(1:nB, :);
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
	Bars.BarWidth = 0.5;
else
	Bars(1).FaceColor = colorHit;
	Bars(2).FaceColor = colorMiss;
	for kB = 1:numel(Bars)
		Bars(kB).EdgeColor = 'none';
		Bars(kB).FaceAlpha = 1;
		Bars(kB).BarWidth = 0.5;
	end
end
% 误差条与所属 bar 同色（第 k 行对应第 k 根 bar）
if istable(ErrorBars) && ~isempty(ErrorBars) && ismember('Object', ErrorBars.Properties.VariableNames)
	barColors = [colorHit; colorMiss];
	for kE = 1:height(ErrorBars)
		eb = ErrorBars.Object(kE);
		if isgraphics(eb) && kE <= size(barColors, 1)
			eb.Color = barColors(kE, :);
		end
	end
end
% BarScatterCompare 内部 PLine 自动绘制；anova/multcompare 不感知配对，
% PText 覆盖为配对 sign-rank p（图注报告口径）
if isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare)
	mc = Optional.MultiCompare;
	if ismember('PText', mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pt = mc.PText(ip);
			if isgraphics(pt)
				pt.String = TransferLearning.Style.iFormatPText(pPaired);
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
legend(ax, 'off');
box(ax, 'off');
ax.Color = 'none';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_Fig2E_HitMissCellDivergence.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig2E_DivergenceStats', struct('Mouse', miceOut, 'DivHit', divHit, 'DivMiss', divMiss, 'pPaired', pPaired));

%% ========== local functions ==========
function dt = iFirstTransferLightWaterDateTime(DS, m)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);
T = T(T.Mouse == m & T.Phase == "Transfer" & T.Stimulus == "LightWater", :);
if isempty(T)
	dt = NaT;
	return;
end
dt = min(T.DateTime);
end

function rows = iQueryFirstBlockRows(DS, m, dt)
rows = table();
res = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'LightWater', 'DateTime', dt), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["Behavior"]);
if istable(res)
	rows = res;
elseif iscell(res)
	parts = res(~cellfun(@isempty, res));
	if ~isempty(parts) && istable(parts{1})
		rows = vertcat(parts{:});
	end
end
if ~isempty(rows)
	% QueryNTS 默认不返回 Mouse/DateTime 列；仅在存在时归一化
	if ismember('Mouse', rows.Properties.VariableNames)
		rows.Mouse = string(rows.Mouse);
	end
	if ismember('DateTime', rows.Properties.VariableNames)
		rows.DateTime = datetime(rows.DateTime);
		if ~isempty(rows.DateTime.TimeZone)
			rows.DateTime.TimeZone = '';
		end
	end
	rows.CellUID = uint64(rows.CellUID);
	rows.TrialUID = uint64(rows.TrialUID);
end
end

function [trialUIDs, behTrial] = iTrialBehavior(rows)
trialUIDs = unique(uint64(rows.TrialUID), 'stable');
behTrial = nan(numel(trialUIDs), 1);
for iT = 1:numel(trialUIDs)
	v = double(rows.Behavior(uint64(rows.TrialUID) == trialUIDs(iT)));
	v = v(isfinite(v));
	if isempty(v)
		continue;
	end
	behTrial(iT) = mode(v);
end
keep = isfinite(behTrial);
trialUIDs = trialUIDs(keep);
behTrial = behTrial(keep);
end

function X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idx1s)
X = [];
rows = rows(ismember(uint64(rows.TrialUID), trialUIDs), :);
if isempty(rows)
	return;
end
present = intersect(cellUIDs, uint64(unique(rows.CellUID)), 'stable');
if numel(present) < 3
		return;
end
X = nan(numel(cellUIDs), numel(trialUIDs));
for iT = 1:numel(trialUIDs)
	rT = rows(uint64(rows.TrialUID) == trialUIDs(iT), :);
	for iC = 1:numel(cellUIDs)
		rC = rT(uint64(rT.CellUID) == cellUIDs(iC), :);
		if height(rC) == 1
			% TrialSignal 是数值时间向量（与 Fig1F 口径一致）
			sig = double(rC.TrialSignal);
			X(iC, iT) = sig(idx1s);
		end
	end
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end
