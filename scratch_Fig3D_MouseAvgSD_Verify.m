% Verify Fig3D bottom panel under mouse-level avg-first heterogeneity.
%
% Rule:
% - Use the same session inclusion as formal Fig3D:
%   Naive = LAB + LAI, Naive->Learned, exclude AudioWater sessions,
%           exclude first 100% session and later, require >=2 sessions per mouse
%   Transfer = AudioLightBaseline, Transfer->Final, pure LW, exclude ceiling,
%              require >=2 sessions per mouse
% - For each mouse, compute response heterogeneity as:
%   per-cell per-session median z@1s -> per-cell mean across used sessions
%   -> filter to [-1,1] -> std across cells

DS_NaiveLAB = TransferLearning.LightAudioBaseline();
DS_NaiveLAI = TransferLearning.LAInterspersed();
DS_Transfer = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s, error('ScratchFig3DMouseAvg:No1s', 'Cannot find a sample close to 1s.'); end

[sdNaive, miceNaive] = iNaiveMouseAvgSD(DS_NaiveLAB, DS_NaiveLAI, idx1s);
[sdTransfer, miceTransfer] = iTransferMouseAvgSD(DS_Transfer, idx1s, "Transfer", "Final");

pMouse = iRanksumSafe(sdNaive, sdTransfer);

fprintf('=== Fig3D lower panel re-evaluation: mouse-level avg-first heterogeneity ===\n');
fprintf('Naive:    %.4f ± %.4f (n=%d mice)\n', mean(sdNaive), std(sdNaive)/sqrt(numel(sdNaive)), numel(sdNaive));
fprintf('Transfer: %.4f ± %.4f (n=%d mice)\n', mean(sdTransfer), std(sdTransfer)/sqrt(numel(sdTransfer)), numel(sdTransfer));
fprintf('ranksum p = %.6g\n', pMouse);
fprintf('Naive mice: %s\n', strjoin(cellstr(miceNaive), ', '));
fprintf('Transfer mice: %s\n', strjoin(cellstr(miceTransfer), ', '));

assignin('base', 'scratch_Fig3D_MouseAvgSD_Naive', sdNaive);
assignin('base', 'scratch_Fig3D_MouseAvgSD_Transfer', sdTransfer);
assignin('base', 'scratch_Fig3D_MouseAvgSD_p', pMouse);

function [sdVec, mice] = iTransferMouseAvgSD(DS, idx1s, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
Sess = sortrows(Sess, {'Mouse','DateTime'});
if isempty(Sess)
	 sdVec = [];
	 mice = string.empty(0,1);
	 return;
end

[SessUsed, mice] = iUsedTransferSessions(Sess);
[sdVec, mice] = iMouseAvgSD_SingleSource(DS, SessUsed, idx1s, mice);
end

function [SessUsed, mice] = iUsedTransferSessions(Sess)
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
	 m = miceAll(iM);
	 R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	 if height(R) < 2, continue; end
	 first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	 if ~isempty(first100) && first100 > 1
		 R = R(1:first100-1, :);
	 elseif ~isempty(first100) && first100 == 1
		 continue;
	 end
	 if height(R) < 2, continue; end
	 keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	 keepMice(iM) = true;
	end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function [sdVec, mice] = iNaiveMouseAvgSD(DS_LAB, DS_LAI, idx1s)
AllSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
AllSess = iExcludeAudioWaterSessions(AllSess, DS_LAB, DS_LAI);
AllSess = iExcludeCeilingNaive(AllSess);
AllSess = sortrows(AllSess, {'Mouse','DateTime'});

[SessUsed, mice] = iUsedNaiveSessions(AllSess);
[sdVec, mice] = iMouseAvgSD_MergedSources(DS_LAB, DS_LAI, SessUsed, idx1s, mice);
end

function [SessUsed, mice] = iUsedNaiveSessions(Sess)
if isempty(Sess)
	 SessUsed = Sess;
	 mice = string.empty(0,1);
	 return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});
miceAll = unique(string(Sess.Mouse));
keepRows = false(height(Sess), 1);
keepMice = false(numel(miceAll), 1);
for iM = 1:numel(miceAll)
	 m = miceAll(iM);
	 R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	 if height(R) < 2, continue; end
	 perf = double(R.Performance);
	 if any(~isfinite(perf)), continue; end
	 keepRows = keepRows | (string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime));
	 keepMice(iM) = true;
	end
SessUsed = Sess(keepRows, :);
mice = miceAll(keepMice);
end

function [sdVec, miceOut] = iMouseAvgSD_SingleSource(DS, SessUsed, idx1s, miceIn)
sdVec = [];
miceOut = string.empty(0,1);
if isempty(SessUsed) || isempty(miceIn), return; end

dts = unique(SessUsed.DateTime);
q = struct('Stimulus', 'LightWater', 'DateTime', dts);
try
	 ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
catch
	 return;
end
if isempty(ntsCell) || isempty(ntsCell{1}), return; end
rawTbl = ntsCell{1};
rawTbl.CellUID = uint64(rawTbl.CellUID);
rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, cellU1, dtU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

dtMouse = SessUsed(:, {'DateTime','Mouse'});
dtMouse.Mouse = string(dtMouse.Mouse);
[~, iU] = unique(dtMouse.DateTime);
dtMouse = dtMouse(iU, :);

medTbl = table(cellU1, dtU1, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
medTbl = innerjoin(medTbl, dtMouse, 'Keys', 'DateTime');

tmp = nan(numel(miceIn), 1);
for iM = 1:numel(miceIn)
	 m = miceIn(iM);
	 rows = medTbl(string(medTbl.Mouse) == m, :);
	 if isempty(rows), continue; end
	 [~, ~, cellID] = unique(rows.CellUID);
	 meanPerCell = accumarray(cellID, rows.Med1s, [], @mean);
	 vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
	 if numel(vals) >= 3
		 tmp(iM) = std(vals);
	 end
	end
keep = isfinite(tmp);
sdVec = tmp(keep);
miceOut = miceIn(keep);
end

function [sdVec, miceOut] = iMouseAvgSD_MergedSources(DS_LAB, DS_LAI, SessUsed, idx1s, miceIn)
sdVec = [];
miceOut = string.empty(0,1);
if isempty(SessUsed) || isempty(miceIn), return; end

rawParts = {};
for srcName = ["LAB"; "LAI"]'
	 dts = unique(SessUsed.DateTime(SessUsed.Source == srcName));
	 if isempty(dts), continue; end
	 if srcName == "LAB", DS = DS_LAB; else, DS = DS_LAI; end
	 try
		 ntsCell = DS.QueryNTS(struct('Stimulus', 'LightWater', 'DateTime', dts), ...
			 UniExp.Flags.ZScore, 1:24, 'ExtraColumns', ["DateTime"]);
	 catch
		 continue;
	 end
	 if isempty(ntsCell) || isempty(ntsCell{1}), continue; end
	 part = ntsCell{1};
	 part.CellUID = uint64(part.CellUID);
	 part.DateTime = iNormDT(datetime(part.DateTime));
	 part.Source = repmat(srcName, height(part), 1);
	 rawParts{end+1} = part; %#ok<AGROW>
	end
if isempty(rawParts), return; end

rawTbl = vertcat(rawParts{:});
sig = double(rawTbl.TrialSignal);
z1s = sig(:, idx1s);

[G1, cellU1, dtU1, srcU1] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G1);

mapTbl = SessUsed(:, {'DateTime','Source','Mouse'});
mapTbl.Source = string(mapTbl.Source);
mapTbl.Mouse = string(mapTbl.Mouse);
[~, iU] = unique(mapTbl(:, {'DateTime','Source'}), 'rows');
mapTbl = mapTbl(iU, :);

medTbl = table(cellU1, dtU1, srcU1, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
medTbl = innerjoin(medTbl, mapTbl, 'Keys', {'DateTime','Source'});

tmp = nan(numel(miceIn), 1);
for iM = 1:numel(miceIn)
	 m = miceIn(iM);
	 rows = medTbl(string(medTbl.Mouse) == m, :);
	 if isempty(rows), continue; end
	 keys = strcat(string(rows.Source), "__", string(rows.CellUID));
	 [~, ~, cellID] = unique(keys);
	 meanPerCell = accumarray(cellID, rows.Med1s, [], @mean);
	 vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
	 if numel(vals) >= 3
		 tmp(iM) = std(vals);
	 end
	end
keep = isfinite(tmp);
sdVec = tmp(keep);
miceOut = miceIn(keep);
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec(:) - tSec));
ok = isfinite(d) && (d <= tolSec);
end

function p = iRanksumSafe(x, y)
p = NaN;
x = double(x(:)); y = double(y(:));
x = x(isfinite(x)); y = y(isfinite(y));
if numel(x) >= 2 && numel(y) >= 2
	 try, p = ranksum(x, y); catch, end
end
end

function Sess = iLightWaterSessions(DS)
Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	 Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
		 'VariableNames',{'Mouse','DateTime','Phase','Performance'}); return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
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
TAW = innerjoin(table(blkAW,'VariableNames',{'BlockUID'}), Blocks, 'Keys','BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut), return; end
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
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

function AllSess = iGatherNaiveSessions(LAB, LAI)
AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Source'});
for iDS = 1:2
	 if iDS == 1
		 DS = LAB; srcName = "LAB";
	 else
		 DS = LAI; srcName = "LAI";
	 end
	 T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
	 T.Mouse = string(T.Mouse);
	 T.DateTime = iNormDT(datetime(T.DateTime));
	 T.Phase = string(T.Phase);
	 Tr = DS.Trials;
	 mice = unique(T.Mouse);
	 for iM = 1:numel(mice)
		 m = mice(iM);
		 Tm = T(T.Mouse == m, :);
		 phases = unique(Tm.Phase);
		 if ~any(phases == "Naive"), continue; end
		 hasLearned = any(phases == "Learned");
		 hasTransfer = any(phases == "Transfer");
		 sessDTs = sort(unique(Tm.DateTime));
		 sessPhase = strings(numel(sessDTs), 1);
		 for ii = 1:numel(sessDTs)
			 ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
			 ph = ph(ph ~= "" & ~ismissing(ph));
			 if isempty(ph)
				 sessPhase(ii) = "";
				 continue;
			 end
			 [uPh, ~, ic] = unique(ph);
			 counts = accumarray(ic, 1);
			 [~, mx] = max(counts);
			 sessPhase(ii) = uPh(mx);
		 end
		 idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
		 if hasLearned
			 idxEnd = find(sessPhase == "Learned", 1, 'last');
		 elseif hasTransfer
			 idxTransferStart = find(sessPhase == "Transfer", 1, 'first');
			 idxEnd = idxTransferStart - 1;
		 else
			 idxEnd = numel(sessDTs);
		 end
		 if isempty(idxNaiveStart) || idxEnd < idxNaiveStart, continue; end
		 for k = idxNaiveStart:idxEnd
			 dt = sessDTs(k);
			 blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
			 TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
			 if isempty(TrSess), continue; end
			 lwMask = string(TrSess.Stimulus) == "LightWater";
			 if ~any(lwMask), continue; end
			 perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
			 if ~isfinite(perf), continue; end
			 AllSess = [AllSess; table(m, dt, perf, srcName, ...
				 'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
		 end
	 end
end
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows');
AllSess = AllSess(ia, :);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
keep = true(height(AllSess), 1);
for i = 1:height(AllSess)
	 if AllSess.Source(i) == "LAB", DS = LAB; else, DS = LAI; end
	 if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
		 keep(i) = false;
	 end
end
AllSess = AllSess(keep, :);
end

function AllSess = iExcludeCeilingNaive(AllSess)
AllSess = sortrows(AllSess, {'Mouse','DateTime'});
remove = false(height(AllSess), 1);
for m = unique(AllSess.Mouse)'
	 rows = find(AllSess.Mouse == m);
	 p = double(AllSess.Performance(rows));
	 i100 = find(p >= 1 - 1e-12, 1, 'first');
	 if ~isempty(i100)
		 remove(rows(i100:end)) = true;
	 end
end
AllSess(remove, :) = [];
perf = double(AllSess.Performance);
AllSess = AllSess(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
tf = false;
Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames), return; end
st = unique(string(Tdt.Stimulus));
st = st(~ismissing(st));
tf = any(st == string(stim));
end

function dt = iNormDT(dt)
try if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end; catch; end
end