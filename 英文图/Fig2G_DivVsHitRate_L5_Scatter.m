% 英文图2G：Divergence vs 首会话命中率 散点图 — 2×2 (L2/3 vs L5) × (Naive vs Transfer)
%
% 2×2 布局：行=层(L2/3, L5), 列=组(Naive, Transfer)
% 关键发现：仅 Transfer L5 显著负相关
%
% 数据来源：Transfer (ALB), Naive (LAB+LAI)
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图2.G_DivVsHitRate_L5_Scatter


sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s  = idxCue + sampleRate;

%% ===== Part 1: Transfer mice (AudioLightBaseline) =====
DS_ALB = TransferLearning.AudioLightBaseline();
CellTbl_ALB = DS_ALB.Cells;
CellTbl_ALB.ZLayer = string(CellTbl_ALB.ZLayer);
CellTbl_ALB.CellUID = uint64(CellTbl_ALB.CellUID);
CellTbl_ALB.Mouse = string(CellTbl_ALB.Mouse);

Ttrans = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.Stimulus = string(Ttrans.Stimulus);
Ttrans = Ttrans(Ttrans.Stimulus == "LightWater", :);
Ttrans.DateTime = datetime(Ttrans.DateTime);
Ttrans.DateTime.TimeZone = '';

trMice = unique(Ttrans.Mouse);
nT = numel(trMice);

T_DivL23 = nan(nT, 1);
T_DivL5  = nan(nT, 1);
T_HR     = nan(nT, 1);
T_Mouse  = strings(nT, 1);

for i = 1:nT
	m = trMice(i);
	T_Mouse(i) = m;

	Tm = Ttrans(Ttrans.Mouse == m, :);
	dt = min(Tm.DateTime);
	Ts = Tm(Tm.DateTime == dt, :);
	Ts = sortrows(Ts, "TrialIndex");

	beh = double(Ts.Behavior);
	beh = beh(isfinite(beh));
	T_HR(i) = mean(beh);

	allUID = unique(uint64(Ts.TrialUID), 'stable');
	if numel(allUID) < 2, continue; end

	ntsLW = DS_ALB.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsLW), ntsLW = ntsLW{1}; end
	if isempty(ntsLW), continue; end

	[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, allUID, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end

	mCell = CellTbl_ALB(CellTbl_ALB.Mouse == m, :);
	[~, loc] = ismember(cellUIDs, mCell.CellUID);
	cLayers = strings(numel(cellUIDs), 1);
	cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

	X = CTT(:, :, idx1s);

	maskL23 = cLayers == "MOp2/3";
	maskL5  = cLayers == "MOp5";

	if sum(maskL23) >= 3
		T_DivL23(i) = iDivFromX(X(maskL23, :));
	end
	if sum(maskL5) >= 3
		T_DivL5(i) = iDivFromX(X(maskL5, :));
	end
end

%% ===== Part 2: Naive mice (LightAudioBaseline + LAInterspersed) =====
naiveDSList = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
	builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};

maxN = 50;
N_DivL23 = nan(maxN, 1);
N_DivL5  = nan(maxN, 1);
N_HR     = nan(maxN, 1);
N_Mouse  = strings(maxN, 1);
nNaive = 0;

for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	CellTbl = DS.Cells;
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);

	TnaiveAll = DS.TableQuery(["Mouse","DateTime","Stimulus","TrialUID","TrialIndex","Behavior"], Phase="Naive");
	if isempty(TnaiveAll), continue; end
	TnaiveAll.Mouse = string(TnaiveAll.Mouse);
	TnaiveAll.Stimulus = string(TnaiveAll.Stimulus);

	mice = unique(TnaiveAll.Mouse);
	for i = 1:numel(mice)
		m = mice(i);
		Tm = TnaiveAll(TnaiveAll.Mouse == m, :);
		if isempty(Tm), continue; end

		% Find first pure-LW Naive session
		sess = sort(unique(Tm.DateTime), 'ascend');
		isValid = false(numel(sess), 1);
		for s = 1:numel(sess)
			Tss = Tm(Tm.DateTime == sess(s), :);
			if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
				isValid(s) = true;
			end
		end
		validSess = sess(isValid);
		if isempty(validSess), continue; end

		dt = validSess(1);
		Ts = Tm(Tm.DateTime == dt & Tm.Stimulus == "LightWater", :);
		Ts = sortrows(Ts, "TrialIndex");
		trialUIDs = unique(uint64(Ts.TrialUID), 'stable');
		if numel(trialUIDs) < 2, continue; end

		beh = double(Ts.Behavior);
		beh = beh(isfinite(beh));
		hitRate = mean(beh);

		ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
		if iscell(ntsLW), ntsLW = ntsLW{1}; end
		if isempty(ntsLW), continue; end

		[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate);
		if isempty(CTT) || size(CTT, 1) < 3, continue; end

		mCell = CellTbl(CellTbl.Mouse == m, :);
		[~, loc] = ismember(cellUIDs, mCell.CellUID);
		cLayers = strings(numel(cellUIDs), 1);
		cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

		X = CTT(:, :, idx1s);
		maskL23 = cLayers == "MOp2/3";
		maskL5  = cLayers == "MOp5";

		% 至少一层有效才计入
		if sum(maskL23) < 3 && sum(maskL5) < 3, continue; end

		nNaive = nNaive + 1;
		N_HR(nNaive)  = hitRate;
		N_Mouse(nNaive) = m;
		if sum(maskL23) >= 3
			N_DivL23(nNaive) = iDivFromX(X(maskL23, :));
		end
		if sum(maskL5) >= 3
			N_DivL5(nNaive) = iDivFromX(X(maskL5, :));
		end
	end
end
N_DivL23 = N_DivL23(1:nNaive);
N_DivL5  = N_DivL5(1:nNaive);
N_HR     = N_HR(1:nNaive);
N_Mouse  = N_Mouse(1:nNaive);

%% ===== 统计检验 (2×2) =====
fprintf('\n=== Panel G: Div vs Hit Rate (2×2: Layer × Group) ===\n');

kNL23 = isfinite(N_DivL23) & isfinite(N_HR);
[rhoNL23, pNL23] = corr(N_DivL23(kNL23), N_HR(kNL23), 'type', 'Spearman');
fprintf('Naive   L2/3: ρ=%+.3f p=%.4g n=%d\n', rhoNL23, pNL23, sum(kNL23));

kNL5 = isfinite(N_DivL5) & isfinite(N_HR);
[rhoNL5, pNL5] = corr(N_DivL5(kNL5), N_HR(kNL5), 'type', 'Spearman');
fprintf('Naive   L5:   ρ=%+.3f p=%.4g n=%d\n', rhoNL5, pNL5, sum(kNL5));

kTL23 = isfinite(T_DivL23) & isfinite(T_HR);
[rhoTL23, pTL23] = corr(T_DivL23(kTL23), T_HR(kTL23), 'type', 'Spearman');
fprintf('Transfer L2/3: ρ=%+.3f p=%.4g n=%d\n', rhoTL23, pTL23, sum(kTL23));

kTL5 = isfinite(T_DivL5) & isfinite(T_HR);
[rhoTL5, pTL5] = corr(T_DivL5(kTL5), T_HR(kTL5), 'type', 'Spearman');
fprintf('Transfer L5:   ρ=%+.3f p=%.4g n=%d\n', rhoTL5, pTL5, sum(kTL5));

%% ===== 作图 (2×2 tiledlayout) =====
f = figure('Color', 'w', 'Name', 'English Fig2G Div vs Hit Rate 2x2');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 6, 4];
f.PaperSize = [6, 4];

Layout = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(Layout, '💡💧', 'FontSize', 6, 'FontWeight', 'normal', 'FontName', 'Segoe UI Emoji');
xl = xlabel(Layout, 'Divergence');
xl.FontSize = 6;
yl = ylabel(Layout, 'First block hit rate');
yl.FontSize = 6;

palette2 = [1, 0, 0; 0, 0, 1];
colorNaive = palette2(1,:);
colorTransfer = palette2(2,:);

% cell array for 2×2: {row, col} = {layer, group}
divData  = {N_DivL23(kNL23), T_DivL23(kTL23); N_DivL5(kNL5), T_DivL5(kTL5)};
hrData   = {N_HR(kNL23),     T_HR(kTL23);     N_HR(kNL5),    T_HR(kTL5)};
rhoVals  = [rhoNL23, rhoTL23; rhoNL5, rhoTL5];
pVals    = [pNL23,   pTL23;   pNL5,   pTL5];
colors   = {colorNaive, colorTransfer; colorNaive, colorTransfer};
rowTitle  = ["L2/3", "L5"];
colTitle  = ["Naive", "Transfer"];

for iR = 1:2
	for iC = 1:2
		tIdx = (iR - 1) * 2 + iC;
		nexttile(Layout, tIdx);
		hold on; box off; grid off;
		ax = gca;
		ax.FontSize = 6;
		ax.Toolbar.Visible = 'off';

		xd = divData{iR, iC};
		yd = hrData{iR, iC};
		cc = colors{iR, iC};

		scatter(ax, xd, yd, 5, cc, 'LineWidth', 0.2);

		% Fit line
		if numel(xd) >= 2 && std(xd) > 0
			pFit = polyfit(xd, yd, 1);
			xFit = [min(xd), max(xd)];
			yFit = polyval(pFit, xFit);
			plot(ax, xFit, yFit, '-', 'Color', cc, 'LineWidth', 1);
		end

		% Title: row label + col label
		if iR == 1
			title(ax, colTitle(iC));
		end
		if iC == 1
			ylabel(ax, rowTitle(iR));
		end

		% p-value annotation (top-right corner)
		text(ax, 0.95, 0.95, iFormatPValue(pVals(iR, iC)), ...
			'Units', 'normalized', 'FontSize', 6, 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
	end
end

% --- Export ---
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgPath = fullfile(outDirUNC, "English_Fig2G_DivVsHitRate_L5.svg");
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
print(f, svgPath, '-dsvg');

% Summary to workspace
assignin('base', 'Fig2G_Transfer', table(T_Mouse, T_DivL23, T_DivL5, T_HR, ...
	'VariableNames', {'Mouse','DivL23','DivL5','HR'}));
assignin('base', 'Fig2G_Naive', table(N_Mouse, N_DivL23, N_DivL5, N_HR, ...
	'VariableNames', {'Mouse','DivL23','DivL5','HR'}));
assignin('base', 'Fig2G_Stats', struct( ...
	'rhoNL23', rhoNL23, 'pNL23', pNL23, ...
	'rhoNL5',  rhoNL5,  'pNL5',  pNL5, ...
	'rhoTL23', rhoTL23, 'pTL23', pTL23, ...
	'rhoTL5',  rhoTL5,  'pTL5',  pTL5));

%% ===== local functions =====

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise  = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [CTT, cellUIDs] = iLocalBuildCTT(nts, trialUIDs, sampleRate)
CTT = [];
cellUIDs = uint64([]);
if isempty(nts) || numel(trialUIDs) < 2, return; end
inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts2 = nts(inTrial, :);
if isempty(nts2), return; end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2, return; end
allC = unique(uint64(nts2.CellUID));
nAllC = numel(allC);
traces = cell(nAllC, 1);
keepU = zeros(nAllC, 1, 'uint64');
nKeep = 0;
for ci = 1:nAllC
	cid = allC(ci);
	rows = (uint64(nts2.CellUID) == cid);
	if sum(rows) < numel(trialUIDs), continue; end
	uid = uint64(nts2.TrialUID(rows));
	sig = double(nts2.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf), continue; end
	so = sig(loc, :);
	if any(~isfinite(so), 'all'), continue; end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepU(nKeep) = cid;
end
if nKeep < 1, return; end
traces = traces(1:nKeep);
keepU = keepU(1:nKeep);
nTr = size(traces{1}, 1);
nTi = size(traces{1}, 2);
CTT = nan(nKeep, nTr, nTi);
for ci = 1:nKeep
	CTT(ci, :, :) = traces{ci};
end
idx0 = 3 * sampleRate;
CTT = CTT - CTT(:, :, idx0);
cellUIDs = keepU;
end

function txt = iFormatPValue(p)
if ~isfinite(p)
	txt = 'p = NaN';
elseif p < 0.001
	txt = 'p < 0.001';
elseif p < 0.01
	txt = sprintf('p = %.3f', p);
else
	txt = sprintf('p = %.2f', p);
end
end
