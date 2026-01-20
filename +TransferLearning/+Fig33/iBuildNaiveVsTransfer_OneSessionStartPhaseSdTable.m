function T = iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable(targetSec)
% Build one-session-per-mouse (start-phase) table for Fig3.3e.
% Returns:
%   Mouse, DateTime, Group, Performance, IsMixedAudio,
%   StdCells{sec}_MOp23, StdCells{sec}_MOp5

sec = double(targetSec);
if ~(isfinite(sec) && sec > -10 && sec < 20)
	error('Fig33:iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable:BadTarget', 'Invalid targetSec=%g', sec);
end

xsSec = seconds(TransferLearning.Xs);
[dtMin, idx] = min(abs(xsSec - sec));
if isempty(idx) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig33:iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable:NoSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', sec);
end

secTag = iSecTag(sec);
sdVar23 = "StdCells" + secTag + "_MOp23";
sdVar5  = "StdCells" + secTag + "_MOp5";

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

badMiceLAI = iFindMiceWithAudioWaterInPhase(LAI, "Naive");

T = table();
T = [T; iOneStartSessionPerMouse(LAB, "Naive", "Naive", idx, sdVar23, sdVar5, strings(0,1))];
T = [T; iOneStartSessionPerMouse(LAI, "Naive", "Naive", idx, sdVar23, sdVar5, badMiceLAI)];
T = [T; iOneStartSessionPerMouse(ALB, "Transfer", "Transfer", idx, sdVar23, sdVar5, strings(0,1))];

T = sortrows(T, {'Group','Mouse','DateTime'});
end

%% --- helpers

function tag = iSecTag(sec)
s = sprintf('%.3g', sec);
s = strrep(s, '.', 'p');
s = regexprep(s, '[^0-9p\-]', '');
tag = string(s);
end

function out = iOneStartSessionPerMouse(DS, groupName, startPhase, idx, sdVar23, sdVar5, excludeMice)
excludeMice = string(excludeMice(:));
startPhase = string(startPhase);

TblkAll = iQueryAllBlocksWithLWPerf(DS);
if isempty(TblkAll)
	out = table();
	return;
end
TblkAll.Mouse = string(TblkAll.Mouse);
TblkAll.Phase = string(TblkAll.Phase);
TblkAll.DateTime = iNormalizeDateTime(TblkAll.DateTime);
if ~isempty(excludeMice)
	TblkAll = TblkAll(~ismember(TblkAll.Mouse, excludeMice), :);
end
if isempty(TblkAll)
	out = table();
	return;
end

TblkLW = TblkAll(TblkAll.HasLW, :);
if isempty(TblkLW)
	out = table();
	return;
end
TblkLW2 = table(TblkLW.Mouse, TblkLW.DateTime, TblkLW.LWPerf, ...
	'VariableNames', {'Mouse','DateTime','Performance'});
Sess = iSessionizeByDateTime(SessFromBlocks(TblkLW2));

mice = unique(TblkAll.Mouse);
rowsKeep = false(height(Sess), 1);
for mi = 1:numel(mice)
	m = mice(mi);
	blkM = TblkAll(TblkAll.Mouse == m, :);
	startDT = min(blkM.DateTime(blkM.Phase == startPhase));
	if isempty(startDT) || ismissing(startDT)
		continue;
	end
	r = find((Sess.Mouse == m) & (Sess.DateTime == startDT), 1, 'first');
	if isempty(r)
		continue;
	end
	rowsKeep(r) = true;
end
Sess = Sess(rowsKeep, :);
if isempty(Sess)
	out = table();
	return;
end

IsMixedAudio = false(height(Sess), 1);
for i = 1:height(Sess)
	m = string(Sess.Mouse(i));
	dt = Sess.DateTime(i);
	bu = uint64(TblkAll.BlockUID((TblkAll.Mouse == m) & (TblkAll.DateTime == dt)));
	IsMixedAudio(i) = iIsMixedAudioInSession(DS, bu);
end

std23 = nan(height(Sess), 1);
std5  = nan(height(Sess), 1);
for i = 1:height(Sess)
	m = string(Sess.Mouse(i));
	dt = Sess.DateTime(i);
	std23(i) = iStdCellsAt_Miss(DS, m, dt, idx, "MOp2/3");
	std5(i)  = iStdCellsAt_Miss(DS, m, dt, idx, "MOp5");
end

out = Sess;
out.Group = repmat(string(groupName), height(out), 1);
out.IsMixedAudio = IsMixedAudio;
out.(sdVar23) = std23;
out.(sdVar5)  = std5;
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
	error('Fig33:iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable:MissingTrials', 'DataSet %s has no Trials.', class(DS));
end
Tr = DS.Trials;
need = {'BlockUID','Stimulus','Behavior'};
if ~all(ismember(need, Tr.Properties.VariableNames))
	error('Fig33:iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable:TrialsMissingFields', 'Trials table for %s lacks required fields.', class(DS));
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
	error('Fig33:iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable:MissingTrials', 'DataSet %s has no Trials; cannot detect mixing.', class(DS));
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	error('Fig33:iBuildNaiveVsTransfer_OneSessionStartPhaseSdTable:TrialsMissingFields', 'Trials table for %s lacks Stimulus/BlockUID.', class(DS));
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
