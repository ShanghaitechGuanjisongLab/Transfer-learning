% English Fig3C: 12-h versus 7-d overall transfer decoding accuracy.
%
% Data are per-mouse held-out LightWater accuracy (s2Acc) from the Fig3B
% cache, generated with the +/-250 ms local-mean cue decoder. The cohorts
% contain different mice; use a two-sided Wilcoxon rank-sum test.
% Bar-scatter layout follows Fig2E_HitMissOutcomeSelectivity.m.
%
% Run as a script in MATLAB Editor.
%
% Run as a script in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

cacheName = 'CueModel_LocalWindow250ms_TransferAudioToLight_Results.mat';
S = load(TransferLearning.CachePath(cacheName));
accuracy12h = [];
accuracy7d = [];
mouse12h = strings(0,1);
mouse7d = strings(0,1);
for i = 1:numel(S.res)
	R = S.res{i};
	if R.DS == 1
		accuracy12h(end+1,1) = R.s2Acc; %#ok<AGROW>
		mouse12h(end+1,1) = string(R.Mouse); %#ok<AGROW>
	elseif R.DS == 2
		accuracy7d(end+1,1) = R.s2Acc; %#ok<AGROW>
		mouse7d(end+1,1) = string(R.Mouse); %#ok<AGROW>
	end
end
assert(all(isfinite(accuracy12h)) && all(isfinite(accuracy7d)), ...
	'Fig3C:InvalidAccuracy', 'Overall accuracy must be finite for every included mouse.');
p = ranksum(accuracy12h,accuracy7d);
%% 

f = figure('Color','w','Name','English Fig3C overall transfer decoding accuracy');
f.Units = 'centimeters';
f.Position(3:4) = [3,4];

ax = axes(f);
color12h = TransferLearning.Color12h / 255;
color7d = TransferLearning.Color7d / 255;
DataCell = {accuracy12h,accuracy7d};
CompareGroup = table([1 2],'VariableNames',{'GroupPair'});
[~,Optional,Bars,ErrorBars] = UniExp.BarScatterCompare(DataCell, ...
	UniExp.Flags.empty,CompareGroup,UniExp.Flags.IndividualErrorbars, ...
	'AsteriskThreshold',0.05);
set(ax,'XTick',[1 2],'XTickLabel',{'12 h','7 d'});
ylabel(ax,'Transfer decoding accuracy');
barColors = [color12h;color7d];
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	barCData = repmat(barColors,ceil(nB/2),1);
	Bars.CData = barCData(1:nB,:);
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1;
	Bars.BarWidth = 0.5;
else
	for kB = 1:numel(Bars)
		Bars(kB).FaceColor = barColors(kB,:);
		Bars(kB).EdgeColor = 'none';
		Bars(kB).FaceAlpha = 1;
		Bars(kB).BarWidth = 0.5;
	end
end
if istable(ErrorBars) && ~isempty(ErrorBars) && ismember('Object',ErrorBars.Properties.VariableNames)
	for kE = 1:height(ErrorBars)
		eb = ErrorBars.Object(kE);
		if isgraphics(eb) && kE <= size(barColors,1)
			eb.Color = barColors(kE,:);
		end
	end
end
% The internal test and the displayed test are both unpaired; report the
% explicitly computed two-sided Wilcoxon rank-sum p value.
if isfield(Optional,'MultiCompare') && istable(Optional.MultiCompare)
	mc = Optional.MultiCompare;
	if ismember('PText',mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pt = mc.PText(ip);
			if isgraphics(pt)
				pt.String = TransferLearning.Style.iFormatPText(p);
				pt.Tag = 'PText';
			end
		end
	end
	if ismember('PLine',mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pl = mc.PLine(ip);
			if isgraphics(pl)
				pl.Tag = 'PLine';
			end
		end
	end
end
legend(ax,'off');
box(ax,'off');
ax.Color = 'none';

svgPath = TransferLearning.ExportStandardFigure(f,1, ...
	'English_Fig3C_LocalWindow_DecoderAccuracy_12hVs7d.svg');

function s = iSem(v)
v = v(isfinite(v));
s = std(v)/sqrt(numel(v));
end
