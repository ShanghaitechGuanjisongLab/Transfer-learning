%% DecodeCrossPhase_ALB_Balanced.m — 跨阶段 MCC 泛化解码（修正版，不改动 DecodeCrossPhase_ALB.m）
%
% 与 DecodeCrossPhase_ALB.m 的差异（共 3 处）：
%   ① 置换检验口径修正：原版真实统计量用「整条对角线均值」，零分布却只取单个 midT 时间点 →
%      p 值不成立。本版让置换也走整条对角线，与真实统计量同口径。
%   ② 训练集默认只用 Naive(AudioWater)：Learned 阶段 AudioWater 几乎全是 hit（~99.5%），
%      把它放进训练集会让「hit 模板」被 Learned 主导、「miss 模板」被 Naive 主导，
%      判别轴实际编码的是「阶段差异」而非「hit vs miss」。本版新增
%      balanceMode="stratifyByPhase"：按阶段分层平衡两类样本数，使任何阶段都不能单方面
%      主导任一类的模板；learnt 阶段若某一类样本为 0 会被自动剔除。
%   ③ 输出「阶段 × 结果」构成表，便于人工核查阶段-结果混淆。
%   ④ 去掉了原版查询处的 try/catch（按项目约定：可由流程自然抛出的异常不予捕获）。
%   其余（MCC 判据、48×48 时间泛化矩阵、CellUID 对齐、出图与导出方式）与原版一致。
%
% 1) 依赖
%    - MATLAB R2023b（无需 Statistics Toolbox：本版用向量化 z-score 替代 corr）
%    - 本项目 +TransferLearning 包
%
% 2) 前置
%    - 可访问 \\Data-Server-2\个人数据\张天夫\202512\声光迁移MOp成像（含学会后三次）.v5.mat
%    - 无需任何其它前置脚本
%
% 3) 图注
%    跨阶段 MCC 泛化解码（训练：Naive/Learned 声水；测试：Transfer 光水）。
%    左：逐鼠的时间×时间泛化矩阵（对角线 = 同步时刻的跨阶段解码准确率）；右：逐鼠对角线准确率。
%
% 4) 代码

%% 0. 可调参数
trainPhases = "Naive";              % 训练阶段；若要含 Learned 改成 ["Naive","Learned"]
nLearnedSessions = 2;               % 仅当 trainPhases 含 "Learned" 时生效：只用前几个 Learned session
balanceMode = "stratifyByPhase";    % "stratifyByPhase"（默认，按阶段分层平衡两类样本）| "none"
nPerm = 1000;                       % 置换次数
rng(0);                             % 固定随机种子，保证分层抽样与置换可复现

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
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

%% 2. 逐鼠跨阶段解码
TQ = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus","Behavior"]);
TQ.Mouse = string(TQ.Mouse); TQ.Phase = string(TQ.Phase);
mice = unique(TQ.Mouse);
fprintf('=== Cross-phase generalization (balanced training set) ===\n');
fprintf('Training phases: %s | balanceMode: %s\n', strjoin(trainPhases, '+'), balanceMode);
fprintf('Mice: %d\n', numel(mice));

results = cell(numel(mice), 1);

for iM = 1:numel(mice)
	mouse = mice(iM);
	fprintf('\n--- %s (%d/%d) ---\n', mouse, iM, numel(mice));

	allData = table();

	for iPh = 1:numel(trainPhases)
		phaseName = trainPhases(iPh);
		q = struct('Mouse', mouse, 'Phase', phaseName, 'Stimulus', "AudioWater");
		res = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:nTime, ...
			'ExtraColumns', ["Behavior","DateTime"]);
		if isempty(res) || isempty(res{1}); continue; end
		tbl = res{1};
		if phaseName == "Learned" && numel(unique(tbl.DateTime)) > nLearnedSessions
			sessDT = sort(unique(tbl.DateTime));
			tbl = tbl(ismember(tbl.DateTime, sessDT(1:nLearnedSessions)), :);
		end
		if isempty(tbl); continue; end
		tbl.Phase = repmat(phaseName, height(tbl), 1);
		allData = [allData; tbl]; %#ok<AGROW>
	end

	qT = struct('Mouse', mouse, 'Phase', "Transfer", 'Stimulus', "LightWater");
	res = DS.QueryNTS(qT, UniExp.Flags.ZScore, 1:nTime, ...
		'ExtraColumns', ["Behavior","DateTime"]);
	if ~isempty(res) && ~isempty(res{1})
		tbl = res{1};
		tbl.Phase = repmat("Transfer", height(tbl), 1);
		allData = [allData; tbl];
	end

	if isempty(allData) || ~ismember('TrialSignal', string(allData.Properties.VariableNames))
		fprintf('  SKIP: no data\n'); continue;
	end

	cellUIDs = uint64(unique(allData.CellUID));
	if numel(cellUIDs) < 5; fprintf('  SKIP: %d cells\n', numel(cellUIDs)); continue; end

	[Xall, yAll, ~, phaseAll] = iBuildFeatureMatrixWithPhase(allData, cellUIDs);
	if isempty(Xall) || numel(yAll) < 10; fprintf('  SKIP: insufficient trials\n'); continue; end

	% ---- 训练集选择（含阶段×结果构成核查）----
	[selTrain, comp] = iPickTrainTrials(yAll, phaseAll, trainPhases, balanceMode);
	testMask = phaseAll == "Transfer";

	fprintf('  训练集构成（阶段 × 结果）：\n');
	disp(comp);

	if sum(selTrain) < 6 || sum(testMask) < 3
		fprintf('  SKIP: train=%d test=%d\n', sum(selTrain), sum(testMask)); continue;
	end

	nCellM = size(Xall{1},1); nTimeM = size(Xall{1},2);
	nTrain = sum(selTrain); nTest = sum(testMask);
	CTTtrain = nan(nCellM, nTrain, nTimeM);
	CTTtest  = nan(nCellM, nTest,  nTimeM);
	yTrain = yAll(selTrain); yTest = yAll(testMask);
	iT = 0;
	for iS = find(selTrain)'; iT = iT + 1; CTTtrain(:,iT,:) = Xall{iS}; end
	iT = 0;
	for iS = find(testMask)'; iT = iT + 1; CTTtest(:,iT,:) = Xall{iS}; end

	fprintf('  Train: %d trials(H%d/M%d)  Test: %d trials(H%d/M%d)  Cells:%d\n', ...
		nTrain, sum(yTrain==1), sum(yTrain==0), ...
		nTest, sum(yTest==1), sum(yTest==0), nCellM);

	if sum(yTrain==1)<2 || sum(yTrain==0)<2 || sum(yTest==1)<1 || sum(yTest==0)<1
		fprintf('  SKIP: class imbalance\n'); continue;
	end

	% ---- 测试集 z-score 与标签无关，预计算一次 ----
	DzCell = cell(nTest,1);
	for iTst = 1:nTest
		DzCell{iTst} = iZScoreCols(CTTtest(:,:,iTst));
	end

	% ---- 真实统计量 + 同口径置换零分布（均取整条对角线均值）----
	accMat = iCrossAcc(CTTtrain, yTrain, DzCell, yTest);
	realDiag = mean(diag(accMat), 'omitnan');

	permDiag = nan(nPerm,1);
	for iP = 1:nPerm
		sy = yTrain(randperm(nTrain));
		if numel(unique(sy)) < 2; continue; end
		accP = iCrossAcc(CTTtrain, sy, DzCell, yTest);
		permDiag(iP) = mean(diag(accP), 'omitnan');
	end
	pVal = mean(permDiag >= realDiag, 'omitnan');

	r = struct();
	r.Mouse = mouse; r.NCells = nCellM;
	r.NTrain = nTrain; r.NTest = nTest;
	r.NHitTrain = sum(yTrain==1); r.NMissTrain = sum(yTrain==0);
	r.NHitTest = sum(yTest==1);   r.NMissTest = sum(yTest==0);
	r.AccMat = accMat; r.RealDiag = realDiag;
	r.PermDiag = permDiag; r.PVal = pVal;
	r.TrainComposition = comp;
	r.Xs = xs(1:nTimeM);
	results{iM} = r;

	fprintf('  跨阶段 ACC(对角线均值): %.1f%%  (置换 %.1f±%.1f%%, p=%.4f)\n', ...
		realDiag*100, mean(permDiag,'omitnan')*100, std(permDiag,'omitnan')*100, pVal);
end

%% 3. Summary
valid = find(~cellfun(@isempty, results));
fprintf('\n====== CROSS-PHASE SUMMARY ======\n');
fprintf('Valid mice: %d/%d\n', numel(valid), numel(mice));
diags = nan(numel(valid),1);
for i = 1:numel(valid)
	r = results{valid(i)};
	sig = ''; if r.PVal < 0.05; sig = ' *'; end; if r.PVal < 0.01; sig = ' **'; end; if r.PVal < 0.001; sig = ' ***'; end
	fprintf('  %s: train=%d(H%d/M%d) test=%d(H%d/M%d) ACC=%.1f%% p=%.4f%s\n', ...
		r.Mouse, r.NTrain, r.NHitTrain, r.NMissTrain, ...
		r.NTest, r.NHitTest, r.NMissTest, r.RealDiag*100, r.PVal, sig);
	diags(i) = r.RealDiag;
end
fprintf('Mean ACC: %.1f%%\n', mean(diags,'omitnan')*100);
fprintf('Above chance: %d/%d\n', sum(diags>0.5,'omitnan'), numel(valid));

%% 4. Plots
nValid = numel(valid);
if nValid > 0
	nCols = min(4, nValid); nRows = ceil(nValid/nCols);
	fCtd = figure('Name','Cross-phase CTD','Color','w','Position',[50 50 nCols*280 nRows*260]);
	tiledlayout(fCtd, nRows, nCols, 'TileSpacing','compact','Padding','compact');
	for i = 1:nValid
		r = results{valid(i)}; nexttile; %#ok<LAXES>
		imagesc(r.Xs, r.Xs, r.AccMat'); axis xy square;
		colormap(hot); clim([0.3 1]);
		hold on; plot(r.Xs, r.Xs, '-', 'Color',[0 0 0 0.25],'LineWidth',1); hold off;
		sig = ''; if r.PVal<0.05; sig=' *'; end
		title(sprintf('%s %.1f%%%s', r.Mouse, r.RealDiag*100, sig),'FontSize',8,'FontWeight','normal');
		xlabel('Train (s)'); ylabel('Test (s)');
	end
	TransferLearning.ExportStandardFigure(fCtd, 2, 'DecodeCrossPhaseBalanced_CTD.svg');
end

fBar = figure('Name','Cross-phase decoding (balanced)','Color','w','Position',[100 100 420 300]);
ax = axes(fBar); %#ok<LAXES>
mouseNames = arrayfun(@(i) results{valid(i)}.Mouse, 1:nValid, 'UniformOutput', false);
barData = 100 * diags;
b = bar(ax, 1:nValid, barData); b.FaceColor = [0.2 0.5 0.7]; b.EdgeColor = 'none';
hold(ax,'on'); yline(ax, 50, '--k');
for i = 1:nValid
	r = results{valid(i)};
	if r.PVal < 0.05
		sg = '*'; if r.PVal<0.01; sg='**'; end; if r.PVal<0.001; sg='***'; end
		text(ax, i, barData(i)+2, sg, 'HorizontalAlignment','center','FontSize',10);
	end
end
set(ax, 'XTickLabel', mouseNames); xtickangle(ax, 45);
ylabel(ax, 'Cross-phase decoding (%)');
title(ax, sprintf('%s -> Transfer', strjoin(trainPhases, '+')));
box(ax,'off'); ylim(ax, [0 105]);
TransferLearning.ExportStandardFigure(fBar, 2, 'DecodeCrossPhaseBalanced_Bar.svg');

fprintf('\nDone.\n');

%% ===== Local functions =====
function accMat = iCrossAcc(CTTtrain, yTrain, DzCell, yTest)
% MCC 跨阶段解码：训练时刻的 hit/miss 模板差即为判别轴；把测试 trial 投影到该轴。
% 测试集 z-score（DzCell）与标签无关，故可预先算好、在置换里复用。
[nCellM, nTimeM, ~] = size(CTTtrain);
nTest = numel(yTest);
Hz = iZScoreCols(mean(CTTtrain(:,:,yTrain==1), 3));
Mz = iZScoreCols(mean(CTTtrain(:,:,yTrain==0), 3));
accMat = zeros(nTimeM, nTimeM);
for iTst = 1:nTest
	Dz = DzCell{iTst};
	cH = (Hz' * Dz) / (nCellM - 1);
	cM = (Mz' * Dz) / (nCellM - 1);
	accMat = accMat + double((cH >= cM) == yTest(iTst));
end
accMat = accMat / nTest;
end

function Z = iZScoreCols(M)
% 按列（跨细胞）z-score。Pearson 相关对正仿射变换不变，故与逐对 corr 判据等价。
mu = mean(M, 1);
sd = std(M, 0, 1);
sd(sd == 0) = 1;
Z = (M - mu) ./ sd;
end

function [sel, comp] = iPickTrainTrials(y, phases, trainPhases, balanceMode)
% 训练试次选择。stratifyByPhase：每个阶段对每一类贡献相同数量的样本，
% 使任何阶段都不能单方面主导模板；某一类样本为 0 的阶段被整体剔除。
n = numel(y);
inPhase = ismember(phases, trainPhases);
uPh = unique(phases(inPhase));
comp = table('Size', [numel(uPh) 3], ...
	'VariableTypes', {'string','double','double'}, ...
	'VariableNames', {'Phase','NHit','NMiss'});
for i = 1:numel(uPh)
	comp.Phase(i)  = uPh(i);
	comp.NHit(i)   = sum(inPhase & phases == uPh(i) & y == 1);
	comp.NMiss(i)  = sum(inPhase & phases == uPh(i) & y == 0);
end

if balanceMode == "none" || numel(uPh) <= 1
	sel = inPhase;
	return;
end

keep = comp.NHit > 0 & comp.NMiss > 0;
if ~any(keep)
	sel = false(n, 1);
	return;
end

m1 = min(comp.NHit(keep));
m0 = min(comp.NMiss(keep));
sel = false(n, 1);
for i = find(keep)'
	idxH = find(inPhase & phases == uPh(i) & y == 1);
	idxM = find(inPhase & phases == uPh(i) & y == 0);
	sel(idxH(randperm(numel(idxH), m1))) = true;
	sel(idxM(randperm(numel(idxM), m0))) = true;
end
end

function [X, y, trialUIDs, phases] = iBuildFeatureMatrixWithPhase(rawTbl, cellUIDs)
sig = double(rawTbl.TrialSignal); nTime = size(sig,2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
	double(rawTbl.Behavior), ...
	'VariableNames', {'CellUID','TrialUID','Behavior'});
rawPhase = string(rawTbl.Phase);
sigCell = cell(size(sig,1),1);
for i=1:size(sig,1); sigCell{i}=sig(i,:); end
ntsTbl.Signal = sigCell;
keepRows = ismember(ntsTbl.CellUID, cellUIDs);
ntsTbl = ntsTbl(keepRows, :);
rawPhase = rawPhase(keepRows);
if isempty(ntsTbl); X=[]; y=[]; trialUIDs=[]; phases=[]; return; end
trialUIDs = unique(ntsTbl.TrialUID);
nTrials = numel(trialUIDs); nCells = numel(cellUIDs);
X = cell(nTrials,1); y = nan(nTrials,1); phases = strings(nTrials,1);
for iT = 1:nTrials
	rows = ntsTbl(ntsTbl.TrialUID == trialUIDs(iT), :);
	seqMat = nan(nCells, nTime);
	[~,loc] = ismember(rows.CellUID, cellUIDs);
	for iR=1:height(rows); ci=loc(iR); if ci>0; seqMat(ci,:)=rows.Signal{iR}; end; end
	X{iT} = seqMat; y(iT) = mode(rows.Behavior);
	uPhase = unique(rawPhase(ntsTbl.TrialUID == trialUIDs(iT)));
	phases(iT) = uPhase(1);
end
hasData = cellfun(@(m) all(isfinite(m),'all'), X) & isfinite(y);
X = X(hasData); y = y(hasData); trialUIDs = trialUIDs(hasData); phases = phases(hasData);
for i=1:numel(X); X{i}(isnan(X{i}))=0; end
end
