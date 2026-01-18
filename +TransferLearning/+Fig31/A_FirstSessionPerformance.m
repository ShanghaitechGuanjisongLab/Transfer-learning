% 图3.1a：LightWater 首会话 performance（每点=鼠）
% - Naive 组：LightAudioBaseline(成像行为) + LAInterspersed(成像行为) + LAPureBehavior(纯行为)
% - Transfer 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
%
% 关键约束（按用户口径硬执行）：
% - 必须用查询条件 Stimulus="LightWater" 且 Phase="Naive"/"Transfer"（不要依赖 Design 名称）。
% - 排除那些 Naive 会话中掺杂了 AudioWater 回合的鼠（同一 block 内出现 AudioWater 即剔除整鼠）。
% - 不同数据库之间理论上不应有重复鼠名；如出现重复，直接报错（不做去重或合并）。
% - 只导出 SVG（不导出 PNG）。
%
% 执行方式（硬性要求，不要忘）：
% - 本文件必须保持为脚本（严禁改写成 function）。
% - 不要使用 run。
% - 在 MATLAB Editor 里打开后直接 Run/F5 执行。

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% Do not suppress UniExp:Exception:Block_must_warn; report if it occurs.
warning('on', 'UniExp:Exception:Block_must_warn');
lastwarn('', '');

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch ME
				warning('TransferLearningFig31:ProjectLoadFailed', char("Project load failed: " + string(ME.message)));
			end
		end
	end
catch ME
	warning('TransferLearningFig31:ProjectCheckFailed', char("Project check failed: " + string(ME.message)));
end

% --- 1) Load datasets
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（LightWater 是 Naive）
LAI  = TransferLearning.LAInterspersed();       % 成像：交错（含 Naive LightWater；需剔除混掺 AudioWater 的鼠）
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（LightWater 是 Transfer）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（LightWater 是 Naive）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（LightWater 是 Transfer）

% --- 2) Per-mouse first session performance (LightWater)
excludeMice = strings(0, 1);
labPure = iFindPureNaiveLightWaterMice(LAB,  excludeMice, "LightAudioBaseline");
laiPure = iFindPureNaiveLightWaterMice(LAI,  excludeMice, "LAInterspersed");
lapPure = iFindPureNaiveLightWaterMice(LAPB, excludeMice, "LAPureBehavior");

naiveA = iFirstLightWaterSessionByMouse(LAB,  "LightAudioBaseline", true,  "Naive", labPure.Mouse);
naiveB = iFirstLightWaterSessionByMouse(LAI,  "LAInterspersed",     true,  "Naive", laiPure.Mouse);
naiveC = iFirstLightWaterSessionByMouse(LAPB, "LAPureBehavior",     false, "Naive", lapPure.Mouse);

tranA  = iFirstLightWaterSessionByMouse(ALB,  "AudioLightBaseline", true,  "Transfer", []);
tranB  = iFirstLightWaterSessionByMouse(ALPB, "ALPureBehavior",     false, "Transfer", []);

naive = [naiveA; naiveB; naiveC];
tran  = [tranA;  tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoDuplicateMiceAcrossSources(naive, "Naive");
iAssertNoDuplicateMiceAcrossSources(tran,  "Transfer");
iAssertNoOverlapBetweenGroups(naive, tran);

xNaive = naive.FirstPerformance;
xTran  = tran.FirstPerformance;
xNaive = xNaive(isfinite(xNaive));
xTran  = xTran(isfinite(xTran));

% --- 3) Stats (unpaired)
if isempty(xNaive) || isempty(xTran)
	warning('TransferLearningFig31:EmptyData', char("Empty group detected (Naive n=" + string(numel(xNaive)) + ", Transfer n=" + string(numel(xTran)) + ")."));
	p = nan;	stats = struct('zval', nan);
else
	[p, ~, stats] = ranksum(xNaive, xTran);
end

summary = table;
summary.NaiveN = numel(xNaive);
summary.TransferN = numel(xTran);
summary.NaiveMean = mean(xNaive,'omitnan');
summary.NaiveMedian = median(xNaive,'omitnan');
summary.NaiveStd = std(xNaive,'omitnan');
summary.TransferMean = mean(xTran,'omitnan');
summary.TransferMedian = median(xTran,'omitnan');
summary.TransferStd = std(xTran,'omitnan');
summary.RankSumP = p;
if isstruct(stats) && isfield(stats,'zval')
	summary.RankSumZ = stats.zval;
else
	summary.RankSumZ = nan;
end
%% 

% --- 4) Plot (one point per mouse)
f = figure('Color','w', 'Name', 'Fig3.1a First session performance');
MATLAB.Graphics.FigureAspectRatio(8,5,1/3);
ax = axes('Parent', f);
hold(ax,'on');

% Avoid exporting the axes toolbar overlay into SVG.
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

x1 = ones(size(xNaive));
x2 = 2 * ones(size(xTran));

swarmchart(ax, x1, xNaive, 24, 'filled');
swarmchart(ax, x2, xTran,  24, 'filled');

ax.XLim = [0.5 2.5];
ax.XTick = [1 2];
ax.XTickLabel = {sprintf('Naive (n=%d)', numel(xNaive)), sprintf('Transfer (n=%d)', numel(xTran))};
ylim(ax, [0 1]);
ylabel(ax, 'Performance (first LightWater session)');
title(ax, 'Naive vs Transfer');
box(ax,'on');

if isfinite(p)
	txt = sprintf('ranksum p=%.2g', p);
else
	txt = 'ranksum p=NA';
end
text(ax, 1.5, 0.98, txt, 'HorizontalAlignment','center', 'VerticalAlignment','top');

% --- 5) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch ME
	warning('TransferLearningFig31:MakeDirFailed', char("mkdir failed: " + string(ME.message)));
end

raw = [naive; tran];

svgPath = fullfile(outDirUNC, 'Fig3_1a_FirstSessionPerformance.svg');
csvRaw  = fullfile(outDirUNC, 'Fig3_1a_FirstSessionPerformance_Raw.csv');
csvSum  = fullfile(outDirUNC, 'Fig3_1a_FirstSessionPerformance_Summary.csv');

% Enforce SVG-only: remove any legacy CSV artifacts from previous runs.
iDeleteIfExists(csvRaw);
iDeleteIfExists(csvSum);

try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', char(svgPath));
catch ME
	warning('TransferLearningFig31:ExportFailed', char("Export failed: " + string(ME.message)));
end

assignin('base', 'Fig3_1a_FirstSessionPerformance_Raw', raw);
assignin('base', 'Fig3_1a_FirstSessionPerformance_Summary', summary);

[wmsg, wid] = lastwarn;
if strcmp(string(wid), "UniExp:Exception:Block_must_warn")
	fprintf(2, 'Fig3.1a WARNING (%s): %s\n', wid, wmsg);
	fprintf(2, 'Fig3.1a: Please review the warning details above.\n');
end

%% --- local functions
function out = iFirstLightWaterSessionByMouse(DS, sourceName, imagingCohort, phase, mouseWhitelist)
	if nargin < 4 || strlength(string(phase)) == 0
		phase = "Naive";
	end
	if nargin < 5 || isempty(mouseWhitelist)
		mouseWhitelist = strings(0, 1);
	end

	Tblk = iQueryBlocksForPhase(DS, phase);
	if isempty(Tblk)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end

	Tblk.Mouse = string(Tblk.Mouse);
	mouseWhitelist = string(mouseWhitelist);
	if ~isempty(mouseWhitelist)
		Tblk = Tblk(ismember(Tblk.Mouse, mouseWhitelist), :);
	end
	if isempty(Tblk)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end
	Tblk.DateTime.TimeZone = '';

	% Compute per-block performance using ONLY LightWater trials
	if ~isprop(DS, 'Trials')
		error('TransferLearningFig31:MissingTrials', char("DataSet " + string(sourceName) + " (" + string(class(DS)) + ") has no Trials; cannot compute LightWater-only performance."));
	end
	Tr = DS.Trials;
	need = {'BlockUID','Stimulus','Behavior'};
	if ~all(ismember(need, Tr.Properties.VariableNames))
		error('TransferLearningFig31:TrialsMissingFields', char("Trials table for " + string(sourceName) + " (" + string(class(DS)) + ") lacks required fields: " + strjoin(string(setdiff(need, Tr.Properties.VariableNames)), ', ')));
	end
	TrStim = string(Tr.Stimulus);
	TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
	if isempty(TrLW)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end

	[G, bu] = findgroups(uint64(TrLW.BlockUID));
	lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
	perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

	blkUID64 = uint64(Tblk.BlockUID);
	[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
	Tblk = Tblk(tf, :);
	if isempty(Tblk)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end
	Tblk.LWPerf = perfByBlock.LWPerf(loc(tf));

	mice = unique(Tblk.Mouse);
	firstDT = NaT(numel(mice), 1);
	firstPerf = nan(numel(mice), 1);
	nBlocks = nan(numel(mice), 1);

	for mouseIdx = 1:numel(mice)
		m = mice(mouseIdx);
		rowsM = (Tblk.Mouse == m);
		dt = Tblk.DateTime(rowsM);
		if isempty(dt) || all(ismissing(dt))
			continue;
		end

		dt0 = min(dt);
		rows0 = rowsM & (Tblk.DateTime == dt0);
		firstDT(mouseIdx) = dt0;
		firstPerf(mouseIdx) = mean(Tblk.LWPerf(rows0), 'omitnan');
		nBlocks(mouseIdx) = sum(rows0);
	end

	out = table(mice, repmat(string(sourceName), numel(mice), 1), repmat(logical(imagingCohort), numel(mice), 1), ...
		firstDT, firstPerf, nBlocks, ...
		'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
end

function T = iQueryBlocksForPhase(DS, phase)
	vars = ["Mouse","DateTime","BlockUID","Phase"];
	phase = string(phase);

	try
		T = DS.TableQuery(vars, Phase=phase);
	catch ME
		% fallback: query broader, then enforce Phase in-memory
		try
			T = DS.TableQuery(vars);
		catch
			error('TransferLearningFig31:BlockQueryFailed', char("Block query failed for " + string(class(DS)) + ": " + string(ME.message)));
		end
		if isempty(T)
			return;
		end
		if ~ismember("Phase", string(T.Properties.VariableNames))
			error('TransferLearningFig31:MissingPhase', char("TableQuery result lacks Phase; cannot enforce Phase=" + phase + " for " + string(class(DS)) + "."));
		end
		T.Phase = string(T.Phase);
		T = T(T.Phase == phase, :);
	end

	if isempty(T)
		return;
	end

	% hard requirement: Phase must match
	if any(string(T.Phase) ~= phase)
		error('TransferLearningFig31:PhaseFilterFailed', char("Phase filter failed; non-" + phase + " rows remain for " + string(class(DS)) + "."));
	end
end

function out = iFindPureNaiveLightWaterMice(DS, excludeMice, sourceName)
	if nargin < 2 || isempty(excludeMice)
		excludeMice = strings(0, 1);
	end
	excludeMice = string(excludeMice);

	try
		T = DS.TableQuery(["Mouse","BlockUID","DateTime","Phase"], Phase="Naive");
	catch ME
		error('TransferLearningFig31:PureNaiveQueryFailed', char("Pure-Naive query failed for " + string(sourceName) + " (" + string(class(DS)) + "): " + string(ME.message)));
	end

	T.Mouse = string(T.Mouse);
	T = T(~ismember(T.Mouse, excludeMice), :);
	if isempty(T)
		out = table(string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','NBlocks'});
		return;
	end

	if ~isprop(DS, 'Trials')
		error('TransferLearningFig31:MissingTrials', char("DataSet " + string(sourceName) + " (" + string(class(DS)) + ") has no Trials; cannot detect AudioWater mixing."));
	end

	Tr = DS.Trials;
	if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
		error('TransferLearningFig31:TrialsMissingFields', char("Trials table for " + string(sourceName) + " (" + string(class(DS)) + ") lacks Stimulus/BlockUID."));
	end
	Tr.Stimulus = string(Tr.Stimulus);

	mice = unique(T.Mouse);
	keep = false(size(mice));
	nBlocks = nan(size(mice));

	for mouseIdx = 1:numel(mice)
		m = mice(mouseIdx);
		rowsM = (T.Mouse == m);
		bu = unique(uint64(T.BlockUID(rowsM)));
		nLWBlocks = 0;

		hasAudio = false;
		for blockIdx = 1:numel(bu)
			b = bu(blockIdx);
			trB = (uint64(Tr.BlockUID) == b);
			stimB = Tr.Stimulus(trB);
			hasLW = any(stimB == "LightWater");
			if ~hasLW
				continue;
			end
			nLWBlocks = nLWBlocks + 1;
			if any(stimB == "AudioWater")
				hasAudio = true;
				break;
			end
		end
		nBlocks(mouseIdx) = nLWBlocks;
		keep(mouseIdx) = (~hasAudio) & (nLWBlocks > 0);
	end

	bad = mice(~keep);
	if ~isempty(bad)
		fprintf('Fig3.1a: Excluding %d mice from %s due to AudioWater-mixed Naive blocks.\n', numel(bad), char(string(sourceName)));
		fprintf('  %s\n', char(strjoin(bad, ', ')));
	end

	out = table(mice(keep), nBlocks(keep), 'VariableNames', {'Mouse','NBlocks'});
end

function iAssertNoDuplicateMiceAcrossSources(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	[keys, ~, g] = unique(T.Mouse);
	nPerMouse = accumarray(g, 1);
	dupMice = keys(nPerMouse > 1);
	if isempty(dupMice)
		return;
	end

	msgLines = strings(numel(dupMice), 1);
	for idx = 1:numel(dupMice)
		m = dupMice(idx);
		src = unique(string(T.Source(T.Mouse == m)));
		msgLines(idx) = m + " -> " + strjoin(src, ", ");
	end

	msg = "Duplicate mouse IDs across sources in group '" + string(groupName) + "':\n" + strjoin(msgLines, "\n");
	error('TransferLearningFig31:DuplicateMouse', char(msg));
end

function iAssertNoOverlapBetweenGroups(naive, tran)
	if isempty(naive) || isempty(tran)
		return;
	end
	naive.Mouse = string(naive.Mouse);
	tran.Mouse = string(tran.Mouse);
	overlap = intersect(naive.Mouse, tran.Mouse);
	if isempty(overlap)
		return;
	end

	msgLines = strings(numel(overlap), 1);
	for idx = 1:numel(overlap)
		m = overlap(idx);
		sNaive = unique(string(naive.Source(naive.Mouse == m)));
		sTran = unique(string(tran.Source(tran.Mouse == m)));
		msgLines(idx) = m + " -> Naive{" + strjoin(sNaive, ",") + "} Transfer{" + strjoin(sTran, ",") + "}";
	end

	msg = "Mouse IDs overlap between Naive and Transfer groups:\n" + strjoin(msgLines, "\n");
	error('TransferLearningFig31:OverlapMouse', char(msg));
end

function iDeleteIfExists(p)
	try
		if exist(p, 'file')
			delete(p);
		end
	catch
		% best-effort cleanup
	end
end
