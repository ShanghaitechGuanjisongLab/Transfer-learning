% Fig37: Compare first-session vs correct-session NTATS correlation (Initial vs Transfer)
%
% Question:
% - Is Corr(first LightWater session NTATS@t, learned LightWater NTATS@t) different from
%   Corr(first Transfer LightWater session NTATS@t, final LightWater NTATS@t)?
%
% Implementation notes:
% - Uses the same session pool rules as Fig37 builder (via its dbg tables).
% - Correlation is computed across common cells (Pearson), per mouse.
%
% Execution:
%   TransferLearning.Fig37.K_FirstVsCorrect_NTATSCorr_CompareInitialTransfer

% Allow overriding defaults from caller workspace (script semantics).
if ~exist('outDirUNC','var') || isempty(outDirUNC)
	outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
end
if ~exist('targetAtSec','var') || isempty(targetAtSec)
	targetAtSec = 1.5;
end
if ~exist('subtractAtSec','var') || isempty(subtractAtSec)
	subtractAtSec = NaN;
end
if ~exist('minCommonCells','var') || isempty(minCommonCells)
	minCommonCells = 5;
end
if ~exist('excludeCorrectSessionItself','var') || isempty(excludeCorrectSessionItself)
	excludeCorrectSessionItself = true;
end

% --- ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% Build dbg tables using the existing builder (keeps session inclusion rules consistent).
[pairs, dbg] = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
	'TargetAtSec', double(targetAtSec), 'SubtractAtSec', double(subtractAtSec), 'ExcludeZeroHit', false, 'ActualSignalMode', "PrevA");
% pairs is not used here; dbg is.
if isempty(dbg) || ~isfield(dbg,'Sessions') || ~isfield(dbg,'CorrectSession')
	error('Fig37FirstVsCorrect:NoDebug', 'Expected dbg.Sessions and dbg.CorrectSession from builder.');
end

xsSec = seconds(TransferLearning.Xs);
[dtMin, idxT] = min(abs(xsSec - double(targetAtSec)));
if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig37FirstVsCorrect:NoTargetSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(targetAtSec));
end
idxRef = [];
if isfinite(double(subtractAtSec))
	[dtMinRef, idxRef] = min(abs(xsSec - double(subtractAtSec)));
	if isempty(idxRef) || ~isfinite(dtMinRef) || dtMinRef > 0.25
		error('Fig37FirstVsCorrect:NoRefSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(subtractAtSec));
	end
end

% Spec matches builder (Initial sources and Transfer source).
spec = [ ...
	struct('Stage',"Initial",  'DataSet',@() TransferLearning.LightAudioBaseline(),  'Source',"LightAudioBaseline"), ...
	struct('Stage',"Initial",  'DataSet',@() TransferLearning.LAInterspersed(),     'Source',"LAInterspersed"), ...
	struct('Stage',"Transfer", 'DataSet',@() TransferLearning.AudioLightBaseline(), 'Source',"AudioLightBaseline") ...
];

R = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
	NaT(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','ZKey','DateTimeFirst','DateTimeCorrect','NCellsCommon','Corr','FisherZ'});

RSession = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
	NaT(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','ZKey','DateTimeSession','DateTimeCorrect','Phase','Hit','NTrials', ...
	'SessionOrdinal','NCellsCommon','Corr','FisherZ'});

fprintf('--- Fig37: First vs Correct NTATS corr (t=%.3gs) ---\n', double(targetAtSec));
fprintf('    Session-unit analysis: all Included sessions before 100%% cutoff.\n');

for iS = 1:numel(spec)
	S = spec(iS);
	try
		DS = S.DataSet();
	catch
		continue;
	end
	if isempty(DS)
		continue;
	end

	% Cells table for z-layer mapping.
	if ~isprop(DS, 'Cells')
		continue;
	end
	C = DS.Cells;
	needC = {'Mouse','CellUID','ZLayer'};
	if isempty(C) || ~all(ismember(needC, C.Properties.VariableNames))
		continue;
	end
	try
		C.Mouse = string(C.Mouse);
		C.CellUID = uint64(C.CellUID);
		C.ZLayer = string(C.ZLayer);
	catch
	end

	% Use builder debug tables to pick included sessions (before 100% cutoff) and correct session per mouse.
	Sess = dbg.Sessions;
	CorrSess = dbg.CorrectSession;
	maskSourceStage = (Sess.Source == string(S.Source)) & (Sess.Stage == string(S.Stage));
	maskCorrect = (CorrSess.Source == string(S.Source)) & (CorrSess.Stage == string(S.Stage));
	Ssub = Sess(maskSourceStage & Sess.Included == true & Sess.Excluded == false, :);
	Csub = CorrSess(maskCorrect, :);
	if isempty(Ssub) || isempty(Csub)
		continue;
	end

	mice = unique(Csub.Mouse);
	mice = mice(~ismissing(mice));
	for m = mice(:)'
		m = string(m);
		rowC = Csub(Csub.Mouse == m, :);
		if isempty(rowC)
			continue;
		end
		dtCorrect = rowC.DateTime(1);
		rowS = Ssub(Ssub.Mouse == m, :);
		if isempty(rowS)
			continue;
		end
		rowS = sortrows(rowS, {'DateTime'});
		dtFirst = rowS.DateTime(1);

		% Query per-cell NTATS for first and correct sessions.
		cellAll = unique(uint64(C.CellUID(C.Mouse == m)));
		if isempty(cellAll)
			continue;
		end
		Cm = C(C.Mouse == m, {'CellUID','ZLayer'});

		[vFirst, uidFirst] = iSessionVals(DS, m, dtFirst, cellAll, idxT, idxRef);
		[vCorrect, uidCorrect] = iSessionVals(DS, m, dtCorrect, cellAll, idxT, idxRef);
		if isempty(vFirst) || isempty(vCorrect)
			continue;
		end

		% Compute correlation for All, MOp23, MOp5.
		for zKey = ["All","MOp23","MOp5"]
			if zKey == "All"
				uidA = uidFirst; valA = vFirst;
				uidB = uidCorrect; valB = vCorrect;
			else
				zkA = iCellZKey(Cm, uidFirst);
				zkB = iCellZKey(Cm, uidCorrect);
				maskA = (zkA == zKey);
				maskB = (zkB == zKey);
				uidA = uidFirst(maskA); valA = vFirst(maskA);
				uidB = uidCorrect(maskB); valB = vCorrect(maskB);
			end
			[r, n] = iPearsonOnCommon(uidA, valA, uidB, valB, double(minCommonCells));
			z = atanh(r);
			if ~isfinite(r)
				z = NaN;
			end
			R = [R; table(string(S.Source), string(S.Stage), m, string(zKey), dtFirst, dtCorrect, double(n), double(r), double(z), ...
				'VariableNames', R.Properties.VariableNames)]; %#ok<AGROW>
		end

		% Session-unit: correlate every Included session (before 100% cutoff) with the correct session.
		% This answers: how similar is each training session to the "correct" training signal.
		for iSess = 1:height(rowS)
			dtSess = rowS.DateTime(iSess);
			if excludeCorrectSessionItself && ~isnat(dtCorrect) && dtSess == dtCorrect
				continue;
			end
			[vSess, uidSess] = iSessionVals(DS, m, dtSess, cellAll, idxT, idxRef);
			if isempty(vSess)
				continue;
			end
			ph = "";
			hit = NaN;
			nTrials = NaN;
			if ismember('Phase', rowS.Properties.VariableNames)
				ph = string(rowS.Phase(iSess));
			end
			if ismember('Hit', rowS.Properties.VariableNames)
				hit = double(rowS.Hit(iSess));
			end
			if ismember('NTrials', rowS.Properties.VariableNames)
				nTrials = double(rowS.NTrials(iSess));
			end
			for zKey = ["All","MOp23","MOp5"]
				if zKey == "All"
					uidA = uidSess; valA = vSess;
					uidB = uidCorrect; valB = vCorrect;
				else
					zkA = iCellZKey(Cm, uidSess);
					zkB = iCellZKey(Cm, uidCorrect);
					maskA = (zkA == zKey);
					maskB = (zkB == zKey);
					uidA = uidSess(maskA); valA = vSess(maskA);
					uidB = uidCorrect(maskB); valB = vCorrect(maskB);
				end
				[r, n] = iPearsonOnCommon(uidA, valA, uidB, valB, double(minCommonCells));
				z = atanh(r);
				if ~isfinite(r)
					z = NaN;
				end
				RSession = [RSession; table(string(S.Source), string(S.Stage), m, string(zKey), dtSess, dtCorrect, string(ph), double(hit), double(nTrials), ...
					double(iSess), double(n), double(r), double(z), 'VariableNames', RSession.Properties.VariableNames)]; %#ok<AGROW>
			end
		end
	end
end

% Compare Initial vs Transfer (unpaired) within each ZKey.
Stats = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'ZKey','NInitial','NTransfer','P_Ranksum_R','P_TTest_Z','DeltaMeanZ'});

for zKey = ["All","MOp23","MOp5"]
	A = R(R.ZKey == zKey & R.Stage == "Initial", :);
	B = R(R.ZKey == zKey & R.Stage == "Transfer", :);
	rA = double(A.Corr); rB = double(B.Corr);
	zA = double(A.FisherZ); zB = double(B.FisherZ);
	rA = rA(isfinite(rA)); rB = rB(isfinite(rB));
	zA = zA(isfinite(zA)); zB = zB(isfinite(zB));
	pRS = NaN; pT = NaN; dZ = NaN;
	if numel(rA) >= 3 && numel(rB) >= 3
		try
			pRS = ranksum(rA, rB);
		catch
		end
		try
			[~, pT] = ttest2(zA, zB);
		catch
		end
		dZ = mean(zB, 'omitnan') - mean(zA, 'omitnan');
	end
	Stats = [Stats; table(string(zKey), double(numel(rA)), double(numel(rB)), double(pRS), double(pT), double(dZ), ...
		'VariableNames', Stats.Properties.VariableNames)]; %#ok<AGROW>
end

assignin('base','Fig37_FirstVsCorrect_NTATSCorr_ByMouse', R);
assignin('base','Fig37_FirstVsCorrect_NTATSCorr_CompareStats', Stats);

% Session-unit outputs
StatsSession = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'ZKey','NInitial','NTransfer','P_Ranksum_R','P_TTest_Z','DeltaMeanZ'});
for zKey = ["All","MOp23","MOp5"]
	A = RSession(RSession.ZKey == zKey & RSession.Stage == "Initial", :);
	B = RSession(RSession.ZKey == zKey & RSession.Stage == "Transfer", :);
	rA = double(A.Corr); rB = double(B.Corr);
	zA = double(A.FisherZ); zB = double(B.FisherZ);
	rA = rA(isfinite(rA)); rB = rB(isfinite(rB));
	zA = zA(isfinite(zA)); zB = zB(isfinite(zB));
	pRS = NaN; pT = NaN; dZ = NaN;
	if numel(rA) >= 3 && numel(rB) >= 3
		try
			pRS = ranksum(rA, rB);
		catch
		end
		try
			[~, pT] = ttest2(zA, zB);
		catch
		end
		dZ = mean(zB, 'omitnan') - mean(zA, 'omitnan');
	end
	StatsSession = [StatsSession; table(string(zKey), double(numel(rA)), double(numel(rB)), double(pRS), double(pT), double(dZ), ...
		'VariableNames', StatsSession.Properties.VariableNames)]; %#ok<AGROW>
end
assignin('base','Fig37_FirstVsCorrect_NTATSCorr_BySession', RSession);
assignin('base','Fig37_FirstVsCorrect_NTATSCorr_CompareStats_SessionUnit', StatsSession);

outDir = iSelectOutDir(outDirUNC);

fnBase = "Fig37_FirstVsCorrect_NTATSCorr_ByMouse.csv";
fnStats = "Fig37_FirstVsCorrect_NTATSCorr_CompareStats.csv";
fnSess = "Fig37_FirstVsCorrect_NTATSCorr_BySession.csv";
fnSessStats = "Fig37_FirstVsCorrect_NTATSCorr_CompareStats_SessionUnit.csv";
fnBase = iFileName(fnBase, double(targetAtSec), double(subtractAtSec));
fnStats = iFileName(fnStats, double(targetAtSec), double(subtractAtSec));
fnSess = iFileName(fnSess, double(targetAtSec), double(subtractAtSec));
fnSessStats = iFileName(fnSessStats, double(targetAtSec), double(subtractAtSec));

p1 = iWriteTableWithRetry(R, outDir, fnBase);
fprintf('Wrote: %s\n', p1);
p2 = iWriteTableWithRetry(Stats, outDir, fnStats);
fprintf('Wrote: %s\n', p2);

p3 = iWriteTableWithRetry(RSession, outDir, fnSess);
fprintf('Wrote: %s\n', p3);
p4 = iWriteTableWithRetry(StatsSession, outDir, fnSessStats);
fprintf('Wrote: %s\n', p4);

fprintf('--- Comparison (Initial vs Transfer) ---\n');
disp(Stats);

fprintf('--- Comparison (Initial vs Transfer) [Session unit] ---\n');
disp(StatsSession);

%% --- local helpers

function [r, nCommon] = iPearsonOnCommon(uidA, valA, uidB, valB, minCommon)
	r = NaN;
	nCommon = 0;
	uidA = uint64(uidA(:)); valA = double(valA(:));
	uidB = uint64(uidB(:)); valB = double(valB(:));
	[tf, loc] = ismember(uidA, uidB);
	if ~any(tf)
		return;
	end
	x = valA(tf);
	y = valB(loc(tf));
	use = isfinite(x) & isfinite(y);
	nCommon = nnz(use);
	if nCommon < minCommon
		return;
	end
	try
		r = corr(x(use), y(use), 'Type','Pearson');
	catch
		r = NaN;
	end
end

function [val, uid] = iSessionVals(DS, mouseName, dt, cellAll, idxT, idxRef)
	val = [];
	uid = uint64([]);
	try
		T = DS.TableQuery("TrialUID", Mouse=string(mouseName), Stimulus="LightWater", DateTime=dt);
	catch
		T = [];
	end
	if isempty(T) || ~ismember('TrialUID', T.Properties.VariableNames)
		return;
	end
	try
		trialUID = unique(uint64(T.TrialUID));
	catch
		trialUID = uint64([]);
	end
	trialUID = trialUID(:);
	if isempty(trialUID)
		return;
	end
	try
		q = struct('CellUID', uint64(cellAll(:)), 'TrialUID', uint64(trialUID(:)));
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	X = G.NTATS;
	if isa(X, 'MATLAB.DataTypes.NDTable')
		X = X.Data;
	end
	try
		uid = uint64(G.CellUID);
		trace = double(X);
	catch
		uid = uint64([]);
		trace = [];
	end
	if isempty(uid) || isempty(trace)
		return;
	end
	needIdx = idxT;
	if ~isempty(idxRef)
		needIdx = max(needIdx, idxRef);
	end
	if size(trace,2) < needIdx
		val = [];
		uid = uint64([]);
		return;
	end
	if ~isempty(idxRef)
		trace = trace - trace(:, idxRef);
	end
	val = trace(:, idxT);
end

function zKey = iCellZKey(Cm, cellUID)
	zKey = repmat("Unknown", numel(cellUID), 1);
	try
		CZ = innerjoin(table(uint64(cellUID(:)), 'VariableNames', {'CellUID'}), Cm(:,{'CellUID','ZLayer'}), 'Keys', 'CellUID');
		[tf, loc] = ismember(uint64(cellUID(:)), uint64(CZ.CellUID));
		if any(tf)
			zKey(tf) = iZKey(string(CZ.ZLayer(loc(tf))));
		end
	catch
	end
end

function zKey = iZKey(zLayer)
	zl = string(zLayer);
	zKey = strings(size(zl));
	m23 = contains(zl, "2/3") | contains(zl, "2") & contains(zl, "3") | contains(zl, "23");
	m5  = contains(zl, "MOp5") | (contains(zl, "5") & ~m23);
	zKey(m23) = "MOp23";
	zKey(m5) = "MOp5";
	zKey(zKey == "") = "Other";
end

function outDir = iSelectOutDir(outDirUNC)
	outDir = outDirUNC;
	if ~isfolder(outDir)
		try
			mkdir(outDir);
		catch
			error('Fig37FirstVsCorrect:OutDirMissing', 'Output dir does not exist and cannot be created: %s', outDir);
		end
	end
end

function fn = iFileName(baseName, targetAtSec, subtractAtSec)
	suffix = strings(0,1);
	if isfinite(targetAtSec) && abs(targetAtSec - 1.5) > 1e-6
		if abs(targetAtSec - 1.0) < 1e-6
			suffix(end+1) = "At1s"; %#ok<AGROW>
		else
			suffix(end+1) = sprintf('At%gs', targetAtSec); %#ok<AGROW>
		end
	end
	if isfinite(subtractAtSec)
		if abs(subtractAtSec - 1.0) < 1e-6
			suffix(end+1) = "Minus1s"; %#ok<AGROW>
		else
			suffix(end+1) = sprintf('Minus%gs', subtractAtSec); %#ok<AGROW>
		end
	end
	if isempty(suffix)
		fn = baseName;
		return;
	end
	[stem, ext] = strtok(baseName, '.');
	if isempty(ext)
		ext = '.csv';
	end
	fn = sprintf('%s_%s%s', stem, strjoin(suffix, '_'), ext);
end

function outPath = iWriteTableWithRetry(T, outDir, fileName)
	basePath = fullfile(outDir, fileName);
	try
		writetable(T, basePath);
		outPath = basePath;
		return;
	catch
	end
	[stem, ext] = strtok(fileName, '.');
	if isempty(ext)
		ext = '.csv';
	end
	ts = datestr(now, 'yyyymmdd_HHMMSS');
	for k = 1:5
		altName = sprintf('%s_%s_%03d_%s%s', stem, ts, k, char(java.util.UUID.randomUUID()), ext);
		altPath = fullfile(outDir, altName);
		try
			writetable(T, altPath);
			outPath = altPath;
			return;
		catch
		end
	end
	error('Fig37FirstVsCorrect:WriteFailed', 'Failed to write CSV in directory: %s', outDir);
end
