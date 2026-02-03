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

% Prepare data as a simple cell array (one cell per cohort) so BarScatterCompare
% draws a single comparison line between group 1 (Naive) and group 2 (Transfer).
DataCell = {naiveA, tranA}; % {Naive, Transfer}

% CompareGroup: numeric pair comparing group 1 vs 2 (ensures a single P-line)
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
%% 

% --- Plot
f = figure('Color','w', 'Name', 'Fig3.1a/e First session performance (combined)');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 2.0]; % 30 x 20 mm
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

% 使用 AsteriskThreshold 自动将 p<0.05 显示为星号
% Capture Bars/ErrorBars so we can style colors and spacing to match Fig1B
[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

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
        pt.FontSize = 6;
    end
end

% 设置条形颜色与间距以匹配 Fig1B 线条颜色（红色=Naive，蓝色=Transfer）
colorNaive = [1 0 0]; % 红色，与B图 Naive 线条一致
colorTrans = [0 0 1]; % 蓝色，与B图 Transfer 线条一致
try
    if numel(Bars) == 1
        Bars.FaceColor = 'flat';
        nBars = numel(Bars.YData); % number of bars drawn
        % Build CData by repeating the two colors
        reps = ceil(nBars/2);
        Bars.CData = repmat([colorNaive; colorTrans], reps, 1);
        Bars.CData = Bars.CData(1:nBars, :);
        Bars.BarWidth = 0.5; % narrower bars -> visually more space
        Bars.LineWidth = 0.5;
        Bars.FaceAlpha = 1/3; % 透明度
    else
        % If Bars is array, assign colors per series
        if numel(Bars) >= 2
            Bars(1).FaceColor = colorNaive;
            Bars(2).FaceColor = colorTrans;
            Bars(1).LineWidth = 0.5;
            Bars(2).LineWidth = 0.5;
            Bars(1).FaceAlpha = 1/3;
            Bars(2).FaceAlpha = 1/3;
        else
            Bars.FaceColor = colorNaive;
            Bars.LineWidth = 0.5;
            Bars.FaceAlpha = 1/3;
        end
    end
catch
end
% set errorbar linewidths
for eb = ErrorBars.Object(:)'
    eb.LineWidth = 0.5;
end
% expand x-limits slightly to increase inter-bar spacing appearance
try
    ax.XLim = [0.5, 2.5];
end

% Cosmetic
ylabel(ax, 'Hit rate', 'FontSize', 6);
title(ax, 'Block#1', 'FontSize', 6);
box off
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
