% 英文图2F：Div 分解 — 继承细胞是"净信号提供者" + 消融验证
%
% 子面板 1: CellFrac / SignalFrac / NoiseFrac 条形图
%   继承细胞仅占 ~15% 的细胞, 却贡献 ~40% 的信号功率
%   SignalFrac vs CellFrac p ≈ 0.002
%
% 子面板 2: Div(all) vs Div(noInh) 消融检验
%   消融继承细胞后 Div 显著升高 (p ≈ 0.005)
%
% 数据来源: AudioLightBaseline (Transfer LW 首会话)
% 继承组定义: Learned AW 末会话活跃细胞 (3σ, idx=32)
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

%% ===== 作图 =====
f = figure('Color', 'w', 'Name', 'English Fig2F Div decomposition');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ylabel(Layout, 'Divergence');

cInh = [0.8 0.2 0.2];
cNon = [0.5 0.5 0.5];
tileLayers = [1, 2];
tileLabels = ["All cells", "L2/3"];

for iT = 1:2
	iL = tileLayers(iT);
	nexttile(Layout, iT);

	k = isfinite(R.Div_inhOnly(:, iL)) & isfinite(R.Div_noInh(:, iL));
	divI = R.Div_inhOnly(k, iL);
	divN = R.Div_noInh(k, iL);

	[~, ~, Bars, EB] = UniExp.BarScatterCompare({divI, divN}, true);
	delete(findobj(gca, 'Type', 'Scatter'));
	ax = gca;
	ax.FontSize = 6;
	ax.XTick = [1, 2];
	ax.XTickLabel = {'Inherited', 'Non-inh.'};
	title(ax, tileLabels(iT));
	legend(ax, 'off');
	box(ax, 'off');
	grid(ax, 'off');

	if isscalar(Bars)
		Bars.FaceColor = 'flat';
		Bars.CData = [cInh; cNon];
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	else
		if numel(Bars) >= 2
			Bars(1).FaceColor = cInh; Bars(1).FaceAlpha = 1/3; Bars(1).LineWidth = 0.5;
			Bars(2).FaceColor = cNon; Bars(2).FaceAlpha = 1/3; Bars(2).LineWidth = 0.5;
		end
	end

	pVal = signrank(divI, divN);
	star = iAsterisk(pVal);
	if star ~= ""
		Desc = table(EB.Object(1), EB.Object(2), 1, 1, star, ...
			'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text'});
		[~, PT] = MATLAB.Graphics.PLine(Desc);
		for t = PT(:)', t.FontSize = 6; end
	end
end

% --- Export ---
svgPath = fullfile(outDirUNC, "English_Fig2F_DivDecomposition.svg");
TransferLearning.PrintFigure(f, svgPath);

% --- Summary to workspace ---
assignin('base', 'Fig2F_R', R);

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
	s = "";
end
end
