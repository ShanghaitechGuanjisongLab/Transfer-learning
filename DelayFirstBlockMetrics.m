% 首个光水 block 的神经指标对比：AW->LW 迁移鼠 vs 延迟范式下的 naive 光水鼠
%
% 目的：若光水"复用"了声水建立的群体编码，迁移鼠在第一次见到光水时，
%       其群体活动应比 naive 鼠第一次见到光水时更有结构。
%
% 指标（均只用该 block 内部数据，与行为标签无关）：
%   1) trial 间轨迹可靠性：5 主成分空间中，两两 trial 轨迹的平均相关
%   2) PC1 方差占比
%   3) 前 3 个主成分累计方差占比
% 另附该 block 的命中率，便于判断行为与神经指标的关系。
%
% 时间窗：cue -1.0 -> +1.5 s（覆盖线索与延迟段；延迟范式的反应在 1.5 s 之后）

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nPC = 5;
DSlist = {TransferLearning.ALDelayed(), TransferLearning.LADelayed()};
cohName = ["AW->LW", "naive LW"];

Rows = table();
for c = 1:numel(DSlist)
	DS = DSlist{c};
	Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
	C = DS.Cells; C.Mouse = string(C.Mouse);
	mice = unique(C.Mouse);
	fprintf('\n===== %s =====\n', cohName(c));
	fprintf('%-9s %-6s %-6s %-6s %-8s %-8s %-8s\n', 'mouse', 'nTr', 'nCell', 'hit', 'reliab', 'PC1%', 'PC1-3%');
	for i = 1:numel(mice)
		m = char(mice(i));
		T = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
		if isempty(T), continue; end
		blks = unique(T.BlockUID);
		tm = arrayfun(@(b) DS.Blocks.DateTime(find(DS.Blocks.BlockUID == b, 1)), blks);
		[~, ord] = sort(tm);
		blk = blks(ord(1));                       % 第一个光水 block

		X = TransferLearning.BuildTrialMatrix(T(T.BlockUID == blk, :), unique(T.CellUID));
		if isempty(X), continue; end
		xs = linspace(-3, 3, size(X, 3))';
		sel = xs >= -1.0 & xs <= 1.5;
		X = X(:, :, sel);
		[nTr, nC, nT] = size(X);
		if nTr < 20 || nC < 30, continue; end

		% 命中率
		tu = unique(T.TrialUID(T.BlockUID == blk));
		st = ismember(Tr.TrialUID, tu) & Tr.BlockUID == blk;
		tags = Tr.ResampledTags(st); tuSel = Tr.TrialUID(st);
		okTag = cellfun(@(x) isa(x, 'table'), tags);
		tags = tags(okTag); tuSel = tuSel(okTag);
		[~, o2] = sort(tuSel); tags = tags(o2);
		[Lick, ~, tt] = TransferLearning.LickTrace(tags, Window=[-3 3]);
		hit = mean(any(Lick & tt >= 1.4, 2));

		% 主成分与可靠性
		R = reshape(permute(X, [1 3 2]), nTr * nT, nC);
		Rc = R - mean(R, 1);
		[~, S, V] = svd(Rc, 'econ');
		e = diag(S).^2; e = e / sum(e);
		k = min(nPC, size(V, 2));
		P = reshape(Rc * V(:, 1:k), nTr, nT * k);
		Cm = corr(P.');
		Cm(logical(eye(nTr))) = NaN;
		rel = mean(Cm(:), 'omitnan');

		fprintf('%-9s %-6d %-6d %-6.2f %-8.3f %-8.1f %-8.1f\n', m, nTr, nC, hit, rel, ...
			100 * e(1), 100 * sum(e(1:min(3, numel(e)))));
		Rows = [Rows; table(string(cohName(c)), string(m), nTr, nC, hit, rel, 100*e(1), ...
			100*sum(e(1:min(3,numel(e)))), 'VariableNames', ...
			{'Cohort','Mouse','NTrial','NCell','Hit','Reliability','PC1pct','PC13pct'})]; %#ok<AGROW>
	end
end

fprintf('\n--- 汇总（个体值 + 中位数）---\n');
for c = 1:numel(cohName)
	sel = Rows.Cohort == cohName(c);
	if ~any(sel), continue; end
	fprintf('%-9s n=%d | rel %s (median %.3f) | PC1%% %s (median %.1f) | hit %s\n', cohName(c), nnz(sel), ...
		mat2str(round(Rows.Reliability(sel)', 3)), median(Rows.Reliability(sel)), ...
		mat2str(round(Rows.PC1pct(sel)', 1)), median(Rows.PC1pct(sel)), ...
		mat2str(round(Rows.Hit(sel)', 2)));
end
disp(Rows);
assignin('base', 'DelayFirstBlock', Rows);

% 组间检验（样本极小，仅作参考）
a = Rows.Reliability(Rows.Cohort == cohName(1));
b = Rows.Reliability(Rows.Cohort == cohName(2));
if ~isempty(a) && ~isempty(b)
	fprintf('可靠性 ranksum p = %.3f（%d vs %d，最小可达 p = %.3f）\n', ...
		ranksum(a, b), numel(a), numel(b), 2 / (nchoosek(numel(a)+numel(b), numel(a))));
end
