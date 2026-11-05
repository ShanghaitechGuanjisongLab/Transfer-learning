% 延迟范式的时间结构对解码结果的影响
%
% 已知任务结构：cue 持续 1 s，随后 0.5 s 延迟，水在 1.5 s 起可得。
% 本脚本检查：
%   1) 每个 trial 的首次舔水时间分布（确认动物在 cue 期间就开始舔）
%   2) 三种特征窗口下的 AW->LW 迁移解码 AUC：
%        P  cue 前基线（-1.0 ~ -0.05 s）—— 纯刺激前状态
%        E  cue 早期（0 ~ 0.3 s）—— 正文所用
%        L  cue 中后段（0.3 ~ 1.0 s）—— 与舔水重叠
%   3) 只保留"首次舔水 > 0.5 s"的 trial 时，E 窗口的 AUC 如何变化

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPC = 8;
tWater = 1.4;
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID);
xs = linspace(-3, 3, 48)';

wins = struct( ...
	'P', xs >= -1.0 & xs <= -0.05, ...
	'E', xs >= 0.0 & xs <= 0.30, ...
	'L', xs >= 0.30 & xs <= 1.00);
wAll = xs >= -1.0 & xs <= 1.0;

mice = unique(string(C.Mouse));
fprintf('%-9s %-9s %-9s %-9s %-9s\n', 'mouse', 'AUC_P', 'AUC_E', 'AUC_L', 'AUC_E_quiet');
Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	% 用长的公共窗口堆叠，之后按需要切片
	[XA, yA, gA, onA] = iStack(DS, Tr, TA, cells, wAll, tWater);
	[XL, yL, gL, onL] = iStack(DS, Tr, TL, cells, wAll, tWater);
	if numel(yA) < 100 || numel(yL) < 100, continue; end
	xsW = xs(wAll);
	fn = fieldnames(wins);
	aucs = nan(1, numel(fn));
	for f = 1:numel(fn)
		sel = wins.(fn{f})(wAll);
		FA = iFlatten(XA(:, :, sel), gA); FA = iCenterBlock(FA, gA);
		FL = iFlatten(XL(:, :, sel), gL); FL = iCenterBlock(FL, gL);
		aucs(f) = iTransferAUC(FA, yA, FL, yL, nPC);
	end
	% 只保留"首次舔水 > 0.5 s"的 trial（安静 trial）
	sel = wins.E(wAll);
	FA = iFlatten(XA(:, :, sel), gA); FA = iCenterBlock(FA, gA);
	FL = iFlatten(XL(:, :, sel), gL); FL = iCenterBlock(FL, gL);
	qA = onA > 0.5 | isnan(onA);
	qL = onL > 0.5 | isnan(onL);
	aucQuiet = iTransferAUC(FA(qA, :), yA(qA), FL(qL, :), yL(qL), nPC);

	fprintf('%-9s %-9.3f %-9.3f %-9.3f %-9.3f\n', m, aucs(1), aucs(2), aucs(3), aucQuiet);
	Rows = [Rows; table(string(m), aucs(1), aucs(2), aucs(3), aucQuiet, ...
		nnz(qA), nnz(qL), mean(onA < 0.3, 'omitnan'), ...
		'VariableNames', {'Mouse','AUC_P','AUC_E','AUC_L','AUC_E_quiet','NAquiet','NLquiet','FracEarlyLick'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('cue 前基线窗口 AUC = %.3f\n', mean(Rows.AUC_P));
fprintf('cue 早期 0-0.3 s  AUC = %.3f\n', mean(Rows.AUC_E));
fprintf('cue 中后段 0.3-1 s AUC = %.3f\n', mean(Rows.AUC_L));
fprintf('只取安静 trial（首次舔水>0.5 s）的 AUC = %.3f\n', mean(Rows.AUC_E_quiet));
fprintf('首次舔水 < 0.3 s 的 trial 比例 = %.2f\n', mean(Rows.FracEarlyLick));
assignin('base', 'DelayWindowControl', Rows);

%% ------------------------------------------------------------------
function [X, y, g, onset] = iStack(DS, Tr, T, cells, wAll, tWater)
X = []; y = []; g = []; onset = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	Xi = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(Xi), continue; end
	Xi = Xi(:, :, wAll);
	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel);
	tuSel = Tr.TrialUID(sel);
	okTag = cellfun(@(x) isa(x, 'table'), tags);
	tags = tags(okTag); tuSel = tuSel(okTag);
	if numel(tags) < 10, continue; end
	[~, ord] = sort(tuSel);
	tags = tags(ord);
	[Lick, on, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	resp = false(size(Lick, 1), 1);
	for k = 1:size(Lick, 1)
		if any(Lick(k, :) & tt >= tWater)
			resp(k) = true;
		end
	end
	n = min(size(Xi, 1), numel(resp));
	if n < 10, continue; end
	X = cat(1, X, Xi(1:n, :, :)); %#ok<AGROW>
	y = [y; double(resp(1:n))]; %#ok<AGROW>
	g = [g; repmat(bi, n, 1)]; %#ok<AGROW>
	onset = [onset; on(1:n)]; %#ok<AGROW>
end
end

function F = iFlatten(X, g) %#ok<INUSD>
F = reshape(permute(X, [1 3 2]), size(X, 1), []);
end

function F = iCenterBlock(F, g)
for bi = unique(g)'
	r = g == bi;
	F(r, :) = F(r, :) - mean(F(r, :), 1);
end
end

function auc = iTransferAUC(FA, yA, FL, yL, nPC)
if numel(unique(yA)) < 2 || numel(unique(yL)) < 2, auc = NaN; return; end
mu = mean(FA, 1);
[~, ~, V] = svd(FA - mu, 'econ');
k = min(nPC, size(V, 2));
W = V(:, 1:k);
Ztr = [ones(size(FA, 1), 1), (FA - mu) * W];
Zte = [ones(size(FL, 1), 1), (FL - mu) * W];
b = (Ztr' * Ztr + eye(k + 1)) \ (Ztr' * yA);
[~, ~, ~, auc] = perfcurve(yL, Zte * b, 1);
end
