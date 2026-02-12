% 英文图2G：L5 Divergence vs 首会话命中率 散点图 + 中介效应注释
%
% 两组分色：Transfer (ALB) + Naive (LAB+LAI)
% 两组均显著负相关 → Div 越低, 命中率越高 (通用机制)
% 关键发现：控制继承细胞占比后，偏相关 ρ→~0 → 预测力完全由继承细胞中介
%
% 预期统计：
%   Transfer L5: ρ ≈ -0.730, p ≈ 0.017
%   Naive    L5: ρ ≈ -0.815, p ≈ 0.002
%   Partial (ctrl CellFrac): ρ ≈ +0.07, NS
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图2.G_DivVsHitRate_L5_Scatter

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

sampleRate = 8;
idxCue = 3 * sampleRate;
idx1s  = idxCue + sampleRate;

targetLayer = "MOp5";

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

TlearnAW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TlearnAW.Mouse = string(TlearnAW.Mouse);
TlearnAW.DateTime = datetime(TlearnAW.DateTime);
TlearnAW.DateTime.TimeZone = '';

trMice = unique(Ttrans.Mouse);
nT = numel(trMice);

T_Div  = nan(nT, 1);
T_HR   = nan(nT, 1);
T_CellFrac = nan(nT, 1);  % for partial correlation
T_Mouse = strings(nT, 1);

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
	ntsAW = DS_ALB.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsLW), ntsLW = ntsLW{1}; end
	if iscell(ntsAW), ntsAW = ntsAW{1}; end
	if isempty(ntsLW), continue; end

	% 继承组定义
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

	% Build CTT
	[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, allUID, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end

	% Layer filter
	mCell = CellTbl_ALB(CellTbl_ALB.Mouse == m, :);
	[~, loc] = ismember(cellUIDs, mCell.CellUID);
	cLayers = strings(numel(cellUIDs), 1);
	cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));
	layMask = cLayers == targetLayer;

	if sum(layMask) < 3, continue; end

	X = CTT(:, :, idx1s);
	Xa = X(layMask, :);
	T_Div(i) = iDivFromX(Xa);

	% CellFrac for partial correlation
	isInh = ismember(cellUIDs, inhUID);
	nAll = sum(layMask);
	nInh = sum(layMask & isInh);
	T_CellFrac(i) = nInh / nAll;
end

%% ===== Part 2: Naive mice (LightAudioBaseline + LAInterspersed) =====
naiveDSList = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
	builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};

maxN = 50;
N_Div  = nan(maxN, 1);
N_HR   = nan(maxN, 1);
N_Mouse = strings(maxN, 1);
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

		% Hit rate
		beh = double(Ts.Behavior);
		beh = beh(isfinite(beh));
		hitRate = mean(beh);

		ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
		if iscell(ntsLW), ntsLW = ntsLW{1}; end
		if isempty(ntsLW), continue; end

		[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate);
		if isempty(CTT) || size(CTT, 1) < 3, continue; end

		% Layer filter
		mCell = CellTbl(CellTbl.Mouse == m, :);
		[~, loc] = ismember(cellUIDs, mCell.CellUID);
		cLayers = strings(numel(cellUIDs), 1);
		cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));
		layMask = cLayers == targetLayer;

		if sum(layMask) < 3, continue; end

		X = CTT(:, :, idx1s);
		divVal = iDivFromX(X(layMask, :));

		nNaive = nNaive + 1;
		N_Div(nNaive) = divVal;
		N_HR(nNaive)  = hitRate;
		N_Mouse(nNaive) = m;
	end
end
N_Div  = N_Div(1:nNaive);
N_HR   = N_HR(1:nNaive);
N_Mouse = N_Mouse(1:nNaive);

%% ===== 统计检验 =====
fprintf('\n=== Panel G: L5 Div vs Hit Rate ===\n');

% Transfer
kT = isfinite(T_Div) & isfinite(T_HR);
[rhoT, pT] = corr(T_Div(kT), T_HR(kT), 'type', 'Spearman');
fprintf('Transfer L5: ρ=%+.3f p=%.4g n=%d\n', rhoT, pT, sum(kT));

% Naive
kN = isfinite(N_Div) & isfinite(N_HR);
[rhoN, pN] = corr(N_Div(kN), N_HR(kN), 'type', 'Spearman');
fprintf('Naive    L5: ρ=%+.3f p=%.4g n=%d\n', rhoN, pN, sum(kN));


%% ===== 作图 =====
f = figure('Color', 'w', 'Name', 'English Fig2G L5 Div vs Hit Rate');
f.Units = 'centimeters';
f.Position(3:4) = [5, 4];

ax = axes(f);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;

% Colors
colorTransfer = [0 0.4470 0.7410];  % blue
colorNaive    = [0.8500 0.3250 0.0980];  % orange

% Scatter points
scatter(ax, T_Div(kT), T_HR(kT), 12, colorTransfer, 'filled', 'MarkerFaceAlpha', 0.7);
scatter(ax, N_Div(kN), N_HR(kN), 12, colorNaive, 'filled', 'MarkerFaceAlpha', 0.7);

% Fit lines
if sum(kT) >= 2 && std(T_Div(kT)) > 0
	pFitT = polyfit(T_Div(kT), T_HR(kT), 1);
	xFitT = [min(T_Div(kT)), max(T_Div(kT))];
	yFitT = polyval(pFitT, xFitT);
	plot(ax, xFitT, yFitT, '-', 'Color', colorTransfer, 'LineWidth', 1);
end

if sum(kN) >= 2 && std(N_Div(kN)) > 0
	pFitN = polyfit(N_Div(kN), N_HR(kN), 1);
	xFitN = [min(N_Div(kN)), max(N_Div(kN))];
	yFitN = polyval(pFitN, xFitN);
	plot(ax, xFitN, yFitN, '-', 'Color', colorNaive, 'LineWidth', 1);
end

xlabel(ax, 'L5 Divergence');
ylabel(ax, 'First session hit rate');

% Annotations
annY = 0.98;
annDY = 0.10;
if isfinite(pT)
	pSigT = iAsterisk(pT);
	text(ax, 0.02, annY, sprintf('Transfer: \\rho=%.2f%s', rhoT, pSigT), ...
		'Units', 'normalized', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
		'FontSize', 6, 'Color', colorTransfer);
end
if isfinite(pN)
	pSigN = iAsterisk(pN);
	text(ax, 0.02, annY - annDY, sprintf('Naive: \\rho=%.2f%s', rhoN, pSigN), ...
		'Units', 'normalized', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
		'FontSize', 6, 'Color', colorNaive);
end

% Legend
lg = legend(ax, {'Transfer', 'Naive'}, 'Location', 'best');
lg.FontSize = 12;
lg.Box = 'off';

% --- Export ---
svgPath = fullfile(outDirUNC, "English_Fig2G_DivVsHitRate_L5.svg");
TransferLearning.PrintFigure(f, svgPath);

% Summary to workspace
assignin('base', 'Fig2G_Transfer', table(T_Mouse(kT), T_Div(kT), T_HR(kT), T_CellFrac(kT), ...
	'VariableNames', {'Mouse','Div','HR','CellFrac'}));
assignin('base', 'Fig2G_Naive', table(N_Mouse(kN), N_Div(kN), N_HR(kN), ...
	'VariableNames', {'Mouse','Div','HR'}));
assignin('base', 'Fig2G_Stats', struct('rhoT', rhoT, 'pT', pT, 'rhoN', rhoN, 'pN', pN));

%% ===== local functions =====

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
