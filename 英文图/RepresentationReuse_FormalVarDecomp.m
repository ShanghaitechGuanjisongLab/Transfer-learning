% 表征复用（第十三步）：三元模板的形式化方差分解（模型比较，而非两两相关）
%
% 问题：两两相关（r、AUC、d2）无法回答"迁移期模式到底被什么解释"。
%       本脚本把迁移期群体模式同时投影到三个模板上，用**交叉验证的独特方差**做模型比较：
%
%   模板（都来自独立 session，与目标无关）：
%     vL = Learned/AudioWater(hit)     学会的声线索（含动作）
%     vC = Naive/LightOnly             未学的光线索（基本无动作）
%     vA = Naive/WaterOnly             只有给水+舔、无线索（纯动作/结局）
%
%   目标：Transfer/LightWater 的群体模式（全部试次 / 仅未舔 / 仅舔）
%
%   做法：Z = [1, vC, vL, vA]，把目标对 Z 做最小二乘。
%     · 2 折交叉验证：β 在一半 Transfer 试次上拟合，R² 在另一半上评估（避免过拟合）
%     · 20 次随机分半取平均
%     · 独特方差 unique_k = R²(全模型) − R²(去掉模板 k)
%       ⇒ **unique_L 显著 > 0** 才等于"学会线索模板在未学线索+动作之外仍有独立贡献"
%   同时报告 unique_C、unique_A 作为对照。
%
% 口径：所有向量先按细胞中心化（去掉整体偏移），R² 由"模式"解释；
%       另给一个不移除截距的版本（含整体水平）。
%
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧；窗口 0–1.5 s

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iW = find(tAll >= 0 & tAll <= 1.5);   % 取完整响应窗（不声称“无舔”，故无需限制在 1 s）
nSplit = 20; rng(20261113, 'twister');
if ~exist('LayerSel', 'var'), LayerSel = ""; end
if ~exist('CohortSel', 'var'), CohortSel = "ALB"; end
switch string(CohortSel)
	case "ALB", DS = TransferLearning.AudioLightBaseline(); cohortSuffix = "";
	case "V7",  DS = TransferLearning.Vacation7();           cohortSuffix = "_V7";
	case "TH",  DS = TransferLearning.THInhibit();           cohortSuffix = "_TH";
	otherwise, error('FormalVarDecomp:badCohort', '未知队列 %s', CohortSel);
end
fprintf('队列: %s\n', CohortSel);
Rows = {};
fprintf('%-9s %6s %5s | %8s | %8s %8s %8s | %7s %7s %7s\n', ...
	'鼠', 'nCell', 'nTrn', 'R2全', 'u_C(未学)', 'u_L(学会)', 'u_A(动作)', 'betaC', 'betaL', 'betaA');
for m = unique(iMouse(DS))'
	[dts, stim] = iList(DS, m);
	isN = stim == "LightOnly"; isA = stim == "AudioOnly";
	best = NaT; bestN = 0;
	for k = unique(dts(isN))'
		n = min(sum(dts == k & isN), sum(dts == k & isA));
		if n > bestN, bestN = n; best = k; end
	end
	if isnat(best) || bestN < 5, continue; end
	nLO = iQuery(DS, m, best, "LightOnly");
	nAO = iQuery(DS, m, best, "AudioOnly");
	nWO = iQuery(DS, m, best, "WaterOnly");
	dtL = iFirst(DS, m, "Learned", "AudioWater");
	dtT = iFirst(DS, m, "Transfer", "LightWater");
	if isnat(dtL) || isnat(dtT) || isempty(nWO), continue; end
	nAW = iQuery(DS, m, dtL, "AudioWater");
	nLW = iQuery(DS, m, dtT, "LightWater");
	if any(cellfun(@isempty, {nLO, nAW, nLW})), continue; end

	cells = intersect(intersect(nLO.CellUID, nWO.CellUID), intersect(nAW.CellUID, nLW.CellUID));
	if strlength(LayerSel) > 0
		Cx = DS.Cells; Cx.CellUID = uint64(Cx.CellUID); Cx.ZLayer = string(Cx.ZLayer);
		[okm, idxm] = ismember(cells, Cx.CellUID);
		keepm = false(size(cells)); keepm(okm) = Cx.ZLayer(idxm(okm)) == LayerSel;
		cells = cells(keepm);
	end
	if numel(cells) < 50, continue; end
	MLO = iMat(nLO, cells, iW);
	[MAW, bAW] = iMatBeh(DS, nAW, cells, iW);
	[MLW, bLW] = iMatBeh(DS, nLW, cells, iW);
	MWO = iMat(nWO, cells, iW);

	okAH = find(bAW == 1);
	if numel(okAH) < 4, continue; end
	vL = mean(MAW(:, okAH), 2, 'omitnan');
	vC = mean(MLO, 2, 'omitnan');
	vA = mean(MWO, 2, 'omitnan');

	% 目标子集：全部 / 未舔 / 舔了
	Subs = {"all", 1:size(MLW, 2); "miss", find(bLW == 0); "hit", find(bLW == 1)};
	for s = 1:3
		idx = Subs{s, 2};
		if numel(idx) < 8, continue; end
		[r2, uC, uL, uA, bb] = iVarDecomp(vL, vC, vA, MLW(:, idx), nSplit);
		fprintf('%-9s %6d %5d | %8.3f | %8.3f %8.3f %8.3f | %7.2f %7.2f %7.2f\n', ...
			string(m) + ":" + Subs{s, 1}, numel(cells), numel(idx), r2, uC, uL, uA, bb(1), bb(2), bb(3));
		Rows(end+1, :) = {string(m), string(Subs{s, 1}), numel(cells), numel(idx), r2, uC, uL, uA, bb(1), bb(2), bb(3)}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Mouse", "Subset", "NCells", "nTrn", ...
	"R2_full", "uniq_C", "uniq_L", "uniq_A", "beta_C", "beta_L", "beta_A"]);
suffix2 = cohortSuffix;
if strlength(LayerSel) > 0, suffix2 = cohortSuffix + "_" + replace(LayerSel, "/", "-"); end
csvPath = fullfile(thisDir, "RepresentationReuse_FormalVarDecomp" + suffix2 + ".csv");
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠，均值 ± SEM；p 为 vs 0 的 signrank）===============\n');
fprintf('u_L > 0 ⇒ 学会线索模板在"未学线索 + 动作"之外仍有独立贡献\n');
f = @(x) sprintf('%+.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
for s = ["all", "miss", "hit"]
	sel = T.Subset == s;
	if sum(sel) < 3, continue; end
	fprintf('%-5s n=%2d | R2全=%s | u_C=%s (p=%.3g) | **u_L=%s (p=%.3g)** | u_A=%s (p=%.3g)\n', ...
		s, sum(sel), f(T.R2_full(sel)), f(T.uniq_C(sel)), iSafeP(T.uniq_C(sel)), ...
		f(T.uniq_L(sel)), iSafeP(T.uniq_L(sel)), f(T.uniq_A(sel)), iSafeP(T.uniq_A(sel)));
	fprintf('       beta: C=%s  L=%s  A=%s\n', f(T.beta_C(sel)), f(T.beta_L(sel)), f(T.beta_A(sel)));
end

%% ========== local ==========
function [r2, uC, uL, uA, bb] = iVarDecomp(vL, vC, vA, MT, nSplit)
% 若模板数不足或目标太少则返回 NaN
r2 = NaN; uC = NaN; uL = NaN; uA = NaN; bb = nan(1, 3);
nT = size(MT, 2);
if nT < 8, return; end
Tmpl = {vC, vL, vA};   % 顺序：C, L, A
nK = 3;
r2v = zeros(nSplit, 1); uv = zeros(nSplit, nK); bv = zeros(nSplit, nK);
for s = 1:nSplit
	idx = randperm(nT);
	h1 = idx(1:floor(nT/2)); h2 = idx(floor(nT/2)+1:end);
	y1 = mean(MT(:, h1), 2, 'omitnan');
	y2 = mean(MT(:, h2), 2, 'omitnan');
	% 模板固定，先按细胞中心化
	Tc = cellfun(@(v) v - mean(v, 'omitnan'), Tmpl, 'UniformOutput', false);
	[r2v(s), uv(s, :), b1] = iFitEval(Tc, y1, y2);
	bv(s, :) = b1;
end
r2 = mean(r2v, 'omitnan');
uC = mean(uv(:, 1), 'omitnan');
uL = mean(uv(:, 2), 'omitnan');
uA = mean(uv(:, 3), 'omitnan');
bb = mean(bv, 1, 'omitnan');
end

function [r2, u, b] = iFitEval(Tc, yTrain, yTest)
% 目标也中心化；拟合无截距回归；在测试目标上评估
yTr = yTrain - mean(yTrain, 'omitnan');
yTe = yTest - mean(yTest, 'omitnan');
X = [Tc{1}, Tc{2}, Tc{3}];
ok = all(isfinite(X), 2) & isfinite(yTr);
if sum(ok) < 20, r2 = NaN; u = nan(1, 3); b = nan(1, 3); return; end
X = X(ok, :); yTr = yTr(ok); yTe = yTe(ok);
b = X \ yTr;
pred = X * b;
r2 = 1 - sum((yTe - pred).^2) / sum(yTe.^2);
u = nan(1, 3);
for k = 1:3
	Xk = X(:, setdiff(1:3, k));
	bk = Xk \ yTr;
	pk = Xk * bk;
	r2k = 1 - sum((yTe - pk).^2) / sum(yTe.^2);
	u(k) = r2 - r2k;
end
end

function u = iMouse(DS)
T = DS.TableQuery(["Mouse", "DateTime"]);
u = unique(string(T.Mouse));
end

function [dts, stim] = iList(DS, m)
T = DS.TableQuery(["Mouse", "DateTime", "Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus);
T = T(T.Mouse == m & T.Stimulus ~= "StartMonitor" & T.Stimulus ~= "StopMonitor", :);
dts = T.DateTime; stim = T.Stimulus;
end

function dt = iFirst(DS, m, ph, stim)
T = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
T.Mouse = string(T.Mouse); T.Phase = string(T.Phase); T.Stimulus = string(T.Stimulus);
sel = T.Mouse == m & T.Phase == ph & T.Stimulus == stim;
if ~any(sel), dt = NaT; return; end
d = sort(unique(T.DateTime(sel))); dt = d(1);
end

function nts = iQuery(DS, mouse, dt, stim)
nts = [];
try
	nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), UniExp.Flags.ZScore, 1:24);
catch
	return;
end
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
nts.CellUID = uint64(nts.CellUID);
nts.TrialUID = uint64(nts.TrialUID);
end

function M = iMat(nts, cells, iW)
M = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
[~, jTu] = ismember(nts.TrialUID, Tu);
nT = numel(Tu);
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal(:, iW));
M = nan(numel(cells), nT);
for i = 1:numel(cells)
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	M(i, jTu(rows)) = mean(sig(rows, :), 2);
end
end

function [M, b] = iMatBeh(DS, nts, cells, iW)
M = iMat(nts, cells, iW); b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
