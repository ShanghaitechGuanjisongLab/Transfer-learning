% RSA 对照：只保留"安静 trial"（cue 后 0.6 s 内没有任何舔水），
% 以排除"两种线索都只是诱发同一个运动/舔水准备状态"这一解释。
%
% 其余计算与 DelayCrossModalRSA.m 完全一致：
%   r_cross = AW 平均响应模式 与 LW 平均响应模式 的逐细胞相关（窗口 0.1-0.6 s）
%   null    = 打乱细胞标签

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nShuffle = 1000;
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
mice = unique(C.Mouse);

fprintf('%-9s %-7s %-8s %-7s %-8s %-7s %-8s %-6s\n', ...
	'mouse', 'nCell', 'nA_q', 'nL_q', 'r_cross_q', 'r_all', 'nullMean', 'p');
Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	[QA, onA] = iQuietPattern(DS, Tr, TA, cells);
	[QL, onL] = iQuietPattern(DS, Tr, TL, cells);
	if isempty(QA) || isempty(QL), continue; end
	pA = mean(QA, 1)'; pL = mean(QL, 1)';
	nC = numel(pA);

	% 全部 trial 的对照（与主脚本一致）
	[FA, ~] = iQuietPattern(DS, Tr, TA, cells, true);
	[FL, ~] = iQuietPattern(DS, Tr, TL, cells, true);
	rAll = corr(mean(FA, 1)', mean(FL, 1)');

	rCross = corr(pA, pL);
	rng(1);
	nul = nan(nShuffle, 1);
	for t = 1:nShuffle
		nul(t) = corr(pA, pL(randperm(nC)));
	end
	nm = mean(nul, 'omitnan');
	p = mean(nul >= rCross);

	fprintf('%-9s %-7d %-8d %-7d %-8.3f %-7.3f %-8.3f %-6.3f\n', m, nC, size(QA,1), size(QL,1), rCross, rAll, nm, p);
	Rows = [Rows; table(string(m), nC, size(QA,1), size(QL,1), rCross, rAll, nm, p, ...
		'VariableNames', {'Mouse','NCells','NA_quiet','NL_quiet','R_cross_quiet','R_all','NullMean','P'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 ---\n');
fprintf('安静 trial 的 r_cross = %.2f +- %.2f（显著 %d/%d）；全部 trial 的 r_cross = %.2f\n', ...
	mean(Rows.R_cross_quiet), std(Rows.R_cross_quiet)/sqrt(height(Rows)), ...
	nnz(Rows.P < 0.05), height(Rows), mean(Rows.R_all));
assignin('base', 'DelayRSAquiet', Rows);

%% ------------------------------------------------------------------
function [P, onset] = iQuietPattern(DS, Tr, T, cells, useAll)
if nargin < 5, useAll = false; end
P = []; onset = [];
blks = unique(T.BlockUID);
for bi = 1:numel(blks)
	X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blks(bi), :), cells);
	if isempty(X), continue; end
	xs = linspace(-3, 3, size(X, 3))';
	iBase = xs >= -1.0 & xs < -0.3;
	iResp = xs >= 0.1 & xs <= 0.6;
	R = mean(X(:, :, iResp), 3) - mean(X(:, :, iBase), 3);   % trials x cells

	tu = unique(T.TrialUID(T.BlockUID == blks(bi)));
	sel = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blks(bi);
	tags = Tr.ResampledTags(sel);
	tuSel = Tr.TrialUID(sel);
	okTag = cellfun(@(x) isa(x, 'table'), tags);
	tags = tags(okTag); tuSel = tuSel(okTag);
	if numel(tags) < 10, continue; end
	[~, ord] = sort(tuSel);
	tags = tags(ord);
	[~, on, ~] = TransferLearning.LickTrace(tags, Window=[-3 3]);
	n = min(size(R, 1), numel(on));
	R = R(1:n, :); on = on(1:n);
	if ~useAll
		q = isnan(on) | on > 0.6;      % 安静 trial
		R = R(q, :);
	end
	if isempty(R), continue; end
	P = [P; R]; %#ok<AGROW>
	onset = [onset; on]; %#ok<AGROW>
end
end
