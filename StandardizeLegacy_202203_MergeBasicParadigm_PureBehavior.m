% Standardize legacy (202203) pure-behavior logs into a single UniExp.DataSet
% Source (legacy format):
%   \\Data-Server-2\个人数据\张天夫\202203\原始数据\合并迁移-基本范式
%
% Output (standard UniExp.DataSet .mat with variable name `DataSet`):
%   \\Data-Server-2\个人数据\张天夫\202601\标准化数据库\合并迁移-基本范式 纯行为 vtf0004-vtf0005.v2.mat
%
% Requirements implemented:
% - Mouse rename: 0004->vtf0004, 0005->vtf0005
% - BlueWater == LightWater (Stimulus/Design renamed)
% - Information -> DataSet.DateTimes.Metadata (stored as-is)
% - Merge both mice into a single standard UniExp.DataSet (DateTimes/Blocks/Trials)
% - Phase policy:
%   - Only the first session per mouse x stimulus has Phase = Naive (LightWater) / Transfer (AudioWater)
%   - Only the last  session per mouse x stimulus has Phase = Learned (LightWater) / Final    (AudioWater)
%   - All intermediate sessions have Phase undefined
% - Add repeat indices via UniExp.DataSet.AddRepeatIndex (BlockRI / TrialRI)

oldRoot = "\\Data-Server-2\个人数据\张天夫\202203\原始数据\合并迁移-基本范式";
outDir  = "\\Data-Server-2\个人数据\张天夫\202601\标准化数据库";
outFile = fullfile(outDir, "合并迁移-基本范式 纯行为 vtf0004-vtf0005.v2.mat");

if ~exist('UniExp.DataSet','class')
	error('Legacy202203:MissingUniExp', 'UniExp.DataSet is not on the MATLAB path.');
end

if ~isfolder(oldRoot)
	error('Legacy202203:MissingInput', 'Input folder not found: %s', oldRoot);
end

if ~isfolder(outDir)
	mkdir(outDir);
end

files = dir(fullfile(oldRoot, '*.mat'));
if isempty(files)
	error('Legacy202203:NoFiles', 'No .mat files found in: %s', oldRoot);
end

% Collect session records first so we can sort by time and assign stable UIDs
records = repmat(struct('path', "", 'mouseOld', "", 'mouseNew', "", 'dt', NaT, 'stimulus', ""), 0, 1);
rIdx = 0;
for k = 1:numel(files)
	name = string(files(k).name);
	m = regexp(char(name), '^(?<mouse>\d{4})\.(?<dt>\d{12})\.(?<stim>BlueWater|AudioWater)\.mat$', 'names');
	if isempty(m)
		continue;
	end

	mouseOld = string(m.mouse);
	if mouseOld ~= "0004" && mouseOld ~= "0005"
		continue;
	end
	mouseNew = "vtf" + mouseOld;

	dt = datetime(m.dt, 'InputFormat', 'yyyyMMddHHmm');
	dt.TimeZone = '';

	stimLegacy = string(m.stim);
	if stimLegacy == "BlueWater"
		stimulus = "LightWater";
	else
		stimulus = "AudioWater";
	end

	rIdx = rIdx + 1;
	records(rIdx, 1) = struct( ...
		'path', fullfile(files(k).folder, files(k).name), ...
		'mouseOld', mouseOld, ...
		'mouseNew', mouseNew, ...
		'dt', dt, ...
		'stimulus', stimulus);
end

if isempty(records)
	error('Legacy202203:NoMatchingFiles', 'No matching legacy files for mice 0004/0005 found in: %s', oldRoot);
end

% Sort by datetime, then mouse
dtAll = [records.dt].';
mouseAll = string({records.mouseNew}).';
[~, order] = sortrows(table(dtAll, mouseAll), {'dtAll','mouseAll'});
records = records(order);

phaseCats = {'Naive','Learned','Transfer','Final'};
stimCats  = {'AudioWater','LightWater'};

% Phase policy: mark only first/last session per mouse x stimulus
phaseStr = strings(nBlocks, 1);
allMice = unique(string({records.mouseNew}));
for mi = 1:numel(allMice)
	mouseThis = allMice(mi);
	for stim = string(stimCats)
		idx = find(string({records.mouseNew}) == mouseThis & string({records.stimulus}) == stim);
		if isempty(idx)
			continue;
		end
		if stim == "LightWater"
			phaseStr(idx(1)) = "Naive";
			if numel(idx) > 1
				phaseStr(idx(end)) = "Learned";
			end
		else
			phaseStr(idx(1)) = "Transfer";
			if numel(idx) > 1
				phaseStr(idx(end)) = "Final";
			end
		end
	end
end

% Preallocate row containers
nBlocks = numel(records);
DateTime = NaT(nBlocks, 1);
Mouse    = strings(nBlocks, 1);
Phase    = categorical(strings(nBlocks,1), phaseCats);
Metadata = cell(nBlocks, 1);

BlockIndex = uint8(ones(nBlocks, 1));
BlockUID   = uint16((1:nBlocks).');
BDateTime  = NaT(nBlocks, 1);
Design     = categorical(strings(nBlocks,1), stimCats);
EventLog   = cell(nBlocks, 1);
Performance = nan(nBlocks, 1);

% Trials will be concatenated
trialRows = cell(nBlocks, 1);
trialUidCounter = uint16(0);

for b = 1:nBlocks
	r = records(b);
	S = load(r.path);

	if ~isfield(S, 'Information') || ~isfield(S, 'TimeTable')
		error('Legacy202203:BadFile', 'Missing Information/TimeTable in %s', r.path);
	end
	info = S.Information;
	TT = S.TimeTable;
	if ~istimetable(TT)
		error('Legacy202203:BadFile', 'TimeTable is not a timetable in %s', r.path);
	end

	% Convert legacy timetable variable name Tag -> Event to match standard dataset
	if ismember('Tag', TT.Properties.VariableNames)
		TT = renamevars(TT, 'Tag', 'Event');
	elseif ~ismember('Event', TT.Properties.VariableNames)
		% accept a single-column timetable and rename it
		if width(TT) == 1
			TT.Properties.VariableNames = {'Event'};
		else
			error('Legacy202203:BadEventLog', 'Unexpected TimeTable variables in %s', r.path);
		end
	end

	% Ensure Event is string/categorical-friendly
	TT.Event = string(TT.Event);

	% Determine per-trial outcomes from ordered Hit/Miss tags
	isHit  = (TT.Event == "命中");	% Hit
	isMiss = (TT.Event == "错失");	% Miss
	outcomeEvents = TT.Event(isHit | isMiss);
	behavior = double(outcomeEvents == "命中");

	nEach = iLegacyGetNoEachTrials(info);
	if numel(behavior) ~= nEach
		error('Legacy202203:TrialCountMismatch', 'Hit+Miss count (%d) != NoEachTrials (%d) in %s', numel(behavior), nEach, r.path);
	end

	perf = mean(behavior, 'omitnan');

	% DateTimes row
	DateTime(b) = r.dt;
	Mouse(b) = r.mouseNew;
	Phase(b) = categorical(phaseStr(b), phaseCats);
	Metadata{b} = info;

	% Blocks row
	BDateTime(b) = r.dt;
	Design(b) = categorical(r.stimulus, stimCats);
	EventLog{b} = TT;
	Performance(b) = perf;

	% Trials rows
	trialIndex = uint16((1:nEach).');
	blockUidThis = BlockUID(b);
	stimThis = categorical(repmat(r.stimulus, nEach, 1), stimCats);

	trialUid = trialUidCounter + uint16((1:nEach).');
	trialUidCounter = trialUid(end);

	trialRows{b} = table( ...
		behavior(:), repmat(blockUidThis, nEach, 1), stimThis, trialIndex, trialUid, ...
		'VariableNames', {'Behavior','BlockUID','Stimulus','TrialIndex','TrialUID'});
end

DT = table(DateTime, Metadata, Mouse, Phase, 'VariableNames', {'DateTime','Metadata','Mouse','Phase'});
B  = table(BlockIndex, BlockUID, BDateTime, Design, EventLog, Performance, ...
	'VariableNames', {'BlockIndex','BlockUID','DateTime','Design','EventLog','Performance'});
Tr = vertcat(trialRows{:});

% Normalize timezones for stability
DT.DateTime.TimeZone = '';
B.DateTime.TimeZone = '';

DataSet = UniExp.DataSet();
DataSet.DateTimes = DT;
DataSet.Blocks = B;
DataSet.Trials = Tr;

% Validate and save
DataSet.Validate();

DataSet.AddRepeatIndex;
DataSet.Validate();

save(outFile, 'DataSet');

% Quick sanity check: reload and run TableQuery
DS2 = UniExp.DataSet(outFile);
Tcheck = DS2.TableQuery(["Mouse","DateTime","BlockUID","TrialUID","Stimulus","Phase","Performance","Design"]);
assert(~isempty(Tcheck), 'Legacy202203:EmptyAfterSave', 'Saved dataset queries empty: %s', outFile);

fprintf('Wrote standard UniExp.DataSet: %s\n', outFile);
fprintf('Blocks: %d, Trials: %d, Mice: %s\n', height(DS2.Blocks), height(DS2.Trials), strjoin(unique(string(DS2.DateTimes.Mouse)), ', '));

function n = iLegacyGetNoEachTrials(info)
	if isstruct(info) && isfield(info, 'NoEachTrials')
		n = double(info.NoEachTrials);
		if isscalar(n) && isfinite(n) && n > 0
			return;
		end
	end
	error('Legacy202203:MissingNoEachTrials', 'Information.NoEachTrials missing/invalid.');
end
