% 英文图3D：信号保留全细胞散点（所有鼠合并，AW z-score vs LW z-score）
%
% 将所有鼠的最后 AW 和首 LW 的逐细胞中位响应@1s 合并为一个散点图。
% 样式与 Fig3C 一致：scatter + 拟合线 + Spearman 标注。
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.D_SignalRetention_CellScatter

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
svgName = "English_Fig3D_SignalRetention_CellScatter.svg";

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
	valid = isfinite(medAW_1s(idxAW)) & isfinite(medLW_1s(idxLW));
	if sum(valid) < 3, continue; end

	allAW.Append(medAW_1s(idxAW(valid)));
	allLW.Append(medLW_1s(idxLW(valid)));
end

awAll = allAW.Harvest;
lwAll = allLW.Harvest;
[rho, p] = corr(awAll, lwAll, 'Type', 'Spearman');
fprintf('All-cell signal retention: ρ=%.3f, p=%.4g, n=%d cells\n', rho, p, numel(awAll));

%% ===== Plot =====
colorD = [0 0.4470 0.7410]; % blue

f = figure('Color', 'w', 'Name', 'English Fig3D Signal Retention Cell Scatter');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];

ax = axes(f);
hold(ax, 'on');
scatter(ax, awAll, lwAll, 5, colorD, 'LineWidth', 0.2);

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

% p-value annotation (top-right corner)
text(ax, 0.95, 0.95, sprintf('p=%.2g', p), ...
	'Units', 'normalized', 'FontSize', 6, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');

%% ===== Export =====
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ===== Local functions =====
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
