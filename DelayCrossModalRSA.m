% 跨模态表征相似性（RSA）：光水是否复用了声水的群体响应模式？
%
% 指标（都在同一批细胞、同一时间窗上计算）：
%   r_cross  AW 平均响应模式 与 LW 平均响应模式 的逐细胞相关
%   r_AW     AW 组内分半信度（两半 trial 的响应模式相关）—— 噪声上限
%   r_LW     LW 组内分半信度
%   null     打乱细胞标签 1000 次得到的 r_cross 零分布
%   reuse    归一化复用指数 = (r_cross - null均值) / (min(r_AW,r_LW) - null均值)
%            >0 表示跨模态相似性超出随机，1 表示达到组内信度水平
%
% 时间窗：cue 后 0.1 ~ 0.6 s（延迟范式 cue 持续 1 s，取更早的一段以避开舔水）

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

nShuffle = 1000;
nSplit = 100;
DS = TransferLearning.ALDelayed();
Tr = DS.Trials; Tr.TrialUID = uint64(Tr.TrialUID);
C = DS.Cells; C.CellUID = uint64(C.CellUID); C.Mouse = string(C.Mouse);
mice = unique(C.Mouse);

fprintf('%-9s %-6s %-8s %-8s %-8s %-8s %-6s %-8s\n', ...
	'mouse', 'nCell', 'r_cross', 'r_AW', 'r_LW', 'nullMean', 'p', 'reuse');
Rows = table();
for i = 1:numel(mice)
	m = char(mice(i));
	TA = TransferLearning.QueryZScoreNts(DS, m, 'AudioLearnWater');
	TL = TransferLearning.QueryZScoreNts(DS, m, 'LightLearnWater');
	if isempty(TA) || isempty(TL), continue; end
	cells = intersect(unique(TA.CellUID), unique(TL.CellUID));
	if numel(cells) < 30, continue; end

	XA = TransferLearning.BuildTrialMatrix(TA, cells);
	XL = TransferLearning.BuildTrialMatrix(TL, cells);
	if isempty(XA) || isempty(XL), continue; end
	xs = linspace(-3, 3, size(XA, 3))';
	iBase = xs >= -1.0 & xs < -0.3;
	iResp = xs >= 0.1 & xs <= 0.6;

	pA = mean(mean(XA(:, :, iResp), 3) - mean(XA(:, :, iBase), 3), 1)';   % 细胞 x 1
	pL = mean(mean(XL(:, :, iResp), 3) - mean(XL(:, :, iBase), 3), 1)';
	nC = numel(pA);

	rCross = corr(pA, pL);

	% 组内分半信度（噪声上限）
rng(0);
	spA = nan(nSplit, 1); spL = nan(nSplit, 1);
	for t = 1:nSplit
		spA(t) = iSplitCorr(XA, iResp, iBase);
		spL(t) = iSplitCorr(XL, iResp, iBase);
	end
	rAW = mean(spA, 'omitnan');
	rLW = mean(spL, 'omitnan');

	% 细胞标签打乱零分布
	rng(1);
	nul = nan(nShuffle, 1);
	for t = 1:nShuffle
		nul(t) = corr(pA, pL(randperm(nC)));
	end
	nm = mean(nul, 'omitnan');
	p = mean(nul >= rCross);
	ceiling = min([rAW, rLW]);
	if isfinite(ceiling) && (ceiling - nm) > 0
		reuse = (rCross - nm) / (ceiling - nm);
	else
		reuse = NaN;
	end

	fprintf('%-9s %-6d %-8.2f %-8.2f %-8.2f %-8.2f %-6.3f %-8.2f\n', m, nC, rCross, rAW, rLW, nm, p, reuse);
	Rows = [Rows; table(string(m), nC, rCross, rAW, rLW, nm, p, reuse, ...
		'VariableNames', {'Mouse','NCells','R_cross','R_AW','R_LW','NullMean','P','Reuse'})]; %#ok<AGROW>
end

fprintf('\n--- 汇总 (n = %d mice) ---\n', height(Rows));
fprintf('r_cross = %.2f +- %.2f；零分布均值 %.2f；显著鼠数 %d/%d\n', ...
	mean(Rows.R_cross), std(Rows.R_cross)/sqrt(height(Rows)), mean(Rows.NullMean), ...
	nnz(Rows.P < 0.05), height(Rows));
fprintf('组内信度：AW %.2f / LW %.2f（若接近 0，则跨模态比较无意义）\n', mean(Rows.R_AW), mean(Rows.R_LW));
fprintf('归一化复用指数 = %.2f +- %.2f\n', mean(Rows.Reuse, 'omitnan'), std(Rows.Reuse, 'omitnan')/sqrt(nnz(isfinite(Rows.Reuse))));
assignin('base', 'DelayRSA', Rows);

%% ------------------------------------------------------------------
function r = iSplitCorr(X, iResp, iBase)
n = size(X, 1);
idx = randperm(n);
h1 = idx(1:floor(n/2)); h2 = idx(floor(n/2)+1:end);
p1 = mean(mean(X(h1, :, iResp), 3) - mean(X(h1, :, iBase), 3), 1)';
p2 = mean(mean(X(h2, :, iResp), 3) - mean(X(h2, :, iBase), 3), 1)';
r = corr(p1, p2);
end
