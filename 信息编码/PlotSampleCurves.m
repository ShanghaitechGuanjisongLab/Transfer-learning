%% Plot sample LightWater learning curves: steepest vs shallowest slope
% 基于工作区已算好的 Sess 表

prjRoot = 'd:\Users\杨青宁\Documents\MATLAB\Transfer-learning';
if ~exist('UniExp.DataSet','class')
    prjFile = fullfile(prjRoot, 'Transferlearning.prj');
    matlab.project.loadProject(prjFile); addpath(prjRoot);
end

% 从工作区取数据，若没有则重算
if ~evalin('base', 'exist(''Sess'',''var'')')
    error('Run the data loading step first.');
end
Sess = evalin('base', 'Sess');
slopeVec = evalin('base', 'slopeVec');
mice = evalin('base', 'mice');

minMouse = "vtf0030";
maxMouse = "yqn2005";

% 重新拟合获取参数
for iCase = 1:2
    if iCase == 1
        m = minMouse; clr = [0.6 0.3 0.8];
    else
        m = maxMouse; clr = [0.9 0.5 0.1];
    end
    R = Sess(string(Sess.Mouse) == m, :);
    x = double(R.Session); y = double(R.Perf);
    obj = @(p) sum((y - (1 ./ (1 + exp(-abs(p(1)) .* (x - p(2)))))).^2);
    p = fminsearch(obj, [0.5; median(x)], optimset('Display','off'));
    k = abs(p(1)); mid = p(2);
    
    xFit = linspace(0, max(x)+2, 200);
    yFit = 1 ./ (1 + exp(-k .* (xFit - mid)));
    
    figure(iCase);
    clf;
    set(gcf, 'Color','w', 'Units','centimeters', 'Position',[5 5 10 8]);
    hold on;
    plot(x, y, 'o', 'Color',clr, 'MarkerFaceColor',clr, ...
        'MarkerSize',10, 'LineWidth',1.5);
    plot(xFit, yFit, '-', 'Color',clr, 'LineWidth',2.5);
    xlabel('Block', 'FontSize',14);
    ylabel('Hit rate', 'FontSize',14);
    xlim([0 max(x)+2]);
    ylim([0 1.02]);
    box off; grid off;
    set(gca, 'FontSize',13, 'LineWidth',1.5, 'TickDir','out');
    title(sprintf('%s: slope=%.4f, midpoint=%.2f', m, k, mid), ...
        'FontWeight','normal', 'FontSize',13);
    
    outName = sprintf('SampleCurve_%s.svg', m);
    outPath = fullfile('\\Data-Server-2\个人数据\杨青宁\202607', outName);
    exportgraphics(gcf, outPath, 'ContentType','vector');
    fprintf('Wrote: %s\n', outPath);
end
