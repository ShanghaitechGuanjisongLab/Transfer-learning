% THInhibitVsCtrl_learningslope
%
% Per-mouse learning slope comparison between Ctrl and TH-inhibited groups.
% Calculation follows the learning-slope definition used in Fig1C:
%   - use per-mouse LightWater session performance trajectory
%   - fit a first-order polynomial across session index
%   - plot raw slopes, annotate group effect p from ANCOVA with baseline
%
% Data source follows Fig3J_THInhibitVsCtrl_DeltaHitAndSD:
%   - Ctrl: TransferLearning.AudioLightBaseline()
%   - TH:   TransferLearning.THInhibit()
%   - LightWater-only sessions
%   - pure LightWater sessions only
%   - phase range: Transfer -> Final
%
% Output:
%   SVG to \\Data-Server-2\个人数据\杨青宁\202604

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202604';
svgName = "THInhibitVsCtrl_learningslope.svg";

%% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet', 'class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
		if exist(prjFile, 'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

%% --- 1) Load datasets (same source as Fig3J)
CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

%% --- 2) Build session tables
ctrlSess = iBuildCohortSessions(CtrlDS, "Ctrl", "Transfer", "Final");
thSess = iBuildCohortSessions(THDS, "TH", "Transfer", "Final");
allSess = [ctrlSess; thSess];

if isempty(allSess)
	warning('THInhibitVsCtrlLearningSlope:EmptyData', 'No valid LightWater sessions found for Ctrl/TH cohorts.');
	return;
end

allSess = sortrows(allSess, {'Group', 'Mouse', 'DateTime'});
allSess = iAddSessionIndex(allSess);
allSess = iAddBaselinePerf(allSess);

perMouse = iPerMouseSlope(allSess);
if isempty(perMouse)
	warning('THInhibitVsCtrlLearningSlope:EmptySlope', 'No mice with enough sessions to compute learning slope.');
	return;
end

%% --- 3) Raw slope vectors and ANCOVA p-value
xCtrl = perMouse.Slope(string(perMouse.Group) == "Ctrl");
xTH = perMouse.Slope(string(perMouse.Group) == "TH");
xCtrl = xCtrl(isfinite(xCtrl));
xTH = xTH(isfinite(xTH));

pAnnot = NaN;
Tm = perMouse(:, {'Mouse', 'Group', 'Slope', 'BaselinePerf'});
Tm.Mouse = categorical(string(Tm.Mouse));
Tm.Group = categorical(string(Tm.Group));
Tm.Slope = double(Tm.Slope);
Tm.BaselinePerf = double(Tm.BaselinePerf);
okM = isfinite(Tm.Slope) & isfinite(Tm.BaselinePerf) & ~isundefined(Tm.Group);
Tm = Tm(okM, :);
if ~isempty(Tm)
	try
		lmSimple = fitlm(Tm, 'Slope ~ 1 + Group + BaselinePerf');
		C = lmSimple.Coefficients;
		idx = find(strcmp(string(C.Properties.RowNames), 'Group_TH'), 1);
		if isempty(idx)
			idx = find(startsWith(string(C.Properties.RowNames), 'Group_'), 1);
		end
		if ~isempty(idx)
			pAnnot = C.pValue(idx);
		end
	catch
	end
end

fprintf('Ctrl: %d mice, slope = %.4f ± %.4f\n', numel(xCtrl), mean(xCtrl, 'omitnan'), std(xCtrl, 'omitnan') / sqrt(max(numel(xCtrl), 1)));
fprintf('TH:   %d mice, slope = %.4f ± %.4f\n', numel(xTH), mean(xTH, 'omitnan'), std(xTH, 'omitnan') / sqrt(max(numel(xTH), 1)));
fprintf('ANCOVA p = %.4g\n', pAnnot);

%% --- 4) Plot (style aligned to Fig1C / Fig3J)
Groups = struct('Ctrl', {xCtrl(:)}, 'TH', {xTH(:)});

f = figure('Color', 'none', 'Name', 'THInhibitVsCtrl learning slope');
set(f, 'InvertHardcopy', 'off');
set(f, 'Units', 'centimeters', 'Position', [5 5 8.2 5.4]);
set(f, 'PaperUnits', 'centimeters', 'PaperSize', [8.2 5.4], 'PaperPositionMode', 'auto');

[~, ~, Bars, ErrorBars] = UniExp.BarScatterCompare(Groups, false);
ax = gca;

ax.FontSize = 12;
ax.LineWidth = 0.75 / 0.3528;
ax.Color = 'none';
ax.XAxis.Visible = 'on';
ax.XTick = [1 2];
ax.XTickLabel = {'Ctrl', 'TH inhibition'};
ax.XTickLabelRotation = 0;
ax.XLim = [0.5, 2.5];
title('');
ylabel('Learning slope', 'FontSize', 12);
ax.Position = [0.24 0.18 0.54 0.72];
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 0.75 / 0.3528;
	ax.YAxis.LineWidth = 0.75 / 0.3528;
end

for b = Bars(:)'
	b.LineWidth = 2;
	b.EdgeColor = 'none';
end

colorCtrl = [1, 0, 0];
colorTH = [0, 0, 1];
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = [colorCtrl; colorTH];
	Bars.BarWidth = 0.45;
	Bars.FaceAlpha = 1/3;
end
semVals = [];
if ~isempty(ErrorBars.Object)
	for iEB = 1:numel(ErrorBars.Object)
		ErrorBars.Object(iEB).Visible = 'off';
		if isempty(semVals)
			try
				semVals = ErrorBars.Object(iEB).YPositiveDelta;
			catch
			end
		end
	end
end
if isempty(semVals)
	semVals = [std(xCtrl, 'omitnan') / sqrt(max(numel(xCtrl), 1)), std(xTH, 'omitnan') / sqrt(max(numel(xTH), 1))];
end
if isscalar(Bars)
	xPos = double(Bars.XEndPoints(1:2));
	yPos = double(Bars.YEndPoints(1:2));
	capHalfWidth = 0.06;
	hold(ax, 'on');
	for iBar = 1:2
		if iBar == 1
			thisColor = colorCtrl;
		else
			thisColor = colorTH;
		end
		yTop = yPos(iBar) + semVals(iBar);
		plot(ax, [xPos(iBar) xPos(iBar)], [yPos(iBar) yTop], '-', 'Color', [thisColor, 1/3], 'LineWidth', 2);
		plot(ax, [xPos(iBar) - capHalfWidth, xPos(iBar) + capHalfWidth], [yTop yTop], '-', 'Color', [thisColor, 1/3], 'LineWidth', 2);
	end
end

if isfinite(pAnnot)
	if pAnnot < 0.001
		pLabel = 'p < 0.001';
	elseif pAnnot < 0.01
		pLabel = sprintf('p = %.3f', pAnnot);
	else
		pLabel = sprintf('p = %.2f', pAnnot);
	end
else
	pLabel = 'p = NaN';
end
annotation(f, 'textbox', [0.485 0.92 0.14 0.04], 'String', pLabel, 'FitBoxToText', 'on', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'LineStyle', 'none', ...
	'FontSize', 11, 'Color', [0.13 0.13 0.13]);
box off

%% --- 5) Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'THInhibitVsCtrlLearningSlope_Sessions', allSess);
assignin('base', 'THInhibitVsCtrlLearningSlope_PerMouse', perMouse);
assignin('base', 'THInhibitVsCtrlLearningSlope_P', pAnnot);

function Sess = iBuildCohortSessions(DS, groupName, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), string.empty(0,1), ...
		'VariableNames', {'Mouse', 'DateTime', 'Phase', 'Performance', 'Group'});
	return;
end
Sess.Group = repmat(string(groupName), height(Sess), 1);
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
end

function Sess = iLightWaterSessions(DS)
blkCols = string(DS.Blocks.Properties.VariableNames);
if any(blkCols == "MustWarn")
	Blocks = DS.Blocks(:, {'BlockUID', 'DateTime', 'MustWarn'});
else
	Blocks = DS.Blocks(:, {'BlockUID', 'DateTime'});
	Blocks.MustWarn = strings(height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Blocks.MustWarn = string(Blocks.MustWarn);

DT = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);

Tr = DS.Trials(:, {'BlockUID', 'Stimulus', 'Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID', 'Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse', 'DateTime', 'Phase', 'Performance'});
	return;
end

[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID', 'LWPerf'});

T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys', 'DateTime');

[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse', 'DateTime', 'Phase', 'Performance'});
Sess = sortrows(Sess, {'Mouse', 'DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end

Blocks = DS.Blocks(:, {'BlockUID', 'DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));

Tr = DS.Trials(:, {'BlockUID', 'Stimulus'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
if isempty(TrAW)
	return;
end

blkAW = unique(uint64(TrAW.BlockUID));
TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
dtAW = unique(TAW.DateTime);
SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
SessOut = SessIn;
if isempty(SessOut)
	return;
end

DT = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
phaseStart = string(phaseStart);
phaseEnd = string(phaseEnd);

mice = unique(string(SessOut.Mouse));
keep = false(height(SessOut), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	dtM = DT(DT.Mouse == m, :);
	phDates = dtM.DateTime(dtM.Phase == phaseStart);
	endDates = dtM.DateTime(dtM.Phase == phaseEnd);
	if isempty(phDates) || isempty(endDates)
		continue;
	end
	startDT = min(phDates);
	endDT = max(endDates);
	if ismissing(startDT) || ismissing(endDT)
		continue;
	end
	rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
	keep = keep | rows;
	end
SessOut = SessOut(keep, :);
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group', 'Mouse', 'DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
T.Session = zeros(height(T), 1);
ug = unique(G);
for gi = 1:numel(ug)
	rows = (G == ug(gi));
	T.Session(rows) = (1:sum(rows)).';
end
end

function T = iAddBaselinePerf(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group', 'Mouse', 'Session'});
T.BaselinePerf = nan(height(T), 1);
[G, ~] = findgroups(T.Group, T.Mouse);
ug = unique(G);
for gi = 1:numel(ug)
	rows = (G == ug(gi));
	p = double(T.Performance(rows));
	b0 = p(1);
	if ~isfinite(b0)
		b0 = mean(p, 'omitnan');
	end
	T.BaselinePerf(rows) = b0;
end
end

function perMouse = iPerMouseSlope(allSessions)
T = allSessions;
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group', 'Mouse', 'Session'});

[mice, ~, g] = unique(T.Mouse);
group = strings(numel(mice), 1);
slope = nan(numel(mice), 1);
nSess = nan(numel(mice), 1);
baselinePerf = nan(numel(mice), 1);

for i = 1:numel(mice)
	rows = (g == i);
	group(i) = string(T.Group(find(rows, 1, 'first')));
	x = double(T.Session(rows));
	y = double(T.Performance(rows));
	b0 = y(1);
	if ~isfinite(b0)
		b0 = mean(y, 'omitnan');
	end
	baselinePerf(i) = b0;
	ok = isfinite(x) & isfinite(y);
	x = x(ok);
	y = y(ok);
	nSess(i) = numel(x);
	if numel(x) < 2
		continue;
	end
	p = polyfit(x, y, 1);
	slope(i) = p(1);
end

perMouse = table(mice, group, slope, nSess, baselinePerf, 'VariableNames', {'Mouse', 'Group', 'Slope', 'NSessions', 'BaselinePerf'});
end

function dt = iNormDT(dt)
try
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end