% 表征复用（第十步）：二维（时空）判别 —— 用整条群体轨迹而不是单点
%
% 上一版（第九步）把每个试次压成"窗口均值"一个标量。本版保留时间维：
%   轴 w(cell, t) = 轨迹_AO(cell,t) − 轨迹_LO(cell,t)，t ∈ [0, 1.5] s
%   投影 p(trial) = Σ_{cell,t} X(cell,t,trial) · w(cell,t)
%   ⇒ 判别利用的是**时空模式**，而不是单一时间窗的幅度
%
% 同时算 1D 版本（窗口均值）作对照，看多出的时间信息是帮忙还是只增加过拟合。
%
% 关键控制（沿用第九步）：
%   · 2 折交叉验证（轴在一半试次上定、另一半上测）
%   · Transfer 的 miss-only / hit-only 分别判别 —— 检验是否由动作造成
%   · 动作对照：同一根轴区分 WaterOnly 与线索类（应 ≈0.5）
%   · 对称对照：AW/LO 应 ≫0.5，LW/AO 应 ≪0.5
%
% 队列：ALB（即时）与 V7（7 天）
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iT   = find(tAll >= 0 & tAll <= 1.5);        % 时空判别的帧集合
iW   = find(tAll >= 0 & tAll <= 1.5);        % 1D 版本用同一窗口（便于直接比较）
fprintf('时空判别使用 %d 帧（%.2f–%.2f s）\n', numel(iT), tAll(iT(1)), tAll(iT(end)));

cfg = struct();
cfg(1).Name = "ALB 声→光 即时"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(2).Name = "V7 声→光 7天";  cfg(2).DS = TransferLearning.Vacation7();

Rows = {};
for ic = 1:2
	DS = cfg(ic).DS;
	fprintf('\n=============== %s ===============\n', cfg(ic).Name);
	fprintf('%-9s %6s | %8s %8s | %8s %8s | %8s %8s | %8s %8s | %6s\n', ...
		'鼠', 'nCell', '2D训练', '2D留出', '1D留出', '动作ctl', '2D AW/LW', '1D AW/LW', '2D AW/LWm', '1D AW/LWm', 'nMiss');
	for m = unique(iMouse(DS))'
		% Naive：同 session 的 LO/AO(+WO)
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
		if isnat(dtL) || isnat(dtT), continue; end
		nAW = iQuery(DS, m, dtL, "AudioWater");
		nLW = iQuery(DS, m, dtT, "LightWater");
		if any(cellfun(@isempty, {nLO, nAO, nAW, nLW})), continue; end

		cells = intersect(intersect(nLO.CellUID, nAO.CellUID), intersect(nAW.CellUID, nLW.CellUID));
		if ~isempty(nWO), cells = intersect(cells, nWO.CellUID); end
		if numel(cells) < 50, continue; end

		% 2D：细胞 × 试次 × 帧
		XLO = iCell3(DS, nLO, cells, iT); XAO = iCell3(DS, nAO, cells, iT);
		XAW = iCell3(DS, nAW, cells, iT); XLW = iCell3(DS, nLW, cells, iT);
		if ~isempty(nWO), XWO = iCell3(DS, nWO, cells, iT); else, XWO = []; end
		nF = numel(iT);
		% 1D：窗口均值
		M1 = @(X) reshape(mean(X, 3, 'omitnan'), size(X, 1), size(X, 2));

		% ---- 2D 交叉验证 ----
		i1 = 1:2:size(XAO, 2); i2 = 2:2:size(XAO, 2);
		j1 = 1:2:size(XLO, 2); j2 = 2:2:size(XLO, 2);
		if isempty(i2) || isempty(j2), continue; end
		a2tr = nan(2, 1); a2cv = nan(2, 1); a1cv = nan(2, 1); a2act = nan(2, 1);
		for f = 1:2
			if f == 1, aTr = i1; aTe = i2; lTr = j1; lTe = j2;
			else,      aTr = i2; aTe = i1; lTr = j2; lTe = j1; end
			w2 = mean(XAO(:, aTr, :), 2, 'omitnan') - mean(XLO(:, lTr, :), 2, 'omitnan');   % 细胞×1×帧
			if all(w2(:) == 0), continue; end
			w1 = mean(M1(XAO(:, aTr, :)), 2, 'omitnan') - mean(M1(XLO(:, lTr, :)), 2, 'omitnan');
			a2tr(f) = iAUC(iProj2(XAO(:, aTr, :), w2), iProj2(XLO(:, lTr, :), w2));
			a2cv(f) = iAUC(iProj2(XAO(:, aTe, :), w2), iProj2(XLO(:, lTe, :), w2));
			a1cv(f) = iAUC(iProj1(M1(XAO(:, aTe, :)), w1), iProj1(M1(XLO(:, lTe, :)), w1));
			if ~isempty(XWO)
				a2act(f) = iAUC(iProj2(XWO, w2), iProj2(cat(2, XAO(:, aTe, :), XLO(:, lTe, :)), w2));
			end
		end
		% ---- 全程轴：迁移期判别 ----
		w2F = mean(XAO, 2, 'omitnan') - mean(XLO, 2, 'omitnan');
		w1F = mean(M1(XAO), 2, 'omitnan') - mean(M1(XLO), 2, 'omitnan');
		pAW2 = iProj2(XAW, w2F); pLW2 = iProj2(XLW, w2F);
		pAW1 = iProj1(M1(XAW), w1F); pLW1 = iProj1(M1(XLW), w1F);
		aAWLW2 = iAUC(pAW2, pLW2); aAWLW1 = iAUC(pAW1, pLW1);
		bLW = iBeh(DS, nLW); nM = 0; aM2 = NaN; aM1 = NaN;
		if numel(bLW) == numel(pLW2)
			nM = sum(bLW == 0);
			if nM >= 3
				aM2 = iAUC(pAW2, pLW2(bLW == 0));
				aM1 = iAUC(pAW1, pLW1(bLW == 0));
			end
		end

		fprintf('%-9s %6d | %8.2f %8.2f | %8.2f %8.2f | %8.2f %8.2f | %8.2f %8.2f | %6d\n', string(m), numel(cells), ...
			mean(a2tr, 'omitnan'), mean(a2cv, 'omitnan'), mean(a1cv, 'omitnan'), mean(a2act, 'omitnan'), ...
			aAWLW2, aAWLW1, aM2, aM1, nM);
		Rows(end+1, :) = {string(cfg(ic).Name), string(m), numel(cells), nF, ...
			mean(a2tr, 'omitnan'), mean(a2cv, 'omitnan'), mean(a1cv, 'omitnan'), mean(a2act, 'omitnan'), ...
			aAWLW2, aAWLW1, aM2, aM1, nM}; %#ok<SAGROW>
	end
end

T = cell2table(Rows, 'VariableNames', ["Cohort", "Mouse", "NCells", "NFrames", ...
	"AUC2D_train", "AUC2D_cv", "AUC1D_cv", "AUC2D_actionctl", ...
	"AUC2D_AW_LW", "AUC1D_AW_LW", "AUC2D_AW_LWmiss", "AUC1D_AW_LWmiss", "nLWmiss"]);
csvPath = fullfile(thisDir, 'RepresentationReuse_2DTrajectoryDecode.csv');
writetable(T, csvPath);
fprintf('\nWrote: %s\n', csvPath);

fprintf('\n=============== 组水平（逐鼠均值 ± SEM）===============\n');
for ic = 1:2
	sel = strcmp(T.Cohort, cfg(ic).Name);
	if sum(sel) < 3, continue; end
	n = sum(sel);
	f = @(x) sprintf('%.2f±%.2f', mean(x, 'omitnan'), std(x, 'omitnan')/sqrt(sum(isfinite(x))));
	fprintf('%-16s n=%2d | 2D训练=%s  2D留出=%s (p=%.3g)  1D留出=%s (p=%.3g)\n', cfg(ic).Name, n, ...
		f(T.AUC2D_train(sel)), f(T.AUC2D_cv(sel)), iSafeP(T.AUC2D_cv(sel)-0.5), ...
		f(T.AUC1D_cv(sel)), iSafeP(T.AUC1D_cv(sel)-0.5));
	fprintf('%-16s      | 动作对照=%s (p=%.3g) | 2D AW/LW=%s (p=%.3g) | 1D AW/LW=%s | **2D AW/LWmiss=%s (p=%.3g)** | 1D AW/LWmiss=%s\n', ...
		'', f(T.AUC2D_actionctl(sel)), iSafeP(T.AUC2D_actionctl(sel)-0.5), ...
		f(T.AUC2D_AW_LW(sel)), iSafeP(T.AUC2D_AW_LW(sel)-0.5), f(T.AUC1D_AW_LW(sel)), ...
		f(T.AUC2D_AW_LWmiss(sel)), iSafeP(T.AUC2D_AW_LWmiss(sel)-0.5), f(T.AUC1D_AW_LWmiss(sel)));
end

%% ========== local ==========
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

function b = iBeh(DS, nts)
b = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
Tr = DS.TableQuery(["TrialUID", "Behavior"]);
[ok, idx] = ismember(Tu, uint64(Tr.TrialUID));
b = nan(numel(Tu), 1);
b(ok) = double(Tr.Behavior(idx(ok)));
end

function X = iCell3(DS, nts, cells, frames)
% 细胞 × 试次 × 帧
X = [];
if isempty(nts), return; end
Tu = unique(nts.TrialUID, 'stable');
[~, jTu] = ismember(nts.TrialUID, Tu);
nT = numel(Tu); nF = numel(frames);
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal(:, frames));
X = nan(numel(cells), nT, nF);
for i = 1:numel(cells)
	rows = find(cu == cells(i));
	if isempty(rows), continue; end
	X(i, jTu(rows), :) = reshape(sig(rows, :), 1, numel(rows), nF);
end
end

function p = iProj2(X, w)
% X: 细胞×试次×帧，w: 细胞×1×帧 → 试次×1
% 展平顺序必须一致：(细胞最快，其次帧)。w 是 细胞×1×帧，其线性序即"细胞最快"。
if isempty(X) || isempty(w), p = []; return; end
s = size(X);
ww = w(:);
M = reshape(permute(X, [1 3 2]), s(1) * s(3), s(2));   % (细胞×帧) × 试次
p = (ww.' * M).';
end

function p = iProj1(M, w)
if isempty(M) || isempty(w), p = []; return; end
p = (w(:).' * M).';
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
