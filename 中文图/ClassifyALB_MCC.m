%% ClassifyALB_MCC.m — MCC (Maximum Correlation Coefficient) classifier
% Follows Yao et al. 2024 cross-temporal decoding (CTD) approach.
% Classifies hit vs miss from trial-level population activity.
%
% MCC: for each class compute mean population vector (template),
%      test trial is assigned to class with highest Pearson correlation.
%
% Data access follows TrainClassifierPerMouse.m pattern.

%% 0. Setup
thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
cd(prjRoot);  % ensure correct working directory
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end
% Ensure path includes project root
addpath(prjRoot);

%% 1. Load ALB and time axis
DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs); xs = seconds(xs); end
nTime = numel(xs);

%% 2. Query behavioral data to list mice
TQ = DS.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","TrialUID"]);
TQ.Mouse = string(TQ.Mouse);
TQ.Phase = string(TQ.Phase);
TQ = TQ(TQ.Stimulus == "LightWater" & TQ.Phase == "Transfer", :);
TQ = sortrows(TQ, ["Mouse","DateTime"]);
mice = unique(TQ.Mouse);
fprintf('Mice in ALB Transfer LightWater: %d\n', numel(mice));

%% 3. Per-mouse MCC
results = cell(numel(mice), 1);

for iM = 1:numel(mice)
	mouse = mice(iM);
	fprintf('\n--- Mouse %s (%d/%d) ---\n', mouse, iM, numel(mice));

	% Query NTS for all Transfer LightWater trials of this mouse
	q = struct('Mouse', mouse, 'Phase', "Transfer", 'Stimulus', "LightWater");
	raw = table();
	try
		res = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:nTime, ...
			'ExtraColumns', ["Behavior","DateTime"]);
		if ~isempty(res) && ~isempty(res{1})
			raw = res{1};
		end
	catch ME
		fprintf('  QueryNTS error: %s\n', ME.message);
	end
	if isempty(raw) || ~ismember('TrialSignal', string(raw.Properties.VariableNames))
		fprintf('  SKIP: empty NTS result\n'); continue;
	end

	% Use NTS cells directly
	cellUIDs = uint64(unique(raw.CellUID));
	nCell = numel(cellUIDs);
	if nCell < 5; fprintf('  SKIP: %d cells < 5\n', nCell); continue; end

	% Build trial-level feature matrix
	[Xcell, yVec, trialUIDs] = iBuildFeatureMatrix(raw, cellUIDs);
	if isempty(Xcell) || sum(isfinite(yVec)) < 6
		fprintf('  SKIP: insufficient data\n'); continue;
	end

	% Convert to 3-D array: nCell × nTrial × nTime
	nTrial = numel(yVec);
	nCellM = size(Xcell{1}, 1);
	nTimeM = size(Xcell{1}, 2);
	CTT = nan(nCellM, nTrial, nTimeM);
	for iT = 1:nTrial
		CTT(:, iT, :) = Xcell{iT};
	end

	fprintf('  %d cells, %d trials (hit=%d, miss=%d), %d time points\n', ...
		nCellM, nTrial, sum(yVec==1), sum(yVec==0), nTimeM);

	if sum(yVec==1) < 3 || sum(yVec==0) < 3
		fprintf('  SKIP: need >=3 per class\n'); continue;
	end

	% ---- MCC cross-temporal decoding ----
	rng(1);
	hitIdx = find(yVec==1); missIdx = find(yVec==0);
	folds = zeros(nTrial,1);
	nFold = min(5, min(numel(hitIdx), numel(missIdx)));
	for iF = 1:nFold
		ih = round((iF-1)*numel(hitIdx)/nFold)+1 : round(iF*numel(hitIdx)/nFold);
		im = round((iF-1)*numel(missIdx)/nFold)+1 : round(iF*numel(missIdx)/nFold);
		folds(hitIdx(ih)) = iF; folds(missIdx(im)) = iF;
	end

	accMat = nan(nTimeM, nTimeM);
	for trT = 1:nTimeM
		for teT = 1:nTimeM
			pred = nan(nTrial,1);
			for iF = 1:nFold
				train = folds~=iF; test = folds==iF;
				testIdx = find(test);
				trD = squeeze(CTT(:,train,trT));
				hTmpl = mean(trD(:,yVec(train)==1),2,'omitnan');
				mTmpl = mean(trD(:,yVec(train)==0),2,'omitnan');
				teD = squeeze(CTT(:,test,teT));
				for iTst = 1:size(teD,2)
					rH = corr(teD(:,iTst), hTmpl, 'Rows','complete');
					rM = corr(teD(:,iTst), mTmpl, 'Rows','complete');
					pred(testIdx(iTst)) = double(rH >= rM);
				end
			end
			accMat(trT,teT) = mean(pred==yVec,'omitnan');
		end
	end

	% Shuffle control (mid-time point)
	nPerm = 500;
	midT = round(nTimeM/2);
	permAcc = nan(nPerm,1);
	for iP = 1:nPerm
		sl = yVec(randperm(nTrial)); pp = nan(nTrial,1);
		for iF = 1:nFold
			train = folds~=iF; test = folds==iF;
			testIdx = find(test);
			trD = squeeze(CTT(:,train,midT));
			hT = mean(trD(:,sl(train)==1),2,'omitnan');
			mT = mean(trD(:,sl(train)==0),2,'omitnan');
			teD = squeeze(CTT(:,test,midT));
			for iTst = 1:size(teD,2)
				rH = corr(teD(:,iTst),hT,'Rows','complete');
				rM = corr(teD(:,iTst),mT,'Rows','complete');
				pp(testIdx(iTst)) = double(rH>=rM);
			end
		end
		permAcc(iP) = mean(pp==sl,'omitnan');
	end
	realDiag = mean(diag(accMat),'omitnan');
	pVal = mean(permAcc >= realDiag);

	% Store
	r = struct();
	r.Mouse = mouse; r.NCells = nCellM; r.NTrial = nTrial;
	r.NHit = sum(yVec==1); r.NMiss = sum(yVec==0);
	r.AccMat = accMat; r.RealDiag = realDiag;
	r.PermAcc = permAcc; r.PVal = pVal;
	r.Xs = xs(1:nTimeM);
	results{iM} = r;

	fprintf('  Same-time ACC: %.1f%% (shuffle: %.1f±%.1f%%, p=%.4f)\n', ...
		realDiag*100, mean(permAcc)*100, std(permAcc)*100, pVal);
end

%% 4. Summary
valid = find(~cellfun(@isempty, results));
fprintf('\n====== SUMMARY ======\n');
fprintf('Valid mice: %d/%d\n', numel(valid), numel(mice));

diags = nan(numel(valid),1);
for i = 1:numel(valid)
	r = results{valid(i)};
	sig = '';
	if r.PVal < 0.05; sig = ' *'; end
	if r.PVal < 0.01; sig = ' **'; end
	if r.PVal < 0.001; sig = ' ***'; end
	fprintf('  %s: %d cells, %d trials(%dH/%dM), ACC=%.1f%%, p=%.4f%s\n', ...
		r.Mouse, r.NCells, r.NTrial, r.NHit, r.NMiss, ...
		r.RealDiag*100, r.PVal, sig);
	diags(i) = r.RealDiag;
end
fprintf('Mean ACC: %.1f%%\n', mean(diags,'omitnan')*100);
fprintf('Above chance: %d/%d\n', sum(diags>0.5,'omitnan'), numel(valid));

%% 5. Plot per-mouse CTD matrices
nValid = numel(valid);
nCols = min(4, nValid);
nRows = ceil(nValid / nCols);
fCtd = figure('Name','MCC CTD per mouse','Color','w');
fCtd.Position = [50 50 nCols*280 nRows*260];
tiledlayout(fCtd, nRows, nCols, 'TileSpacing','compact','Padding','compact');
for i = 1:nValid
	r = results{valid(i)};
	nexttile;
	imagesc(r.Xs, r.Xs, r.AccMat'); axis xy square;
	colormap(hot); clim([0.3 1]);
	hold on;
	% 对角线参考线（训练时间 = 测试时间）
	plot(r.Xs, r.Xs, '-', 'Color', [0 0 0 0.25], 'LineWidth', 1);
	hold off;
	xlabel('Train (s)'); ylabel('Test (s)');
	sig = '';
	if r.PVal < 0.05; sig = ' *'; end
	title(sprintf('%s %.1f%%%s', r.Mouse, r.RealDiag*100, sig), ...
		'FontSize',8,'FontWeight','normal');
end
TransferLearning.ExportStandardFigure(fCtd, 2, 'MCC_CTD_ALB.svg');

%% 6. Group bar plot
fBar = figure('Name','MCC decoding accuracy','Color','w','Position',[100 100 420 300]);
ax = axes(fBar);
mouseNames = arrayfun(@(i) results{valid(i)}.Mouse, 1:nValid, 'UniformOutput',false);
barData = 100 * diags;
b = bar(ax, 1:nValid, barData);
b.FaceColor = [0.7 0.2 0.2];
b.EdgeColor = 'none';
hold(ax,'on');
yline(ax, 50, '--k', 'LineWidth',1);
for i = 1:nValid
	r = results{valid(i)};
	if r.PVal < 0.05
		sig = '*'; if r.PVal<0.01; sig='**'; end; if r.PVal<0.001; sig='***'; end
		text(ax, i, barData(i)+2, sig, 'HA','center','FontSize',10);
	end
end
set(ax, 'XTickLabel', mouseNames); xtickangle(ax, 45);
ylabel(ax, 'Same-time decoding (%)');
title(ax, 'MCC hit/miss decoding');
box(ax,'off'); ylim(ax, [0 105]);
TransferLearning.ExportStandardFigure(fBar, 2, 'MCC_Bar_ALB.svg');

fprintf('\nDone.\n');


% ===== Local functions =====

function [X, y, trialUIDs] = iBuildFeatureMatrix(rawTbl, cellUIDs)

sig = double(rawTbl.TrialSignal);
nTime = size(sig, 2);

ntsTbl = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), ...
    double(rawTbl.Behavior), 'VariableNames', {'CellUID','TrialUID','Behavior'});
sigCell = cell(size(sig,1), 1);
for i = 1:size(sig,1)
	sigCell{i} = sig(i, :);
end
ntsTbl.Signal = sigCell;

ntsTbl = ntsTbl(ismember(ntsTbl.CellUID, cellUIDs), :);
if isempty(ntsTbl); X=[]; y=[]; trialUIDs=[]; return; end

% Unique trial IDs
trialUIDs = unique(ntsTbl.TrialUID);
nTrials = numel(trialUIDs);
nCells = numel(cellUIDs);

X = cell(nTrials,1);
y = nan(nTrials,1);

for iT = 1:nTrials
	rows = ntsTbl(ntsTbl.TrialUID == trialUIDs(iT), :);
	seqMat = nan(nCells, nTime);
	[~, loc] = ismember(rows.CellUID, cellUIDs);
	for iR = 1:height(rows)
		ci = loc(iR);
		if ci > 0
			seqMat(ci, :) = rows.Signal{iR};
		end
	end
	X{iT} = seqMat;
	y(iT) = mode(rows.Behavior);
end

hasData = cellfun(@(m) all(isfinite(m),'all'), X) & isfinite(y);
X = X(hasData); y = y(hasData); trialUIDs = trialUIDs(hasData);
for i = 1:numel(X)
	X{i}(isnan(X{i})) = 0;
end
end
