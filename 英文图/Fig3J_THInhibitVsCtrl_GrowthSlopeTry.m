% English Fig3J trial: use Fig3J top-panel sessions, but test group difference
% with the Fig1C growth-slope algorithm (per-mouse slope + ANCOVA).

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

ctrlSess = iSlopeSessionsFrom3J(CtrlDS, "Ctrl", "Transfer", "Final");
thSess = iSlopeSessionsFrom3J(THDS, "TH", "Transfer", "Final");
allSessions = [ctrlSess; thSess];

if isempty(allSessions)
	error('Fig3JTry:EmptyData', 'No valid sessions were retained from the Fig3J top-panel data path.');
end

allSessions = sortrows(allSessions, {'Group','Mouse','DateTime'});
allSessions = iAddSessionIndex(allSessions);
allSessions = iAddBaselinePerf(allSessions);
perMouse = iPerMouseSlope(allSessions);

xCtrl = perMouse.Slope(string(perMouse.Group) == "Ctrl");
xTH = perMouse.Slope(string(perMouse.Group) == "TH");
xCtrl = xCtrl(isfinite(xCtrl));
xTH = xTH(isfinite(xTH));

pAnnot = NaN;
Tm = perMouse(:, {'Mouse','Group','Slope','BaselinePerf'});
Tm.Mouse = categorical(string(Tm.Mouse));
Tm.Group = categorical(string(Tm.Group));
Tm.Slope = double(Tm.Slope);
Tm.BaselinePerf = double(Tm.BaselinePerf);
okM = isfinite(Tm.Slope) & isfinite(Tm.BaselinePerf) & ~isundefined(Tm.Group);
Tm = Tm(okM, :);
if ~isempty(Tm) && exist('fitlm', 'file')
	lmSimple = fitlm(Tm, 'Slope ~ 1 + Group + BaselinePerf');
	C = lmSimple.Coefficients;
	idx = find(strcmp(string(C.Properties.RowNames), 'Group_TH'), 1);
	if isempty(idx)
		idx = find(startsWith(string(C.Properties.RowNames), 'Group_'), 1);
	end
	if ~isempty(idx)
		pAnnot = C.pValue(idx);
	end
end

fprintf('Ctrl: %d mice for slope\n', numel(xCtrl));
fprintf('TH:   %d mice for slope\n', numel(xTH));
fprintf('Ctrl mean slope = %.6f\n', mean(xCtrl, 'omitnan'));
fprintf('TH   mean slope = %.6f\n', mean(xTH, 'omitnan'));
fprintf('Fig1C-style ANCOVA p = %.4g\n', pAnnot);

f = figure('Color','none', 'Name', 'Fig3J try growth slope');
set(f, 'Units', 'centimeters', 'Position', [5 5 4 4]);
set(f, 'PaperUnits', 'centimeters', 'PaperSize', [4 4], 'PaperPositionMode', 'auto');

Groups = struct('Ctrl', {xCtrl(:)}, 'TH', {xTH(:)});
[~, ~, Bars, ErrorBars] = UniExp.BarScatterCompare(Groups, false);
ax = gca;

ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
ax.XAxis.Visible = 'off';
ax.XTick = [];

for b = Bars(:)'
	b.LineWidth = 2;
	b.EdgeColor = 'none';
end
for eb = ErrorBars.Object(:)'
	eb.LineWidth = 2;
end

palette2 = [1, 0, 0; 0, 0, 1];
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = palette2;
	Bars.BarWidth = 0.5;
	Bars.FaceAlpha = 1/3;
end
ax.XLim = [0.5, 2.5];
title('Learning slope', 'FontSize', 12, 'FontWeight', 'normal');
ylabel('Slope', 'FontSize', 12);

if isfinite(pAnnot) && pAnnot < 0.05 && height(ErrorBars) >= 1
	Descriptors = table(ErrorBars.Object(1), "*", 'VariableNames', {'ObjectA','Text'});
	PL = MATLAB.Graphics.PLine(Descriptors);
	for pl = PL(:)'
		pl.LineWidth = 2;
	end
end
box off

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, 'English_Fig3J_THInhibitVsCtrl_GrowthSlopeTry.svg');
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig3J_GrowthSlopeTry_PerMouse', perMouse);
assignin('base', 'Fig3J_GrowthSlopeTry_AllSessions', allSessions);
assignin('base', 'Fig3J_GrowthSlopeTry_P', pAnnot);

function SessOut = iSlopeSessionsFrom3J(DS, groupName, phaseStart, phaseEnd)
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLW_NoMustWarn(DS, Sess);
Sess = iKeepPhaseRange(DS, Sess, phaseStart, phaseEnd);
if isempty(Sess)
	SessOut = iEmptySessionsTable();
	return;
end
Sess = sortrows(Sess, {'Mouse','DateTime'});

mice = unique(string(Sess.Mouse));
out = cell(numel(mice), 1);
for iM = 1:numel(mice)
	m = mice(iM);
	R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
	if height(R) < 2
		continue;
	end
	first100 = find(double(R.Performance) >= 1.0, 1, 'first');
	if ~isempty(first100) && first100 > 1
		R = R(1:first100-1, :);
	elseif ~isempty(first100) && first100 == 1
		continue;
	end
	if height(R) < 2
		continue;
	end
	R.Group = repmat(string(groupName), height(R), 1);
	out{iM} = R(:, {'Mouse','DateTime','Performance','Group'});
	end

out = out(~cellfun('isempty', out));
if isempty(out)
	SessOut = iEmptySessionsTable();
	return;
end
SessOut = vertcat(out{:});
end

function T = iEmptySessionsTable()
T = table(string.empty(0,1), NaT(0,1), nan(0,1), string.empty(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','Group'});
end

function T = iAddSessionIndex(T)
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','DateTime'});
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
T = sortrows(T, {'Group','Mouse','Session'});
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
T = sortrows(T, {'Group','Mouse','Session'});

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

perMouse = table(mice, group, slope, nSess, baselinePerf, 'VariableNames', {'Mouse','Group','Slope','NSessions','BaselinePerf'});
end

function Sess = iLightWaterSessions(DS)
blkCols = DS.Blocks.Properties.VariableNames;
hasMustWarn = ismember('MustWarn', blkCols);
if hasMustWarn
	Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	Blocks.MustWarn = string(Blocks.MustWarn);
else
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.MustWarn = repmat("", height(Blocks), 1);
end
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
Tr.BlockUID = uint64(Tr.BlockUID);
TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames',{'BlockUID','LWPerf'});
T = innerjoin(perfByBlock, Blocks, 'Keys','BlockUID');
keep = ismissing(T.MustWarn) | (T.MustWarn == "");
T = T(keep, :);
T = innerjoin(T, DT, 'Keys','DateTime');
[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
perf2 = splitapply(@(x) mean(double(x),'omitnan'), T.LWPerf, G2);
phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
Sess = table(mouse, dt, phase2, perf2, 'VariableNames',{'Mouse','DateTime','Phase','Performance'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut)
	return;
end
Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
Blocks.BlockUID = uint64(Blocks.BlockUID);
Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
Tr = DS.Trials(:, {'BlockUID','Stimulus'});
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
DT = DS.DateTimes(:,{'DateTime','Mouse','Phase'});
DT.DateTime = iNormDT(datetime(DT.DateTime));
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
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

function dt = iNormDT(dt)
try
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end