% 英文图3E：信号保留全细胞散点（Moderates only）
%
% 将所有鼠的最后 AW 和首 LW 的逐细胞中位响应@1s 合并为一个散点图。
% 仅保留两个会话都是 Moderates 的细胞（AW 和 LW 中位 z-score@1s 均 ∈ [-1,1]）。
% 样式：scatter + 拟合线 + Spearman 标注。
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.E_SignalRetention_CellScatter_Moderates

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName = "English_Fig3E_SignalRetention_CellScatter_Moderates.svg";

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

% Collect all cells across mice
allAW = MATLAB.DataTypes.ArrayBuilder;
allLW = MATLAB.DataTypes.ArrayBuilder;

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

	% Match cells
	[~, idxAW, idxLW] = intersect(awCells, lwCells);
	awMatched = medAW_1s(idxAW);
	lwMatched = medLW_1s(idxLW);

	% Keep only both-Moderates for scatter
	valid = isfinite(awMatched) & isfinite(lwMatched) ...
		& awMatched >= -1 & awMatched <= 1 ...
		& lwMatched >= -1 & lwMatched <= 1;
	if sum(valid) < 3, continue; end

	allAW.Append(awMatched(valid));
	allLW.Append(lwMatched(valid));
end

awAll = allAW.Harvest;
lwAll = allLW.Harvest;
[rho, p] = corr(awAll, lwAll, 'Type', 'Spearman');
fprintf('Moderates-cell signal retention: ρ=%.3f, p=%.4g, n=%d cells\n', rho, p, numel(awAll));

%% ===== Plot =====
colorE = [0 0.4470 0.7410]; % blue

f = figure('Color', 'w', 'Name', 'English Fig3E Signal Retention (Moderates)');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

ax = axes(f);
hold(ax, 'on');
scatter(ax, awAll, lwAll, 5, colorE, 'LineWidth', 0.2);

% Fit line
if numel(awAll) >= 2 && std(awAll) > 0
	pFit = polyfit(awAll, lwAll, 1);
	xFit = [min(awAll), max(awAll)];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'Color', [0.85 0.325 0.098], 'LineWidth', 1);
end
hold(ax, 'off');

ax.FontSize = 6;
box(ax, 'off');
grid(ax, 'off');
xlabel(ax, '🔊💧 z-score');
ylabel(ax, '💡💧 z-score');
title(ax, 'Moderate cells', 'FontSize', 6);

% Expand x/y limits so points do not sit on axes bounds
xMin = min(awAll); xMax = max(awAll);
yMin = min(lwAll); yMax = max(lwAll);
dx = max(0.05, 0.08 * max(1e-6, xMax - xMin));
dy = max(0.05, 0.08 * max(1e-6, yMax - yMin));
xlim(ax, [xMin - dx, xMax + dx]);
ylim(ax, [yMin - dy, yMax + dy]);

% p-value annotation (top-right corner)
if p == 0 || p < 1e-10
	pStr = 'p<10^{-10}';
elseif p < 0.001
	pStr = sprintf('p=%.1e', p);
else
	pStr = sprintf('p=%.2g', p);
end
text(ax, 0.97, 0.97, pStr, ...
	'Units', 'normalized', 'FontSize', 6, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
	'BackgroundColor', 'w', 'Margin', 0.5);

%% ===== Export Part 1 =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);
