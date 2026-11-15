% 表征复用（第十五步）：降维后再做形式化分解 —— 试图把"目标信度 0.36"的天花板抬起来
%
% 上一轮的硬限制：未舔试次均值模式的 split-half 信度只有 ≈0.36，
% 于是任何模板能解释的 R² 都被衰减到 ≤ 0.36，实测只有 0.02–0.04 → 无法定论。
%
% 本轮把模式向量降维（只用与目标无关的数据定降维方向，避免循环）：
%   mode = "all"  : 不降维（复现上一轮，作为对照）
%   mode = "ens"  : 只保留 Learned 阶段响应最强的细胞（逐细胞 t>2.5，不足则取 top 60）
%   mode = "pc10" : 用 Learned/AudioWater 试次矩阵的前 10 个 PC 作为基底（细胞×10）
%   mode = "pc20" : 同上，前 20 个 PC
%
% 对每种 mode 报告：
%   rel     —— 目标（未舔试次均值模式）的 split-half 信度
%   R2      —— [vC, vL] 解释的留出方差
%   uL      —— 学会模板的独特贡献
%   uU      —— 动作轴（Transfer hit−miss，仅训练半估计）的独特贡献
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
if ~exist('CohortName', 'var'), CohortName = "ALB"; end
switch CohortName
	case "ALB", DS = TransferLearning.AudioLightBaseline();
	otherwise,  DS = TransferLearning.Vacation7();
end
fprintf('\n########## 队列：%s ##########\n', CohortName);

modes = ["all", "ens", "pc10", "pc20"];
Rows = {};
for md = modes
	fprintf('\n--- 降维方式：%s ---\n', md);
	fprintf('%-9s %6s %6s | %7s %6s | %8s %8s | %8s %8s\n', ...
		'鼠', 'nCell', 'nDim', 'rel', 'nMiss', 'R2[CL]', 'uL', 'R2[CLu]', 'uU');
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
		nWO = iQuery(DS, m, best, "WaterOnly");
		dtL = iFirst(DS, m, "Learned", "AudioWater");
		dtT = iFirst(DS, m, "Transfer", "LightWater");
		if isnat(dtL) || isnat(dtT), continue; end
		nAW = iQuery(DS, m, dtL, "AudioWater");
		nLW = iQuery(DS, m, dtT, "LightWater");
		if any(cellfun(@isempty, {nLO, nAW, nLW})), continue; end

		cells = intersect(intersect(nLO.CellUID, nAW.CellUID), nLW.CellUID);
		if numel(cells) < 50, continue; end
		MLO = iMat(nLO, cells, iW); [MAW, bAW] = iMatBeh(DS, nAW, cells, iW);
		[MLW, bLW] = iMatBeh(DS, nLW, cells, iW);
		okAH = find(bAW == 1); okH = find(bLW == 1); okM = find(bLW == 0);
		if numel(okAH) < 4 || numel(okM) < 10, continue; end

		% ---- 降维基底（只用 Learned 试次，与目标无关）----
		[R, nDim] = iReduce(md, MAW, okAH);
		if isempty(R), continue; end
		ZLO = R.' * MLO; ZAW = R.' * MAW; ZLW = R.' * MLW;
		vC = mean(ZLO, 2, 'omitnan'); vC = vC - mean(vC);
		vL = mean(ZAW(:, okAH), 2, 'omitnan'); vL = vL - mean(vL);

		% ---- 目标信度 ----
		rh = nan(20, 1);
		for s2 = 1:20
			p2 = randperm(numel(okM));
			a1 = okM(p2(1:floor(numel(okM)/2))); a2 = okM(p2(floor(numel(okM)/2)+1:end));
			rh(s2) = iCorr(mean(ZLW(:, a1), 2, 'omitnan'), mean(ZLW(:, a2), 2, 'omitnan'));
		end
		r0 = mean(rh, 'omitnan');
		if isfinite(r0) && r0 > -1, rel = 2*r0/(1+r0); else, rel = NaN; end

		doAct = numel(okH) >= 6;
		r2a = nan(nSplit, 1); uLa = nan(nSplit, 1);
		r2b = nan(nSplit, 1); uUb = nan(nSplit, 1);
		for s = 1:nSplit
			pH = randperm(numel(okH)); pM = randperm(numel(okM));
			hH1 = okH(pH(1:floor(numel(okH)/2))); hH2 = okH(pH(floor(numel(okH)/2)+1:end));
			hM1 = okM(pM(1:floor(numel(okM)/2))); hM2 = okM(pM(floor(numel(okM)/2)+1:end));
			if numel(hM1) < 3 || numel(hM2) < 3, continue; end
			[r1, l1] = iEval(vC, vL, ZLW, hH1, hM1, hM2, false);
			r2a(s) = r1; uLa(s) = l1;
			if doAct
				[r2, l2, u2] = iEval(vC, vL, ZLW, hH1, hM1, hM2, true);
				r2b(s) = r2; uUb(s) = u2;
			end
			[r1, l1] = iEval(vC, vL, ZLW, hH2, hM2, hM1, false);
			r2a(s) = mean([r2a(s), r1], 'omitnan'); uLa(s) = mean([uLa(s), l1], 'omitnan');
			if doAct
				[r2, l2, u2] = iEval(vC, vL, ZLW, hH2, hM2, hM1, true);
				r2b(s) = mean([r2b(s), r2], 'omitnan'); uUb(s) = mean([uUb(s), u2], 'omitnan');
			end
		end
		fprintf('%-9s %6d %6d | %7.3f %6d | %8.3f %8.3f | %8s %8s\n', string(m), size(R, 1), nDim, rel, numel(okM), ...
			mean(r2a, 'omitnan'), mean(uLa, 'omitnan'), ...
			sprintf('%.3f', mean(r2b, 'omitnan')), sprintf('%.3f', mean(uUb, 'omitnan')));
		Rows(end+1, :) = {CohortName, string(md), string(m), size(R, 1), nDim, rel, numel(okM), ...
			mean(r2a, 'omitnan'), mean(uLa, 'omitnan'), mean(r2b, 'omitnan'), mean(uUb, 'omitnan')}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Mode", "Mouse", "NCell", "NDim", "Rel_target", "nMiss", ...
	"R2_CL", "uL", "R2_CLu", "uU"]);
csvPath = fullfile(thisDir, sprintf('RepresentationReuse_DimReduced_%s.csv', CohortName));
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 汇总（逐鼠均值 ± SEM）===============\n');
f = @(x) sprintf('%+.3f±%.3f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
for md = modes
	sel = T.Mode == md;
	if ~any(sel), continue; end
	fprintf('%-5s n=%2d | rel=%s | R2[CL]=%s | **uL=%s (p=%.3g)** | R2[CLu]=%s | uU=%s\n', ...
		md, sum(sel), f(T.Rel_target(sel)), f(T.R2_CL(sel)), f(T.uL(sel)), iSafeP(T.uL(sel)), ...
		f(T.R2_CLu(sel)), f(T.uU(sel)));
end

%% ========== local ==========
function [R, nDim] = iReduce(md, MAW, okAH)
% 返回 cells × nDim 的投影基底（只用 Learned 试次构造）
X = MAW(:, okAH);
nC = size(X, 1);
switch md
	case "all"
		R = eye(nC);
	case "ens"
		mu = mean(X, 2, 'omitnan');
		sd = std(X, 0, 2, 'omitnan') ./ sqrt(size(X, 2));
		t = mu ./ sd;
		t(~isfinite(t)) = 0;
		keep = find(t > 2.5);
		if numel(keep) < 30
			[~, ord] = sort(t, 'descend');
			keep = ord(1:min(60, nC));
		end
		R = zeros(nC, numel(keep));
		R(sub2ind([nC, numel(keep)], keep(:), (1:numel(keep))')) = 1;
	case {"pc10", "pc20"}
		k = 10; if md == "pc20", k = 20; end
		Xc = X - mean(X, 2, 'omitnan');
		Xc(~isfinite(Xc)) = 0;
		[U, ~, ~] = svd(Xc, 'econ');
		k = min(k, size(U, 2));
		R = U(:, 1:k);
	otherwise
		R = [];
end
nDim = size(R, 2);
end

function [r2, uL, uU] = iEval(vC, vL, Z, hHit, hMissTr, hMissTe, withU)
uL = NaN; uU = NaN;
yTr = mean(Z(:, hMissTr), 2, 'omitnan'); yTr = yTr - mean(yTr, 'omitnan');
yTe = mean(Z(:, hMissTe), 2, 'omitnan'); yTe = yTe - mean(yTe, 'omitnan');
u = mean(Z(:, hHit), 2, 'omitnan') - mean(Z(:, hMissTr), 2, 'omitnan');
u = u - mean(u, 'omitnan');
if withU, X = [vC, vL, u]; else, X = [vC, vL]; end
ok = all(isfinite(X), 2) & isfinite(yTr) & isfinite(yTe);
if sum(ok) < 10, r2 = NaN; return; end
X = X(ok, :); yTr = yTr(ok); yTe = yTe(ok);
b = X \ yTr; p = X * b;
r2 = 1 - sum((yTe - p).^2) / sum(yTe.^2);
Xk = X(:, [1, 3:size(X, 2)]); bk = Xk \ yTr; pk = Xk * bk;
uL = r2 - (1 - sum((yTe - pk).^2) / sum(yTe.^2));
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

function r = iCorr(a, b)
a = a(:); b = b(:);
ok = isfinite(a) & isfinite(b);
if sum(ok) < 5, r = NaN; return; end
a = a(ok); b = b(ok);
if std(a) == 0 || std(b) == 0, r = NaN; return; end
c = corrcoef(a, b); r = c(1, 2);
end

function p = iSafeP(x)
x = x(isfinite(x));
if numel(x) < 3 || all(x == 0), p = NaN; else, p = signrank(x); end
end
