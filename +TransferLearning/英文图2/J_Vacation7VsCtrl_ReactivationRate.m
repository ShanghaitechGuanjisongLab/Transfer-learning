% English Fig2J: Vacation7 vs Control — Reactivation Rate P(T|L)
%
% v6 Panel J (sub-panel): Vacation7 复用率 P(T|L) 条形图
%
% P(T|L) = P(Transfer LightWater active@1s | Learned AudioWater active@1s)
% Combined across layers (MOp2/3 + MOp5), weighted by # learned-active cells.
%
% Data extraction: Fig3.5E 口径 (iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer)
% Plot style:      English Fig1L 口径 (UniExp.BarScatterCompare)
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图2.J_Vacation7VsCtrl_ReactivationRate

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName   = "English_Fig2J_Vacation7VsCtrl_ReactivationRate.svg";

% --- 1) Load datasets
CtrlDS = TransferLearning.AudioLightBaseline();
V7DS   = TransferLearning.Vacation7();

% --- 2) Compute P(T|L) per mouse per layer
RCtrl = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	'DataSet', CtrlDS, 'Source', "AudioLightBaseline");
RV7 = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	'DataSet', V7DS, 'Source', "Vacation7");

if isempty(RCtrl) || isempty(RV7)
	error('English_Fig2J:EmptyBuild', 'Empty rows from P(T|L) builder.');
end

RCtrl.Group = repmat("Control",   height(RCtrl), 1);
RV7.Group   = repmat("Vacation7", height(RV7),   1);
R = [RCtrl; RV7];
R.Mouse = string(R.Mouse);

% --- 3) Combine layers: weighted average P(T|L) across MOp2/3 + MOp5
n23 = R.NLearnedActive23;
n5  = R.NLearnedActive5;
n23(~isfinite(n23)) = 0;
n5(~isfinite(n5))   = 0;

w23 = n23 .* R.Prob23;
w5  = n5  .* R.Prob5;
w23(~isfinite(w23)) = 0;
w5(~isfinite(w5))   = 0;

nTotal = n23 + n5;
R.PTgivenL = (w23 + w5) ./ nTotal;
R.PTgivenL(nTotal == 0) = NaN;

xCtrl = R.PTgivenL(R.Group == "Control");
xV7   = R.PTgivenL(R.Group == "Vacation7");
xCtrl = xCtrl(isfinite(xCtrl));
xV7   = xV7(isfinite(xV7));

fprintf('Control:   n=%d, mean=%.4f, median=%.4f\n', numel(xCtrl), mean(xCtrl), median(xCtrl));
fprintf('Vacation7: n=%d, mean=%.4f, median=%.4f\n', numel(xV7),   mean(xV7),   median(xV7));

pRS = ranksum(xCtrl, xV7);
fprintf('Wilcoxon rank-sum: p=%.4g\n', pRS);

% --- 4) Plot (UniExp.BarScatterCompare, transparent background)
DataCell     = {double(xCtrl(:)), double(xV7(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color', 'w', 'Name', 'English Fig2J Vacation7 Reactivation');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0];

[~, ~, Bars, ErrorBars] = UniExp.BarScatterCompare( ...
	DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);

ax = gca;
ax.FontSize = 6;
ax.XTick = [1 2];
ax.XTickLabel = {'Ctrl', 'Vac7'};
legend(ax, 'off');

% Bar styling (red = Control, blue = Vacation7; match English Fig2F)
colorA = [1 0 0];
colorB = [0 0 1];

if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nBars = numel(Bars.YData);
	reps = ceil(nBars / 2);
	Bars.CData = repmat([colorA; colorB], reps, 1);
	Bars.CData = Bars.CData(1:nBars, :);
	Bars.BarWidth = 0.5;
	Bars.LineWidth = 0.5;
	Bars.FaceAlpha = 1/3;
else
	if numel(Bars) >= 2
		Bars(1).FaceColor = colorA;
		Bars(2).FaceColor = colorB;
		Bars(1).LineWidth = 0.5;
		Bars(2).LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	end
end

for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

ax.XLim = [0.5, 2.5];
ylabel(ax, 'Reactivation', 'FontSize', 6);
box(ax, 'off');
grid(ax, 'off');
ax.Toolbar.Visible = 'off';

% P值线文字也设为6pt
txts = findobj(ax, 'Type', 'text');
set(txts, 'FontSize', 6);

% --- 5) Export
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

% --- 6) Save to workspace
assignin('base', 'English_Fig2J_R', R);
assignin('base', 'English_Fig2J_P_Ranksum', pRS);
