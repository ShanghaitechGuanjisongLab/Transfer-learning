% 英文图3F：信号保留分组条形图（Moderates only）
%
% 口径：仅保留两个会话都是 Moderates 的细胞（AW 和 LW 中位 z-score@1s 均 ∈ [-1,1]）。
% 两个 tile：
%   上：按 🔊💧 正/负分组，比较其在 💡💧 中 z-score
%   下：按 💡💧 正/负分组，比较其在 🔊💧 中 z-score
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.F_SignalRetention_SubgroupBar_Moderates

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName = "English_Fig3F_SubgroupBar_Moderates.svg";

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));

baseMask = 1:24;

% Get metadata
Blocks = DS.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Trials = DS.Trials;
Trials.BlockUID = uint64(Trials.BlockUID);

mice = unique(DT.Mouse);
nMice = numel(mice);

meanLW_AWpos = nan(nMice, 1);
meanLW_AWneg = nan(nMice, 1);
meanAW_LWpos = nan(nMice, 1);
meanAW_LWneg = nan(nMice, 1);

for mi = 1:nMice
	m = mice(mi);
	mouseDTs = DT.DateTime(DT.Mouse == m);

	% Find last AW session
	awTrials = Trials(string(Trials.Stimulus) == "AudioWater", :);
	awBlkDTs = innerjoin(awTrials(:,'BlockUID'), Blocks(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	awMouseDates = intersect(unique(awBlkDTs.DateTime), mouseDTs);
	if isempty(awMouseDates), continue; end
	lastAWdt = max(awMouseDates);

	% Find first LW session
	lwTrials = Trials(string(Trials.Stimulus) == "LightWater", :);
	lwBlkDTs = innerjoin(lwTrials(:,'BlockUID'), Blocks(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	lwMouseDates = intersect(unique(lwBlkDTs.DateTime), mouseDTs);
	if isempty(lwMouseDates), continue; end
	firstLWdt = min(lwMouseDates);

	% Get per-cell AW response
	qAW = struct('Stimulus', 'AudioWater', 'DateTime', lastAWdt);
	ntsAW = DS.QueryNTS(qAW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsAW) || isempty(ntsAW{1}), continue; end
	ntsAW = ntsAW{1};
	if ~istable(ntsAW) || height(ntsAW) == 0, continue; end

	awCells = unique(uint64(ntsAW.CellUID));
	medAW_1s = nan(numel(awCells), 1);
	for ic = 1:numel(awCells)
		rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medAW_1s(ic) = med(idx1s); end
	end

	% Get per-cell LW response
	qLW = struct('Stimulus', 'LightWater', 'DateTime', firstLWdt);
	ntsLW = DS.QueryNTS(qLW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsLW) || isempty(ntsLW{1}), continue; end
	ntsLW = ntsLW{1};
	if ~istable(ntsLW) || height(ntsLW) == 0, continue; end

	lwCells = unique(uint64(ntsLW.CellUID));
	medLW_1s = nan(numel(lwCells), 1);
	for ic = 1:numel(lwCells)
		rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medLW_1s(ic) = med(idx1s); end
	end

	% Match cells and keep both-session Moderates
	[~, idxAW, idxLW] = intersect(awCells, lwCells);
	awMatched = medAW_1s(idxAW);
	lwMatched = medLW_1s(idxLW);
	modMask = isfinite(awMatched) & isfinite(lwMatched) ...
		& awMatched >= -1 & awMatched <= 1 ...
		& lwMatched >= -1 & lwMatched <= 1;

	% Tile 1: 🔊💧 pos/neg -> 💡💧
	awPos = modMask & awMatched > 0;
	awNeg = modMask & awMatched < 0;
	if sum(awPos) >= 3 && sum(awNeg) >= 3
		meanLW_AWpos(mi) = mean(lwMatched(awPos));
		meanLW_AWneg(mi) = mean(lwMatched(awNeg));
	end

	% Tile 2: 💡💧 pos/neg -> 🔊💧
	lwPos = modMask & lwMatched > 0;
	lwNeg = modMask & lwMatched < 0;
	if sum(lwPos) >= 3 && sum(lwNeg) >= 3
		meanAW_LWpos(mi) = mean(awMatched(lwPos));
		meanAW_LWneg(mi) = mean(awMatched(lwNeg));
	end
end

vPN1 = isfinite(meanLW_AWpos) & isfinite(meanLW_AWneg);
pPN1 = signrank(meanLW_AWpos(vPN1), meanLW_AWneg(vPN1));
fprintf('\n=== Panel F1: 🔊💧+ vs 🔊💧- -> 💡💧 z-score ===\n');
fprintf('  🔊💧+: %.4f ± %.4f (n=%d)\n', mean(meanLW_AWpos(vPN1)), std(meanLW_AWpos(vPN1))/sqrt(sum(vPN1)), sum(vPN1));
fprintf('  🔊💧-: %.4f ± %.4f (n=%d)\n', mean(meanLW_AWneg(vPN1)), std(meanLW_AWneg(vPN1))/sqrt(sum(vPN1)), sum(vPN1));
fprintf('  signrank p = %.4g\n', pPN1);

vPN2 = isfinite(meanAW_LWpos) & isfinite(meanAW_LWneg);
pPN2 = signrank(meanAW_LWpos(vPN2), meanAW_LWneg(vPN2));
fprintf('\n=== Panel F2: 💡💧+ vs 💡💧- -> 🔊💧 z-score ===\n');
fprintf('  💡💧+: %.4f ± %.4f (n=%d)\n', mean(meanAW_LWpos(vPN2)), std(meanAW_LWpos(vPN2))/sqrt(sum(vPN2)), sum(vPN2));
fprintf('  💡💧-: %.4f ± %.4f (n=%d)\n', mean(meanAW_LWneg(vPN2)), std(meanAW_LWneg(vPN2))/sqrt(sum(vPN2)), sum(vPN2));
fprintf('  signrank p = %.4g\n', pPN2);

colorPos = [0.85 0.325 0.098];
colorNeg = [0 0.4470 0.7410];

f = figure('Color', 'w', 'Name', 'English Fig3F Subgroup Bar');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile(Layout, 1);
CompareGroup1 = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional1, Bars1, EB1] = UniExp.BarScatterCompare( ...
	{meanLW_AWpos(vPN1), meanLW_AWneg(vPN1)}, false, CompareGroup1, 'AsteriskThreshold', 0.05);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB1.Object(:)', eb.LineWidth = 0.5; end

ax1 = gca;
ax1.FontSize = 6;
ax1.XTick = [1 2];
ax1.XTickLabel = {'+', '-'};
ax1.XRuler.Color = 'none';
ax1.XRuler.TickLabelColor = [0 0 0];
ylabel(ax1, '💡💧 z-score');
title(ax1, '🔊💧 subgroups', 'FontSize', 6);
box(ax1, 'off');
grid(ax1, 'off');
legend(ax1, 'off');
ax1.Toolbar.Visible = 'off';

if isscalar(Bars1)
	Bars1.FaceColor = 'flat';
	Bars1.CData = [colorPos; colorNeg];
	Bars1.BarWidth = 0.5; Bars1.LineWidth = 0.5; Bars1.FaceAlpha = 1/3;
else
	if numel(Bars1) >= 2
		Bars1(1).FaceColor = colorPos; Bars1(1).FaceAlpha = 1/3; Bars1(1).LineWidth = 0.5;
		Bars1(2).FaceColor = colorNeg; Bars1(2).FaceAlpha = 1/3; Bars1(2).LineWidth = 0.5;
	end
end

nexttile(Layout, 2);
CompareGroup2 = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional2, Bars2, EB2] = UniExp.BarScatterCompare( ...
	{meanAW_LWpos(vPN2), meanAW_LWneg(vPN2)}, false, CompareGroup2, 'AsteriskThreshold', 0.05);
delete(findobj(gca, 'Type', 'Scatter'));
for eb = EB2.Object(:)', eb.LineWidth = 0.5; end

ax2 = gca;
ax2.FontSize = 6;
ax2.XTick = [1 2];
ax2.XTickLabel = {'+', '-'};
ax2.XRuler.Color = 'none';
ax2.XRuler.TickLabelColor = [0 0 0];
ylabel(ax2, '🔊💧 z-score');
title(ax2, '💡💧 subgroups', 'FontSize', 6);
box(ax2, 'off');
grid(ax2, 'off');
legend(ax2, 'off');
ax2.Toolbar.Visible = 'off';

if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	Bars2.CData = [colorPos; colorNeg];
	Bars2.BarWidth = 0.5; Bars2.LineWidth = 0.5; Bars2.FaceAlpha = 1/3;
else
	if numel(Bars2) >= 2
		Bars2(1).FaceColor = colorPos; Bars2(1).FaceAlpha = 1/3; Bars2(1).LineWidth = 0.5;
		Bars2(2).FaceColor = colorNeg; Bars2(2).FaceAlpha = 1/3; Bars2(2).LineWidth = 0.5;
	end
end

if isfield(Optional1, 'MultiCompare') ...
		&& ismember('PLine', Optional1.MultiCompare.Properties.VariableNames) ...
		&& ismember('PText', Optional1.MultiCompare.Properties.VariableNames)
	MATLAB.Graphics.PLineRetune(Optional1.MultiCompare.PLine, Optional1.MultiCompare.PText);
end
if isfield(Optional2, 'MultiCompare') ...
		&& ismember('PLine', Optional2.MultiCompare.Properties.VariableNames) ...
		&& ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
	MATLAB.Graphics.PLineRetune(Optional2.MultiCompare.PLine, Optional2.MultiCompare.PText);
end

if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
