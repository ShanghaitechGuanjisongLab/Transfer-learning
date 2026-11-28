%% _chk_A2_vs_A1.m
% 只算不画：把 6 组 slope 的计算从 A1(逐 trial 惩罚 sigmoid) 换成
% A2(逐 trial 无惩罚 MLE sigmoid, lower=0, upper=1, k<=200)，
% 比较 per-mouse 斜率与组间检验 p 是否改变。不导出任何 SVG。
%
% 每个 group 都在**同一份 trial 表**上同时算 A1 和 A2，因此差异纯粹来自算法。
clear variables; close all; clc;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

outFile = 'd:\git\Transfer-Learning\_chk_A2_vs_A1_results.txt';
if isfile(outFile), delete(outFile); end
diary(outFile);
fprintf('==== A1 vs A2 slope algorithm check (%s) ====\n', datestr(now));

PairRows = table();

%% ================= G1: Fig1C 三对 =================
fprintf('\n--- G1  Fig1C (Naive/12h/7d) ---\n');
try
	Sess1 = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
	S1 = iSlopesFromSessions(Sess1);
	fprintf('per-mouse rows = %d\n', height(S1));
	pairs1 = ["Naive","Transfer"; "Naive","7dayTransfer"; "Transfer","7dayTransfer"];
	pairName1 = ["Naive vs 12h"; "Naive vs 7d"; "12h vs 7d"];
	for i = 1:3
		a = pairs1(i,1); b = pairs1(i,2);
		x1 = S1.SlopeA1(S1.Group == a & isfinite(S1.SlopeA1)); y1 = S1.SlopeA1(S1.Group == b & isfinite(S1.SlopeA1));
		x2 = S1.SlopeA2(S1.Group == a & isfinite(S1.SlopeA2)); y2 = S1.SlopeA2(S1.Group == b & isfinite(S1.SlopeA2));
		p1v = iRankP(x1, y1); p2v = iRankP(x2, y2);
		fprintf('%-13s n=%2d/%2d | A1 %.2f vs %.2f p=%.4g | A2 %.2f vs %.2f p=%.4g\n', ...
			pairName1(i), numel(x1), numel(y1), median(x1), median(y1), p1v, median(x2), median(y2), p2v);
		PairRows = [PairRows; table("G1 " + pairName1(i), numel(x1), numel(y1), ...
			median(x1), median(y1), p1v, median(x2), median(y2), p2v, ...
			'VariableNames', {'Case','N1','N2','MedA1_1','MedA1_2','P_A1','MedA2_1','MedA2_2','P_A2'})]; %#ok<AGROW>
	end
	iReportAgreement(S1);
catch err
	fprintf('G1 FAILED: %s\n', err.message);
end

%% ================= G6: TH 抑制 vs 12h =================
fprintf('\n--- G6  TH vs 12h ---\n');
try
	[IC, IT] = TransferLearning.BuildIntervalBehaviorCurves();
	controlCurves = IC(string(IC.Group) == "12h", :);
	controlTrials = innerjoin(IT(string(IT.Group) == "12h", :), ...
		controlCurves(:, {'Group','Mouse','DateTime','Block'}), ...
		'Keys', {'Group','Mouse','DateTime'});
	thImaging = TransferLearning.BuildTHInhibitTrialTable();
	thBehavior = TransferLearning.BuildPOBehaviorTrialTable();
	vars = {'Group','Mouse','DateTime','Block','Behavior','Source'};
	common = intersect(intersect(controlTrials.Properties.VariableNames, ...
		thImaging.Properties.VariableNames), thBehavior.Properties.VariableNames);
	vars = intersect(vars, common, 'stable');
	TT6 = [controlTrials(:, vars); thImaging(:, vars); thBehavior(:, vars)];
	S6 = iSlopesFromTrialTable(TT6);
	x1 = S6.SlopeA1(S6.Group == "12h"); y1 = S6.SlopeA1(S6.Group == "THInhibit");
	x2 = S6.SlopeA2(S6.Group == "12h"); y2 = S6.SlopeA2(S6.Group == "THInhibit");
	p1v = iRankP(x1, y1); p2v = iRankP(x2, y2);
	fprintf('12h vs TH  n=%2d/%2d | A1 %.2f vs %.2f p=%.4g | A2 %.2f vs %.2f p=%.4g\n', ...
		numel(x1), numel(y1), median(x1), median(y1), p1v, median(x2), median(y2), p2v);
	PairRows = [PairRows; table("G6 12h vs TH", numel(x1), numel(y1), ...
		median(x1), median(y1), p1v, median(x2), median(y2), p2v, ...
		'VariableNames', PairRows.Properties.VariableNames)]; %#ok<AGROW>
	iReportAgreement(S6);
catch err
	fprintf('G6 FAILED: %s\n', err.message);
end

%% ================= G2: Sup1 延迟 vs 未延迟 =================
fprintf('\n--- G2  Sup1 Undelayed vs Delayed ---\n');
try
	alpb = TransferLearning.ALPureBehavior();
	Tu = TransferLearning.DelayComparison.LightSessionTable(alpb, "LightWater", "Transfer", "Final");
	Tu = Tu(isfinite(Tu.Performance) & Tu.NTrial > 0, :);
	Tu.Group = repmat("Undelayed", height(Tu), 1);
	Tu = TransferLearning.DelayComparison.AddBlockIndex(Tu);
	Td = TransferLearning.DelayComparison.CohortBlocks("DelayedBehaviorTransfer");
	Td.Group = repmat("Delayed", height(Td), 1);
	Td = TransferLearning.DelayComparison.AddBlockIndex(Td);
	DSd = UniExp.DataSet(TransferLearning.DelayComparison.BehaviorDataPath("A2L_L"));
	TTu = iTrialsFromDS(alpb, Tu, "LightWater", "Block");
	TTd = iTrialsFromDS(DSd, Td, ["LightLearnWater","LightLearnWaterAlways"], "Block");
	S2 = iSlopesFromTrialTable([TTu; TTd]);
	x1 = S2.SlopeA1(S2.Group == "Undelayed"); y1 = S2.SlopeA1(S2.Group == "Delayed");
	x2 = S2.SlopeA2(S2.Group == "Undelayed"); y2 = S2.SlopeA2(S2.Group == "Delayed");
	p1v = iRankP(x1, y1); p2v = iRankP(x2, y2);
	fprintf('Undelayed vs Delayed n=%2d/%2d | A1 %.2f vs %.2f p=%.4g | A2 %.2f vs %.2f p=%.4g\n', ...
		numel(x1), numel(y1), median(x1), median(y1), p1v, median(x2), median(y2), p2v);
	PairRows = [PairRows; table("G2 Undelayed vs Delayed", numel(x1), numel(y1), ...
		median(x1), median(y1), p1v, median(x2), median(y2), p2v, ...
		'VariableNames', PairRows.Properties.VariableNames)]; %#ok<AGROW>
	iReportAgreement(S2);
catch err
	fprintf('G2 FAILED: %s\n', err.message);
end

%% ================= G3: 光转声（AudioWater）Naive vs Transfer =================
fprintf('\n--- G3  AudioWater Naive vs Transfer ---\n');
try
	ALB  = TransferLearning.AudioLightBaseline();
	ALPB = TransferLearning.ALPureBehavior();
	LAB  = TransferLearning.LightAudioBaseline();
	LAPB = TransferLearning.LAPureBehavior();
	specs = {ALB,  "AudioWater", "Naive",    "Learned", "Naive"; ...
	         ALPB, "AudioWater", "Naive",    "Learned", "Naive"; ...
	         LAB,  "AudioWater", "Transfer", "Final",   "Transfer"; ...
	         LAPB, "AudioWater", "Transfer", "Final",   "Transfer"};
	TT3 = table();
	for i = 1:size(specs, 1)
		Ss = TransferLearning.DelayComparison.LightSessionTable(specs{i,1}, specs{i,2}, specs{i,3}, specs{i,4});
		Ss = Ss(isfinite(Ss.Performance) & Ss.NTrial > 0, :);
		if isempty(Ss), continue; end
		Ss.Group = repmat(string(specs{i,5}), height(Ss), 1);
		Ss = TransferLearning.DelayComparison.AddBlockIndex(Ss);
		TT3 = [TT3; iTrialsFromDS(specs{i,1}, Ss, "AudioWater", "Block")]; %#ok<AGROW>
	end
	S3 = iSlopesFromTrialTable(TT3);
	x1 = S3.SlopeA1(S3.Group == "Naive"); y1 = S3.SlopeA1(S3.Group == "Transfer");
	x2 = S3.SlopeA2(S3.Group == "Naive"); y2 = S3.SlopeA2(S3.Group == "Transfer");
	p1v = iRankP(x1, y1); p2v = iRankP(x2, y2);
	fprintf('AudioWater Naive vs Transfer n=%2d/%2d | A1 %.2f vs %.2f p=%.4g | A2 %.2f vs %.2f p=%.4g\n', ...
		numel(x1), numel(y1), median(x1), median(y1), p1v, median(x2), median(y2), p2v);
	PairRows = [PairRows; table("G3 AudioWater Naive vs Transfer", numel(x1), numel(y1), ...
		median(x1), median(y1), p1v, median(x2), median(y2), p2v, ...
		'VariableNames', PairRows.Properties.VariableNames)]; %#ok<AGROW>
	iReportAgreement(S3);
catch err
	fprintf('G3 FAILED: %s\n', err.message);
end

%% ================= G5: cFos Control vs MOp =================
fprintf('\n--- G5  cFos Control vs MOp ---\n');
try
	DS5 = UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202611\cFos合集.v3.mat");
	S = DS5.Mice;
	if ~ismember('Mouse', S.Properties.VariableNames)
		S.Mouse = string(S.Properties.RowNames);
	end
	S.Mouse = string(S.Mouse);
	S.Group = string(S.ExpressedBrain);
	S.Group(~logical(S.MarkTimes)) = "Control";
	S = S(ismember(S.Group, ["Control", "MOp"]), :);
	[~, ia] = unique(S.Mouse, 'stable');
	S = S(ia, :);
	B = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS5, false);
	B.Mouse = string(B.Mouse);
	B.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(B.DateTime);
	J = innerjoin(B, S(:, {'Mouse','Group'}), 'Keys', 'Mouse');
	J.Group = string(J.Group);
	vv = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable');
	Sess5 = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, vv));
	Sess5 = sortrows(Sess5, {'Group','Mouse','DateTime'});
	Sess5 = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess5);
	TT5 = iTrialsFromDS(DS5, Sess5, "LightWater", "Session");
	S5 = iSlopesFromTrialTable(TT5);
	x1 = S5.SlopeA1(S5.Group == "Control"); y1 = S5.SlopeA1(S5.Group == "MOp");
	x2 = S5.SlopeA2(S5.Group == "Control"); y2 = S5.SlopeA2(S5.Group == "MOp");
	p1v = iRankP(x1, y1); p2v = iRankP(x2, y2);
	fprintf('cFos Control vs MOp n=%2d/%2d | A1 %.2f vs %.2f p=%.4g | A2 %.2f vs %.2f p=%.4g\n', ...
		numel(x1), numel(y1), median(x1), median(y1), p1v, median(x2), median(y2), p2v);
	PairRows = [PairRows; table("G5 cFos Control vs MOp", numel(x1), numel(y1), ...
		median(x1), median(y1), p1v, median(x2), median(y2), p2v, ...
		'VariableNames', PairRows.Properties.VariableNames)]; %#ok<AGROW>
	iReportAgreement(S5);
catch err
	fprintf('G5 FAILED: %s\n', err.message);
end

%% ================= G4: RH-slope 相关（12h） =================
fprintf('\n--- G4  RH vs slope (12h, Fig4D/Fig3E 口径) ---\n');
try
	ALBq = TransferLearning.AudioLightBaseline();
	sess = TransferLearning.DelayComparison.CohortBlocks("UndelayedRecordingTransfer");
	blk = TransferLearning.DelayComparison.AddBlockIndex(sess);
	S4 = iSlopesFromTrialTable(iTrialsFromDS(ALBq, blk, "LightWater", "Block"));
	% 异质性：Fig4D 的 pre-ceiling 筛选
	hetSess = iPreCeiling(sess);
	Het = TransferLearning.Metrics.ResponseHeterogeneity(ALBq, hetSess, "LightWater");
	Het = Het(isfinite(Het.SD) & Het.NCells > 0, :);
	% (a) 合并层（按 NCells 加权，Fig4D）
	[g4, mice4] = findgroups(string(Het.Mouse));
	pooled = splitapply(@(s, n) sum(s .* n) / sum(n), Het.SD, Het.NCells, g4);
	Tp = table(mice4, pooled, 'VariableNames', {'Mouse','Heterogeneity'});
	fprintf('pooled-layer:\n');
	iCorrReport(innerjoin(S4, Tp, 'Keys', 'Mouse'));
	% (b) 逐层（Fig3E）
	for layer = ["MOp2/3","MOp5"]
		H1 = Het(Het.Layer == layer, :);
		Tl = table(string(H1.Mouse), H1.SD, 'VariableNames', {'Mouse','Heterogeneity'});
		fprintf('%s:\n', layer);
		iCorrReport(innerjoin(S4, Tl, 'Keys', 'Mouse'));
	end
catch err
	fprintf('G4 FAILED: %s\n', err.message);
end

%% ================= 汇总 =================
fprintf('\n\n==== 汇总：组间检验 p（A1 vs A2）====\n');
disp(PairRows);
save('d:\git\Transfer-Learning\_chk_A2_vs_A1.mat', 'PairRows');
diary off;
fprintf('done. results -> %s\n', outFile);

%% ================= 局部函数 =================
function S = iSlopesFromSessions(Sess)
pool = {TransferLearning.LightAudioBaseline(), "Naive"; ...
	TransferLearning.LAInterspersed(), "Naive"; ...
	TransferLearning.AudioLightBaseline(), "Transfer"; ...
	TransferLearning.Vacation7(), "7dayTransfer"};
S = iEmptySlopeTable();
for g = unique(string(Sess.Group), 'stable').'
	Sg = Sess(string(Sess.Group) == g, :);
	for m = unique(string(Sg.Mouse), 'stable').'
		Sm = Sg(string(Sg.Mouse) == m, :);
		DS = iFindDS(pool, g, m);
		if isempty(DS), continue; end
		dt = iNormDT(Sm.DateTime);
		Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Behavior"], Mouse = m, Stimulus = "LightWater");
		if isempty(Tq), continue; end
		y = double(Tq.Behavior);
		[~, loc] = ismember(iNormDT(Tq.DateTime), dt);
		ok = isfinite(y) & loc > 0;
		if nnz(ok) < 2, continue; end
		blk = double(Sm.Session(loc(ok)));
		if numel(unique(blk)) < 2, continue; end
		S = [S; iOneRow(g, m, blk, y(ok))]; %#ok<AGROW>
	end
end
end

function S = iSlopesFromTrialTable(TT)
S = iEmptySlopeTable();
if isempty(TT), return; end
for g = unique(string(TT.Group), 'stable').'
	Sg = TT(string(TT.Group) == g, :);
	for m = unique(string(Sg.Mouse), 'stable').'
		Q = Sg(string(Sg.Mouse) == m, :);
		x = double(Q.Block); y = double(Q.Behavior);
		ok = isfinite(x) & isfinite(y);
		if nnz(ok) < 2 || numel(unique(x(ok))) < 2, continue; end
		S = [S; iOneRow(g, m, x(ok), y(ok))]; %#ok<AGROW>
	end
end
end

function T = iEmptySlopeTable()
T = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), nan(0,1), nan(0,1), false(0,1), false(0,1), ...
	'VariableNames', {'Group','Mouse','NBlocks','NTrials','SlopeA1','SlopeA2','A1Bound','A2Bound'});
end

function T = iOneRow(g, m, x, y)
fitA1 = TransferLearning.FitPenalizedSigmoid(double(x), double(y), FixLowerZero = true);
[k2, b2] = iFitA2(double(x), double(y));
T = table(string(g), string(m), numel(unique(double(x))), numel(y), ...
	fitA1.Slope, k2, logical(fitA1.AtSlopeBoundary), logical(b2), ...
	'VariableNames', {'Group','Mouse','NBlocks','NTrials','SlopeA1','SlopeA2','A1Bound','A2Bound'});
end

function [k, atBound] = iFitA2(x, y)
x = double(x(:)); y = double(y(:));
kMax = 200;
starts = [log(0.2) median(x); log(0.8) median(x); log(2) median(x); log(6) median(x)];
best = inf; pBest = [NaN NaN];
opt = optimset('Display','off','MaxFunEvals',5000,'MaxIter',2000);
for i = 1:size(starts,1)
	p = fminsearch(@(p) iNLL(p, x, y, kMax), starts(i,:), opt);
	o = iNLL(p, x, y, kMax);
	if isfinite(o) && o < best, best = o; pBest = p; end
end
k = exp(min(pBest(1), log(kMax)));
atBound = pBest(1) >= log(kMax) - 1e-6;
end

function o = iNLL(p, x, y, kMax)
k = exp(min(p(1), log(kMax)));
pr = 1 ./ (1 + exp(-k * (x - p(2))));
pr = min(max(pr, 1e-12), 1 - 1e-12);
o = -sum(y .* log(pr) + (1 - y) .* log(1 - pr));
end

function TT = iTrialsFromDS(DS, Sess, stims, blockField)
TT = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
	'VariableNames', {'Group','Mouse','Block','Behavior'});
for m = unique(string(Sess.Mouse), 'stable').'
	Sm = Sess(string(Sess.Mouse) == m, :);
	dt = iNormDT(Sm.DateTime);
	blk = double(Sm.(blockField));
	acc = table();
	for s = stims
		Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Behavior"], Mouse = m, Stimulus = s);
		if isempty(Tq), continue; end
		acc = [acc; Tq(:, {'DateTime','Behavior'})]; %#ok<AGROW>
	end
	if isempty(acc), continue; end
	if ismember('Group', Sm.Properties.VariableNames)
		gLabel = string(Sm.Group(1));
	else
		gLabel = "All";
	end
	y = double(acc.Behavior);
	[~, loc] = ismember(iNormDT(acc.DateTime), dt);
	ok = isfinite(y) & loc > 0;
	if nnz(ok) < 2 || numel(unique(blk(loc(ok)))) < 2, continue; end
	TT = [TT; table(repmat(gLabel, nnz(ok), 1), repmat(string(m), nnz(ok), 1), ...
		blk(loc(ok)), y(ok), 'VariableNames', {'Group','Mouse','Block','Behavior'})]; %#ok<AGROW>
end
end

function DS = iFindDS(pool, group, mouse)
DS = [];
for i = 1:size(pool, 1)
	if string(pool{i,2}) ~= string(group), continue; end
	if any(unique(string(pool{i,1}.DateTimes.Mouse)) == string(mouse))
		DS = pool{i,1};
		return;
	end
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
end

function T = iTake(T, vars)
vars = intersect(vars, T.Properties.VariableNames, 'stable');
T = T(:, vars);
end

function p = iRankP(a, b)
a = double(a(:)); b = double(b(:));
a = a(isfinite(a)); b = b(isfinite(b));
if numel(a) < 2 || numel(b) < 2, p = NaN; return; end
p = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
end

function iReportAgreement(S)
ok = isfinite(S.SlopeA1) & isfinite(S.SlopeA2);
if nnz(ok) < 3
	fprintf('  (agreement: 样本不足)\n'); return;
end
rho = corr(S.SlopeA1(ok), S.SlopeA2(ok), 'Type', 'Spearman');
r = corr(S.SlopeA1(ok), S.SlopeA2(ok));
fprintf('  A1 vs A2 per-mouse: Spearman=%.3f Pearson=%.3f | A1bound=%d A2bound=%d | A2/A1 median=%.2f\n', ...
	rho, r, nnz(S.A1Bound), nnz(S.A2Bound), median(S.SlopeA2(ok) ./ max(S.SlopeA1(ok), eps)));
end

function sess = iPreCeiling(sess)
sess = sortrows(sess, {'Mouse','DateTime'});
keep = false(height(sess), 1);
for m = unique(string(sess.Mouse), 'stable').'
	idx = find(string(sess.Mouse) == m);
	firstCeil = find(double(sess.Performance(idx)) >= 1 - 1e-12, 1, 'first');
	if isempty(firstCeil), avail = idx; else, avail = idx(1:firstCeil-1); end
	if numel(avail) >= 2, keep(avail) = true; end
end
sess = sess(keep, :);
end

function iCorrReport(J)
ok = isfinite(J.SlopeA1) & isfinite(J.SlopeA2) & isfinite(J.Heterogeneity);
n = nnz(ok);
if n < 3
	fprintf('  n=%d 样本不足\n', n); return;
end
[r1, p1] = corr(J.Heterogeneity(ok), J.SlopeA1(ok), 'Type', 'Spearman');
[r2, p2] = corr(J.Heterogeneity(ok), J.SlopeA2(ok), 'Type', 'Spearman');
fprintf('  n=%d | A1 rho=%+.3f p=%.4g | A2 rho=%+.3f p=%.4g\n', n, r1, p1, r2, p2);
end
