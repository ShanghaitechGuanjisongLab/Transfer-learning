% 图3.3a：示例细胞钙曲线（高散度 vs 低散度）
%
% High divergence example (within ONE mouse):
% - Choose 3~4 cells (same mouse)
% - Choose 3~4 trials from a Naive-stage session (see config below)
% - In each chosen trial: only 1~3 cells are active
% - Active-cell sets are NOT identical across trials
% - Each cell is active in only 1~3 trials
%
% Low divergence example (within ONE mouse):
% - Choose 3~4 cells (same mouse)
% - Choose 3~4 trials from a Learned AudioWater session
% - In each chosen trial: 2~4 cells are active
% - Active-cell sets are identical across chosen trials
%   (so each cell is either always active or always inactive)
%
% Signal:
% - Use ResampledSignal (48 points, aligned to cue)
% - ZScore per trial using baseline -3~0s
% - Active criterion: max(0~1s) > kSigma
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   IMPORTANT: MUST REMAIN A SCRIPT (do not convert to a function).
%   Call via package name (do NOT use run):
%     TransferLearning.Fig33.A_DivergenceExampleCells

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3a_DivergenceExampleCells.svg";

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

DS = TransferLearning.AudioLightBaseline();
Ts = DS.TrialSignals;
C = DS.Cells;

xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
plotMask = (xsSec >= -2) & (xsSec <= 2);
xsPlot = xsSec(plotMask);

if ~any(baseMask)
	error('Fig3_3a:NoBaselineSamples', 'baseline window -3~0s has no samples in TransferLearning.Xs');
end
if ~any(winMask)
	error('Fig3_3a:NoWindowSamples', 'response window 0~1s has no samples in TransferLearning.Xs');
end
if ~any(plotMask)
	error('Fig3_3a:NoPlotSamples', 'plot window -2~2s has no samples in TransferLearning.Xs');
end

kSigma = 3;

% --- 1) Define which session type to use for the "high divergence" example
% NOTE: In this dataset, Phase="Naive" has no Stimulus="LightWater".
% We therefore attempt Naive+LightWater first, and if empty fall back to
% Naive+LightOnly within LAuW design.

highQueryPrimary = struct('Phase','Naive','Stimulus','LightWater');
highQueryFallback = struct('Phase','Naive','Design','LAuW','Stimulus','LightOnly');

lowQuery = struct('Phase','Learned','Stimulus','AudioWater');

% --- 2) Find examples (deterministic search)
[highEx, highLabel] = iFindExample(DS, Ts, C, highQueryPrimary, highQueryFallback, xsSec, baseMask, winMask, kSigma, "high");
[lowEx,  lowLabel ] = iFindExample(DS, Ts, C, lowQuery,          struct(),        xsSec, baseMask, winMask, kSigma, "low");

assignin('base', 'Fig3_3a_HighDivergenceExample', highEx);
assignin('base', 'Fig3_3a_LowDivergenceExample',  lowEx);

% --- 3) Plot
nCols = max([numel(highEx.TrialUIDs), numel(lowEx.TrialUIDs)]);

figName = sprintf('Fig3.3a Divergence examples (High=%s, Low=%s)', highEx.Mouse, lowEx.Mouse);
f = figure('Color','w', 'Name', figName);
MATLAB.Graphics.FigureAspectRatio(10, 6, 1/2);

TL = tiledlayout(2, nCols, 'TileSpacing','compact', 'Padding','compact');

axesList = gobjects(0,1);

% --- High divergence row
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
	xlim(ax, [-2 2]);
	if j <= numel(highEx.TrialUIDs)
		Z = highEx.Z(:, :, :);
		Zj = squeeze(Z(j, plotMask, :)); % 48->plot points
		col = lines(size(Zj,2));
		for cIdx = 1:size(Zj,2)
			plot(ax, xsPlot, Zj(:,cIdx), 'LineWidth', 1.0, 'Color', col(cIdx,:), 'DisplayName', sprintf('CellUID=%d', highEx.CellUIDs(cIdx)));
		end
		TransferLearning.DrawCueWaterLines(ax);
		title(ax, sprintf('High: Trial %d', j), 'Interpreter','none');
		if j == 1
			lg = legend(ax, 'show', 'Location','best');
			try
				lg.Box = 'off';
			catch
			end
		end
	else
		axis(ax,'off');
	end
end

% --- Low divergence row
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
	xlim(ax, [-2 2]);
	if j <= numel(lowEx.TrialUIDs)
		Z = lowEx.Z(:, :, :);
		Zj = squeeze(Z(j, plotMask, :));
		col = lines(size(Zj,2));
		for cIdx = 1:size(Zj,2)
			plot(ax, xsPlot, Zj(:,cIdx), 'LineWidth', 1.0, 'Color', col(cIdx,:), 'DisplayName', sprintf('CellUID=%d', lowEx.CellUIDs(cIdx)));
		end
		TransferLearning.DrawCueWaterLines(ax);
		title(ax, sprintf('Low: Trial %d', j), 'Interpreter','none');
		if j == 1
			lg = legend(ax, 'show', 'Location','best');
			try
				lg.Box = 'off';
			catch
			end
		end
	else
		axis(ax,'off');
	end
end

% Unify Y limits across all visible axes
try
	axesVisible = axesList(isgraphics(axesList));
	MATLAB.Graphics.UnifyAxesLims(axesVisible, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesVisible, @ylim);
catch
end

% Shared labels on tiledlayout
xlabel(TL, 'Time from cue (s)');
ylabel(TL, sprintf('ZScore (baseline -3~0s), active if max(0~1s) > %.1f', kSigma));

% A concise title (no figure index)
sgtitle(TL, sprintf('Example calcium traces | High divergence: %s (%s) | Low divergence: %s (%s)', ...
	highEx.Mouse, highLabel, lowEx.Mouse, lowLabel), 'Interpreter','none');

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

function [ex, label] = iFindExample(DS, Ts, C, qPrimary, qFallback, xsSec, baseMask, winMask, kSigma, mode)
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
			warning('Fig3_3a:FallbackQuery', 'Primary query returned empty; using fallback: %s', label);
		end
	end
	if isempty(T) || height(T) == 0
		error('Fig3_3a:EmptyQuery', 'No trials returned for mode=%s.', string(mode));
	end

	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);

	% group into sessions by Mouse+DateTime
	[gSess, keyMouse, keyDT] = findgroups(T.Mouse, T.DateTime);
	sessN = splitapply(@numel, T.TrialUID, gSess);
	Sess = table(keyMouse, keyDT, sessN, 'VariableNames', {'Mouse','DateTime','NTrials'});
	Sess = sortrows(Sess, {'NTrials','Mouse','DateTime'}, {'descend','ascend','ascend'});

	ex = struct('Mode', string(mode), 'Mouse', "", 'DateTime', NaT, 'ZLayer', "", ...
		'CellUIDs', uint64([]), 'TrialUIDs', uint64([]), 'ActiveMatrix', [], 'Z', []);

	% Try top sessions until success
	maxTry = min(30, height(Sess));
	for i = 1:maxTry
		m = string(Sess.Mouse(i));
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
			[ok, out] = iTrySession(Ts, cellUIDsAll, trialUIDs, xsSec, baseMask, winMask, kSigma, mode);
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
			ex.Z = out.Z;
			fprintf('Fig3.3a %s example: Mouse=%s %s | %s | cells=[%s] trials=[%s]\n', ...
				string(mode), m, string(dt), zPick, strjoin(string(out.CellUIDs(:).'), ','), strjoin(string(out.TrialUIDs(:).'), ','));
			return;
		end
	end

	error('Fig3_3a:NoExampleFound', 'Failed to find %s example within %d sessions (query=%s).', string(mode), maxTry, label);
end

function [ok, out] = iTrySession(Ts, cellUIDsAll, trialUIDsAll, xsSec, baseMask, winMask, kSigma, mode)
	% limit trials (deterministic) to keep compute bounded
	trialUIDsAll = sort(uint64(trialUIDsAll(:)));
	maxTrials = 80;
	if numel(trialUIDsAll) > maxTrials
		trialUIDsAll = trialUIDsAll(1:maxTrials);
	end

	% Fetch all signals for these cell×trial pairs (ResampledSignal only)
	[X, cellUIDsAll, trialUIDsAll] = iFetchMatrix(Ts, cellUIDsAll, trialUIDsAll, numel(xsSec));

	% Z-score per trial per cell using baseline
	mu = mean(X(:, baseMask, :), 2, 'omitnan');
	sd = std(X(:, baseMask, :), 0, 2, 'omitnan');
	Z = (X - mu) ./ sd;

	A = squeeze(max(Z(:, winMask, :), [], 2, 'omitnan')) > kSigma; % trials x cells
	if isempty(A)
		ok = false; out = struct(); return;
	end

	if strcmpi(string(mode), "high")
		[ok, out] = iSelectHigh(cellUIDsAll, trialUIDsAll, Z, A);
	else
		[ok, out] = iSelectLow(cellUIDsAll, trialUIDsAll, Z, A);
	end
end

function [ok, out] = iSelectHigh(cellUIDsAll, trialUIDsAll, Z, A)
	% High divergence constraints
	% - 3~4 cells
	% - 3~4 trials
	% - Each chosen trial has 1~3 active cells
	% - Active sets are all different
	% - Each chosen cell active in 1~3 trials

	ok = false;
	out = struct();

	colSum = sum(A, 1, 'omitnan');
	idxCandCells = find(colSum >= 1 & colSum <= 6);
	if numel(idxCandCells) < 6
		return;
	end
	% deterministic: prefer sparser cells
	[~, o] = sortrows([colSum(idxCandCells).', double(cellUIDsAll(idxCandCells))], [1 2]);
	idxCandCells = idxCandCells(o);
	idxCandCells = idxCandCells(1:min(20, numel(idxCandCells)));

	% Try 4-cell combos first, then 3-cell
	for nCells = [4 3]
		comb = nchoosek(1:numel(idxCandCells), nCells);
		for i = 1:size(comb,1)
			cIdx = idxCandCells(comb(i,:));
			Acs = A(:, cIdx);
			% candidate trials: 1~3 actives
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
				if numel(uP) < nT
					continue;
				end
				patComb = nchoosek(1:numel(uP), nT);
				bestScore = -inf;
				best = struct();
				for j = 1:size(patComb,1)
					pp = uP(patComb(j,:));
					pickTrials = zeros(nT,1,'uint64');
					pickIdx = zeros(nT,1);
					for k = 1:nT
						idxk = idxTrials(find(gP == patComb(j,k), 1, 'first')); %#ok<FNDSB>
						pickIdx(k) = idxk;
						pickTrials(k) = trialUIDsAll(idxk);
					end
					pickIdx = unique(pickIdx, 'stable');
					if numel(pickIdx) ~= nT
						continue;
					end
					Asel = Acs(pickIdx, :);
					% per-cell active count 1~3
					csum = sum(Asel, 1);
					if any(csum < 1) || any(csum > min(3, nT))
						continue;
					end
					% trial patterns must be all unique (already by construction)
					% score: maximize average pairwise Hamming distance
					s = iAvgHamming(Asel);
					if s > bestScore
						bestScore = s;
						best.CellUIDs = cellUIDsAll(cIdx);
						best.TrialUIDs = uint64(trialUIDsAll(pickIdx));
						best.Active = logical(Asel);
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

function [ok, out] = iSelectLow(cellUIDsAll, trialUIDsAll, Z, A)
	% Low divergence constraints
	% - 3~4 cells
	% - 3~4 trials
	% - Each chosen trial has 2~4 active cells
	% - Active sets are identical across chosen trials

	ok = false;
	out = struct();

	% prefer cells with some activity (to allow 3~4 actives)
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
				nT = min(4, numel(rowsP));
				nT = max(3, nT);
				pickIdx = rowsP(1:nT);
				Asel = Acs(pickIdx, :);
				% sanity: all rows identical
				if ~all(all(Asel == Asel(1,:), 2))
					continue;
				end
				if nT > bestN
					bestN = nT;
					best.CellUIDs = cellUIDsAll(cIdx);
					best.TrialUIDs = uint64(trialUIDsAll(pickIdx));
					best.Active = logical(Asel);
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
	sig = Ts1.ResampledSignal(ok);

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
		if isstring(v) || ischar(v)
			s(i) = string(f{i}) + "=" + string(v);
		else
			s(i) = string(f{i}) + "=" + string(v);
		end
	end
	s = strjoin(s, ",");
end
