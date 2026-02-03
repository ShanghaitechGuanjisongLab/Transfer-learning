% 英文图1L：Naive vs Transfer 散度比较
%
% 条形图比较初始光水（Naive）和迁移光水（Transfer）的散度
% 以鼠为单位，合并2/3层和5层
% 排除1s处没有任何回合超过基线+3σ的细胞
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

% --- 1) Compute divergence for Naive LightWater (from LightAudioBaseline)
DS_naive = TransferLearning.LightAudioBaseline();
[naive_mice, naive_per_mouse] = iComputeDivergencePerMouse(DS_naive, "Naive", "LightWater", baseMask, idx1s, kSigma);
fprintf('Naive: n=%d mice, mean=%.4f, std=%.4f\n', numel(naive_mice), mean(naive_per_mouse,'omitnan'), std(naive_per_mouse,'omitnan'));

% --- 2) Compute divergence for Transfer LightWater (from AudioLightBaseline)
DS_transfer = TransferLearning.AudioLightBaseline();
[transfer_mice, transfer_per_mouse] = iComputeDivergencePerMouse(DS_transfer, "Transfer", "LightWater", baseMask, idx1s, kSigma);
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

function [mice, divPerMouse] = iComputeDivergencePerMouse(DS, phaseName, stimulusName, baseMask, idx1s, kSigma)
% Compute divergence per mouse, only using cells with at least one trial > kSigma at 1s
	mice = string([]);
	divPerMouse = [];
	
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
	T.DateTime = datetime(T.DateTime);
	T.DateTime.TimeZone = '';
	
	% Pick first session per mouse
	dtT = groupsummary(T, "Mouse", "min", "DateTime");
	dtT.Properties.VariableNames{end} = 'DateTimeTarget';
	
	% Get cells
	Cmeta = DS.Cells(:, ["CellUID","Mouse"]);
	Cmeta.Mouse = string(Cmeta.Mouse);
	
	% TrialSignals
	Ts = DS.TrialSignals;
	
	for iM = 1:height(dtT)
		m = dtT.Mouse(iM);
		dt = dtT.DateTimeTarget(iM);
		
		% Get trial UIDs for this mouse/session
		mask = T.Mouse == m & T.DateTime == dt;
		trialUIDs = uint64(T.TrialUID(mask));
		if numel(trialUIDs) < 2
			continue;
		end
		
		% Get cells for this mouse
		cellUIDs = uint64(Cmeta.CellUID(Cmeta.Mouse == m));
		if isempty(cellUIDs)
			continue;
		end
		
		% Collect Z-scored values at 1s for active cells
		allCellVals1s = [];
		
		for iC = 1:numel(cellUIDs)
			cid = cellUIDs(iC);
			
			% Extract signals for this cell
			maskTs = (uint64(Ts.CellUID) == cid) & ismember(uint64(Ts.TrialUID), trialUIDs);
			if sum(maskTs) < 2
				continue;
			end
			
			sig = double(Ts.ResampledSignal(maskTs, :));
			
			% Z-score normalize
			mu = mean(sig(:, baseMask), 2, 'omitnan');
			sd = std(sig(:, baseMask), 0, 2, 'omitnan');
			sd(sd < eps) = 1;
			Z = (sig - mu) ./ sd;
			
			% Get values at 1s
			vals1s = Z(:, idx1s);
			if any(~isfinite(vals1s))
				continue;
			end
			
			% Filter: at least one trial > kSigma
			if max(vals1s) <= kSigma
				continue;
			end
			
			allCellVals1s = [allCellVals1s; vals1s'];  % each row = one cell, cols = trials
		end
		
		if size(allCellVals1s, 1) < 5  % need at least 5 active cells
			continue;
		end
		
		% Compute divergence using TransferLearning.Divergence formula
		% D = sqrt(mean(var(CellTrials,[],2))) / norm(mean(CellTrials,2))
		cellVar = var(allCellVals1s, 0, 2, 'omitnan');
		absDiv = sqrt(mean(cellVar, 'omitnan'));
		centroid = mean(allCellVals1s, 2, 'omitnan');
		d0 = norm(centroid);
		
		if isfinite(absDiv) && isfinite(d0) && d0 > 0
			div = absDiv / d0;
			mice(end+1) = m;
			divPerMouse(end+1) = div;
		end
	end
	
	mice = mice(:);
	divPerMouse = divPerMouse(:);
end
