% Fig37K (by-layer): DeltaHit vs training-signal matching metrics
%
% Goal:
% - Define correct training signal (NTATS ZScore median @targetAtSec, default 1.5s)
%     Initial learning: Learned LightWater
%     Transfer learning: Final  LightWater
% - For each adjacent-session pair (within Naive LightWater or Transfer LightWater;
%   excluding first-100% session and later), compute actual training signal as the
%   average NTATS trace across the 2 sessions, then take @targetAtSec.
% - Compute 4 metrics per pair (per layer):
%     1) Corr(actual@t, correct@t) across common cells (Pearson)
%     2) MSE(actual@t, correct@t) across common cells
%     3) Fraction of correct-active cells also active in actual
%     4) Jaccard overlap of active cell sets
% - Report Spearman correlations between DeltaHit and each metric.
%
% Output: 2 (Initial/Transfer) × 2 (MOp23/MOp5) × 4 metrics = 16 correlations.
%
% Execution:
%   TransferLearning.Fig37.K_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer

% Allow overriding defaults from caller workspace (script semantics).
% Example:
%   actualSignalMode = "PrevA";
%   TransferLearning.Fig37.K_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer
if ~exist('outDirUNC','var') || isempty(outDirUNC)
	outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
end

% Actual training signal mode:
% - "MeanAB": mean of session A and B NTATS traces (default)
% - "PrevA" : use only previous session A NTATS trace
if ~exist('actualSignalMode','var') || isempty(actualSignalMode)
	actualSignalMode = "MeanAB";
end

% Optional: exclude 0%-hit sessions from the adjacent-session pool.
if ~exist('excludeZeroHit','var') || isempty(excludeZeroHit)
	excludeZeroHit = false;
end

% Optional: subtract NTATS at a reference time from NTATS@1.5s for both
% correct and actual training signals (e.g., subtractAtSec=1.0 means 1.5s-1.0s).
if ~exist('subtractAtSec','var') || isempty(subtractAtSec)
	subtractAtSec = NaN;
end

% Optional: use NTATS at a different target time (default 1.5s).
% Example: targetAtSec = 1.0 uses NTATS@1s for both correct & actual signals.
if ~exist('targetAtSec','var') || isempty(targetAtSec)
	targetAtSec = 1.5;
end

% Optional: control for previous-session hit rate (Hit1) when correlating
% DeltaHit with each metric. This reports a partial Spearman:
%   corr(DeltaHit, Metric | Hit1)
if ~exist('controlPrevHit','var') || isempty(controlPrevHit)
	controlPrevHit = false;
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

pairs = [];
dbg = [];
try
	[pairs, dbg] = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
		'TargetAtSec', double(targetAtSec), 'ActualSignalMode', actualSignalMode, 'ExcludeZeroHit', logical(excludeZeroHit), 'SubtractAtSec', double(subtractAtSec));
catch
	pairs = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
		'TargetAtSec', double(targetAtSec), 'ActualSignalMode', actualSignalMode, 'ExcludeZeroHit', logical(excludeZeroHit), 'SubtractAtSec', double(subtractAtSec));
end
if isempty(pairs)
	error('Fig37KTrainSigMatchByLayer:Empty', 'No valid adjacent session pairs (by layer).');
end

assignin('base','Fig3_7k_TrainSignalMatch_ByLayer_Pairs', pairs);
if ~isempty(dbg)
	assignin('base','Fig3_7k_TrainSignalMatch_ByLayer_Debug', dbg);
end

metrics = ["SignalCorr","SignalMSE","ActiveOverlapFrac","ActiveJaccard"];
stages = ["Initial","Transfer"];
layers = ["MOp23","MOp5"];

Summary = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Stage','ZKey','Metric','N','Rho','P','NCtrlHit1','RhoCtrlHit1','PCtrlHit1'});

fprintf('--- Fig37K: DeltaHit vs training-signal match (Spearman) ---\n');

for st = stages
	for z = layers
		zKey = z;
		rows = (pairs.Stage == st) & (pairs.ZKey == zKey);
		P = pairs(rows, :);
		for m = metrics
			x = double(P.DeltaHit);
			y = double(P.(m));
			[rho, p, n] = iSpearman(x, y);
			if logical(controlPrevHit)
				hit1 = double(P.Hit1);
				[rhoC, pC, nC] = iPartialSpearmanCtrl(x, y, hit1);
			else
				rhoC = NaN;
				pC = NaN;
				nC = NaN;
			end
			Summary = [Summary; table(string(st), string(zKey), string(m), double(n), double(rho), double(p), ...
				double(nC), double(rhoC), double(pC), 'VariableNames', Summary.Properties.VariableNames)]; %#ok<AGROW>
			fprintf('%s %s %-16s: n=%d, rho=%.4f, p=%.4g\n', st, zKey, m, n, rho, p);
			if logical(controlPrevHit)
				fprintf('%s %s %-16s (|Hit1): n=%d, rho=%.4f, p=%.4g\n', st, zKey, m, nC, rhoC, pC);
			end
		end
	end
end

assignin('base','Fig3_7k_TrainSignalMatch_ByLayer_Summary', Summary);

outDir = iSelectOutDir(outDirUNC);

[ok, outDirUsed] = iWriteAll(outDir, Summary, pairs, dbg, actualSignalMode, logical(excludeZeroHit), double(subtractAtSec), double(targetAtSec), logical(controlPrevHit));
if ~ok
	error('Fig37KTrainSigMatchByLayer:WriteFailed', 'Failed to write one or more CSVs to: %s', outDirUsed);
end
fprintf('CSV dir: %s\n', outDirUsed);

%% --- local helpers

function [rho, p, n] = iSpearman(x, y)
	rho = NaN;
	p = NaN;
	x = double(x(:));
	y = double(y(:));
	use = isfinite(x) & isfinite(y);
	n = nnz(use);
	if n < 5
		return;
	end
	try
		[rho, p] = corr(x(use), y(use), 'Type','Spearman');
	catch
		rho = NaN;
		p = NaN;
	end
end

function [rho, p, n] = iPartialSpearmanCtrl(x, y, z)
	% Partial Spearman correlation controlling for z (Hit1).
	% Implemented as: rank-transform then correlate residuals after regressing
	% out rank(z) from rank(x) and rank(y).
	rho = NaN;
	p = NaN;
	x = double(x(:));
	y = double(y(:));
	z = double(z(:));
	use = isfinite(x) & isfinite(y) & isfinite(z);
	n = nnz(use);
	if n < 5
		return;
	end
	try
		rx = tiedrank(x(use));
		ry = tiedrank(y(use));
		rz = tiedrank(z(use));
		X = [ones(n,1), rz];
		bx = X \ rx;
		by = X \ ry;
		ex = rx - X*bx;
		ey = ry - X*by;
		[rho, p] = corr(ex, ey, 'Type','Pearson');
	catch
		rho = NaN;
		p = NaN;
	end
end

function outDir = iSelectOutDir(outDirUNC)
	outDir = outDirUNC;
	if ~isfolder(outDir)
		% Only write to UNC; do NOT fall back to local temp.
		try
			mkdir(outDir);
		catch
			error('Fig37KTrainSigMatchByLayer:OutDirMissing', 'Output dir does not exist and cannot be created: %s', outDir);
		end
	end
end

function [ok, outDir] = iWriteAll(outDir, Summary, pairs, dbg, actualSignalMode, excludeZeroHit, subtractAtSec, targetAtSec, controlPrevHit)
	ok = true;
	try
		outPath = iWriteTableWithRetry(Summary, outDir, iFileName('Fig3_7k_TrainSignalMatch_ByLayer_Summary.csv', actualSignalMode, excludeZeroHit, subtractAtSec, targetAtSec, controlPrevHit));
		fprintf('Wrote: %s\n', outPath);
	catch ME
		ok = false;
		warning(ME.identifier, 'Write summary failed: %s', ME.message);
	end
	try
		outPathPairs = iWriteTableWithRetry(pairs, outDir, iFileName('Fig3_7k_TrainSignalMatch_ByLayer_Pairs.csv', actualSignalMode, excludeZeroHit, subtractAtSec, targetAtSec, controlPrevHit));
		fprintf('Wrote: %s\n', outPathPairs);
	catch ME
		ok = false;
		warning(ME.identifier, 'Write pairs failed: %s', ME.message);
	end
	if ~isempty(dbg)
		try
			if isfield(dbg,'Sessions') && ~isempty(dbg.Sessions)
				outPathSessions = iWriteTableWithRetry(dbg.Sessions, outDir, iFileName('Fig3_7k_TrainSignalMatch_ByLayer_Sessions.csv', actualSignalMode, excludeZeroHit, subtractAtSec, targetAtSec, controlPrevHit));
				fprintf('Wrote: %s\n', outPathSessions);
			end
		catch ME
			ok = false;
			warning(ME.identifier, 'Write sessions failed: %s', ME.message);
		end
		try
			if isfield(dbg,'CorrectSession') && ~isempty(dbg.CorrectSession)
				outPathCorrect = iWriteTableWithRetry(dbg.CorrectSession, outDir, iFileName('Fig3_7k_TrainSignalMatch_ByLayer_CorrectSession.csv', actualSignalMode, excludeZeroHit, subtractAtSec, targetAtSec, controlPrevHit));
				fprintf('Wrote: %s\n', outPathCorrect);
			end
		catch ME
			ok = false;
			warning(ME.identifier, 'Write correct-session failed: %s', ME.message);
		end
	end
end

function fn = iFileName(baseName, actualSignalMode, excludeZeroHit, subtractAtSec, targetAtSec, controlPrevHit)
	% If using a non-default actual-signal mode, append suffix to avoid overwriting.
	mode = string(actualSignalMode);
	if nargin < 3
		excludeZeroHit = false;
	end
	excludeZeroHit = logical(excludeZeroHit);
	if nargin < 4
		subtractAtSec = NaN;
	end
	subtractAtSec = double(subtractAtSec);
	if nargin < 5
		targetAtSec = 1.5;
	end
	targetAtSec = double(targetAtSec);
	if nargin < 6
		controlPrevHit = false;
	end
	controlPrevHit = logical(controlPrevHit);

	suffix = strings(0,1);
	if ~(mode == "MeanAB" || strlength(mode) == 0)
		suffix(end+1) = mode; %#ok<AGROW>
	end
	if excludeZeroHit
		suffix(end+1) = "No0Hit"; %#ok<AGROW>
	end
	if isfinite(subtractAtSec)
		% keep it readable, most common is Minus1s
		if abs(subtractAtSec - 1.0) < 1e-6
			suffix(end+1) = "Minus1s"; %#ok<AGROW>
		else
			suffix(end+1) = sprintf('Minus%gs', subtractAtSec); %#ok<AGROW>
		end
	end
	if isfinite(targetAtSec) && abs(targetAtSec - 1.5) > 1e-6
		if abs(targetAtSec - 1.0) < 1e-6
			suffix(end+1) = "At1s"; %#ok<AGROW>
		else
			suffix(end+1) = sprintf('At%gs', targetAtSec); %#ok<AGROW>
		end
	end
	if controlPrevHit
		suffix(end+1) = "CtrlHit1"; %#ok<AGROW>
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
	% Write to the requested UNC folder. If the target file is locked/denied,
	% retry with a randomized name in the SAME folder.
	if nargin < 3
		error('Fig37KTrainSigMatchByLayer:BadArgs', 'Missing fileName.');
	end
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
		randStr = char(java.util.UUID.randomUUID);
		randStr = randStr(1:8);
		altName = sprintf('%s_%s_%s%s', stem, ts, randStr, ext);
		altPath = fullfile(outDir, altName);
		try
			writetable(T, altPath);
			outPath = altPath;
			return;
		catch
			% keep trying
		end
	end
	error('Fig37KTrainSigMatchByLayer:WriteFailed', 'Failed to write %s (and randomized retries) under: %s', fileName, outDir);
end
