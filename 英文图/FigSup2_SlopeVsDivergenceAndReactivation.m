% FigSup2_SlopeVsDivergenceAndReactivation.m —— 补充材料 S2：学习速度（sigmoid slope）与细胞层面指标的相关性
%
%  图 A  slope vs divergence（试次间相对散度）
%        队列：Naive（LightAudioBaseline + LAInterspersed）/ 12 h（AudioLightBaseline）/ 7 d（Vacation7）
%  图 B  slope vs reactivation（P(Transfer active | Learned active) @ cue + 1 s）
%        队列：12 h（AudioLightBaseline）/ 7 d（Vacation7）
%
%  每个指标都算三套：合并全部细胞 / 仅 MOp2/3 / 仅 MOp5
%
%  散度口径与 TransferLearning.Metrics.StartBlockDivergence 完全一致：
%    每鼠取「首个纯 LightWater 会话」——
%      Naive   ：Naive 相位中第一个含 LightWater 且不含 AudioWater 的会话
%      12 h/7 d：Transfer 相位中第一个 LightWater 会话
%    X = cue 后 1 s（Xs 第 32 点，≈0.96 s）的 ZScore 响应矩阵（细胞 × 试次），
%    div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )；
%    合并层用**同一会话的全部细胞重新计算**（不是两层数值平均）。
%
%  reactivation 的分层值直接取 iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer 的
%    Prob23 / Prob5，合并值按 learned-active 细胞数（NLearnedActive23/5）加权。
%  slope 取自 TransferLearning.Metrics.LightWaterMetricData().Slope（与 1C 的 Learning speed 同源）。
%
%  输出（\\Data-Server-2\个人数据\杨青宁\<yyyyMM>\）：
%    English_FigS2_SlopeVsDivergence.svg
%    English_FigS2_SlopeVsReactivation.svg

clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
addpath('d:\git\Transfer-Learning\英文图');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ================= 数据集与常量 =================
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
V7  = TransferLearning.Vacation7();

cols = [TransferLearning.ColorNaive; TransferLearning.Color12h; TransferLearning.Color7d] / 255;
colFit = [0.62 0.62 0.62];

%% ================= slope（每鼠一个值，跨层共用） =================
D = TransferLearning.Metrics.LightWaterMetricData(ForceRebuild = false);
SlopeT = D.Slope;

%% ================= A：divergence =================
fprintf('\n=== 计算 divergence（分层 + 合并）===\n');
DivN  = iDivNaive({LAB, LAI});
Div12 = iDivPhase(ALB, "Transfer");
Div7  = iDivPhase(V7,  "Transfer");
fprintf('  Naive %d 鼠 / 12 h %d 鼠 / 7 d %d 鼠\n', height(DivN), height(Div12), height(Div7));

%% ================= B：reactivation =================
fprintf('\n=== 计算 reactivation（分层 + 合并）===\n');
R12 = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = ALB, Source = "AudioLightBaseline", RequireHitMiss = false);
R7  = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = V7,  Source = "Vacation7",        RequireHitMiss = false);
R12.PAll = iWeightedPTL(R12);
R7.PAll  = iWeightedPTL(R7);
fprintf('  12 h %d 鼠 / 7 d %d 鼠\n', height(R12), height(R7));

%% ================= 图 A：slope vs divergence（合并层，Fig1K 样式）=================
colName  = ["Naive", "12 h", "7 d"];
slopeGrp = ["Naive", "Transfer", "7dayTransfer"];
divVal   = {DivN.DivAll, Div12.DivAll, Div7.DivAll};
divMouse = {DivN.Mouse,  Div12.Mouse,  Div7.Mouse};

%只出 12 h 组（合并层）
iC12 = 2;
XV = cell(1, 3); YV = cell(1, 3);
for iC = 1:3
	[XV{iC}, YV{iC}] = iPair(divVal{iC}, divMouse{iC}, slopeGrp(iC), SlopeT);
end
[xA, yA] = deal(XV{iC12}, YV{iC12});
yLimA = iCommonYLim({yA});

figW = 3.0; figH = 4.0;      % 单面板 30 x 40 mm（同 Fig1K）
fA = iPanelFigure('English FigS2 slope vs divergence', figW, figH);
axA = axes(fA, 'Position', [0.225, 0.155, 0.705, 0.775]);
stA = iPanel1K(axA, xA, yA, cols(iC12, :), colName(iC12), 'divergence', yLimA, true);
StatsA = table(string(colName(iC12)), "All", stA.N, stA.Rho, stA.PValue, ...
	'VariableNames', {'Group', 'Layers', 'N', 'Rho', 'PValue'});
fprintf('[A] %-6s All  n=%2d  ρ=%+.3f  p=%.4g\n', colName(iC12), stA.N, stA.Rho, stA.PValue);
svgA = TransferLearning.ExportStandardFigure(fA, 1, 'English_FigS2_SlopeVsDivergence.svg');
fprintf('\nWrote: %s\n', svgA);

%% ================= 图 B：slope vs reactivation（仅 12 h，合并层，Fig1K 样式）=================
colNameB  = ["12 h", "7 d"];
slopeGrpB = ["Transfer", "7dayTransfer"];
reaVal    = {R12.PAll, R7.PAll};
reaMouse  = {R12.Mouse, R7.Mouse};

XVb = cell(1, 2); YVb = cell(1, 2);
for iC = 1:2
	[XVb{iC}, YVb{iC}] = iPair(reaVal{iC}, reaMouse{iC}, slopeGrpB(iC), SlopeT);
end
[xB, yB] = deal(XVb{1}, YVb{1});
yLimB = iCommonYLim({yB});

fB = iPanelFigure('English FigS2 slope vs reactivation', figW, figH);
axB = axes(fB, 'Position', [0.225, 0.155, 0.705, 0.775]);
stB = iPanel1K(axB, xB, yB, cols(iC12, :), colNameB(1), 'reactivation', yLimB, true);
StatsB = table(string(colNameB(1)), "All", stB.N, stB.Rho, stB.PValue, ...
	'VariableNames', {'Group', 'Layers', 'N', 'Rho', 'PValue'});
fprintf('[B] %-6s All  n=%2d  ρ=%+.3f  p=%.4g\n', colNameB(1), stB.N, stB.Rho, stB.PValue);
svgB = TransferLearning.ExportStandardFigure(fB, 1, 'English_FigS2_SlopeVsReactivation.svg');
fprintf('\nWrote: %s\n', svgB);

assignin('base', 'FigS2_Divergence', struct('Naive', DivN, 'H12', Div12, 'D7', Div7));
assignin('base', 'FigS2_Reactivation', struct('H12', R12, 'D7', R7));
assignin('base', 'FigS2_StatsSlopeVsDivergence', StatsA);
assignin('base', 'FigS2_StatsSlopeVsReactivation', StatsB);

%% ================= 局部函数 =================

function [x, y] = iPair(val, mouseNames, slopeGroup, SlopeT)
%把细胞指标与 slope 按鼠名对齐（slope 只在同一队列内匹配）
x = double(val(:));
y = nan(size(x));
Sg = SlopeT(string(SlopeT.Group) == string(slopeGroup), :);
[has, loc] = ismember(string(mouseNames(:)), string(Sg.Mouse));
y(has) = double(Sg.Slope(loc(has)));
end

function st = iPanel1K(ax, x, y, col, ttl, xlab, yLim, doYLabel)
%与 Fig1K 完全一致的单面板散点样式：实心圆点 + 淡灰拟合线 + 左上角 ρ/p + 彩色粗标题
x = double(x(:)); y = double(y(:));
ok = isfinite(x) & isfinite(y);
x = x(ok); y = y(ok);
n = numel(x);
hold(ax, 'on');

plot(ax, x, y, 'o', 'MarkerSize', 3.6, 'MarkerFaceColor', col, 'MarkerEdgeColor', 'none');

rho = NaN; pv = NaN;
if n >= 3 && std(x) > 0 && std(y) > 0
	pFit = polyfit(x, y, 1);
	xf = linspace(min(x), max(x), 60).';
	hFit = plot(ax, xf, polyval(pFit, xf), '-', 'Color', [0.62 0.62 0.62], 'LineWidth', 0.5);
	setappdata(hFit, 'TransferLearningPreserveLineWidth', true);
	[rho, pv] = corr(x, y, 'Type', 'Spearman');
end

ax.Box = 'off';
ax.LineWidth = 0.75;
ax.TickDir = 'out';
ax.TickLength = [0.025 0.025];
ax.FontSize = 6;
if n > 0 && std(x) > 0
	xPad = 0.06 * (max(x) - min(x));
	xlim(ax, [min(x) - xPad, max(x) + xPad]);
end
ylim(ax, yLim);
xlabel(ax, xlab);
if doYLabel
	ylabel(ax, 'learning slope');
end
title(ax, ttl, 'Color', col, 'FontWeight', 'bold', 'FontSize', 6);

if isfinite(rho)
	star = '';
	if pv < 0.05, star = ' *'; end
	if pv < 1e-3
		labelStr = {sprintf('\\rho = %.2f%s', rho, star), 'p < 0.001'};
	elseif pv < 0.01
		labelStr = {sprintf('\\rho = %.2f%s', rho, star), sprintf('p = %.3f', pv)};
	else
		labelStr = {sprintf('\\rho = %.2f%s', rho, star), sprintf('p = %.2f', pv)};
	end
	text(ax, 0.04, 0.96, labelStr, 'Units', 'normalized', 'FontSize', 6, ...
		'Color', [0.1 0.1 0.1], 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
end
st = struct('N', n, 'Rho', rho, 'PValue', pv);
end

function f = iPanelFigure(name, wCm, hCm)
%固定画布与纸张尺寸（cm），与 Fig1K 同一套尺寸逻辑
f = figure('Color', 'w', 'Name', name, 'Units', 'centimeters');
f.Position(3:4) = [wCm hCm];
f.PaperUnits = 'centimeters';
f.PaperSize = [wCm hCm];
f.PaperPosition = [0 0 wCm hCm];
f.PaperPositionMode = 'manual';
end

function yl = iCommonYLim(YV)
%所有面板共用一个 y 范围，方便横向比较；顶部多留空间给 ρ/p 文字，避免压住散点
v = cellfun(@(x) x(isfinite(x)), YV, 'UniformOutput', false);
v = vertcat(v{:});
yl = [0, max(v) * 1.45];
end

%% ---------- divergence ----------

function T = iDivNaive(dsList)
%Naive 组：每个数据集里各鼠「第一个只含 LightWater 的 Naive 会话」
Rows = cell(0, 1);
for k = 1:numel(dsList)
	DS = dsList{k};
	Tq = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Phase","Stimulus"]);
	Tq = iNormTable(Tq);
	mice = unique(Tq.Mouse);
	for i = 1:numel(mice)
		Tm = Tq(Tq.Mouse == mice(i) & Tq.Phase == "Naive", :);
		if isempty(Tm), continue; end
		sess = sort(unique(Tm.DateTime), 'ascend');
		for s = 1:numel(sess)
			Tss = Tm(Tm.DateTime == sess(s), :);
			if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
				Tss = sortrows(Tss(Tss.Stimulus == "LightWater", :), 'TrialIndex');
				Rows{end+1, 1} = iDivOneSession(DS, mice(i), Tss); %#ok<AGROW>
				break;
			end
		end
	end
end
if isempty(Rows)
	T = iEmptyDiv();
else
	T = vertcat(Rows{:});
	T = T(T.Mouse ~= "", :);
end
end

function T = iDivPhase(DS, phaseName)
%12 h / 7 d：每鼠第一个 phaseName 相位里的 LightWater 会话
Tq = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Phase","Stimulus"]);
Tq = iNormTable(Tq);
mice = unique(Tq.Mouse);
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	Tm = Tq(Tq.Mouse == mice(i) & Tq.Phase == string(phaseName) & Tq.Stimulus == "LightWater", :);
	if isempty(Tm)
		Rows{i} = iEmptyDiv();
		continue;
	end
	dt = min(Tm.DateTime);
	Tss = sortrows(Tq(Tq.Mouse == mice(i) & Tq.DateTime == dt & Tq.Stimulus == "LightWater", :), 'TrialIndex');
	Rows{i} = iDivOneSession(DS, mice(i), Tss);
end
T = vertcat(Rows{:});
T = T(T.Mouse ~= "", :);
end

function T = iDivOneSession(DS, mouseName, SessTbl)
%一个会话内：构建 1 s 响应矩阵，算合并 / L2-3 / L5 三套散度
T = iEmptyDiv();
if height(SessTbl) < 2, return; end
T.Mouse = string(mouseName);

trialUIDs = unique(uint64(SessTbl.TrialUID), 'stable');
if numel(trialUIDs) < 2, return; end
dt = SessTbl.DateTime(1);

[X, layers, cellUIDs] = iResponseMatrix(DS, mouseName, dt, trialUIDs);
if isempty(X) || size(X, 1) < 3, return; end

T.DivAll  = iDivergence(X);
T.NCells  = size(X, 1);
m23 = layers == "MOp2/3";
m5  = layers == "MOp5";
if sum(m23) >= 3, T.DivL23 = iDivergence(X(m23, :)); end
if sum(m5)  >= 3, T.DivL5  = iDivergence(X(m5,  :)); end
T.CellUID = numel(cellUIDs);
end

function [X, layers, cellUIDs] = iResponseMatrix(DS, mouseName, dt, trialUIDs)
%X = 细胞 × 试次 的 ZScore 响应（cue 后 1 s 那一个时间点），与 StartBlockDivergence 同口径
sampleRate = 8;
idx1s = 4 * sampleRate;   % Xs 第 32 点 ≈ 0.96 s
X = []; layers = strings(0, 1); cellUIDs = uint64([]);

nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', string(mouseName), 'DateTime', dt), ...
	UniExp.Flags.ZScore, 1:24);
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end

nts = nts(ismember(uint64(nts.TrialUID), trialUIDs), :);
if isempty(nts), return; end
trialUIDs = trialUIDs(ismember(trialUIDs, unique(uint64(nts.TrialUID), 'stable')));
if numel(trialUIDs) < 2, return; end

allC = unique(uint64(nts.CellUID), 'stable');
tr = cell(numel(allC), 1);
keep = zeros(numel(allC), 1, 'uint64');
nk = 0;
for c = 1:numel(allC)
	rows = uint64(nts.CellUID) == allC(c);
	uid  = uint64(nts.TrialUID(rows));
	sig  = double(nts.TrialSignal(rows, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf), continue; end
	so = sig(loc, :);
	if size(so, 2) < idx1s || any(~isfinite(so), 'all'), continue; end
	nk = nk + 1;
	tr{nk} = so;
	keep(nk) = allC(c);
end
if nk < 3, return; end
tr = tr(1:nk); keep = keep(1:nk);

X = zeros(nk, numel(trialUIDs));
for c = 1:nk
	X(c, :) = tr{c}(:, idx1s).';
end
cellUIDs = keep;

CellTbl = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.ZLayer = string(CellTbl.ZLayer);
mc = CellTbl(CellTbl.Mouse == string(mouseName), :);
[has, loc] = ismember(cellUIDs, mc.CellUID);
layers = strings(nk, 1);
layers(has) = mc.ZLayer(loc(has));
end

function div = iDivergence(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise  = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function T = iEmptyDiv()
T = table("", nan, nan, nan, 0, 0, ...
	'VariableNames', {'Mouse','DivAll','DivL23','DivL5','NCells','CellUID'});
end

function T = iNormTable(T)
T.Mouse = string(T.Mouse);
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
end

%% ---------- reactivation ----------

function p = iWeightedPTL(R)
%两层按 learned-active 细胞数加权合并成一个每鼠 P(T|L)
n23 = double(R.NLearnedActive23);  n5 = double(R.NLearnedActive5);
n23(~isfinite(n23)) = 0;           n5(~isfinite(n5)) = 0;
w23 = n23 .* double(R.Prob23);
w5  = n5  .* double(R.Prob5);
w23(~isfinite(w23)) = 0;           w5(~isfinite(w5)) = 0;
nTot = n23 + n5;
p = (w23 + w5) ./ nTot;
p(nTot == 0) = NaN;
end
