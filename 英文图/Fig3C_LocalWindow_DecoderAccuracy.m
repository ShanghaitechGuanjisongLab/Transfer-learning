% English Fig3C: per-mouse cue pre/post decoding accuracy.
% Audio-water self-test combines 12-h and 7-d mice. Transfer accuracy is
% shown separately by interval. Only the 12-h versus 7-d transfer contrast
% is displayed; the annotation is the two-sided Wilcoxon rank-sum p value.
% Decoder inputs and trial-wise CV are identical to Fig3B (+/-250 ms mean).

S = load(TransferLearning.CachePath( ...
	'CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat'));
res = S.res;
audio = [];
audioMice = strings(0,1);
transfer12 = [];
transfer7 = [];
transfer12Mice = strings(0,1);
transfer7Mice = strings(0,1);
for i=1:numel(res)
	R = res{i};
	audio(end+1) = R.s1Acc; %#ok<AGROW>
	audioMice(end+1) = string(R.Mouse); %#ok<AGROW>
	if R.DS==1
		transfer12(end+1) = R.s2Acc; %#ok<AGROW>
		transfer12Mice(end+1) = string(R.Mouse); %#ok<AGROW>
	else
		transfer7(end+1) = R.s2Acc; %#ok<AGROW>
		transfer7Mice(end+1) = string(R.Mouse); %#ok<AGROW>
	end
end
pTransfer = ranksum(transfer12,transfer7);
%% 

f = figure('Color','w','Name','English Fig3C local-window decoder accuracy');
f.Units = 'centimeters';
f.Position(3:4) = [6,8];
colors = [TransferLearning.LearnedColor;TransferLearning.TransferColor;TransferLearning.TransferColor];
CompareGroup = table([2 3],'VariableNames',{'GroupPair'});
[~,Optional,Bars,ErrorBars] = UniExp.BarScatterCompare( ...
	{audio(:),transfer12(:),transfer7(:)},UniExp.Flags.empty, ...
	CompareGroup,UniExp.Flags.IndividualErrorbars,'AsteriskThreshold',0.05);
ax = gca;
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = colors;
	Bars.EdgeColor = 'none';
end
if istable(ErrorBars) && ismember('Object',ErrorBars.Properties.VariableNames)
	for i=1:height(ErrorBars)
		eb = ErrorBars.Object(i);
		if isgraphics(eb)
			eb.Color = colors(i,:);
		end
	end
end
if isfield(Optional,'MultiCompare') && istable(Optional.MultiCompare)
	MC = Optional.MultiCompare;
	assert(height(MC)==1 && isequal(MC.GroupPair(1,:),[2 3]), ...
		'Fig3C must contain only the 12-h versus 7-d comparison.');
	if ismember('PText',MC.Properties.VariableNames) && isgraphics(MC.PText(1))
		MC.PText(1).String = TransferLearning.Style.iFormatPText(pTransfer);
		MC.PText(1).Tag = 'PText_1';
	end
	if ismember('PLine',MC.Properties.VariableNames) && isgraphics(MC.PLine(1))
		MC.PLine(1).Tag = 'PLine_1';
	end
end
ax.XTick = 1:3;
ax.XTickLabel = {'Audio','12 h','7 d'};
ylabel(ax,'Decoding accuracy');
ax.Color = 'none';
svgPath = TransferLearning.ExportStandardFigure(f,2, ...
	'English_Fig3C_LocalWindow_DecoderAccuracy.svg');