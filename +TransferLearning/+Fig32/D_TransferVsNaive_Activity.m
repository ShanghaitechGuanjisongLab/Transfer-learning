% 图3.2d：Transfer vs Naive 的 LightWater 是否更“活跃/更多/更早”，以及是否主要由 LearnedAudio 复用细胞承载
%
% Cross-cohort (unpaired) comparison (imaging cohorts):
% - Naive LightWater: TransferLearning.LightAudioBaseline(), Phase=Naive, Stimulus=LightWater
% - Transfer LightWater: TransferLearning.AudioLightBaseline(), Phase=Transfer, Stimulus=LightWater
% Using each mouse's FIRST LightWater session in that phase.
%
% Required computation:
% - Median per-cell response must come from QueryNTATS:
%     DS.QueryNTATS(..., UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median)
%
% Per-mouse metrics (from per-cell median trial trace):
% - ActiveRate: fraction of cells active
% - NActive: number of active cells
% - MeanPeakActive: mean 0~1s peak among active cells
% - MedianLatencyActive: median peak latency (0~1s) among active cells
%
% LearnedAudio contribution (transfer cohort only):
% - ReuseAmongTransferActive = P(LearnedAudio active | TransferLight active)
% - Reuse vs New within transfer: compare peak/latency (paired across mice)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution (hard requirements):
% - This file MUST remain a SCRIPT (do not convert to function).
% - Do NOT use run.
% - Open in MATLAB Editor and Run/F5.

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2d_TransferVsNaive_Activity.svg";
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

LAB = TransferLearning.LightAudioBaseline();
ALB = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
winMask  = (xsSec >= 0) & (xsSec <= 1);
xsWin = xsSec(winMask);
kSigma = 3;
minTrials = 1;

% --- 1) Query per-trial tables
Tnaive = iTableQueryOrEmpty(LAB, ["TrialUID","Mouse","DateTime","Phase","Stimulus","Behavior"], Phase="Naive", Stimulus="LightWater");
Ttran  = iTableQueryOrEmpty(ALB, ["TrialUID","Mouse","DateTime","Phase","Stimulus","Behavior"], Phase="Transfer", Stimulus="LightWater");
Tlearn = iTableQueryOrEmpty(ALB, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Phase="Learned", Stimulus="AudioWater");

if isempty(Tnaive) || isempty(Ttran)
	error('Fig3_2d:MissingTrials', 'Missing Naive(LightWater) or Transfer(LightWater) trials in imaging cohorts.');
end

Tnaive.Mouse = string(Tnaive.Mouse);
Ttran.Mouse  = string(Ttran.Mouse);
Tlearn.Mouse = string(Tlearn.Mouse);

Tnaive = Tnaive(~ismember(Tnaive.Mouse, excludeMice), :);
Ttran  = Ttran(~ismember(Ttran.Mouse, excludeMice), :);
Tlearn = Tlearn(~ismember(Tlearn.Mouse, excludeMice), :);

% --- 2) Per-mouse session metrics
naiveRows = iPerMouseFirstSessionMetrics(LAB, Tnaive, "Naive", "LightWater", baseMask, winMask, xsWin, kSigma, minTrials);
tranRows  = iPerMouseFirstSessionMetrics(ALB, Ttran,  "Transfer", "LightWater", baseMask, winMask, xsWin, kSigma, minTrials);

naiveRows.Group(:) = "Naive";
tranRows.Group(:)  = "Transfer";

allRows = [naiveRows; tranRows];
assignin('base','Fig3_2d_TransferVsNaive_Activity_Rows', allRows);

% --- 3) Stats (unpaired)
S = struct;
[S.ActiveRateP, S.ActiveRateStats] = iRankSum(naiveRows.ActiveRate, tranRows.ActiveRate);
[S.NActiveP,    S.NActiveStats]    = iRankSum(naiveRows.NActive,    tranRows.NActive);
[S.PeakP,       S.PeakStats]       = iRankSum(naiveRows.MeanPeakActive, tranRows.MeanPeakActive);
[S.LatP,        S.LatStats]        = iRankSum(naiveRows.MedianLatencyActive, tranRows.MedianLatencyActive);

fprintf('Fig3.2d ranksum p: ActiveRate=%.3g, NActive=%.3g, Peak=%.3g, Latency=%.3g\n', ...
	S.ActiveRateP, S.NActiveP, S.PeakP, S.LatP);

% --- 4) LearnedAudio contribution within transfer
tranContrib = iTransferReuseContribution(ALB, Tlearn, Ttran, baseMask, winMask, xsWin, kSigma, minTrials);
assignin('base','Fig3_2d_Transfer_ReuseContribution', tranContrib);

pReusePeak = NaN;
pReuseLat  = NaN;
maskP = isfinite(tranContrib.MeanPeakReuse) & isfinite(tranContrib.MeanPeakNew);
maskL = isfinite(tranContrib.MedianLatReuse) & isfinite(tranContrib.MedianLatNew);
if nnz(maskP) >= 4
	pReusePeak = signrank(tranContrib.MeanPeakReuse(maskP), tranContrib.MeanPeakNew(maskP), 'tail','right');
end
if nnz(maskL) >= 4
	pReuseLat = signrank(tranContrib.MedianLatReuse(maskL), tranContrib.MedianLatNew(maskL), 'tail','left');
end
fprintf('Transfer within-mouse (Reuse vs New): peak p=%.3g, latency p=%.3g\n', pReusePeak, pReuseLat);

% --- 5) Plot
f = figure('Color','w', 'Name','Fig3.2d Transfer vs Naive activity');
try
	MATLAB.Graphics.FigureAspectRatio(9,6,1/2);
catch
end
TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax1 = iSwarm2(TL, 1, naiveRows.ActiveRate, tranRows.ActiveRate, 'Active cell rate', 'LightWater first session', S.ActiveRateP);
ylim(ax1, [0 1]);

ax2 = iSwarm2(TL, 2, naiveRows.NActive, tranRows.NActive, 'N active cells', 'LightWater first session', S.NActiveP);

ax3 = iSwarm2(TL, 3, naiveRows.MeanPeakActive, tranRows.MeanPeakActive, 'Mean peak (0~1s) among active', 'LightWater first session', S.PeakP);

ax4 = nexttile(TL, 4);
hold(ax4,'on');
try
	if isprop(ax4, 'Toolbar') && ~isempty(ax4.Toolbar)
		ax4.Toolbar.Visible = 'off';
	end
catch
end

% reuse contribution distribution (transfer only)
rf = tranContrib.ReuseAmongTransferActive;
rf = rf(isfinite(rf));
swarmchart(ax4, ones(numel(rf),1), rf, 18, 'filled');
ax4.XLim = [0.5 1.5];
ax4.XTick = 1;
ax4.XTickLabel = {sprintf('Transfer (n=%d)', numel(rf))};
ylabel(ax4, 'P(LearnedAudio active | Transfer active)');
ylim(ax4, [0 1]);
grid(ax4,'on');
box(ax4,'on');
if isfinite(pReusePeak) || isfinite(pReuseLat)
	title(ax4, sprintf('Contribution of LearnedAudio cells | peak p=%.3g, lat p=%.3g', pReusePeak, pReuseLat), 'Interpreter','none');
else
	title(ax4, 'Contribution of LearnedAudio cells', 'Interpreter','none');
end

sgtitle(TL, 'Fig3.2d: Transfer vs Naive LightWater activity + LearnedAudio contribution', 'Interpreter','none');

% --- 6) Export (SVG only)
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

function cellUID = iMouseCellUID(DS, mouseName)
	cellUID = uint64([]);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({'Mouse','CellUID'}, C.Properties.VariableNames))
			return;
		end
		m = string(mouseName);
		C.Mouse = string(C.Mouse);
		cellUID = unique(uint64(C.CellUID(C.Mouse == m)));
	catch
		cellUID = uint64([]);
	end
end

function Z = iMedianTraceZScore(DS, cellUID, trialUID, baseMask)
	% Returns a table with per-cell median trial trace (ZScore) for given TrialUIDs.
	Z = [];
	if isempty(cellUID) || isempty(trialUID)
		return;
	end
	q = struct('CellUID', uint64(cellUID), 'TrialUID', uint64(trialUID));
	G = iQueryNTATSOrEmpty(DS, q);
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	if nargin >= 4 && ~isempty(baseMask)
		try
			if size(X,2) ~= numel(baseMask)
				return;
			end
		catch
		end
	end
	Z = table(uint64(G.CellUID), X, 'VariableNames', {'CellUID','Trace'});
end

function ax = iSwarm2(TL, tileIdx, y1, y2, ylab, ttl, pval)
	ax = nexttile(TL, tileIdx);
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end
	x1 = ones(numel(y1),1);
	x2 = 2*ones(numel(y2),1);
	swarmchart(ax, x1, y1, 18, 'filled');
	swarmchart(ax, x2, y2, 18, 'filled');
	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('Naive (n=%d)', numel(y1)), sprintf('Transfer (n=%d)', numel(y2))};
	ylabel(ax, ylab);
	grid(ax,'on');
	box(ax,'on');
	if isfinite(pval)
		title(ax, sprintf('%s | ranksum p=%.3g', ttl, pval), 'Interpreter','none');
	else
		title(ax, ttl, 'Interpreter','none');
	end
end

function act = iMedianActive(X, baseMask, winMask, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	winMx = max(X(:, winMask), [], 2, 'omitnan');
	act = winMx > (baseMu + kSigma .* baseSd);
end

function [pk, lat] = iPeakAndLatency(X, xsWin)
	if isempty(X)
		pk = nan(0,1);
		lat = nan(0,1);
		return;
	end
	[pk, idx] = max(X, [], 2, 'omitnan');
	idx(~isfinite(pk)) = 1;
	lat = xsWin(idx);
	lat(~isfinite(pk)) = NaN;
end

function rows = iPerMouseFirstSessionMetrics(DS, T, phaseName, stimulusName, baseMask, winMask, xsWin, kSigma, minTrials)
	mice = unique(string(T.Mouse));
	rows = table(string.empty(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		string.empty(0,1), ...
		'VariableNames', {'Mouse','DateTime','NTrials','NCellsUsed','NActive','ActiveRate','MeanPeakActive','MedianLatencyActive','Group'});
	for iM = 1:numel(mice)
		m = mice(iM);
		Ti = T(string(T.Mouse)==m & string(T.Phase)==string(phaseName) & string(T.Stimulus)==string(stimulusName), :);
		if isempty(Ti)
			continue;
		end
		Ti = sortrows(Ti, 'DateTime');
		dt = Ti.DateTime(1);
		tu = unique(uint64(Ti.TrialUID(Ti.DateTime==dt)));
		if numel(tu) < minTrials
			continue;
		end
		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end
		Z = iMedianTraceZScore(DS, cellUID, tu, baseMask);
		if isempty(Z) || height(Z) < 10
			continue;
		end
		act = iMedianActive(Z.Trace, baseMask, winMask, kSigma);
		Xw = Z.Trace(:, winMask);
		[pkAll, latAll] = iPeakAndLatency(Xw, xsWin);
		pk = pkAll(act);
		lat = latAll(act);
		rows = [rows; table(m, dt, numel(tu), height(Z), nnz(act), nnz(act)/height(Z), mean(pk,'omitnan'), median(lat,'omitnan'), "", ...
			'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function [p, stats] = iRankSum(x, y)
	x = x(isfinite(x));
	y = y(isfinite(y));
	p = NaN;
	stats = struct('zval', NaN, 'n1', numel(x), 'n2', numel(y));
	if numel(x) < 3 || numel(y) < 3
		return;
	end
	try
		[p, ~, st] = ranksum(x, y);
		stats.zval = st.zval;
	catch
	end
end

function out = iTransferReuseContribution(DS, Tlearn, Ttran, baseMask, winMask, xsWin, kSigma, minTrials)
	mice = intersect(unique(string(Tlearn.Mouse)), unique(string(Ttran.Mouse)));
	out = table(string.empty(0,1), NaT(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer','NCellsUsed','NTransferActive','ReuseAmongTransferActive','MeanPeakReuse','MeanPeakNew','MedianLatReuse','MedianLatNew'});
	for iM = 1:numel(mice)
		m = mice(iM);
		Tl = Tlearn(string(Tlearn.Mouse)==m & string(Tlearn.Phase)=="Learned" & string(Tlearn.Stimulus)=="AudioWater", :);
		Tt = Ttran(string(Ttran.Mouse)==m & string(Ttran.Phase)=="Transfer" & string(Ttran.Stimulus)=="LightWater", :);
		if isempty(Tl) || isempty(Tt)
			continue;
		end
		Tl = sortrows(Tl, 'DateTime');
		Tt = sortrows(Tt, 'DateTime');
		dtL = Tl.DateTime(end);
		dtT = Tt.DateTime(1);
		tuL = unique(uint64(Tl.TrialUID(Tl.DateTime==dtL)));
		tuT = unique(uint64(Tt.TrialUID(Tt.DateTime==dtT)));
		if numel(tuL) < minTrials || numel(tuT) < minTrials
			continue;
		end
		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end
		ZL = iMedianTraceZScore(DS, cellUID, tuL, baseMask);
		ZT = iMedianTraceZScore(DS, cellUID, tuT, baseMask);
		c = intersect(ZL.CellUID, ZT.CellUID);
		if numel(c) < 10
			continue;
		end
		ZL = sortrows(ZL(ismember(ZL.CellUID,c),:), 'CellUID');
		ZT = sortrows(ZT(ismember(ZT.CellUID,c),:), 'CellUID');
		learnAct = iMedianActive(ZL.Trace, baseMask, winMask, kSigma);
		tranAct  = iMedianActive(ZT.Trace, baseMask, winMask, kSigma);
		if nnz(tranAct) < 10
			continue;
		end

		reuseAmong = nnz(learnAct & tranAct) / nnz(tranAct);

		Xw = ZT.Trace(:, winMask);
		[pkAll, latAll] = iPeakAndLatency(Xw, xsWin);

		reuseCells = learnAct & tranAct;
		newCells = (~learnAct) & tranAct;

		meanPkReuse = mean(pkAll(reuseCells), 'omitnan');
		meanPkNew   = mean(pkAll(newCells),   'omitnan');

		medLatReuse = median(latAll(reuseCells), 'omitnan');
		medLatNew   = median(latAll(newCells),   'omitnan');

		out = [out; table(m, dtL, dtT, numel(c), nnz(tranAct), reuseAmong, meanPkReuse, meanPkNew, medLatReuse, medLatNew, ...
			'VariableNames', out.Properties.VariableNames)]; %#ok<AGROW>
	end
	out = sortrows(out, 'ReuseAmongTransferActive');
end
