function R = EncodingGLMRunMouse(DS, m, Blocks, nTime, tIdx, nShuffle)
% 单鼠全程（AudioWater+LightWater）逐细胞逐时点三元编码 GLM。
% 每个 (cell,time) 拟合 r = b0 + b_cue*cue + b_beh*beh + b_perf*perf，
% 返回三张 beta/p 矩阵与显著性掩码。供 parfor 调用。
arguments
	DS (1,1)
	m (1,1) string
	Blocks table
	nTime (1,1) double
	tIdx double
	nShuffle (1,1) double
end
	R = [];
	raw = table();
	for stim = ["AudioWater","LightWater"]
		try
			rsp = DS.QueryNTS(struct('Mouse', m, 'Stimulus', stim), ...
				UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior","BlockUID","DateTime"]);
			if ~isempty(rsp) && ~isempty(rsp{1})
				tb = rsp{1};
				tb.Stimulus = repmat(stim, height(tb), 1);
				raw = [raw; tb]; %#ok<AGROW>
			end
		catch
		end
	end
	if isempty(raw) || ~ismember('TrialSignal', string(raw.Properties.VariableNames))
		return;
	end

	% trial-level predictors
	trialU = unique(raw.TrialUID);
	nTr = numel(trialU);
	beh = nan(nTr,1); cue = nan(nTr,1); blk = nan(nTr,1);
	for k = 1:nTr
		rows = raw(raw.TrialUID==trialU(k),:);
		beh(k) = mode(rows.Behavior);
		cue(k) = double(string(rows.Stimulus(1))=="AudioWater");
		blk(k) = rows.BlockUID(1);
	end
	perf = nan(nTr,1);
	[tf,loc] = ismember(blk, Blocks.BlockUID);
	perf(tf) = Blocks.Performance(loc(tf));

	keep = isfinite(beh) & isfinite(cue) & isfinite(perf);
	if sum(keep) < 20; return; end
	trialK = trialU(keep);
	beh = beh(keep); cue = cue(keep); perf = perf(keep); blk = blk(keep);

	% [nTrial x nCell x nTime] tensor
	cellU = uint64(unique(raw.CellUID));
	nC = numel(cellU);
	if nC < 5; return; end
	nTk = numel(trialK);
	X = nan(nTk, nC, nTime);
	for k = 1:nTk
		rows = raw(raw.TrialUID==trialK(k),:);
		[tf2,loc2] = ismember(uint64(rows.CellUID), cellU);
		sig = double(rows.TrialSignal(tf2,:));
		X(k, loc2(tf2), :) = permute(sig, [3 1 2]);
	end

	% 全部预测因子 z 标准化 → 标准化回归系数（无量纲，跨细胞/变量可比）
	cueZ = (cue - mean(cue)) ./ std(cue);
	behZ = (beh - mean(beh)) ./ std(beh);
	perfZ = (perf - mean(perf)) ./ std(perf);
	Xd = [cueZ, behZ, perfZ];
	Xw = X(:,:,tIdx);
	nT = numel(tIdx);

	betaCue  = nan(nC, nT); betaBeh = nan(nC, nT); betaPerf = nan(nC, nT);
	pCue = nan(nC,nT); pBeh = nan(nC,nT); pPerf = nan(nC,nT);
	for iC = 1:nC
		Y = squeeze(Xw(:,iC,:));
		for iT = 1:nT
			y = Y(:,iT);
			finite = isfinite(y);
			if sum(finite) < 10 || range(y(finite)) == 0; continue; end
			[b,~,st] = glmfit(Xd(finite,:), y(finite), 'normal');
			betaCue(iC,iT)  = b(2); pCue(iC,iT)  = st.p(2);
			betaBeh(iC,iT)  = b(3); pBeh(iC,iT)  = st.p(3);
			betaPerf(iC,iT) = b(4); pPerf(iC,iT) = st.p(4);
		end
	end

	% block-level permutation null for performance axis
	uniqBlk = unique(blk);
	nB = numel(uniqBlk);
	if nB >= 3
		nullmax = nan(nShuffle,1);
		for s = 1:nShuffle
			sp = perfZ(randperm(numel(perfZ)));
			Xs3 = [cueZ, behZ, sp];
			mx = 0;
			for iC = 1:min(nC, 20)
				y = squeeze(Xw(:,iC,:));
				for iT = 1:nT
					finite = isfinite(y(:,iT));
					yv = y(:,iT);
					if sum(finite)<10 || range(yv(finite))==0; continue; end
					b = glmfit(Xs3(finite,:), yv(finite), 'normal');
					mx = max(mx, abs(b(4)));
				end
			end
			nullmax(s) = mx;
		end
		thPerf = quantile(nullmax, 0.95);
	else
		thPerf = inf;
	end

	R = struct();
	R.Mouse = m;
	R.NCells = nC;
	R.NTrials = nTk;
	R.BetaCue = betaCue; R.BetaBeh = betaBeh; R.BetaPerf = betaPerf;
	R.SigCue = pCue < 0.05;
	R.SigBeh = pBeh < 0.05;
	R.SigPerf = abs(betaPerf) > thPerf;
end
