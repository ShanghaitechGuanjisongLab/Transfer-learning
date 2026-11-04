% Sensitivity analysis: local temporal averaging for cue/choice GLM decoders.
% The current decoder trains independently at each time point. This probe
% preserves its data, baseline normalization, class-balanced training, and
% naive-Gaussian rule; only the input features change.
%
% Conditions: single 125-ms sample; centered local means spanning 3, 5, or 7
% samples (nominal half-windows +/-125, +/-250, +/-375 ms). The central
% sample is at t=0 s, so a full +/-375-ms window is truncated at t=0.
%
% Primary accuracy: balanced accuracy. For cue, use calibration 5-fold OOF
% predictions; for choice, report pre-transfer OOF and held-out Transfer.
% Every condition uses the same trial folds and balanced subsamples within a
% mouse/task. Paired mouse-label sign flips compare window versus single-
% sample accuracy. These are exploratory paired randomization p values.
%
% Run as a script; does not change existing decoder functions or figures.

rng(42,'twister');
D = TransferLearning.BuildCueChoiceDecoderData();
halfWidths = [0,0.125,0.250,0.375];
conditionNames = ["Single","±125 ms","±250 ms","±375 ms"];
nC = numel(conditionNames);
nT = numel(D.tVec);
mouseNames = string(cellfun(@(s)s.Mouse,D.choice,'UniformOutput',false));
cueMice = string(cellfun(@(s)s.Mouse,D.cue,'UniformOutput',false));

CueCV = nan(numel(D.cue),nC,nT);
ChoiceCV = nan(numel(D.choice),nC,nT);
ChoiceTransfer = nan(numel(D.choice),nC,nT);
for iM = 1:numel(D.cue)
	fprintf('Cue window comparison mouse %d/%d: %s\n',iM,numel(D.cue),cueMice(iM));
	cue = D.cue{iM};
	for iC = 1:nC
		for iT = 1:nT
			timeIdx = iLocalWindow(D.tVec,iT,halfWidths(iC));
			[~,cvPred,~] = iPairedGlm( ...
				mean(cue.X2(:,:,timeIdx),3),cue.y2, ...
				mean(cue.Xt(:,:,timeIdx),3),5);
			CueCV(iM,iC,iT) = iBalAcc(cvPred,cue.y2);
		end
	end
end
for iM = 1:numel(mouseNames)
	fprintf('Choice window comparison mouse %d/%d: %s\n',iM,numel(mouseNames),mouseNames(iM));
	choice = D.choice{iM};
	for iC = 1:nC
		for iT = 1:nT
			timeIdx = iLocalWindow(D.tVec,iT,halfWidths(iC));
			okB = isfinite(choice.behTr2);
			[~,cvPred,tePred] = iPairedGlm( ...
				mean(choice.Xtr2(okB,:,timeIdx),3),choice.behTr2(okB), ...
				mean(choice.Xte(:,:,timeIdx),3),5);
			ChoiceCV(iM,iC,iT) = iBalAcc(cvPred,choice.behTr2(okB));
			if any(choice.behTe==0) && any(choice.behTe==1)
				ChoiceTransfer(iM,iC,iT) = iBalAcc(tePred,choice.behTe);
			end
		end
	end
end

Metrics = struct( ...
	'CueCV',CueCV,'ChoiceCV',ChoiceCV,'ChoiceTransfer',ChoiceTransfer);
metricNames = fieldnames(Metrics);
PostMask = D.tVec>=0 & D.tVec<=1.5;
[~,idx1s] = min(abs(D.tVec-1));
nPermutation = 20000;
rng(20261102,'twister');
Stats = table();
for iMetric = 1:numel(metricNames)
	metricName = metricNames{iMetric};
	X = Metrics.(metricName);
	regions = {"Post mean","At +1 s"};
	for iRegion = 1:2
		if iRegion==1
			Y = mean(X(:,:,PostMask),3,'omitnan');
		else
			Y = X(:,:,idx1s);
		end
		for iC = 2:nC
			delta = Y(:,iC)-Y(:,1);
			valid = isfinite(delta);
			observed = mean(delta(valid));
			n = sum(valid);
			d = delta(valid);
			null = nan(nPermutation,1);
			for iP = 1:nPermutation
				signs = randi([0,1],n,1)*2-1;
				null(iP) = mean(d.*signs);
			end
			p = (1+sum(abs(null)>=abs(observed)))/(nPermutation+1);
			Stats = [Stats;table(string(metricName),regions(iRegion),conditionNames(iC), ...
				n,mean(Y(valid,1)),mean(Y(valid,iC)),observed,p, ...
				'VariableNames',{'Metric','Region','Window','N','SingleMean', ...
				'WindowMean','Delta','PairedSignFlipP'})]; %#ok<AGROW>
		end
	end
end
LocalTimeWindowDecoder = struct('Data',D,'HalfWidths',halfWidths, ...
	'ConditionNames',conditionNames,'Metrics',Metrics,'Stats',Stats, ...
	'PostMask',PostMask,'Index1s',idx1s,'NPermutation',nPermutation);
disp('=== Local temporal averaging versus single-time-point GLM ===');
disp(Stats);

for iMetric = 1:numel(metricNames)
	metricName = metricNames{iMetric};
	X = Metrics.(metricName);
	f = figure('Color','w','Name',metricName+" local time windows");
	f.Units='centimeters';
	f.Position(3:4)=[12,8];
	tl = tiledlayout(f,1,2,'TileSpacing','tight','Padding','tight');
	ax1 = nexttile(tl);
	hold(ax1,'on');
	for iC=1:nC
		iShaded(ax1,D.tVec,squeeze(X(:,iC,:)),iC);
	end
	xline(ax1,0,':','HandleVisibility','off');
	yline(ax1,0.5,':','HandleVisibility','off');
	ylabel(ax1,'Balanced accuracy');
	legend(ax1,conditionNames,'Box','off','Location','best');
	ax2 = nexttile(tl);
	hold(ax2,'on');
	Y = mean(X(:,:,PostMask),3,'omitnan');
	for iM=1:size(Y,1)
		plot(ax2,1:nC,Y(iM,:),'-','Color',[0.65 0.65 0.65], ...
			'HandleVisibility','off');
	end
	plot(ax2,1:nC,mean(Y,1,'omitnan'),'k.-','LineWidth',1.5,'HandleVisibility','off');
	xlim(ax2,[0.8,nC+0.2]);
	xticks(ax2,1:nC);
	xticklabels(ax2,conditionNames);
	ylabel(ax2,'Post-stimulus balanced accuracy');
	xlabel(tl,'Time from stimulus (s)');
	svgPath = TransferLearning.ExportStandardFigure(f,2, ...
		"English_Decoder_LocalTimeWindow_"+metricName+".svg");
	fprintf('Wrote: %s\n',svgPath);
end
assignin('base','LocalTimeWindowDecoder',LocalTimeWindowDecoder);

function idx = iLocalWindow(tVec,iT,halfWidth)
lo = max(1,iT-floor(halfWidth/0.125+1e-9));
hi = min(numel(tVec),iT+floor(halfWidth/0.125+1e-9));
idx = lo:hi;
end

function [cvScore,cvPred,tePred] = iPairedGlm(X,y,Xte,K)
n = size(X,1);
perm = randperm(n);
foldSize = ceil(n/K);
cvScore = nan(n,1);
cvPred = nan(n,1);
for k=1:K
	te = false(n,1);
	idx = (k-1)*foldSize+1:min(k*foldSize,n);
	te(perm(idx)) = true;
	tr = ~te;
	if sum(y(te)==0)<1 || sum(y(te)==1)<1
		cvPred(te) = mode(y(tr));
		cvScore(te) = 2*cvPred(te)-1;
		continue;
	end
	bal = iBalanceTrain(y(tr));
	idxTr = find(tr);
	[cvScore(te),cvPred(te)] = iGlm(X(idxTr(bal),:),y(idxTr(bal)),X(te,:));
end
bal = iBalanceTrain(y);
[~,tePred] = iGlm(X(bal,:),y(bal),Xte);
end

function idx = iBalanceTrain(y)
i1 = find(y==1);
i0 = find(y==0);
n = min(numel(i1),numel(i0));
idx = [i1(randperm(numel(i1),n));i0(randperm(numel(i0),n))];
end

function [score,pred] = iGlm(Xtr,ytr,Xte)
m0 = mean(Xtr(ytr==0,:),1);
m1 = mean(Xtr(ytr==1,:),1);
s0 = std(Xtr(ytr==0,:),0,1);
s1 = std(Xtr(ytr==1,:),0,1);
sp = sqrt((s0.^2+s1.^2)/2);
sp(sp==0) = 1;
score = sum((Xte-m0).^2./(2*sp.^2)-(Xte-m1).^2./(2*sp.^2),2);
pred = double(score>=0);
end

function bal = iBalAcc(pred,label)
valid = isfinite(pred)&isfinite(label);
pred = pred(valid);
label = label(valid);
bal = (mean(pred(label==1)==1)+mean(pred(label==0)==0))/2;
end

function iShaded(ax,tVec,X,condition)
colors = lines(4);
mu = mean(X,1,'omitnan');
se = std(X,0,1,'omitnan')./sqrt(sum(isfinite(X),1));
fill(ax,[tVec(:);flipud(tVec(:))],[mu(:)+se(:);flipud(mu(:)-se(:))], ...
	colors(condition,:),'FaceAlpha',0.10,'EdgeColor','none','HandleVisibility','off');
plot(ax,tVec,mu,'Color',colors(condition,:),'LineWidth',1.2);
end
