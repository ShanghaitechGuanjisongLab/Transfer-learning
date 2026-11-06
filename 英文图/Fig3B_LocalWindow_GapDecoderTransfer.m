% English Fig3B: interval-dependent cue-response decoding with local averaging.
% Three tiles: pooled AudioWater self-test (12-h and 7-d mice combined),
% followed by 12-h and 7-d held-out LightWater transfer. Every mouse keeps
% its own AudioWater-trained decoder; only the per-mouse OOF curves are pooled
% for the AudioWater display.
%
% Feature window: centered +/-250 ms local mean (5 samples at 125-ms spacing),
% truncated only at the boundaries of the displayed [-1.5,+1.5] s time range.
% This is an actual decoder input change, not post-hoc smoothing of P(post).
% Training windows are widened from [-1,0] to [-1.25,+0.25] s for pre and
% from [0,1] to [-0.25,+1.25] s for post, consistent with local averaging.
%
% Decoder, data anchors, trial-wise CV, and 200 label-shuffled nulls follow
% TransferLearning.DecodeCuePrePostTransfer / original Fig3D. The original
% vtf0353 exclusion is preserved. No null curve or significance is displayed.
%
% Run as a script in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(thisDir,'..','Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end
rng(42,'twister');

halfWindow = 0.250;
nPermutation = 200;
cacheName = 'CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat';
matPath = TransferLearning.CachePath(cacheName);
if isfile(matPath)
	S = load(matPath);
else
	S = iBuildResults(halfWindow,nPermutation);
	save(matPath,'-struct','S');
end
tVec = S.tVec;
res = S.res;
groupNames = ["12 h","7 d"];
readoutNames = ["Audio-water self","Light-water transfer"];


curves = cell(2,2);
nulls = cell(2,2);
accuracy = cell(2,2);
mouseNames = cell(2,1);
for iDS=1:2
	rowsSelf = [];
	rowsTransfer = [];
	nullSelf = [];
	nullTransfer = [];
	accSelf = [];
	accTransfer = [];
	mice = strings(0,1);
	for i=1:numel(res)
		R = res{i};
		if R.DS~=iDS
			continue;
		end
		rowsSelf = [rowsSelf;R.pPostS1T(:)']; %#ok<AGROW>
		rowsTransfer = [rowsTransfer;R.pPostByT(:)']; %#ok<AGROW>
		nullSelf = [nullSelf;R.null95S1(:)']; %#ok<AGROW>
		nullTransfer = [nullTransfer;R.null95(:)']; %#ok<AGROW>
		accSelf(end+1) = R.s1Acc; %#ok<AGROW>
		accTransfer(end+1) = R.s2Acc; %#ok<AGROW>
		mice(end+1) = string(R.Mouse); %#ok<AGROW>
	end
	curves(:,iDS) = {rowsSelf;rowsTransfer};
	nulls(:,iDS) = {nullSelf;nullTransfer};
	accuracy(:,iDS) = {accSelf;accTransfer};
	mouseNames{iDS} = mice;
end

fprintf('=== Fig3B: +/-250 ms local-mean cue pre/post decoder ===\n');
pTransferAccuracy = ranksum(accuracy{2,1},accuracy{2,2});
fprintf('Pooled AudioWater self: n=%d, accuracy=%.3f\n', ...
	numel([accuracy{1,1},accuracy{1,2}]),mean([accuracy{1,1},accuracy{1,2}]));
fprintf('Transfer accuracy, 12 h versus 7 d: rank-sum p=%.4g\n',pTransferAccuracy);

plotCurves = {[curves{1,1};curves{1,2}],curves{2,1},curves{2,2}};
plotNames = {"Audio-water self","12 h","7 d"};
%% 
plotColors = [TransferLearning.ColorLearned;TransferLearning.Color12h;TransferLearning.Color7d] / 255;

f = figure('Color','w','Name','English Fig3B local-window gap decoder');
f.Units = 'centimeters';
f.Position(3:4) = [6,4];
Layout = tiledlayout(f,1,3,'TileSpacing','tight','Padding','tight');
Ax = gobjects(1,3);
for i=1:3
	ax = nexttile(Layout);
	hold(ax,'on');
	V = plotCurves{i};
	mn = mean(V,1,'omitnan');
	se = zeros(1,numel(tVec));
	for iT=1:numel(tVec)
		se(iT) = iSem(V(:,iT));
	end
	iShadedError(ax,tVec,mn,se,plotColors(i,:),1.2,'P(post)');
	yline(ax,0.5,':','Color',[0.75 0.75 0.75], ...
		'LineWidth',0.6,'HandleVisibility','off');
	xline(ax,0,'--','Color',[0.35 0.35 0.35], ...
		'LineWidth',0.8,'HandleVisibility','off');
	title(ax,plotNames(i),'FontSize',8,'FontWeight','normal');
	if i>1
		ax.YAxis.Visible = 'off';
	end
	legend(ax,'off');
	ax.Color = 'none';
	box(ax,'off');
	if isprop(ax,'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
	Ax(i) = ax;
end
xlabel(Layout,'Time from cue onset (s)');
ylabel(Layout,'P(post)');
TransferLearning.ApplyStandardExportStyle(f,2);
MATLAB.Graphics.UnifyAxesLims(Ax(:),@xlim,@ylim);
for iA=1:numel(Ax)
	xlim(Ax(iA),[-1.5 1.5]);
end
svgPath = TransferLearning.ExportStandardFigure(f,1, ...
	'English_Fig3B_LocalWindow_GapDecoderTransfer.svg');
fprintf('Wrote: %s\n',svgPath);
Fig3B_LocalWindowDecoderStats = struct('curves',{curves},'nulls',{nulls}, ...
	'accuracy',{accuracy},'mouseNames',{mouseNames}, ...
	'pTransferAccuracy',pTransferAccuracy,'halfWindow',halfWindow, ...
	'tVec',tVec,'nPermutation',nPermutation);
assignin('base','Fig3B_LocalWindowDecoderStats',Fig3B_LocalWindowDecoderStats);

function S = iBuildResults(halfWindow,nPermutation)
DSs = {TransferLearning.AudioLightBaseline(),TransferLearning.Vacation7()};
xs = seconds(TransferLearning.Xs);
tIdx = find(xs>=-1.5 & xs<=1.5);
tVec = xs(tIdx);
radius = round(halfWindow/median(diff(xs)));
tPre = (xs>=-1-halfWindow)&(xs<=halfWindow);
tPost = (xs>=-halfWindow)&(xs<=1+halfWindow);
excludeMice = "vtf0353";
tasks = {};
for iDS=1:2
	DS = DSs{iDS};
	Blk = DS.Blocks;
	Blk.Design = string(Blk.Design);
	Blk.BlockUID = uint64(Blk.BlockUID);
	DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
	DT.DateTime = iDateTime(DT.DateTime);
	DT.Mouse = string(DT.Mouse);
	DT.Phase = string(DT.Phase);
	blkDT = iDateTime(Blk.DateTime);
	ph = strings(height(Blk),1);
	mo = strings(height(Blk),1);
	for i=1:height(Blk)
		j = find(DT.DateTime==blkDT(i),1);
		if ~isempty(j)
			ph(i) = DT.Phase(j);
			mo(i) = DT.Mouse(j);
		end
	end
	Blk.Phase = ph;
	Blk.Mouse = mo;
	mice = setdiff(unique(DT.Mouse)',excludeMice);
	for m=mice
		awBlocks = Blk.BlockUID(Blk.Design=="AudioWater" & ...
			Blk.Phase=="Learned" & Blk.Mouse==m);
		if isempty(awBlocks)
			continue;
		end
		awT = iQueryZScoreNts(DS,m,'AudioWater');
		if isempty(awT)
			continue;
		end
		trTbl = awT(ismember(uint64(awT.BlockUID),awBlocks) & ~isnan(awT.Behavior),:);
		if isempty(trTbl)
			continue;
		end
		lwBlocks = Blk.BlockUID(Blk.Design=="LightWater" & ...
			Blk.Phase=="Transfer" & Blk.Mouse==m);
		if isempty(lwBlocks)
			continue;
		end
		lwT = iQueryZScoreNts(DS,m,'LightWater');
		if isempty(lwT)
			continue;
		end
		teTbl = lwT(ismember(uint64(lwT.BlockUID),lwBlocks),:);
		if isempty(teTbl)
			continue;
		end
		cu = intersect(unique(uint64(trTbl.CellUID)),unique(uint64(teTbl.CellUID)));
		if numel(cu)<5
			continue;
		end
		XTr = iBuildTrialMatrix(trTbl,cu);
		XTe = iBuildTrialMatrix(teTbl,cu);
		if isempty(XTr)||isempty(XTe)
			continue;
		end
		preTr = mean(XTr(:,:,tPre),3);
		postTr = mean(XTr(:,:,tPost),3);
		preTe = mean(XTe(:,:,tPre),3);
		postTe = mean(XTe(:,:,tPost),3);
		tasks{end+1} = struct('DS',iDS,'Mouse',char(m),'NCells',numel(cu), ...
			'CellUIDs',cu,'preTr',preTr,'postTr',postTr,'preTe',preTe, ...
			'postTe',postTe,'XTrT',iLocalMean(XTr(:,:,tIdx),radius), ...
			'XTeT',iLocalMean(XTe(:,:,tIdx),radius)); %#ok<AGROW>
	end
end
fprintf('Local-window decoder: %d mouse/cohort units\n',numel(tasks));
res = cell(numel(tasks),1);
for i=1:numel(tasks)
	fprintf('Decoding %d/%d: %s\n',i,numel(tasks),tasks{i}.Mouse);
	rng(42+i,'twister');
	res{i} = TransferLearning.DecodeCuePrePostTransfer(tasks{i},tVec,nPermutation);
end
S = struct('res',{res},'tasks',{tasks},'tVec',tVec, ...
	'halfWindow',halfWindow,'nPermutation',nPermutation,'excludeMice',excludeMice);
end

function T = iQueryZScoreNts(DS,mouse,stimulus)
T = DS.TableQuery(["ResampledSignal","CellUID","TrialUID","Behavior","BlockUID"], ...
	struct('Mouse',mouse,'Stimulus',stimulus));
if isempty(T)
	return;
end
S = T.ResampledSignal;
if iscell(S)
	S = double(vertcat(S{:}));
else
	S = double(S);
end
bad = any(isnan(S),2)|all(S==0,2);
T(bad,:) = [];
S(bad,:) = [];
if isempty(T)
	return;
end
mu = mean(S,2);
sd = std(S,0,2);
sd(sd==0) = 1;
T.TrialSignal = (S-mu)./sd;
T.CellUID = uint64(T.CellUID);
T.TrialUID = uint64(T.TrialUID);
end

function X = iBuildTrialMatrix(T,cu)
tu = unique(T.TrialUID);
sig = T.TrialSignal;
X = zeros(numel(tu),numel(cu),size(sig,2));
for i=1:height(T)
	[tf,ci] = ismember(T.CellUID(i),cu);
	[tf2,ti] = ismember(T.TrialUID(i),tu);
	if tf&&tf2
		X(ti,ci,:) = sig(i,:);
	end
end
end

function Y = iLocalMean(X,radius)
Y = zeros(size(X));
for i=1:size(X,3)
	idx = max(1,i-radius):min(size(X,3),i+radius);
	Y(:,:,i) = mean(X(:,:,idx),3);
end
end

function dt = iDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function s = iSem(v)
v = v(:);
v = v(isfinite(v));
if isempty(v)
	s = NaN;
else
	s = std(v)/sqrt(numel(v));
end
end

function iShadedError(ax,x,mn,se,col,lw,dn)
x = x(:)';
mn = mn(:)';
se = se(:)';
ok = isfinite(mn)&isfinite(se);
x = x(ok);mn = mn(ok);se = se(ok);
fill(ax,[x fliplr(x)],[mn+se fliplr(mn-se)],col, ...
	'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
plot(ax,x,mn,'-','Color',col,'LineWidth',lw,'DisplayName',dn);
end

