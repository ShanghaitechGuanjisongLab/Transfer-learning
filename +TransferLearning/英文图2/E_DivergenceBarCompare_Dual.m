% 英文图2E：散度条形图（双比较）
%
% 左面板：Naive AudioOnly vs Learned AudioWater（配对 signrank，全细胞）
%   — 学习使群体 trial 轨迹从分散压缩为聚敛
% 右面板：L2/3 Naive LightWater vs Transfer LightWater（非配对 ranksum）
%   — Transfer 组在 L2/3 层保持了学习带来的低散度
%
% 数据来源：
%   配对: AudioLightBaseline + ALInterspersed（Naive AO first session, Learned AW last session）
%   非配对 Naive LW: LightAudioBaseline + LAInterspersed（Phase=Naive, 排除含AudioWater的会话）
%   非配对 Transfer LW: AudioLightBaseline（Phase=Transfer, Stimulus=LightWater）
%
% 预期统计：
%   左: NaiveAO vs LearnedAW signrank 显著
%   右: L2/3 NaiveLW vs TransferLW ranksum p ≈ 0.046
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图2.E_DivergenceBarCompare_Dual

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

sampleRate = 8;
idxCue = 3 * sampleRate;   % index 24
idx1s  = idxCue + sampleRate; % index 32

%% ===== Part 1: Naive AO vs Learned AW (配对, 全细胞) =====
Sources_Paired = {
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
	builtin('struct', 'Name', "ALInterspersed",     'DS', TransferLearning.ALInterspersed())
};

nSrc = numel(Sources_Paired);
pairRows = cell(nSrc, 1);

for iS = 1:nSrc
	DS = Sources_Paired{iS}.DS;
	dsName = Sources_Paired{iS}.Name;

	% Naive AO sessions
	TNaiveAO = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="AudioOnly");
	if isempty(TNaiveAO)
		pairRows{iS} = table(string.empty(0,1), nan(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DivNaiveAO','DivLearnedAW','Source'});
		continue;
	end
	TNaiveAO.Mouse = string(TNaiveAO.Mouse);
	TNaiveAO.DateTime = datetime(TNaiveAO.DateTime);
	TNaiveAO.DateTime.TimeZone = '';

	% Learned AW sessions
	TLearnAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
	if isempty(TLearnAW)
		pairRows{iS} = table(string.empty(0,1), nan(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DivNaiveAO','DivLearnedAW','Source'});
		continue;
	end
	TLearnAW.Mouse = string(TLearnAW.Mouse);
	TLearnAW.DateTime = datetime(TLearnAW.DateTime);
	TLearnAW.DateTime.TimeZone = '';

	mice = intersect(unique(TNaiveAO.Mouse), unique(TLearnAW.Mouse));
	nM = numel(mice);
	result = table(mice, nan(nM,1), nan(nM,1), repmat(dsName, nM, 1), ...
		'VariableNames', {'Mouse','DivNaiveAO','DivLearnedAW','Source'});

	for i = 1:nM
		m = mice(i);

		% Naive AO: first session
		Ta = TNaiveAO(TNaiveAO.Mouse == m, :);
		dtAO = min(Ta.DateTime);
		Ta = sortrows(Ta(Ta.DateTime == dtAO, :), "TrialIndex");
		trialsAO = unique(uint64(Ta.TrialUID), 'stable');

		% Learned AW: last session
		Tl = TLearnAW(TLearnAW.Mouse == m, :);
		dtAW = max(Tl.DateTime);
		Tl = sortrows(Tl(Tl.DateTime == dtAW, :), "TrialIndex");
		trialsAW = unique(uint64(Tl.TrialUID), 'stable');

		% NTS
		ntsAO = DS.QueryNTS(struct('Stimulus', "AudioOnly", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
		ntsAW = DS.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
		if iscell(ntsAO), ntsAO = ntsAO{1}; end
		if iscell(ntsAW), ntsAW = ntsAW{1}; end
		if isempty(ntsAO) || isempty(ntsAW), continue; end

		% Build CTT and compute Div
		[CTT_AO, ~] = iLocalBuildCTT(ntsAO, trialsAO, sampleRate);
		if ~isempty(CTT_AO) && size(CTT_AO, 1) >= 3
			result.DivNaiveAO(i) = iDivAtIdx(CTT_AO, idx1s);
		end

		[CTT_AW, ~] = iLocalBuildCTT(ntsAW, trialsAW, sampleRate);
		if ~isempty(CTT_AW) && size(CTT_AW, 1) >= 3
			result.DivLearnedAW(i) = iDivAtIdx(CTT_AW, idx1s);
		end
	end
	pairRows{iS} = result;
end

allPaired = vertcat(pairRows{:});

% Collapse by mouse (mean across sources if duplicated)
[G, ~] = findgroups(allPaired.Mouse);
divAO_all = splitapply(@(x) mean(x,'omitnan'), allPaired.DivNaiveAO, G);
divAW_all = splitapply(@(x) mean(x,'omitnan'), allPaired.DivLearnedAW, G);
kPaired = isfinite(divAO_all) & isfinite(divAW_all);
divAO = divAO_all(kPaired);
divAW = divAW_all(kPaired);

pPaired = signrank(divAO, divAW);
fprintf('\n=== Panel E Left: NaiveAO vs LearnedAW Div (paired signrank) ===\n');
fprintf('  NaiveAO:    %.3f ± %.3f (n=%d)\n', mean(divAO), std(divAO)/sqrt(numel(divAO)), numel(divAO));
fprintf('  LearnedAW:  %.3f ± %.3f (n=%d)\n', mean(divAW), std(divAW)/sqrt(numel(divAW)), numel(divAW));
fprintf('  signrank p = %.4g\n', pPaired);

%% ===== Part 2: L2/3 NaiveLW vs TransferLW (非配对) =====

% --- Naive LW: LightAudioBaseline + LAInterspersed ---
naiveDSList = {
	builtin('struct', 'Name', "LightAudioBaseline", 'DS', TransferLearning.LightAudioBaseline())
	builtin('struct', 'Name', "LAInterspersed",     'DS', TransferLearning.LAInterspersed())
};

maxN = 50;
N_DivL23 = nan(maxN, 1);
N_Mouse = strings(maxN, 1);
nNaive = 0;

for d = 1:numel(naiveDSList)
	DS = naiveDSList{d}.DS;
	CellTbl = DS.Cells;
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);

	TnaiveAll = DS.TableQuery(["Mouse","DateTime","Stimulus","TrialUID","TrialIndex"], Phase="Naive");
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
			Ts = Tm(Tm.DateTime == sess(s), :);
			if any(Ts.Stimulus == "LightWater") && ~any(Ts.Stimulus == "AudioWater")
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

		ntsLW = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
		if iscell(ntsLW), ntsLW = ntsLW{1}; end
		if isempty(ntsLW), continue; end

		[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, trialUIDs, sampleRate);
		if isempty(CTT) || size(CTT, 1) < 3, continue; end

		% L2/3 cells only
		mCell = CellTbl(CellTbl.Mouse == m, :);
		[~, loc] = ismember(cellUIDs, mCell.CellUID);
		cLayers = strings(numel(cellUIDs), 1);
		cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));
		mask = cLayers == "MOp2/3";

		if sum(mask) < 3, continue; end

		nNaive = nNaive + 1;
		N_DivL23(nNaive) = iDivAtIdx(CTT(mask, :, :), idx1s);
		N_Mouse(nNaive) = m;
	end
end
N_DivL23 = N_DivL23(1:nNaive);
N_Mouse = N_Mouse(1:nNaive);

% --- Transfer LW: AudioLightBaseline ---
DS_ALB = TransferLearning.AudioLightBaseline();
CellTbl_ALB = DS_ALB.Cells;
CellTbl_ALB.ZLayer = string(CellTbl_ALB.ZLayer);
CellTbl_ALB.CellUID = uint64(CellTbl_ALB.CellUID);
CellTbl_ALB.Mouse = string(CellTbl_ALB.Mouse);

TtransLW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
TtransLW.Mouse = string(TtransLW.Mouse);
TtransLW.DateTime = datetime(TtransLW.DateTime);
TtransLW.DateTime.TimeZone = '';

trMice = unique(TtransLW.Mouse);
nT = numel(trMice);
T_DivL23 = nan(nT, 1);
T_Mouse = strings(nT, 1);

for i = 1:nT
	m = trMice(i);
	T_Mouse(i) = m;

	Tt = TtransLW(TtransLW.Mouse == m, :);
	dtT = min(Tt.DateTime);
	Tt = sortrows(Tt(Tt.DateTime == dtT, :), "TrialIndex");
	trialT = unique(uint64(Tt.TrialUID), 'stable');
	if numel(trialT) < 2, continue; end

	ntsLW = DS_ALB.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsLW), ntsLW = ntsLW{1}; end
	if isempty(ntsLW), continue; end

	[CTT, cellUIDs] = iLocalBuildCTT(ntsLW, trialT, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end

	mCell = CellTbl_ALB(CellTbl_ALB.Mouse == m, :);
	[~, loc] = ismember(cellUIDs, mCell.CellUID);
	cLayers = strings(numel(cellUIDs), 1);
	cLayers(loc > 0) = mCell.ZLayer(loc(loc > 0));
	mask = cLayers == "MOp2/3";

	if sum(mask) < 3, continue; end
	T_DivL23(i) = iDivAtIdx(CTT(mask, :, :), idx1s);
end

kN = isfinite(N_DivL23);
kT = isfinite(T_DivL23);
pUnpaired = ranksum(N_DivL23(kN), T_DivL23(kT));
fprintf('\n=== Panel E Right: L2/3 NaiveLW vs TransferLW Div (unpaired ranksum) ===\n');
fprintf('  NaiveLW L2/3:    %.3f ± %.3f (n=%d)\n', mean(N_DivL23(kN)), std(N_DivL23(kN))/sqrt(sum(kN)), sum(kN));
fprintf('  TransferLW L2/3: %.3f ± %.3f (n=%d)\n', mean(T_DivL23(kT)), std(T_DivL23(kT))/sqrt(sum(kT)), sum(kT));
fprintf('  ranksum p = %.4g\n', pUnpaired);

%% ===== Plot =====
f = figure('Color', 'w', 'Name', 'English Fig2E Divergence dual bar compare');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ylabel(Layout, 'Divergence');

colorNaive = [1 0 0];
colorLearn = [0 0 1];

% --- Top: NaiveAO vs LearnedAW (paired) ---
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({divAO, divAW}, true);
delete(findobj(gca, 'Type', 'Scatter'));
ax1 = gca;
ax1.FontSize = 6;
ax1.FontName = 'Segoe UI Emoji';
ax1.XTick = [1, 2];
ax1.XTickLabel = {'Naive 🔊', 'Learned 🔊💧'};
legend(ax1, 'off');
box(ax1, 'off');
grid(ax1, 'off');

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

star1 = iAsterisk(pPaired);
if star1 ~= ""
	Desc1 = table(EB1.Object(1), EB1.Object(2), 1, 1, star1, ...
		'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text'});
	[~, PT1] = MATLAB.Graphics.PLine(Desc1);
	for t = PT1(:)', t.FontSize = 6; end
end

% --- Bottom: L2/3 NaiveLW vs TransferLW (unpaired) ---
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({N_DivL23(kN), T_DivL23(kT)}, false);
delete(findobj(gca, 'Type', 'Scatter'));
ax2 = gca;
ax2.FontSize = 6;
ax2.FontName = 'Segoe UI Emoji';
ax2.XTick = [1, 2];
ax2.XTickLabel = {'Naive 💡💧', 'Transfer 💡💧'};
title(ax2, 'L2/3');
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

star2 = iAsterisk(pUnpaired);
if star2 ~= ""
	Desc2 = table(EB2.Object(1), EB2.Object(2), 1, 1, star2, ...
		'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text'});
	[~, PT2] = MATLAB.Graphics.PLine(Desc2);
	for t = PT2(:)', t.FontSize = 6; end
end

% --- Export ---
svgPath = fullfile(outDirUNC, "English_Fig2E_DivergenceBarCompare_Dual.svg");
TransferLearning.PrintFigure(f, svgPath);

% --- Summary to base workspace ---
assignin('base', 'Fig2E_Paired_NaiveAO', divAO);
assignin('base', 'Fig2E_Paired_LearnedAW', divAW);
assignin('base', 'Fig2E_Paired_p', pPaired);
assignin('base', 'Fig2E_Unpaired_NaiveLW_L23', N_DivL23(kN));
assignin('base', 'Fig2E_Unpaired_TransferLW_L23', T_DivL23(kT));
assignin('base', 'Fig2E_Unpaired_p', pUnpaired);

%% ===== local functions =====

function div = iDivAtIdx(CTT, timeIdx)
% Divergence at a specific time index from Cell×Trial×Time tensor
X = CTT(:, :, timeIdx);
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
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
