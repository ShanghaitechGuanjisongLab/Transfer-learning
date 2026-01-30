% Fig37: Is Corr(AudioWater learned, LightWater final) increasing over time?
%
% Question:
% - For each mouse (one point per mouse), compute Pearson Corr across common cells
%   between:
%     AudioWater learned session NTATS@t
%   and
%     Transfer LightWater final (correct) session NTATS@t
%   at t = 0.5s, 1.0s, 1.5s.
% - Test whether the correlation shows a significant increasing trend with time.
%
% Notes:
% - Uses AudioLightBaseline dataset.
% - AudioWater learned session: last session whose Phase == "Learned" for Stimulus=="AudioWater".
% - LightWater final session: correct session from Fig37 builder (Transfer stage).
% - Correlation computed on common CellUID only.
%
% Execution:
%   TransferLearning.Fig37.K_AWLearned_vs_LWFinal_Corr_TrendOverTime

% Allow overriding defaults from caller workspace (script semantics).
if ~exist('outDirUNC','var') || isempty(outDirUNC)
	outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
end
if ~exist('timeSecList','var') || isempty(timeSecList)
	timeSecList = [0.5, 1.0, 1.5];
end
if ~exist('subtractAtSec','var') || isempty(subtractAtSec)
	subtractAtSec = NaN;
end
if ~exist('minCommonCells','var') || isempty(minCommonCells)
	minCommonCells = 5;
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

% Validate time list
if ~isvector(timeSecList) || isempty(timeSecList)
	error('Fig37Trend:BadTimeList', 'timeSecList must be a non-empty vector.');
end
timeSecList = double(timeSecList(:)');

% Dataset
DS = TransferLearning.AudioLightBaseline();
if isempty(DS)
	error('Fig37Trend:NoDataSet', 'AudioLightBaseline dataset is empty.');
end

% Cells table
if ~isprop(DS,'Cells') || isempty(DS.Cells)
	error('Fig37Trend:NoCells', 'Dataset has no Cells table.');
end
C = DS.Cells;
needC = {'Mouse','CellUID'};
if ~all(ismember(needC, C.Properties.VariableNames))
	error('Fig37Trend:BadCells', 'Cells table missing required columns.');
end
C.Mouse = string(C.Mouse);
C.CellUID = uint64(C.CellUID);

% Reuse builder to get Transfer final LightWater correct session per mouse
[~, dbg] = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
	'TargetAtSec', 1.0, 'SubtractAtSec', double(subtractAtSec), 'ExcludeZeroHit', false, 'ActualSignalMode', "PrevA");
if isempty(dbg) || ~isfield(dbg,'CorrectSession')
	error('Fig37Trend:NoDebug', 'Expected dbg.CorrectSession from builder.');
end
CorrSess = dbg.CorrectSession;
sourceName = "AudioLightBaseline";
stageName = "Transfer";
Csub = CorrSess(CorrSess.Source == sourceName & CorrSess.Stage == stageName, :);
if isempty(Csub)
	error('Fig37Trend:NoCorrectSession', 'No transfer correct session found in dbg.CorrectSession.');
end

% Build AudioWater trial table to infer learned session per mouse
try
	TA = DS.TableQuery(["Mouse","DateTime","TrialUID","Phase"], Stimulus="AudioWater");
catch
	TA = [];
end
if isempty(TA)
	error('Fig37Trend:NoAudioWater', 'No AudioWater trials found; cannot locate learned session.');
end
TA.Mouse = string(TA.Mouse);
TA.DateTime = datetime(TA.DateTime);
TA.DateTime.TimeZone = '';
if ismember('Phase', TA.Properties.VariableNames)
	TA.Phase = string(TA.Phase);
else
	TA.Phase = repmat("", height(TA), 1);
end
TA = sortrows(TA, {'Mouse','DateTime'});

% Time indices
xsSec = seconds(TransferLearning.Xs);
idxTList = nan(size(timeSecList));
for iT = 1:numel(timeSecList)
	[dtMin, idxT] = min(abs(xsSec - timeSecList(iT)));
	if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
		error('Fig37Trend:NoTargetSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', timeSecList(iT));
	end
	idxTList(iT) = idxT;
end
idxRef = [];
if isfinite(double(subtractAtSec))
	[dtMinRef, idxRef] = min(abs(xsSec - double(subtractAtSec)));
	if isempty(idxRef) || ~isfinite(dtMinRef) || dtMinRef > 0.25
		error('Fig37Trend:NoRefSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(subtractAtSec));
	end
end

ByMouse = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','TimeSec','NCellsCommon','CorrR','FisherZ','UsedForTrend'});

fprintf('--- Fig37: AW Learned vs LW Final corr trend over time (times=%s) ---\n', mat2str(timeSecList));

mice = intersect(unique(Csub.Mouse), unique(TA.Mouse));
mice = mice(~ismissing(mice));
mice = sort(mice);
for m = mice(:)'
	m = string(m);
	rowFinal = Csub(Csub.Mouse == m, :);
	if isempty(rowFinal)
		continue;
	end
	dtLWFinal = rowFinal.DateTime(1);

	% Find AudioWater learned session dt
	Ti = TA(TA.Mouse == m, :);
	if isempty(Ti)
		continue;
	end
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
	if isempty(idxLearned)
		continue;
	end
	dtAWLearned = sessDT(idxLearned);

	cellAll = unique(uint64(C.CellUID(C.Mouse == m)));
	if isempty(cellAll)
		continue;
	end

	% For each timepoint, compute correlation
	rList = nan(1, numel(timeSecList));
	zList = nan(1, numel(timeSecList));
	nList = nan(1, numel(timeSecList));
	for iT = 1:numel(timeSecList)
		idxT = idxTList(iT);
		[vFinal, uidFinal] = iSessionVals(DS, m, dtLWFinal, cellAll, idxT, idxRef, "LightWater");
		[vAW, uidAW] = iSessionVals(DS, m, dtAWLearned, cellAll, idxT, idxRef, "AudioWater");
		[r, nCommon] = iPearsonOnCommon(uidAW, vAW, uidFinal, vFinal, double(minCommonCells));
		z = atanh(r); if ~isfinite(r), z = NaN; end
		rList(iT) = r;
		zList(iT) = z;
		nList(iT) = nCommon;

		ByMouse = [ByMouse; table(m, timeSecList(iT), double(nCommon), double(r), double(z), 0, ...
			'VariableNames', ByMouse.Properties.VariableNames)]; %#ok<AGROW>
	end

	% Mark rows used for trend: require all timepoints finite
	useTrend = all(isfinite(zList));
	if useTrend
		ByMouse.UsedForTrend(ByMouse.Mouse == m) = 1;
	end
end

% Trend test (one point per mouse)
Tuse = ByMouse(ByMouse.UsedForTrend == 1, :);
if isempty(Tuse)
	warning('Fig37Trend:NoTrendData', 'No mice have complete data across all time points.');
	Trend = table;
else
	miceUse = unique(Tuse.Mouse);
	Zwide = nan(numel(miceUse), numel(timeSecList));
	Rwide = nan(numel(miceUse), numel(timeSecList));
	for iM = 1:numel(miceUse)
		m = miceUse(iM);
		for iT = 1:numel(timeSecList)
			row = Tuse(Tuse.Mouse == m & Tuse.TimeSec == timeSecList(iT), :);
			if ~isempty(row)
				Zwide(iM, iT) = row.FisherZ(1);
				Rwide(iM, iT) = row.CorrR(1);
			end
		end
	end

	% Linear slope of FisherZ vs time for each mouse
	slopes = nan(numel(miceUse), 1);
	for iM = 1:numel(miceUse)
		z = Zwide(iM, :);
		if all(isfinite(z))
			p = polyfit(timeSecList, z, 1);
			slopes(iM) = p(1);
		end
	end
	slopes = slopes(isfinite(slopes));

	pSlopeSignrank = NaN;
	pSlopeT = NaN;
	if numel(slopes) >= 5
		try
			pSlopeSignrank = signrank(slopes, 0, 'tail', 'right');
		catch
		end
		try
			[~, pSlopeT] = ttest(slopes, 0, 'Tail', 'right');
		catch
		end
	end

	% Paired tests on adjacent timepoints (FisherZ)
	pZ_1m0p5 = NaN;
	pZ_1p5m1 = NaN;
	if size(Zwide,1) >= 5
		try
			pZ_1m0p5 = signrank(Zwide(:,2), Zwide(:,1), 'tail', 'right');
		catch
		end
		try
			pZ_1p5m1 = signrank(Zwide(:,3), Zwide(:,2), 'tail', 'right');
		catch
		end
	end

	% Descriptives
	medZ = median(Zwide, 1, 'omitnan');
	medR = tanh(medZ);

	Trend = table(double(numel(miceUse)), string(mat2str(timeSecList)), ...
		double(medR(1)), double(medR(2)), double(medR(3)), ...
		double(pSlopeSignrank), double(pSlopeT), double(pZ_1m0p5), double(pZ_1p5m1), ...
		'VariableNames', {'NMouse','TimeSecList', 'MedianR_0p5','MedianR_1','MedianR_1p5', ...
		'PSlope_Signrank_Right','PSlope_TTest_Right','PZ_1minus0p5_Signrank_Right','PZ_1p5minus1_Signrank_Right'});
end

assignin('base','Fig37_AWLearned_vs_LWFinal_CorrTrend_ByMouse', ByMouse);
assignin('base','Fig37_AWLearned_vs_LWFinal_CorrTrend_Summary', Trend);

disp('--- Fig37 trend summary (one point per mouse) ---');
disp(Trend);

% Export
outDir = iSelectOutDir(outDirUNC);
fn1 = iFileName("Fig37_AWLearned_vs_LWFinal_CorrTrend_ByMouse.csv", timeSecList, double(subtractAtSec));
fn2 = iFileName("Fig37_AWLearned_vs_LWFinal_CorrTrend_Summary.csv", timeSecList, double(subtractAtSec));

p1 = iWriteTableWithRetry(ByMouse, outDir, fn1);
fprintf('Wrote: %s\n', p1);
p2 = iWriteTableWithRetry(Trend, outDir, fn2);
fprintf('Wrote: %s\n', p2);

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
		r = NaN;
		return;
	end
	try
		r = corr(x(use), y(use), 'Type','Pearson');
	catch
		r = NaN;
	end
end

function [vals, uid] = iSessionVals(DS, mouse, dt, cellListAll, idxT, idxRef, stimulus)
	vals = [];
	uid = uint64([]);
	if isnat(dt)
		return;
	end
	try
		T = DS.TableQuery("TrialUID", Mouse=string(mouse), Stimulus=string(stimulus), DateTime=dt);
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
		q = struct('CellUID', uint64(cellListAll(:)), 'TrialUID', uint64(trialUID(:)));
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
		uid = uint64(G.CellUID(:));
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
		vals = [];
		uid = uint64([]);
		return;
	end
	if ~isempty(idxRef)
		trace = trace - trace(:, idxRef);
	end
	vals = trace(:, idxT);
end

function outDir = iSelectOutDir(outDirUNC)
	outDir = string(outDirUNC);
	if ~startsWith(outDir, "\\")
		error('Fig37Trend:OutDirNotUNC', 'Output directory must be a UNC path: %s', outDir);
	end
	if ~exist(outDir, 'dir')
		mkdir(outDir);
	end
end

function fileName = iFileName(baseName, timeSecList, subtractAtSec)
	baseName = string(baseName);
	if isscalar(timeSecList)
		tag = sprintf('_At%gs', double(timeSecList));
	else
		tag = sprintf('_At%s', strrep(mat2str(double(timeSecList)), ' ', ''));
		tag = strrep(tag, '.', 'p');
		tag = strrep(tag, '[', '_');
		tag = strrep(tag, ']', '');
		tag = strrep(tag, ',', '_');
	end
	if isfinite(subtractAtSec)
		tag = tag + sprintf('_Minus%gs', double(subtractAtSec));
	end
	[pth, nm, ext] = fileparts(baseName);
	fileName = nm + tag + ext;
	if strlength(pth) > 0
		fileName = fullfile(pth, fileName);
	end
end

function outPath = iWriteTableWithRetry(T, outDir, fileName)
	outDir = string(outDir);
	fileName = string(fileName);
	if ~startsWith(outDir, "\\")
		error('Fig37Trend:OutDirNotUNC', 'Output directory must be UNC.');
	end
	maxTry = 5;
	for k = 1:maxTry
		try
			if k == 1
				fn = fileName;
			else
				[pth, nm, ext] = fileparts(fileName);
				rnd = char(java.util.UUID.randomUUID);
				fn = fullfile(pth, nm + "_" + string(rnd(1:8)) + ext);
			end
			outPath = fullfile(outDir, fn);
			writetable(T, outPath);
			return;
		catch ME
			lastME = ME; %#ok<NASGU>
		end
	end
	error('Fig37Trend:WriteFailed', 'Failed to write table after retries: %s', fileName);
end
