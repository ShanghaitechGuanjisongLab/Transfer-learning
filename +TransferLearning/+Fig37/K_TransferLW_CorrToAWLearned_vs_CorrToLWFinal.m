% Fig37: Are two correlation metrics correlated (Transfer LightWater session-level)?
%
% Question:
%   For transfer paradigm (AudioLightBaseline), across transfer LightWater sessions
%   (100% cutoff applied by Fig37 builder), is
%     Corr( LW_session NTATS@t , AudioWater Learned NTATS@t )
%   correlated with
%     Corr( LW_session NTATS@t , LightWater Final NTATS@t ) ?
%
% Notes:
% - LW sessions are exactly the Included sessions from the Fig37 builder (pre-100%).
% - AudioWater learned session is picked as the last session whose Phase == "Learned"
%   for Stimulus=="AudioWater" (within the same dataset/mouse).
% - Correlations are computed across common cells (Pearson r) and then we correlate
%   these r values across sessions using Spearman.
%
% Execution:
%   TransferLearning.Fig37.K_TransferLW_CorrToAWLearned_vs_CorrToLWFinal

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
if ~exist('excludeFinalItself','var') || isempty(excludeFinalItself)
	excludeFinalItself = true;
end
if ~exist('onlyFirstLWPerMouse','var') || isempty(onlyFirstLWPerMouse)
	onlyFirstLWPerMouse = false;
end
if ~exist('exportCSV','var') || isempty(exportCSV)
	exportCSV = true;
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

% Time index
xsSec = seconds(TransferLearning.Xs);
[dtMin, idxT] = min(abs(xsSec - double(targetAtSec)));
if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig37TransferCorr:NoTargetSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(targetAtSec));
end
idxRef = [];
if isfinite(double(subtractAtSec))
	[dtMinRef, idxRef] = min(abs(xsSec - double(subtractAtSec)));
	if isempty(idxRef) || ~isfinite(dtMinRef) || dtMinRef > 0.25
		error('Fig37TransferCorr:NoRefSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(subtractAtSec));
	end
end

% Use builder to reuse EXACT session inclusion (pre-100% etc).
[~, dbg] = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
	'TargetAtSec', double(targetAtSec), 'SubtractAtSec', double(subtractAtSec), 'ExcludeZeroHit', false, 'ActualSignalMode', "PrevA");
if isempty(dbg) || ~isfield(dbg,'Sessions') || ~isfield(dbg,'CorrectSession')
	error('Fig37TransferCorr:NoDebug', 'Expected dbg.Sessions and dbg.CorrectSession from builder.');
end

% Focus on transfer dataset only
sourceName = "AudioLightBaseline";
stageName = "Transfer";
DS = TransferLearning.AudioLightBaseline();
if isempty(DS)
	error('Fig37TransferCorr:NoDataSet', 'AudioLightBaseline dataset is empty.');
end

% Cells table (z-layer mapping)
if ~isprop(DS,'Cells') || isempty(DS.Cells)
	error('Fig37TransferCorr:NoCells', 'Dataset has no Cells table.');
end
C = DS.Cells;
needC = {'Mouse','CellUID','ZLayer'};
if ~all(ismember(needC, C.Properties.VariableNames))
	error('Fig37TransferCorr:BadCells', 'Cells table missing required columns.');
end
C.Mouse = string(C.Mouse);
C.CellUID = uint64(C.CellUID);
C.ZLayer = string(C.ZLayer);

% Transfer LightWater included sessions and Final LightWater correct session (per mouse)
Sess = dbg.Sessions;
CorrSess = dbg.CorrectSession;
Ssub = Sess(Sess.Source == sourceName & Sess.Stage == stageName & Sess.Included == true & Sess.Excluded == false, :);
Csub = CorrSess(CorrSess.Source == sourceName & CorrSess.Stage == stageName, :);
if isempty(Ssub) || isempty(Csub)
	error('Fig37TransferCorr:NoSessions', 'No transfer LightWater sessions found in dbg tables.');
end

% Build AudioWater session index to find "Learned" session per mouse.
try
	TA = DS.TableQuery(["Mouse","DateTime","TrialUID","Phase"], Stimulus="AudioWater");
catch
	TA = [];
end
if isempty(TA)
	warning('Fig37TransferCorr:NoAudioWater', 'No AudioWater trials found.');
end
if ~isempty(TA)
	TA.Mouse = string(TA.Mouse);
	TA.DateTime = datetime(TA.DateTime);
	TA.DateTime.TimeZone = '';
	if ismember('Phase', TA.Properties.VariableNames)
		TA.Phase = string(TA.Phase);
	else
		TA.Phase = repmat("", height(TA), 1);
	end
	TA = sortrows(TA, {'Mouse','DateTime'});
end

BySess = table(string.empty(0,1), string.empty(0,1), ...
	NaT(0,1), NaT(0,1), NaT(0,1), ...
	string.empty(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','ZKey','DateTimeSessionLW','DateTimeAWLearned','DateTimeLWFinal', ...
	'PhaseLW','HitLW','NTrialsLW', ...
	'NCellsCommon_AW','CorrToAWLearned','FisherZ_ToAW', ...
	'NCellsCommon_LW','CorrToLWFinal','FisherZ_ToLW'});

if onlyFirstLWPerMouse
	unitTag = "first LW per mouse";
else
	unitTag = "all included LW sessions";
end
fprintf('--- Fig37: Transfer LW corr-to-AWLearned vs corr-to-LWFinal (t=%.3gs; %s) ---\n', double(targetAtSec), unitTag);

mice = unique(Csub.Mouse);
mice = mice(~ismissing(mice));
for m = mice(:)'
	m = string(m);
	rowFinal = Csub(Csub.Mouse == m, :);
	if isempty(rowFinal)
		continue;
	end
	dtLWFinal = rowFinal.DateTime(1);

	rowLW = Ssub(Ssub.Mouse == m, :);
	if isempty(rowLW)
		continue;
	end
	rowLW = sortrows(rowLW, {'DateTime'});
	if onlyFirstLWPerMouse
		rowLW = rowLW(1, :);
	end

	% Find AudioWater learned session dateTime
	dtAW = NaT;
	if ~isempty(TA)
		Ti = TA(TA.Mouse == m, :);
		if ~isempty(Ti)
			sessDT = unique(Ti.DateTime, 'stable');
			sessPhase = strings(numel(sessDT),1);
			for ii = 1:numel(sessDT)
				dt = sessDT(ii);
				ph = Ti.Phase(Ti.DateTime == dt);
				ph = ph(ph ~= "");
				if isempty(ph)
					sessPhase(ii) = "";
				else
					[uPh,~,ic] = unique(ph);
					counts = accumarray(ic, 1);
					[~,mx] = max(counts);
					sessPhase(ii) = uPh(mx);
				end
			end
			idxLearned = find(sessPhase == "Learned", 1, 'last');
			if ~isempty(idxLearned)
				dtAW = sessDT(idxLearned);
			end
		end
	end
	if isnat(dtAW)
		continue;
	end

	% Build cell list
	cellAll = unique(uint64(C.CellUID(C.Mouse == m)));
	if isempty(cellAll)
		continue;
	end
	Cm = C(C.Mouse == m, {'CellUID','ZLayer'});

	% Reference vectors
	[vFinal, uidFinal] = iSessionVals(DS, m, dtLWFinal, cellAll, idxT, idxRef, "LightWater");
	[vAW, uidAW] = iSessionVals(DS, m, dtAW, cellAll, idxT, idxRef, "AudioWater");
	if isempty(vFinal) || isempty(vAW)
		continue;
	end

	% Loop LW sessions
	for iSess = 1:height(rowLW)
		dtSess = rowLW.DateTime(iSess);
		if excludeFinalItself && ~isnat(dtLWFinal) && dtSess == dtLWFinal
			continue;
		end
		[vSess, uidSess] = iSessionVals(DS, m, dtSess, cellAll, idxT, idxRef, "LightWater");
		if isempty(vSess)
			continue;
		end

		phLW = "";
		hitLW = NaN;
		nTrialsLW = NaN;
		if ismember('Phase', rowLW.Properties.VariableNames)
			phLW = string(rowLW.Phase(iSess));
		end
		if ismember('Hit', rowLW.Properties.VariableNames)
			hitLW = double(rowLW.Hit(iSess));
		end
		if ismember('NTrials', rowLW.Properties.VariableNames)
			nTrialsLW = double(rowLW.NTrials(iSess));
		end

		for zKey = ["All","MOp23","MOp5"]
			if zKey == "All"
				uidA = uidSess; valA = vSess;
				uidB1 = uidAW; valB1 = vAW;
				uidB2 = uidFinal; valB2 = vFinal;
			else
				zkA = iCellZKey(Cm, uidSess);
				zkB1 = iCellZKey(Cm, uidAW);
				zkB2 = iCellZKey(Cm, uidFinal);
				maskA = (zkA == zKey);
				maskB1 = (zkB1 == zKey);
				maskB2 = (zkB2 == zKey);
				uidA = uidSess(maskA); valA = vSess(maskA);
				uidB1 = uidAW(maskB1); valB1 = vAW(maskB1);
				uidB2 = uidFinal(maskB2); valB2 = vFinal(maskB2);
			end

			[r1, n1] = iPearsonOnCommon(uidA, valA, uidB1, valB1, double(minCommonCells));
			[r2, n2] = iPearsonOnCommon(uidA, valA, uidB2, valB2, double(minCommonCells));
			z1 = atanh(r1); if ~isfinite(r1), z1 = NaN; end
			z2 = atanh(r2); if ~isfinite(r2), z2 = NaN; end

			BySess = [BySess; table(m, string(zKey), dtSess, dtAW, dtLWFinal, string(phLW), double(hitLW), double(nTrialsLW), ...
				double(n1), double(r1), double(z1), double(n2), double(r2), double(z2), ...
				'VariableNames', BySess.Properties.VariableNames)]; %#ok<AGROW>
		end
	end
end

% Correlate the two correlation metrics across sessions (or across mice if onlyFirstLWPerMouse)
Summary = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'ZKey','N','SpearmanRho_R','SpearmanP_R','SpearmanRho_Z'});
for zKey = ["All","MOp23","MOp5"]
	T = BySess(BySess.ZKey == zKey, :);
	x = double(T.CorrToAWLearned);
	y = double(T.CorrToLWFinal);
	use = isfinite(x) & isfinite(y);
	n = nnz(use);
	rho = NaN; p = NaN; rhoZ = NaN;
	if n >= 5
		try
			[rho, p] = corr(x(use), y(use), 'Type','Spearman');
		catch
		end
		try
			rhoZ = corr(double(T.FisherZ_ToAW(use)), double(T.FisherZ_ToLW(use)), 'Type','Spearman');
		catch
		end
	end
	Summary = [Summary; table(string(zKey), double(n), double(rho), double(p), double(rhoZ), 'VariableNames', Summary.Properties.VariableNames)]; %#ok<AGROW>
end

assignin('base','Fig37_TransferLW_CorrToAWLearned_vs_CorrToLWFinal_BySession', BySess);
assignin('base','Fig37_TransferLW_CorrToAWLearned_vs_CorrToLWFinal_Summary', Summary);

if onlyFirstLWPerMouse
	disp('--- Spearman correlation between the two metrics (across mice; first LW per mouse) ---');
else
	disp('--- Spearman correlation between the two metrics (across sessions) ---');
end
disp(Summary);

% Export
if exportCSV
	outDir = iSelectOutDir(outDirUNC);
	suffix = "";
	if onlyFirstLWPerMouse
		suffix = "_FirstLWPerMouse";
	end
	fn1 = iFileName("Fig37_TransferLW_CorrToAWLearned_vs_CorrToLWFinal_BySession" + suffix + ".csv", double(targetAtSec), double(subtractAtSec));
	fn2 = iFileName("Fig37_TransferLW_CorrToAWLearned_vs_CorrToLWFinal_Summary" + suffix + ".csv", double(targetAtSec), double(subtractAtSec));

	p1 = iWriteTableWithRetry(BySess, outDir, fn1);
	fprintf('Wrote: %s\n', p1);
	p2 = iWriteTableWithRetry(Summary, outDir, fn2);
	fprintf('Wrote: %s\n', p2);
end

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

function [val, uid] = iSessionVals(DS, mouseName, dt, cellAll, idxT, idxRef, stimulusName)
	val = [];
	uid = uint64([]);
	try
		T = DS.TableQuery("TrialUID", Mouse=string(mouseName), Stimulus=string(stimulusName), DateTime=dt);
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
			error('Fig37TransferCorr:OutDirMissing', 'Output dir does not exist and cannot be created: %s', outDir);
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
	error('Fig37TransferCorr:WriteFailed', 'Failed to write CSV in directory: %s', outDir);
end
