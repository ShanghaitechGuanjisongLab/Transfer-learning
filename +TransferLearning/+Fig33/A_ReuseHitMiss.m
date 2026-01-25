% 图3.2b（新口径预览）：Transfer LightWater 会话内 Hit vs Miss 的复用表型（同鼠配对）
%
% Primary metric (forward reuse, updated):
%   Reuse (1 s) = P(TransferLight active at 1 s | LearnedAudio active at 1 s)
% computed within the SAME mouse.
%
% Implementation notes:
% - Use QueryNTATS (Median) directly; no manual TrialSignals aggregation.
% - Default is phase-level pooling per mouse:
%     Learned:  Phase=Learned,  Stimulus=AudioWater
%     Transfer: Phase=Transfer, Stimulus=LightWater, split by Behavior (Hit/Miss)
%   This avoids dropping mice due to session Hit/Miss imbalance.
% - Active definition (updated):
%     value(1s) > mean(-3~0s) + 3*std(-3~0s)
%   applied to the per-cell median trial trace from QueryNTATS (ZScore baseline indices 1:24).
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution (hard requirements):
% - This file MUST remain a SCRIPT (do not convert to a function).
% - Call it like a function via the package name (do NOT use run):
%     TransferLearning.Fig32.B_ReuseHitMiss_ActiveAt1s

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
excludeMice = string([]);

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
xs = TransferLearning.Xs; % duration(48x1)
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
if ~any(baseMask) || ~any(winMask)
	error('Fig3_2b1s:BadTimeMask', 'Baseline or response window has no samples.');
end
idx1 = find(xsSec == 1, 1, 'first');
if isempty(idx1)
	[~, idx1] = min(abs(xsSec - 1));
end
kSigma = 3;

% --- 1) Determine mice from raw trial table (for diagnostics only)
Tlearn = iTableQueryOrEmpty(DS, ["Mouse"], Phase="Learned", Stimulus="AudioWater");
Ttran  = iTableQueryOrEmpty(DS, ["Mouse"], Phase="Transfer", Stimulus="LightWater");
if isempty(Tlearn) || isempty(Ttran)
	error('Fig3_2b1s:MissingTrials', 'Missing Learned(AudioWater) or Transfer(LightWater) trials in dataset.');
end
Tlearn.Mouse = string(Tlearn.Mouse);
Ttran.Mouse = string(Ttran.Mouse);
Tlearn = Tlearn(~ismember(Tlearn.Mouse, excludeMice), :);
Ttran  = Ttran(~ismember(Ttran.Mouse, excludeMice), :);
mice = intersect(unique(Tlearn.Mouse), unique(Ttran.Mouse));
if isempty(mice)
	error('Fig3_2b1s:NoCommonMice', 'No mice have both Learned(AudioWater) and Transfer(LightWater).');
end

% --- 2) Per mouse: compute reuse(Hit/Miss) from QueryNTATS
rows = table;
skip = strings(0,2);
layerNames = string(["MOp2/3","MOp5"]);
detail = table(string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), false(0,1), ...
	'VariableNames', {'Mouse','ZLayer','NCellsLayer','NLearnedActive','Included'});

for iM = 1:numel(mice)
	m = mice(iM);

	% Trial counts (sanity)
	nLearn = iCountTrials(DS, Mouse=m, Phase="Learned", Stimulus="AudioWater");
	nHit   = iCountTrials(DS, Mouse=m, Phase="Transfer", Stimulus="LightWater", Behavior=1);
	nMiss  = iCountTrials(DS, Mouse=m, Phase="Transfer", Stimulus="LightWater", Behavior=0);

	GLearn = iQueryNTATSOrEmpty(DS, struct('Mouse',m,'Phase','Learned','Stimulus','AudioWater'));
	QT = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, repmat({m},2,1), ...
		'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior','Mouse'});
	GHM = iQueryNTATSOrEmpty(DS, QT);

	if isempty(GLearn) || isempty(GHM)
		skip(end+1,:) = [m, "QueryNTATS empty"]; %#ok<AGROW>
		continue;
	end

	XL = iNtatsData(GLearn.NTATS);
	XHM = iNtatsData(GHM.NTATS);
	if ndims(XHM) ~= 3 || size(XHM,3) < 2
		skip(end+1,:) = [m, "Bad Hit/Miss NTATS dims"]; %#ok<AGROW>
		continue;
	end

	uidL = uint64(GLearn.CellUID);
	uidHM = uint64(GHM.CellUID);
	uid = intersect(uidL, uidHM);
	if isempty(uid)
		skip(end+1,:) = [m, "No common CellUID"]; %#ok<AGROW>
		continue;
	end
	[~, iL] = ismember(uid, uidL);
	[~, iHM] = ismember(uid, uidHM);
	XL = XL(iL, :);
	XHit = XHM(iHM, :, 1);
	XMiss = XHM(iHM, :, 2);
	zlayer = iCellZLayer(DS, uid);

	for iZ = 1:numel(layerNames)
		zl = layerNames(iZ);
		maskZ = (zlayer == zl);
		nCellsLayer = nnz(maskZ);
		if ~any(maskZ)
			detail = [detail; table(m, zl, nCellsLayer, 0, false, 'VariableNames', detail.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		XLz = XL(maskZ, :);
		XHitz = XHit(maskZ, :);
		XMissz = XMiss(maskZ, :);

		learnAct = iActiveAt1s(XLz, baseMask, idx1, kSigma);
		nLearnAct = nnz(learnAct);
		isIn = nCellsLayer > 0;
		detail = [detail; table(m, zl, nCellsLayer, nLearnAct, isIn, 'VariableNames', detail.Properties.VariableNames)]; %#ok<AGROW>
		hitAct   = iActiveAt1s(XHitz, baseMask, idx1, kSigma);
		missAct  = iActiveAt1s(XMissz, baseMask, idx1, kSigma);

		den = learnAct;

		reuseHit  = NaN;
		reuseMiss = NaN;
		meanPkHit = NaN;
		meanPkMiss = NaN;
		medLatHit = NaN;
		medLatMiss = NaN;
		if nnz(den) > 0
			reuseHit  = mean(double(hitAct(den)),  'omitnan');
			reuseMiss = mean(double(missAct(den)), 'omitnan');
			[pkHit, latHit]   = iPeakAndLatency(XHitz(den,:), xsSec, winMask);
			[pkMiss, latMiss] = iPeakAndLatency(XMissz(den,:), xsSec, winMask);
			meanPkHit = mean(pkHit,'omitnan');
			meanPkMiss = mean(pkMiss,'omitnan');
			medLatHit = median(latHit,'omitnan');
			medLatMiss = median(latMiss,'omitnan');
		end

		rows = [rows; table( ...
			m, zl, nLearn, nHit, nMiss, nnz(maskZ), nnz(maskZ), nnz(den), ...
			reuseHit, reuseMiss, ...
			meanPkHit, meanPkMiss, ...
			medLatHit, medLatMiss, ...
			'VariableNames', { ...
				'Mouse','ZLayer','NTrialsLearned','NTrialsHit','NTrialsMiss','NCellsLearned','NCellsTransferHM','NCellsUsed', ...
				'ReuseHit','ReuseMiss', ...
				'MeanPeakHit','MeanPeakMiss', ...
				'MedianLatencyHit','MedianLatencyMiss' ...
			})]; %#ok<AGROW>
	end
end

if isempty(rows)
	error('Fig3_2b1s:NoValidMice', 'No mice passed requirements.');
end

rows = sortrows(rows, "Mouse");
assignin('base','Fig3_2b1s_ReuseHitMiss_Summary', rows);
assignin('base','Fig3_2b1s_ReuseHitMiss_LayerDetail', detail);
if ~isempty(skip)
	assignin('base','Fig3_2b1s_ReuseHitMiss_Skipped', array2table(skip, 'VariableNames', {'Mouse','Reason'}));
end

% --- 3) Stats (paired) by layer
for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	R = rows(rows.ZLayer == zl, :);
	mask = isfinite(R.ReuseHit) & isfinite(R.ReuseMiss);
	p = NaN;
	if nnz(mask) >= 4
		p = signrank(R.ReuseHit(mask), R.ReuseMiss(mask), 'tail','right');
	end
	fprintf('Fig3.2b (%s) reuse (Hit>Miss) signrank p=%.4g (n=%d)\n', zl, p, nnz(mask));
end

% --- 3.5) Coverage diagnostics
allMice = unique(string(rows.Mouse));
cov = table;
cov.Mouse = allMice;
for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	has = ismember(allMice, unique(string(rows.Mouse(rows.ZLayer==zl))));
	cov.(matlab.lang.makeValidName(char(zl))) = has;
end
assignin('base','Fig3_2b1s_ReuseHitMiss_LayerCoverage', cov);

%% 
% --- Plot (paired) by layer
svgName = "Fig3_3a_Reuse_HitMiss_ActiveAt1s.svg";
f = figure('Color','w', 'Name','Fig3.2b Reuse Hit vs Miss (by layer, active at 1 s)');
MATLAB.Graphics.FigureAspectRatio(8,5,1/2);
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

ylabel(TL, 'Reuse (1 s)');

axesList = gobjects(0,1);
pvals = nan(numel(layerNames),1);
nPairs = zeros(numel(layerNames),1);
hitVals = cell(numel(layerNames),1);
missVals = cell(numel(layerNames),1);

for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	R = rows(rows.ZLayer == zl, :);
	if isempty(R)
		continue;
	end

	x = R.ReuseHit;
	y = R.ReuseMiss;
	mask = isfinite(x) & isfinite(y);
	hitVals{iZ} = x(mask);
	missVals{iZ} = y(mask);
	pp = NaN;
	if nnz(mask) >= 4
		pp = signrank(x(mask), y(mask), 'tail','right');
	end

	ax = nexttile(TL, iZ);
	axesList(end+1,1) = ax; %#ok<AGROW>
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	Y = [R.ReuseHit, R.ReuseMiss];
	plot(ax, [1 2], Y', '-o', ...
		'Color', [0.60 0.60 0.60], ...
		'MarkerSize', 4, ...
		'MarkerFaceColor', [0.60 0.60 0.60]);

	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	nPair = nnz(isfinite(R.ReuseHit) & isfinite(R.ReuseMiss));
	pvals(iZ) = pp;
	nPairs(iZ) = nPair;
	ax.XTickLabel = {sprintf('Hit (n=%d)', nPair), sprintf('Miss (n=%d)', nPair)};
	grid(ax,'on');
	box(ax,'off');
	title(ax, sprintf('%s', zl), 'Interpreter','none');
	if iZ == numel(layerNames)
		try
			ax.YAxis.Visible = 'off';
		catch
		end
	end
end

% Keep MATLAB auto y-lims, but unify across layers
try
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

% --- Significance annotation (paired signrank p) per layer
for iZ = 1:min(numel(layerNames), numel(axesList))
	ax = axesList(iZ);
	if ~isgraphics(ax)
		continue;
	end
	pp = pvals(iZ);
	if ~isfinite(pp)
		continue;
	end
	try
		% p-value line (via MATLAB.Graphics.PLine)
		xh = hitVals{iZ};
		ym = missVals{iZ};
		if isempty(xh) || isempty(ym)
			continue;
		end
		S = scatter(ax, [ones(numel(xh),1); 2*ones(numel(ym),1)], [xh(:); ym(:)], ...
			1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
		try
			if isprop(S, 'HitTest'); S.HitTest = 'off'; end
			if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
			if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
		except
		end
		Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', pp), 0, ...
			'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
		MATLAB.Graphics.PLine(Descriptors);
		try
			delete(S);
		catch
		end
	catch
	end
end

sgtitle(TL, 'Transfer phase Hit vs Miss (paired) by ZLayer (active at 1 s)', 'Interpreter','none');

% --- 5) Export (SVG only)
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
function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	if ismember('DateTime', T.Properties.VariableNames)
		try
			T.DateTime = datetime(T.DateTime);
			T.DateTime.TimeZone = '';
		catch
		end
	end
end

function n = iCountTrials(DS, varargin)
	n = 0;
	try
		Tu = DS.TableQuery("TrialUID", varargin{:});
		if isempty(Tu)
			return;
		end
		n = numel(unique(uint64(Tu.TrialUID)));
	catch
		n = 0;
	end
end

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function z = iCellZLayer(DS, cellUID)
	z = strings(size(cellUID));
	try
		C = DS.Cells;
		[tf, loc] = ismember(uint64(cellUID), uint64(C.CellUID));
		z(tf) = string(C.ZLayer(loc(tf)));
		z(~tf) = "";
	catch
		z(:) = "";
	end
end

function act = iActiveAt1s(X, baseMask, idx1, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	val1 = X(:, idx1);
	act = val1 > (baseMu + kSigma .* baseSd);
end

function [pk, lat] = iPeakAndLatency(X, xsSec, winMask)
	% X: [nCells x nTime] (already z-scored). Latency is time of peak within win.
	if isempty(X)
		pk = nan(0,1);
		lat = nan(0,1);
		return;
	end
	Xw = X(:, winMask);
	[pk, idx] = max(Xw, [], 2, 'omitnan');
	tw = xsSec(winMask);
	idx(~isfinite(pk)) = 1;
	lat = tw(idx);
	lat(~isfinite(pk)) = NaN;
end