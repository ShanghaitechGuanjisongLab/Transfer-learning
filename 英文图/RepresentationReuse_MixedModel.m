% 表征复用（第十一步）：试次级混合模型（鼠为随机效应）
%
% 目的：前面所有关键检验都是"逐鼠算一个数，再做 signrank"，n=5–10，功效受限
%       （V7 的 p=0.125 就是这个原因）。这里把**试次**当作观测单位，鼠作为随机效应，
%       把全部试次放进同一个模型，直接给出系数、SE 和 p。
%
% 四个模型：
%  M1（论点②，模态判别）     y = 线索类型(声=1/光=0)，AW@Learned vs LW@Transfer
%                            固定效应：投影 p（逐鼠 z 化）、舔(0/1)；随机：(1|鼠)
%                            ⇒ p 的系数显著 = 模态轴能读出身份；控制舔后仍显著 = 不由动作造成
%  M2（论点③，7 天是否改变模态编码）
%                            y 同上，加 cohort(V7=1)、p×cohort 交互；随机：(1|鼠)
%                            ⇒ 交互不显著 = 7 天后模态编码未变
%  M3（论点③，学会表征再激活）
%                            y = 窗口 z（群体均值），AW@Learned vs LW@Transfer-未舔
%                            固定效应：isTransfer；随机：(1|鼠)
%                            ⇒ isTransfer 显著为负 = 迁移期没有唤起学会表征
%  M4（同 M3，但用逐细胞数据 + 细胞嵌套随机效应，仅 ALB/V7 各自内部）
%                            y = 单细胞窗口 z，固定：isTransfer；随机：(1|鼠)+(1|鼠:细胞)
%
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧；投影轴沿用"Naive 的 AO−LO"

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
iT = find(tAll >= 0 & tAll <= 1.5);
haveGLME = exist('fitglme', 'file') > 0;
if ~exist('LayerSel', 'var'), LayerSel = ""; end
fprintf('fitglme 可用: %d\n', haveGLME);

cfg = struct();
cfg(1).Name = "ALB"; cfg(1).DS = TransferLearning.AudioLightBaseline();
cfg(2).Name = "V7";  cfg(2).DS = TransferLearning.Vacation7();

% ---------- 逐鼠抽取：Naive 定轴 + 三条件投影 + 逐试次记录 ----------
R = table();   % 试次级：Mouse, Cohort, Cond, p, lick, act
A = table();   % 细胞×试次级（M4 用）
for ic = 1:2
	DS = cfg(ic).DS;
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
		dtL = iFirst(DS, m, "Learned", "AudioWater");
		dtT = iFirst(DS, m, "Transfer", "LightWater");
		if isnat(dtL) || isnat(dtT), continue; end
		nAW = iQuery(DS, m, dtL, "AudioWater");
		nLW = iQuery(DS, m, dtT, "LightWater");
		if any(cellfun(@isempty, {nLO, nAO, nAW, nLW})), continue; end

		cells = intersect(intersect(nLO.CellUID, nAO.CellUID), intersect(nAW.CellUID, nLW.CellUID));
		if strlength(LayerSel) > 0
			Cx = DS.Cells; Cx.CellUID = uint64(Cx.CellUID); Cx.ZLayer = string(Cx.ZLayer);
			[okm, idxm] = ismember(cells, Cx.CellUID);
			keepm = false(size(cells)); keepm(okm) = Cx.ZLayer(idxm(okm)) == LayerSel;
			cells = cells(keepm);
		end
		if numel(cells) < 50, continue; end

		XLO = iCell3(nLO, cells, iT); XAO = iCell3(nAO, cells, iT);
		XAW = iCell3(nAW, cells, iT); XLW = iCell3(nLW, cells, iT);
		w   = mean(XAO, 2, 'omitnan') - mean(XLO, 2, 'omitnan');   % 细胞×1×帧
		if all(w(:) == 0), continue; end

		% 逐试次：投影 + 群体均值 + 舔
		rec = {{"AW_Lrn", XAW, nAW}, {"LW_Trn", XLW, nLW}};
		for q = 1:2
			nm = rec{q}{1}; X = rec{q}{2}; nts = rec{q}{3};
			p = iProj2(X, w);
			act = reshape(mean(X, 1, 'omitnan'), [], 1);
			b = iBeh(DS, nts);
			for t = 1:numel(p)
				lk = NaN; if numel(b) == numel(p), lk = b(t); end
				R(end+1, :) = {string(m), string(cfg(ic).Name), string(nm), p(t), lk, act(t)}; %#ok<SAGROW>
			end
			for t = 1:size(X, 2)
				lk = NaN; if numel(b) == size(X, 2), lk = b(t); end
				for ci = 1:size(X, 1)
					v = X(ci, t, :);
					A(end+1, :) = {string(cfg(ic).Name), string(m), string(nm), string(cells(ci)), ...
						squeeze(v(1)), lk}; %#ok<SAGROW>
				end
			end
		end
	end
end
R.Properties.VariableNames = ["Mouse", "Cohort", "Cond", "p", "lick", "act"];
A.Properties.VariableNames = ["Cohort", "Mouse", "Cond", "Cell", "act", "lick"];
writetable(R, fullfile(thisDir, 'MixedModel_TrialLevel.csv'));

fprintf('\n数据：试次级 %d 行（鼠 %d 只），细胞×试次 %d 行\n', ...
	height(R), numel(unique(R.Mouse)), height(A));

% 逐鼠 z 化投影，使不同鼠的系数可比
R.p = iZbyGroup(R.p, R.Mouse);
R.isAW = double(R.Cond == "AW_Lrn");
R.isV7 = double(R.Cohort == "V7");

%% ---------- M1：模态判别（AW vs LW），控制舔 ----------
fprintf('\n=============== M1  y = 声(1)/光(0)，p + 舔 ===============\n');
D1 = R(isfinite(R.p) & isfinite(R.lick), :);
fprintf('n=%d 行，鼠 %d 只，AW=%d / LW=%d\n', height(D1), numel(unique(D1.Mouse)), sum(D1.isAW), sum(~D1.isAW));
iFit(D1, 'isAW ~ p + lick + (1|Mouse)', haveGLME, 'binomial');
fprintf('--- 仅未舔试次（动作完全排除）---\n');
D1m = D1(D1.lick == 0, :);
fprintf('n=%d 行\n', height(D1m));
iFit(D1m, 'isAW ~ p + (1|Mouse)', haveGLME, 'binomial');

%% ---------- M2：7 天是否改变模态编码 ----------
fprintf('\n=============== M2  y = 声/光，p × cohort(7天) ===============\n');
D2 = R(isfinite(R.p) & isfinite(R.lick), :);
iFit(D2, 'isAW ~ p * isV7 + lick + (1|Mouse)', haveGLME, 'binomial');

%% ---------- M3：学会表征再激活（群体均值，试次级） ----------
fprintf('\n=============== M3  y = 群体窗口 z，Learned vs Transfer-未舔 ===============\n');
D3 = R(isfinite(R.act), :);
D3 = D3(D3.Cond == "AW_Lrn" | (D3.Cond == "LW_Trn" & D3.lick == 0), :);
D3.isTransfer = double(D3.Cond == "LW_Trn");
for c = ["ALB", "V7"]
	Dc = D3(D3.Cohort == c, :);
	fprintf('--- %s：n=%d 行，鼠 %d 只（Learned %d / Transfer-未舔 %d）---\n', c, height(Dc), ...
		numel(unique(Dc.Mouse)), sum(Dc.isTransfer == 0), sum(Dc.isTransfer == 1));
	if height(Dc) < 20, continue; end
	iFit(Dc, 'act ~ isTransfer + (1|Mouse)', haveGLME, 'normal');
end

%% ---------- M4：逐细胞版（细胞嵌套于鼠） ----------
fprintf('\n=============== M4  y = 单细胞窗口 z（细胞嵌套于鼠）===============\n');
D4 = A(isfinite(A.act), :);
D4 = D4(D4.Cond == "AW_Lrn" | (D4.Cond == "LW_Trn" & D4.lick == 0), :);
D4.isTransfer = double(D4.Cond == "LW_Trn");
D4.MouseCell = string(D4.Mouse) + "_" + string(D4.Cell);
for c = ["ALB", "V7"]
	Dc = D4(D4.Cohort == c, :);
	fprintf('--- %s：n=%d 行，鼠 %d 只，细胞 %d 个 ---\n', c, height(Dc), ...
		numel(unique(Dc.Mouse)), numel(unique(Dc.MouseCell)));
	if height(Dc) < 200, continue; end
	iFit(Dc, 'act ~ isTransfer + (1|Mouse) + (1|MouseCell)', haveGLME, 'normal');
end

%% ========== 拟合封装 ==========
function iFit(D, formula, haveGLME, dist)
if height(D) < 20
	fprintf('    （数据太少，跳过）\n'); return;
end
if haveGLME
	try
		if dist == "binomial"
			mdl = fitglme(D, formula, 'Distribution', 'binomial');
		else
			mdl = fitglme(D, formula);
		end
		disp(mdl.Coefficients(:, {'Name', 'Estimate', 'SE', 'pValue'}));
		return;
	catch ME
		fprintf('    fitglme 失败（%s），改用固定效应 Mouse\n', ME.identifier);
	end
end
% 退路：Mouse 作为固定效应
f2 = replace(formula, "(1|Mouse)", "Mouse");
try
	if dist == "binomial"
		mdl = fitglm(D, f2, 'Distribution', 'binomial');
	else
		mdl = fitglm(D, f2);
	end
	T = mdl.Coefficients(:, {'Name', 'Estimate', 'SE', 'pValue'});
	keep = ~startsWith(string(T.Name), "Mouse_");
	disp(T(keep, :));
catch ME2
	fprintf('    fitglm 也失败：%s\n', ME2.message);
end
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

function X = iCell3(nts, cells, frames)
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
if isempty(X) || isempty(w), p = []; return; end
s = size(X);
M = reshape(permute(X, [1 3 2]), s(1)*s(3), s(2));
p = (w(:).' * M).';
end

function v = iZbyGroup(x, g)
v = nan(size(x));
u = unique(g);
for i = 1:numel(u)
	sel = g == u(i);
	s = std(x(sel));
	if s > 0, v(sel) = (x(sel) - mean(x(sel))) / s; end
end
end
