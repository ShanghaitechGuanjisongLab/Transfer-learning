% 图3.1a/e 合并：First session performance（LightWater + AudioWater）
% 使用 UniExp.BarScatterCompare 二维表语法绘制条形图（不显示散点），并以 emoji 标注刺激类型。
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% Ensure project loaded (best-effort)
try
    if ~exist('UniExp.DataSet','class')
        thisFile = mfilename('fullpath');
        thisDir = fileparts(thisFile);
        prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
        if exist(prjFile,'file')
            try matlab.project.loadProject(prjFile); catch, end
        end
    end
catch
end

% Run the original A and E scripts to populate base workspace summaries
try
    evalc('TransferLearning.Fig31.A_FirstSessionPerformance');
catch
end
try
    evalc('TransferLearning.Fig31.E_FirstSessionPerformance_AudioWater');
catch
end

% Retrieve raw tables left in base by those scripts
try
    rawA = evalin('base', 'Fig3_1a_FirstSessionPerformance_Raw');
catch
    error('AE_Combined:MissingA', 'Could not find Fig3_1a_FirstSessionPerformance_Raw in base workspace. Run A_FirstSessionPerformance first.');
end
try
    rawE = evalin('base', 'Fig3_1e_FirstSessionPerformance_AudioWater_Raw');
catch
    error('AE_Combined:MissingE', 'Could not find Fig3_1e_FirstSessionPerformance_AudioWater_Raw in base workspace. Run E_FirstSessionPerformance_AudioWater first.');
end

% Extract per-mouse performance vectors (keep only LightWater)
naiveA = double(rawA.FirstPerformance(rawA.Group=="Naive"));
tranA  = double(rawA.FirstPerformance(rawA.Group=="Transfer"));

% Build Groups table for UniExp.BarScatterCompare (rows = Stimulus)
% RowNames use emoji: LightWater -> 💡💧 (only LightWater kept)
colNaive = {naiveA};
colTran  = {tranA};
stimNames = ["💡💧"];
Groups = table(colNaive, colTran, 'VariableNames', {'Naive','Transfer'}, 'RowNames', cellstr(stimNames));
Groups.Properties.DimensionNames = {'Stimulus','Cohort'};

% CompareGroup: compare Naive vs Transfer within each stimulus (2D pairs)
stimPairs = [stimNames, stimNames];
cohortPairs = repmat(["Naive","Transfer"], numel(stimNames), 1);
groupPair2D = table(stimPairs, cohortPairs, 'VariableNames', Groups.Properties.DimensionNames);
CompareGroup = table(groupPair2D, 'VariableNames', {'GroupPair'});

% --- Plot
f = figure('Color','w', 'Name', 'Fig3.1a/e First session performance (combined)');
f.Units = 'centimeters';
f.Position(3:4) = [4.5, 4.5]; % 45 x 45 mm
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

% 使用 AsteriskThreshold 自动将 p<0.05 显示为星号
[~, Optional] = UniExp.BarScatterCompare(Groups, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 12;

% Use X axis to label Naive/Transfer and remove legend if present
try
    ax.XTick = [1, 2];
    ax.XTickLabel = {'Naive', 'Transfer'};
    legend(ax, 'off');
catch
end

% 设置星号字体为 6pt
if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
    for pt = Optional.MultiCompare.PText(:)'
        pt.FontSize = 12;
    end
end

% 设置条形和误差条边框粗细
bars = findobj(ax, 'Type', 'Bar');
for b = bars(:)'
    b.LineWidth = 1;
end
errorBars = findobj(ax, 'Type', 'ErrorBar');
for eb = errorBars(:)'
    eb.LineWidth = 1;
end

% Cosmetic
ylabel(ax, 'Hit rate', 'FontSize', 12);
title(ax, 'Session#1 hit rate', 'FontSize', 12);
box(ax,'on');

% Export SVG
svgPath = fullfile(outDirUNC, 'English_Fig1C_FirstSessionPerformance.svg');
try
    if ~isfolder(outDirUNC), mkdir(outDirUNC); end
    TransferLearning.PrintFigure(f, svgPath);
    fprintf('Wrote: %s\n', svgPath);
catch ME
    warning(ME.identifier, 'Export failed: %s', ME.message);
end

% Save summary table for later use
Summary = table();
Summary.Stimulus = stimNames;
Summary.NaiveN = cellfun(@numel, colNaive);
Summary.TransferN = cellfun(@numel, colTran);
assignin('base','Fig3_1a_e_Combined_Summary', Summary);
