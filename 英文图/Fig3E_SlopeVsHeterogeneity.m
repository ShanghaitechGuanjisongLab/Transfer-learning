% 英文图3E：Transfer响应异质性与纯trial MLE Sigmoid学习斜率的相关性。
% 斜率无Jeffreys或弱先验惩罚；下渐近线固定为0，异质性按层计算。

svgName = 'English_Fig3E_SlopeVsHeterogeneity.svg';

transferMouseAllow = ["vtf0233"; "vtf0352"; "vtf0353"; "vtf0354"; "vtf1233"; "yqn0133"; "yqn0411"; "yqn1018"];

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

ALB = TransferLearning.AudioLightBaseline();

trialSessions = TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingTransfer");
trialSessions.Mouse = string(trialSessions.Mouse);
trialSessions = trialSessions(ismember(trialSessions.Mouse, transferMouseAllow), :);
sigmoidFitTable = iFitTrialMLEPerMouse(ALB, trialSessions);
if isempty(sigmoidFitTable)
	error('Fig3E:NoSigmoidFits', 'No per-mouse unpenalized trial MLE fit could be computed.');
end
assert(all(sigmoidFitTable.Lower == 0 & sigmoidFitTable.Upper == 1 & sigmoidFitTable.Slope <= 200), 'Sigmoid拟合约束不符合纯trial MLE口径。');

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];
colorT = TransferLearning.Color12h / 255;
colorFit = [0.5 0.5 0.5];

dataParts = cell(numel(layers), 1);
statsRows = table();

heterogeneitySessions = iPreCeilingSessions(trialSessions);
heterogeneityTable = TransferLearning.Metrics.ResponseHeterogeneity(ALB, heterogeneitySessions, "LightWater");
heterogeneityTable = heterogeneityTable(ismember(string(heterogeneityTable.Layer), layers), :);
%% 

f = figure;
f.Units = 'centimeters';
f.Position(3:4) = [4.5,4];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
xlabel(tl, 'Response heterogeneity');
axAll = gobjects(numel(layers), 1);

for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);
	layerHeterogeneity = heterogeneityTable(heterogeneityTable.Layer == layerName & isfinite(heterogeneityTable.SD), :);
	layerHeterogeneity = layerHeterogeneity(ismember(layerHeterogeneity.Mouse, sigmoidFitTable.Mouse), :);
	dataL = table(layerHeterogeneity.Mouse, repmat(layerLabel, height(layerHeterogeneity), 1), layerHeterogeneity.SD, VariableNames={'Mouse','Layer','Heterogeneity'});
	dataL = innerjoin(dataL, sigmoidFitTable, Keys='Mouse');
	dataL.Group = repmat("Transfer", height(dataL), 1);
	dataParts{iL} = dataL;
	use = isfinite(dataL.Slope) & isfinite(dataL.Heterogeneity);
	if nnz(use) >= 3 && std(dataL.Heterogeneity(use)) > 0 && std(dataL.Slope(use)) > 0
		[rho, p] = corr(dataL.Heterogeneity(use), dataL.Slope(use), 'Type', 'Spearman');
	else
		rho = NaN;
		p = NaN;
	end
	statsRows = [statsRows; table(layerLabel, nnz(use & dataL.Group == "Transfer"), rho, p, ...
		'VariableNames', {'Layer','TransferN','SpearmanRho','SpearmanP'})]; %#ok<AGROW>

	if ~isfinite(p)
		pLabel = 'p = NaN';
	elseif p < 0.001
		pLabel = 'p < 0.001';
	elseif p < 0.01
		pLabel = sprintf('p = %.3f', p);
	else
		pLabel = sprintf('p = %.2f', p);
	end

	ax = nexttile(tl, iL);
	hold(ax, 'on');
	box(ax, 'off');

	maskT = use & (dataL.Group == "Transfer");
	scatter(ax, dataL.Heterogeneity(maskT), dataL.Slope(maskT), 10, colorT, 'filled');
	if iL == 1
		ylabel(ax, 'Sigmoid slope');
	else
		ax.YAxis.Visible = 'off';
	end
	if nnz(use) >= 2 && std(dataL.Heterogeneity(use)) > 0
		fitP = polyfit(dataL.Heterogeneity(use), dataL.Slope(use), 1);
		xFitLine = [min(dataL.Heterogeneity(use)), max(dataL.Heterogeneity(use))];
		plot(ax, xFitLine, polyval(fitP, xFitLine), '-', 'Color', colorFit);
	end
	title(ax, layerLabel);
	text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
	axAll(iL) = ax;

	fprintf('\n=== Fig3E %s ===\n', layerLabel);
	fprintf('Transfer mice: %d\n', nnz(maskT));
	fprintf('Spearman ρ=%.3f, p=%.4g\n', rho, p);
end

MATLAB.Graphics.UnifyAxesLims(axAll(:), @ylim);

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
allAxes = findall(f, 'Type', 'axes');
% 先结算散点padding，再统一轴限，最后直接导出SVG。
TransferLearning.ApplyStandardExportStyle(f, 1);
MATLAB.Graphics.UnifyAxesLims(axAll(:), @ylim);
print(f, svgPath, '-dsvg');

function Fit = iFitTrialMLEPerMouse(DS, Sessions)
Mice = unique(string(Sessions.Mouse), 'stable');
Slope = nan(numel(Mice), 1);
Midpoint = nan(numel(Mice), 1);
RSquared = nan(numel(Mice), 1);
for MouseIndex = 1:numel(Mice)
	Mouse = Mice(MouseIndex);
	MouseSessions = Sessions(string(Sessions.Mouse) == Mouse, :);
	DateTimes = unique(MouseSessions.DateTime, 'sorted');
	TrialTable = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], Mouse=Mouse, Stimulus="LightWater");
	TrialTimes = datetime(TrialTable.DateTime);
	if ~isempty(TrialTimes.TimeZone)
		TrialTimes.TimeZone = '';
	end
	[IsSelected, SessionLocation] = ismember(TrialTimes, DateTimes);
	Behavior = double(TrialTable.Behavior);
	Use = IsSelected & isfinite(Behavior);
	if nnz(Use) < 2 || numel(unique(SessionLocation(Use))) < 2
		continue;
	end
	X = double(SessionLocation(Use));
	Y = Behavior(Use);
	[FitParams, Predicted] = iFitTrialMLE(X, Y);
	Slope(MouseIndex) = exp(min(FitParams(1), log(200)));
	Midpoint(MouseIndex) = FitParams(2);
	ResidualSS = sum((Y - Predicted).^2);
	TotalSS = sum((Y - mean(Y)).^2);
	if TotalSS > 0
		RSquared(MouseIndex) = 1 - ResidualSS / TotalSS;
	end
end
Keep = isfinite(Slope);
Fit = table(repmat("Transfer", nnz(Keep), 1), Mice(Keep), zeros(nnz(Keep), 1), ones(nnz(Keep), 1), Slope(Keep), Midpoint(Keep), RSquared(Keep), VariableNames={'Group','Mouse','Lower','Upper','Slope','Midpoint','RSquared'});
end

function [BestParams, Predicted] = iFitTrialMLE(X, Y)
% 逐trial纯二项极大似然，不加Jeffreys或弱先验；多起点确定性优化。
Starts = [log(0.2), median(X); log(0.8), median(X); log(2), median(X); log(6), median(X)];
BestObjective = inf;
BestParams = [NaN, NaN];
Options = optimset('Display', 'off', 'MaxFunEvals', 5000, 'MaxIter', 2000);
for StartIndex = 1:size(Starts, 1)
	Params = fminsearch(@(P)iTrialNLL(P, X, Y), Starts(StartIndex, :), Options);
	Objective = iTrialNLL(Params, X, Y);
	if isfinite(Objective) && Objective < BestObjective
		BestObjective = Objective;
		BestParams = Params;
	end
end
Predicted = iTrialSigmoid(BestParams, X);
end

function Objective = iTrialNLL(Params, X, Y)
Probability = iTrialSigmoid(Params, X);
Probability = min(max(Probability, 1e-12), 1 - 1e-12);
Objective = -sum(Y .* log(Probability) + (1 - Y) .* log(1 - Probability));
end

function Probability = iTrialSigmoid(Params, X)
Slope = exp(min(Params(1), log(200)));
Probability = 1 ./ (1 + exp(-Slope .* (X - Params(2))));
end

function SelectedSessions = iPreCeilingSessions(Sessions)
Sessions = sortrows(Sessions, {'Mouse', 'DateTime'});
Keep = false(height(Sessions), 1);
Mice = unique(string(Sessions.Mouse), 'stable');
for MouseIndex = 1:numel(Mice)
	SessionIndices = find(string(Sessions.Mouse) == Mice(MouseIndex));
	FirstCeiling = find(double(Sessions.Performance(SessionIndices)) >= 1 - 1e-12, 1, 'first');
	if isempty(FirstCeiling)
		AvailableIndices = SessionIndices;
	else
		AvailableIndices = SessionIndices(1:FirstCeiling - 1);
	end
	if numel(AvailableIndices) >= 2
		Keep(AvailableIndices) = true;
	end
end
SelectedSessions = Sessions(Keep, :);
end