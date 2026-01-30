function Out = iBuildCorr_TransferSessionsToLearnedAudio_ByMouseLayer(DS, groupName, varargin)
% Build session-level Corr(Transfer LightWater, Learned AudioWater) per mouse/layer.
%
% Session selection matches Fig3.4F style as closely as possible:
% - Transfer-session pool is LightWater sessions from first StartPhase to last EndPhase
% - Exclude sessions contaminated with forbidden stimulus (default AudioWater)
% - Exclude sessions with no usable NTATS trace at target time
% - Apply After100 cutoff: exclude the first 100% hit session and all later sessions
%
% Learned session:
% - Last pure Learned AudioWater session (forbidden stimulus default LightWater)
%
% Output variables:
%   Group, Mouse, ZKey, DateTimeLearned, DateTimeTransfer, NCommon, Corr, FisherZ, HasData
%
% Usage:
%   T = TransferLearning.Fig37.iBuildCorr_TransferSessionsToLearnedAudio_ByMouseLayer(DS, "Ctrl", ...
%       'TargetAtSec', 1.5, 'MinCommonCells', 5);

ip = inputParser;
ip.FunctionName = 'TransferLearning.Fig37.iBuildCorr_TransferSessionsToLearnedAudio_ByMouseLayer';
addParameter(ip, 'TargetAtSec', 1.5, @(x) isnumeric(x) && isscalar(x));
addParameter(ip, 'MinCommonCells', 5, @(x) isnumeric(x) && isscalar(x));
addParameter(ip, 'StartPhase', "Transfer", @(s) isstring(s) || ischar(s));
addParameter(ip, 'EndPhase', "Final", @(s) isstring(s) || ischar(s));
addParameter(ip, 'LearnedPhase', "Learned", @(s) isstring(s) || ischar(s));
addParameter(ip, 'LearnedStimulus', "AudioWater", @(s) isstring(s) || ischar(s));
addParameter(ip, 'TransferStimulus', "LightWater", @(s) isstring(s) || ischar(s));
addParameter(ip, 'ForbiddenStimulusLearned', "LightWater", @(s) isstring(s) || ischar(s));
addParameter(ip, 'ForbiddenStimulusTransfer', "AudioWater", @(s) isstring(s) || ischar(s));
addParameter(ip, 'ApplyAfter100', true, @(x) islogical(x) && isscalar(x));
parse(ip, varargin{:});

targetAtSec = double(ip.Results.TargetAtSec);
minCommonCells = double(ip.Results.MinCommonCells);
startPhase = string(ip.Results.StartPhase);
endPhase = string(ip.Results.EndPhase);
learnedPhase = string(ip.Results.LearnedPhase);
learnedStimulus = string(ip.Results.LearnedStimulus);
transferStimulus = string(ip.Results.TransferStimulus);
forbiddenLearned = string(ip.Results.ForbiddenStimulusLearned);
forbiddenTransfer = string(ip.Results.ForbiddenStimulusTransfer);
applyAfter100 = logical(ip.Results.ApplyAfter100);

groupName = string(groupName);

Out = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Group','Mouse','ZKey','DateTimeLearned','DateTimeTransfer','NCommon','Corr','FisherZ','HasData'});

if isempty(DS)
	return;
end
if ~isprop(DS, 'Cells') || ~isprop(DS, 'Trials')
	return;
end

% Time index
xsSec = seconds(TransferLearning.Xs);
[dtMin, idxT] = min(abs(xsSec - targetAtSec));
if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig37:CorrTL:NoTargetSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', targetAtSec);
end

% Mice that have both learned and transfer stims
miceL = iMiceInPhaseStimulus(DS, learnedPhase, learnedStimulus);
miceT = iMiceInStimulus(DS, transferStimulus);
mice = intersect(miceL, miceT);
mice = mice(~ismissing(mice));
if isempty(mice)
	return;
end

C = DS.Cells;
needC = {'Mouse','CellUID','ZLayer'};
if isempty(C) || ~all(ismember(needC, C.Properties.VariableNames))
	return;
end
try
	C.Mouse = string(C.Mouse);
	C.CellUID = uint64(C.CellUID);
	C.ZLayer = string(C.ZLayer);
catch
end

for iM = 1:numel(mice)
	mouse = string(mice(iM));
	cellAll = unique(uint64(C.CellUID(C.Mouse == mouse)));
	if isempty(cellAll)
		continue;
	end
	Cm = C(C.Mouse == mouse, {'CellUID','ZLayer'});

	% Learned session: last pure AudioWater session
	[Tl, dtL] = iTrialsByMousePureSession(DS, mouse, learnedPhase, learnedStimulus, "last", forbiddenStimulus=forbiddenLearned);
	if isempty(Tl) || isnat(dtL)
		continue;
	end
	[uidL, vL] = iSessionVecByTrialUID(DS, cellAll, Tl, idxT);
	if isempty(uidL) || isempty(vL)
		continue;
	end

	% Transfer session pool like Fig3.4F (from first Transfer to last Final)
	Sess = iTransferSessionPool(DS, mouse, transferStimulus, startPhase, endPhase);
	if isempty(Sess)
		continue;
	end

	% Build usable sessions (exclude forbidden stimulus; exclude missing trace)
	usable = struct('DateTime', {}, 'Hit', {}, 'CellUID', {}, 'Val', {});
	for k = 1:height(Sess)
		dt = Sess.DateTime(k);
		trialUID = uint64(Sess.TrialUID{k});
		trialUID = trialUID(:);
		if isempty(trialUID)
			continue;
		end

		if iHasStimulus(DS, mouse, dt, forbiddenTransfer)
			continue;
		end

		hit = iHitRateFromTrialUID(DS, trialUID, transferStimulus);
		if ~isfinite(hit)
			continue;
		end

		[uidT, vT] = iSessionVecByTrialUID(DS, cellAll, trialUID, idxT);
		if isempty(uidT) || isempty(vT)
			continue;
		end

		usable(end+1) = struct('DateTime', dt, 'Hit', double(hit), 'CellUID', uint64(uidT), 'Val', double(vT)); %#ok<AGROW>
	end
	if numel(usable) < 1
		continue;
	end

	% Apply After100 cutoff on usable sessions
	if applyAfter100
		h = [usable.Hit];
		idx100 = find(isfinite(h) & (h >= (1 - 1e-12)), 1, 'first');
		if ~isempty(idx100)
			usable = usable(1:max(0, idx100-1));
		end
	end
	if numel(usable) < 1
		continue;
	end

	% Precompute z-keys for learned/transfer uids via Cm
	zL = iCellZKey(Cm, uidL);
	for k = 1:numel(usable)
		dtT = usable(k).DateTime;
		uidT = usable(k).CellUID;
		vT = usable(k).Val;
		zT = iCellZKey(Cm, uidT);
		for zKey = ["MOp23","MOp5"]
			maskL = (zL == zKey);
			uidLz = uidL(maskL);
			vLz = vL(maskL);

			maskT = (zT == zKey);
			uidTz = uidT(maskT);
			vTz = vT(maskT);

			[r, n] = iPearsonOnCommon(uidTz, vTz, uidLz, vLz, minCommonCells);
			z = atanh(r);
			if ~isfinite(r)
				z = NaN;
			end
			if ~isfinite(r) || n < minCommonCells
				continue;
			end
			Out = [Out; table(groupName, mouse, string(zKey), dtL, dtT, double(n), double(r), double(z), 1, ...
				'VariableNames', Out.Properties.VariableNames)]; %#ok<AGROW>
		end
	end
end

end

%% --- local helpers

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName)
	mice = string([]);
	try
		T = DS.TableQuery(["Mouse"], Phase=string(phaseName), Stimulus=string(stimulusName));
		if isempty(T)
			return;
		end
		mice = unique(string(T.Mouse));
		mice = mice(~ismissing(mice));
	catch
		mice = string([]);
	end
end

function mice = iMiceInStimulus(DS, stimulusName)
	mice = string([]);
	try
		T = DS.TableQuery(["Mouse"], Stimulus=string(stimulusName));
		if isempty(T)
			return;
		end
		mice = unique(string(T.Mouse));
		mice = mice(~ismissing(mice));
	catch
		mice = string([]);
	end
end

function Sess = iTransferSessionPool(DS, mouseName, stimName, startPhase, endPhase)
	Sess = table(NaT(0,1), cell(0,1), string.empty(0,1), 'VariableNames', {'DateTime','TrialUID','Phase'});
	try
		T = DS.TableQuery(["Mouse","DateTime","TrialUID","Phase"], Mouse=string(mouseName), Stimulus=string(stimName));
	catch
		T = [];
	end
	if isempty(T) || ~all(ismember(["DateTime","TrialUID"], string(T.Properties.VariableNames)))
		return;
	end
	try
		T.Mouse = string(T.Mouse);
		T.DateTime = datetime(T.DateTime);
		T.DateTime.TimeZone = '';
		if ismember('Phase', T.Properties.VariableNames)
			T.Phase = string(T.Phase);
		else
			T.Phase = repmat("", height(T), 1);
		end
	catch
	end
	T = sortrows(T, {'DateTime'});

	sessDT = unique(T.DateTime, 'stable');
	if isempty(sessDT)
		return;
	end
	
	% session-level phase: mode across trials
	sessPhase = strings(numel(sessDT),1);
	sessTrialUIDs = cell(numel(sessDT),1);
	for ii = 1:numel(sessDT)
		dt = sessDT(ii);
		maskDt = (T.DateTime == dt);
		ph = string(T.Phase(maskDt));
		ph = ph(ph ~= "");
		if isempty(ph)
			sessPhase(ii) = "";
		else
			[uPh,~,ic] = unique(ph);
			counts = accumarray(ic, 1);
			[~,mx] = max(counts);
			sessPhase(ii) = uPh(mx);
		end
		try
			sessTrialUIDs{ii} = unique(uint64(T.TrialUID(maskDt)));
		catch
			sessTrialUIDs{ii} = uint64([]);
		end
	end

	idxStart = find(sessPhase == string(startPhase), 1, 'first');
	idxEnd = find(sessPhase == string(endPhase), 1, 'last');
	if isempty(idxStart)
		return;
	end
	if isempty(idxEnd)
		idxEnd = find(sessPhase == string(startPhase), 1, 'last');
	end
	if isempty(idxEnd) || idxEnd < idxStart
		return;
	end

	sessDT = sessDT(idxStart:idxEnd);
	sessPhase = sessPhase(idxStart:idxEnd);
	sessTrialUIDs = sessTrialUIDs(idxStart:idxEnd);

	Sess = table(sessDT(:), sessTrialUIDs(:), string(sessPhase(:)), 'VariableNames', Sess.Properties.VariableNames);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
	tf = false;
	try
		Tdt = DS.TableQuery(["Stimulus"], Mouse=string(mouseName), DateTime=dt);
	catch
		Tdt = [];
	end
	if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames)
		return;
	end
	try
		st = unique(string(Tdt.Stimulus));
		st = st(~ismissing(st));
	catch
		st = string([]);
	end
	if isempty(st)
		return;
	end
	tf = any(st == string(stim));
end

function [trialUID, dt] = iTrialsByMousePureSession(DS, mouseName, phaseName, stimulusName, whichOne, opts)
	arguments
		DS
		mouseName
		phaseName
		stimulusName
		whichOne
		opts.forbiddenStimulus string = string([])
	end
	trialUID = uint64([]);
	dt = NaT;
	forbidden = string(opts.forbiddenStimulus);
	try
		T = DS.TableQuery(["TrialUID","Mouse","DateTime","Phase","Stimulus"], Mouse=string(mouseName), Phase=string(phaseName));
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	try
		T.Mouse = string(T.Mouse);
		T.Phase = string(T.Phase);
		T.Stimulus = string(T.Stimulus);
		T.DateTime = datetime(T.DateTime);
		T.DateTime.TimeZone = '';
	catch
	end
	T = T(~isnat(T.DateTime), :);
	if isempty(T)
		return;
	end
	T = sortrows(T, 'DateTime');
	allDT = unique(T.DateTime, 'stable');
	if isempty(allDT)
		return;
	end
	if strcmpi(whichOne, 'last')
		allDT = flipud(allDT);
	end

	for iD = 1:numel(allDT)
		dtTry = allDT(iD);
		Ti = T(T.DateTime==dtTry, :);
		stims = unique(string(Ti.Stimulus));
		stims = stims(~ismissing(stims));
		if isempty(stims) || ~any(stims == string(stimulusName))
			continue;
		end
		if strlength(forbidden) > 0
			stimsAll = iStimuliAtDateTimeAllPhases(DS, mouseName, dtTry);
			if any(stimsAll == forbidden)
				continue;
			end
		end
		Tu = unique(uint64(Ti.TrialUID(string(Ti.Stimulus)==string(stimulusName))));
		if isempty(Tu)
			continue;
		end
		dt = dtTry;
		trialUID = Tu;
		return;
	end
end

function stims = iStimuliAtDateTimeAllPhases(DS, mouseName, dt)
	stims = string([]);
	try
		T = DS.TableQuery(["Stimulus"], Mouse=string(mouseName), DateTime=dt);
	catch
		T = [];
	end
	if isempty(T) || ~ismember('Stimulus', T.Properties.VariableNames)
		return;
	end
	try
		stims = unique(string(T.Stimulus));
		stims = stims(~ismissing(stims));
	catch
		stims = string([]);
	end
end

function hit = iHitRateFromTrialUID(DS, trialUID, stimulusName)
	hit = NaN;
	trialUID = uint64(trialUID(:));
	if isempty(trialUID) || ~isprop(DS, 'Trials')
		return;
	end
	Tr = DS.Trials;
	need = {'TrialUID','Stimulus','Behavior'};
	if isempty(Tr) || ~all(ismember(need, Tr.Properties.VariableNames))
		return;
	end
	try
		Tr.TrialUID = uint64(Tr.TrialUID);
		Tr.Stimulus = string(Tr.Stimulus);
	catch
		return;
	end
	mask = ismember(uint64(Tr.TrialUID), trialUID) & (Tr.Stimulus == string(stimulusName));
	if ~any(mask)
		return;
	end
	b = double(Tr.Behavior(mask));
	hit = mean(b(isfinite(b)), 'omitnan');
end

function [uid, val] = iSessionVecByTrialUID(DS, cellAll, trialUID, idxT)
	uid = uint64([]);
	val = [];
	try
		q = struct('CellUID', uint64(cellAll(:)), 'TrialUID', uint64(trialUID(:)));
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	A = G.NTATS;
	A = iNtatsData(A);
	if isempty(A) || ndims(A) < 2 || size(A,2) < idxT
		return;
	end
	uid = uint64(G.CellUID(:));
	val = double(A(:, idxT));
	% drop non-finite
	try
		good = isfinite(val);
		uid = uid(good);
		val = val(good);
	catch
	end
end

function X = iNtatsData(NT)
	try
		if isa(NT, 'MATLAB.DataTypes.NDTable')
			X = NT.Data;
		else
			X = NT;
		end
	catch
		X = [];
		return;
	end
	try
		X = squeeze(double(X));
	catch
	end
end

function zKey = iCellZKey(Cm, uid)
	zKey = strings(numel(uid), 1);
	try
		[tf, loc] = ismember(uint64(uid(:)), uint64(Cm.CellUID));
		z = strings(numel(uid), 1);
		zz = strings(nnz(tf), 1);
		zz(:) = string(Cm.ZLayer(loc(tf)));
		zz(zz == "MOp2/3") = "MOp23";
		zz(zz == "MOp23") = "MOp23";
		zz(zz == "MOp5") = "MOp5";
		z(tf) = zz;
		zKey = z;
	catch
		zKey(:) = "";
	end
end

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
	if std(x(use)) == 0 || std(y(use)) == 0
		r = NaN;
		return;
	end
	try
		r = corr(x(use), y(use), 'Type','Pearson');
	catch
		r = NaN;
	end
end
