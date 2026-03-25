% 英文图2D：散度条形图（双比较）
%
% 上面板：Naive AudioOnly vs Learned AudioWater（配对 signrank，全细胞）
%   — 学习使群体 trial 轨迹从分散压缩为聚敛
% 下面板：All cells Div(继承) vs Div(非继承)（配对 signrank）
%   — 消融继承细胞后 Div 显著升高
%
% 数据来源：
%   配对AO-AW: AudioLightBaseline + ALInterspersed（Naive AO first session, Learned AW last session）
%   Div分解: AudioLightBaseline（Transfer LW 首会话，继承组=Learned AW 末会话活跃细胞 3σ）
%
% 预期统计：
%   上: NaiveAO vs LearnedAW signrank 显著
%   下: All-cell Div(Inherited) vs Div(Non-inherited) signrank 显著
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图2.D_DivergenceBarCompare_Dual


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
fprintf('\n=== Panel D Left: NaiveAO vs LearnedAW Div (paired signrank) ===\n');
fprintf('  NaiveAO:    %.3f ± %.3f (n=%d)\n', mean(divAO), std(divAO)/sqrt(numel(divAO)), numel(divAO));
fprintf('  LearnedAW:  %.3f ± %.3f (n=%d)\n', mean(divAW), std(divAW)/sqrt(numel(divAW)), numel(divAW));
fprintf('  signrank p = %.4g\n', pPaired);

%% ===== Part 2: Inherited vs Non-inherited Div (All cells, paired signrank) =====

DS_ALB = TransferLearning.AudioLightBaseline();
CellTbl_ALB = DS_ALB.Cells;
CellTbl_ALB.CellUID = uint64(CellTbl_ALB.CellUID);
CellTbl_ALB.Mouse = string(CellTbl_ALB.Mouse);

Ttrans = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Transfer", Stimulus="LightWater");
Ttrans.Mouse = string(Ttrans.Mouse);
Ttrans.DateTime = datetime(Ttrans.DateTime);
Ttrans.DateTime.TimeZone = '';

TlearnAW = DS_ALB.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
TlearnAW.Mouse = string(TlearnAW.Mouse);
TlearnAW.DateTime = datetime(TlearnAW.DateTime);
TlearnAW.DateTime.TimeZone = '';

trMice = unique(Ttrans.Mouse);
nT = numel(trMice);
Div_inhOnly = nan(nT, 1);
Div_noInh = nan(nT, 1);

for i = 1:nT
	m = trMice(i);

	Tm = Ttrans(Ttrans.Mouse == m, :);
	dt = min(Tm.DateTime);
	Ts = sortrows(Tm(Tm.DateTime == dt, :), "TrialIndex");
	allUID = unique(uint64(Ts.TrialUID), 'stable');
	if numel(allUID) < 2, continue; end

	ntsLW = DS_ALB.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	ntsAW = DS_ALB.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsLW), ntsLW = ntsLW{1}; end
	if iscell(ntsAW), ntsAW = ntsAW{1}; end
	if isempty(ntsLW), continue; end

	% Inherited definition: Learned AW last session active cells (3σ)
	inhUID = uint64([]);
	if ~isempty(ntsAW)
		Ta = TlearnAW(TlearnAW.Mouse == m, :);
		if ~isempty(Ta)
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
	end

	[CTT, uidLW] = iLocalBuildCTT(ntsLW, allUID, sampleRate);
	if isempty(CTT) || size(CTT, 1) < 3, continue; end

	isInh = ismember(uidLW, inhUID);
	nInh = sum(isInh);
	nNon = sum(~isInh);

	X = CTT(:, :, idx1s);  % Cell × Trial

	if nInh >= 3
		Div_inhOnly(i) = iDivFromX(X(isInh, :));
	end
	if nNon >= 3
		Div_noInh(i) = iDivFromX(X(~isInh, :));
	end
end

kDecomp = isfinite(Div_inhOnly) & isfinite(Div_noInh);
divI_all = Div_inhOnly(kDecomp);
divN_all = Div_noInh(kDecomp);
pDecomp = signrank(divI_all, divN_all);
fprintf('\n=== Panel D Bottom: All-cell Div Inherited vs Non-inherited (paired signrank) ===\n');
fprintf('  Inherited:     %.3f ± %.3f (n=%d)\n', mean(divI_all), std(divI_all)/sqrt(numel(divI_all)), numel(divI_all));
fprintf('  Non-inherited: %.3f ± %.3f (n=%d)\n', mean(divN_all), std(divN_all)/sqrt(numel(divN_all)), numel(divN_all));
fprintf('  signrank p = %.4g\n', pDecomp);

%% ===== Plot =====
f = figure('Color', 'w', 'Name', 'English Fig2D Divergence dual bar compare');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
yl = ylabel(Layout, 'Divergence');
yl.FontSize = 6;

palette2 = TransferLearning.FigurePalette(2);
colorNaive = palette2(1,:);
colorLearn = palette2(2,:);

% --- Top: NaiveAO vs LearnedAW (paired) ---
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({divAO, divAW}, true);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end
ax1 = gca;
ax1.FontSize = 6;
ax1.FontName = 'Segoe UI Emoji';
ax1.XTick = [1, 2];
ax1.XTickLabel = {'🔊', '🔊💧'};
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
	Desc1 = table(EB1.Object(1), EB1.Object(2), EB1.Index(1), EB1.Index(2), star1, 0, ...
		'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
	[~, PT1] = MATLAB.Graphics.PLine(Desc1);
	for t = PT1(:)', t.FontSize = 6; end
end

% --- Bottom: All cells Div(inherited) vs Div(non-inherited) (paired) ---
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({divI_all, divN_all}, true);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end
ax2 = gca;
ax2.FontSize = 6;
ax2.FontName = 'Segoe UI Emoji';
ax2.XTick = [1, 2];
ax2.XTickLabel = {'Active', 'Inact.'};
title(ax2, 'Cell subgroups of 💡💧');
xlabel(ax2, '🔊💧');
legend(ax2, 'off');
box(ax2, 'off');
grid(ax2, 'off');

cInh = palette2(1,:);
cNon = palette2(2,:);
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	Bars2.CData = [cInh; cNon];
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 0.5;
	Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = cInh; Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 0.5;
		Bars2(2).FaceColor = cNon; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 0.5;
	end
end

star2 = iAsterisk(pDecomp);
if star2 ~= ""
	Desc2 = table(EB2.Object(1), EB2.Object(2), EB2.Index(1), EB2.Index(2), star2, 0, ...
		'VariableNames', {'ObjectA','ObjectB','IndexA','IndexB','Text','ExtraOffset'});
	[~, PT2] = MATLAB.Graphics.PLine(Desc2);
	for t = PT2(:)', t.FontSize = 6; end
end

% --- Export ---
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgPath = fullfile(outDirUNC, "English_Fig2D_DivergenceBarCompare_Dual.svg");
TransferLearning.PrintFigure(f, svgPath);

% --- Summary to base workspace ---
assignin('base', 'Fig2D_Paired_NaiveAO', divAO);
assignin('base', 'Fig2D_Paired_LearnedAW', divAW);
assignin('base', 'Fig2D_Paired_p', pPaired);
assignin('base', 'Fig2D_Decomp_DivInh', divI_all);
assignin('base', 'Fig2D_Decomp_DivNon', divN_all);
assignin('base', 'Fig2D_Decomp_p', pDecomp);

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

function div = iDivFromX(X)
% Divergence from Cell × Trial snapshot at a single time point
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
