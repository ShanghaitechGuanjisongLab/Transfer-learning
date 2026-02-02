%[text] 图3.1D：达到95%命中率所需会话数（光水/声水 × 初始/迁移）
%
% 使用 UniExp.BarScatterCompare 的二维表语法
% - 行名：刺激类型（emoji）💡💧=LightWater, 🔊💧=AudioWater
% - 列名：学习阶段（Naive/Transfer）
% - 不显示散点
% - 输出图窗 45×45mm，字体 6pt
%
% 数据来源（与 C_TimeToCriterion 一致）：
% - LightWater Naive: LightAudioBaseline + LAInterspersed（剔除混音鼠）+ LAPureBehavior
% - LightWater Transfer: AudioLightBaseline + ALPureBehavior
% - AudioWater Naive: AudioLightBaseline + ALPureBehavior
% - AudioWater Transfer: LightAudioBaseline + LAPureBehavior
%
% 执行方式（硬性要求）：
% - 本文件必须保持为脚本
% - 在 MATLAB Editor 里打开后直接 Run/F5 执行

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch ME
				warning('Fig3_1d:ProjectLoadFailed', 'Project load failed: %s', ME.message);
			end
		end
	end
catch ME
	warning('Fig3_1d:ProjectCheckFailed', 'Project check failed: %s', ME.message);
end

% --- 1) Load datasets
LAB  = TransferLearning.LightAudioBaseline();   % 成像：光→声
LAI  = TransferLearning.LAInterspersed();       % 成像：交错
LAPB = TransferLearning.LAPureBehavior();       % 纯行为：光→声
ALB  = TransferLearning.AudioLightBaseline();   % 成像：声→光
ALPB = TransferLearning.ALPureBehavior();       % 纯行为：声→光

% --- 2) Build per-mouse session tables for LightWater (复用 C_TimeToCriterion 的模式)
lwNaiveA = iStimulusSessionsByMouse(LAB,  "LightWater", "Naive", "Learned");
lwNaiveB = iStimulusSessionsByMouse_LAInterspersed(LAI, "LightWater", "Naive", "Learned");
lwNaiveC = iStimulusSessionsByMouse(LAPB, "LightWater", "Naive", "Learned");
lwTransA = iStimulusSessionsByMouse(ALB,  "LightWater", "Transfer", "Final");
lwTransB = iStimulusSessionsByMouse(ALPB, "LightWater", "Transfer", "Final");

lwNaive = [lwNaiveA; lwNaiveB; lwNaiveC];
lwTrans = [lwTransA; lwTransB];

% --- 3) Build per-mouse session tables for AudioWater
awNaiveA = iStimulusSessionsByMouse(ALB,  "AudioWater", "Naive", "Learned");
awNaiveB = iStimulusSessionsByMouse(ALPB, "AudioWater", "Naive", "Learned");
awTransA = iStimulusSessionsByMouse(LAB,  "AudioWater", "Transfer", "Final");
awTransB = iStimulusSessionsByMouse(LAPB, "AudioWater", "Transfer", "Final");

awNaive = [awNaiveA; awNaiveB];
awTrans = [awTransA; awTransB];

% --- 4) Calculate sessions to 95% criterion
threshold = 0.95;

lwNaiveTTC = iCalcTTC(lwNaive, threshold);
lwTransTTC = iCalcTTC(lwTrans, threshold);
awNaiveTTC = iCalcTTC(awNaive, threshold);
awTransTTC = iCalcTTC(awTrans, threshold);

fprintf('LightWater Naive: n=%d, median=%.1f\n', numel(lwNaiveTTC), median(lwNaiveTTC,'omitnan'));
fprintf('LightWater Transfer: n=%d, median=%.1f\n', numel(lwTransTTC), median(lwTransTTC,'omitnan'));
fprintf('AudioWater Naive: n=%d, median=%.1f\n', numel(awNaiveTTC), median(awNaiveTTC,'omitnan'));
fprintf('AudioWater Transfer: n=%d, median=%.1f\n', numel(awTransTTC), median(awTransTTC,'omitnan'));

% --- 5) Build data table for BarScatterCompare
% 行：💡💧（LightWater）, 🔊💧（AudioWater）
% 列：Naive, Transfer
dataTable = table(...
	{lwNaiveTTC, awNaiveTTC}', ...
	{lwTransTTC, awTransTTC}', ...
	'VariableNames', {'Naive', 'Transfer'}, ...
	'RowNames', {'💡💧', '🔊💧'});

% --- 6) Plot using UniExp.BarScatterCompare
f = figure('Color', 'w', 'Name', 'Fig3.1D Sessions to 95%');
% 设置图窗大小为 45×45mm
set(f, 'Units', 'centimeters', 'Position', [5, 5, 4.5, 4.5]);

% 设置 DimensionNames 以便 CompareGroup 使用
dataTable.Properties.DimensionNames = {'Stimulus', 'Cohort'};

% 构建 CompareGroup（与 AE_Combined 相同的格式）
stimNames = ["💡💧"; "🔊💧"];
stimPairs = [stimNames, stimNames];  % 每行是同一刺激类型的两个位置
cohortPairs = repmat(["Naive", "Transfer"], numel(stimNames), 1);  % 每行比较 Naive vs Transfer
groupPair2D = table(stimPairs, cohortPairs, 'VariableNames', dataTable.Properties.DimensionNames);
CompareGroup = table(groupPair2D, 'VariableNames', {'GroupPair'});

tiledlayout(1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;

% 使用二维表语法: BarScatterCompare(Data, ShowScatter, CompareGroup, AsteriskThreshold=...)
% AsteriskThreshold 自动将 p<0.05 显示为星号
UniExp.BarScatterCompare(dataTable, false, CompareGroup, 'AsteriskThreshold', 0.05);

ax = gca;
ax.FontSize = 6;

% 减小条形边框粗细
bars = findobj(ax, 'Type', 'Bar');
for b = bars(:)'
	b.LineWidth = 0.5;
end

ylabel(ax, 'Sessions to 95%');
title(ax, '');
box(ax, 'on');

% 设置图例字体
lgd = findobj(f, 'Type', 'Legend');
if ~isempty(lgd)
	lgd.FontSize = 6;
end

% --- 7) Export SVG
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch ME
	warning('Fig3_1d:MkdirFailed', 'mkdir failed: %s', ME.message);
end

svgPath = fullfile(outDirUNC, 'Fig3_1d_SessionsTo95_BarCompare.svg');
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', char(svgPath));
catch ME
	warning('Fig3_1d:ExportFailed', 'Export failed: %s', ME.message);
end

%% === Local Functions ===

function out = iStimulusSessionsByMouse(DS, stimulus, startPhase, endPhase)
% 获取指定刺激类型的会话数据
T = iQueryStimBehaviorAll(DS, stimulus);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Session'});
	return;
end
T.Mouse = string(T.Mouse);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T = iAddSessionIndex(T);
out = T(:, intersect({'Mouse','DateTime','Performance','Session'}, T.Properties.VariableNames, 'stable'));
end

function out = iStimulusSessionsByMouse_LAInterspersed(DS, stimulus, startPhase, endPhase)
% LAInterspersed 特殊处理：排除 Naive LightWater 会话中混入 AudioWater 的鼠
if stimulus ~= "LightWater"
	out = iStimulusSessionsByMouse(DS, stimulus, startPhase, endPhase);
	return;
end
pure = iFindPureNaiveLightWaterMice(DS);
T = iQueryStimBehaviorAll(DS, stimulus);
if isempty(T)
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Session'});
	return;
end
T.Mouse = string(T.Mouse);
if ~isempty(pure)
	keepMice = string(pure.Mouse);
	T = T(ismember(T.Mouse, keepMice), :);
	fprintf('Fig3.1d: LAInterspersed kept %d pure mice.\n', numel(keepMice));
end
T.DateTime = iNormalizeDateTime(T.DateTime);
T = iSessionizeByDateTime(T);
T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
T = iAddSessionIndex(T);
out = T(:, intersect({'Mouse','DateTime','Performance','Session'}, T.Properties.VariableNames, 'stable'));
end

function T = iQueryStimBehaviorAll(DS, stimulus)
% 查询指定刺激类型的行为数据
vars = ["Mouse","DateTime","Performance","Phase","Stimulus"];
try
	T = DS.TableQuery(vars, Stimulus=stimulus);
catch
	try
		T = DS.TableQuery(vars);
		if ismember("Stimulus", T.Properties.VariableNames)
			T.Stimulus = string(T.Stimulus);
			T = T(T.Stimulus == stimulus, :);
		else
			T = table();
		end
	catch
		T = table();
	end
end
if isempty(T)
	return;
end
if ~ismember("Phase", T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
T.Phase = string(T.Phase);
end

function S = iSessionizeByDateTime(T)
% 按日期时间分组，计算会话性能
if ~ismember('Phase', T.Properties.VariableNames)
	T.Phase = repmat(missing, height(T), 1);
end
T = T(:, intersect({'Mouse','DateTime','Performance','Phase'}, T.Properties.VariableNames, 'stable'));
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse','DateTime'});

[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
perf = splitapply(@(x) mean(double(x), 'omitnan'), T.Performance, G);
phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);

S = table(mouseKeys, dtKeys, perf, phaseSession, ...
	'VariableNames', {'Mouse','DateTime','Performance','Phase'});
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

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
% 选择在 startPhase 和 endPhase 之间的会话
startPhase = string(startPhase);
endPhase = string(endPhase);
if isempty(S)
	return;
end
if ~ismember('Phase', S.Properties.VariableNames)
	S = S([],:);
	return;
end
S.Mouse = string(S.Mouse);
S.Phase = string(S.Phase);
S = sortrows(S, {'Mouse','DateTime'});

mice = unique(S.Mouse);
keepRows = false(height(S),1);
for i = 1:numel(mice)
	m = mice(i);
	idx = find(S.Mouse == m);
	ph = S.Phase(idx);
	st = find(ph == startPhase, 1, 'first');
	if isempty(st)
		continue;
	end
	ed = find(ph == endPhase & (1:numel(ph))' >= st, 1, 'first');
	if isempty(ed)
		ed = numel(ph);
	end
	keepRows(idx(st:ed)) = true;
end
S = S(keepRows, :);
end

function T = iAddSessionIndex(T)
% 添加会话索引
if isempty(T)
	T.Session = nan(0,1);
	return;
end
T.Mouse = string(T.Mouse);
T = sortrows(T, {'Mouse','DateTime'});
[G, ~] = findgroups(T.Mouse);
sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
T.Session = vertcat(sessCell{:});
end

function ttc = iCalcTTC(sessionTable, threshold)
% 计算每只鼠达到阈值所需的会话数
if isempty(sessionTable)
	ttc = [];
	return;
end

mice = unique(sessionTable.Mouse);
ttc = nan(numel(mice), 1);

for i = 1:numel(mice)
	m = mice(i);
	idx = sessionTable.Mouse == m;
	s = sessionTable.Session(idx);
	p = sessionTable.Performance(idx);
	
	reachedIdx = find(p >= threshold, 1, 'first');
	if ~isempty(reachedIdx)
		ttc(i) = s(reachedIdx);
	end
end

% 移除未达标的鼠
ttc = ttc(isfinite(ttc));
end

function pure = iFindPureNaiveLightWaterMice(DS)
% 找出 Naive LightWater 会话中没有混入 AudioWater 的鼠
try
	B = DS.TableQuery(["Mouse","BlockUID","Phase","Stimulus"], Phase="Naive", Stimulus="LightWater");
catch
	pure = table(string.empty(0,1), 'VariableNames', {'Mouse'});
	return;
end
if isempty(B)
	pure = table(string.empty(0,1), 'VariableNames', {'Mouse'});
	return;
end
B.Mouse = string(B.Mouse);
if ~isprop(DS, 'Trials')
	pure = table(unique(B.Mouse), 'VariableNames', {'Mouse'});
	return;
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	pure = table(unique(B.Mouse), 'VariableNames', {'Mouse'});
	return;
end
Tr.Stimulus = string(Tr.Stimulus);

mice = unique(B.Mouse);
keep = false(size(mice));
for i = 1:numel(mice)
	m = mice(i);
	rowsM = (B.Mouse == m);
	bu = unique(uint64(B.BlockUID(rowsM)));
	hasAudio = false;
	for j = 1:numel(bu)
		b = bu(j);
		trB = (uint64(Tr.BlockUID) == b);
		if any(Tr.Stimulus(trB) == "AudioWater")
			hasAudio = true;
			break;
		end
	end
	keep(i) = ~hasAudio;
end
pure = table(mice(keep), 'VariableNames', {'Mouse'});
end

function dt = iNormalizeDateTime(dt)
try
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
catch
end
end
