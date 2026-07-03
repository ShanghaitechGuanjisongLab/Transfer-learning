% 中文图32D：光水首个训练单元事件栅格（上下双tile）
%
% Top:     Naive —— LAPureBehavior 每鼠首个光水训练单元
% Bottom:  Continual —— ALPureBehavior 每鼠首个光水训练单元
%
% 数据源：ALPureBehavior / LAPureBehavior，Blocks.EventLog 列
% 方法：   UniExp.TrialwiseEventPlot

if ~exist('UniExp.DataSet','class')
    thisFile = mfilename('fullpath');
    thisDir = fileparts(thisFile);
    prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
    if exist(prjFile,'file')
        matlab.project.loadProject(prjFile);
    end
end

%% --- 提取每鼠首个 LightWater 训练单元的 EventLog ---
naiveELs = iCollectFirstLightWaterEventLogs(TransferLearning.LAPureBehavior(), "Naive");
contELs  = iCollectFirstLightWaterEventLogs(TransferLearning.ALPureBehavior(), "Transfer");

if isempty(naiveELs) && isempty(contELs)
    error('Fig32D:EmptyData', 'No LightWater Naive or Transfer blocks found.');
end

fprintf('Naive: %d mice\n', numel(naiveELs));
fprintf('Continual: %d mice\n', numel(contELs));

%% --- 绘图 ---
marker  = categorical("灯光亮");
tRange  = seconds([-5, 20]);
exclude = categorical(["灯光灭","错失","给水"]);

f = figure('Color','w', 'Name','中文图32D LightWater first-block event raster');
f.Units = 'centimeters';
f.Position(3:4) = [14, 12];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'auto';

layout = tiledlayout(f, 2, 1, 'TileSpacing','compact','Padding','tight');

% --- Top: Naive ---
axTop = nexttile(layout, 1);
legendDataTop = [];
if ~isempty(naiveELs)
    hold(axTop, 'on');
    for iM = 1:numel(naiveELs)
        lt = UniExp.TrialwiseEventPlot(naiveELs{iM}, marker, tRange, ExcludedEvents=exclude);
        if iM == 1
            legendDataTop = lt;
        end
    end
    hold(axTop, 'off');
    delete(findobj(axTop, 'Type', 'Legend'));
    if ~isempty(legendDataTop)
        lg = legend(axTop, legendDataTop.Scatter, string(legendDataTop.Event), 'Location', 'best');
        lg.Box = 'off';
        lg.AutoUpdate = 'off';
    end
    title(axTop, sprintf('Naive (n=%d mice)', numel(naiveELs)), 'FontSize', 8, 'FontWeight', 'normal');
    axTop.XAxis.Visible = 'off';
else
    title(axTop, 'Naive — no data', 'FontSize', 8, 'FontWeight', 'normal');
end
box(axTop,'off');

% --- Bottom: Continual ---
axBot = nexttile(layout, 2);
legendDataBot = [];
if ~isempty(contELs)
    hold(axBot, 'on');
    for iM = 1:numel(contELs)
        lt = UniExp.TrialwiseEventPlot(contELs{iM}, marker, tRange, ExcludedEvents=exclude);
        if iM == 1
            legendDataBot = lt;
        end
    end
    hold(axBot, 'off');
    delete(findobj(axBot, 'Type', 'Legend'));
    if ~isempty(legendDataBot)
        lg = legend(axBot, legendDataBot.Scatter, string(legendDataBot.Event), 'Location', 'best');
        lg.Box = 'off';
        lg.AutoUpdate = 'off';
    end
    title(axBot, sprintf('Continual (n=%d mice)', numel(contELs)), 'FontSize', 8, 'FontWeight', 'normal');
else
    title(axBot, 'Continual — no data', 'FontSize', 8, 'FontWeight', 'normal');
end
box(axBot,'off');

xlabel(axBot, 'Time (s)', 'FontSize', 8);
ylabel(layout, 'Trial', 'FontSize', 8);

%% --- 导出（跳过 ScatterAxPadding，因 duration 类型不受支持）---
TransferLearning.Style.ApplyStandardFigureStyle(f, 2);
svgPath = TransferLearning.StandardFigureSvgPath('中文图Fig32D_LickRasterAllMice.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ========== 子函数 ==========

function eventLogs = iCollectFirstLightWaterEventLogs(DS, phaseName)
% 返回 cell array，每个 cell 是一只鼠首个指定 phase 光水 block 的 EventLog timetable
eventLogs = {};
if isempty(DS), return; end

lw = DS.Blocks(string(DS.Blocks.Design) == "LightWater", :);
if isempty(lw), return; end

dt = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
dt.DateTime = iNormDT(datetime(dt.DateTime));
dt.Mouse = string(dt.Mouse);
dt.Phase   = string(dt.Phase);

lw.DateTime = iNormDT(datetime(lw.DateTime));
lw = innerjoin(lw, dt, 'Keys','DateTime');
phaseRows  = lw(string(lw.Phase) == string(phaseName), :);
if isempty(phaseRows), return; end

mice = unique(string(phaseRows.Mouse), 'stable');
for iM = 1:numel(mice)
    m = mice(iM);
    rows = phaseRows(string(phaseRows.Mouse) == m, :);
    rows = sortrows(rows, 'DateTime');
    firstRow = rows(1, :);
    el = firstRow.EventLog{1};
    if isempty(el), continue; end
    % 确保 Event 是 categorical
    if ~iscategorical(el.Event)
        el.Event = categorical(string(el.Event));
    end
    % 确保 Time 是 duration
    if ~isduration(el.Time)
        el.Time = seconds(el.Time);
    end
    eventLogs{end+1} = el; %#ok<AGROW>
end
% 统一所有 EventLog 的 categorical 类别集合，避免 ismember 报错
if ~isempty(eventLogs)
    allCats = categorical.empty(0,1);
    for k = 1:numel(eventLogs)
        allCats = [allCats; eventLogs{k}.Event];
    end
    catSet = categories(allCats);
    for k = 1:numel(eventLogs)
        eventLogs{k}.Event = categorical(string(eventLogs{k}.Event), catSet);
    end
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
try
    if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end
