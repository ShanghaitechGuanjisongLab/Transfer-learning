% 英文图2F：L2/3 & L5 NaiveLW vs TransferLW 散度对比
%
% 上面板：L2/3 Naive LightWater vs Transfer LightWater（非配对 ranksum）
%   — Transfer 组在 L2/3 层保持了学习带来的低散度
% 下面板：L5 Naive LightWater vs Transfer LightWater（非配对 ranksum）
%   — L5 层 Naive 与 Transfer 散度对比
%
% 数据来源:
%   非配对 Naive LW: LightAudioBaseline + LAInterspersed（Phase=Naive, 排除含AudioWater的会话）
%   非配对 Transfer LW + Div分解: AudioLightBaseline (Transfer LW 首会话)
%   继承组定义: Learned AW 末会话活跃细胞 (3σ, idx=32)
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图2.F_DivDecomposition_InheritedCells

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s  = idxCue + sampleRate;

layers = ["All", "MOp2/3", "MOp5"];
layerLabels = ["All", "L2/3", "L5"];
nLay = numel(layers);

%% ===== 加载数据 =====
DS = TransferLearning.AudioLightBaseline();
CellTbl = DS.Cells;
CellTbl.ZLayer = string(CellTbl.ZLayer);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);

Ttrans = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus"], Phase="Transfer");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.Stimulus = string(Ttrans.Stimulus);
Ttrans = Ttrans(Ttrans.Stimulus == "LightWater", :);
Ttrans.DateTime = datetime(Ttrans.DateTime);
Ttrans.DateTime.TimeZone = '';

TlearnAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TlearnAW.Mouse = string(TlearnAW.Mouse);
TlearnAW.DateTime = datetime(TlearnAW.DateTime);
TlearnAW.DateTime.TimeZone = '';

trMice = unique(Ttrans.Mouse);
nT = numel(trMice);

%% ===== 逐鼠计算分解指标 =====
R = struct();
R.Mouse = strings(nT, 1);
R.HitRate = nan(nT, 1);

% [mouse, layer]
R.Div_all    = nan(nT, nLay);
R.Div_noInh  = nan(nT, nLay);
R.CellFrac   = nan(nT, nLay);
R.SignalFrac  = nan(nT, nLay);
R.NoiseFrac   = nan(nT, nLay);
R.Leverage    = nan(nT, nLay);
R.nCells_all  = nan(nT, nLay);
R.nCells_inh  = nan(nT, nLay);
R.Div_inhOnly = nan(nT, nLay);

for i = 1:nT
	m = trMice(i);
	R.Mouse(i) = m;

	Tm = Ttrans(Ttrans.Mouse == m, :);
	dt = min(Tm.DateTime);
	Ts = Tm(Tm.DateTime == dt, :);
	Ts = sortrows(Ts, "TrialIndex");

	beh = double(Ts.Behavior);
	beh = beh(isfinite(beh));
	R.HitRate(i) = mean(beh);

	allUID = unique(uint64(Ts.TrialUID), 'stable');
	if numel(allUID) < 2, continue; end

	ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	ntsAW = DS.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsLW), ntsLW = ntsLW{1}; end
	if iscell(ntsAW), ntsAW = ntsAW{1}; end
	if isempty(ntsLW), continue; end

	% 继承组定义: Learned AW 末 session 活跃 (3σ)
	inhUID = uint64([]);
	if ~isempty(ntsAW)
		Ta = TlearnAW(TlearnAW.Mouse == m, :);
		dtA = max(Ta.DateTime);
		Ta = sortrows(Ta(Ta.DateTime == dtA, :), "TrialIndex");
		trialA = unique(uint64(Ta.TrialUID), 'stable');
		[CTT_A, uidA] = iLocalBuildCTT(ntsAW, trialA, sampleRate);
		if ~isempty(CTT_A) && size(CTT_A, 1) >= 3
			ntA = squeeze(mean(CTT_A, 2));
			bsl = ntA(:, 1:idxCue);
			activeA = ntA(:, idx1s) > mean(bsl, 2) + 3 * std(bsl, [], 2);
			inhUID = uidA(activeA);
		end
	end

	% Build CTT for Transfer LW first session
	[CTT, uidLW] = iLocalBuildCTT(ntsLW, allUID, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end

	% Layer info
	mCell = CellTbl(CellTbl.Mouse == m, :);
	[~, loc] = ismember(uidLW, mCell.CellUID);
	cLayers = strings(numel(uidLW), 1);
	cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));

	isInh = ismember(uidLW, inhUID);

	for iL = 1:nLay
		if layers(iL) == "All"
			layMask = true(numel(uidLW), 1);
		else
			layMask = cLayers == layers(iL);
		end

		inhMask = layMask & isInh;
		nonMask = layMask & ~isInh;
		allMask = layMask;

		nAll = sum(allMask);
		nInh = sum(inhMask);
		nNon = sum(nonMask);

		if nAll < 3, continue; end

		X = CTT(:, :, idx1s);  % Cell × Trial

		% 全细胞 Div
		Xa = X(allMask, :);
		R.Div_all(i, iL) = iDivFromX(Xa);
		R.nCells_all(i, iL) = nAll;
		R.nCells_inh(i, iL) = nInh;

		% 消融继承组 (仅保留非继承)
		if nNon >= 3
			Xn = X(nonMask, :);
			R.Div_noInh(i, iL) = iDivFromX(Xn);
		end

		% 仅继承组 Div
		if nInh >= 3
			Xi = X(inhMask, :);
			R.Div_inhOnly(i, iL) = iDivFromX(Xi);
		end

		% Div 分解
		if nInh >= 1 && nNon >= 1
			sigI = sum(mean(X(inhMask, :), 2).^2);
			sigN = sum(mean(X(nonMask, :), 2).^2);
			noI  = sum(var(X(inhMask, :), [], 2));
			noN  = sum(var(X(nonMask, :), [], 2));

			sigTotal = sigI + sigN;
			noTotal  = noI + noN;

			R.CellFrac(i, iL)   = nInh / nAll;
			if sigTotal > 0
				R.SignalFrac(i, iL) = sigI / sigTotal;
			end
			if noTotal > 0
				R.NoiseFrac(i, iL) = noI / noTotal;
			end
			R.Leverage(i, iL) = R.SignalFrac(i, iL) - R.NoiseFrac(i, iL);
		end
	end

	fprintf('Mouse %s: HR=%.3f | CellFrac=%.3f SignFrac=%.3f NoiFrac=%.3f | Div all=%.2f noInh=%.2f\n', ...
		m, R.HitRate(i), R.CellFrac(i,1), R.SignalFrac(i,1), ...
		R.NoiseFrac(i,1), R.Div_all(i,1), R.Div_noInh(i,1));
end

%% ===== 统计检验 =====
fprintf('\n=== Panel F: Inherited vs Non-inherited Divergence ===\n');
for iL = 1:nLay
	k = isfinite(R.Div_inhOnly(:, iL)) & isfinite(R.Div_noInh(:, iL));
	n = sum(k);
	if n < 3, continue; end
	p = signrank(R.Div_inhOnly(k, iL), R.Div_noInh(k, iL));
	fprintf('[%s] n=%d: Div(inh)=%.3f±%.3f  Div(non)=%.3f±%.3f  signrank p=%.4g\n', ...
		layerLabels(iL), n, ...
		mean(R.Div_inhOnly(k,iL)), std(R.Div_inhOnly(k,iL))/sqrt(n), ...
		mean(R.Div_noInh(k,iL)), std(R.Div_noInh(k,iL))/sqrt(n), p);
end

%% ===== Naive LW L2/3 Div (for top tile) =====
naiveDSList = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
	builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};

maxN = 50;
N_DivL23 = nan(maxN, 1);
N_DivL5  = nan(maxN, 1);
nNaive_L23 = 0;
nNaive_L5  = 0;

for d = 1:numel(naiveDSList)
	DSn = naiveDSList{d}.DS;
	CellTblN = DSn.Cells;
	CellTblN.ZLayer = string(CellTblN.ZLayer);
	CellTblN.CellUID = uint64(CellTblN.CellUID);
	CellTblN.Mouse = string(CellTblN.Mouse);

	TnaiveAll = DSn.TableQuery(["Mouse","DateTime","Stimulus","TrialUID","TrialIndex"], Phase="Naive");
	if isempty(TnaiveAll), continue; end
	TnaiveAll.Mouse = string(TnaiveAll.Mouse);
	TnaiveAll.Stimulus = string(TnaiveAll.Stimulus);

	mice = unique(TnaiveAll.Mouse);
	for i = 1:numel(mice)
		m = mice(i);
		Tm = TnaiveAll(TnaiveAll.Mouse == m, :);
		if isempty(Tm), continue; end

		% Find first pure-LW Naive session (no AudioWater)
		sess = sort(unique(Tm.DateTime), 'ascend');
		isValid = false(numel(sess), 1);
		for s = 1:numel(sess)
			Tsess = Tm(Tm.DateTime == sess(s), :);
			if any(Tsess.Stimulus == "LightWater") && ~any(Tsess.Stimulus == "AudioWater")
				isValid(s) = true;
			end
		end
		validSess = sess(isValid);
		if isempty(validSess), continue; end

		dt = validSess(1);
		Tsess = Tm(Tm.DateTime == dt & Tm.Stimulus == "LightWater", :);
		Tsess = sortrows(Tsess, "TrialIndex");
		trialUIDs = unique(uint64(Tsess.TrialUID), 'stable');
		if numel(trialUIDs) < 2, continue; end

		ntsLW = DSn.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
		if iscell(ntsLW), ntsLW = ntsLW{1}; end
		if isempty(ntsLW), continue; end

		[CTTn, cellUIDsN] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate);
		if isempty(CTTn) || size(CTTn, 1) < 3, continue; end

		mCellN = CellTblN(CellTblN.Mouse == m, :);
		[~, loc] = ismember(cellUIDsN, mCellN.CellUID);
		cLayersN = strings(numel(cellUIDsN), 1);
		cLayersN(loc > 0) = mCellN.ZLayer(loc(loc > 0));
		maskL23 = cLayersN == "MOp2/3";
		maskL5  = cLayersN == "MOp5";

		if sum(maskL23) >= 3
			nNaive_L23 = nNaive_L23 + 1;
			N_DivL23(nNaive_L23) = iDivFromX(CTTn(maskL23, :, idx1s));
		end
		if sum(maskL5) >= 3
			nNaive_L5 = nNaive_L5 + 1;
			N_DivL5(nNaive_L5) = iDivFromX(CTTn(maskL5, :, idx1s));
		end
	end
end
N_DivL23 = N_DivL23(1:nNaive_L23);
N_DivL5  = N_DivL5(1:nNaive_L5);

% Transfer L2/3 & L5 Div from main loop
kT_L23 = isfinite(R.Div_all(:, 2));
T_DivL23 = R.Div_all(kT_L23, 2);
kT_L5 = isfinite(R.Div_all(:, 3));
T_DivL5 = R.Div_all(kT_L5, 3);

kN = isfinite(N_DivL23);
pUnpaired_L23 = ranksum(N_DivL23(kN), T_DivL23);
fprintf('\n=== Panel F Top: L2/3 NaiveLW vs TransferLW Div (unpaired ranksum) ===\n');
fprintf('  NaiveLW L2/3:    %.3f ± %.3f (n=%d)\n', mean(N_DivL23(kN)), std(N_DivL23(kN))/sqrt(sum(kN)), sum(kN));
fprintf('  TransferLW L2/3: %.3f ± %.3f (n=%d)\n', mean(T_DivL23), std(T_DivL23)/sqrt(numel(T_DivL23)), numel(T_DivL23));
fprintf('  ranksum p = %.4g\n', pUnpaired_L23);

kN5 = isfinite(N_DivL5);
pUnpaired_L5 = ranksum(N_DivL5(kN5), T_DivL5);
fprintf('\n=== Panel F Bottom: L5 NaiveLW vs TransferLW Div (unpaired ranksum) ===\n');
fprintf('  NaiveLW L5:    %.3f ± %.3f (n=%d)\n', mean(N_DivL5(kN5)), std(N_DivL5(kN5))/sqrt(sum(kN5)), sum(kN5));
fprintf('  TransferLW L5: %.3f ± %.3f (n=%d)\n', mean(T_DivL5), std(T_DivL5)/sqrt(numel(T_DivL5)), numel(T_DivL5));
fprintf('  ranksum p = %.4g\n', pUnpaired_L5);

%% ===== 作图 =====
f = figure('Color', 'w', 'Name', 'English Fig2F Div decomposition');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
yl = ylabel(Layout, 'Divergence');
yl.FontSize = 6;

colorNaive = [1 0 0];
colorLearn = [0 0 1];
cInh = [0.8 0.2 0.2];
cNon = [0.5 0.5 0.5];

% --- Tile 1: L2/3 NaiveLW vs TransferLW (unpaired) ---
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({N_DivL23(kN), T_DivL23}, false);  %#ok<*NASGU>
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end
ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1, 2];
ax1.XTickLabel = {'Naive', 'Transfer'};
title(ax1, 'L2/3 💡💧');
legend(ax1, 'off');
box(ax1, 'off');
grid(ax1, 'off');
ax1.XAxis.Visible = 'off';

if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	Bars1.CData = [colorNaive; colorLearn];
	Bars1.BarWidth = 0.5;
	Bars1.LineWidth = 0.5;
	Bars1.FaceAlpha = 1/3;
else
	if numel(Bars1) >= 2
		Bars1(1).FaceColor = colorNaive; Bars1(1).FaceAlpha = 1/3; Bars1(1).LineWidth = 0.5;
		Bars1(2).FaceColor = colorLearn; Bars1(2).FaceAlpha = 1/3; Bars1(2).LineWidth = 0.5;
	end
end

star1 = iAsterisk(pUnpaired_L23);
Desc1 = table(EB1.Object(1), EB1.Object(2), EB1.Index(1), EB1.Index(2), star1, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT1] = MATLAB.Graphics.PLine(Desc1);
for t = PT1(:)', t.FontSize = 6; end

% --- Tile 2: L5 NaiveLW vs TransferLW (unpaired) ---
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({N_DivL5(kN5), T_DivL5}, false);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end
ax2 = gca;
ax2.FontSize = 6;
ax2.FontName = 'Segoe UI Emoji';
ax2.XTick = [1, 2];
ax2.XTickLabel = {'Naive', 'Transfer'};
title(ax2, 'L5 💡💧');
xlabel(ax2, '');
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	Bars2.CData = [colorNaive; colorLearn];
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 0.5;
	Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorNaive; Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 0.5;
		Bars2(2).FaceColor = colorLearn; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 0.5;
	end
end

star2 = iAsterisk(pUnpaired_L5);
Desc2 = table(EB2.Object(1), EB2.Object(2), EB2.Index(1), EB2.Index(2), star2, 0, ...
	'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
[~, PT2] = MATLAB.Graphics.PLine(Desc2);
for t = PT2(:)', t.FontSize = 6; end

% --- Export ---
svgPath = fullfile(outDirUNC, "English_Fig2F_DivDecomposition.svg");
TransferLearning.PrintFigure(f, svgPath);

% --- Summary to workspace ---
assignin('base', 'Fig2F_R', R);
assignin('base', 'Fig2F_NaiveLW_L23', N_DivL23(kN));
assignin('base', 'Fig2F_TransferLW_L23', T_DivL23);
assignin('base', 'Fig2F_pUnpaired_L23', pUnpaired_L23);
assignin('base', 'Fig2F_NaiveLW_L5', N_DivL5(kN5));
assignin('base', 'Fig2F_TransferLW_L5', T_DivL5);
assignin('base', 'Fig2F_pUnpaired_L5', pUnpaired_L5);

%% ===== local functions =====

function div = iDivFromX(X)
% X: Cell × Trial snapshot at a single time point
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

function s = iAsterisk(p)
if p < 0.001
	s = "***";
elseif p < 0.01
	s = "**";
elseif p < 0.05
	s = "*";
else
	s = "n.s.";
end
end
