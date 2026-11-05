%% DiscriminantAxisTransfer.m — Leow 2026 式"判别轴迁移"（独立实现，不依赖 DecodeCrossPhase_ALB.m）
%
% 方法骨架（参考 Leow et al. 2026, Neuron 的 Fig 4C–4F 设计）：
%   ① 在"训练阶段"用 LDA 求出显式判别轴 w；
%   ② 固定 w（不重训），把它投影到同一批细胞在各阶段的群体活动上；
%   ③ 在每个阶段算"沿 w 的判别力" d'，试次层面交叉验证；
%   ④ 逐鼠得到"判别力随阶段的变化" → 组水平配对检验。
%
% ⚠ 与原文的差异（详见笔记 D.16d）：原文正文虽然写 "linear discriminant analysis"，
%   但 STAR Methods 的 `Population diet-discrimination analysis` 实际用的是 Mante 2013 式
%   targeted dimensionality reduction —— 判别轴 = 条件均值差向量，再做 QR 正交化，**不含协方差项**。
%   因此本脚本**并排跑两种口径**（axisTypes），全部结果都同时给：
%     - "ShrinkLda"：收缩协方差 LDA，w = S_p^{-1}(mu1-mu0)（主口径；N ≫ 试次数时可逆）
%     - "MeanDiff" ：条件均值差轴，w = mu1-mu0（对齐原文口径）
%   注：本脚本只有单一对比，不需多轴，故原文的 QR 正交化在这里没有作用对象。
%
% 与 DecodeCrossPhase_ALB.m 的关键差别：
%   - 判别器：LDA（显式轴）而非 MCC 模板相关
%   - 读出量：沿固定轴的判别力 d' 而非分类准确率（后者在不平衡测试集上不可用）
%   - LDA 必须正则化：细胞数 N ≫ 试次数，朴素 LDA 必然退化（本脚本用协方差收缩 lambda）
%   - 交叉验证按"试次"分组（同一试次的基线/响应两个样本不得跨折）
%
% 判别目标（样本 = 试次 × 时间窗）：0 = 线索前基线（-3~0 s），1 = 线索后响应（0~1 s），
% 因此轴即"该阶段的响应方向"。
%
% 1) 依赖
%    - MATLAB R2023b，本项目 +TransferLearning 包
%    - Statistics and Machine Learning Toolbox（signrank）
%
% 2) 前置
%    - 可访问 \\Data-Server-2\个人数据\张天夫\202512\声光迁移MOp成像（含学会后三次）.v5.mat
%    - 无需其它前置脚本
%
% 3) 图注
%    判别轴迁移：轴在训练阶段求得、跳阶段固定。
%    列＝轴取自“旧任务学会(声)”/“旧任务初学(声)”；行＝判别轴算法（上：收缩 LDA；下：均值差轴）。
%    柱＝各阶段的迁移保真度（= 迁移 d' / 该阶段自训 d'，均值±SEM，逐鼠先平均；1 = 与自训轴等效）。
%    评估集含同模态的另一声水阶段（Naive↔Learned），用于分离“跳模态”与“跳阶段”两种效应。
%    P 值＝各评估阶段与训练阶段的逐鼠配对 Wilcoxon 符号秩检验（n＝鼠数）；
%    P 值线的位置由 MATLAB.Graphics.PLine 自动布局，文本经 TransferLearning.Style.SetBarPValues 改写。
%    均值差轴与 lambda 无关，故 lambda 敏感性曲线只画收缩 LDA。
%
% 4) 待办
%    - "声 cue vs 光 cue" 需要在同一 session 内含两种线索的穿插组（ALI/LAI）；
%      现用 ALB 每次成像只有单一线索，直接套用会退化成"跨 session 比较"，故暂不实现。
%
% 5) 代码

%% 0. 可调参数
nFold = 5;                       % 试次层交叉验证折数
lambdaList = [0.05 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 0.95];  % LDA 协方差收缩系数扫描
lambdaLda = 0.50;                % 主结果采用的 lambda（须在 lambdaList 中）
minTrainTrials = 12;             % 训练阶段最少试次数
minCells = 10;                   % 参与分析的细胞数下限
rng(0);
iLambdaMain = find(abs(lambdaList - lambdaLda) < 1e-9, 1);

% 判别轴类型（并排对照）：
%   "ShrinkLda" —— 收缩协方差 LDA：w = S_p^{-1}(mu1-mu0)（本脚本主口径，含 lambda 收缩）
%   "MeanDiff"  —— 条件均值差轴：w = mu1-mu0，无协方差项
%                  （Leow 2026 STAR Methods `Population diet-discrimination analysis` 的原文口径，
%                   源自 Mante et al. 2013 的 targeted dimensionality reduction）
axisTypes  = ["ShrinkLda", "MeanDiff"];
axisLabels = ["收缩 LDA", "均值差轴(原文口径)"];
nAxisType  = numel(axisTypes);
iShrink    = find(axisTypes == "ShrinkLda", 1);

% 评估阶段（两条配对共用）：除训练阶段自身外，还含同模态的另一声水阶段（Naive↔Learned），
% 用于把"跨模态"（声→光）与"跨阶段"（声水内部）两种效应分开
evalSpecs = [ ...
	struct('Phase',"Naive",   'Stimulus',"AudioWater"), ...
	struct('Phase',"Learned", 'Stimulus',"AudioWater"), ...
	struct('Phase',"Transfer",'Stimulus',"LightWater"), ...
	struct('Phase',"Final",   'Stimulus',"LightWater")];

% 两条配对（训练阶段 × 评估阶段），并排比
pairings = struct( ...
	'Title', {"轴取自旧任务学会(声)", "轴取自旧任务初学(声)"}, ...
	'Train', {struct('Phase',"Learned",'Stimulus',"AudioWater"), ...
	          struct('Phase',"Naive",  'Stimulus',"AudioWater")}, ...
	'Eval',  {evalSpecs, evalSpecs});

%% 1. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile,'file'); matlab.project.loadProject(prjFile); end
end

DS = TransferLearning.AudioLightBaseline();

% 时间窗（TransferLearning.Xs = linspace(-3,3,48)，步长 0.125 s）
nTime = numel(TransferLearning.Xs);
xsSec = seconds(TransferLearning.Xs); xsSec = xsSec(:)';
idxBaseline = find(xsSec >= -3 & xsSec < 0);     % 线索前基线（-3~0 s）
idxCue      = find(xsSec >=  0 & xsSec <= 1);    % 线索后 1 s 响应窗

TQ = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus","Behavior"]);
TQ.Mouse = string(TQ.Mouse); TQ.Phase = string(TQ.Phase);
mice = unique(TQ.Mouse);
fprintf('=== 判别轴迁移 (Leow 2026 式) ===\n');
fprintf('nFold=%d | lambda=%.2f | mice=%d\n', nFold, lambdaLda, numel(mice));

% 逐鼠逐配对的结果容器
allRes = cell(numel(pairings), numel(mice));

for iP = 1:numel(pairings)
	fprintf('\n########## 配对 %d: %s ##########\n', iP, pairings(iP).Title);
	for iM = 1:numel(mice)
		mouse = mice(iM);
		fprintf('--- %s (%d/%d) ---\n', mouse, iM, numel(mice));

		% 收集"训练阶段 + 各评估阶段"的数据（一次取全，保证 CellUID 一致）
		specs = pairings(iP).Eval;
		trainSpec = pairings(iP).Train;
		if ~any(arrayfun(@(s) s.Phase == trainSpec.Phase && s.Stimulus == trainSpec.Stimulus, specs))
			specs = [trainSpec, specs];
		end

		phaseData = cell(numel(specs), 1);
		cellUIDs = uint64([]);
		for iS = 1:numel(specs)
			tbl = iQueryPhaseTrials(DS, mouse, specs(iS).Phase, specs(iS).Stimulus, nTime);
			phaseData{iS} = tbl;
			if ~isempty(tbl); cellUIDs = union(cellUIDs, uint64(tbl.CellUID)); end
		end
		if numel(cellUIDs) < minCells
			fprintf('  SKIP: 仅 %d 个细胞\n', numel(cellUIDs)); continue;
		end

		% 构造样本
		[S, ok] = iBuildSamples(specs, phaseData, cellUIDs, idxBaseline, idxCue);
		if ~ok; fprintf('  SKIP: 样本不足\n'); continue; end

		iTrain = find(arrayfun(@(s) s.Phase == trainSpec.Phase && s.Stimulus == trainSpec.Stimulus, specs), 1);
		if isempty(iTrain) || sum(S.phaseIdx == iTrain) < minTrainTrials
			fprintf('  SKIP: 训练阶段试次不足\n'); continue;
		end

		% 阶段可用性检查：不可用的阶段不剔除，只提示（其保真度将为 NaN，不参与配对检验）
		for iS = 1:numel(specs)
			mS = S.phaseIdx == iS;
			if ~any(mS)
				fprintf('  WARN: 阶段 %s(%s) 无样本 → 记为 NaN\n', specs(iS).Phase, specs(iS).Stimulus);
			elseif numel(unique(S.y(mS))) < 2
				fprintf('  WARN: 阶段 %s(%s) 只有单一类别 → 记为 NaN\n', specs(iS).Phase, specs(iS).Stimulus);
			end
		end

		% 折固定（跨 lambda 复用），保证不同 lambda 的结果可比
		nPhase = numel(specs);
		foldOfTrial = iKFoldByTrial(S.trialIdx, S.phaseIdx, iTrain, nFold);
		foldsSelf = cell(nPhase, 1);
		for iS = 1:nPhase
			if iS == iTrain
				foldsSelf{iS} = foldOfTrial;
			else
				foldsSelf{iS} = iKFoldByTrial(S.trialIdx, S.phaseIdx, iS, nFold);
			end
		end

		% ---- 逐判别轴类型计算（数据只加载一次）----
		nLambda = numel(lambdaList);
		ratioCurve = nan(nPhase, nLambda, nAxisType);
		selfDMain = nan(nPhase, nAxisType);
		for iA = 1:nAxisType
			if axisTypes(iA) == "MeanDiff"
				% 均值差轴与 lambda 无关 → 只算一次，再展平成同祥的 lambda 维度以便统一出图
				[rA, selfD] = iRatioAtLambda(S, specs, iTrain, nFold, foldOfTrial, foldsSelf, NaN, axisTypes(iA));
				ratioCurve(:, :, iA) = repmat(rA, 1, nLambda);
				selfDMain(:, iA) = selfD;
			else
				for iL = 1:nLambda
					[rA, selfD] = iRatioAtLambda(S, specs, iTrain, nFold, foldOfTrial, foldsSelf, lambdaList(iL), axisTypes(iA));
					ratioCurve(:, iL, iA) = rA;
					if iL == iLambdaMain; selfDMain(:, iA) = selfD; end
				end
			end
		end
		ratio = squeeze(ratioCurve(:, iLambdaMain, :));   % 阶段 × 轴类型

		fprintf('  lambda=%.2f：\n', lambdaList(iLambdaMain));
		for iA = 1:nAxisType
			fprintf('    %-18s 自训 d''=[%s]  迁移保真度=[%s]\n', axisTypes(iA), ...
				strjoin(compose('%.2f', selfDMain(:, iA)'), ' '), ...
				strjoin(compose('%.2f', ratio(:, iA)'), ' '));
		end

		r = struct();
		r.Mouse = mouse; r.NCells = numel(cellUIDs);
		r.Specs = specs; r.TrainIdx = iTrain;
		r.Ratio = ratio; r.SelfD = selfDMain; r.RatioCurve = ratioCurve;
		allRes{iP, iM} = r;
	end
end

%% 2. 汇总 + 组水平配对检验（按判别轴类型分组报告）
for iA = 1:nAxisType
	fprintf('\n@@@@@@@@@@ 判别轴类型：%s (%s) @@@@@@@@@@\n', axisLabels(iA), axisTypes(iA));
	for iP = 1:numel(pairings)
		fprintf('\n====== 配对 %d: %s ======\n', iP, pairings(iP).Title);
		[R, ~, specs, iTrain] = iCollectRatio(allRes, iP);
		if isempty(R); fprintf('  无有效鼠\n'); continue; end
		Ra = R(:, :, iA);
		fprintf('  n = %d 鼠\n', size(Ra, 1));
		for iS = setdiff(1:numel(specs), iTrain)
			ok = isfinite(Ra(:,iTrain)) & isfinite(Ra(:,iS));   % NaN（该阶段不可用）不参与配对
			pv = signrank(Ra(ok,iTrain), Ra(ok,iS));
			fprintf('  %s(%s) vs 训练阶段(%s): 迁移保真度 %.2f vs %.2f, 有效 n=%d, 符号秩 p=%.4f\n', ...
				specs(iS).Phase, specs(iS).Stimulus, specs(iTrain).Phase, ...
				mean(Ra(ok,iS),'omitnan'), mean(Ra(ok,iTrain),'omitnan'), sum(ok), pv);
		end
	end
end

%% 3. 出图：迁移保真度（柱）＋配对符号秩 P 值
%    列＝轴取自哪个训练阶段；行＝判别轴算法（上：收缩 LDA；下：原文口径均值差轴）。
%    柱与单向误差条由 UniExp.BarScatterCompare 绘制，P 值线的位置由 MATLAB.Graphics.PLine 自动布局；
%    但其内部 P 值来自未配对多重比较，与逐鼠配对设计不符 → 文本改写为配对符号秩 P 值。
f = iNewFigure('Discriminant axis transfer', [9, 4 * nAxisType]);
tlo = tiledlayout(f, nAxisType, numel(pairings), 'TileSpacing','compact','Padding','compact');
for iA = 1:nAxisType
	for iP = 1:numel(pairings)
		ax = nexttile(tlo, (iA-1) * numel(pairings) + iP);
		[R, ~, specs, iTrain] = iCollectRatio(allRes, iP);
		if isempty(R); title(ax, "no data"); continue; end
		Ra = R(:, :, iA);
		nPhase = numel(specs);
		DataCell = arrayfun(@(iS) Ra(isfinite(Ra(:,iS)), iS), 1:nPhase, 'UniformOutput', false);
		otherIdx = setdiff((1:nPhase)', iTrain);
		CompareGroup = table([iTrain * ones(numel(otherIdx), 1), otherIdx], 'VariableNames', {'GroupPair'});
		[~, Optional, Bars] = UniExp.BarScatterCompare(DataCell, CompareGroup);
		set(Bars, 'FaceColor', [0.25 0.45 0.65], 'EdgeColor', 'none');
		pPaired = arrayfun(@(iS) signrank(Ra(:,iTrain), Ra(:,iS)), otherIdx);
		TransferLearning.Style.SetBarPValues(Optional, pPaired);
		yline(ax, 1, '--k');
		set(ax, 'XTick', 1:nPhase, ...
			'XTickLabel', arrayfun(@(s) s.Phase + "(" + s.Stimulus + ")", specs, 'UniformOutput', false));
		xtickangle(ax, 30);
		if iP == 1
			ylabel(ax, sprintf('transfer fidelity\n(%s)', axisLabels(iA)));
		else
			ylabel(ax, '');
		end
		title(ax, pairings(iP).Title, 'FontWeight', 'normal');
		box(ax, 'off');
	end
end
TransferLearning.ExportStandardFigure(f, 1, 'DiscriminantAxisTransfer.svg');

%% 4. lambda 敏感性曲线（仅收缩 LDA；均值差轴与 lambda 无关，已在柱图上给出水平）
f2 = iNewFigure('Lambda sensitivity', [9, 4]);
tlo2 = tiledlayout(f2, 1, numel(pairings), 'TileSpacing','compact','Padding','compact');
for iP = 1:numel(pairings)
	ax2 = nexttile(tlo2, iP);
	[~, C, specs, iTrain] = iCollectRatio(allRes, iP);
	if isempty(C); title(ax2, "no data"); continue; end
	C = C(:, :, :, iShrink);
	hold(ax2, 'on');
	otherIdx = setdiff(1:numel(specs), iTrain);
	nOther = numel(otherIdx);
	yEnd = nan(nOther, 1); labEnd = strings(nOther, 1); colEnd = cell(nOther, 1);
	for k = 1:nOther
		iS = otherIdx(k);
		muV = squeeze(mean(C(:,iS,:), 1, 'omitnan'));                    % λ × 1
		nOk = squeeze(sum(isfinite(C(:,iS,:)), 1));
		seV = squeeze(std(C(:,iS,:), 0, 1, 'omitnan')) ./ sqrt(nOk);
		he = errorbar(ax2, lambdaList(:), muV, seV, 'LineStyle', 'none');
		set(he, 'HandleVisibility', 'off');
		plot(ax2, lambdaList(:), muV, '-o', 'Color', he.Color);
		yEnd(k) = muV(end); labEnd(k) = specs(iS).Phase; colEnd{k} = he.Color;
	end
	yline(ax2, 1, '--k', 'HandleVisibility', 'off');
	hold(ax2, 'off');
	xlim(ax2, [lambdaList(1), lambdaList(end) + 0.16]);   % 右侧留白给线端标签
	% 线端标签：按 y 排序后强制最小间距（≈ 2 倍字高），避免叠字
	[yText, ord] = sort(yEnd);
	lim = ylim(ax2);
	gap = 0.09 * diff(lim);
	for k = 2:nOther
		yText(k) = max(yText(k), yText(k-1) + gap);
	end
	ylim(ax2, [lim(1), max(lim(2), yText(end) + 0.5 * gap)]);
	for k = 1:nOther
		text(ax2, lambdaList(end) + 0.02, yText(k), char(labEnd(ord(k))), ...
			'Color', colEnd{ord(k)}, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
	end
	xlabel(ax2, 'shrinkage \lambda');
	if iP == 1; ylabel(ax2, 'transfer fidelity'); else; ylabel(ax2, ''); end
	title(ax2, pairings(iP).Title, 'FontWeight', 'normal');
	box(ax2, 'off');
end
TransferLearning.ExportStandardFigure(f2, 1, 'DiscriminantAxisTransfer_LambdaCurve.svg');

fprintf('\nDone.\n');

%% ===== Local functions =====
function tbl = iQueryPhaseTrials(DS, mouse, phaseName, stimulusName, nTime)
q = struct('Mouse', mouse, 'Phase', phaseName, 'Stimulus', stimulusName);
res = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior","DateTime","Stimulus"]);
tbl = table();
if isempty(res); return; end
for i = 1:numel(res)                    % 逐个 session 拼接（不丢 session）
	if isempty(res{i}); continue; end
	t = res{i}; t.Phase = repmat(phaseName, height(t), 1);
	tbl = [tbl; t]; %#ok<AGROW>
end
end

function [S, ok] = iBuildSamples(specs, phaseData, cellUIDs, idxBaseline, idxCue)
% 每个试次产生两个样本：线索前基线（y=0）与线索后响应（y=1）
% 输出：X (nSamp × nCell)、y、phaseIdx、trialIdx
S = struct('X', [], 'y', [], 'phaseIdx', [], 'trialIdx', []);
ok = false;
Xall = []; yAll = []; pAll = []; tAll = [];
nBase = numel(idxBaseline);
globalTrial = 0;
for iS = 1:numel(specs)
	tbl = phaseData{iS};
	if isempty(tbl); continue; end
	trialUIDs = unique(tbl.TrialUID);
	for iT = 1:numel(trialUIDs)
		rows = tbl(tbl.TrialUID == trialUIDs(iT), :);
		M = nan(numel(cellUIDs), nBase + numel(idxCue));
		sig = double(rows.TrialSignal);
		[~, loc] = ismember(uint64(rows.CellUID), cellUIDs);
		for iR = 1:height(rows)
			if loc(iR) > 0
				M(loc(iR), 1:nBase) = sig(iR, idxBaseline);
				M(loc(iR), nBase+1:end) = sig(iR, idxCue);
			end
		end
		if any(~isfinite(M), 'all'); continue; end   % 细胞不全的试次整条丢弃，避免缺测污染两类的均值
		globalTrial = globalTrial + 1;
		Xall = [Xall; [mean(M(:, 1:nBase), 2)'; mean(M(:, nBase+1:end), 2)']]; %#ok<AGROW>
		yAll = [yAll; 0; 1]; %#ok<AGROW>
		pAll = [pAll; iS; iS]; %#ok<AGROW>
		tAll = [tAll; globalTrial; globalTrial]; %#ok<AGROW>
	end
end
if isempty(Xall); return; end
S.X = Xall; S.y = yAll; S.phaseIdx = pAll; S.trialIdx = tAll;
ok = true;
end

function [ratio, selfD] = iRatioAtLambda(S, specs, iTrain, nFold, foldOfTrial, foldsSelf, lam, axisType)
% 单个 lambda 下的迁移保真度：ratio = 迁移 d' / 自训 d'（阶段 × 1）
% lam 对 "MeanDiff" 无意义（传 NaN）
nPhase = numel(specs);

% 迁移：轴在训练阶段求得、固定后评估各阶段
dMat = nan(nPhase, nFold);
for iF = 1:nFold
	trMask = S.phaseIdx == iTrain & foldOfTrial ~= iF;
	if numel(unique(S.y(trMask))) < 2; continue; end
	w = iAxis(S.X(trMask,:), S.y(trMask), lam, axisType);
	for iS = 1:nPhase
		mS = S.phaseIdx == iS;
		if iS == iTrain; mS = mS & foldOfTrial == iF; end   % 训练阶段只评估留出折
		if ~any(mS) || numel(unique(S.y(mS))) < 2; continue; end
		dMat(iS, iF) = iEvalAxis(S.X(mS,:), S.y(mS), w);
	end
end
dPhase = mean(dMat, 2, 'omitnan');

% 对照：各阶段"自训轴"的判别力（该阶段自身的可分性上界）
selfD = nan(nPhase, 1);
for iS = 1:nPhase
	foldS = foldsSelf{iS};
	dS = nan(nFold, 1);
	for iF = 1:nFold
		tr = S.phaseIdx == iS & foldS ~= iF;
		te = S.phaseIdx == iS & foldS == iF;
		if numel(unique(S.y(tr))) < 2 || numel(unique(S.y(te))) < 2; continue; end
		dS(iF) = iEvalAxis(S.X(te,:), S.y(te), iAxis(S.X(tr,:), S.y(tr), lam, axisType));
	end
	selfD(iS) = mean(dS, 'omitnan');
end
ratio = dPhase ./ selfD;   % 迁移保真度：1 = 与自训轴等效
end

function w = iAxis(X, y, lambda, axisType)
% 判别轴。两种口径：
%   "ShrinkLda"：收缩协方差 LDA，w = Sp^{-1}(mu1-mu0)（细胞数 N ≫ 试次数，必须收缩）
%   "MeanDiff" ：条件均值差轴，w = mu1-mu0，无协方差项
%                （Mante 2013 targeted dimensionality reduction / Leow 2026 STAR Methods 口径；
%                 单一对比只需一根轴，原文的 QR 正交化在此无作用对象）
switch axisType
	case "ShrinkLda"
		nCell = size(X, 2);
		X1 = X(y == 1, :); X0 = X(y == 0, :);
		mu1 = mean(X1, 1)'; mu0 = mean(X0, 1)';
		S1 = cov(X1); S0 = cov(X0);
		n1 = size(X1, 1); n0 = size(X0, 1);
		Sp = ((n1-1) * S1 + (n0-1) * S0) / max(n1 + n0 - 2, 1);
		Sp = (1 - lambda) * Sp + lambda * (trace(Sp) / nCell) * eye(nCell);
		w = Sp \ (mu1 - mu0);
	case "MeanDiff"
		w = mean(X(y == 1, :), 1)' - mean(X(y == 0, :), 1)';
end
end

function d = iEvalAxis(X, y, w)
% 沿判别轴 w 的投影分离度 d'（与阈值无关，便于跨阶段比较判别力的“大小”）
p = X * w;
p1 = p(y == 1); p0 = p(y == 0);
sd = sqrt(0.5 * (var(p1) + var(p0)));
d = abs(mean(p1) - mean(p0)) / max(sd, eps);
end

function foldOfTrial = iKFoldByTrial(trialIdx, phaseIdx, iTrain, nFold)
% 按试次分组折（同一试次的多个样本必须同折，否则泄漏）
foldOfTrial = zeros(size(trialIdx));
uT = unique(trialIdx(phaseIdx == iTrain));
perm = uT(randperm(numel(uT)));
for i = 1:numel(perm)
	foldOfTrial(trialIdx == perm(i)) = mod(i-1, nFold) + 1;
end
end

function [R, Curve, specs, iTrain] = iCollectRatio(allRes, iP)
% 把第 iP 条配对的逐鼠结果收成矩阵（组水平检验与出图共用）
%   R     ：鼠 × 阶段 × 轴类型，主 lambda 下的迁移保真度
%   Curve ：鼠 × 阶段 × lambda × 轴类型，全部 lambda
rows = allRes(iP, :);
valid = ~cellfun(@isempty, rows);
R = []; Curve = []; specs = []; iTrain = [];
if ~any(valid); return; end
specs = rows{find(valid, 1)}.Specs;
iTrain = rows{find(valid, 1)}.TrainIdx;
sz = size(rows{find(valid, 1)}.RatioCurve);   % 阶段 × λ × 轴类型
R = nan(sum(valid), sz(1), sz(3));
Curve = nan(sum(valid), sz(1), sz(2), sz(3));
iRow = 0;
for i = find(valid)
	iRow = iRow + 1;
	R(iRow, :, :) = rows{i}.Ratio;
	Curve(iRow, :, :, :) = rows{i}.RatioCurve;
end
end

function f = iNewFigure(figName, sizeCm)
% 统一创建图窗（作图规范：基础高 4 cm，宽为 1.5 cm 的整数倍）
f = figure('Color', 'w', 'Name', figName);
f.Units = 'centimeters';
f.Position(3:4) = sizeCm;
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, sizeCm];
f.PaperSize = sizeCm;
end
