% LearningCurveCompare
%
% 独立统计脚本：比较 TH inhibited 与 Control 两条 LightWater 学习曲线是否存在显著差异。
%
% 设计原则：
% 1) 不修改任何已存在的作图代码。
% 2) 复用英文图3G的数据来源与分组口径：
%    - Control: TransferLearning.AudioLightBaseline
%    - TH:      TransferLearning.THInhibit + PO 化学遗传抑制（纯行为）
% 3) 主分析使用混合效应模型：Performance ~ Block*Group + (1|Mouse)
%    - Group 主效应：两组总体表现是否不同
%    - Block 主效应：整体是否随 block 学习
%    - Block:Group 交互：两组学习过程/斜率是否不同
% 4) 补充输出第一 block 的非配对 ranksum 检验，便于与图中 inset 对照。
%
% 输出目录：\\Data-Server-2\个人数据\杨青宁\202604\
% 输出文件：
%   - LearningCurveCompare_SessionTable.csv
%   - LearningCurveCompare_GroupCurveSummary.csv
%   - LearningCurveCompare_Stats.txt
%   - LearningCurveCompare_ModelCoefficients.csv
%
% 运行方式：在 MATLAB 编辑器中打开本脚本后直接运行（F5）。

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202604\';
sessionCsvName = 'LearningCurveCompare_SessionTable.csv';
summaryCsvName = 'LearningCurveCompare_GroupCurveSummary.csv';
statsTxtName = 'LearningCurveCompare_Stats.txt';
coefCsvName = 'LearningCurveCompare_ModelCoefficients.csv';

%% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet', 'class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, 'Transferlearning.prj');
		if exist(prjFile, 'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

%% --- 1) Load datasets
CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

%% --- 2) Build block-level table from the same data path as Fig3G
Bc = iQueryLightWaterBlocks(CtrlDS);
Bt = iQueryLightWaterBlocks(THDS);
Bc.Group = repmat("Ctrl", height(Bc), 1);
Bt.Group = repmat("TH", height(Bt), 1);

Bc.Mouse = string(Bc.Mouse);
Bt.Mouse = string(Bt.Mouse);
Bc.DateTime = iNormalizeDateTime(Bc.DateTime);
Bt.DateTime = iNormalizeDateTime(Bt.DateTime);

J = MATLAB.DataTypes.MergeTables(Bc, Bt);
J.Group = string(J.Group);

vars = intersect(J.Properties.VariableNames, {'Mouse','DateTime','Behavior','Performance','Group','Phase'}, 'stable');
Sess = iSessionizeByDateTime(J(:, vars));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = iAddSessionIndex(Sess);

sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','DateTime'});

%% --- 2b) Include PO chemogenetic inhibition into TH group
poMatPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO.v1.mat";
try
	if exist(poMatPath, 'file')
		PO = UniExp.DataSet(poMatPath);
		POTable = PO.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater", Expression="溢出");
		if ~isempty(POTable)
			if ismember('Phase', POTable.Properties.VariableNames)
				POTable.Phase = string(POTable.Phase);
				POTable(POTable.Phase == "Recall", :) = [];
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
catch ME
	warning('LearningCurveCompare:POReadFailed', 'Failed to include PO dataset: %s', ME.message);
end

sessionForSummary = iAddSessionIndex(sessionForSummary);
sessionForSummary = sortrows(sessionForSummary, {'Group','Mouse','Session','DateTime'});

%% --- 3) Summary curve by group and block
groupOrder = ["Ctrl", "TH"];
groupLabels = ["Control", "TH inhibited"];

summaryTbl = iBuildCurveSummary(sessionForSummary, groupOrder, groupLabels);

%% --- 4) Mixed-effects statistics
lmeTbl = table;
lmeTbl.Performance = double(sessionForSummary.Performance);
lmeTbl.Block = double(sessionForSummary.Session);
lmeTbl.Group = categorical(string(sessionForSummary.Group), groupOrder, groupLabels);
lmeTbl.Mouse = categorical(string(sessionForSummary.Mouse));

use = isfinite(lmeTbl.Performance) & isfinite(lmeTbl.Block) & ~isundefined(lmeTbl.Group) & ~isundefined(lmeTbl.Mouse);
lmeTbl = lmeTbl(use, :);

if isempty(lmeTbl)
	error('LearningCurveCompare:EmptyLmeTable', 'No valid rows available for mixed-effects analysis.');
end

modelFormula = 'Performance ~ 1 + Block*Group + (1|Mouse)';
lme = fitlme(lmeTbl, modelFormula);
lmeAnova = anova(lme);
coefTbl = lme.Coefficients;
coefOutTbl = iEnsureWritableTable(coefTbl);

pBlock = iGetAnovaP(lmeAnova, "Block");
pGroup = iGetAnovaP(lmeAnova, "Group");
pInteraction = iGetAnovaP(lmeAnova, "Block:Group");

%% --- 5) First block comparison
firstBlock = sessionForSummary(sessionForSummary.Session == 1, :);
xCtrl = double(firstBlock.Performance(firstBlock.Group == "Ctrl"));
xTH = double(firstBlock.Performance(firstBlock.Group == "TH"));
[pFirstBlock, hFirstBlock] = iRanksumSafe(xCtrl, xTH);

%% --- 6) Write outputs
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

sessionCsvPath = fullfile(outDirUNC, sessionCsvName);
summaryCsvPath = fullfile(outDirUNC, summaryCsvName);
statsTxtPath = fullfile(outDirUNC, statsTxtName);
coefCsvPath = fullfile(outDirUNC, coefCsvName);

writetable(sessionForSummary, sessionCsvPath);
writetable(summaryTbl, summaryCsvPath);
writetable(coefOutTbl, coefCsvPath);
iWriteStatsFile(statsTxtPath, modelFormula, lmeTbl, pBlock, pGroup, pInteraction, xCtrl, xTH, pFirstBlock, hFirstBlock);

fprintf('Wrote: %s\n', sessionCsvPath);
fprintf('Wrote: %s\n', summaryCsvPath);
fprintf('Wrote: %s\n', coefCsvPath);
fprintf('Wrote: %s\n', statsTxtPath);

fprintf('\n=== LearningCurveCompare: mixed-effects summary ===\n');
fprintf('Model: %s\n', modelFormula);
fprintf('Block main effect p = %.6g\n', pBlock);
fprintf('Group main effect p = %.6g\n', pGroup);
fprintf('Block x Group interaction p = %.6g\n', pInteraction);
fprintf('\n=== First block comparison ===\n');
fprintf('Control: %.3f +- %.3f (n=%d)\n', mean(xCtrl, 'omitnan'), std(xCtrl, 'omitnan') / sqrt(numel(xCtrl)), numel(xCtrl));
fprintf('TH inhibited: %.3f +- %.3f (n=%d)\n', mean(xTH, 'omitnan'), std(xTH, 'omitnan') / sqrt(numel(xTH)), numel(xTH));
fprintf('ranksum p = %.6g\n', pFirstBlock);

assignin('base', 'LearningCurveCompare_SessionTable', sessionForSummary);
assignin('base', 'LearningCurveCompare_SummaryTable', summaryTbl);
assignin('base', 'LearningCurveCompare_LME', lme);
assignin('base', 'LearningCurveCompare_LMEAnova', lmeAnova);
assignin('base', 'LearningCurveCompare_Coefficients', coefOutTbl);
assignin('base', 'LearningCurveCompare_FirstBlockP', pFirstBlock);
assignin('base', 'LearningCurveCompare_InteractionP', pInteraction);

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
[u, ~, ic] = unique(phases);
counts = accumarray(ic, 1);
[~, ix] = max(counts);
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

function [p, h] = iRanksumSafe(x, y)
x = double(x(:));
y = double(y(:));
x = x(isfinite(x));
y = y(isfinite(y));
if isempty(x) || isempty(y)
	p = NaN;
	h = NaN;
	return;
end
[p, h] = ranksum(x, y);
end

function pVal = iGetAnovaP(anovaTbl, termName)
pVal = NaN;
if isempty(anovaTbl)
	return;
end
idx = find(string(anovaTbl.Term) == string(termName), 1, 'first');
if ~isempty(idx)
	pVal = anovaTbl.pValue(idx);
	return;
end
idx = find(contains(string(anovaTbl.Term), string(termName)), 1, 'first');
if ~isempty(idx)
	pVal = anovaTbl.pValue(idx);
end
end

function outTbl = iEnsureWritableTable(inObj)
if istable(inObj)
	outTbl = inObj;
	if isempty(outTbl.Properties.RowNames)
		return;
	end
	outTbl = addvars(outTbl, string(outTbl.Properties.RowNames), 'Before', 1, 'NewVariableNames', 'Term');
	outTbl.Properties.RowNames = {};
	return;
end

if isa(inObj, 'dataset')
	outTbl = dataset2table(inObj);
	if ismember('ObsNames', outTbl.Properties.VariableNames)
		outTbl.Properties.VariableNames{'ObsNames'} = 'Term';
	end
	return;
end

try
	outTbl = struct2table(inObj);
catch
	if isobject(inObj)
		props = properties(inObj);
		data = cell(1, numel(props));
		for k = 1:numel(props)
			data{k} = inObj.(props{k});
		end
		outTbl = table(data{:}, 'VariableNames', props);
	else
		error('LearningCurveCompare:CoeffExportType', 'Unsupported coefficient object type: %s', class(inObj));
	end
	end
end

function summaryTbl = iBuildCurveSummary(T, groupOrder, groupLabels)
rows = table('Size', [0 6], ...
	'VariableTypes', {'string','string','double','double','double','double'}, ...
	'VariableNames', {'GroupCode','GroupLabel','Block','MeanHitRate','SemHitRate','NMouse'});
for g = 1:numel(groupOrder)
	groupCode = string(groupOrder(g));
	groupLabel = string(groupLabels(g));
	maskG = string(T.Group) == groupCode;
	if ~any(maskG)
		continue;
	end
	blocks = unique(double(T.Session(maskG)));
	blocks = blocks(isfinite(blocks));
	blocks = sort(blocks(:));
	for b = 1:numel(blocks)
		mask = maskG & double(T.Session) == blocks(b) & isfinite(double(T.Performance));
		values = double(T.Performance(mask));
		mice = unique(string(T.Mouse(mask)));
		newRow = {groupCode, groupLabel, blocks(b), mean(values, 'omitnan'), std(values, 'omitnan') / sqrt(numel(values)), numel(mice)};
		rows = [rows; newRow]; %#ok<AGROW>
	end
	end
	summaryTbl = rows;
end

function iWriteStatsFile(outPath, modelFormula, lmeTbl, pBlock, pGroup, pInteraction, xCtrl, xTH, pFirstBlock, hFirstBlock)
fid = fopen(outPath, 'w');
if fid < 0
	error('LearningCurveCompare:OpenStatsFileFailed', 'Cannot open stats file for writing: %s', outPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'LearningCurveCompare\n');
fprintf(fid, '====================\n\n');
fprintf(fid, 'Model formula\n');
fprintf(fid, '%s\n\n', modelFormula);

fprintf(fid, 'Sample size\n');
fprintf(fid, 'Valid rows in mixed-effects table: %d\n', height(lmeTbl));
fprintf(fid, 'Control mice: %d\n', numel(unique(string(lmeTbl.Mouse(lmeTbl.Group == categorical("Control")) ))));
fprintf(fid, 'TH inhibited mice: %d\n\n', numel(unique(string(lmeTbl.Mouse(lmeTbl.Group == categorical("TH inhibited")) ))));

fprintf(fid, 'Mixed-effects ANOVA p-values\n');
fprintf(fid, 'Block: %.6g\n', pBlock);
fprintf(fid, 'Group: %.6g\n', pGroup);
fprintf(fid, 'Block x Group: %.6g\n\n', pInteraction);

fprintf(fid, 'Interpretation guide\n');
fprintf(fid, '- Group significant: two groups differ in overall hit rate level.\n');
fprintf(fid, '- Block significant: performance changes across blocks.\n');
fprintf(fid, '- Block x Group significant: learning trajectory differs between groups.\n\n');

fprintf(fid, 'First block comparison\n');
fprintf(fid, 'Control mean +- SEM: %.6g +- %.6g (n=%d)\n', mean(xCtrl, 'omitnan'), std(xCtrl, 'omitnan') / sqrt(numel(xCtrl)), numel(xCtrl));
fprintf(fid, 'TH inhibited mean +- SEM: %.6g +- %.6g (n=%d)\n', mean(xTH, 'omitnan'), std(xTH, 'omitnan') / sqrt(numel(xTH)), numel(xTH));
fprintf(fid, 'ranksum p: %.6g\n', pFirstBlock);
fprintf(fid, 'ranksum h: %.6g\n', hFirstBlock);
end