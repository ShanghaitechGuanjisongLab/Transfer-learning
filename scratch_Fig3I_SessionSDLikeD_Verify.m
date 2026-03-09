% Verify Fig3I lower tile if using the same algorithm as Fig3D lower tile:
% response heterogeneity per session (one point = one session).

DS_Ctrl = TransferLearning.AudioLightBaseline();
DS_TH = TransferLearning.THInhibit();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[dMin, idx1s] = min(abs(xsSec(:) - 1));
if ~isfinite(dMin) || dMin > 0.25
	error('ScratchFig3I:No1s', 'Cannot find sample close to 1s.');
end

[SessC, sdC] = iCohortSessionSD(DS_Ctrl, idx1s, "Transfer", "Final");
[SessT, sdT] = iCohortSessionSD(DS_TH, idx1s, "Transfer", "Final");
pSD = iRanksumSafe(sdC, sdT);

fprintf('=== Fig3I lower tile with Fig3D session-level heterogeneity ===\n');
fprintf('Ctrl: %.4f ± %.4f (n=%d sessions)\n', mean(sdC), std(sdC)/sqrt(numel(sdC)), numel(sdC));
fprintf('TH:   %.4f ± %.4f (n=%d sessions)\n', mean(sdT), std(sdT)/sqrt(numel(sdT)), numel(sdT));
fprintf('ranksum p = %.6g\n', pSD);
fprintf('Ctrl mice = %d, TH mice = %d\n', numel(unique(string(SessC.Mouse))), numel(unique(string(SessT.Mouse))));

assignin('base', 'scratch_Fig3I_SessionSDLikeD_Ctrl', sdC);
assignin('base', 'scratch_Fig3I_SessionSDLikeD_TH', sdT);
assignin('base', 'scratch_Fig3I_SessionSDLikeD_p', pSD);

function [Sess, sdVec] = iCohortSessionSD(DS, idx1s, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
allUsedDTs = datetime.empty(0,1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2, continue; end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2, continue; end
	allUsedDTs = [allUsedDTs; R.DateTime]; %#ok<AGROW>
end

allUsedDTs = unique(allUsedDTs);
Sess = Sess(ismember(Sess.DateTime, allUsedDTs), :);
if isempty(allUsedDTs)
	sdVec = [];
	return;
end

ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', allUsedDTs), ...
	UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
if isempty(ntsCell) || isempty(ntsCell{1})
	sdVec = [];
	return;
end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, ~, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

uDTs = unique(dtU1);
sdVec = nan(numel(uDTs), 1);
for iDT = 1:numel(uDTs)
	vals = med1s(dtU1 == uDTs(iDT));
	vals = vals(isfinite(vals) & vals >= -1 & vals <= 1);
	if numel(vals) >= 3
		sdVec(iDT) = std(vals);
	end
end
sdVec = sdVec(isfinite(sdVec));
end

function p = iRanksumSafe(x, y)
p = NaN;
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if numel(x) >= 2 && numel(y) >= 2
	try, p = ranksum(x, y); catch, end
end
end

function Sess = iLightWaterSessions(DS)
blkCols = DS.Blocks.Properties.VariableNames;
hasMustWarn = ismember('MustWarn', blkCols);
if hasMustWarn
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW), return; end
blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	phDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(phDates) || isempty(endDates), continue; end
	startDT = min(phDates);
	endDT = max(endDates);
	if ismissing(startDT) || ismissing(endDT), continue; end
	rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
end
SessOut = SessOut(keep, :);
end

function dt = iNormDT(dt)
try
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end