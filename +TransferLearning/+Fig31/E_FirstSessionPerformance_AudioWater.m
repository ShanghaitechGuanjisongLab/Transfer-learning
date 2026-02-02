% 图3.1e：AudioWater 首会话 performance（每点=鼠）
% - Naive 组：AudioLightBaseline(成像行为) + ALPureBehavior(纯行为)
% - Transfer 组：LightAudioBaseline(成像行为) + LAPureBehavior(纯行为，\\data-server-2\个人数据\张天夫\202601\基本迁移行为 光水转声水.v3.mat)
%
% 关键约束（与 Fig3.1a 一致）：
% - 必须用查询条件 Stimulus="AudioWater" 且 Phase="Naive"/"Transfer"（不要依赖 Design 名称）。
% - 不同数据库之间理论上不应有重复鼠名；如出现重复，直接报错（不做去重或合并）。
% - 只导出 SVG（不导出 PNG/CSV）。
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
				warning('Fig3_1e:ProjectLoadFailed', char("Project load failed: " + string(ME.message)));
			end
		end
	end
catch ME
	warning('Fig3_1e:ProjectCheckFailed', char("Project check failed: " + string(ME.message)));
end

% --- 1) Load datasets
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光（AudioWater 是 Naive）
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声（AudioWater 是 Transfer）
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光（AudioWater 是 Naive）
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声（AudioWater 是 Transfer）

% --- 2) Per-mouse first session performance (AudioWater)
naiveA = iFirstAudioWaterSessionByMouse(ALB,  "AudioLightBaseline", true,  "Naive");
naiveB = iFirstAudioWaterSessionByMouse(ALPB, "ALPureBehavior",     false, "Naive");

tranA  = iFirstAudioWaterSessionByMouse(LAB,  "LightAudioBaseline", true,  "Transfer");
tranB  = iFirstAudioWaterSessionByMouse(LAPB, "LAPureBehavior",     false, "Transfer");

naive = [naiveA; naiveB];
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
	warning('Fig3_1e:EmptyData', '%s', char("Empty group detected (Naive n=" + string(numel(xNaive)) + ", Transfer n=" + string(numel(xTran)) + ")."));
	p = nan; stats = struct('zval', nan);
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

% --- 4) Plot (one point per mouse)
f = figure('Color','w', 'Name', 'Fig3.1e First session performance (AudioWater)');
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
ax.XTickLabel = {sprintf('Naive (n=%d)', numel(xNaive)), sprintf('Transfer (n=%d)', numel(xTran))};ax.FontSize = 6;ylim(ax, [0 1]);
ylabel(ax, 'Performance');
title(ax, 'First AudioWater session');
box(ax,'on');

% p-value line (via MATLAB.Graphics.PLine)
if isfinite(p) && ~isempty(xNaive) && ~isempty(xTran)
	S = scatter(ax, [x1(:); x2(:)], [xNaive(:); xTran(:)], 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end
	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), 0, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		[~, pTexts] = MATLAB.Graphics.PLine(Descriptors);
		for pt = pTexts(:)'
			pt.FontSize = 6;
		end
	catch
	end
	try
		delete(S);
	catch
	end
end

% --- 5) Export (SVG only)
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch ME
	warning('Fig3_1e:MakeDirFailed', char("mkdir failed: " + string(ME.message)));
end

raw = [naive; tran];

svgPath = fullfile(outDirUNC, 'Fig3_1e_FirstSessionPerformance_AudioWater.svg');
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', char(svgPath));
catch ME
	warning('Fig3_1e:ExportFailed', char("Export failed: " + string(ME.message)));
end

assignin('base', 'Fig3_1e_FirstSessionPerformance_AudioWater_Raw', raw);
assignin('base', 'Fig3_1e_FirstSessionPerformance_AudioWater_Summary', summary);

[wmsg, wid] = lastwarn;
if strcmp(string(wid), "UniExp:Exception:Block_must_warn")
	fprintf(2, 'Fig3.1e WARNING (%s): %s\n', wid, wmsg);
	fprintf(2, 'Fig3.1e: Please review the warning details above.\n');
end

%% --- local functions
function out = iFirstAudioWaterSessionByMouse(DS, sourceName, imagingCohort, phase)
	if nargin < 4 || strlength(string(phase)) == 0
		phase = "Naive";
	end

	Tblk = iQueryBlocksForPhase(DS, phase);
	if isempty(Tblk)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end

	Tblk.Mouse = string(Tblk.Mouse);
	Tblk.DateTime.TimeZone = '';

	% Compute per-block performance using ONLY AudioWater trials
	if ~isprop(DS, 'Trials')
		error('Fig3_1e:MissingTrials', 'DataSet %s (%s) has no Trials; cannot compute AudioWater-only performance.', char(string(sourceName)), class(DS));
	end
	Tr = DS.Trials;
	need = {'BlockUID','Stimulus','Behavior'};
	if ~all(ismember(need, Tr.Properties.VariableNames))
		error('Fig3_1e:TrialsMissingFields', 'Trials table for %s (%s) lacks required fields: %s', char(string(sourceName)), class(DS), strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
	end
	TrStim = string(Tr.Stimulus);
	TrAW = Tr(TrStim == "AudioWater", {'BlockUID','Behavior'});
	if isempty(TrAW)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end

	[G, bu] = findgroups(uint64(TrAW.BlockUID));
	awPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrAW.Behavior, G);
	perfByBlock = table(uint64(bu), awPerf, 'VariableNames', {'BlockUID64','AWPerf'});

	blkUID64 = uint64(Tblk.BlockUID);
	[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
	Tblk = Tblk(tf, :);
	if isempty(Tblk)
		out = table(string.empty(0,1), string.empty(0,1), false(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
		return;
	end
	Tblk.AWPerf = perfByBlock.AWPerf(loc(tf));

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
		firstPerf(mouseIdx) = mean(Tblk.AWPerf(rows0), 'omitnan');
		nBlocks(mouseIdx) = sum(rows0);
	end

	out = table(mice, repmat(string(sourceName), numel(mice), 1), repmat(logical(imagingCohort), numel(mice), 1), ...
		firstDT, firstPerf, nBlocks, ...
		'VariableNames', {'Mouse','Source','ImagingCohort','FirstDateTime','FirstPerformance','NBlocksInFirstSession'});
end

function Tblk = iQueryBlocksForPhase(DS, phaseName)
	phaseName = string(phaseName);
	vars = ["Mouse","DateTime","BlockUID","Phase","Stimulus","Design"];
	Tblk = table();
	try
		Tblk = DS.TableQuery(vars, Phase=phaseName, Stimulus="AudioWater");
	catch
		% fallback if Stimulus field is missing in TableQuery: query by Design then filter by Stimulus if present
		try
			Tblk = DS.TableQuery(vars, Phase=phaseName, Design="AudioWater");
		catch
			Tblk = table();
		end
	end
	if isempty(Tblk)
		return;
	end
	if ~ismember('BlockUID', Tblk.Properties.VariableNames)
		error('Fig3_1e:MissingBlockUID', 'TableQuery result lacks BlockUID; cannot compute per-session performance.');
	end
	Tblk.Mouse = string(Tblk.Mouse);
	Tblk.DateTime = iNormalizeDateTime(Tblk.DateTime);
	if ismember('Stimulus', Tblk.Properties.VariableNames)
		Tblk.Stimulus = string(Tblk.Stimulus);
		Tblk = Tblk(Tblk.Stimulus=="AudioWater", :);
	end
	Tblk = Tblk(~ismissing(Tblk.Mouse) & ~ismissing(Tblk.DateTime), :);
end

function iAssertNoDuplicateMiceAcrossSources(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	mice = unique(T.Mouse);
	msgLines = strings(0,1);
	for i = 1:numel(mice)
		m = mice(i);
		sources = unique(T.Source(T.Mouse==m));
		if numel(sources) > 1
			msgLines(end+1,1) = m + ": " + strjoin(sources, ", "); %#ok<AGROW>
		end
	end
	if ~isempty(msgLines)
		error('Fig3_1e:DuplicateMouseAcrossSources', 'Some mice appear in multiple sources within %s:\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
	end
end

function iAssertNoOverlapBetweenGroups(naive, tran)
	m1 = unique(string(naive.Mouse));
	m2 = unique(string(tran.Mouse));
	overlap = intersect(m1, m2);
	if ~isempty(overlap)
		error('Fig3_1e:MouseInMultipleGroups', 'Some mice appear in both Naive and Transfer groups:\n%s', char(strjoin(overlap, newline)));
	end
end

function dt = iNormalizeDateTime(dt)
	% Normalize datetime (strip timezone; accept datenum/char/string)
	if isdatetime(dt)
		dt.TimeZone = '';
		return;
	end
	try
		dt = datetime(dt);
		dt.TimeZone = '';
	catch
		dt = datetime(dt, 'ConvertFrom','datenum');
		dt.TimeZone = '';
	end
end
