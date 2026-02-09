% 探索：哪些首会话神经特征能显著预测首会话命中率（First-Session Hit Rate）？
%
% 统计单位：每只鼠的首个 LightWater 会话（一个值/鼠）
% Transfer 来源：AudioLightBaseline（ALB），Phase = "Transfer"
% Naive 来源：LightAudioBaseline（LAB）+ LAInterspersed（LAI），Phase = "Naive"
% 仅含成像数据的鼠（排除纯行为队列）
%
% 候选特征：SD, ActiveFrac, MeanNTATS, Divergence
% 时间点（0–1s 内）：0.3s, 0.5s, 0.75s, 1.0s
% 层分组：All (L2/3+L5), MOp23, MOp5
%
% 筛选条件：
%   ① Transfer 内 Spearman ρ(feature, hitRate) p<0.05
%   ② Naive 内 Spearman ρ(feature, hitRate) p<0.05
%   ③ Rank-sum (T vs N) p<0.05 且方向一致（ρ>0 → T>N）
%
% 后续：AW 细胞中介分析（在满足上述条件的特征上）

%% ====== 加载数据集 ======
fprintf('========== 首会话命中率特征探索 ==========\n');
ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

% --- 时间轴 ---
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);

timePoints = [0.3, 0.5, 0.75, 1.0];
nTP = numel(timePoints);
idxTP = nan(1, nTP);
for iT = 1:nTP
	[dt, idx] = min(abs(xsSec - timePoints(iT)));
	if dt <= 0.15, idxTP(iT) = idx; end
end
kSigma = 3;

fprintf('时间点 → 采样索引：');
for iT = 1:nTP
	fprintf(' %.2fs→idx%d(%.3fs)', timePoints(iT), idxTP(iT), xsSec(idxTP(iT)));
end
fprintf('\n');

layerNames  = ["All","MOp23","MOp5"];
layerFilters = {@(z) true(size(z)), @(z) z=="MOp2/3", @(z) z=="MOp5"};
nLayers = numel(layerNames);

%% ====== 构建特征名称列表 ======
featureNames = {};
for iTP = 1:nTP
	tpStr = strrep(sprintf('%.2fs', timePoints(iTP)), '.', 'p');
	for iL = 1:nLayers
		prefix = [tpStr '_' char(layerNames(iL)) '_'];
		featureNames = [featureNames, ...
			{[prefix 'SD'], [prefix 'ActFrac'], ...
			 [prefix 'MeanNTATS'], [prefix 'Div']}]; %#ok<AGROW>
	end
end
% 额外特征：细胞数量
for iL = 1:nLayers
	featureNames = [featureNames, {['nCells_' char(layerNames(iL))]}]; %#ok<AGROW>
end
% 额外特征：基线 SD（pre-stimulus period，所有细胞）
featureNames = [featureNames, {'BaselineSD_All', 'BaselineSD_MOp23', 'BaselineSD_MOp5'}];
% 额外特征：跨时间变化斜率（SD 和 MeanNTATS 的 1.0s vs 0.3s 比值）
for iL = 1:nLayers
	ln = char(layerNames(iL));
	featureNames = [featureNames, {['SDSlope_' ln], ['MeanSlope_' ln]}]; %#ok<AGROW>
end
nFeatures = numel(featureNames);
fprintf('共 %d 个候选特征\n', nFeatures);

%% ====== Transfer 鼠：首会话提取 ======
fprintf('\n--- Transfer 鼠（ALB, Phase=Transfer）---\n');
[transMice, transHit, transFeats, transNCells] = iExtractFirstSession( ...
	ALB, "Transfer", string.empty, featureNames, ...
	idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers);

%% ====== Naive 鼠：首会话提取（LAB + LAI，排除 AW 污染） ======
fprintf('\n--- Naive 鼠（LAB + LAI, Phase=Naive）---\n');

% LAB + LAI：AW 排除在 iExtractFirstSession 内部进行
% 策略：仅剔除首个 LW 会话掺杂 AudioWater 的鼠（其它会话不影响）
fprintf('  AW 排除策略: 仅剔除首个LW会话掺杂AudioWater的鼠\n');

% 分别提取（无鼠级别预筛选）
[labMice, labHit, labFeats, ~] = iExtractFirstSession( ...
	LAB, "Naive", string.empty, featureNames, ...
	idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers);
[laiMice, laiHit, laiFeats, ~] = iExtractFirstSession( ...
	LAI, "Naive", string.empty, featureNames, ...
	idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers);

% 合并 Naive
naiveMice  = [labMice; laiMice];
naiveHit   = [labHit;  laiHit];
naiveFeats = [labFeats; laiFeats];

fprintf('\n汇总: Transfer %d 鼠, Naive %d 鼠\n', numel(transMice), numel(naiveMice));
fprintf('Transfer 首会话命中率: median=%.3f, range=[%.3f, %.3f]\n', ...
	median(transHit), min(transHit), max(transHit));
fprintf('Naive   首会话命中率: median=%.3f, range=[%.3f, %.3f]\n', ...
	median(naiveHit), min(naiveHit), max(naiveHit));
[pHitRS, ~] = ranksum(transHit, naiveHit);
fprintf('Hit Rate rank-sum T vs N: p=%.4f\n', pHitRS);

%% ====== Spearman 相关：特征 vs 首会话命中率 ======
fprintf('\n========== Transfer 内 Spearman (feature vs hit) ==========\n');
[rhoT, pT, nT] = iSpearmanSweep(transFeats, transHit, featureNames);

fprintf('\n========== Naive 内 Spearman (feature vs hit) ==========\n');
[rhoN, pN, nN] = iSpearmanSweep(naiveFeats, naiveHit, featureNames);

%% ====== Rank-Sum：T vs N 特征值差异 ======
fprintf('\n========== Rank-Sum T vs N (特征值) ==========\n');
[pRS, dirRS, medT, medN] = iRankSumSweep(transFeats, naiveFeats, featureNames);

%% ====== 三重筛选 ======
fprintf('\n\n');
fprintf('╔════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                        三 重 筛 选 结 果                                 ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════════╝\n');
fprintf('\n筛选条件：\n');
fprintf('  ① Transfer Spearman p < 0.05\n');
fprintf('  ② Naive Spearman p < 0.05\n');
fprintf('  ③ Rank-sum p < 0.05 + 方向一致 + T>N (若 ρ>0)\n');
fprintf('\n');

passAll = false(nFeatures, 1);
fprintf('%-38s | %6s %6s | %6s %6s | %6s %6s %6s %6s | Pass\n', ...
	'Feature', 'rhoT', 'pT', 'rhoN', 'pN', 'pRS', 'medT', 'medN', 'dir');
fprintf('%s\n', repmat('-', 1, 110));

for iF = 1:nFeatures
	pass1 = ~isnan(pT(iF)) && pT(iF) < 0.05;
	pass2 = ~isnan(pN(iF)) && pN(iF) < 0.05;
	
	% 方向一致性：ρ>0 要求 T>N, ρ<0 要求 T<N
	% 同时 Transfer 和 Naive 的 ρ 符号必须一致
	sameSign = (~isnan(rhoT(iF)) && ~isnan(rhoN(iF))) && sign(rhoT(iF)) == sign(rhoN(iF));
	if sameSign && rhoT(iF) > 0
		dirOK = dirRS(iF) > 0;  % T > N
	elseif sameSign && rhoT(iF) < 0
		dirOK = dirRS(iF) < 0;  % T < N
	else
		dirOK = false;
	end
	pass3 = ~isnan(pRS(iF)) && pRS(iF) < 0.05 && dirOK;
	
	passAll(iF) = pass1 && pass2 && pass3;
	
	% 如果至少通过了一项筛选或接近通过，显示
	anyClose = (pass1 || pass2 || pass3 || ...
		(~isnan(pT(iF)) && pT(iF) < 0.1) || ...
		(~isnan(pN(iF)) && pN(iF) < 0.1) || ...
		(~isnan(pRS(iF)) && pRS(iF) < 0.1));
	if anyClose
		mark = "";
		if passAll(iF), mark = " <<<< PASS ALL"; end
		fprintf('%-38s | %+.3f %.4f | %+.3f %.4f | %.4f %6.3f %6.3f %+d |%s\n', ...
			featureNames{iF}, rhoT(iF), pT(iF), rhoN(iF), pN(iF), ...
			pRS(iF), medT(iF), medN(iF), dirRS(iF), mark);
	end
end

nPass = nnz(passAll);
fprintf('\n通过全部三重筛选的特征数: %d / %d\n', nPass, nFeatures);
if nPass > 0
	passIdx = find(passAll);
	for ii = 1:numel(passIdx)
		iF = passIdx(ii);
		fprintf('  ★ %s: rhoT=%+.3f(p=%.4f), rhoN=%+.3f(p=%.4f), RS_p=%.4f, medT=%.3f, medN=%.3f\n', ...
			featureNames{iF}, rhoT(iF), pT(iF), rhoN(iF), pN(iF), pRS(iF), medT(iF), medN(iF));
	end
end

%% ====== 宽松筛选（各项 p<0.10）======
fprintf('\n=== 宽松筛选（p < 0.10） ===\n');
passLoose = false(nFeatures, 1);
for iF = 1:nFeatures
	p1 = ~isnan(pT(iF)) && pT(iF) < 0.10;
	p2 = ~isnan(pN(iF)) && pN(iF) < 0.10;
	sameSign = (~isnan(rhoT(iF)) && ~isnan(rhoN(iF))) && sign(rhoT(iF)) == sign(rhoN(iF));
	if sameSign && rhoT(iF) > 0, dirOK = dirRS(iF) > 0;
	elseif sameSign && rhoT(iF) < 0, dirOK = dirRS(iF) < 0;
	else, dirOK = false; end
	p3 = ~isnan(pRS(iF)) && pRS(iF) < 0.10 && dirOK;
	passLoose(iF) = p1 && p2 && p3;
end
nLoose = nnz(passLoose);
fprintf('通过宽松三重筛选: %d / %d\n', nLoose, nFeatures);
if nLoose > 0
	looseIdx = find(passLoose);
	for ii = 1:numel(looseIdx)
		iF = looseIdx(ii);
		fprintf('  ◆ %s: rhoT=%+.3f(p=%.4f), rhoN=%+.3f(p=%.4f), RS_p=%.4f, medT=%.3f, medN=%.3f\n', ...
			featureNames{iF}, rhoT(iF), pT(iF), rhoN(iF), pN(iF), pRS(iF), medT(iF), medN(iF));
	end
end

%% ====== 分项排名 Top-10 ======
fprintf('\n=== Transfer 内相关 Top-10（按 p 排序）===\n');
iPrintTopN(featureNames, rhoT, pT, 10);

fprintf('\n=== Naive 内相关 Top-10（按 p 排序）===\n');
iPrintTopN(featureNames, rhoN, pN, 10);

fprintf('\n=== Rank-Sum T vs N Top-10（按 p 排序）===\n');
iPrintTopN_RS(featureNames, pRS, medT, medN, dirRS, 10);

%% ====== AW 细胞中介分析（对通过或接近通过的特征） ======
% 寻找满足宽松条件的特征进行 AW 中介检验
candidateIdx = find(passAll | passLoose);
if isempty(candidateIdx)
	% 退而求其次：选 Transfer 和 Naive 相关都 < 0.2 且 RS < 0.2 的特征
	relaxed = (~isnan(pT) & pT < 0.2) & (~isnan(pN) & pN < 0.2) & (~isnan(pRS) & pRS < 0.2);
	candidateIdx = find(relaxed);
	fprintf('\n无严格通过特征。对 %d 个宽松候选做 AW 中介分析。\n', numel(candidateIdx));
end

if ~isempty(candidateIdx)
	fprintf('\n╔════════════════════════════════════════════════════════════╗\n');
	fprintf('║              AW 细胞中介分析                               ║\n');
	fprintf('╚════════════════════════════════════════════════════════════╝\n');
	
	% 获取 Learned AudioWater NTATS（Transfer 鼠 only）
	LearnedG = ALB.QueryNTATS(struct('Stimulus','AudioWater','Phase','Learned'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	learnedUID = uint64(LearnedG.CellUID);
	learnedNTATS = iNtatsData(LearnedG.NTATS);
	
	C_ALB = ALB.Cells;
	C_ALB.CellUID = uint64(C_ALB.CellUID);
	C_ALB.Mouse = string(C_ALB.Mouse);
	C_ALB.ZLayer = string(C_ALB.ZLayer);
	
	% 重新计算 Transfer 首会话，但去除 AW 活跃细胞后的特征值
	fprintf('\n--- Test C: 消融 AW 活跃细胞后重新计算 ---\n');
	[transFeats_noAW] = iRecomputeWithoutAW( ...
		ALB, transMice, C_ALB, learnedUID, learnedNTATS, ...
		featureNames, idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers);
	
	% Pre-compute ALL AW Learned 特征用于 Test D 多指标扫描
	fprintf('\n--- Test D 准备: 计算 AW Learned 阶段全部 %d 个特征 ---\n', nFeatures);
	awAllFeats = iComputeAllAWFeatures(ALB, transMice, C_ALB, learnedUID, learnedNTATS, ...
		featureNames, idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers);
	
	for ii = 1:numel(candidateIdx)
		iF = candidateIdx(ii);
		fname = featureNames{iF};
		fprintf('\n--- 特征: %s ---\n', fname);
		
		% Test C-1: 消融后 Transfer 内预测力是否消失
		x_orig = transFeats(:, iF);
		x_noAW = transFeats_noAW(:, iF);
		y = transHit;
		
		mask_orig = isfinite(x_orig) & isfinite(y);
		mask_noAW = isfinite(x_noAW) & isfinite(y);
		
		if nnz(mask_orig) >= 5 && std(x_orig(mask_orig)) > 0
			[rO, pO] = corr(x_orig(mask_orig), y(mask_orig), 'Type', 'Spearman');
		else
			rO = NaN; pO = NaN;
		end
		if nnz(mask_noAW) >= 5 && std(x_noAW(mask_noAW)) > 0
			[rA, pA] = corr(x_noAW(mask_noAW), y(mask_noAW), 'Type', 'Spearman');
		else
			rA = NaN; pA = NaN;
		end
		fprintf('  Transfer 预测: 原始 ρ=%+.3f p=%.4f → 消融AW后 ρ=%+.3f p=%.4f\n', rO, pO, rA, pA);
		if pO < 0.05 && (isnan(pA) || pA >= 0.05)
			fprintf('  ✓ Test C-1 PASS: 消融 AW 细胞后预测力消失\n');
		else
			fprintf('  ✗ Test C-1 FAIL\n');
		end
		
		% Test C-2: 消融后 T>N 差异是否消失
		nf = naiveFeats(:, iF);
		if nnz(isfinite(x_orig)) >= 3 && nnz(isfinite(nf)) >= 3
			pRS_orig = ranksum(x_orig(isfinite(x_orig)), nf(isfinite(nf)));
		else
			pRS_orig = NaN;
		end
		if nnz(isfinite(x_noAW)) >= 3 && nnz(isfinite(nf)) >= 3
			pRS_noAW = ranksum(x_noAW(isfinite(x_noAW)), nf(isfinite(nf)));
		else
			pRS_noAW = NaN;
		end
		fprintf('  T vs N 差异: 原始 p=%.4f → 消融AW后 p=%.4f\n', pRS_orig, pRS_noAW);
		if pRS_orig < 0.05 && (isnan(pRS_noAW) || pRS_noAW >= 0.05)
			fprintf('  ✓ Test C-2 PASS: 消融 AW 细胞后组间差异消失\n');
		else
			fprintf('  ✗ Test C-2 FAIL\n');
		end
		
		% Test D: AW Learned 阶段多种特征与 LW 首会话当前特征的相关（Transfer 鼠内）
		fprintf('  Test D (AW→LW 多指标扫描):\n');
		bestR_D = 0; bestP_D = 1; bestName_D = "";
		nSigD = 0;
		for jF = 1:nFeatures
			aw = awAllFeats(:, jF);
			mask_d = isfinite(aw) & isfinite(x_orig);
			if nnz(mask_d) >= 5 && std(aw(mask_d)) > 0 && std(x_orig(mask_d)) > 0
				[rAW, pAW] = corr(aw(mask_d), x_orig(mask_d), 'Type', 'Spearman');
				if pAW < 0.05
					nSigD = nSigD + 1;
					fprintf('    ✓ AW[%s] → LW[%s]: ρ=%+.3f p=%.4f (n=%d)\n', ...
						featureNames{jF}, fname, rAW, pAW, nnz(mask_d));
				end
				if abs(rAW) > abs(bestR_D)
					bestR_D = rAW; bestP_D = pAW; bestName_D = string(featureNames{jF});
				end
			end
		end
		if nSigD == 0
			fprintf('    ✗ 无显著AW特征 (最佳: %s, ρ=%+.3f, p=%.3f)\n', bestName_D, bestR_D, bestP_D);
		else
			fprintf('    共 %d 个AW特征显著相关\n', nSigD);
		end
	end
end

%% ====== 保存到 Workspace ======
summaryTable = table(string(featureNames)', rhoT, pT, rhoN, pN, pRS, medT, medN, ...
	'VariableNames', {'Feature','rhoT','pT','rhoN','pN','pRS','medT','medN'});
summaryTable = sortrows(summaryTable, 'pT');
assignin('base', 'FirstHit_Summary', summaryTable);
assignin('base', 'FirstHit_TransFeats', transFeats);
assignin('base', 'FirstHit_NaiveFeats', naiveFeats);
assignin('base', 'FirstHit_TransHit', transHit);
assignin('base', 'FirstHit_NaiveHit', naiveHit);
assignin('base', 'FirstHit_TransMice', transMice);
assignin('base', 'FirstHit_NaiveMice', naiveMice);
fprintf('\nDone. 结果已保存到 workspace.\n');

%% ======== LOCAL FUNCTIONS ========

function [mice, hitRates, feats, nCellsAll] = iExtractFirstSession( ...
		DS, phase, pureWhitelist, featureNames, ...
		idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers)
	% 获取指定 phase 的所有 blocks
	T = DS.TableQuery(["Mouse","BlockUID","DateTime","Phase"], Phase=phase);
	if isempty(T)
		mice = string.empty; hitRates = []; feats = []; nCellsAll = []; return;
	end
	
	allMice = unique(string(T.Mouse));
	
	% 白名单过滤
	if ~isempty(pureWhitelist)
		allMice = intersect(allMice, pureWhitelist);
	end
	
	% 从 Trials 中计算 LW-only 每 block 的命中率
	Tr = DS.Trials;
	Tr.BlockUID = uint64(Tr.BlockUID);
	T.BlockUID = uint64(T.BlockUID);
	
	C = DS.Cells;
	C.CellUID = uint64(C.CellUID);
	C.Mouse = string(C.Mouse);
	C.ZLayer = string(C.ZLayer);
	
	nFeat = numel(featureNames);
	mice = string.empty;
	hitRates = [];
	feats = [];
	nCellsAll = [];
	
	for iM = 1:numel(allMice)
		m = allMice(iM);
		rowsM = T.Mouse == m;
		dts = unique(T.DateTime(rowsM));
		
		% 对每个日期检查是否含 AudioWater
		validDTs = dts([]); % preserve timezone info from source
		validPerfs = [];
		validHasAW = false(1,0);
		for iDT = 1:numel(dts)
			dt_i = dts(iDT);
			% 获取该日期所有 blocks 的 BlockUID
			buThis = T.BlockUID(rowsM & T.DateTime == dt_i);
			
			% 统计 LW 命中率，同时检查是否含 AudioWater
			hasAW = false;
			totalHit = 0; totalLW = 0;
			for iBu = 1:numel(buThis)
				trB = Tr(Tr.BlockUID == buThis(iBu), :);
				if isempty(trB), continue; end
				stim = string(trB.Stimulus);
				if any(stim == "AudioWater")
					hasAW = true;
				end
				lwMask = stim == "LightWater";
				if any(lwMask)
					totalLW = totalLW + nnz(lwMask);
					totalHit = totalHit + sum(double(trB.Behavior(lwMask)), 'omitnan');
				end
			end
			if totalLW == 0, continue; end
			
			validDTs(end+1) = dt_i; %#ok<AGROW>
			validPerfs(end+1) = totalHit / totalLW; %#ok<AGROW>
			validHasAW(end+1) = hasAW; %#ok<AGROW>
		end
		
		if isempty(validDTs), continue; end
		
		% 取最早 LW 日期 = 首会话
		[~, firstIdx] = min(validDTs);
		firstDT = validDTs(firstIdx);
		firstPerf = validPerfs(firstIdx);
		
		% 若首会话掺杂 AudioWater → 排除该鼠
		if validHasAW(firstIdx)
			fprintf('  排除 %s: 首个LW会话 %s 掺杂AudioWater\n', m, datestr(firstDT,'yyyy-mm-dd'));
			continue;
		end
		
		% 获取 NTATS
		[uid, ntats] = iSessionNTATS(DS, m, firstDT);
		if isempty(uid) || size(ntats, 1) < 3
			fprintf('  跳过 %s（首会话 %s 细胞数不足: %d）\n', m, datestr(firstDT,'yyyy-mm-dd'), numel(uid));
			continue;
		end
		
		% 获取 trial-level 数据（用于 Divergence）
		trials = iSessionTrials(DS, m, firstDT);
		
		% Cell layer lookup
		cellLayer = iCellLayerLookup(C, m);
		
		% 计算所有特征
		fv = nan(1, nFeat);
		col = 0;
		for iTP = 1:nTP
			idx = idxTP(iTP);
			if ~isfinite(idx)
				col = col + 4*nLayers;
				continue;
			end
			for iL = 1:nLayers
				lFilt = layerFilters{iL};
				[~, ia] = iLayerCells(uid, cellLayer, lFilt);
				
				sd  = iInterCellSD(ntats, ia, idx);
				af  = iActiveFrac(ntats, ia, baseMask, idx, kSigma);
				mn  = iMeanNTATS(ntats, ia, idx);
				div = iDivergence(trials, uid, cellLayer, lFilt, idx);
				
				fv(col+1) = sd;
				fv(col+2) = af;
				fv(col+3) = mn;
				fv(col+4) = div;
				col = col + 4;
			end
		end
		
		% nCells per layer
		for iL = 1:nLayers
			[~, ia] = iLayerCells(uid, cellLayer, layerFilters{iL});
			fv(col+1) = numel(ia);
			col = col + 1;
		end
		
		% Baseline SD
		for iL = 1:nLayers
			[~, ia] = iLayerCells(uid, cellLayer, layerFilters{iL});
			if numel(ia) >= 3
				baseVals = ntats(ia, baseMask);
				fv(col+1) = mean(std(baseVals, 0, 1, 'omitnan'), 'omitnan');
			end
			col = col + 1;
		end
		
		% SD slope and Mean slope (1.0s vs 0.3s)
		idxFirst = idxTP(1); % 0.3s
		idxLast  = idxTP(end); % 1.0s
		for iL = 1:nLayers
			[~, ia] = iLayerCells(uid, cellLayer, layerFilters{iL});
			if numel(ia) >= 3 && isfinite(idxFirst) && isfinite(idxLast)
				sd1 = std(double(ntats(ia, idxFirst)), 0, 1, 'omitnan');
				sd2 = std(double(ntats(ia, idxLast)),  0, 1, 'omitnan');
				fv(col+1) = sd2 - sd1;
				mn1 = mean(double(ntats(ia, idxFirst)), 'omitnan');
				mn2 = mean(double(ntats(ia, idxLast)),  'omitnan');
				fv(col+2) = mn2 - mn1;
			end
			col = col + 2;
		end
		
		mice(end+1) = m; %#ok<AGROW>
		hitRates(end+1) = firstPerf; %#ok<AGROW>
		feats(end+1, :) = fv; %#ok<AGROW>
		nCellsAll(end+1) = numel(uid); %#ok<AGROW>
		
		fprintf('  %s: DT=%s, hit=%.3f, nCells=%d\n', m, datestr(firstDT,'yyyy-mm-dd'), firstPerf, numel(uid));
	end
	
	mice = mice(:);
	hitRates = hitRates(:);
end

function [rho, p, n] = iSpearmanSweep(feats, hitRates, featureNames)
	nF = size(feats, 2);
	rho = nan(nF, 1); p = nan(nF, 1); n = nan(nF, 1);
	for iF = 1:nF
		x = feats(:, iF);
		y = hitRates;
		mask = isfinite(x) & isfinite(y);
		n(iF) = nnz(mask);
		if n(iF) >= 5 && std(x(mask)) > 0 && std(y(mask)) > 0
			[rho(iF), p(iF)] = corr(x(mask), y(mask), 'Type', 'Spearman');
		end
	end
	% 打印 top-10 按 p 排序
	tbl = table(string(featureNames)', n, rho, p, 'VariableNames', {'Feature','n','rho','p'});
	tbl = sortrows(tbl, 'p');
	fprintf('%-38s %5s %8s %8s\n', 'Feature', 'n', 'rho', 'p');
	fprintf('%s\n', repmat('-', 1, 65));
	for iR = 1:min(15, height(tbl))
		if isnan(tbl.p(iR)), continue; end
		sig = "";
		if tbl.p(iR) < 0.001, sig = "***";
		elseif tbl.p(iR) < 0.01, sig = "**";
		elseif tbl.p(iR) < 0.05, sig = "*";
		elseif tbl.p(iR) < 0.1, sig = ".";
		end
		fprintf('%-38s %5d %+8.3f %8.4f %s\n', tbl.Feature(iR), tbl.n(iR), tbl.rho(iR), tbl.p(iR), sig);
	end
end

function [pRS, dir, medT, medN] = iRankSumSweep(transFeats, naiveFeats, featureNames)
	nF = size(transFeats, 2);
	pRS = nan(nF, 1); dir = zeros(nF, 1); medT = nan(nF, 1); medN = nan(nF, 1);
	for iF = 1:nF
		xT = transFeats(:, iF);
		xN = naiveFeats(:, iF);
		xT = xT(isfinite(xT));
		xN = xN(isfinite(xN));
		if numel(xT) >= 3 && numel(xN) >= 3
			pRS(iF) = ranksum(xT, xN);
			medT(iF) = median(xT);
			medN(iF) = median(xN);
			dir(iF) = sign(medT(iF) - medN(iF));
		end
	end
end

function iPrintTopN(featureNames, rho, p, N)
	[~, ord] = sort(p);
	fprintf('%-38s %8s %8s\n', 'Feature', 'rho', 'p');
	fprintf('%s\n', repmat('-', 1, 58));
	cnt = 0;
	for ii = 1:numel(ord)
		iF = ord(ii);
		if isnan(p(iF)), continue; end
		cnt = cnt + 1; if cnt > N, break; end
		sig = "";
		if p(iF) < 0.001, sig = "***";
		elseif p(iF) < 0.01, sig = "**";
		elseif p(iF) < 0.05, sig = "*";
		elseif p(iF) < 0.1, sig = ".";
		end
		fprintf('%-38s %+8.3f %8.4f %s\n', featureNames{iF}, rho(iF), p(iF), sig);
	end
end

function iPrintTopN_RS(featureNames, pRS, medT, medN, dir, N)
	[~, ord] = sort(pRS);
	fprintf('%-38s %8s %8s %8s %4s\n', 'Feature', 'pRS', 'medT', 'medN', 'dir');
	fprintf('%s\n', repmat('-', 1, 65));
	cnt = 0;
	for ii = 1:numel(ord)
		iF = ord(ii);
		if isnan(pRS(iF)), continue; end
		cnt = cnt + 1; if cnt > N, break; end
		sig = "";
		if pRS(iF) < 0.001, sig = "***";
		elseif pRS(iF) < 0.01, sig = "**";
		elseif pRS(iF) < 0.05, sig = "*";
		elseif pRS(iF) < 0.1, sig = ".";
		end
		fprintf('%-38s %8.4f %8.3f %8.3f %+d %s\n', featureNames{iF}, pRS(iF), medT(iF), medN(iF), dir(iF), sig);
	end
end

% [已移除 iFindPureNaiveMice / iFindBadMiceLAI / iHasStimulus]
% AW 排除逻辑已整合进 iExtractFirstSession：仅排除首个 LW 会话掺杂 AW 的鼠

function [uid, ntats] = iSessionNTATS(DS, mouse, dt)
	q = struct('Mouse', char(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	uid = uint64.empty(0,1); ntats = [];
	if isempty(ntsCell) || isempty(ntsCell{1}), return; end
	nts = ntsCell{1};
	if ~istable(nts) || height(nts)==0, return; end
	if ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames))), return; end
	uid = unique(uint64(nts.CellUID));
	nT = size(nts.TrialSignal, 2);
	ntats = nan(numel(uid), nT);
	for iC = 1:numel(uid)
		rows = uint64(nts.CellUID) == uid(iC);
		if nnz(rows)<1, continue; end
		ntats(iC,:) = median(double(nts.TrialSignal(rows,:)), 1, 'omitnan');
	end
end

function nts = iSessionTrials(DS, mouse, dt)
	q = struct('Mouse', char(mouse), 'DateTime', dt, 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	nts = [];
	if isempty(ntsCell) || isempty(ntsCell{1}), return; end
	nts = ntsCell{1};
	if ~istable(nts) || height(nts)==0, nts = []; end
end

function cellLayer = iCellLayerLookup(C, mouse)
	idx = C.Mouse == string(mouse);
	cellLayer = containers.Map('KeyType','uint64','ValueType','char');
	uids = uint64(C.CellUID(idx)); zls = string(C.ZLayer(idx));
	for i = 1:numel(uids), cellLayer(uids(i)) = char(zls(i)); end
end

function [uids, idx] = iLayerCells(allUID, cellLayer, layerFilter)
	zl = strings(numel(allUID), 1);
	for i = 1:numel(allUID)
		if cellLayer.isKey(allUID(i)), zl(i) = string(cellLayer(allUID(i))); end
	end
	keep = layerFilter(zl); uids = allUID(keep); idx = find(keep);
end

function sd = iInterCellSD(ntats, idx, idxTP)
	sd = NaN; if isempty(idx) || numel(idx) < 3, return; end
	v = double(ntats(idx, idxTP));
	v = v(isfinite(v));
	if numel(v)<3, return; end
	sd = std(v, 0, 1);
end

function af = iActiveFrac(ntats, idx, baseMask, idxTP, kSigma)
	af = NaN; if isempty(idx), return; end
	base = ntats(idx, baseMask);
	thr = mean(base, 2, 'omitnan') + kSigma * std(base, 0, 2, 'omitnan');
	act = ntats(idx, idxTP) > thr;
	af = mean(double(act), 'omitnan');
end

function mn = iMeanNTATS(ntats, idx, idxTP)
	mn = NaN; if isempty(idx), return; end
	mn = mean(double(ntats(idx, idxTP)), 'omitnan');
end

function div = iDivergence(nts, uidAll, cellLayer, layerFilter, idxTP)
	div = NaN;
	if isempty(nts), return; end
	
	[layerUID, ~] = iLayerCells(uidAll, cellLayer, layerFilter);
	if numel(layerUID) < 3, return; end
	
	varSum = 0; meanSqSum = 0; nCounted = 0;
	for iC = 1:numel(layerUID)
		rows = uint64(nts.CellUID) == layerUID(iC);
		if nnz(rows) < 2, continue; end
		vals = double(nts.TrialSignal(rows, idxTP));
		vals = vals(isfinite(vals));
		if numel(vals) < 2, continue; end
		varSum = varSum + var(vals);
		meanSqSum = meanSqSum + mean(vals)^2;
		nCounted = nCounted + 1;
	end
	if nCounted < 3 || meanSqSum == 0, return; end
	div = sqrt(varSum) / sqrt(meanSqSum);
end

function X = iNtatsData(ntatsCol)
	if isa(ntatsCol, 'MATLAB.DataTypes.NDTable')
		X = squeeze(ntatsCol.Data);
	elseif iscell(ntatsCol)
		X = cell2mat(cellfun(@(x) double(x(:)'), ntatsCol, 'UniformOutput', false));
	else
		X = double(ntatsCol);
	end
end

function feats_noAW = iRecomputeWithoutAW( ...
		DS, mice, C, learnedUID, learnedNTATS, ...
		featureNames, idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers)
	% 去除 AW 活跃细胞后重新计算首会话特征
	nFeat = numel(featureNames);
	nMice = numel(mice);
	feats_noAW = nan(nMice, nFeat);
	
	% AW 活跃细胞判定（ @1.0s 的 NTATS > baseline + 3σ）
	xsSec = seconds(TransferLearning.Xs);
	bm = (xsSec >= -3) & (xsSec < 0);
	[~, idx1s] = min(abs(xsSec - 1.0));
	
	for iM = 1:nMice
		m = mice(iM);
		
		% 该鼠的 Learned AW 细胞(活跃的)
		mouseMask = ismember(learnedUID, uint64(C.CellUID(C.Mouse == m)));
		awUID = learnedUID(mouseMask);
		awNT  = learnedNTATS(mouseMask, :);
		if isempty(awUID), continue; end
		
		awBase = awNT(:, bm);
		awThr = mean(awBase, 2, 'omitnan') + kSigma * std(awBase, 0, 2, 'omitnan');
		awActive = awNT(:, idx1s) > awThr;
		awActiveUID = awUID(awActive);
		
		% 获取 LW 首会话的数据（从已提取的信息中需要重新获取）
		T = DS.TableQuery(["Mouse","BlockUID","DateTime","Phase"], Phase="Transfer", Mouse=char(m));
		if isempty(T), continue; end
		dts = unique(T.DateTime);
		
		% 找首个纯净 LW 会话
		Tr = DS.Trials;
		firstDT = datetime.empty;
		for iDT = 1:numel(dts)
			buThis = uint64(T.BlockUID(T.DateTime == dts(iDT)));
			hasAW = false;
			for iBu = 1:numel(buThis)
				trB = Tr(uint64(Tr.BlockUID) == buThis(iBu), :);
				if any(string(trB.Stimulus) == "AudioWater"), hasAW=true; break; end
			end
			if hasAW, continue; end
			if isempty(firstDT) || dts(iDT) < firstDT
				firstDT = dts(iDT);
			end
		end
		if isempty(firstDT), continue; end
		
		[uid, ntats] = iSessionNTATS(DS, m, firstDT);
		if isempty(uid), continue; end
		
		% 去除 AW 活跃细胞
		keepMask = ~ismember(uid, awActiveUID);
		uid_clean = uid(keepMask);
		ntats_clean = ntats(keepMask, :);
		if numel(uid_clean) < 3, continue; end
		
		% 获取 trial-level（也需要去除 AW 活跃细胞）
		trials = iSessionTrials(DS, m, firstDT);
		if ~isempty(trials)
			trKeep = ~ismember(uint64(trials.CellUID), awActiveUID);
			trials = trials(trKeep, :);
		end
		
		cellLayer = iCellLayerLookup(C, m);
		
		% 重新计算所有特征
		col = 0;
		for iTP = 1:nTP
			idx = idxTP(iTP);
			if ~isfinite(idx)
				col = col + 4*nLayers;
				continue;
			end
			for iL = 1:nLayers
				lFilt = layerFilters{iL};
				[~, ia] = iLayerCells(uid_clean, cellLayer, lFilt);
				
				sd  = iInterCellSD(ntats_clean, ia, idx);
				af  = iActiveFrac(ntats_clean, ia, baseMask, idx, kSigma);
				mn  = iMeanNTATS(ntats_clean, ia, idx);
				div = iDivergence(trials, uid_clean, cellLayer, lFilt, idx);
				
				feats_noAW(iM, col+1) = sd;
				feats_noAW(iM, col+2) = af;
				feats_noAW(iM, col+3) = mn;
				feats_noAW(iM, col+4) = div;
				col = col + 4;
			end
		end
		
		% nCells
		for iL = 1:nLayers
			[~, ia] = iLayerCells(uid_clean, cellLayer, layerFilters{iL});
			feats_noAW(iM, col+1) = numel(ia);
			col = col + 1;
		end
		
		% Baseline SD
		for iL = 1:nLayers
			[~, ia] = iLayerCells(uid_clean, cellLayer, layerFilters{iL});
			if numel(ia) >= 3
				baseVals = ntats_clean(ia, baseMask);
				feats_noAW(iM, col+1) = mean(std(baseVals, 0, 1, 'omitnan'), 'omitnan');
			end
			col = col + 1;
		end
		
		% SD slope and Mean slope
		idxFirst = idxTP(1); idxLast = idxTP(end);
		for iL = 1:nLayers
			[~, ia] = iLayerCells(uid_clean, cellLayer, layerFilters{iL});
			if numel(ia) >= 3 && isfinite(idxFirst) && isfinite(idxLast)
				sd1 = std(double(ntats_clean(ia, idxFirst)), 0, 1, 'omitnan');
				sd2 = std(double(ntats_clean(ia, idxLast)),  0, 1, 'omitnan');
				feats_noAW(iM, col+1) = sd2 - sd1;
				mn1 = mean(double(ntats_clean(ia, idxFirst)), 'omitnan');
				mn2 = mean(double(ntats_clean(ia, idxLast)),  'omitnan');
				feats_noAW(iM, col+2) = mn2 - mn1;
			end
			col = col + 2;
		end
		
		fprintf('  消融 %s: kept %d/%d cells (removed %d AW-active)\n', ...
			m, numel(uid_clean), numel(uid), nnz(~keepMask));
	end
end

function awFeats = iComputeAllAWFeatures(DS, mice, C, learnedUID, learnedNTATS, ...
		featureNames, idxTP, timePoints, baseMask, layerFilters, layerNames, kSigma, nTP, nLayers)
	% 计算 Transfer 鼠在 AW Learned 阶段的全部特征（用于 Test D 多指标扫描）
	nFeat = numel(featureNames);
	nMice = numel(mice);
	awFeats = nan(nMice, nFeat);
	
	xsSec = seconds(TransferLearning.Xs);
	bm = (xsSec >= -3) & (xsSec < 0);
	
	for iM = 1:nMice
		m = mice(iM);
		mouseMask = ismember(learnedUID, uint64(C.CellUID(C.Mouse == m)));
		mUID = learnedUID(mouseMask);
		mNTATS = learnedNTATS(mouseMask, :);
		if numel(mUID) < 3, continue; end
		
		% 获取 trial-level 数据（用于 Divergence）
		q = struct('Mouse', char(m), 'Stimulus', 'AudioWater', 'Phase', 'Learned');
		ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
		trials = [];
		if ~isempty(ntsCell) && ~isempty(ntsCell{1})
			nts = ntsCell{1};
			if istable(nts) && height(nts) > 0, trials = nts; end
		end
		
		cellLayer = iCellLayerLookup(C, m);
		
		% 与 iExtractFirstSession 相同的特征计算逻辑
		col = 0;
		for iTP = 1:nTP
			idx = idxTP(iTP);
			if ~isfinite(idx)
				col = col + 4*nLayers;
				continue;
			end
			for iL = 1:nLayers
				lFilt = layerFilters{iL};
				[~, ia] = iLayerCells(mUID, cellLayer, lFilt);
				
				awFeats(iM, col+1) = iInterCellSD(mNTATS, ia, idx);
				awFeats(iM, col+2) = iActiveFrac(mNTATS, ia, bm, idx, kSigma);
				awFeats(iM, col+3) = iMeanNTATS(mNTATS, ia, idx);
				awFeats(iM, col+4) = iDivergence(trials, mUID, cellLayer, lFilt, idx);
				col = col + 4;
			end
		end
		
		% nCells per layer
		for iL = 1:nLayers
			[~, ia] = iLayerCells(mUID, cellLayer, layerFilters{iL});
			awFeats(iM, col+1) = numel(ia);
			col = col + 1;
		end
		
		% Baseline SD
		for iL = 1:nLayers
			[~, ia] = iLayerCells(mUID, cellLayer, layerFilters{iL});
			if numel(ia) >= 3
				baseVals = mNTATS(ia, bm);
				awFeats(iM, col+1) = mean(std(baseVals, 0, 1, 'omitnan'), 'omitnan');
			end
			col = col + 1;
		end
		
		% SD slope and Mean slope
		idxFirst = idxTP(1); idxLast = idxTP(end);
		for iL = 1:nLayers
			[~, ia] = iLayerCells(mUID, cellLayer, layerFilters{iL});
			if numel(ia) >= 3 && isfinite(idxFirst) && isfinite(idxLast)
				sd1 = std(double(mNTATS(ia, idxFirst)), 0, 1, 'omitnan');
				sd2 = std(double(mNTATS(ia, idxLast)),  0, 1, 'omitnan');
				awFeats(iM, col+1) = sd2 - sd1;
				mn1 = mean(double(mNTATS(ia, idxFirst)), 'omitnan');
				mn2 = mean(double(mNTATS(ia, idxLast)),  'omitnan');
				awFeats(iM, col+2) = mn2 - mn1;
			end
			col = col + 2;
		end
		
		fprintf('  AW特征 %s: %d cells, %d features computed\n', m, numel(mUID), nnz(isfinite(awFeats(iM,:))));
	end
end
