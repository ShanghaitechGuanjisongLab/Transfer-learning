% English FigS2G: hit/miss cell divergence + outcome selectivity on ALDelayed
% （英文图/Fig2D_HitMissCellDivergence 与 Fig2E_HitMissOutcomeSelectivity 的合并：
% 两组条形上下两 tile，取点由 1.0 s 改为延迟任务的 1.5 s）。
%
% Choice decoder weights w at +1.5 s（训练 = AudioLearnWater 声水训练 hit/miss，
% Always 不参与；见 TransferLearning.BuildChoiceDecoderDataDelayed）；
% 每鼠首个 LightLearnWater 会话（transfer/光水学习；Always 不参与）内：
%   上 tile（← Fig2D）：hit divergence（hit-weight 细胞在 hit 回合）vs
%                       miss divergence（miss-weight 细胞在 miss 回合），
%                       散度用 Figure 1 定义，取 cue +1.5 s；
%   下 tile（← Fig2E）：hit cells on hit trials vs miss cells on miss trials，
%                       平均 z（cue +1.5 s）。
% 两组条形配对（sign-rank），显著性标注同 Fig2D/2E（BarScatterCompare PLine +
% PText 覆盖为配对 sign-rank p），不画每鼠散点。
%
% Outputs (SVG):
%   - English_FigS2G_Delayed_HitMissBars.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

data = TransferLearning.BuildChoiceDecoderDataDelayed();
if isempty(data.choice)
	error('FigS2G:NoMice', 'No valid AudioLearnWater choice-decoder mice in ALDelayed.');
end
DS = TransferLearning.ALDelayed();
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[~, idx1p5] = min(abs(xsSec - 1.5));

nM = numel(data.choice);
divHit = nan(nM, 1);
divMiss = nan(nM, 1);
actH_hit = nan(nM, 1);
actM_miss = nan(nM, 1);
miceOut = strings(nM, 1);
for i = 1:nM
	m = string(data.choice{i}.Mouse);
	cellUIDs = uint64(data.choice{i}.cellUIDs);
	w = data.choice{i}.w1p5;
	hitCells = cellUIDs(w > 0);
	missCells = cellUIDs(w < 0);
	if numel(hitCells) < 3 || numel(missCells) < 3
		continue;
	end
	dt = iFirstLearnLightDateTime(DS, m);
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
	X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idx1p5);
	if isempty(X)
		continue;
	end
	% 上 tile（Fig2D 口径）：散度
	Xh = X(ismember(cellUIDs, hitCells), behTrial == 1);
	Xm = X(ismember(cellUIDs, missCells), behTrial == 0);
	if size(Xh, 1) >= 3 && size(Xh, 2) >= 3 && size(Xm, 1) >= 3 && size(Xm, 2) >= 3
		divHit(i) = iDivFromX(Xh);
		divMiss(i) = iDivFromX(Xm);
	end
	% 下 tile（Fig2E 口径）：平均 z
	iH = ismember(cellUIDs, hitCells);
	iM = ismember(cellUIDs, missCells);
	hT = behTrial == 1;
	mT = behTrial == 0;
	aHH = mean(mean(X(iH, hT), 2), 'omitnan');
	aMM = mean(mean(X(iM, mT), 2), 'omitnan');
	if all(isfinite([aHH, aMM]))
		actH_hit(i) = aHH;
		actM_miss(i) = aMM;
	end
	miceOut(i) = m;
end

okD = isfinite(divHit) & isfinite(divMiss);
divHitD = divHit(okD);
divMissD = divMiss(okD);
okA = isfinite(actH_hit) & isfinite(actM_miss);
actH = actH_hit(okA);
actM = actM_miss(okA);
if numel(divHitD) < 2 || numel(actH) < 2
	error('FigS2G:InsufficientMice', 'Fewer than 2 mice with valid hit/miss data.');
end

pDiv = signrank(divHitD, divMissD);
pAct = signrank(actH, actM);
fprintf('=== FigS2G divergence (first LightLearnWater session, cue +1.5 s) ===\n');
fprintf('hit cells in hit trials:   %.3f +/- %.3f (n = %d mice)\n', mean(divHitD), std(divHitD) / sqrt(numel(divHitD)), numel(divHitD));
fprintf('miss cells in miss trials: %.3f +/- %.3f\n', mean(divMissD), std(divMissD) / sqrt(numel(divMissD)));
fprintf('paired signrank p = %.4g\n', pDiv);
fprintf('=== FigS2G activity at cue +1.5 s (first LightLearnWater session) ===\n');
fprintf('hit cells on hit trials:   %.3f +/- %.3f (n = %d mice)\n', mean(actH), std(actH) / sqrt(numel(actH)), numel(actH));
fprintf('miss cells on miss trials: %.3f +/- %.3f\n', mean(actM), std(actM) / sqrt(numel(actM)));
fprintf('paired signrank p = %.4g\n', pAct);

colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];

%% 
% ---------- figure：上下两 tile（Fig2D 条形 + Fig2E 条形），tiledlayout 自动布局 ----------
f = figure('Color', 'w', 'Name', 'English FigS2G delayed hit-miss bars');
f.Units = 'centimeters';
f.Position(3:4) = [4, 8];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
ax1 = nexttile(Layout);
iPairedBars(ax1, divHitD, divMissD, pDiv);
xticklabels(ax1,[]);
ylabel(ax1, 'Divergence');
ax2 = nexttile(Layout);
iPairedBars(ax2, actH, actM, pAct);
ylabel(ax2, 'Mean z at cue +1.5 s');

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_FigS2G_Delayed_HitMissBars.svg');
fprintf('Wrote: %s\n', svgPath);

%% ========== local functions ==========
function iPairedBars(ax, vHit, vMiss, pPaired)
% Fig2D/2E 式两组条形：BarScatterCompare（单侧 SEM 误差条、逐根同色、无散点），
% PText 覆盖为配对 sign-rank p，PLine/PText 打标交给标准样式 Retune。
colorHit = [0.85 0.33 0.10];
colorMiss = [0.10 0.45 0.70];
DataCell = {double(vHit(:)), double(vMiss(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
set(ax, 'XTick', [1 2], 'XTickLabel', {'hit', 'miss'});
% bar 不设透明度：FaceAlpha<1 会冲淡柱色，与全饱和 errorbar 视觉不同色（同色规范）
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
if istable(ErrorBars) && ~isempty(ErrorBars) && ismember('Object', ErrorBars.Properties.VariableNames)
	barColors = [colorHit; colorMiss];
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
end

function dt = iFirstLearnLightDateTime(DS, m)
% ALDelayed 无 Phase 列：每鼠首个含 LightLearnWater 回合的会话 = transfer/光水学习首会话。
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
T.Stimulus = string(T.Stimulus);
T = T(T.Mouse == m & T.Stimulus == "LightLearnWater", :);
if isempty(T)
	dt = NaT;
	return;
end
dt = min(T.DateTime);
end

function rows = iQueryFirstBlockRows(DS, m, dt)
% 首会话全部 LightLearnWater 回合（LightLearnWaterAlways 总是给水不参与）。
rows = table();
res = DS.QueryNTS(struct('Mouse', m, 'Stimulus', "LightLearnWater", 'DateTime', dt), UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["Behavior"]);
if istable(res)
	rows = res;
elseif iscell(res)
	parts = res(~cellfun(@isempty, res));
	if ~isempty(parts) && istable(parts{1})
		rows = vertcat(parts{:});
	end
end
if ~isempty(rows)
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

function X = iBuildCellTrialMatrix(rows, cellUIDs, trialUIDs, idxT)
% cells × trials 矩阵，取第 idxT 个时间采样（TrialSignal 是数值时间向量，同 Fig2D）。
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
			sig = double(rC.TrialSignal);
			X(iC, iT) = sig(idxT);
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
