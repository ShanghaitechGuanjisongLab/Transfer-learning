% 图3.3c：示例细胞钙曲线（细胞间标准差低 vs 高）
%
% Lower inter-cell SD example (within ONE mouse):
% - Choose 3~4 cells (same mouse)
% - Choose 3~4 trials from ONE session
% - For each chosen cell: among chosen trials, at least one trial is active at 1s,
%   and at least one trial is negative at 1s
% - Active-cell sets are NOT identical across trials
%
% Higher inter-cell SD example (within ANOTHER mouse):
% - Choose 3~4 cells (same mouse)
% - Choose 3~4 trials from ONE session
% - For each chosen cell: across chosen trials, 1s is either always active OR always negative
% - Each chosen trial contains at least one active cell and one negative cell
%
% Signal:
% - Use ResampledSignal (48 points, aligned to cue)
% - ZScore per trial using EACH TRIAL's own baseline (-3~0s)
% - Active criterion:   X(t=1s) > baseline mean(-3~0s) + kSigma*baseline std(-3~0s)
% - Inactive criterion: X(t=1s) < baseline mean(-3~0s) (per-trial)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   IMPORTANT: MUST REMAIN A SCRIPT (do not convert to a function).
%   Call via package name:
%     TransferLearning.Fig33.C_DivergenceExampleCells

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- 0) Ensure project loaded (for UniExp)
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

% Datasets
% - Lower-SD example: Naive LightWater from LAInterspersed + LightAudioBaseline
% - Higher-SD example: Learned AudioWater from AudioLightBaseline
DS_hiSD = TransferLearning.AudioLightBaseline();
Ts_hiSD = DS_hiSD.TrialSignals;
C_hiSD  = DS_hiSD.Cells;

DS_loSD_1 = TransferLearning.LAInterspersed();
Ts_loSD_1 = DS_loSD_1.TrialSignals;
C_loSD_1  = DS_loSD_1.Cells;

DS_loSD_2 = TransferLearning.LightAudioBaseline();
Ts_loSD_2 = DS_loSD_2.TrialSignals;
C_loSD_2  = DS_loSD_2.Cells;

xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
plotMask = (xsSec >= -1) & (xsSec <= 1);
xsPlot = xsSec(plotMask);

if ~any(baseMask)
	error('Fig3_3a:NoBaselineSamples', 'baseline window -3~0s has no samples in TransferLearning.Xs');
end
if ~any(plotMask)
	error('Fig3_3c:NoPlotSamples', 'plot window -1~1s has no samples in TransferLearning.Xs');
end

% active sample (closest to 1s)
[dtMin, actIdx] = min(abs(xsSec - 1));
if isempty(actIdx) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig3_3c:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end

kSigma = 3;

% --- 1) Queries
qLoSD = struct('Phase','Naive','Stimulus','LightWater');
qHiSD = struct('Phase','Learned','Stimulus','AudioWater');

% --- 2) Find paired examples with SAME number of trials
desiredTrialsList = [4 3];
lowEx = struct(); highEx = struct();
lowLabel = ""; highLabel = "";
okPaired = false;
for nTrialsDesired = desiredTrialsList
	try
		% Lower-SD example (variable active sets): allow fallback across two sources
		[lowEx, lowLabel] = iFindExample2Sources( ...
			DS_loSD_1, Ts_loSD_1, C_loSD_1, "LAInterspersed", qLoSD, ...
			DS_loSD_2, Ts_loSD_2, C_loSD_2, "LightAudioBaseline", qLoSD, ...
			xsSec, baseMask, actIdx, kSigma, "low", nTrialsDesired, "");
		% Higher-SD example (stable sign per cell) must be ANOTHER mouse
		[highEx, highLabel] = iFindExample(DS_hiSD, Ts_hiSD, C_hiSD, qHiSD, struct(), xsSec, baseMask, actIdx, kSigma, "high", nTrialsDesired, lowEx.Mouse);
		okPaired = true;
		break;
	catch
		okPaired = false;
	end
end
if ~okPaired
	error('Fig3_3c:NoPairedExampleFound', 'Failed to find paired examples with the same number of trials (tried %s).', mat2str(desiredTrialsList));
end

assignin('base', 'Fig3_3c_LowSDExample',  lowEx);
assignin('base', 'Fig3_3c_HighSDExample', highEx);
%% 

% --- 3) Plot
nCols = numel(lowEx.TrialUIDs);

svgName = "Fig3_3c_CellToCellSD_ExampleDistributions.svg";
figName = sprintf('Fig3.3c Cell-to-cell SD examples (Low=%s, High=%s)', lowEx.Mouse, highEx.Mouse);
f = figure('Name', figName, 'Color','w');
try
	MATLAB.Graphics.FigureAspectRatio(16, 5, 1);
catch
end

TL = tiledlayout(2, nCols, 'TileSpacing','compact', 'Padding','compact');
axesList = gobjects(0,1);

% --- Lower inter-cell SD row (row 1)
for j = 1:nCols
	ax = nexttile(TL, j);
	axesList(end+1,1) = ax; %#ok<AGROW>
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end
	box(ax,'off');
	grid(ax,'on');
	xlim(ax, [-1 1]);

	% Hide X axis for the first row
	try
		ax.XAxis.Visible = 'off';
		ax.XTickLabel = [];
	catch
	end
	% Hide Y axis for all but the first column
	if j > 1
		try
			ax.YAxis.Visible = 'off';
			ax.YTickLabel = [];
		catch
		end
	end

	if j <= numel(lowEx.TrialUIDs)
		Zj = squeeze(lowEx.Z(j, plotMask, :));
		col = feval('lines', size(Zj,2));
		for cIdx = 1:size(Zj,2)
			plot(ax, xsPlot, Zj(:,cIdx), 'LineWidth', 1.0, 'Color', col(cIdx,:));
		end
		% Must be added BEFORE legend (and excluded by explicit handles below)
		TransferLearning.DrawCueWaterLines(ax);
		if j == 1
			ylabel(ax, 'Low SD');
		end
	else
		axis(ax,'off');
	end
end

% --- Higher inter-cell SD row (row 2)
for j = 1:nCols
	ax = nexttile(TL, nCols + j);
	axesList(end+1,1) = ax; %#ok<AGROW>
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end
	box(ax,'off');
	grid(ax,'on');
	xlim(ax, [-1 1]);

	% Hide Y axis for all but the first column
	if j > 1
		try
			ax.YAxis.Visible = 'off';
			ax.YTickLabel = [];
		catch
		end
	end

	if j <= numel(highEx.TrialUIDs)
		Zj = squeeze(highEx.Z(j, plotMask, :));
		col = feval('lines', size(Zj,2));
		for cIdx = 1:size(Zj,2)
			plot(ax, xsPlot, Zj(:,cIdx), 'LineWidth', 1.0, 'Color', col(cIdx,:));
		end
		% Must be added BEFORE legend (and excluded by explicit handles below)
		TransferLearning.DrawCueWaterLines(ax);
		if j == 1
			ylabel(ax, 'High SD');
		end
	else
		axis(ax,'off');
	end
end

% Unify Y limits within each group only (high row vs low row)
try
	axesVisible = axesList(isgraphics(axesList));
	isOn = false(size(axesVisible));
	for ii = 1:numel(axesVisible)
		try
			isOn(ii) = strcmpi(axesVisible(ii).Visible, 'on');
		catch
			isOn(ii) = true;
		end
	end
	axesVisible = axesVisible(isOn);
	% split by row: first nCols tiles are high, next nCols tiles are low
	highAxes = axesVisible(axesVisible.Tile <= nCols);
	lowAxes  = axesVisible(axesVisible.Tile >  nCols);
	if ~isempty(highAxes)
		MATLAB.Graphics.UnifyAxesLims(highAxes, @ylim);
	end
	if ~isempty(lowAxes)
		MATLAB.Graphics.UnifyAxesLims(lowAxes, @ylim);
	end
catch
end

% Shared labels on tiledlayout
xlabel(TL, 'Time (s)');
ylabel(TL, 'Z-score');

% A concise title (no figure index)
sgtitle(TL, 'Example calcium traces (low vs high cell-to-cell SD)', 'Interpreter','none');

% --- 4) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local functions

function [ex, label] = iFindExample(DS, Ts, C, qPrimary, qFallback, xsSec, baseMask, actIdx, kSigma, mode, nTrialsDesired, excludeMouse)
	T = table;
	label = "";
	if ~isempty(fieldnames(qPrimary))
		T = iTableQueryOrEmpty(DS, qPrimary);
		label = iLabelOfQuery(qPrimary);
	end
	if isempty(T) || height(T) == 0
		if ~isempty(fieldnames(qFallback))
			T = iTableQueryOrEmpty(DS, qFallback);
			label = iLabelOfQuery(qFallback);
			warning('Fig3_3c:FallbackQuery', 'Primary query returned empty; using fallback: %s', label);
		end
	end
	if isempty(T) || height(T) == 0
		error('Fig3_3c:EmptyQuery', 'No trials returned for mode=%s.', string(mode));
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);

	% group into sessions by Mouse+DateTime
	[gSess, keyMouse, keyDT] = findgroups(T.Mouse, T.DateTime);
	sessN = splitapply(@numel, T.TrialUID, gSess);
	Sess = table(keyMouse, keyDT, sessN, 'VariableNames', {'Mouse','DateTime','NTrials'});
	Sess = sortrows(Sess, {'NTrials','Mouse','DateTime'}, {'descend','ascend','ascend'});

	ex = struct('Mode', string(mode), 'Mouse', "", 'DateTime', NaT, 'ZLayer', "", ...
		'CellUIDs', uint64([]), 'TrialUIDs', uint64([]), 'ActiveMatrix', [], 'InactiveMatrix', [], 'Z', []);

	% Try top sessions until success
	maxTry = min(60, height(Sess));
	for i = 1:maxTry
		m = string(Sess.Mouse(i));
		if exist('excludeMouse','var') && strlength(string(excludeMouse))>0
			if strcmpi(m, string(excludeMouse))
				continue;
			end
		end
		dt = Sess.DateTime(i);
		idx = (T.Mouse==m) & (T.DateTime==dt);
		trialUIDs = unique(uint64(T.TrialUID(idx)));
		if numel(trialUIDs) < 6
			continue;
		end

		% pick the layer with most cells for this mouse (stability)
		Cm = C(string(C.Mouse)==m, :);
		if isempty(Cm)
			continue;
		end
		Cm.ZLayer = string(Cm.ZLayer);
		[gZ, zKey] = findgroups(Cm.ZLayer);
		zN = splitapply(@numel, Cm.CellUID, gZ);
		[~, oZ] = sort(zN, 'descend');
		zPick = string(zKey(oZ(1)));
		cellUIDsAll = uint64(Cm.CellUID(Cm.ZLayer==zPick));
		if numel(cellUIDsAll) < 20
			continue;
		end

		try
			[ok, out] = iTrySession(Ts, cellUIDsAll, trialUIDs, xsSec, baseMask, actIdx, kSigma, mode, nTrialsDesired);
		catch
			ok = false;
			out = struct();
		end
		if ok
			ex.Mouse = m;
			ex.DateTime = dt;
			ex.ZLayer = zPick;
			ex.CellUIDs = out.CellUIDs;
			ex.TrialUIDs = out.TrialUIDs;
			ex.ActiveMatrix = out.Active;
				ex.InactiveMatrix = out.Inactive;
			ex.Z = out.Z;
			fprintf('Fig3.3c %s example: Mouse=%s %s | %s | cells=[%s] trials=[%s]\n', ...
				string(mode), m, string(dt), zPick, strjoin(string(out.CellUIDs(:).'), ','), strjoin(string(out.TrialUIDs(:).'), ','));
			return;
		end
	end

	error('Fig3_3c:NoExampleFound', 'Failed to find %s example within %d sessions (query=%s).', string(mode), maxTry, label);
end


function [ex, srcLabel] = iFindExample2Sources(DS1, Ts1, C1, src1, q1, DS2, Ts2, C2, src2, q2, xsSec, baseMask, actIdx, kSigma, mode, nTrialsDesired, excludeMouse)
	srcLabel = "";
	try
		[ex, ~] = iFindExample(DS1, Ts1, C1, q1, struct(), xsSec, baseMask, actIdx, kSigma, mode, nTrialsDesired, excludeMouse);
		srcLabel = string(src1);
		return;
	catch ME1
		try
			[ex, ~] = iFindExample(DS2, Ts2, C2, q2, struct(), xsSec, baseMask, actIdx, kSigma, mode, nTrialsDesired, excludeMouse);
			srcLabel = string(src2);
			warning('Fig3_3c:SourceFallback', 'Failed on %s (%s). Falling back to %s.', string(src1), ME1.identifier, string(src2));
			return;
		catch ME2
			error('Fig3_3c:SourceBothFailed', 'Failed to find example in both sources. %s: %s | %s: %s', ...
			string(src1), ME1.message, string(src2), ME2.message);
		end
	end
end

function [ok, out] = iTrySession(Ts, cellUIDsAll, trialUIDsAll, xsSec, baseMask, actIdx, kSigma, mode, nTrialsDesired)
		% limit trials (deterministic) to keep compute bounded
	trialUIDsAll = sort(uint64(trialUIDsAll(:)));
		maxTrials = 200;
	if numel(trialUIDsAll) > maxTrials
		trialUIDsAll = trialUIDsAll(1:maxTrials);
	end

	% Fetch all signals for these cell×trial pairs (ResampledSignal only)
	[X, cellUIDsAll, trialUIDsAll] = iFetchMatrix(Ts, cellUIDsAll, trialUIDsAll, numel(xsSec));

	% Z-score per trial per cell using baseline
	mu = mean(X(:, baseMask, :), 2, 'omitnan');
	sd = std(X(:, baseMask, :), 0, 2, 'omitnan');
	Z = (X - mu) ./ sd;

	X1 = squeeze(X(:, actIdx, :));
	mu1 = squeeze(mu); % baseline mean per trial per cell (trials x cells)
	sd1 = squeeze(sd); % baseline std per trial per cell (trials x cells)
	A = X1 > (mu1 + kSigma .* sd1); % Active (trials x cells)
	I = X1 < mu1; % Inactive (trials x cells)
	if isempty(A) || isempty(I)
		ok = false; out = struct(); return;
	end
	% robustify NaNs
	A(~isfinite(A)) = false;
	I(~isfinite(I)) = false;

	if strcmpi(string(mode), "low")
		% Low inter-cell SD example: variable active sets; each chosen cell has both active and negative trials
		[ok, out] = iSelectLowSD(cellUIDsAll, trialUIDsAll, Z, A, I, nTrialsDesired);
	else
		% High inter-cell SD example: stable sign per cell across selected trials
		[ok, out] = iSelectHighSD(cellUIDsAll, trialUIDsAll, Z, A, I, nTrialsDesired);
	end
end

function [ok, out] = iSelectLowSD(cellUIDsAll, trialUIDsAll, Z, A, I, nTrialsDesired)
	% Lower inter-cell SD constraints (per outline)
	% - 3~4 cells, 3~4 trials
	% - Active sets are NOT identical across chosen trials
	% - Each chosen cell has >=1 active trial AND >=1 negative trial

	ok = false;
	out = struct();

	colSum = sum(A, 1, 'omitnan');
	idxCandCells = find(colSum >= 1 & colSum <= 12);
	if numel(idxCandCells) < 6
		return;
	end
	% deterministic: prefer sparser cells
	[~, o] = sortrows([colSum(idxCandCells).', double(cellUIDsAll(idxCandCells))], [1 2]);
	idxCandCells = idxCandCells(o);
	idxCandCells = idxCandCells(1:min(30, numel(idxCandCells)));

	% Try 4-cell combos first, then 3-cell
	for nCells = [4 3]
		comb = nchoosek(1:numel(idxCandCells), nCells);
		for i = 1:size(comb,1)
			cIdx = idxCandCells(comb(i,:));
			Acs = A(:, cIdx);
			Ics = I(:, cIdx);
			% candidate trials: require at least 1 active cell (cap to keep patterns sparse)
			rsum = sum(Acs, 2);
			idxTrials = find(rsum >= 1 & rsum <= min(3, nCells));
			if numel(idxTrials) < 3
				continue;
			end
			% group trials by pattern (bitmask)
			P = iRowPattern(Acs(idxTrials,:));
			[uP, ~, gP] = unique(P, 'stable');
			% pick unique patterns only
			if numel(uP) < 3
				continue;
			end
			% try selecting 4 patterns else 3
			for nT = [4 3]
				if ~isempty(nTrialsDesired) && isfinite(nTrialsDesired) && nT ~= nTrialsDesired
					continue;
				end
				if numel(uP) < nT
					continue;
				end
				patComb = nchoosek(1:numel(uP), nT);
				bestScore = -inf;
				best = struct();
				for j = 1:size(patComb,1)
					patIdx = patComb(j,:);
					trialChoices = cell(nT,1);
					for k = 1:nT
						rowsP = idxTrials(gP == patIdx(k));
						rowsP = rowsP(:);
						trialChoices{k} = rowsP(1:min(5, numel(rowsP))); % bound search
					end
					[pickIdx, Asel] = iPickTrialsHigh(Acs, trialChoices);
					if isempty(pickIdx)
						continue;
					end
					Isel = Ics(pickIdx, :);
					csum = sum(Asel, 1);
					% Each chosen cell must have >=1 active AND >=1 negative trial
					if any(csum < 1) || any(csum >= nT)
						continue;
					end
					if any(sum(Isel, 1) < 1)
						continue;
					end
					s = iAvgHamming(Asel);
					if s > bestScore
						bestScore = s;
						best.CellUIDs = cellUIDsAll(cIdx);
						best.TrialUIDs = uint64(trialUIDsAll(pickIdx));
						best.Active = logical(Asel);
						best.Inactive = logical(Isel);
						best.Z = Z(pickIdx, :, cIdx);
					end
				end
				if bestScore > -inf
					ok = true;
					out = best;
					return;
				end
			end
		end
	end
end

function [ok, out] = iSelectHighSD(cellUIDsAll, trialUIDsAll, Z, A, I, nTrialsDesired)
	% Higher inter-cell SD constraints (per outline)
	% - 3~4 cells, 3~4 trials
	% - For each chosen cell: across chosen trials, 1s is either always active OR always negative
	% - Each chosen trial contains at least one active and one negative cell

	ok = false;
	out = struct();

	% prefer cells with some activity (to allow 2~4 actives)
	colSum = sum(A, 1, 'omitnan');
	idxCandCells = find(colSum >= 2);
	if numel(idxCandCells) < 6
		return;
	end
	[~, o] = sortrows([(-colSum(idxCandCells)).', double(cellUIDsAll(idxCandCells))], [1 2]);
	idxCandCells = idxCandCells(o);
	idxCandCells = idxCandCells(1:min(24, numel(idxCandCells)));

	for nCells = [4 3]
		comb = nchoosek(1:numel(idxCandCells), nCells);
		bestN = 0;
		best = struct();
		for i = 1:size(comb,1)
			cIdx = idxCandCells(comb(i,:));
			Acs = A(:, cIdx);
			Ics = I(:, cIdx);
			rsum = sum(Acs, 2);
			idxTrials = find(rsum >= 2 & rsum <= min(4, nCells));
			if numel(idxTrials) < 3
				continue;
			end
			P = iRowPattern(Acs(idxTrials,:));
			[uP, ~, gP] = unique(P, 'stable');
			% we need a pattern repeated >=3
			for pIdx = 1:numel(uP)
				rowsP = idxTrials(gP == pIdx);
				if numel(rowsP) < 3
					continue;
				end
				% pick 4 if available, else 3
				if ~isempty(nTrialsDesired) && isfinite(nTrialsDesired)
					nT = nTrialsDesired;
					if numel(rowsP) < nT
						continue;
					end
				else
					nT = min(4, numel(rowsP));
					nT = max(3, nT);
				end
				pickIdx = rowsP(1:nT);
				Asel = Acs(pickIdx, :);
				Isel = Ics(pickIdx, :);
				% sanity: all rows identical (active set stable)
				if ~all(all(Asel == Asel(1,:), 2))
					continue;
				end
				% enforce that non-active cells are truly negative across all selected trials
				inactiveCols = ~logical(Asel(1,:));
				if any(inactiveCols) && ~all(all(Isel(:, inactiveCols)))
					continue;
				end
				% also require at least one active and one negative cell (then every trial has both)
				if ~any(Asel(1,:)) || ~any(inactiveCols)
					continue;
				end
				if nT > bestN
					bestN = nT;
					best.CellUIDs = cellUIDsAll(cIdx);
					best.TrialUIDs = uint64(trialUIDsAll(pickIdx));
					best.Active = logical(Asel);
					best.Inactive = logical(Isel);
					best.Z = Z(pickIdx, :, cIdx);
				end
			end
		end
		if bestN >= 3
			ok = true;
			out = best;
			return;
		end
	end
end

function [X, cellUIDs, trialUIDs] = iFetchMatrix(Ts, cellUIDs, trialUIDs, nTime)
	cellUIDs = uint64(cellUIDs(:));
	trialUIDs = uint64(trialUIDs(:));
	trialUIDs = unique(trialUIDs, 'stable');
	cellUIDs = unique(cellUIDs, 'stable');

	idxT = ismember(uint64(Ts.TrialUID), trialUIDs);
	Ts1 = Ts(idxT, {'CellUID','TrialUID','ResampledSignal'});
	idxC = ismember(uint64(Ts1.CellUID), cellUIDs);
	Ts1 = Ts1(idxC, :);

	% Keep only pairs that exist
	cellUIDs = intersect(cellUIDs, uint64(Ts1.CellUID));
	trialUIDs = intersect(trialUIDs, uint64(Ts1.TrialUID));
	cellUIDs = unique(cellUIDs, 'stable');
	trialUIDs = unique(trialUIDs, 'stable');

	nC = numel(cellUIDs);
	nT = numel(trialUIDs);
	X = nan(nT, nTime, nC);

	[tfC, iC] = ismember(uint64(Ts1.CellUID), cellUIDs);
	[tfT, iT] = ismember(uint64(Ts1.TrialUID), trialUIDs);
	ok = tfC & tfT;
	iC = iC(ok);
	iT = iT(ok);
	sig = Ts1.ResampledSignal(ok, :);

	if isnumeric(sig) && size(sig,2) == nTime
		for k = 1:size(sig,1)
			X(iT(k), :, iC(k)) = double(sig(k, :));
		end
		return;
	end

	if iscell(sig)
		for k = 1:numel(sig)
			try
				v = sig{k};
				if numel(v) ~= nTime
					continue;
				end
				X(iT(k), :, iC(k)) = double(v(:));
			catch
			end
		end
		return;
	end
end

function P = iRowPattern(A)
	% A: nRow x nCol logical
	A = logical(A);
	P = zeros(size(A,1), 1, 'uint32');
	for j = 1:size(A,2)
		P = bitor(P, uint32(A(:,j)) * bitshift(uint32(1), j-1));
	end
end

function s = iAvgHamming(A)
	A = logical(A);
	n = size(A,1);
	if n < 2
		s = 0; return;
	end
	acc = 0;
	cnt = 0;
	for i = 1:n
		for j = i+1:n
			acc = acc + sum(xor(A(i,:), A(j,:)));
			cnt = cnt + 1;
		end
	end
	s = acc / max(cnt,1);
end

function [pickIdx, Asel] = iPickTrialsHigh(Acs, trialChoices)
	% trialChoices: cell(nT,1), each contains trial indices in the FULL Acs row-space
	nT = numel(trialChoices);
	pickIdx = [];
	Asel = [];

	% simple depth-first search over bounded choices (<=5^4)
	cur = zeros(nT,1);
	best = [];
	bestScore = -inf;

	function dfs(k)
		if k > nT
			idx = cur;
			if numel(unique(idx)) ~= nT
				return;
			end
			A0 = Acs(idx, :);
			% enforce all rows different (pairwise) for high divergence
			if numel(unique(iRowPattern(A0))) ~= nT
				return;
			end
			s = iAvgHamming(A0);
			if s > bestScore
				bestScore = s;
				best = idx;
			end
			return;
		end
		choices = trialChoices{k};
		for ii = 1:numel(choices)
			cur(k) = choices(ii);
			dfs(k+1);
		end
	end

	dfs(1);
	if ~isempty(best)
		pickIdx = best;
		Asel = Acs(pickIdx, :);
	end
end

function T = iTableQueryOrEmpty(DS, queryStruct)
	try
		args = namedargs2cell(queryStruct);
		T = DS.TableQuery(["Mouse","DateTime","TrialUID"], args{:});
	catch
		T = table;
	end
end

function dt = iNormalizeDateTime(dt)
	% TableQuery may return datetime, duration, or cell arrays depending on backend.
	try
		if iscell(dt)
			dt = cellfun(@(x) x, dt);
		end
		if isduration(dt)
			dt = datetime(dt, 'ConvertFrom', 'datenum');
		end
	catch
	end
end

function s = iLabelOfQuery(q)
	f = string(fieldnames(q));
	s = strings(numel(f),1);
	for i = 1:numel(f)
		v = q.(f{i});
		s(i) = string(f{i}) + "=" + string(v);
	end
	s = strjoin(s, ",");
end
