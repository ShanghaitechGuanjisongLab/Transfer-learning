function Fig = FlareNtatsHeatmapFigure(Mode, Mouse)
arguments
	Mode (1,1) string {mustBeMember(Mode, ["LearnedTransfer","Timeline"])} = "Timeline"
	Mouse (1,1) string = ""
end

F = TransferLearning.scFLARE;
DT = F.DateTimes;
B = F.Blocks;
T = F.Trials;

% 可选：按 Mouse 限制细胞集合（通过 QueryTable.CellUID 传给 QueryNTATS）
cellUIDFilter = [];
if Mouse ~= ""
	cellUIDFilter = F.Cells.CellUID(string(F.Cells.Mouse) == Mouse);
	if isempty(cellUIDFilter)
		error('No cells found for Mouse=%s in F.Cells.', Mouse);
	end
end

% 按 Mouse 反推出该鼠有哪些 DateTime（DateTimes 本身不带 Mouse 信息）
dtMouse = [];
maskBlockMouse = [];
if Mouse ~= ""
	pathAll = string(B.TiffPath);
	maskBlockMouse = contains(pathAll, filesep + Mouse + filesep) | contains(pathAll, Mouse + ".");
	dtMouse = unique(B.DateTime(maskBlockMouse));
	if isempty(dtMouse)
		error('No Blocks found for Mouse=%s (cannot map sessions).', Mouse);
	end
end

phaseAll = string(DT.Phase);
if Mouse ~= ""
	inMouse = ismember(DT.DateTime, dtMouse);
	idxLearnedDT = find((phaseAll == "Learned") & inMouse, 1, 'first');
	idxTransferDT = find((phaseAll == "Transfer") & inMouse, 1, 'first');
	idxFinalDT = find((phaseAll == "Final") & inMouse, 1, 'first');
else
	idxLearnedDT = find(phaseAll == "Learned", 1, 'first');
	idxTransferDT = find(phaseAll == "Transfer", 1, 'first');
	idxFinalDT = find(phaseAll == "Final", 1, 'first');
end

if isempty(idxLearnedDT) || isempty(idxTransferDT)
	error('Cannot find Learned/Transfer in F.DateTimes.Phase.');
end

dtLearned = DT.DateTime(idxLearnedDT);
dtTransfer = DT.DateTime(idxTransferDT);

finalIsFallback = false;
dtFinal = NaT;
if Mode == "Timeline"
	if ~isempty(idxFinalDT)
		dtFinal = DT.DateTime(idxFinalDT);
	else
		finalIsFallback = true;
		if Mouse ~= ""
			dtFinal = max(dtMouse);
		else
			dtFinal = max(DT.DateTime);
		end
	end

	if dtFinal < dtLearned
		error('Final DateTime is earlier than Learned DateTime.');
	end
	if dtTransfer < dtLearned || dtTransfer > dtFinal
		error('Transfer DateTime is outside Learned→Final range.');
	end
else
	if dtTransfer < dtLearned
		error('Transfer DateTime is earlier than Learned DateTime.');
	end
end

switch Mode
	case "LearnedTransfer"
		Sess = DT((DT.DateTime == dtLearned) | (DT.DateTime == dtTransfer), {'DateTime','Phase'});
	case "Timeline"
		Sess = DT((DT.DateTime == dtLearned) | (DT.DateTime == dtTransfer) | ((DT.DateTime > dtTransfer) & (DT.DateTime < dtFinal)) | (DT.DateTime == dtFinal), {'DateTime','Phase'});
	otherwise
		error('Unknown Mode: %s', Mode);
end

Sess.Phase = string(Sess.Phase);
Sess = sortrows(Sess, 'DateTime');

if Mode == "Timeline" && finalIsFallback
	Sess.Phase(Sess.DateTime == dtFinal) = "Final";
end

% 按 Mouse 过滤会话（DateTimes 本身不带 Mouse，因此用 Blocks.TiffPath 反推）
if Mouse ~= ""
	Sess = Sess(ismember(Sess.DateTime, dtMouse), :);
	if isempty(Sess)
		error('No sessions found for Mouse=%s.', Mouse);
	end
end

stimulus = strings(height(Sess), 1);
for i = 1:height(Sess)
	dt = Sess.DateTime(i);
	if Mouse ~= ""
		blockUIDs = B.BlockUID((B.DateTime == dt) & maskBlockMouse);
	else
		blockUIDs = B.BlockUID(B.DateTime == dt);
	end
	st = string(T.Stimulus(ismember(T.BlockUID, blockUIDs)));
	st = st(~ismissing(st));
	if isempty(st)
		stimulus(i) = missing;
	else
		[u, ~, ic] = unique(st);
		c = accumarray(ic, 1);
		[~, m] = max(c);
		stimulus(i) = u(m);
	end
end

phaseLabel = Sess.Phase;

if Mode == "Timeline"
	isTransition = (Sess.DateTime > dtTransfer) & (Sess.DateTime < dtFinal);
else
	isTransition = false(height(Sess), 1);
end

% 可选：按 Mouse 过滤（vtf0442/vtf0451 等）
if Mode == "Timeline"
	phaseLabel(ismissing(phaseLabel) & isTransition) = "Inter";
end
if any(ismissing(phaseLabel) & ~isTransition)
	error('Unexpected <missing> Phase outside Transfer→Final transition range.');
end

QueryTable = table();
QueryTable.GroupName = phaseLabel + "_" + string(Sess.DateTime, 'yyyyMMdd_HHmm');
QueryTable.DateTime = Sess.DateTime;
QueryTable.Phase = Sess.Phase;
QueryTable.Stimulus = stimulus;

if ~isempty(cellUIDFilter)
	QueryTable.CellUID = repmat({cellUIDFilter}, height(QueryTable), 1);
end

groupNames = string(QueryTable.GroupName(:))';

% 列标题：在 GroupName 后追加刺激类型
stim = string(QueryTable.Stimulus(:))';
icon = strings(size(stim));
icon(contains(stim, "AudioWater")) = "🔊";
icon(contains(stim, "LightWater")) = "💡";

titleStrings = groupNames;
hasIcon = icon ~= "";
titleStrings(hasIcon) = titleStrings(hasIcon) + " " + icon(hasIcon);

idxLearned = find(string(QueryTable.Phase) == "Learned", 1, 'first');
if isempty(idxLearned)
	error('Cannot find a Learned session in the selected sessions.');
end
learnedGroupName = string(QueryTable.GroupName(idxLearned));

LearnedNtats = F.QueryNTATS(QueryTable(idxLearned, :), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

cellUIDAll = LearnedNtats.CellUID;
learnedData = LearnedNtats.NTATS{:,:, learnedGroupName};
learnedData = squeeze(learnedData);
if ~ismatrix(learnedData)
	error('Unexpected Learned NTATS dimension.');
end

% Mouse 过滤已通过 QueryTable.CellUID 在 QueryNTATS 内完成

nCells = numel(cellUIDAll);
nTime = size(learnedData, 2);
nSess = height(QueryTable);

keepSess = true(nSess, 1);

DataAll = nan(nCells, nTime, nSess);
DataAll(:, :, idxLearned) = learnedData;

for i = 1:nSess
	if i == idxLearned
		continue;
	end
	if ismissing(QueryTable.Stimulus(i))
		error('Missing Stimulus for session %s.', string(QueryTable.GroupName(i)));
	end

	Gi = [];
	for attempt = 1:3
		try
			Gi = F.QueryNTATS(QueryTable(i, :), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
			break;
		catch ME
			if ME.identifier == "UniExp:Exception:Empty_group"
				keepSess(i) = false;
				Gi = [];
				break;
			end
			if ME.identifier == "UniExp:Exception:NaN_appears_after_normalization" && ~isempty(cellUIDFilter)
				bad = iParseBadCellUID(ME);
				if isempty(bad)
					rethrow(ME);
				end
				cellUIDFilter = setdiff(cellUIDFilter, bad);
				QueryTable.CellUID = repmat({cellUIDFilter}, height(QueryTable), 1);
				continue;
			end
			rethrow(ME);
		end
	end
	if ~keepSess(i)
		continue;
	end
	if isempty(Gi) || height(Gi) == 0
		error('QueryNTATS returned empty for session %s.', string(QueryTable.GroupName(i)));
	end

	datai = Gi.NTATS{:,:, string(QueryTable.GroupName(i))};
	datai = squeeze(datai);
	if ~ismatrix(datai)
		error('Unexpected NTATS dimension for %s.', string(QueryTable.GroupName(i)));
	end

	[tf, loc] = ismember(Gi.CellUID, cellUIDAll);
	DataAll(loc(tf), :, i) = datai(tf, :);
end

% 丢弃 QueryNTATS 为空的会话列（避免后续 Group 查询再次抛 Empty_group）
if any(~keepSess)
	QueryTable = QueryTable(keepSess, :);
	DataAll = DataAll(:, :, keepSess);
	groupNames = string(QueryTable.GroupName(:))';
	stim = string(QueryTable.Stimulus(:))';
	icon = strings(size(stim));
	icon(contains(stim, "AudioWater")) = "🔊";
	icon(contains(stim, "LightWater")) = "💡";
	titleStrings = groupNames;
	hasIcon = icon ~= "";
	titleStrings(hasIcon) = titleStrings(hasIcon) + " " + icon(hasIcon);
	idxLearned = find(string(QueryTable.Phase) == "Learned", 1, 'first');
	if isempty(idxLearned)
		error('Cannot find a Learned session after filtering empty groups.');
	end
end

% 仅保留在所有会话中都有信号的细胞
% 仅保留在所有会话中都有信号的细胞
GroupNtatsRaw = [];
for attempt = 1:3
	try
		GroupNtatsRaw = F.QueryNTATS(QueryTable, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		break;
	catch ME
		if ME.identifier == "UniExp:Exception:Empty_group"
			rethrow(ME);
		end
		if ME.identifier == "UniExp:Exception:NaN_appears_after_normalization" && ~isempty(cellUIDFilter)
			bad = iParseBadCellUID(ME);
			if isempty(bad)
				rethrow(ME);
			end
			cellUIDFilter = setdiff(cellUIDFilter, bad);
			QueryTable.CellUID = repmat({cellUIDFilter}, height(QueryTable), 1);
			continue;
		end
		rethrow(ME);
	end
end

GroupNtatsRaw = GroupNtatsRaw(ismember(GroupNtatsRaw.CellUID, cellUIDAll), :);
GroupNtats = UniExp.NtatsCellStrip(GroupNtatsRaw);

keepCellUID = GroupNtats.CellUID;
[tfKeepCell, locKeepCell] = ismember(keepCellUID, cellUIDAll);
if ~all(tfKeepCell)
	missingN = nnz(~tfKeepCell);
	error('Some stripped CellUID are missing from learned CellUID set (n=%d).', missingN);
end


function badUID = iParseBadCellUID(ME)
badUID = [];
tok = regexp(string(ME.message), "细胞UID：([0-9,]+)", "tokens", "once");
if isempty(tok)
	return;
end
parts = split(string(tok{1}), ",");
parts(parts == "") = [];
badUID = str2double(parts);
badUID = badUID(~isnan(badUID));
badUID = badUID(:);
end

cellUIDAll = cellUIDAll(locKeepCell);
DataAll = DataAll(locKeepCell, :, :);

% 按细胞类型/层分组
[tfCell, locCell] = ismember(cellUIDAll, F.Cells.CellUID);
if ~all(tfCell)
	missingN = nnz(~tfCell);
	error('Some CellUID are missing from F.Cells (n=%d).', missingN);
end

cellTypeAll = string(F.Cells.CellType(locCell));
zLayerAll = string(F.Cells.ZLayer(locCell));

maskHm4d = (cellTypeAll == "hM4D(Gi)");
maskOther = (cellTypeAll == "Others");
maskMOp23 = (zLayerAll == "MOp2/3");
maskMOp5 = (zLayerAll == "MOp5");

uid_Hm4d_MOp23 = cellUIDAll(maskHm4d & maskMOp23);
uid_Hm4d_MOp5  = cellUIDAll(maskHm4d & maskMOp5);
uid_Other_MOp23 = cellUIDAll(maskOther & maskMOp23);
uid_Other_MOp5  = cellUIDAll(maskOther & maskMOp5);

Data_Hm4d_MOp23 = iDataSortedByLearned(LearnedNtats, learnedGroupName, uid_Hm4d_MOp23, cellUIDAll, DataAll);
Data_Hm4d_MOp5  = iDataSortedByLearned(LearnedNtats, learnedGroupName, uid_Hm4d_MOp5,  cellUIDAll, DataAll);
Data_Other_MOp23 = iDataSortedByLearned(LearnedNtats, learnedGroupName, uid_Other_MOp23, cellUIDAll, DataAll);
Data_Other_MOp5  = iDataSortedByLearned(LearnedNtats, learnedGroupName, uid_Other_MOp5,  cellUIDAll, DataAll);

% CLim（带符号平方根变换）
allData = cat(1, Data_Hm4d_MOp23, Data_Hm4d_MOp5, Data_Other_MOp23, Data_Other_MOp5);
oldNeg = min(allData, [], 'all', 'omitnan');
oldPos = max(allData, [], 'all', 'omitnan');
sqrtCLim = [ -sqrt(abs(oldNeg)), sqrt(abs(oldPos)) ];

Fig = figure;
Layout = tiledlayout(4, numel(groupNames), TileSpacing='compact', Padding='tight');

CommonFlags = [UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap];

Axes_Hm4d_MOp23 = iLanearHeatmapAxes(Layout, Data_Hm4d_MOp23, CommonFlags, sqrtCLim);
Axes_Hm4d_MOp5  = iLanearHeatmapAxes(Layout, Data_Hm4d_MOp5,  CommonFlags, sqrtCLim);
Axes_Other_MOp23 = iLanearHeatmapAxes(Layout, Data_Other_MOp23, CommonFlags, sqrtCLim);
Axes_Other_MOp5  = iLanearHeatmapAxes(Layout, Data_Other_MOp5,  CommonFlags, sqrtCLim);

AxesAll = [Axes_Hm4d_MOp23(:); Axes_Hm4d_MOp5(:); Axes_Other_MOp23(:); Axes_Other_MOp5(:)];
AxesAll = AxesAll(isgraphics(AxesAll));

for k = 1:numel(AxesAll)
	try
		axtoolbar(AxesAll(k), 'Visible', 'off');
	catch
	end
end

AxesRows = {Axes_Hm4d_MOp23, Axes_Hm4d_MOp5, Axes_Other_MOp23, Axes_Other_MOp5};
for r = 1:numel(AxesRows)
	axRow = AxesRows{r};
	for k = 1:numel(axRow)
		if r == 1 && k <= numel(groupNames)
			title(axRow(k), titleStrings(k), Interpreter='none', FontSize=8);
		end
		xline(axRow(k), 0, ':k');
		xline(axRow(k), 1, '-k');
	end
end

Axes_Hm4d_MOp23(1).YAxis.Visible = 'on';
Axes_Hm4d_MOp5(1).YAxis.Visible = 'on';
Axes_Other_MOp23(1).YAxis.Visible = 'on';
Axes_Other_MOp5(1).YAxis.Visible = 'on';

ylabel(Axes_Hm4d_MOp23(1), sprintf('hM4D(Gi) MOp2/3 (%u)', size(Data_Hm4d_MOp23,1)));
ylabel(Axes_Hm4d_MOp5(1),  sprintf('hM4D(Gi) MOp5 (%u)',  size(Data_Hm4d_MOp5,1)), FontSize=10);
ylabel(Axes_Other_MOp23(1), sprintf('Others MOp2/3 (%u)', size(Data_Other_MOp23,1)), FontSize=10);
ylabel(Axes_Other_MOp5(1),  sprintf('Others MOp5 (%u)',  size(Data_Other_MOp5,1)), FontSize=10);

Axes_Hm4d_MOp23(1).YLabel.FontSize = 10;

xlabel(Layout, 'Time(s) from cue(:) water(|)');

CB = colorbar;
CB.Layout.Tile = 'east';
CB.Label.String = 'z-score';

try
	MATLAB.Graphics.FigureAspectRatio(max(2, numel(groupNames)), 4, MATLAB.Flags.Amplify);
catch
end

end


function DataSorted = iDataSortedByLearned(LearnedNtats, learnedGroupName, uidSubset, cellUIDAll, DataAll)
uidSubset = uidSubset(:);
if isempty(uidSubset)
	DataSorted = zeros(0, size(DataAll, 2), size(DataAll, 3));
	return;
end

sub = LearnedNtats(ismember(LearnedNtats.CellUID, uidSubset), :);
if isempty(sub)
	DataSorted = zeros(0, size(DataAll, 2), size(DataAll, 3));
	return;
end

sorted = UniExp.HeatmapSort(sub, learnedGroupName);
[tf, loc] = ismember(sorted.CellUID, cellUIDAll);
loc = loc(tf);
DataSorted = DataAll(loc, :, :);
end


function Ax = iLanearHeatmapAxes(Layout, Data, CommonFlags, sqrtCLim)
[~, Ax] = UniExp.LanearHeatmap( ...
	Data, ...
	XData=seconds([-3,3]), ...
	Flags=CommonFlags, ...
	CLim=sqrtCLim, ...
	Layout=Layout ...
);

Ax = Ax(isgraphics(Ax));
if ~isempty(Ax)
	tiles = arrayfun(@(a)a.Layout.Tile, Ax);
	[~, idx] = sort(tiles);
	Ax = Ax(idx);
end
end
