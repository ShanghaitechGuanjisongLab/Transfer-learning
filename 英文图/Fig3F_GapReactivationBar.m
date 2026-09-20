% English Fig3F: transfer-day reactivation of the learned ensemble,
% No gap (AudioLightBaseline) vs 7-day gap (Vacation7)
%
% Reactivation probability P(transfer-active | learned), per mouse, from
% iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer (cells active at cue
% +1 s, > baseline -3..0 s mean + 3 sigma, in the learned audio-water block;
% transfer lane = first transfer light-water block; layers combined by
% learned-active cell counts, same as old Fig2N).
% Two groups are different mice (unpaired); for uniform reporting the PText
% is overwritten with the rank-sum p (same convention as Fig3C).
%
% Outputs (SVG):
%   - English_Fig3F_GapReactivationBar.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

CtrlDS = TransferLearning.AudioLightBaseline();
V7DS = TransferLearning.Vacation7();

RCtrl = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = CtrlDS, Source = "AudioLightBaseline", RequireHitMiss = false);
RV7 = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer( ...
	DataSet = V7DS, Source = "Vacation7", RequireHitMiss = false);
if isempty(RCtrl) || isempty(RV7)
	error('English_Fig3F:EmptyBuild', 'Empty rows from P(T|L) builder.');
end

RCtrl.Group = repmat("Control", height(RCtrl), 1);
RV7.Group = repmat("Vacation7", height(RV7), 1);
R = [RCtrl; RV7];
R.Mouse = string(R.Mouse);

% 层合并：按 learned-active 细胞数加权（与旧 Fig2N 相同）
n23 = R.NLearnedActive23;
n5 = R.NLearnedActive5;
n23(~isfinite(n23)) = 0;
n5(~isfinite(n5)) = 0;
w23 = n23 .* R.Prob23;
w5 = n5 .* R.Prob5;
w23(~isfinite(w23)) = 0;
w5(~isfinite(w5)) = 0;
nTotal = n23 + n5;
R.PTgivenL = (w23 + w5) ./ nTotal;
R.PTgivenL(nTotal == 0) = NaN;

reactCtrlMask = R.Group == "Control" & isfinite(R.PTgivenL);
reactV7Mask = R.Group == "Vacation7" & isfinite(R.PTgivenL);
xCtrl = R.PTgivenL(reactCtrlMask);
xV7 = R.PTgivenL(reactV7Mask);
nReactCellsCtrl = sum(nTotal(reactCtrlMask), 'omitnan');
nReactCellsV7 = sum(nTotal(reactV7Mask), 'omitnan');

fprintf('=== Fig3F: Reactivation P(T|L) ===\n');
fprintf('  No gap:    mice n=%d, learned-active cells n=%d, mean=%.4f sem=%.4f\n', ...
	numel(xCtrl), nReactCellsCtrl, mean(xCtrl), iSem(xCtrl));
fprintf('  7-day gap: mice n=%d, learned-active cells n=%d, mean=%.4f sem=%.4f\n', ...
	numel(xV7), nReactCellsV7, mean(xV7), iSem(xV7));
pReact = ranksum(xCtrl, xV7);
fprintf('  rank-sum p = %.4g\n', pReact);

colorCtrl = TransferLearning.TransferColor;
colorGap = TransferLearning.ColorB;

% 规范：只有 2 个 bar 的条形图宽度 ≤3 cm、高 4 cm
f = figure('Color', 'w', 'Name', 'English Fig3F gap reactivation bar');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperSize = [3, 4];
f.PaperPositionMode = 'auto';
ax = axes(f);
DataCell = {double(xCtrl(:)), double(xV7(:))};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);
ax.XTick = 1:2;
% 3 cm 宽下两标签会相接：加 3 个前导空格触发 MATLAB 自动旋转标签，免手工旋转
ax.XTickLabel = {'   No gap', '   7-day gap'};
ax.Color = 'none';
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	nB = numel(Bars.YData);
	Bars.CData = repmat([colorCtrl; colorGap], ceil(nB / 2), 1);
	Bars.CData = Bars.CData(1:nB, :);
else
	Bars(1).FaceColor = colorCtrl;
	Bars(2).FaceColor = colorGap;
end
for kB = 1:numel(Bars)
	Bars(kB).BarWidth = 0.5;
	Bars(kB).EdgeColor = 'none';
	Bars(kB).FaceAlpha = 1;
end
if istable(ErrorBars) && ~isempty(ErrorBars) && ismember('Object', ErrorBars.Properties.VariableNames)
	barColors = [colorCtrl; colorGap];
	for kE = 1:height(ErrorBars)
		eb = ErrorBars.Object(kE);
		if isgraphics(eb) && kE <= size(barColors, 1)
			eb.Color = barColors(kE, :);
		end
	end
end
if isfield(Optional, 'MultiCompare') && istable(Optional.MultiCompare)
	mc = Optional.MultiCompare;
	if ismember('PText', mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pt = mc.PText(ip);
			if isgraphics(pt)
				pt.String = TransferLearning.Style.iFormatPText(pReact);
				pt.Tag = 'PText';
			end
		end
	end
	if ismember('PLine', mc.Properties.VariableNames)
		for ip = 1:height(mc)
			pl = mc.PLine(ip);
			if isgraphics(pl)
				pl.Tag = 'PLine';
			end
		end
	end
end
ylabel(ax, 'P(T | L) at cue +1 s');
legend(ax, 'off');
box(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_Fig3F_GapReactivationBar.svg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3F_ReactivationStats', struct('xCtrl', xCtrl, 'xV7', xV7, 'pReact', pReact, 'nCellsCtrl', nReactCellsCtrl, 'nCellsV7', nReactCellsV7));

%% ========== local functions ==========
function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end
