% 英文图3C：Inter-cell SD@1s (session k+1) vs ΔHit — 2×2 (L2/3 vs L5) × (Naive vs Transfer)
%
% 与 Fig2G 布局一致：行=层(L2/3, L5), 列=组(Naive, Transfer)
% 但使用学习过程中所有相邻会话对，而非仅首会话。
%
% Data scope:
% - Transfer: AudioLightBaseline，全部 LW 会话（ceiling excluded）
% - Naive: LightAudioBaseline + LAInterspersed，纯 LW 会话（ceiling excluded）
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) − Hit(k).
% - x = inter-cell SD of median ZScore at 1s in session k+1, per layer.
%
% Layout: tiledlayout(2,2) — rows: L2/3, L5; cols: Naive, Transfer
% Style: scatter + fit line + Spearman (ref Fig2G).
%
% Execution:
%   TransferLearning.英文图3.C_SD1sVsDeltaHit_ByLayer

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3C_SD1sVsDeltaHit_ByLayer.svg";

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3C:No1s', 'Cannot find a sample close to 1s.');
end

%% ===== Part 1: Transfer LW — AudioLightBaseline =====
DS_ALB = TransferLearning.AudioLightBaseline();
CellTbl_ALB = DS_ALB.Cells;
CellTbl_ALB.CellUID = uint64(CellTbl_ALB.CellUID);
CellTbl_ALB.Mouse = string(CellTbl_ALB.Mouse);
CellTbl_ALB.ZLayer = string(CellTbl_ALB.ZLayer);

SessT = iLightWaterSessions(DS_ALB);
SessT = iKeepPureLW(DS_ALB, SessT);
SessT = iExcludeCeiling(SessT);
PairsT = iSessionPairs(SessT);
fprintf('Transfer LW: %d adjacent session pairs\n', height(PairsT));

% Batch query per-layer SD for session k+1
allDTs_T = unique(PairsT.DateTimeNext);
sdTbl_T = iBatchSD1s_ByLayer(DS_ALB, CellTbl_ALB, allDTs_T, idx1s);

% Build Transfer data vectors
nPT = height(PairsT);
T_SD23 = nan(nPT, 1);
T_SD5  = nan(nPT, 1);
T_DH   = nan(nPT, 1);
T_HK   = nan(nPT, 1);
for iP = 1:nPT
	dtK1 = PairsT.DateTimeNext(iP);
	r = sdTbl_T(sdTbl_T.DateTime == dtK1, :);
	if height(r) == 1
		T_SD23(iP) = r.SD_MOp23;
		T_SD5(iP)  = r.SD_MOp5;
	end
	T_DH(iP) = PairsT.PerformanceNext(iP) - PairsT.Performance(iP);
	T_HK(iP) = PairsT.Performance(iP);
end

%% ===== Part 2: Naive LW — LightAudioBaseline + LAInterspersed =====
% Use phase-based session gathering (matching scratchDualSessionFeatures)
DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();

CT_LAB = DS_LAB.Cells;
CT_LAB.CellUID = uint64(CT_LAB.CellUID); CT_LAB.Mouse = string(CT_LAB.Mouse); CT_LAB.ZLayer = string(CT_LAB.ZLayer);
CT_LAI = DS_LAI.Cells;
CT_LAI.CellUID = uint64(CT_LAI.CellUID); CT_LAI.Mouse = string(CT_LAI.Mouse); CT_LAI.ZLayer = string(CT_LAI.ZLayer);
naiveCellTbls = {CT_LAB; CT_LAI};
naiveDSNames  = ["LAB"; "LAI"];
naiveDSObjs   = {DS_LAB; DS_LAI};

allNaiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
allNaiveSess = iExcludeAudioWaterSessions(allNaiveSess, DS_LAB, DS_LAI);
allNaiveSess = iExcludeCeilingNaive(allNaiveSess);

PairsN = iSessionPairs(allNaiveSess);
fprintf('Naive LW: %d adjacent session pairs (phase-based)\n', height(PairsN));

% Batch query per-layer SD per source dataset
naiveSD = table(NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_MOp23','SD_MOp5'});
for d = 1:numel(naiveDSObjs)
	DS = naiveDSObjs{d};
	dsName = naiveDSNames(d);
	CT = naiveCellTbls{d};
	if isempty(CT), continue; end
	dts = unique(PairsN.DateTimeNext(PairsN.SourceNext == dsName));
	if isempty(dts), continue; end
	sdPart = iBatchSD1s_ByLayer(DS, CT, dts, idx1s);
	if ~isempty(sdPart)
		naiveSD = [naiveSD; sdPart]; %#ok<AGROW>
	end
end
[~, iU] = unique(naiveSD.DateTime);
naiveSD = naiveSD(iU, :);

nPN = height(PairsN);
N_SD23 = nan(nPN, 1);
N_SD5  = nan(nPN, 1);
N_DH   = nan(nPN, 1);
N_HK   = nan(nPN, 1);
for iP = 1:nPN
	dtK1 = PairsN.DateTimeNext(iP);
	r = naiveSD(naiveSD.DateTime == dtK1, :);
	if height(r) == 1
		N_SD23(iP) = r.SD_MOp23;
		N_SD5(iP)  = r.SD_MOp5;
	end
	N_DH(iP) = PairsN.PerformanceNext(iP) - PairsN.Performance(iP);
	N_HK(iP) = PairsN.Performance(iP);
end

%% ===== Statistics (2×2: Spearman, Pearson, Partial Spearman) =====
fprintf('\n=== Panel C: SD@1s vs ΔHit (2×2: Layer × Group) ===\n');
fprintf('  Ceiling (>=100%%) sessions excluded\n');
fprintf('  Simple Spearman | Simple Pearson | Partial Spearman (ctrl Hit_K)\n\n');

kNL23 = isfinite(N_SD23) & isfinite(N_DH) & isfinite(N_HK);
[rhoNL23, pNL23] = deal(NaN); [rPNL23, pPNL23] = deal(NaN); [prhoNL23, ppNL23] = deal(NaN);
if sum(kNL23) >= 4
	[rhoNL23, pNL23] = corr(N_SD23(kNL23), N_DH(kNL23), 'Type', 'Spearman');
	[rPNL23, pPNL23] = corr(N_SD23(kNL23), N_DH(kNL23), 'Type', 'Pearson');
end
if sum(kNL23) >= 6 && std(N_HK(kNL23))>0
	[prhoNL23, ppNL23] = iPartialSpearman(N_SD23(kNL23), N_DH(kNL23), N_HK(kNL23));
end
fprintf('Naive    L2/3: Spearman rho=%+.3f p=%.4g | Pearson r=%+.3f p=%.4g | Partial rho=%+.3f p=%.4g (n=%d)\n', rhoNL23, pNL23, rPNL23, pPNL23, prhoNL23, ppNL23, sum(kNL23));

kNL5 = isfinite(N_SD5) & isfinite(N_DH) & isfinite(N_HK);
[rhoNL5, pNL5] = deal(NaN); [rPNL5, pPNL5] = deal(NaN); [prhoNL5, ppNL5] = deal(NaN);
if sum(kNL5) >= 4
	[rhoNL5, pNL5] = corr(N_SD5(kNL5), N_DH(kNL5), 'Type', 'Spearman');
	[rPNL5, pPNL5] = corr(N_SD5(kNL5), N_DH(kNL5), 'Type', 'Pearson');
end
if sum(kNL5) >= 6 && std(N_HK(kNL5))>0
	[prhoNL5, ppNL5] = iPartialSpearman(N_SD5(kNL5), N_DH(kNL5), N_HK(kNL5));
end
fprintf('Naive    L5:   Spearman rho=%+.3f p=%.4g | Pearson r=%+.3f p=%.4g | Partial rho=%+.3f p=%.4g (n=%d)\n', rhoNL5, pNL5, rPNL5, pPNL5, prhoNL5, ppNL5, sum(kNL5));

kTL23 = isfinite(T_SD23) & isfinite(T_DH) & isfinite(T_HK);
[rhoTL23, pTL23] = deal(NaN); [rPTL23, pPTL23] = deal(NaN); [prhoTL23, ppTL23] = deal(NaN);
if sum(kTL23) >= 4
	[rhoTL23, pTL23] = corr(T_SD23(kTL23), T_DH(kTL23), 'Type', 'Spearman');
	[rPTL23, pPTL23] = corr(T_SD23(kTL23), T_DH(kTL23), 'Type', 'Pearson');
end
if sum(kTL23) >= 6 && std(T_HK(kTL23))>0
	[prhoTL23, ppTL23] = iPartialSpearman(T_SD23(kTL23), T_DH(kTL23), T_HK(kTL23));
end
fprintf('Transfer L2/3: Spearman rho=%+.3f p=%.4g | Pearson r=%+.3f p=%.4g | Partial rho=%+.3f p=%.4g (n=%d)\n', rhoTL23, pTL23, rPTL23, pPTL23, prhoTL23, ppTL23, sum(kTL23));

kTL5 = isfinite(T_SD5) & isfinite(T_DH) & isfinite(T_HK);
[rhoTL5, pTL5] = deal(NaN); [rPTL5, pPTL5] = deal(NaN); [prhoTL5, ppTL5] = deal(NaN);
if sum(kTL5) >= 4
	[rhoTL5, pTL5] = corr(T_SD5(kTL5), T_DH(kTL5), 'Type', 'Spearman');
	[rPTL5, pPTL5] = corr(T_SD5(kTL5), T_DH(kTL5), 'Type', 'Pearson');
end
if sum(kTL5) >= 6 && std(T_HK(kTL5))>0
	[prhoTL5, ppTL5] = iPartialSpearman(T_SD5(kTL5), T_DH(kTL5), T_HK(kTL5));
end
fprintf('Transfer L5:   Spearman rho=%+.3f p=%.4g | Pearson r=%+.3f p=%.4g | Partial rho=%+.3f p=%.4g (n=%d)\n', rhoTL5, pTL5, rPTL5, pPTL5, prhoTL5, ppTL5, sum(kTL5));

% Use partial Spearman for figure annotation (matches scratch)
rhoNL23_fig = prhoNL23; pNL23_fig = ppNL23;
rhoNL5_fig  = prhoNL5;  pNL5_fig  = ppNL5;
rhoTL23_fig = prhoTL23; pTL23_fig = ppTL23;
rhoTL5_fig  = prhoTL5;  pTL5_fig  = ppTL5;

%% ===== Plot (2×2 tiledlayout) =====
f = figure('Color', 'w', 'Name', 'English Fig3C SD@1s vs ΔHit 2x2');
f.Units = 'centimeters';
f.Position(3:4) = [6, 4];

Layout = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
xl = xlabel(Layout, 'Inter-cell SD');
xl.FontSize = 6;
yl = ylabel(Layout, '\DeltaHit');
yl.FontSize = 6;

colorNaive    = [0.8500 0.3250 0.0980]; % orange
colorTransfer = [0 0.4470 0.7410];      % blue

% {row, col} = {layer, group}
sdData = {N_SD23(kNL23), T_SD23(kTL23); N_SD5(kNL5), T_SD5(kTL5)};
dhData = {N_DH(kNL23),  T_DH(kTL23);   N_DH(kNL5),  T_DH(kTL5)};
rhoVals = [rhoNL23_fig, rhoTL23_fig; rhoNL5_fig, rhoTL5_fig];
pVals   = [pNL23_fig,   pTL23_fig;   pNL5_fig,   pTL5_fig];
colors  = {colorNaive, colorTransfer; colorNaive, colorTransfer};
rowTitle = ["L2/3", "L5"];
colTitle = ["Naive", "Transfer"];

axs = gobjects(2, 2);
for iR = 1:2
	for iC = 1:2
		tIdx = (iR - 1) * 2 + iC;
		ax = nexttile(Layout, tIdx);
		axs(iR, iC) = ax;
		hold(ax, 'on'); box(ax, 'off'); grid(ax, 'off');
		ax.FontSize = 6;

		xd = sdData{iR, iC};
		yd = dhData{iR, iC};
		cc = colors{iR, iC};

		scatter(ax, xd, yd, 8, cc, 'LineWidth', 0.2);

		% Fit line
		if numel(xd) >= 2 && std(xd) > 0
			pFit = polyfit(xd, yd, 1);
			xFit = [min(xd), max(xd)];
			yFit = polyval(pFit, xFit);
			plot(ax, xFit, yFit, '-', 'Color', cc, 'LineWidth', 1);
		end

		% Column title on top row only
		if iR == 1
			title(ax, colTitle(iC), 'FontSize', 6, 'FontWeight', 'normal');
		end
		% Row label on left column only
		if iC == 1
			ylabel(ax, rowTitle(iR), 'FontSize', 6);
		end

		% Spearman annotation
		sig = iAsterisk(pVals(iR, iC));
		text(ax, 0.05, 0.95, sprintf('\\rho=%.2f%s', rhoVals(iR, iC), sig), ...
			'Units', 'normalized', 'FontSize', 6, 'VerticalAlignment', 'top');
	end
end

% Unify axes per row
for iR = 1:2
	yl1 = ylim(axs(iR,1)); yl2 = ylim(axs(iR,2));
	ylAll = [min(yl1(1), yl2(1)), max(yl1(2), yl2(2))];
	if ylAll(1) < ylAll(2)
		ylim(axs(iR,1), ylAll); ylim(axs(iR,2), ylAll);
	end
	axs(iR,2).YTickLabel = [];
end

% --- Export SVG
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====

function sdTbl = iBatchSD1s_ByLayer(DS, CellTbl, dts, idx1s)
% Batch compute per-layer inter-cell SD@1s for a list of sessions.
% Returns table(DateTime, SD_MOp23, SD_MOp5).
minCells = 3;

q = struct('Stimulus', 'LightWater', 'DateTime', dts);
ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
nts = ntsCell{1};

if isempty(nts) || ~istable(nts) || height(nts) == 0
	sdTbl = table(NaT(0,1), nan(0,1), nan(0,1), 'VariableNames', {'DateTime','SD_MOp23','SD_MOp5'});
	return;
end

nts.CellUID = uint64(nts.CellUID);
nts.DateTime = datetime(nts.DateTime);
if ~isempty(nts.DateTime.TimeZone), nts.DateTime.TimeZone = ''; end

% Build cell→layer lookup
layerMap = containers.Map('KeyType', 'uint64', 'ValueType', 'char');
for iC = 1:height(CellTbl)
	layerMap(CellTbl.CellUID(iC)) = char(CellTbl.ZLayer(iC));
end

uDTs = unique(nts.DateTime);
nDT = numel(uDTs);
sd23 = nan(nDT, 1);
sd5  = nan(nDT, 1);

for iDT = 1:nDT
	dt = uDTs(iDT);
	sessRows = nts(nts.DateTime == dt, :);

	uCells = unique(sessRows.CellUID);
	nC = numel(uCells);
	vals = nan(nC, 1);
	layers = strings(nC, 1);
	for iC = 1:nC
		cid = uCells(iC);
		cRows = sessRows.TrialSignal(sessRows.CellUID == cid, :);
		med = median(double(cRows), 1, 'omitnan');
		if numel(med) >= idx1s
			vals(iC) = med(idx1s);
		end
		if isKey(layerMap, cid)
			layers(iC) = string(layerMap(cid));
		end
	end

	v23 = vals(isfinite(vals) & layers == "MOp2/3");
	v5  = vals(isfinite(vals) & layers == "MOp5");
	if numel(v23) >= minCells, sd23(iDT) = std(v23, 0, 1); end
	if numel(v5)  >= minCells, sd5(iDT)  = std(v5,  0, 1); end
end

sdTbl = table(uDTs, sd23, sd5, 'VariableNames', {'DateTime','SD_MOp23','SD_MOp5'});
end

function s = iAsterisk(p)
if p < 0.001
	s = "***";
elseif p < 0.01
	s = "**";
elseif p < 0.05
	s = "*";
else
	s = " n.s.";
end
end

function [rho, p] = iPartialSpearman(x, y, z)
% Partial Spearman correlation of x and y, controlling for z.
rx = tiedrank(x); ry = tiedrank(y); rz = tiedrank(z);
rx_res = rx - rz * (rz \ rx);
ry_res = ry - rz * (rz \ ry);
[rho, p] = corr(rx_res, ry_res, 'Type', 'Pearson');
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
% Gather Naive learning sessions from LAB + LAI (phase-based range selection).
% Matches scratchDualSessionFeatures approach.
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});

for iDS = 1:2
	if iDS == 1, DS = LAB; srcName = "LAB"; else, DS = LAI; srcName = "LAI"; end

	if iDS == 2
		badMice = iFindBadMiceLAI(DS);
	else
		badMice = string.empty;
	end

	T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
	T.Phase = string(T.Phase);
	Tr = DS.Trials;
	mice = unique(T.Mouse);

	for iM = 1:numel(mice)
		m = mice(iM);
		if iDS == 2 && any(m == badMice), continue; end
		Tm = T(T.Mouse == m, :);
		phases = unique(Tm.Phase);
		if ~any(phases == "Naive"), continue; end

		hasLearned = any(phases == "Learned");
		hasTransfer = any(phases == "Transfer");
		sessDTs = sort(unique(Tm.DateTime));

		sessPhase = strings(numel(sessDTs), 1);
		for ii = 1:numel(sessDTs)
			ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			ph = ph(ph ~= "" & ~ismissing(ph));
			if isempty(ph), sessPhase(ii) = ""; continue; end
			[uPh,~,ic] = unique(ph); counts = accumarray(ic,1);
			[~,mx] = max(counts); sessPhase(ii) = uPh(mx);
		end

		idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		if hasLearned
			idxEnd = find(sessPhase == "Learned", 1, 'last');
		elseif hasTransfer
			idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
			idxEnd = idxTransferStart - 1;
		else
			idxEnd = numel(sessDTs);
		end

		if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end

		for k = idxNaiveStart:idxEnd
			dt = sessDTs(k);
			blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
			TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
			if isempty(TrSess), continue; end
			lwMask = string(TrSess.Stimulus) == "LightWater";
			if ~any(lwMask), continue; end
			perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
			if ~isfinite(perf), continue; end
			AllSess = [AllSess; table(m, dt, perf, srcName, ...
				'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		end
	end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows', 'first');
AllSess = AllSess(ia, :);
end

function badMice = iFindBadMiceLAI(DS)
badMice = string.empty;
T = DS.TableQuery(["Mouse","DateTime","Phase"]);
T.Mouse = string(T.Mouse); T.DateTime = datetime(T.DateTime); T.DateTime.TimeZone = '';
T.Phase = string(T.Phase);
mice = unique(T.Mouse);
for iM = 1:numel(mice)
	m = mice(iM);
	Tm = T(T.Mouse == m, :);
	dts = unique(Tm.DateTime);
	for iDT = 1:numel(dts)
		ph = Tm.Phase(Tm.DateTime == dts(iDT));
		if any(ph == "Naive" | ph == "Learned")
			if iHasStimulus(DS, m, dts(iDT), "AudioWater")
				badMice = [badMice; m]; %#ok<AGROW>
				break;
			end
		end
	end
end
badMice = unique(badMice);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
	if AllSess.Source(i) == "LAB", DS = LAB; else, DS = LAI; end
	if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		keep(i) = false;
	end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	rows = find(AllSess.Mouse == m);
	p = double(AllSess.Performance(rows));
	i100 = find(p >= 1-1e-12, 1, 'first');
	if ~isempty(i100), remove(rows(i100:end)) = true; end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1-1e-12, :);
end

function SessOut = iExcludeFloor(SessIn)
% Exclude last 0% session and all sessions before it (per mouse).
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i0 = find(p <= 1e-12, 1, 'last');
	if ~isempty(i0)
		remove(rows(1:i0)) = true;
	end
end
SessOut(remove, :) = [];
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus)); st = st(~ismissing(st));
tf = any(st == string(stim));
end

function Sess = iLightWaterSessions(DS)
% Build per-session LW performance (all sessions, no phase filter).
Blocks = DS.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end
blkVars = string(Blocks.Properties.VariableNames);
if ismember("MustWarn", blkVars)
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks = Blocks(:, {'BlockUID','DateTime','MustWarn'});

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", :);
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});

T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perfSess = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
Sess = table(mouse, dt, perfSess, 'VariableNames', {'Mouse','DateTime','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW(DS, SessIn)
% Exclude sessions that contain any AudioWater trials.
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", :);
if isempty(TrAW), return; end

blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
for m = unique(SessOut.Mouse)'
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(p >= 1 - 1e-12, 1, 'first');
	if ~isempty(i100)
		remove(rows(i100:end)) = true;
	end
end
SessOut(remove, :) = [];
perf = double(SessOut.Performance);
SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function Pairs = iSessionPairs(Sess)
% Build adjacent session pair table. One row per pair (k, k+1).
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(Sess.Mouse);

nTotal = 0;
for mi = 1:numel(mice)
	nS = nnz(Sess.Mouse == mice(mi));
	if nS >= 2, nTotal = nTotal + nS - 1; end
end

outMouse = strings(nTotal, 1);
outDT    = NaT(nTotal, 1);
outPerf  = nan(nTotal, 1);
outDT2   = NaT(nTotal, 1);
outPerf2 = nan(nTotal, 1);
hasSrc = ismember('Source', Sess.Properties.VariableNames);
if hasSrc
	outSrc  = strings(nTotal, 1);
	outSrc2 = strings(nTotal, 1);
end

pos = 0;
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance);
	dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	R = R(use, :);
	perf = perf(use);
	dt = dt(use);
	if numel(perf) < 2, continue; end
	n = numel(perf) - 1;
	idx = (pos + 1):(pos + n);
	outMouse(idx) = repmat(m, n, 1);
	outDT(idx)    = dt(1:end-1);
	outPerf(idx)  = perf(1:end-1);
	outDT2(idx)   = dt(2:end);
	outPerf2(idx) = perf(2:end);
	if hasSrc
		src = string(R.Source);
		outSrc(idx)  = src(1:end-1);
		outSrc2(idx) = src(2:end);
	end
	pos = pos + n;
end

Pairs = table(outMouse(1:pos), outDT(1:pos), outPerf(1:pos), outDT2(1:pos), outPerf2(1:pos), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext'});
if hasSrc
	Pairs.Source     = outSrc(1:pos);
	Pairs.SourceNext = outSrc2(1:pos);
end
end
