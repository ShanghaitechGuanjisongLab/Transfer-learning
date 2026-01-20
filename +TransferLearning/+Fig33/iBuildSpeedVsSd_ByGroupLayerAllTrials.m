function T = iBuildSpeedVsSd_ByGroupLayerAllTrials(targetSec)
% Build session-step table for Fig3.3c/d:
% inter-cell SD (by layer; all trials) vs forward-diff learning speed.
%
% Returns one-row-per-session-step table with:
%   Mouse, DateTime, Group, Performance, LearningSpeed_DeltaNext,
%   StdCells{sec}_MOp23, StdCells{sec}_MOp5
%
% Notes:
% - Performance is LightWater-only session performance computed from Trials.
% - SD uses QueryNTATS on LightWater without Behavior filtering (i.e., all trials).
% - Sessions with any AudioWater trials in the session are excluded.

sec = double(targetSec);
if ~(isfinite(sec) && sec > -10 && sec < 20)
	error('Fig33:iBuildSpeedVsSd_ByGroupLayerAllTrials:BadTarget', 'Invalid targetSec=%g', sec);
end

xsSec = seconds(TransferLearning.Xs);
[dtMin, idx] = min(abs(xsSec - sec));
if isempty(idx) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig33:iBuildSpeedVsSd_ByGroupLayerAllTrials:NoSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', sec);
end

secTag = iSecTag(sec);
sdVar23 = "StdCells" + secTag + "_MOp23";
sdVar5  = "StdCells" + secTag + "_MOp5";

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

badMiceLAI = iFindMiceWithAudioWaterInPhase(LAI, "Naive");

T = table();
T = [T; iBuildCohortSessions(LAB, "Naive", "Naive", "Learned", idx, sdVar23, sdVar5, strings(0,1))];
T = [T; iBuildCohortSessions(LAI, "Naive", "Naive", "Learned", idx, sdVar23, sdVar5, badMiceLAI)];
T = [T; iBuildCohortSessions(ALB, "Transfer", "Transfer", "Final", idx, sdVar23, sdVar5, strings(0,1))];

T = sortrows(T, {'Group','Mouse','DateTime'});

% One row per session step (forward diff)
T = iBuildDeltaNextPoints(T);

end

%% --- helpers

function tag = iSecTag(sec)
% 0.3 -> 0p3, 1.5 -> 1p5
s = sprintf('%.3g', sec);
s = strrep(s, '.', 'p');
s = regexprep(s, '[^0-9p\-]', '');
tag = string(s);
end

function Sess = iBuildCohortSessions(DS, groupName, startPhase, endPhase, idx, sdVar23, sdVar5, excludeMice)
excludeMice = string(excludeMice(:));
startPhase = string(startPhase);
endPhase = string(endPhase);

TblkAll = iQueryAllBlocksWithLWPerf(DS);
if isempty(TblkAll)
	Sess = table();
	return;
end

TblkAll.Mouse = string(TblkAll.Mouse);
TblkAll.Phase = string(TblkAll.Phase);
TblkAll.DateTime = iNormalizeDateTime(TblkAll.DateTime);
if ~isempty(excludeMice)
	TblkAll = TblkAll(~ismember(TblkAll.Mouse, excludeMice), :);
end
if isempty(TblkAll)
	Sess = table();
	return;
end

TblkLW = TblkAll(TblkAll.HasLW, :);
if isempty(TblkLW)
	Sess = table();
	return;
end
TblkLW2 = table(TblkLW.Mouse, TblkLW.DateTime, TblkLW.LWPerf, ...
	'VariableNames', {'Mouse','DateTime','Performance'});
SessPerf = iSessionizeByDateTime(SessFromBlocks(TblkLW2));

% Trajectory window per mouse
mice = unique(TblkAll.Mouse);
keepRows = false(height(SessPerf), 1);
for mi = 1:numel(mice)
	m = mice(mi);
	blkM = TblkAll(TblkAll.Mouse == m, :);
	startDT = min(blkM.DateTime(blkM.Phase == startPhase));
	endDT2 = max(blkM.DateTime(blkM.Phase == endPhase));
	if isempty(startDT) || isempty(endDT2) || any(ismissing([startDT endDT2]))
		continue;
	end
	if endDT2 < startDT
		continue;
	end
	rows = (SessPerf.Mouse == m) & (SessPerf.DateTime >= startDT) & (SessPerf.DateTime <= endDT2);
	keepRows = keepRows | rows;
end
SessPerf = SessPerf(keepRows, :);
if isempty(SessPerf)
	Sess = table();
	return;
end

% Exclude mixed sessions
mixed = false(height(SessPerf), 1);
for i = 1:height(SessPerf)
	m = string(SessPerf.Mouse(i));
	dt = SessPerf.DateTime(i);
	bu = uint64(TblkAll.BlockUID((TblkAll.Mouse == m) & (TblkAll.DateTime == dt)));
	mixed(i) = iIsMixedAudioInSession(DS, bu);
end
SessPerf = SessPerf(~mixed, :);
if isempty(SessPerf)
	Sess = table();
	return;
end

% Inter-cell SD by layer (all trials)
std23 = nan(height(SessPerf), 1);
std5  = nan(height(SessPerf), 1);
for i = 1:height(SessPerf)
	m = string(SessPerf.Mouse(i));
	dt = SessPerf.DateTime(i);
	std23(i) = iStdCellsAt_Miss(DS, m, dt, idx, "MOp2/3");
	std5(i)  = iStdCellsAt_Miss(DS, m, dt, idx, "MOp5");
end

Sess = SessPerf;
Sess.Group = repmat(string(groupName), height(Sess), 1);
Sess.(sdVar23) = std23;
Sess.(sdVar5)  = std5;

end

function T = SessFromBlocks(T)
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
end

function dt = iNormalizeDateTime(dt)
try
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end

function T = iSessionizeByDateTime(T)
T.DateTime = datetime(T.DateTime);
T.DateTime.TimeZone = '';
[G, mouse, dt] = findgroups(string(T.Mouse), T.DateTime);
perf = splitapply(@(x) mean(x,'omitnan'), double(T.Performance), G);
T = table(mouse, dt, perf, 'VariableNames', {'Mouse','DateTime','Performance'});
end

function Tblk = iQueryAllBlocksWithLWPerf(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
try
	Tblk = DS.TableQuery(vars);
catch
	Tblk = table();
	return;
end
if isempty(Tblk)
	Tblk = table();
	return;
end
if ~isprop(DS, 'Trials')
	error('Fig33:iBuildSpeedVsSd_ByGroupLayerAllTrials:MissingTrials', 'DataSet %s has no Trials.', class(DS));
end
Tr = DS.Trials;
need = {'BlockUID','Stimulus','Behavior'};
if ~all(ismember(need, Tr.Properties.VariableNames))
	error('Fig33:iBuildSpeedVsSd_ByGroupLayerAllTrials:TrialsMissingFields', 'Trials table for %s lacks required fields.', class(DS));
end
TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
Tblk.HasLW = false(height(Tblk), 1);
Tblk.LWPerf = nan(height(Tblk), 1);
if isempty(TrLW)
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});
blkUID64 = uint64(Tblk.BlockUID);
[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
Tblk.HasLW(tf) = true;
Tblk.LWPerf(tf) = perfByBlock.LWPerf(loc(tf));
end

function tf = iIsMixedAudioInSession(DS, blockUIDs)
try
	if isempty(blockUIDs)
		tf = true;
		return;
	end
	if ~isprop(DS, 'Trials')
		tf = true;
		return;
	end
	Tr = DS.Trials;
	if ~all(ismember({'Stimulus','BlockUID'}, Tr.Properties.VariableNames))
		tf = true;
		return;
	end
	stim = string(Tr.Stimulus);
	bu = uint64(Tr.BlockUID);
	rows = ismember(bu, uint64(blockUIDs));
	if ~any(rows)
		tf = true;
		return;
	end
	tf = any(stim(rows) == "AudioWater");
catch
	tf = true;
end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
try
	T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
catch
	badMice = strings(0,1);
	return;
end
if isempty(T)
	badMice = strings(0,1);
	return;
end
if ~isprop(DS, 'Trials')
	error('Fig33:iBuildSpeedVsSd_ByGroupLayerAllTrials:MissingTrials', 'DataSet %s has no Trials; cannot detect mixing.', class(DS));
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	error('Fig33:iBuildSpeedVsSd_ByGroupLayerAllTrials:TrialsMissingFields', 'Trials table for %s lacks Stimulus/BlockUID.', class(DS));
end
TrStim = string(Tr.Stimulus);
TrBU = uint64(Tr.BlockUID);
T.Mouse = string(T.Mouse);
blkBU = uint64(T.BlockUID);

mice = unique(T.Mouse);
bad = false(size(mice));
for i = 1:numel(mice)
	m = mice(i);
	bu = blkBU(T.Mouse == m);
	rows = ismember(TrBU, bu);
	if ~any(rows)
		bad(i) = false;
		continue;
	end
	st = TrStim(rows);
	bad(i) = any(st == "AudioWater") && any(st == "LightWater");
end
badMice = mice(bad);
end

function sd = iStdCellsAt_Miss(DS, mouse, dt, idx, zLayer)
% SD of Median(DeltaF) across cells at given time index, LightWater all trials.
sd = NaN;
try
	q = struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', 'LightWater');
	G = DS.QueryNTATS(q, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
	if isempty(G) || ~all(ismember(["NTATS","CellUID"], string(G.Properties.VariableNames)))
		return;
	end
	M = iNtatsData(G.NTATS);
	M = iFilterByZLayer(DS, G, M, string(zLayer));
	if isempty(M)
		return;
	end
	if idx < 1 || idx > size(M, 2)
		return;
	end
	v = double(M(:, idx));
	sd = std(v, 0, 1, 'omitnan');
catch
	sd = NaN;
end
end

function M = iNtatsData(N)
try
	if isa(N, 'MATLAB.DataTypes.NDTable')
		M = double(N{:, :});
	elseif isnumeric(N)
		M = double(N);
	else
		M = double(N{:, :});
	end
catch
	try
		M = cell2mat(N);
	catch
		M = [];
	end
end
end

function M = iFilterByZLayer(DS, G, M, zLayer)
try
	if isempty(M) || ~isprop(DS, 'Cells')
		return;
	end
	C = DS.Cells;
	need = ["CellUID","ZLayer"];
	if ~all(ismember(need, string(C.Properties.VariableNames)))
		return;
	end
	uids = uint64(G.CellUID);
	[tf, loc] = ismember(uids, uint64(C.CellUID));
	if ~any(tf)
		M(:,:) = [];
		return;
	end
	z = strings(numel(uids), 1);
	z(tf) = string(C.ZLayer(loc(tf)));
	keep = (z == string(zLayer));
	M = M(keep, :);
catch
end
end

function P = iBuildDeltaNextPoints(Sess)
% One row per session step (forward diff) with ceiling handling aligned to Fig3.3.
if isempty(Sess)
	P = table();	P.LearningSpeed_DeltaNext = nan(0,1);	return;
end
Sess.Mouse = string(Sess.Mouse);
Sess.Group = string(Sess.Group);
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});

zTol = 1e-12;
oneTol = 1 - 1e-12;

out = cell(numel(unique(Sess.Mouse)), 1);
mice = unique(Sess.Mouse);
for i = 1:numel(mice)
	m = mice(i);
	S = Sess(Sess.Mouse == m, :);
	S = sortrows(S, 'DateTime');
	perf = double(S.Performance);

	keep = isfinite(perf) & (perf > zTol);
	S = S(keep, :);
	perf = perf(keep);
	if height(S) < 2
		continue;
	end

	i100 = find(isfinite(perf) & (perf >= oneTol), 1, 'first');
	if ~isempty(i100)
		if i100 <= 2
			continue;
		end
		S = S(1:i100-2, :);
		perf = perf(1:i100-2);
	end
	if height(S) < 2
		continue;
	end

	d = diff(perf);
	P1 = S(1:end-1, :);
	P1.LearningSpeed_DeltaNext = d(:);
	out{i} = P1;
end

out = out(~cellfun('isempty', out));
if isempty(out)
	P = table();
	P.LearningSpeed_DeltaNext = nan(0,1);
else
	P = vertcat(out{:});
	P = P(isfinite(P.LearningSpeed_DeltaNext), :);
end
end
