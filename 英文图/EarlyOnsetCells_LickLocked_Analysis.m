%% EarlyOnsetCells_LickLocked_Analysis.m
% 仿 Nature 2026 (s41586-026-11174-3) "early-onset neuron" 定义，在 ALDelayed
% （有延迟不舔不给水钙成像，声水转光水，延迟任务）中寻找舔水(movement)前激活的细胞。
%
% 文献口径（Methods 原文核对）：
%   - 活动信号：Suite2p 反卷积的估计 spike（"estimated spike activity used for all neural
%     activity analyses"）。本工程无 spike 反卷积工具，改用项目标准 ΔF/F（cue 前基线 ZScore）替代，
%     钙上升沿滞后/拖尾会使 early-onset 略被低估，结论需注明该偏差。
%   - movement onset：文献为 lever 前推速度首次 >41.7 mm/s；我们等价为"孤立舔水 bout 起点"，
%     即 CD2 上升沿越过基线阈、且其前 isoWindow(=1 s) 内无任何舔水（对应文献"前 1 s 无其他
%     movement 以污染"）。CD2=精确舔水时点，CD1=线索(cue)时点。
%   - activity onset：仅用孤立 movement 的"跨 movement 平均"活动(PSTH)；onset = 在
%     [movement 前 0.2 s, movement 结束] 内，活动首次高于 baseline([−1,−0.5] s 均值) 达
%     ≥1 SD 且持续 200 ms 的帧。
%   - early-onset = movement-active 且 onset < 0；late-onset = onset ≥ 0。
%   - 文献报告：early 12.1±1.5%、late 15.9±0.9%（占每 session 全部神经元）。
%
% 数据对齐：原生分辨率以 DS.DateTimes.SeriesInterval 为准，按 block 自适应
% （yqn2200/2202=93样@15.20Hz、cue@样47；yqn2201/2203=49样@7.95Hz、cue@样25）；
% TrialTags 原生 CD1/CD2 与神经信号同采样。
% lick 检测、ΔF/F、PSTH 全部在原生分辨率完成（fs/nSm/cueIdx 按块推导）。
% SD 阈值口径经敏感性检验（PSTH 自身基线SD / 单trial基线SD / 固定1SD），取"单trial基线SD"
% 最贴合文献（block15: early 8.1%、late 23.4%，接近文献 12.1%/15.9%）。
%
% Output（缓存，经 TransferLearning.CachePath，不入 git）：
%   EarlyOnsetCells_LickLocked_Results.mat
%     .S          每 session 汇总表(Mouse,DateTime,BlockUID,Stimulus,nC,nMvt,nEarly,nLate,...)
%     .PerBlock   每 block 的 PSTH/onsetT/label/cellUID（供作图）
%     .P          参数
%
% Execution:
% - Keep as a script. Open in MATLAB Editor and Run/F5.

%% ---- 参数 ----
thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

P = struct();
P.minNSm     = 40;              % 每 trial 原生样本数下限（93@15.2Hz 或 49@8Hz；剔除 nSm=1 坏样）
P.isoWindow  = 1.0;             % 孤立 movement：此窗内不得有其他舔水（文献=1 s）
P.lickMargin = 35;              % CD2 舔水阈 = 每trial稳健基线 + 此值
P.tPwin      = [-1.5, 2.0];     % PSTH 相对 lick 的时间窗（s）
P.baseline   = [-1.0, -0.5];    % 基线窗（文献）
P.detWin     = [-0.2, 1.5];     % onset 搜索窗（文献：movement 前 0.2 s → movement 结束）
P.sustain    = 0.2;             % 持续判据（文献 200 ms）
P.sdScheme   = 'singleTrial';   % 见文件头敏感性检验
P.minTrials  = 10;              % block 最少可用 trial 数

DS = TransferLearning.ALDelayed();
warning('off', 'UniExp:Exception:Block_must_warn');
Tr = DS.Trials; Tr.Stimulus = string(Tr.Stimulus);
sr = Tr.SampleRange;
Sd = double(sr.Start); Ed = double(sr.End); Td = double(sr.Tag);
bs = DS.BlockSignals;

% learn-water block 列表（每鼠每天一个），按学习顺序（Mouse,DateTime）
T = DS.TableQuery(["Mouse","DateTime","BlockUID","Stimulus"]);
T.Mouse = string(T.Mouse); T.Stimulus = string(T.Stimulus); T.DateTime = datetime(T.DateTime);
lw = T(ismember(T.Stimulus, ["AudioLearnWater","LightLearnWater"]), :);
blk = unique(lw(:, ["Mouse","DateTime","BlockUID","Stimulus"]), 'stable');
blk = sortrows(blk, ["Mouse","DateTime"]);

% 原生帧率以 DS.DateTimes.SeriesInterval（真实采集间隔）为准：
% yqn2200/2202=0.065779s(15.20Hz,93样,cue@47)；yqn2201/2203=0.125729s(7.95Hz,49样,cue@25)。
% SeriesInterval=NaN 的两个 session 恰为坏块 28/29（nSm=1，本已剔除）；block6 同样 nSm=1 作废，
% block7 蓝屏混合样本数。样本数/cue 位按 block 众数自适应。
SIall = seconds(DS.DateTimes.SeriesInterval);
DTall = DS.DateTimes.DateTime;
if ~isempty(DTall.TimeZone), DTall.TimeZone = ''; end
MallSess = string(DS.DateTimes.Mouse);

%% ---- 遍历 block ----
S = table();
emptyBlk = struct('BlockUID',[],'Mouse',[],'DateTime',[],'Stimulus',[],'tP',[],'fs',[], ...
	'nSmB',[],'cueIdxB',[],'PSTH',[],'PSTHsem',[],'baseMean',[],'baseSD',[],'tFine',[],'onsetT',[],'onsetAmp',[], ...
	'isEarly',[],'isLate',[],'hasOnset',[],'cellUID',[],'nMvt',[]);
PerBlock = repmat(emptyBlk, 0, 1);
biOut = 0;
for bi = 1:height(blk)
	buid = blk.BlockUID(bi);
	selT0 = find(Tr.BlockUID == buid & ismember(Tr.Stimulus, ["AudioLearnWater","LightLearnWater"]));
	nSmT = Ed(selT0) - Sd(selT0) + 1;
	selT = selT0(nSmT >= P.minNSm);          % 剔除坏样(nSm=1)
	if numel(selT) < P.minTrials
		warning('EarlyOnset:SkipBlock', 'block %d 可用 trial=%d 过少，跳过', buid, numel(selT));
		continue;
	end
	% ---- per-block 自适应：本块原生帧率/样本数/cue 位 ----
	nSmT = Ed(selT) - Sd(selT) + 1;
	nSmB = mode(nSmT);                        % 93 或 49
	keep = nSmT == nSmB;                      % 只取样本数一致的 trial（block7 蓝屏混合）
	selT = selT(keep); nTr = numel(selT);
	if nTr < P.minTrials
		warning('EarlyOnset:SkipBlock', 'block %d 一致样本 trial=%d 过少，跳过', buid, nTr);
		continue;
	end
	cueIdxB = mode(Td(selT) - Sd(selT) + 1);  % 47 或 25
	% 真实采样间隔：按 session(Mouse,DateTime) 从 DateTimes.SeriesInterval 匹配（容差 60 s）
	rSI = find(MallSess == blk.Mouse(bi) & abs(seconds(DTall - blk.DateTime(bi))) < 60, 1);
	if isempty(rSI) || ~isfinite(SIall(rSI)) || SIall(rSI) <= 0
		warning('EarlyOnset:NoInterval', 'block %d (%s) 无有效 SeriesInterval，跳过', buid, blk.Mouse(bi));
		continue;
	end
	fs = 1 / SIall(rSI);                       % 15.20 或 7.95 Hz（SeriesInterval 为准）
	tAx1 = ((0:nSmB-1)' / fs) - (cueIdxB-1) / fs;   % cue@t=0，nSmB x 1
	tP = (P.tPwin(1) : 1/fs : P.tPwin(2))';          % lick 锁定网格（列）
	nTP = numel(tP);
	preMask = tAx1 < -0.02;                           % cue 前基线样本
	bmask = (tP >= P.baseline(1) & tP <= P.baseline(2))';
	Starts = Sd(selT); IDX = Starts + (0:nSmB-1);   % nTr x nSmB 原生样本索引

	% ---- 原生 CD2 检测孤立舔水 bout 起点 ----
	lickT = nan(nTr, 1); isoOk = false(nTr, 1);
	for j = 1:nTr
		cd2 = double(Tr.TrialTags{selT(j)}.CD2); cd2 = cd2(:)';
		low = cd2(cd2 < prctile(cd2, 60)); thr = median(low) + P.lickMargin;
		licking = cd2 > thr;
		rise = licking & ~[false, licking(1:end-1)];
		cand = find(rise); cand = cand(tAx1(cand) >= -0.1);   % cue 之后的上升沿
		for p = cand
			pre = max(1, p-round(P.isoWindow*fs)) : p-1;
			if ~any(licking(pre)), lickT(j) = tAx1(p); isoOk(j) = true; break; end
		end
		if ~isoOk(j) && ~isempty(cand), lickT(j) = tAx1(cand(1)); end
	end
	isoTr = find(isoOk); nIso = numel(isoTr);

	% ---- 预计算插值权重（相对 lick）----
	loArr = zeros(nIso, nTP); fracArr = zeros(nIso, nTP); validArr = false(nIso, nTP);
	for jj = 1:nIso
		q = tP + lickT(isoTr(jj));
		pIdx = q * fs + cueIdxB; lo = floor(pIdx); fr = pIdx - lo;
		va = lo >= 1 & (lo+1) <= nSmB;
		loArr(jj,:) = min(max(lo,1), nSmB-1)'; fracArr(jj,:) = fr'; validArr(jj,:) = va';
	end

	% ---- per-cell ΔF/F(precue ZScore) → lick-PSTH → onset ----
	ub = bs(bs.BlockUID == buid, :); nC = height(ub);
	cellUID = uint64(ub.CellUID);
	PSTH = nan(nC, nTP); PSTHsem = nan(nC, nTP); baseMean = nan(nC,1); baseSD = nan(nC,1);
	for c = 1:nC
		sig = double(ub.BlockSignal{c});
		raw = sig(IDX');                       % nSmB x nTr
		b = mean(raw(preMask,:), 1); s = std(raw(preMask,:), 0, 1); s(s==0) = nan;
		Zc = ((raw - b) ./ s)';                % nTr x nSmB  (cue 前基线 ZScore)
		if nIso == 0, continue; end
		V = nan(nIso, nTP);
		for jj = 1:nIso
			j = isoTr(jj); lo = loArr(jj,:); fr = fracArr(jj,:);
			vv = Zc(j, lo).*(1-fr) + Zc(j, lo+1).*fr;
			vv(~validArr(jj,:)) = nan; V(jj,:) = vv;
		end
		PSTH(c,:)   = mean(V, 1, 'omitnan');
		nv = sum(isfinite(V), 1);
		PSTHsem(c,:) = std(V, 0, 1, 'omitnan') ./ sqrt(max(nv, 1));
		baseMean(c) = mean(PSTH(c, bmask'), 'omitnan');
		if strcmp(P.sdScheme, 'singleTrial')
			baseSD(c) = mean(std(V(:, bmask), 0, 2, 'omitnan'), 'omitnan');
		else % 'psth'
			baseSD(c) = std(PSTH(c, bmask'), 0, 2, 'omitnan');
		end
	end
	onsetT = nan(nC,1); onsetAmp = nan(nC,1);
	% onset 检测在"上采样后的平滑 PSTH"上做：跨 movement 平均的 PSTH 足够平滑，
	% 上采样到 dtFine 后 onset 时刻可连续估计，消除 8/15.3Hz 原生网格在
	% [-0.2,0) 早发窄窗(仅~1.6~3 样本)处 early/late 划分对采样相位的脆弱依赖。
	dtFine = 0.005;                              % 200 Hz
	tFine = (P.detWin(1) : dtFine : P.detWin(2))';
	nSusFine = max(2, round(P.sustain / dtFine)); % 200 ms = 40 样本
	maxStartFine = numel(tFine) - nSusFine + 1;
	psthFine = nan(nC, numel(tFine));
	for c = 1:nC
		tr = PSTH(c,:); ok = isfinite(tr);
		if sum(ok) < 2, continue; end
		psthFine(c,:) = interp1(tP(ok), tr(ok), tFine, 'linear', nan)';
	end
	for c = 1:nC
		trF = psthFine(c,:); thr = baseMean(c) + baseSD(c);
		if ~isfinite(thr), continue; end
		for i = 1:maxStartFine
			seg = trF(i:i+nSusFine-1);
			if all(isfinite(seg)) && all(seg > thr)
				onsetT(c) = tFine(i);
				onsetAmp(c) = max(trF, [], 'omitnan') - baseMean(c);
				break;
			end
		end
	end
	hasOnset = isfinite(onsetT);
	isEarly  = hasOnset & onsetT < 0;
	isLate   = hasOnset & onsetT >= 0;

	S = [S; table(blk.Mouse(bi), blk.DateTime(bi), buid, blk.Stimulus(bi), fs, nSmB, nC, nTr, nIso, ...
		sum(hasOnset), sum(isEarly), sum(isLate), 100*sum(isEarly)/nC, 100*sum(isLate)/nC, ...
		100*sum(isEarly)/max(1,sum(isEarly)+sum(isLate)), ...
		'VariableNames', {'Mouse','DateTime','BlockUID','Stimulus','fs','nSmB','nC','nTrial','nMvt', ...
		'nMvtActive','nEarly','nLate','EarlyPctAll','LatePctAll','EarlyPctOfActive'})]; %#ok<AGROW>

	biOut = biOut + 1;
	PerBlock(biOut).BlockUID = buid; %#ok<AGROW,SAGROW>
	PerBlock(biOut).Mouse = blk.Mouse(bi);
	PerBlock(biOut).DateTime = blk.DateTime(bi);
	PerBlock(biOut).Stimulus = blk.Stimulus(bi);
	PerBlock(biOut).tP = tP;
	PerBlock(biOut).fs = fs;
	PerBlock(biOut).nSmB = nSmB;
	PerBlock(biOut).cueIdxB = cueIdxB;
	PerBlock(biOut).PSTH = PSTH;
	PerBlock(biOut).PSTHsem = PSTHsem;
	PerBlock(biOut).baseMean = baseMean;
	PerBlock(biOut).baseSD = baseSD;
	PerBlock(biOut).tFine = tFine;
	PerBlock(biOut).onsetT = onsetT;
	PerBlock(biOut).onsetAmp = onsetAmp;
	PerBlock(biOut).isEarly = isEarly;
	PerBlock(biOut).isLate = isLate;
	PerBlock(biOut).hasOnset = hasOnset;
	PerBlock(biOut).cellUID = cellUID;
	PerBlock(biOut).nMvt = nIso;

	fprintf('blk%-3d %s %-16s fs=%.1f nSm=%d nC=%3d nMvt=%2d | mvtActive=%3d early=%3d(%.1f%%) late=%3d(%.1f%%)\n', ...
		buid, blk.Mouse(bi), string(blk.Stimulus(bi)), fs, nSmB, nC, nIso, sum(hasOnset), ...
		sum(isEarly), 100*sum(isEarly)/nC, sum(isLate), 100*sum(isLate)/nC);
end

%% ---- 汇总 ----
fprintf('\n===== 全库汇总（%d sessions）=====\n', height(S));
fprintf('early-onset %%: mean=%.1f  median=%.1f  SEM=%.1f  (文献 12.1±1.5%%)\n', ...
	mean(S.EarlyPctAll), median(S.EarlyPctAll), std(S.EarlyPctAll)/sqrt(height(S)));
fprintf('late-onset  %%: mean=%.1f  SEM=%.1f  (文献 15.9±0.9%%)\n', ...
	mean(S.LatePctAll), std(S.LatePctAll)/sqrt(height(S)));
fprintf('nMvt (isolated movements) per session: min=%d median=%d max=%d\n', ...
	min(S.nMvt), median(S.nMvt), max(S.nMvt));

% 可靠子集（movement 数足够）
rel = S(S.nMvt >= 30, :);
fprintf('\n--- nMvt>=30 子集 (%d sessions) ---\n', height(rel));
fprintf('early %%: mean=%.1f±%.1f(SEM)  range[%.1f,%.1f]\n', ...
	mean(rel.EarlyPctAll), std(rel.EarlyPctAll)/sqrt(height(rel)), min(rel.EarlyPctAll), max(rel.EarlyPctAll));
fprintf('late  %%: mean=%.1f±%.1f(SEM)\n', mean(rel.LatePctAll), std(rel.LatePctAll)/sqrt(height(rel)));

% 按原生帧率分组（early-onset 检测分辨率依赖性强）
fprintf('\n--- nMvt>=30, 按原生帧率 ---\n');
hi = rel(rel.fs > 12, :); lo = rel(rel.fs <= 12, :);
if ~isempty(hi)
	fprintf('hi-res 15.2Hz (n=%d): early=%.1f±%.1f%%  late=%.1f±%.1f%%  mvtActive=%.1f%%\n', ...
		height(hi), mean(hi.EarlyPctAll), std(hi.EarlyPctAll)/sqrt(height(hi)), ...
		mean(hi.LatePctAll), std(hi.LatePctAll)/sqrt(height(hi)), 100*mean(hi.nMvtActive./hi.nC));
end
if ~isempty(lo)
	fprintf('lo-res 7.95Hz (n=%d): early=%.1f±%.1f%%  late=%.1f±%.1f%%  mvtActive=%.1f%%\n', ...
		height(lo), mean(lo.EarlyPctAll), std(lo.EarlyPctAll)/sqrt(height(lo)), ...
		mean(lo.LatePctAll), std(lo.LatePctAll)/sqrt(height(lo)), 100*mean(lo.nMvtActive./lo.nC));
end

% 分阶段（仅 hi-res 15.2Hz，避免分辨率混淆）：Audio(声水学习) vs Light(光水迁移/学会)
fprintf('\n--- 分阶段（hi-res 15.2Hz, nMvt>=30）---\n');
for stg = ["AudioLearnWater","LightLearnWater"]
	g = hi(ismember(hi.Stimulus, stg), :);
	if isempty(g), continue; end
	fprintf('%s: n=%d  early%%=%.1f±%.1f  late%%=%.1f±%.1f  mvtActive%%=%.1f\n', ...
		string(stg), height(g), mean(g.EarlyPctAll), std(g.EarlyPctAll)/sqrt(height(g)), ...
		mean(g.LatePctAll), std(g.LatePctAll)/sqrt(height(g)), 100*mean(g.nMvtActive./g.nC));
end

%% ---- 缓存 ----
matPath = TransferLearning.CachePath('EarlyOnsetCells_LickLocked_Results.mat');
save(matPath, 'S', 'PerBlock', 'P', '-v7.3');
fprintf('\n缓存已写入: %s\n', matPath);
assignin('base', 'EOS_S', S);
assignin('base', 'EOS_PerBlock', PerBlock);
