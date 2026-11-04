% Dense local-window scan for diminishing returns of choice GLM decoding.
% Uses the same decoder and paired-fold logic as the previous comparison.
% Each center-time/window cell receives identical CV folds and class-balanced
% subsamples. Half-window is sampled from 0 to 1.5 s in 125-ms increments.
% Post-stimulus balanced accuracy is the primary endpoint. Peak and
% piecewise-linear breakpoint estimates are descriptive; paired sign-flip
% p values are computed for the maximum-mean window only.

rng(20261102,'twister');
D = TransferLearning.BuildCueChoiceDecoderData();
halfWidths = (0:12)'*0.125;
nW = numel(halfWidths);
nT = numel(D.tVec);
nM = numel(D.choice);
PostMask = D.tVec>=0 & D.tVec<=1.5;
ChoiceCV = nan(nM,nW,nT);
ChoiceTransfer = nan(nM,nW,nT);
for iM=1:nM
	fprintf('Dense window scan mouse %d/%d\n',iM,nM);
	R = D.choice{iM};
	okB = isfinite(R.behTr2);
	X = R.Xtr2(okB,:,:);
	y = R.behTr2(okB);
	Xte = R.Xte;
	yTe = R.behTe;
	perm = randperm(size(X,1));
	foldSize = ceil(size(X,1)/5);
	for iT=1:nT
		[maxBack,maxForward] = iMaxRadius(D.tVec,iT);
		% Keep the number of samples at every time center identical across
		% conditions, including the truncated window centered at t=0.
		for iW=1:nW
			r = round(halfWidths(iW)/0.125);
			idx = iT-min(r,maxBack):iT+min(r,maxForward);
			F = mean(X(:,:,idx),3);
			Fte = mean(Xte(:,:,idx),3);
			[cvPred,tePred] = iPairedGlm(F,y,Fte,perm,foldSize);
			ChoiceCV(iM,iW,iT) = iBalAcc(cvPred,y);
			if any(yTe==0) && any(yTe==1)
				ChoiceTransfer(iM,iW,iT) = iBalAcc(tePred,yTe);
			end
		end
	end
end

Curve = table();
for iW=1:nW
	for stage=["ChoiceCV","ChoiceTransfer"]
		if stage=="ChoiceCV"
			X = ChoiceCV;
		else
			X = ChoiceTransfer;
		end
		post = mean(X(:,iW,PostMask),3,'omitnan');
		Curve = [Curve;table(stage,halfWidths(iW),2*halfWidths(iW)+0.125, ...
			mean(post,'omitnan'),std(post,0,'omitnan')/sqrt(sum(isfinite(post))), ...
			'VariableNames',{'Stage','HalfWidth','TotalWindow','Mean','SEM'})]; %#ok<AGROW>
	end
end
Breaks = table();
for stage=["ChoiceCV","ChoiceTransfer"]
	Y = Curve.Mean(Curve.Stage==stage);
	if stage=="ChoiceCV"
		X = ChoiceCV;
	else
		X = ChoiceTransfer;
	end
	x = halfWidths;
	[~,iPeak] = max(Y);
	% Descriptive knee: fit two joined lines over 0..peak, with the first
	% segment constrained to one half-window. Report only if at least three
	% grid points lie on each side of the breakpoint.
	candidates = (3:(iPeak-2))';
	if isempty(candidates)
		knee = NaN;
	else
		sse = inf(numel(candidates),1);
		for j=1:numel(candidates)
			k = candidates(j);
			X = [ones(iPeak,1),x(1:iPeak),max(x(1:iPeak)-x(k),0)];
			b = X\Y(1:iPeak);
			sse(j) = sum((Y(1:iPeak)-X*b).^2);
		end
		[~,j] = min(sse);
		knee = x(candidates(j));
	end
	if stage=="ChoiceCV"
		X = ChoiceCV;
	else
		X = ChoiceTransfer;
	end
	post = mean(X(:,iPeak,PostMask),3,'omitnan');
	base = mean(X(:,1,PostMask),3,'omitnan');
	d = post-base;
	valid = isfinite(d);
	d = d(valid);
	n = numel(d);
	observed = mean(d);
	nPermutation = 20000;
	null = nan(nPermutation,1);
	for iP=1:nPermutation
		null(iP) = mean(d.*(randi([0,1],n,1)*2-1));
	end
	p = (1+sum(abs(null)>=abs(observed)))/(nPermutation+1);
	Breaks = [Breaks;table(stage,x(iPeak),2*x(iPeak)+0.125,Y(iPeak),knee, ...
		mean(base),observed,n,p,'VariableNames',{'Stage','PeakHalfWidth', ...
		'PeakTotalWindow','PeakMean','DescriptiveKnee','SingleMean', ...
		'PeakMinusSingle','N','PeakVsSingleP'})]; %#ok<AGROW>
end
WindowMarginalReturns = struct('Data',D,'HalfWidths',halfWidths, ...
	'PostMask',PostMask,'ChoiceCV',ChoiceCV,'ChoiceTransfer',ChoiceTransfer, ...
	'Curve',Curve,'Breaks',Breaks);
disp('=== Window scan: peak and descriptive marginal-return breakpoint ===');
disp(Breaks);
disp(Curve);
assignin('base','WindowMarginalReturns',WindowMarginalReturns);

f = figure('Color','w','Name','Local-window marginal returns');
f.Units='centimeters';
f.Position(3:4)=[6,8];
ax=axes(f);
hold(ax,'on');
colors=[0.15 0.45 0.75;0.85 0.33 0.10];
for i=1:2
	stage=["ChoiceCV","ChoiceTransfer"];
	Q=Curve(Curve.Stage==stage(i),:);
	errorbar(ax,Q.TotalWindow,Q.Mean,Q.SEM,'.-','Color',colors(i,:), ...
		'LineWidth',1.2,'DisplayName',stage(i));
end
xlabel(ax,'Full local window (s)');
ylabel(ax,'Post-stimulus balanced accuracy');
legend(ax,{'Choice CV','Choice Transfer'},'Box','off','Location','best');
box(ax,'off');
svgPath=TransferLearning.ExportStandardFigure(f,2, ...
	'English_Decoder_LocalTimeWindow_MarginalReturns.svg');
fprintf('Wrote: %s\n',svgPath);

function [back,forward]=iMaxRadius(tVec,iT)
back=iT-1;
forward=numel(tVec)-iT;
end

function [cvPred,tePred]=iPairedGlm(X,y,Xte,perm,foldSize)
n=size(X,1);
cvPred=nan(n,1);
for k=1:5
	te=false(n,1);
	idx=(k-1)*foldSize+1:min(k*foldSize,n);
	te(perm(idx))=true;
	tr=~te;
	if sum(y(te)==0)<1 || sum(y(te)==1)<1
		cvPred(te)=mode(y(tr));
		continue;
	end
	bal=iBalanceTrain(y(tr));
	idxTr=find(tr);
	[~,cvPred(te)]=iGlm(X(idxTr(bal),:),y(idxTr(bal)),X(te,:));
end
bal=iBalanceTrain(y);
[~,tePred]=iGlm(X(bal,:),y(bal),Xte);
end

function idx=iBalanceTrain(y)
i1=find(y==1);i0=find(y==0);n=min(numel(i1),numel(i0));
idx=[i1(randperm(numel(i1),n));i0(randperm(numel(i0),n))];
end

function [score,pred]=iGlm(Xtr,ytr,Xte)
m0=mean(Xtr(ytr==0,:),1);m1=mean(Xtr(ytr==1,:),1);
s0=std(Xtr(ytr==0,:),0,1);s1=std(Xtr(ytr==1,:),0,1);
sp=sqrt((s0.^2+s1.^2)/2);sp(sp==0)=1;
score=sum((Xte-m0).^2./(2*sp.^2)-(Xte-m1).^2./(2*sp.^2),2);
pred=double(score>=0);
end

function bal=iBalAcc(pred,label)
bal=(mean(pred(label==1)==1)+mean(pred(label==0)==0))/2;
end
