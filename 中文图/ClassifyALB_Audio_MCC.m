%% ClassifyALB_Audio_MCC.m — within-phase MCC for AudioWater
% Same as ClassifyALB_MCC.m but for AudioWater (Naive+Learned phases).
% Saves figures with _Audio suffix to avoid name conflict.

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

%% 1. List mice
TQ = DS.TableQuery(["Mouse","DateTime","Phase","Stimulus","Behavior"]);
TQ.Mouse = string(TQ.Mouse); TQ.Phase = string(TQ.Phase);
mice = unique(TQ.Mouse);
fprintf('=== AudioWater within-phase MCC ===\n');

results = cell(numel(mice), 1);

for iM = 1:numel(mice)
	mouse = mice(iM);
	fprintf('\n--- %s (%d/%d) ---\n', mouse, iM, numel(mice));

	% Query AudioWater from Naive+Learned
	allData = table();
	for phase = ["Naive", "Learned"]
		q = struct('Mouse', mouse, 'Phase', phase, 'Stimulus', "AudioWater");
		try
			res = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:nTime, ...
				'ExtraColumns', ["Behavior","DateTime"]);
			if ~isempty(res) && ~isempty(res{1})
				tbl = res{1};
				allData = [allData; tbl]; %#ok<AGROW>
			end
		catch, end
	end
	if isempty(allData) || ~ismember('TrialSignal', string(allData.Properties.VariableNames))
		fprintf('  SKIP: no data\n'); continue;
	end

	cellUIDs = uint64(unique(allData.CellUID));
	nCell = numel(cellUIDs);
	if nCell < 5; fprintf('  SKIP: %d cells\n', nCell); continue; end

	[Xcell, yVec] = iBuildFM(allData, cellUIDs);
	if isempty(Xcell) || numel(yVec) < 6; fprintf('  SKIP: insufficient trials\n'); continue; end
	if sum(yVec==1) < 3 || sum(yVec==0) < 3; fprintf('  SKIP: need >=3 per class\n'); continue; end

	nTrial = numel(yVec);
	nCellM = size(Xcell{1},1); nTimeM = size(Xcell{1},2);
	CTT = nan(nCellM, nTrial, nTimeM);
	for iT = 1:nTrial; CTT(:,iT,:) = Xcell{iT}; end
	fprintf('  %d cells, %d trials (hit=%d, miss=%d)\n', nCellM, nTrial, sum(yVec==1), sum(yVec==0));

	% Stratified 5-fold
	rng(1);
	hitIdx = find(yVec==1); missIdx = find(yVec==0);
	folds = zeros(nTrial,1);
	nFold = min(5, min(numel(hitIdx), numel(missIdx)));
	for iF = 1:nFold
		ih = round((iF-1)*numel(hitIdx)/nFold)+1 : round(iF*numel(hitIdx)/nFold);
		im = round((iF-1)*numel(missIdx)/nFold)+1 : round(iF*numel(missIdx)/nFold);
		folds(hitIdx(ih)) = iF; folds(missIdx(im)) = iF;
	end

	% MCC CTD
	accMat = nan(nTimeM, nTimeM);
	for trT = 1:nTimeM
		for teT = 1:nTimeM
			pred = nan(nTrial,1);
			for iF = 1:nFold
				train = folds~=iF; test = folds==iF;
				trD = squeeze(CTT(:,train,trT));
				hT = mean(trD(:,yVec(train)==1),2,'omitnan');
				mT = mean(trD(:,yVec(train)==0),2,'omitnan');
				teD = squeeze(CTT(:,test,teT));
				testIdx = find(test);
				for iTst = 1:size(teD,2)
					rH = corr(teD(:,iTst),hT,'Rows','complete');
					rM = corr(teD(:,iTst),mT,'Rows','complete');
					pred(testIdx(iTst)) = double(rH>=rM);
				end
			end
			accMat(trT,teT) = mean(pred==yVec,'omitnan');
		end
	end

	% Shuffle
	nPerm = 500; midT = round(nTimeM/2); permAcc = nan(nPerm,1);
	for iP = 1:nPerm
		sl = yVec(randperm(nTrial)); pp = nan(nTrial,1);
		for iF = 1:nFold
			train = folds~=iF; test = folds==iF;
			trD = squeeze(CTT(:,train,midT));
			hT = mean(trD(:,sl(train)==1),2,'omitnan');
			mT = mean(trD(:,sl(train)==0),2,'omitnan');
			teD = squeeze(CTT(:,test,midT));
			testIdx = find(test);
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

	r = struct();
	r.Mouse = mouse; r.NCells = nCellM; r.NTrial = nTrial;
	r.NHit = sum(yVec==1); r.NMiss = sum(yVec==0);
	r.AccMat = accMat; r.RealDiag = realDiag;
	r.PVal = pVal; r.Xs = xs(1:nTimeM);
	results{iM} = r;
	fprintf('  ACC: %.1f%% (shuffle: %.1f±%.1f%%, p=%.4f)\n', ...
		realDiag*100, mean(permAcc)*100, std(permAcc)*100, pVal);
end

%% Summary
valid = find(~cellfun(@isempty, results));
fprintf('\n====== AUDIO MCC ======\n');
fprintf('Valid: %d/%d\n', numel(valid), numel(mice));
diags = nan(numel(valid),1);
for i = 1:numel(valid)
	r = results{valid(i)}; s='';
	if r.PVal<0.05; s=' *'; end; if r.PVal<0.01; s=' **'; end; if r.PVal<0.001; s=' ***'; end
	fprintf('  %s: %d cells, %d trials(%dH/%dM), ACC=%.1f%%, p=%.4f%s\n', ...
		r.Mouse, r.NCells, r.NTrial, r.NHit, r.NMiss, r.RealDiag*100, r.PVal, s);
	diags(i) = r.RealDiag;
end
fprintf('Mean: %.1f%%\n', mean(diags,'omitnan')*100);

%% Plots
nV = numel(valid);
if nV > 0
	nC = min(4,nV); nR = ceil(nV/nC);
	fC = figure('Name','Audio MCC CTD','Color','w','Position',[50 50 nC*280 nR*260]);
	tiledlayout(fC, nR, nC, 'TileSpacing','compact','Padding','compact');
	for i=1:nV
		r=results{valid(i)}; nexttile;
		imagesc(r.Xs,r.Xs,r.AccMat'); axis xy square; colormap(hot); clim([0.3 1]);
		hold on; plot(r.Xs,r.Xs,'-','Color',[0 0 0 0.25],'LineWidth',1); hold off;
		s=''; if r.PVal<0.05; s='*'; end
		title(sprintf('%s %.1f%%%s',r.Mouse,r.RealDiag*100,s),'FontSize',8,'FontWeight','normal');
		xlabel('Train (s)'); ylabel('Test (s)');
	end
	TransferLearning.ExportStandardFigure(fC, 2, 'MCC_Audio_CTD.svg');
end

fB = figure('Name','Audio MCC bar','Color','w','Position',[100 100 420 300]);
ax = axes(fB);
bar(ax, 1:nV, 100*diags, 'FaceColor',[0.5 0.2 0.7],'EdgeColor','none');
hold(ax,'on'); yline(ax,50,'--k');
for i=1:nV
	r=results{valid(i)};
	if r.PVal<0.05
		sg='*'; if r.PVal<0.01; sg='**'; end; if r.PVal<0.001; sg='***'; end
		text(ax,i,100*diags(i)+2,sg,'HorizontalAlignment','center','FontSize',10);
	end
end
set(ax,'XTick',1:nV,'XTickLabel',arrayfun(@(i)results{valid(i)}.Mouse,1:nV,'UniformOutput',false));
xtickangle(ax,45); ylabel(ax,'Decoding (%)'); title(ax,'AudioWater MCC');
box(ax,'off'); ylim(ax,[0 105]);
TransferLearning.ExportStandardFigure(fB, 2, 'MCC_Audio_Bar.svg');

fprintf('\nDone.\n');

%% Local
function [X,y] = iBuildFM(rawTbl, cellUIDs)
sig = double(rawTbl.TrialSignal); nT = size(sig,2);
t = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), double(rawTbl.Behavior), ...
    'VariableNames',{'CellUID','TrialUID','Behavior'});
sc = cell(size(sig,1),1); for i=1:size(sig,1); sc{i}=sig(i,:); end; t.Signal = sc;
t = t(ismember(t.CellUID,cellUIDs),:);
if isempty(t); X=[]; y=[]; return; end
tU = unique(t.TrialUID); nTr = numel(tU); nC = numel(cellUIDs);
X = cell(nTr,1); y = nan(nTr,1);
for iT=1:nTr
	rr = t(t.TrialUID==tU(iT),:); sm = nan(nC,nT);
	[~,loc] = ismember(rr.CellUID,cellUIDs);
	for iR=1:height(rr); ci=loc(iR); if ci>0; sm(ci,:)=rr.Signal{iR}; end; end
	X{iT}=sm; y(iT)=mode(rr.Behavior);
end
ok = cellfun(@(m)all(isfinite(m),'all'),X) & isfinite(y);
X=X(ok); y=y(ok);
for i=1:numel(X); X{i}(isnan(X{i}))=0; end
end
