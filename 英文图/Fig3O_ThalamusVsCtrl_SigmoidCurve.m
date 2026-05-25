% English Fig3O: Thalamus inhibition vs Control sigmoid learning curves
%
% Data source follows English Fig3G:
% - Control: TransferLearning.AudioLightBaseline
% - Thalamus inhibited: TransferLearning.THInhibit + PO chemogenetic inhibition (behavior only)
%
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202602
%
% Execution:
%   TransferLearning.英文图3.O_ThalamusVsCtrl_SigmoidCurve

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "English_Fig3O_ThalamusVsCtrl_SigmoidCurve.svg";

%% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try, matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

%% --- 1) Load datasets (same as Fig3G)
CtrlDS = TransferLearning.AudioLightBaseline();
THDS   = TransferLearning.THInhibit();

%% --- 2) Query LightWater behavior blocks
Bc = iQueryLightWaterBlocks(CtrlDS);
Bt = iQueryLightWaterBlocks(THDS);
Bc.Group = repmat("Ctrl", height(Bc), 1);
Bt.Group = repmat("TH",   height(Bt), 1);

Bc.Mouse = string(Bc.Mouse);
Bt.Mouse = string(Bt.Mouse);
Bc.DateTime = iNormalizeDateTime(Bc.DateTime);
Bt.DateTime = iNormalizeDateTime(Bt.DateTime);

J = MATLAB.DataTypes.MergeTables(Bc, Bt);
J.Group = string(J.Group);

%% --- 3) Sessionize
vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Behavior','Performance','Group','Phase'}, 'stable');
Sess = iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);

sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});

%% --- 3b) Include PO chemogenetic inhibition into TH group (matching Fig3G)
poMatPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO.v1.mat";
try
	if exist(poMatPath, 'file')
		PO = UniExp.DataSet(poMatPath);
		POTable = PO.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater", Expression="溢出");
		if ~isempty(POTable)
			if ismember('Phase', POTable.Properties.VariableNames)
				POTable.Phase = string(POTable.Phase);
				POTable(POTable.Phase=="Recall", :) = [];
			end
			poSess = POTable(:, intersect(["Mouse","DateTime","Performance"], string(POTable.Properties.VariableNames), 'stable'));
			poSess.Mouse = string(poSess.Mouse);
			poSess.DateTime = iNormalizeDateTime(poSess.DateTime);
			poSess.Group = repmat("TH", height(poSess), 1);
			poSess = unique(poSess(:, ["Mouse","DateTime","Performance","Group"]), 'rows');
			sessionForSummary = [sessionForSummary; poSess]; %#ok<AGROW>
			sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});
		end
	end
catch
end

if isempty(sessionForSummary)
	error('English_Fig3O:EmptyData', 'No valid sessions found for Control/TH cohorts.');
end

%% --- 4) Build per-mouse performance matrices for sigmoid fitting
barSess = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});
barSess = iAddSessionIndex(barSess);

ctrlSess = barSess(barSess.Group == "Ctrl", :);
thSess = barSess(barSess.Group == "TH", :);
if isempty(ctrlSess) || isempty(thSess)
	error('English_Fig3O:MissingGroup', 'One or both groups are empty after preprocessing.');
end

ctrlPerf = iSessionTableToMatrix(ctrlSess);
thPerf = iSessionTableToMatrix(thSess);
if isempty(ctrlPerf) || isempty(thPerf)
	error('English_Fig3O:EmptyMatrix', 'One or both sigmoid matrices are empty.');
end

if size(thPerf, 2) > 14
	thPerf = thPerf(:, 1:14);
end

%% --- 5) Plot sigmoid curves
[fig, stats] = TransferLearning.PlotSigmoidLearningCurvePanels( ...
	ctrlPerf, thPerf, "Control", "Thalamus", "Control", "TH inhibited", ...
	FigureName="English Fig3O Thalamus vs Control sigmoid", ...
	FigureSizeCm=[9, 8], ...
	Scale=2, ...
	CurveColor=[0, 0, 0], ...
	ShowLegend=true, ...
	LegendPanel="B", ...
	NPermutation=10000, ...
	RngSeed=1);

try
	if ~isfolder(outDirUNC), mkdir(outDirUNC); end
catch
end
svgPath = TransferLearning.ExportStandardFigure(fig, 2, svgName);

fprintf('Wrote: %s\n', svgPath);
fprintf('Control sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f\n', ...
	stats.FitA.Lower, stats.FitA.Upper, stats.FitA.Slope, stats.FitA.Midpoint);
fprintf('TH sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f\n', ...
	stats.FitB.Lower, stats.FitB.Upper, stats.FitB.Slope, stats.FitB.Midpoint);
fprintf('Permutation slope difference p = %.4g\n', stats.ComparisonTable.PValueTwoSided(1));

assignin('base', 'English_Fig3O_SessionSummary', sessionForSummary);
assignin('base', 'English_Fig3O_BarSessions', barSess);
assignin('base', 'English_Fig3O_ControlPerfMatrix', ctrlPerf);
assignin('base', 'English_Fig3O_THPerfMatrix', thPerf);
assignin('base', 'English_Fig3O_SigmoidStats', stats);

function T = iQueryLightWaterBlocks(DS)
varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
try
	T = DS.TableQuery(varsTry, Stimulus="LightWater");
catch
	T = DS.TableQuery(varsFallback, Stimulus="LightWater");
end
if isempty(T)
	return;
end
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightWater", :);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if isdatetime(dt) && ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function S = iSessionizeByDateTime(T)
useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
if useBehavior
	T = T(:, {'Mouse','DateTime','Behavior','Phase','Group'});
else
	T = T(:, {'Mouse','DateTime','Performance','Phase','Group'});
end
T.Mouse = string(T.Mouse);
T.Group = string(T.Group);
T = sortrows(T, {'Group','Mouse','DateTime'});
if useBehavior
	val = double(T.Behavior);
else
	val = double(T.Performance);
end
[G, groupKeys, mouseKeys, dtKeys] = findgroups(T.Group, T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
S = table(groupKeys, mouseKeys, dtKeys, perf, phaseSession, 'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
end

function ph = iPickSessionPhase(phases)
phases = string(phases);
phases = phases(~ismissing(phases) & phases ~= "");
if isempty(phases)
	ph = "";
	return;
end
[u,~,ic] = unique(phases);
counts = accumarray(ic, 1);
[~,ix] = max(counts);
ph = u(ix);
end

function T = iAddSessionIndex(T)
T.Group = string(T.Group);
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Group','Mouse','DateTime'});
[G, ~] = findgroups(T.Group, T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function perfMatrix = iSessionTableToMatrix(T)
T = sortrows(T, {'Mouse','Session'});
mice = unique(string(T.Mouse), 'stable');
maxSession = max(double(T.Session), [], 'omitnan');
perfMatrix = nan(numel(mice), maxSession);
for iMouse = 1:numel(mice)
	rows = T.Mouse == mice(iMouse);
	sessIdx = double(T.Session(rows));
	perf = double(T.Performance(rows));
	valid = isfinite(sessIdx) & sessIdx >= 1 & isfinite(perf);
	perfMatrix(iMouse, sessIdx(valid)) = perf(valid);
end
end