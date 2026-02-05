% 英文图1L：Naive vs Transfer 散度比较
%
% 条形图比较初始光水（Naive）和迁移光水（Transfer）的散度
% Naive 组：LightAudioBaseline + LAInterspersed（剔除 Naive 阶段掺 AudioWater 的鼠）
% 以鼠为单位，合并2/3层和5层
% 不筛选活跃细胞，使用最新散度算法
%
% Execution:
%   run('D:\Users\张天夫\Documents\MATLAB\Transfer-learning\+TransferLearning\英文图1\L_DivergenceComparison.m')

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1L_DivergenceComparison.svg";

% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

% Suppress warnings
warnIds = [
	"UniExp:Exception:Block_must_warn"
	"UniExp:Exception:Split_trials_less_than_existing_Trials"
	"UniExp:Exception:No_TagPeaks_found"
];
for w = warnIds'
	try warning('off', w); catch, end
end

kSigma = 3; % threshold for active cell

% Time axis
xs = TransferLearning.Xs;
xsSec = seconds(xs);
baseMask = (xsSec >= -1) & (xsSec < 0);
idx1s = find(abs(xsSec - 1) < 0.05, 1, 'first');
if isempty(idx1s)
	[~, idx1s] = min(abs(xsSec - 1));
end

%% --- 1) Prepare data (run once)
if ~exist('LData', 'var') || ~isstruct(LData)
	LData = struct();
end

if ~isfield(LData, 'NaiveA') || ~isfield(LData, 'NaiveB') || ~isfield(LData, 'Transfer')
	DS_naive = TransferLearning.LightAudioBaseline();
	LData.NaiveA = iPrepareMouseCellTrials(DS_naive, "Naive", "LightWater", string.empty(0,1));

	DS_lai = TransferLearning.LAInterspersed();
	badMiceLAI = iFindMiceWithAudioWaterInPhase(DS_lai, "Naive");
	LData.BadMiceLAI = badMiceLAI;
	if ~isempty(badMiceLAI)
		fprintf('Fig1L: LAInterspersed excluded %d mice with AudioWater mixed into Naive phase.\n', numel(badMiceLAI));
		fprintf('  Excluded mice: %s\n', char(strjoin(string(badMiceLAI), ', ')));
	end
	LData.NaiveB = iPrepareMouseCellTrials(DS_lai, "Naive", "LightWater", badMiceLAI);

	DS_transfer = TransferLearning.AudioLightBaseline();
	LData.Transfer = iPrepareMouseCellTrials(DS_transfer, "Transfer", "LightWater", string.empty(0,1));
end

%% --- 2) Compute divergence (fast re-run)
[naive_mice_a, naive_per_mouse_a] = iComputeDivergenceFromPrepared(LData.NaiveA);
[naive_mice_b, naive_per_mouse_b] = iComputeDivergenceFromPrepared(LData.NaiveB);

% Combine and collapse by mouse (mean if duplicates)
naive_mice_all = [naive_mice_a; naive_mice_b];
naive_vals_all = [naive_per_mouse_a; naive_per_mouse_b];
[naive_mice, naive_per_mouse] = iCollapseByMouse(naive_mice_all, naive_vals_all);
fprintf('Naive: n=%d mice, mean=%.4f, std=%.4f\n', numel(naive_mice), mean(naive_per_mouse,'omitnan'), std(naive_per_mouse,'omitnan'));

[transfer_mice, transfer_per_mouse] = iComputeDivergenceFromPrepared(LData.Transfer);
fprintf('Transfer: n=%d mice, mean=%.4f, std=%.4f\n', numel(transfer_mice), mean(transfer_per_mouse,'omitnan'), std(transfer_per_mouse,'omitnan'));

% Remove NaN
naive_per_mouse = naive_per_mouse(isfinite(naive_per_mouse));
transfer_per_mouse = transfer_per_mouse(isfinite(transfer_per_mouse));

% Statistical test (non-paired, different mice)
[p, ~, stats] = ranksum(naive_per_mouse, transfer_per_mouse);
if isfield(stats, 'zval')
	fprintf('Wilcoxon rank-sum test: p=%.6f, z=%.4f\n', p, stats.zval);
else
	fprintf('Wilcoxon rank-sum test: p=%.6f\n', p);
end

% --- 3) Plot using UniExp.BarScatterCompare (same as C图)
DataCell = {naive_per_mouse, transfer_per_mouse};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'English Fig1L Divergence Comparison');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 2.0]; % 30mm x 20mm (same as C)
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

% 使用 UniExp.BarScatterCompare
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

% X axis labels
try
	ax.XTick = [1, 2];
	ax.XTickLabel = {'Naive', 'Transfer'};
	legend(ax, 'off');
catch
end

% 设置星号字体为 6pt
if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
	for pt = Optional.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

% 设置条形颜色与样式（同C图：红色=Naive，蓝色=Transfer）
colorNaive = [1 0 0];
colorTrans = [0 0 1];
try
	if numel(Bars) == 1
		Bars.FaceColor = 'flat';
		nBars = numel(Bars.YData);
		reps = ceil(nBars/2);
		Bars.CData = repmat([colorNaive; colorTrans], reps, 1);
		Bars.CData = Bars.CData(1:nBars, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	else
		if numel(Bars) >= 2
			Bars(1).FaceColor = colorNaive;
			Bars(2).FaceColor = colorTrans;
			Bars(1).LineWidth = 0.5;
			Bars(2).LineWidth = 0.5;
			Bars(1).FaceAlpha = 1/3;
			Bars(2).FaceAlpha = 1/3;
		end
	end
catch
end

% set errorbar linewidths
for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

try
	ax.XLim = [0.5, 2.5];
end

ylabel(ax, 'Divergence', 'FontSize', 6);
box off

try ax.Toolbar.Visible = 'off'; catch, end

% --- 4) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% Save summary
Summary = table();
Summary.Group = ["Naive"; "Transfer"];
Summary.N = [numel(naive_per_mouse); numel(transfer_per_mouse)];
Summary.Mean = [mean(naive_per_mouse); mean(transfer_per_mouse)];
Summary.SEM = [std(naive_per_mouse)/sqrt(numel(naive_per_mouse)); ...
               std(transfer_per_mouse)/sqrt(numel(transfer_per_mouse))];
Summary.P = [p; p];
assignin('base', 'Fig1L_DivergenceSummary', Summary);


%% --- Local helper functions

function dataOut = iPrepareMouseCellTrials(DS, phaseName, stimulusName, excludeMice)
% Prepare per-mouse CellTrialTimes tensors for divergence
	dataOut = struct('Mice', string.empty(0,1), 'CellTrialTimes', {{}}, 'Source', class(DS));
	excludeMice = string(excludeMice);
	
	% Get trials for this phase/stimulus
	try
		T = DS.TableQuery(["Mouse","DateTime","TrialUID"], Phase=phaseName, Stimulus=stimulusName);
	catch
		return;
	end
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isempty(excludeMice)
		keep = ~ismember(T.Mouse, excludeMice);
		T = T(keep, :);
	end
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
	
	% Pick first session per mouse
	dtT = groupsummary(T, "Mouse", "min", "DateTime");
	dtT.Properties.VariableNames{end} = 'DateTimeTarget';
	
	% Use QueryNTS to get per-trial DeltaF signals
	
	for iM = 1:height(dtT)
		m = dtT.Mouse(iM);
		dt = dtT.DateTimeTarget(iM);
		
		% Get trial UIDs for this mouse/session
		mask = T.Mouse == m & T.DateTime == dt;
		trialUIDs = uint64(T.TrialUID(mask));
		if numel(trialUIDs) < 2
			continue;
		end
		trialUIDs = unique(trialUIDs(:));
		trialUIDs = sort(trialUIDs);
		
		% Build cell x trial x time tensor (DeltaF)
		cellTraces = {};
		try
			ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Mouse', string(m)), UniExp.Flags.DeltaF, 1:24);
			nts = ntsCell{1};
		catch
			nts = [];
		end
		if isempty(nts)
			continue;
		end
		
		try
			inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
			nts = nts(inTrial, :);
		catch
			continue;
		end
		if isempty(nts)
			continue;
		end
		
		cellUIDs = unique(uint64(nts.CellUID));
		for iC = 1:numel(cellUIDs)
			cid = cellUIDs(iC);
			rowsC = (uint64(nts.CellUID) == cid);
			if sum(rowsC) < numel(trialUIDs)
				continue;
			end
			
			uid = uint64(nts.TrialUID(rowsC));
			sig = double(nts.TrialSignal(rowsC, :));
			
			[~, loc] = ismember(trialUIDs, uid);
			if any(loc == 0)
				continue;
			end
			
			sigOrdered = sig(loc, :);
			if any(~isfinite(sigOrdered), 'all')
				continue;
			end
			cellTraces{end+1, 1} = sigOrdered; % [nTrials x nTime]
		end
		
		if isempty(cellTraces)
			continue;
		end
		
		nCells = numel(cellTraces);
		nTrials = size(cellTraces{1}, 1);
		nTime = size(cellTraces{1}, 2);
		CellTrialTimes = nan(nCells, nTrials, nTime);
		for iC = 1:nCells
			CellTrialTimes(iC, :, :) = cellTraces{iC};
		end
		
		dataOut.Mice(end+1, 1) = m;
		dataOut.CellTrialTimes{end+1, 1} = CellTrialTimes;
	end
end

function [miceOut, divOut] = iComputeDivergenceFromPrepared(dataIn)
% Compute per-mouse divergence from prepared tensors
	miceOut = string([]);
	divOut = [];
	if ~isstruct(dataIn) || ~isfield(dataIn, 'Mice') || ~isfield(dataIn, 'CellTrialTimes')
		return;
	end
	for i = 1:numel(dataIn.Mice)
		ct = dataIn.CellTrialTimes{i};
		if isempty(ct)
			continue;
		end
		div = TransferLearning.Divergence(ct);
		if isfinite(div)
			miceOut(end+1, 1) = dataIn.Mice(i);
			divOut(end+1, 1) = div;
		end
	end
end

function [miceOut, valsOut] = iCollapseByMouse(miceIn, valsIn)
	% Collapse duplicates by mouse using mean
	miceIn = string(miceIn(:));
	valsIn = valsIn(:);
	if isempty(miceIn)
		miceOut = string.empty(0,1);
		valsOut = [];
		return;
	end
	[grp, miceOut] = findgroups(miceIn);
	valsOut = splitapply(@(x) mean(x, 'omitnan'), valsIn, grp);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	% 在给定 Phase 内，只要出现过 AudioWater（Stimulus 或 Design），就判定该鼠混入并剔除
	badMice = string.empty(0,1);
	try
		Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
		if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
			badMice = unique(string(Ta.Mouse));
			return;
		end
	catch
	end
end
