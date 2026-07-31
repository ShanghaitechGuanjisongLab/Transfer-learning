%% DecodeCrossPhase_ALB.m — 跨阶段 MCC 泛化解码
% 训练集：Naive + Learned 阶段（LightWater）
% 测试集：Transfer 阶段（LightWater）
% 比较信息编码是否跨阶段保守

%% 0. Setup
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

%% 1. List mice with Naive+Learned+Transfer LightWater
TQ = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus","Behavior"]);
TQ.Mouse = string(TQ.Mouse); TQ.Phase = string(TQ.Phase);
mice = unique(TQ.Mouse);
fprintf('=== Cross-phase generalization ===\n');
fprintf('Mice: %d\n', numel(mice));

results = cell(numel(mice), 1);

for iM = 1:numel(mice)
	mouse = mice(iM);
	fprintf('\n--- %s (%d/%d) ---\n', mouse, iM, numel(mice));

	% Query NTS: train on Naive + first 2 Learned AudioWater; test on Transfer LightWater
	allData = table();

	% === Training: Naive AudioWater (all) ===
	qN = struct('Mouse', mouse, 'Phase', "Naive", 'Stimulus', "AudioWater");
	try
		res = DS.QueryNTS(qN, UniExp.Flags.ZScore, 1:nTime, ...
			'ExtraColumns', ["Behavior","DateTime"]);
		if ~isempty(res) && ~isempty(res{1})
			tbl = res{1};
			tbl.Phase = repmat("Naive", height(tbl), 1);
			allData = [allData; tbl];
		end
	catch, end

	% === Training: Learned AudioWater (first 2 sessions only) ===
	qL = struct('Mouse', mouse, 'Phase', "Learned", 'Stimulus', "AudioWater");
	try
		res = DS.QueryNTS(qL, UniExp.Flags.ZScore, 1:nTime, ...
			'ExtraColumns', ["Behavior","DateTime"]);
		if ~isempty(res) && ~isempty(res{1})
			tbl = res{1};
			% Keep only first 2 Learned sessions
			sessDT = unique(tbl.DateTime);
			if numel(sessDT) > 2
				sessDT = sort(sessDT);
				tbl = tbl(ismember(tbl.DateTime, sessDT(1:2)), :);
			end
			if ~isempty(tbl)
				tbl.Phase = repmat("Learned", height(tbl), 1);
				allData = [allData; tbl];
			end
		end
	catch, end

	% === Testing: Transfer LightWater (all) ===
	qT = struct('Mouse', mouse, 'Phase', "Transfer", 'Stimulus', "LightWater");
	try
		res = DS.QueryNTS(qT, UniExp.Flags.ZScore, 1:nTime, ...
			'ExtraColumns', ["Behavior","DateTime"]);
		if ~isempty(res) && ~isempty(res{1})
			tbl = res{1};
			tbl.Phase = repmat("Transfer", height(tbl), 1);
			allData = [allData; tbl];
		end
	catch, end
	if isempty(allData) || ~ismember('TrialSignal', string(allData.Properties.VariableNames))
		fprintf('  SKIP: no data\n'); continue;
	end

	cellUIDs = uint64(unique(allData.CellUID));
	nCell = numel(cellUIDs);
	if nCell < 5; fprintf('  SKIP: %d cells\n', nCell); continue; end

	% Build feature matrix for all data
	[Xall, yAll, trialUIDs, phaseAll] = iBuildFeatureMatrixWithPhase(allData, cellUIDs);
	if isempty(Xall) || numel(yAll) < 10; fprintf('  SKIP: insufficient trials\n'); continue; end

	% Split train/test by phase
	trainMask = ismember(phaseAll, ["Naive","Learned"]);
	testMask = phaseAll == "Transfer";

	nTrain = sum(trainMask); nTest = sum(testMask);
	if nTrain < 6 || nTest < 3; fprintf('  SKIP: train=%d test=%d\n', nTrain, nTest); continue; end

	nCellM = size(Xall{1},1); nTimeM = size(Xall{1},2);
	CTTtrain = nan(nCellM, nTrain, nTimeM);
	CTTtest  = nan(nCellM, nTest, nTimeM);
	yTrain = yAll(trainMask); yTest = yAll(testMask);
	for iT = 1:nTrain; CTTtrain(:,iT,:) = Xall{trainMask}; end
	for iT = 1:nTest;  CTTtest(:,iT,:)  = Xall{testMask}; end

	fprintf('  Train: %d trials(%dH/%dM)  Test: %d trials(%dH/%dM)  Cells:%d\n', ...
		nTrain, sum(yTrain==1), sum(yTrain==0), nTest, sum(yTest==1), sum(yTest==0), nCellM);

	if sum(yTrain==1)<2 || sum(yTrain==0)<2 || sum(yTest==1)<1 || sum(yTest==0)<1
		fprintf('  SKIP: class imbalance\n'); continue;
	end

	% MCC: train templates on Naive+Learned → test on Transfer
	accMat = nan(nTimeM, nTimeM);
	for trT = 1:nTimeM
		hTmpl = mean(squeeze(CTTtrain(:, yTrain==1, trT)), 2, 'omitnan');
		mTmpl = mean(squeeze(CTTtrain(:, yTrain==0, trT)), 2, 'omitnan');
		for teT = 1:nTimeM
			teD = squeeze(CTTtest(:, :, teT));
			pred = nan(nTest,1);
			for iTst = 1:nTest
				rH = corr(teD(:,iTst), hTmpl, 'Rows','complete');
				rM = corr(teD(:,iTst), mTmpl, 'Rows','complete');
				pred(iTst) = double(rH >= rM);
			end
			accMat(trT, teT) = mean(pred == yTest, 'omitnan');
		end
	end

	% Shuffle control
	nPerm = 200; midT = round(nTimeM/2); permAcc = nan(nPerm,1);
	for iP = 1:nPerm
		sy = yTrain(randperm(nTrain));
		hT = mean(squeeze(CTTtrain(:, sy==1, midT)), 2, 'omitnan');
		mT = mean(squeeze(CTTtrain(:, sy==0, midT)), 2, 'omitnan');
		teD = squeeze(CTTtest(:, :, midT));
		pp = nan(nTest,1);
		for iTst = 1:nTest
			rH = corr(teD(:,iTst), hT, 'Rows','complete');
			rM = corr(teD(:,iTst), mT, 'Rows','complete');
			pp(iTst) = double(rH >= rM);
		end
		permAcc(iP) = mean(pp == yTest, 'omitnan');
	end
	realDiag = mean(diag(accMat), 'omitnan');
	pVal = mean(permAcc >= realDiag);

	r = struct();
	r.Mouse = mouse; r.NCells = nCellM;
	r.NTrain = nTrain; r.NTest = nTest;
	r.NHitTrain = sum(yTrain==1); r.NMissTrain = sum(yTrain==0);
	r.NHitTest = sum(yTest==1); r.NMissTest = sum(yTest==0);
	r.AccMat = accMat; r.RealDiag = realDiag;
	r.PermAcc = permAcc; r.PVal = pVal;
	r.Xs = xs(1:nTimeM);
	results{iM} = r;

	fprintf('  Cross-phase ACC: %.1f%% (shuffle: %.1f±%.1f%%, p=%.4f)\n', ...
		realDiag*100, mean(permAcc)*100, std(permAcc)*100, pVal);
end

%% 2. Summary
valid = find(~cellfun(@isempty, results));
fprintf('\n====== CROSS-PHASE SUMMARY ======\n');
fprintf('Valid mice: %d/%d\n', numel(valid), numel(mice));
diags = nan(numel(valid),1);
for i = 1:numel(valid)
	r = results{valid(i)};
	sig = '';
	if r.PVal < 0.05; sig = ' *'; end
	if r.PVal < 0.01; sig = ' **'; end
	if r.PVal < 0.001; sig = ' ***'; end
	fprintf('  %s: train=%d(H%d/M%d) test=%d(H%d/M%d) ACC=%.1f%% p=%.4f%s\n', ...
		r.Mouse, r.NTrain, r.NHitTrain, r.NMissTrain, ...
		r.NTest, r.NHitTest, r.NMissTest, r.RealDiag*100, r.PVal, sig);
	diags(i) = r.RealDiag;
end
fprintf('Mean ACC: %.1f%%\n', mean(diags,'omitnan')*100);
fprintf('Above chance: %d/%d\n', sum(diags>0.5,'omitnan'), numel(valid));

%% 3. Plots
nValid = numel(valid);
if nValid > 0
	nCols = min(4, nValid); nRows = ceil(nValid/nCols);
	fCtd = figure('Name','Cross-phase CTD','Color','w','Position',[50 50 nCols*280 nRows*260]);
	tiledlayout(fCtd, nRows, nCols, 'TileSpacing','compact','Padding','compact');
	for i = 1:nValid
		r = results{valid(i)}; nexttile;
		imagesc(r.Xs, r.Xs, r.AccMat'); axis xy square;
		colormap(hot); clim([0.3 1]);
		hold on; plot(r.Xs, r.Xs, '-', 'Color',[0 0 0 0.25],'LineWidth',1); hold off;
		sig = ''; if r.PVal<0.05; sig=' *'; end
		title(sprintf('%s %.1f%%%s', r.Mouse, r.RealDiag*100, sig),'FontSize',8,'FontWeight','normal');
		xlabel('Train (s)'); ylabel('Test (s)');
	end
	TransferLearning.ExportStandardFigure(fCtd, 2, 'DecodeCrossPhase_CTD.svg');
end

fBar = figure('Name','Cross-phase decoding','Color','w','Position',[100 100 420 300]);
ax = axes(fBar);
mouseNames = arrayfun(@(i) results{valid(i)}.Mouse, 1:nValid, 'UniformOutput',false);
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
ylabel(ax, 'Cross-phase decoding (%)'); title(ax, 'Naive+Learned → Transfer');
box(ax,'off'); ylim(ax, [0 105]);
TransferLearning.ExportStandardFigure(fBar, 2, 'DecodeCrossPhase_Bar.svg');

fprintf('\nDone.\n');


% ===== Local =====
function [X, y, trialUIDs, phases] = iBuildFeatureMatrixWithPhase(rawTbl, cellUIDs)
sig = double(rawTbl.TrialSignal); nTime = size(sig,2);
ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), ...
    'VariableNames', {'CellUID','TrialUID','Behavior'});
rawPhase = string(rawTbl.Phase);
sigCell = cell(size(sig,1),1);
for i=1:size(sig,1); sigCell{i}=sig(i,:); end
ntsTbl.Signal = sigCell;
rawPhase = string(rawTbl.Phase);
% Filter rows
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
	% Most common phase (avoid mode() on strings)
	uPhase = unique(rawPhase(ntsTbl.TrialUID == trialUIDs(iT)));
	phases(iT) = uPhase(1);
end
hasData = cellfun(@(m) all(isfinite(m),'all'), X) & isfinite(y);
X = X(hasData); y = y(hasData); trialUIDs = trialUIDs(hasData); phases = phases(hasData);
for i=1:numel(X); X{i}(isnan(X{i}))=0; end
end
