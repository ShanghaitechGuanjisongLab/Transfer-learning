% scratchFig3_SignalRetention.m
% 验证"信号保留"假说：AW学习是否在细胞层面留下痕迹，影响LW响应
%
% 分析内容：
% 1. 细胞级 Spearman(AW_response@1s, LW_response@1s)：信号方向保留
% 2. 细胞级 Spearman(|AW|, |LW|)：响应幅度/兴奋性保留
% 3. AW-active vs AW-inactive 的 mean LW response @1s（方向性）
% 4. AW-active vs AW-inactive 的 mean |LW response| @1s（幅度）
% 5. AW-active vs AW-inactive 的 mean NTATS 时间曲线（全时间轴，观察）
%
% Execution:
%   TransferLearning.英文图3.scratchFig3_SignalRetention

DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
[~, idx1s] = min(abs(xsSec - 1));
nTimepoints = numel(xsSec);

baseMask = 1:24;

% Get metadata
Blocks = DS.Blocks;
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = datetime(Blocks.DateTime);
if ~isempty(Blocks.DateTime.TimeZone), Blocks.DateTime.TimeZone = ''; end

DT = DS.DateTimes(:, {'DateTime','Mouse'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone), DT.DateTime.TimeZone = ''; end
DT.Mouse = string(DT.Mouse);

Trials = DS.Trials;
Trials.BlockUID = uint64(Trials.BlockUID);

mice = unique(DT.Mouse);
nMice = numel(mice);

% Results storage
rhoSigned = nan(nMice, 1);   % Spearman(AW, LW) signed
pSigned = nan(nMice, 1);
rhoAbs = nan(nMice, 1);      % Spearman(|AW|, |LW|) abs
pAbs = nan(nMice, 1);
nMatched = nan(nMice, 1);    % number of matched cells
nAW = nan(nMice, 1);         % total AW cells
nLW = nan(nMice, 1);         % total LW cells

meanLW_active = nan(nMice, 1);
meanLW_inactive = nan(nMice, 1);
meanAbsLW_active = nan(nMice, 1);
meanAbsLW_inactive = nan(nMice, 1);

% For time-course analysis: accumulate across mice
tcActive_all = [];   % nCells × nTimepoints
tcInactive_all = [];

for mi = 1:nMice
	m = mice(mi);
	mouseDTs = DT.DateTime(DT.Mouse == m);

	% ===== Find last AW and first LW sessions =====
	awTrials = Trials(string(Trials.Stimulus) == "AudioWater", :);
	awBlkDTs = innerjoin(awTrials(:,'BlockUID'), Blocks(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	awMouseDates = intersect(unique(awBlkDTs.DateTime), mouseDTs);
	if isempty(awMouseDates), continue; end
	lastAWdt = max(awMouseDates);

	lwTrials = Trials(string(Trials.Stimulus) == "LightWater", :);
	lwBlkDTs = innerjoin(lwTrials(:,'BlockUID'), Blocks(:,{'BlockUID','DateTime'}), 'Keys','BlockUID');
	lwMouseDates = intersect(unique(lwBlkDTs.DateTime), mouseDTs);
	if isempty(lwMouseDates), continue; end
	firstLWdt = min(lwMouseDates);

	% ===== Get per-cell response in last AW session =====
	qAW = struct('Stimulus', 'AudioWater', 'DateTime', lastAWdt);
	ntsAW = DS.QueryNTS(qAW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsAW) || isempty(ntsAW{1}), continue; end
	ntsAW = ntsAW{1};
	if ~istable(ntsAW) || height(ntsAW) == 0, continue; end

	awCells = unique(uint64(ntsAW.CellUID));
	medAW_1s = nan(numel(awCells), 1);
	for ic = 1:numel(awCells)
		rows = ntsAW(uint64(ntsAW.CellUID) == awCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medAW_1s(ic) = med(idx1s); end
	end
	nAW(mi) = numel(awCells);

	% ===== Get per-cell response in first LW session =====
	qLW = struct('Stimulus', 'LightWater', 'DateTime', firstLWdt);
	ntsLW = DS.QueryNTS(qLW, UniExp.Flags.ZScore, baseMask, 'ExtraColumns', ["CellUID"]);
	if isempty(ntsLW) || isempty(ntsLW{1}), continue; end
	ntsLW = ntsLW{1};
	if ~istable(ntsLW) || height(ntsLW) == 0, continue; end

	lwCells = unique(uint64(ntsLW.CellUID));
	medLW_1s = nan(numel(lwCells), 1);
	medLW_tc = nan(numel(lwCells), nTimepoints); % full time course
	for ic = 1:numel(lwCells)
		rows = ntsLW(uint64(ntsLW.CellUID) == lwCells(ic), :);
		med = median(double(rows.TrialSignal), 1, 'omitnan');
		if numel(med) >= idx1s, medLW_1s(ic) = med(idx1s); end
		if numel(med) == nTimepoints, medLW_tc(ic, :) = med; end
	end
	nLW(mi) = numel(lwCells);

	% ===== Match cells =====
	[sharedCells, idxAW, idxLW] = intersect(awCells, lwCells);
	valid = isfinite(medAW_1s(idxAW)) & isfinite(medLW_1s(idxLW));
	if sum(valid) < 5, continue; end

	awV = medAW_1s(idxAW(valid));
	lwV = medLW_1s(idxLW(valid));
	nMatched(mi) = numel(awV);

	% ===== Analysis 1: Spearman signed =====
	[rhoSigned(mi), pSigned(mi)] = corr(awV, lwV, 'Type', 'Spearman');

	% ===== Analysis 2: Spearman absolute =====
	[rhoAbs(mi), pAbs(mi)] = corr(abs(awV), abs(lwV), 'Type', 'Spearman');

	% ===== Analysis 3-4: AW-active vs AW-inactive split =====
	absAW = abs(awV);
	nHalf = ceil(numel(awV) / 2);
	[~, sortIdx] = sort(absAW, 'descend');
	activeIdx = sortIdx(1:nHalf);
	inactiveIdx = sortIdx(nHalf+1:end);

	meanLW_active(mi) = mean(lwV(activeIdx));
	meanLW_inactive(mi) = mean(lwV(inactiveIdx));
	meanAbsLW_active(mi) = mean(abs(lwV(activeIdx)));
	meanAbsLW_inactive(mi) = mean(abs(lwV(inactiveIdx)));

	% ===== Analysis 5: Time course for this mouse =====
	% Map active/inactive indices back to lwCells indices
	matchedLWIdx = idxLW(valid);
	activeLWIdx = matchedLWIdx(activeIdx);
	inactiveLWIdx = matchedLWIdx(inactiveIdx);

	validTC_a = all(isfinite(medLW_tc(activeLWIdx, :)), 2);
	validTC_i = all(isfinite(medLW_tc(inactiveLWIdx, :)), 2);
	tcActive_all = [tcActive_all; medLW_tc(activeLWIdx(validTC_a), :)]; %#ok<AGROW>
	tcInactive_all = [tcInactive_all; medLW_tc(inactiveLWIdx(validTC_i), :)]; %#ok<AGROW>
end

% ===== Report =====
fprintf('\n========== SIGNAL RETENTION ANALYSIS ==========\n');

% Cell matching quality
validM = isfinite(nMatched);
fprintf('\n--- Cell Matching (last AW → first LW) ---\n');
fprintf('Mice with data: %d/%d\n', sum(validM), nMice);
for mi = find(validM')
	fprintf('  %s: AW=%d, LW=%d, matched=%d (%.0f%%)\n', ...
		mice(mi), nAW(mi), nLW(mi), nMatched(mi), 100*nMatched(mi)/max(nAW(mi),nLW(mi)));
end

% Analysis 1: Signed Spearman
vS = isfinite(rhoSigned);
fprintf('\n--- Analysis 1: Spearman(AW_signed, LW_signed) per mouse ---\n');
for mi = find(vS')
	fprintf('  %s: n=%d, rho=%.3f, p=%.4f\n', mice(mi), nMatched(mi), rhoSigned(mi), pSigned(mi));
end
fprintf('Mean rho: %.3f ± %.3f (SEM)\n', mean(rhoSigned(vS)), std(rhoSigned(vS))/sqrt(sum(vS)));
pSR_signed = signrank(rhoSigned(vS));
fprintf('Signrank (rho ≠ 0): p = %.4g\n', pSR_signed);

% Analysis 2: Absolute Spearman
vA = isfinite(rhoAbs);
fprintf('\n--- Analysis 2: Spearman(|AW|, |LW|) per mouse ---\n');
for mi = find(vA')
	fprintf('  %s: n=%d, rho=%.3f, p=%.4f\n', mice(mi), nMatched(mi), rhoAbs(mi), pAbs(mi));
end
fprintf('Mean rho: %.3f ± %.3f (SEM)\n', mean(rhoAbs(vA)), std(rhoAbs(vA))/sqrt(sum(vA)));
pSR_abs = signrank(rhoAbs(vA));
fprintf('Signrank (rho ≠ 0): p = %.4g\n', pSR_abs);

% Analysis 3: Mean LW response (signed)
vAI = isfinite(meanLW_active) & isfinite(meanLW_inactive);
fprintf('\n--- Analysis 3: AW-active vs AW-inactive mean LW response @1s ---\n');
fprintf('Active:   %.4f ± %.4f (SEM, n=%d)\n', mean(meanLW_active(vAI)), std(meanLW_active(vAI))/sqrt(sum(vAI)), sum(vAI));
fprintf('Inactive: %.4f ± %.4f (SEM, n=%d)\n', mean(meanLW_inactive(vAI)), std(meanLW_inactive(vAI))/sqrt(sum(vAI)), sum(vAI));
pMeanSigned = signrank(meanLW_active(vAI), meanLW_inactive(vAI));
fprintf('Paired signrank p = %.4g\n', pMeanSigned);

% Analysis 4: Mean |LW response| (absolute)
fprintf('\n--- Analysis 4: AW-active vs AW-inactive mean |LW response| @1s ---\n');
fprintf('Active:   %.4f ± %.4f (SEM, n=%d)\n', mean(meanAbsLW_active(vAI)), std(meanAbsLW_active(vAI))/sqrt(sum(vAI)), sum(vAI));
fprintf('Inactive: %.4f ± %.4f (SEM, n=%d)\n', mean(meanAbsLW_inactive(vAI)), std(meanAbsLW_inactive(vAI))/sqrt(sum(vAI)), sum(vAI));
pMeanAbs = signrank(meanAbsLW_active(vAI), meanAbsLW_inactive(vAI));
fprintf('Paired signrank p = %.4g\n', pMeanAbs);

% Analysis 5: Time course summary
fprintf('\n--- Analysis 5: Time course summary ---\n');
fprintf('AW-active cells pooled: %d\n', size(tcActive_all, 1));
fprintf('AW-inactive cells pooled: %d\n', size(tcInactive_all, 1));
if ~isempty(tcActive_all) && ~isempty(tcInactive_all)
	meanTC_active = mean(tcActive_all, 1, 'omitnan');
	meanTC_inactive = mean(tcInactive_all, 1, 'omitnan');
	fprintf('Mean z-score at 1s: Active=%.4f, Inactive=%.4f\n', ...
		meanTC_active(idx1s), meanTC_inactive(idx1s));
	% Ranksum at each timepoint
	tc_p = nan(1, nTimepoints);
	for t = 1:nTimepoints
		tc_p(t) = ranksum(tcActive_all(:,t), tcInactive_all(:,t));
	end
	sigTP = find(tc_p < 0.05);
	fprintf('Timepoints with p<0.05: %d/%d\n', numel(sigTP), nTimepoints);
	if ~isempty(sigTP)
		fprintf('  Time indices: %s\n', mat2str(sigTP));
		fprintf('  Time (sec): %s\n', mat2str(round(xsSec(sigTP), 2)));
	end
end

fprintf('\n========== END ==========\n');
