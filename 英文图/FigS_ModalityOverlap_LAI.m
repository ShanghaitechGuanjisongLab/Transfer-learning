% FigS_ModalityOverlap_LAI.m —— 超模态（supramodal）响应细胞比例
%
% 目的（"不是单纯的感觉信号"这一质疑的核心证据之一）：
%   如果 MOp 只是把光/声的低级感觉特征分别编码，那么"线索响应细胞"应当是**模态特异**的，
%   即几乎不重叠；若相当一部分细胞对两种模态都响应，说明这里表征的是线索的身份/意义，
%   而不是某一模态的物理特征。
%
% 设计（用 LAI 穿插队列，同一 session 内同时有 AudioOnly 与 LightOnly）：
%   · 两种条件都是**无线索强化、基本不舔**（纯线索），因此不受动作/结局污染；
%   · 同一批细胞（取 AO 与 LO 共有 CellUID）；
%   · 窗口 0–1.5 s（与全项目一致，cue 只有 0.2 s，已过感觉诱发期）。
%
% 响应判定（试次感知，不用单一 z 阈值）：
%   对每个细胞，取 0–1.5 s 窗口的**逐试次**均值，做单样本 t 检验（H0: 均值 = 0），
%   再对 session 内所有细胞做 BH-FDR（q = 0.05）控制多重比较。
%   某条件下 p_BH < 0.05 ⇒ 该细胞在该条件下"响应"。
%
% 输出指标：
%   nRespAO / nRespLO      各条件下响应细胞数
%   nBoth                  两者都响应（超模态）
%   FracBoth = nBoth / nUnion                  观察到的重叠比例
%   ExpFracBoth = (nAO/N)*(nLO/N) * N / nUnion 独立假设下的期望重叠比例
%   OR, pFisher            2×2 独立性检验（Fisher 精确检验）
%
% 输出：英文图/FigS_ModalityOverlap_LAI.csv
% 数据：QueryNTS（ZScore，F0 = 1:24），±3 s / 48 帧

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));
warning('off', 'UniExp:Exception:Block_must_warn');

tAll = linspace(-3, 3, 48)';
mask = tAll >= 0 & tAll <= 1.5;
qFDR = 0.05;
phases = ["Naive", "Recall", "Transfer", "Final"];

DS = TransferLearning.LAInterspersed();
CellTbl = DS.Cells;
CellTbl.CellUID = uint64(CellTbl.CellUID);
CellTbl.Mouse = string(CellTbl.Mouse);
CellTbl.ZLayer = string(CellTbl.ZLayer);

TT = DS.TableQuery(["Mouse", "DateTime", "Phase", "Stimulus"]);
TT.Mouse = string(TT.Mouse);
TT.Phase = string(TT.Phase);
TT.Stimulus = string(TT.Stimulus);

R = table(strings(0,1), strings(0,1), strings(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), false(0,1), ...
	'VariableNames', {'Mouse','Phase','Layer','NCells','nRespAO','nRespLO', ...
	'nBoth','nUnion','FracBoth','ExpFracBoth','OR','pFisher','Valid'});

minUnion = 10;   % 可评估门槛：响应细胞并集至少 10 个
minEach  = 5;    % 且每个条件至少 5 个响应细胞，否则比例不稳定

mice = unique(TT.Mouse);
for im = 1:numel(mice)
	m = mice(im);
	for ip = 1:numel(phases)
		ph = phases(ip);
		sel = TT.Mouse == m & TT.Phase == ph;
		if ~any(sel), continue; end
		dts = unique(TT.DateTime(sel));
		for idt = 1:numel(dts)
			dt = dts(idt);
			[BAO, cellsAO] = iTrialMatrix(DS, m, dt, "AudioOnly", mask);
			[BLO, cellsLO] = iTrialMatrix(DS, m, dt, "LightOnly", mask);
			if isempty(BAO) || isempty(BLO), continue; end
			[cells, iA, iL] = intersect(cellsAO, cellsLO);
			if numel(cells) < 50, continue; end
			BAO = BAO(iA, :); BLO = BLO(iL, :);

			respAO = iRespFDR(BAO, qFDR);
			respLO = iRespFDR(BLO, qFDR);

			meta = CellTbl(CellTbl.Mouse == m, {'CellUID','ZLayer'});
			[tf, loc] = ismember(cells, meta.CellUID);
			layers = strings(numel(cells), 1);
			layers(tf) = meta.ZLayer(loc(tf));

			layerSets = {"ALL", "MOp2/3", "MOp5"};
			for iLay = 1:numel(layerSets)
				if layerSets{iLay} == "ALL"
					mk = true(numel(cells), 1);
				else
					mk = layers == layerSets{iLay};
				end
				n = nnz(mk);
				if n < 20, continue; end
				a = respAO(mk); l = respLO(mk);
				nAO = nnz(a); nLO = nnz(l); nBoth = nnz(a & l);
				nUn = nnz(a | l);
				if nUn == 0, continue; end
				fracBoth = nBoth / nUn;
				expBothCount = n * (nAO/n) * (nLO/n);
				expFrac = expBothCount / nUn;
				valid = (nUn >= minUnion) && (nAO >= minEach) && (nLO >= minEach);
				ORv = NaN; pF = NaN;
				if valid
					% 2×2：[both, LO-only; AO-only, neither]，OR 用 +0.5 连续性校正，避免 Inf
					a = nBoth; b = nLO - nBoth; cc = nAO - nBoth;
					d = n - nBoth - b - cc;
					ORv = ((a + 0.5) * (d + 0.5)) / ((b + 0.5) * (cc + 0.5));
					T2 = [a, b; cc, d];
					try
						[~, pF, ~] = fishertest(T2);
					catch
						pF = NaN;
					end
				end
				R(end+1, :) = {m, string(ph), string(layerSets{iLay}), n, nAO, nLO, ...
					nBoth, nUn, fracBoth, expFrac, ORv, pF, valid}; %#ok<SAGROW>
			end
		end
	end
end

writetable(R, fullfile(thisDir, 'FigS_ModalityOverlap_LAI.csv'));

%% ---------------- 报告 ----------------
fprintf('\n=========== 超模态响应比例（AudioOnly vs LightOnly，同一批细胞，0–1.5 s）===========\n');
fprintf('%-9s %-9s %-7s %6s %7s %7s %6s %6s %9s %9s %7s %8s\n', ...
	'鼠','Phase','Layer','nCell','nAO','nLO','nBoth','nUnion','f_Both','f_Both期望','OR','pFisher');
for i = 1:height(R)
	fprintf('%-9s %-9s %-7s %6d %7d %7d %6d %6d %9.3f %9.3f %7.2f %8.3g\n', ...
		R.Mouse(i), R.Phase(i), R.Layer(i), R.NCells(i), R.nRespAO(i), R.nRespLO(i), ...
		R.nBoth(i), R.nUnion(i), R.FracBoth(i), R.ExpFracBoth(i), R.OR(i), R.pFisher(i));
end

fprintf('\n--- 组水平（只统计可评估的 session：nUnion≥%d 且每条件≥%d）---\n', minUnion, minEach);
layersAll = unique(R.Layer);
for iLay = 1:numel(layersAll)
	s = R.Layer == layersAll(iLay) & R.Valid;
	if ~any(s), continue; end
	fb = R.FracBoth(s); ex = R.ExpFracBoth(s);
	fprintf(['%-7s session=%2d | f_Both=%.3f±%.3f | 独立期望=%.3f | ' ...
		'OR>1 的 session: %d/%d | pFisher<0.05: %d/%d | 配对比（f_Both vs 期望）p=%.3g\n'], ...
		layersAll(iLay), nnz(s), mean(fb), std(fb)/sqrt(nnz(s)), mean(ex), ...
		nnz(R.OR(s) > 1), nnz(s), nnz(R.pFisher(s) < 0.05), nnz(s), ...
		iPairedP(fb, ex));
end
fprintf('\n注：f_Both 的分母是「两条件响应细胞的并集」，期望值按两条件独立估计；\n');
fprintf('    Naive 阶段因无强化、响应细胞极少，多数 session 达不到可评估门槛。\n');

%% ========== local ==========
function [B, cells] = iTrialMatrix(DS, mouse, dt, stim, mask)
B = []; cells = uint64.empty(0,1);
nts = DS.QueryNTS(struct('Mouse', mouse, 'DateTime', dt, 'Stimulus', stim), ...
	UniExp.Flags.ZScore, 1:24);
if iscell(nts), nts = nts{1}; end
if isempty(nts), return; end
cu = uint64(nts.CellUID);
sig = double(nts.TrialSignal);
Tu = unique(uint64(nts.TrialUID), 'stable');
[~, jT] = ismember(uint64(nts.TrialUID), Tu);
cells = unique(cu);
B = nan(numel(cells), numel(Tu));
[cLoc, jC] = ismember(cu, cells);
for t = 1:numel(Tu)
	rows = jT == t;
	B(jC(rows), t) = mean(sig(rows, mask), 2);
end
end

function p = iPairedP(x, y)
% 配对 Wilcoxon（观察 f_Both vs 独立期望 f_Both）
v = x(:) - y(:);
v = v(isfinite(v));
if numel(v) < 3 || all(v == 0)
	p = NaN;
else
	p = signrank(v);
end
end

function resp = iRespFDR(B, q)% 每细胞在窗口内的逐试次均值 → 单样本 t 检验 → BH-FDR
nC = size(B, 1);
resp = false(nC, 1);
p = nan(nC, 1);
for i = 1:nC
	v = B(i, :);
	v = v(isfinite(v));
	n = numel(v);
	if n < 3, continue; end
	m = mean(v); sd = std(v);
	if sd == 0, continue; end
	t = m / (sd / sqrt(n));
	p(i) = 2 * tcdf(-abs(t), n - 1);
end
ok = isfinite(p);
pv = p(ok);
[ps, ord] = sort(pv);
mm = numel(ps);
kMax = 0;
for k = 1:mm
	if ps(k) <= k / mm * q, kMax = k; end
end
if kMax > 0
	thr = ps(kMax);
	resp(ok) = pv <= thr;
end
end
