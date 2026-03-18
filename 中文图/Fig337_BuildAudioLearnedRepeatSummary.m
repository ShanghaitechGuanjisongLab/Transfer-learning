function Data = Fig337_BuildAudioLearnedRepeatSummary()
if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

xMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(xMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Cannot find sample close to 1 s.');
end

sessionSummary = iBuildAudioSessionSummary(DS);
mice = unique(sessionSummary.Mouse, 'stable');
entries = repmat(iEmptyEntry(), 0, 1);

for iMouse = 1:numel(mice)
	mouseId = mice(iMouse);
	Sm = sessionSummary(sessionSummary.Mouse == mouseId, :);
	idx100 = find(isfinite(Sm.Performance) & (double(Sm.Performance) >= 1 - 1e-12), 1, 'first');
	if isempty(idx100) || height(Sm) < idx100 + 3
		continue;
	end
	pickIdx = [1, idx100, idx100 + 2, idx100 + 3];
	Spick = Sm(pickIdx, :);
	[X, commonUID] = iQueryCommonNtatsForSessions(DS, mouseId, Spick.DateTime);
	if isempty(X) || isempty(commonUID)
		continue;
	end
	vals1s = squeeze(X(:, idx1s, :));
	if isvector(vals1s)
		vals1s = reshape(vals1s, size(X, 1), size(X, 3));
	end
	baseMu = mean(X(:, baseMask, :), 2, 'omitnan');
	baseSd = std(X(:, baseMask, :), 0, 2, 'omitnan');
	baseMu = squeeze(baseMu);
	baseSd = squeeze(baseSd);
	if isvector(baseMu)
		baseMu = reshape(baseMu, size(X, 1), size(X, 3));
		baseSd = reshape(baseSd, size(X, 1), size(X, 3));
	end
	activeByLane = isfinite(vals1s) & isfinite(baseMu) & isfinite(baseSd) & (vals1s > (baseMu + 3 * baseSd));
	activeMask = any(activeByLane, 2);
	if ~any(activeMask)
		continue;
	end
	sortKey = max(vals1s(activeMask, :), [], 2, 'omitnan');
	sortKey(~isfinite(sortKey)) = -inf;
	[~, sortIdx] = sort(sortKey, 'descend');

	entry = iEmptyEntry();
	entry.Mouse = mouseId;
	entry.SessionTable = Spick;
	entry.CellUID = commonUID;
	entry.NTATS = X;
	entry.ActiveMask = activeMask;
	entry.ActiveCellUID = commonUID(activeMask);
	entry.SortIdx = sortIdx;
	entry.ActiveSortedNTATS = X(activeMask, :, :);
	entry.ActiveSortedNTATS = entry.ActiveSortedNTATS(sortIdx, :, :);
	entries(end + 1) = entry; %#ok<AGROW>
end

if isempty(entries)
	error('No AudioLightBaseline mice have all four required AudioWater NTATS sessions.');
end

laneParts = cell(numel(entries), 1);
superParts = cell(numel(entries), 1);
for iEntry = 1:numel(entries)
	laneParts{iEntry} = entries(iEntry).ActiveSortedNTATS;
	vals = squeeze(entries(iEntry).ActiveSortedNTATS(:, idx1s, :));
	if isvector(vals)
		vals = reshape(vals, size(entries(iEntry).ActiveSortedNTATS, 1), size(entries(iEntry).ActiveSortedNTATS, 3));
	end
	superParts{iEntry} = vals';
end

laneData = cat(1, laneParts{:});
superMouseSessionByCell = cat(2, superParts{:});
[points, explained] = iSessionPointsFromMatrix(superMouseSessionByCell);

Data = struct();
Data.MouseEntries = entries;
Data.SessionLabels = ["Naive", "100%", "24h", "36h"];
Data.XsSec = xsSec;
Data.XMask = xMask;
Data.XsPlot = xsPlot;
Data.BaseMask = baseMask;
Data.Index1s = idx1s;
Data.LaneData = laneData;
Data.SuperMouseSessionByCell = superMouseSessionByCell;
Data.Points = points;
Data.Explained = explained;
Data.SessionSummary = sessionSummary;
Data.SelectedMice = string({entries.Mouse})';
end

function S = iBuildAudioSessionSummary(DS)
B = DS.Blocks(:, {'DateTime', 'Performance', 'Design', 'BlockIndex'});
D = DS.DateTimes(:, {'Mouse', 'DateTime', 'Phase'});
T = outerjoin(B, D, 'Keys', 'DateTime', 'MergeKeys', true);
T = sortrows(T, {'Mouse', 'DateTime', 'BlockIndex'});
T.Mouse = string(T.Mouse);
T.Design = string(T.Design);
T.Phase = string(T.Phase);
T = T(T.Design == "AudioWater", :);

[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
phaseCell = splitapply(@(x) {iPickSessionPhase(x)}, T.Phase, G);
phaseVals = string(vertcat(phaseCell{:}));

S = table(mouseKeys, dtKeys, perf, phaseVals, 'VariableNames', {'Mouse', 'DateTime', 'Performance', 'Phase'});
S = sortrows(S, {'Mouse', 'DateTime'});
end

function phase = iPickSessionPhase(ph)
ph = string(ph);
ph = ph(~ismissing(ph) & ph ~= "");
if isempty(ph)
	phase = "missing";
else
	phase = ph(end);
end
end

function [X, commonUID] = iQueryCommonNtatsForSessions(DS, mouseId, dateTimes)
nSess = numel(dateTimes);
parts = cell(nSess, 1);
for iSess = 1:nSess
	q = struct('Mouse', string(mouseId), 'DateTime', dateTimes(iSess), 'Stimulus', 'AudioWater');
	try
		g = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch ME
		if ME.identifier == "UniExp:Exception:Empty_group"
			X = [];
			commonUID = uint64([]);
			return;
		end
		rethrow(ME);
	end
	parts{iSess} = iNtatsResultToTable(g);
	if isempty(parts{iSess})
		X = [];
		commonUID = uint64([]);
		return;
	end
	end

commonUID = uint64(parts{1}.CellUID);
for iSess = 2:nSess
	commonUID = intersect(commonUID, uint64(parts{iSess}.CellUID), 'stable');
end
if isempty(commonUID)
	X = [];
	return;
end

X = nan(numel(commonUID), size(iNtatsTo2D(parts{1}.NTATS), 2), nSess);
for iSess = 1:nSess
	part = parts{iSess};
	[tf, loc] = ismember(commonUID, uint64(part.CellUID));
	if ~all(tf)
		X = [];
		commonUID = uint64([]);
		return;
	end
	partX = iNtatsTo2D(part.NTATS);
	X(:, :, iSess) = partX(loc, :);
	end
end

function T = iNtatsResultToTable(raw)
T = table();
S = UniExp.NtatsCellStrip(raw);
if isempty(S) || ~istable(S)
	return;
end
if ~all(ismember({'CellUID', 'NTATS'}, string(S.Properties.VariableNames)))
	return;
end
X = iNtatsTo3D(S.NTATS);
if isempty(X)
	return;
end
if ndims(X) == 2
	X = reshape(X, size(X, 1), size(X, 2), 1);
end
if size(X, 3) ~= 1
	return;
end
T = table(uint64(S.CellUID), MATLAB.DataTypes.NDTable(X), 'VariableNames', {'CellUID', 'NTATS'});
end

function X = iNtatsTo3D(nt)
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
	return;
end
if istable(nt) && ismember('NTATS', string(nt.Properties.VariableNames))
	X = iNtatsTo3D(nt.NTATS);
	return;
end
if isnumeric(nt)
	X = nt;
	return;
end
	error('Unsupported NTATS container type: %s', class(nt));
end

function X2 = iNtatsTo2D(nt)
X3 = iNtatsTo3D(nt);
if isempty(X3) || size(X3, 3) ~= 1
	error('Expected single-session NTATS.');
end
X2 = squeeze(X3(:, :, 1));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
if isempty(xsSec) || ~isvector(xsSec)
	idx = 1;
	ok = false;
	return;
end
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function [points, explained] = iSessionPointsFromMatrix(sessionByCell)
validCols = all(isfinite(sessionByCell), 1);
sessionByCell = sessionByCell(:, validCols);
if size(sessionByCell, 1) < 2 || size(sessionByCell, 2) < 1
	points = nan(size(sessionByCell, 1), 2);
	explained = [NaN NaN];
	return;
end
sessionByCell = sessionByCell - mean(sessionByCell, 1, 'omitnan');
[u, s, ~] = svd(sessionByCell, 'econ');
score = u * s;
latent = diag(s).^2;
if ~isempty(latent) && sum(latent) > 0
	explAll = latent ./ sum(latent) * 100;
else
	explAll = nan(size(latent));
end
points = zeros(size(sessionByCell, 1), 2);
points(:, 1:min(2, size(score, 2))) = score(:, 1:min(2, size(score, 2)));
explained = nan(1, 2);
explained(1:min(2, numel(explAll))) = explAll(1:min(2, numel(explAll)));
end

function entry = iEmptyEntry()
entry = struct( ...
	'Mouse', "", ...
	'SessionTable', table(), ...
	'CellUID', uint64([]), ...
	'NTATS', [], ...
	'ActiveMask', false(0, 1), ...
	'ActiveCellUID', uint64([]), ...
	'SortIdx', zeros(0, 1), ...
	'ActiveSortedNTATS', []);
end