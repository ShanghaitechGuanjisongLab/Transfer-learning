% 英文图2F：Naive声水 vs 学会声水 Divergence，分 L2/3 / L5 上下 tile
%
% 上面板：L2/3  Naive AW vs Learned AW（配对 signrank）
% 下面板：L5    Naive AW vs Learned AW（配对 signrank）
%
% 数据来源：AudioLightBaseline + ALInterspersed
%   Naive AW = 每鼠首会话, Learned AW = 每鼠末会话
%
% 输出: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图2.F_NaiveVsLearnedAW_DivByLayer


sampleRate = 8;
idxCue = 3 * sampleRate;   % index 24
idx1s  = idxCue + sampleRate; % index 32

%% ===== Data: Naive AW vs Learned AW (配对, 分 L2/3 和 L5) =====
Sources = {
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
	builtin('struct', 'Name', "ALInterspersed",     'DS', TransferLearning.ALInterspersed())
};

nSrc = numel(Sources);
pairRows = cell(nSrc, 1);

for iS = 1:nSrc
	DS = Sources{iS}.DS;
	dsName = Sources{iS}.Name;
	CellTbl = DS.Cells;
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);

	% Naive AW sessions
	TNaiveAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Naive", Stimulus="AudioWater");
	if isempty(TNaiveAW)
		pairRows{iS} = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DivNaiveAW_L23','DivLearnedAW_L23','DivNaiveAW_L5','DivLearnedAW_L5','Source'});
		continue;
	end
	TNaiveAW.Mouse = string(TNaiveAW.Mouse);
	TNaiveAW.DateTime = datetime(TNaiveAW.DateTime);
	TNaiveAW.DateTime.TimeZone = '';

	% Learned AW sessions
	TLearnAW = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex"], Phase="Learned", Stimulus="AudioWater");
	if isempty(TLearnAW)
		pairRows{iS} = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DivNaiveAW_L23','DivLearnedAW_L23','DivNaiveAW_L5','DivLearnedAW_L5','Source'});
		continue;
	end
	TLearnAW.Mouse = string(TLearnAW.Mouse);
	TLearnAW.DateTime = datetime(TLearnAW.DateTime);
	TLearnAW.DateTime.TimeZone = '';

	mice = intersect(unique(TNaiveAW.Mouse), unique(TLearnAW.Mouse));
	nM = numel(mice);
	result = table(mice, nan(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), repmat(dsName, nM, 1), ...
		'VariableNames', {'Mouse','DivNaiveAW_L23','DivLearnedAW_L23','DivNaiveAW_L5','DivLearnedAW_L5','Source'});

	for i = 1:nM
		m = mice(i);

		% Naive AW: first session
		Ta = TNaiveAW(TNaiveAW.Mouse == m, :);
		dtNaive = min(Ta.DateTime);
		Ta = sortrows(Ta(Ta.DateTime == dtNaive, :), "TrialIndex");
		trialsNaive = unique(uint64(Ta.TrialUID), 'stable');

		% Learned AW: last session
		Tl = TLearnAW(TLearnAW.Mouse == m, :);
		dtLearned = max(Tl.DateTime);
		Tl = sortrows(Tl(Tl.DateTime == dtLearned, :), "TrialIndex");
		trialsLearned = unique(uint64(Tl.TrialUID), 'stable');

		% NTS for AudioWater
		ntsAW = DS.QueryNTS(struct('Stimulus', "AudioWater", 'Mouse', m), UniExp.Flags.ZScore, 1:24);
		if iscell(ntsAW), ntsAW = ntsAW{1}; end
		if isempty(ntsAW), continue; end

		% Layer mapping
		mCell = CellTbl(CellTbl.Mouse == m, :);

		% --- Naive AW ---
		[CTT_N, uidN] = iLocalBuildCTT(ntsAW, trialsNaive, sampleRate);
		if ~isempty(CTT_N) && size(CTT_N, 1) >= 3
			[~, locN] = ismember(uidN, mCell.CellUID);
			layersN = strings(numel(uidN), 1);
			layersN(locN > 0) = mCell.ZLayer(locN(locN > 0));
			maskN_L23 = layersN == "MOp2/3";
			maskN_L5  = layersN == "MOp5";
			X_N = CTT_N(:, :, idx1s);
			if sum(maskN_L23) >= 3
				result.DivNaiveAW_L23(i) = iDivFromX(X_N(maskN_L23, :));
			end
			if sum(maskN_L5) >= 3
				result.DivNaiveAW_L5(i) = iDivFromX(X_N(maskN_L5, :));
			end
		end

		% --- Learned AW ---
		[CTT_L, uidL] = iLocalBuildCTT(ntsAW, trialsLearned, sampleRate);
		if ~isempty(CTT_L) && size(CTT_L, 1) >= 3
			[~, locL] = ismember(uidL, mCell.CellUID);
			layersL = strings(numel(uidL), 1);
			layersL(locL > 0) = mCell.ZLayer(locL(locL > 0));
			maskL_L23 = layersL == "MOp2/3";
			maskL_L5  = layersL == "MOp5";
			X_L = CTT_L(:, :, idx1s);
			if sum(maskL_L23) >= 3
				result.DivLearnedAW_L23(i) = iDivFromX(X_L(maskL_L23, :));
			end
			if sum(maskL_L5) >= 3
				result.DivLearnedAW_L5(i) = iDivFromX(X_L(maskL_L5, :));
			end
		end
	end
	pairRows{iS} = result;
end

allPaired = vertcat(pairRows{:});

% Collapse by mouse (mean across sources if duplicated)
[G, ~] = findgroups(allPaired.Mouse);
divNaiveL23_all   = splitapply(@(x) mean(x,'omitnan'), allPaired.DivNaiveAW_L23, G);
divLearnedL23_all = splitapply(@(x) mean(x,'omitnan'), allPaired.DivLearnedAW_L23, G);
divNaiveL5_all    = splitapply(@(x) mean(x,'omitnan'), allPaired.DivNaiveAW_L5, G);
divLearnedL5_all  = splitapply(@(x) mean(x,'omitnan'), allPaired.DivLearnedAW_L5, G);

kL23 = isfinite(divNaiveL23_all) & isfinite(divLearnedL23_all);
divNaiveL23   = divNaiveL23_all(kL23);
divLearnedL23 = divLearnedL23_all(kL23);
pL23 = signrank(divNaiveL23, divLearnedL23);

kL5 = isfinite(divNaiveL5_all) & isfinite(divLearnedL5_all);
divNaiveL5   = divNaiveL5_all(kL5);
divLearnedL5 = divLearnedL5_all(kL5);
pL5 = signrank(divNaiveL5, divLearnedL5);

fprintf('\n=== Panel F: NaiveAW vs LearnedAW Div by layer (paired signrank) ===\n');
fprintf('  L2/3: Naive %.3f ± %.3f vs Learned %.3f ± %.3f (n=%d), p=%.4g\n', ...
	mean(divNaiveL23), std(divNaiveL23)/sqrt(numel(divNaiveL23)), ...
	mean(divLearnedL23), std(divLearnedL23)/sqrt(numel(divLearnedL23)), numel(divNaiveL23), pL23);
fprintf('  L5:   Naive %.3f ± %.3f vs Learned %.3f ± %.3f (n=%d), p=%.4g\n', ...
	mean(divNaiveL5), std(divNaiveL5)/sqrt(numel(divNaiveL5)), ...
	mean(divLearnedL5), std(divLearnedL5)/sqrt(numel(divLearnedL5)), numel(divNaiveL5), pL5);

%% ===== Plot =====
f = figure('Color', 'w', 'Name', 'English Fig2F NaiveAW vs LearnedAW Div by layer');
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

% --- Top tile: L2/3 ---
nexttile(Layout, 1);
[~, ~, Bars1, EB1] = UniExp.BarScatterCompare({divNaiveL23, divLearnedL23}, true, ...
	table([1 2], 'VariableNames', {'GroupPair'}));
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end
ax1 = gca;
ax1.FontSize = 6;
ax1.FontName = 'Arial';
ax1.XTick = [1 2];
ax1.XTickLabel = {'Naive', 'Learned'};
title(ax1, 'L2/3', 'FontSize', 6);
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
	for ib = 1:numel(Bars1)
		if mod(ib,2)==1, Bars1(ib).FaceColor = colorNaive; else, Bars1(ib).FaceColor = colorLearn; end
		Bars1(ib).FaceAlpha = 1/3; Bars1(ib).LineWidth = 0.5;
	end
end
for t = findobj(ax1, 'Type', 'Text')', t.FontSize = 6; end

% --- Bottom tile: L5 ---
nexttile(Layout, 2);
[~, ~, Bars2, EB2] = UniExp.BarScatterCompare({divNaiveL5, divLearnedL5}, true, ...
	table([1 2], 'VariableNames', {'GroupPair'}));
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end
ax2 = gca;
ax2.FontSize = 6;
ax2.FontName = 'Arial';
ax2.XTick = [1 2];
ax2.XTickLabel = {'Naive', 'Learned'};
title(ax2, 'L5', 'FontSize', 6);
xlabel(ax2, '🔊💧', 'FontSize', 6);
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
	for ib = 1:numel(Bars2)
		if mod(ib,2)==1, Bars2(ib).FaceColor = colorNaive; else, Bars2(ib).FaceColor = colorLearn; end
		Bars2(ib).FaceAlpha = 1/3; Bars2(ib).LineWidth = 0.5;
	end
end
for t = findobj(ax2, 'Type', 'Text')', t.FontSize = 6; end

% --- Export ---
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgPath = fullfile(outDirUNC, "English_Fig2F_NaiveVsLearnedAW_DivByLayer.svg");
TransferLearning.PrintFigure(f, svgPath);

% --- Summary to base workspace ---
assignin('base', 'Fig2F_NaiveAW_L23', divNaiveL23);
assignin('base', 'Fig2F_LearnedAW_L23', divLearnedL23);
assignin('base', 'Fig2F_pL23', pL23);
assignin('base', 'Fig2F_NaiveAW_L5', divNaiveL5);
assignin('base', 'Fig2F_LearnedAW_L5', divLearnedL5);
assignin('base', 'Fig2F_pL5', pL5);

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
