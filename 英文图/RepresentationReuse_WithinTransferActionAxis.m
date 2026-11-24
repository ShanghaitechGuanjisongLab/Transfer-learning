% 表征复用（第十四步）：用"迁移期内部的 hit−miss"当动作模板，检验学会模板的独特贡献是否幸存
%
% 上一轮的形式化分解里，动作模板用的是 Naive 的 WaterOnly（无线索+给水），
% 它捕捉不到"线索驱动的预期性舔"，所以 u_A≈0 既不能证明动作无关、也没能有效排除动作。
%
% 本脚本换成**最精确的动作模板**：Transfer session 内部的 hit − miss 对比
%   —— 同一线索、同一 session、同一批细胞，唯一差别就是舔没舔/有没有结局。
%
% 去循环性的做法（关键）：
%   · 把 Transfer 试次**分层**分半（hit 与 miss 各自对半分）→ H1 / H2
%   · 动作轴 u 只用**训练半**估计：u = mean(hit@train) − mean(miss@train)
%   · 目标 y 只用**测试半的未舔试次均值**（完全无动作）
%   · β 在训练半的未舔试次均值上拟合，R² 在测试半的未舔试次均值上评估
%
% 对比两种模型：
%   M_a: [vC, vL]              —— 未学线索 + 学会线索
%   M_b: [vC, vL, u]           —— 再加入动作轴
%   unique_L = R²(全) − R²(去 vL)
%   ⇒ 若 M_b 下 unique_L 仍显著 > 0，则"学会模板的贡献"不是动作轴能解释的
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
iW = find(tAll >= 0 & tAll <= 1.5);
nSplit = 40; rng(20261113, 'twister');
minHit = 0; minMiss = 10;

% 可用 CohortName 指定队列后重复 run 本脚本（"ALB" / "V7"）
if ~exist('CohortName', 'var'), CohortName = "ALB"; end
switch CohortName
	case "ALB", DS = TransferLearning.AudioLightBaseline();
	otherwise,  DS = TransferLearning.Vacation7();
end
fprintf('\n########## 队列：%s ##########\n', CohortName);
Rows = {};
	fprintf('%-9s %6s %4s %5s | %7s %7s | %8s %8s | %8s %8s %8s\n', ...
	'鼠', 'nCell', 'hit', 'miss', 'AUC(动作轴)', 'AUC_CV', 'R2[CL]', 'uL_前', 'R2[CLu]', 'uL_后', 'uC_后', 'uU(动作)');
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
	dtL = iFirst(DS, m, "Learned", "AudioWater");
	dtT = iFirst(DS, m, "Transfer", "LightWater");
	if isnat(dtL) || isnat(dtT), continue; end
	nAW = iQuery(DS, m, dtL, "AudioWater");
	nLW = iQuery(DS, m, dtT, "LightWater");
	if any(cellfun(@isempty, {nLO, nAW, nLW})), continue; end

	cells = intersect(intersect(nLO.CellUID, nAW.CellUID), nLW.CellUID);
	if numel(cells) < 50, continue; end
	MLO = iMat(nLO, cells, iW);
	[MAW, bAW] = iMatBeh(DS, nAW, cells, iW);
	[MLW, bLW] = iMatBeh(DS, nLW, cells, iW);

	okAH = find(bAW == 1);
	okH = find(bLW == 1); okM = find(bLW == 0);
	if numel(okAH) < 4 || numel(okM) < minMiss, continue; end
	doAct = numel(okH) >= 6;      % hit 太少则估不出动作轴

	vC = mean(MLO, 2, 'omitnan');
	vL = mean(MAW(:, okAH), 2, 'omitnan');
	vC = vC - mean(vC); vL = vL - mean(vL);

	% 动作轴的效度检查（全程）
	uAll = mean(MLW(:, okH), 2, 'omitnan') - mean(MLW(:, okM), 2, 'omitnan');
	aucU = iAUC(iProj(MLW(:, okH), uAll), iProj(MLW(:, okM), uAll));
	aucUCV = iSplitHalfAUC(MLW(:, okH), MLW(:, okM));   % 正对照主指标：未见试次上的 hit vs miss 解码
	% 目标（未舔试次均值模式）的可信度：split-half → Spearman-Brown
	rh = nan(20, 1);
	for s2 = 1:20
		p2 = randperm(numel(okM));
		a1 = okM(p2(1:floor(numel(okM)/2))); a2 = okM(p2(floor(numel(okM)/2)+1:end));
		rh(s2) = iCorr(mean(MLW(:, a1), 2, 'omitnan'), mean(MLW(:, a2), 2, 'omitnan'));
	end
	r0 = mean(rh, 'omitnan');
	if isfinite(r0) && r0 > -1, relTarget = 2*r0/(1+r0); else, relTarget = NaN; end

	r2a = zeros(nSplit, 1); uLa = zeros(nSplit, 1);
	r2b = zeros(nSplit, 1); uLb = zeros(nSplit, 1); uCb = zeros(nSplit, 1); uUb = zeros(nSplit, 1);
	for s = 1:nSplit
		% 分层分半
		pH = randperm(numel(okH)); pM = randperm(numel(okM));
		hH1 = okH(pH(1:floor(numel(okH)/2))); hH2 = okH(pH(floor(numel(okH)/2)+1:end));
		hM1 = okM(pM(1:floor(numel(okM)/2))); hM2 = okM(pM(floor(numel(okM)/2)+1:end));
		if numel(hM1) < 3 || numel(hM2) < 3, continue; end

		% fold A：训练 H1、测试 H2
		[r2a(s), uLa(s)] = iEval(vC, vL, MLW, hH1, hM1, hM2, false);
		[r2b(s), uLb(s), uCb(s), uUb(s)] = iEval(vC, vL, MLW, hH1, hM1, hM2, true);
		% fold B：训练 H2、测试 H1
		[ra, la] = iEval(vC, vL, MLW, hH2, hM2, hM1, false);
		[rb, lb, cb, ub] = iEval(vC, vL, MLW, hH2, hM2, hM1, true);
		if isfinite(ra), r2a(s) = mean([r2a(s), ra], 'omitnan'); uLa(s) = mean([uLa(s), la], 'omitnan'); end
		if isfinite(rb) && doAct, r2b(s) = mean([r2b(s), rb], 'omitnan'); uLb(s) = mean([uLb(s), lb], 'omitnan');
			uCb(s) = mean([uCb(s), cb], 'omitnan'); uUb(s) = mean([uUb(s), ub], 'omitnan'); end
	end

	fprintf('%-9s %6d %4d %5d | %7.2f %6.2f | %8.3f %8.3f | %8.3f %8.3f %8.3f\n', string(m), numel(cells), ...
		numel(okH), numel(okM), aucU, aucUCV, relTarget, mean(r2a, 'omitnan'), mean(uLa, 'omitnan'), ...
		mean(r2b, 'omitnan'), mean(uLb, 'omitnan'), mean(uCb, 'omitnan'), mean(uUb, 'omitnan'));
	Rows(end+1, :) = {string(m), numel(cells), numel(okH), numel(okM), aucU, aucUCV, relTarget, ...
		mean(r2a, 'omitnan'), mean(uLa, 'omitnan'), ...
		mean(r2b, 'omitnan'), mean(uLb, 'omitnan'), mean(uCb, 'omitnan'), mean(uUb, 'omitnan')}; %#ok<SAGROW>
end

T = cell2table(Rows, 'VariableNames', ["Mouse", "NCells", "nHit", "nMiss", "AUC_actionAxis", ...
	"AUC_actionAxisCV", "Rel_target", "R2_CL", "uniqL_before", "R2_CLu", "uniqL_after", ...
	"uniqC_after", "uniqU_after"]);
csvPath = fullfile(thisDir, sprintf('RepresentationReuse_WithinTransferActionAxis_%s.csv', CohortName));
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠，均值 ± SEM；p 为 vs 0 的 signrank）===============\n');
f = @(x) sprintf('%+.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
fprintf('n=%d 鼠 | 动作轴效度 AUC(hit vs miss, 全数据)=%s | AUC_CV(未见试次)=%s (vs 0.5, p=%.3g)\n', ...
	height(T), f(T.AUC_actionAxis), f(T.AUC_actionAxisCV), iSafeP(T.AUC_actionAxisCV - 0.5));
fprintf('  目标可信度 rel(miss 均值模式, split-half)=%s  ⇒ R² 上限受此限制\n', f(T.Rel_target));
fprintf('  校正后的 R²[CL]/rel=%s ，unique_L/rel=%s\n', ...
	f(T.R2_CL ./ T.Rel_target), f(T.uniqL_before ./ T.Rel_target));
fprintf('  模型 M_a [vC,vL]      : R²=%s , unique_L=%s (p=%.3g)\n', ...
	f(T.R2_CL), f(T.uniqL_before), iSafeP(T.uniqL_before));
fprintf('  模型 M_b [vC,vL,u]    : R²=%s , unique_L=%s (p=%.3g)  unique_C=%s (p=%.3g)  unique_u=%s (p=%.3g)\n', ...
	f(T.R2_CLu), f(T.uniqL_after), iSafeP(T.uniqL_after), ...
	f(T.uniqC_after), iSafeP(T.uniqC_after), f(T.uniqU_after), iSafeP(T.uniqU_after));

%% ========== local ==========
function [r2, uL, uC, uU] = iEval(vC, vL, MLW, hHit, hMissTr, hMissTe, withU)
uL = NaN; uC = NaN; uU = NaN;
yTr = mean(MLW(:, hMissTr), 2, 'omitnan'); yTr = yTr - mean(yTr, 'omitnan');
yTe = mean(MLW(:, hMissTe), 2, 'omitnan'); yTe = yTe - mean(yTe, 'omitnan');
u = mean(MLW(:, hHit), 2, 'omitnan') - mean(MLW(:, hMissTr), 2, 'omitnan');
u = u - mean(u, 'omitnan');
if withU
	X = [vC, vL, u]; idxC = 1; idxL = 2;
else
	X = [vC, vL];   idxC = 1; idxL = 2;
end
ok = all(isfinite(X), 2) & isfinite(yTr) & isfinite(yTe);
if sum(ok) < 20, r2 = NaN; return; end
X = X(ok, :); yTr = yTr(ok); yTe = yTe(ok);
b = X \ yTr; p = X * b;
r2 = 1 - sum((yTe - p).^2) / sum(yTe.^2);
Xk = X(:, setdiff(1:size(X, 2), idxL)); bk = Xk \ yTr; pk = Xk * bk;
uL = r2 - (1 - sum((yTe - pk).^2) / sum(yTe.^2));
Xk = X(:, setdiff(1:size(X, 2), idxC)); bk = Xk \ yTr; pk = Xk * bk;
uC = r2 - (1 - sum((yTe - pk).^2) / sum(yTe.^2));
if withU
	Xk = X(:, 1:2); bk = Xk \ yTr; pk = Xk * bk;
	uU = r2 - (1 - sum((yTe - pk).^2) / sum(yTe.^2));
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
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal(:, iW));
M = nan(numel(cells), numel(Tu));
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

function p = iProj(M, w)
p = (w(:).' * M).';
end

function r = iCorr(a, b)
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 10, r = NaN; return; end
a = a(ok); b = b(ok);
if std(a) == 0 || std(b) == 0, r = NaN; return; end
c = corrcoef(a, b); r = c(1, 2);
end

function a = iAUC(x, y)
x = x(isfinite(x)); y = y(isfinite(y));
if isempty(x) || isempty(y), a = NaN; return; end
allv = [x(:); y(:)]; r = tiedrank(allv);
nx = numel(x); ny = numel(y);
a = (sum(r(1:nx)) - nx*(nx+1)/2) / (nx*ny);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end

function a = iSplitHalfAUC(X1, X2)
% 同条件内分半：一半试次拟合判别轴，另一半评 AUC，两折互换后平均
if size(X1, 2) < 4 || size(X2, 2) < 4, a = NaN; return; end
n1 = size(X1, 2); p1 = randperm(n1); h1 = floor(n1/2);
n2 = size(X2, 2); p2 = randperm(n2); h2 = floor(n2/2);
A1 = X1(:, p1(1:h1)); B1 = X1(:, p1(h1+1:end));
A2 = X2(:, p2(1:h2)); B2 = X2(:, p2(h2+1:end));
w  = mean(A1, 2, 'omitnan') - mean(A2, 2, 'omitnan');
a1 = iAUC(iProj(B1, w), iProj(B2, w));
w2 = mean(B1, 2, 'omitnan') - mean(B2, 2, 'omitnan');
a2 = iAUC(iProj(A1, w2), iProj(A2, w2));
a = mean([a1 a2], 'omitnan');
end
