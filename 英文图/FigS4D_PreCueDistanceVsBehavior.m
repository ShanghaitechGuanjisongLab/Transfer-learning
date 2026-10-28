%% FigS4D_PreCueDistanceVsBehavior.m
% English FigS4D: pre-cue population-state distance 与 trial outcome。
% 左：Fig.5a/b 的 bar(mean±SEM)+逐鼠点样式；纵轴仍为本工程线索前距离。
% 右：ED Fig.9d 的四分位均值点±横纵 SEM + 平滑 logistic 曲线；分箱点不连线。
% 文献 initial state 是 movement/no-movement decoder 输出；本工程 Learned 几乎全
% hit，无法直接套用该训练，故保留预先确认的描述性量“线索前距离”而非同义复刻。
%
% Outputs (SVG): English_FigS4D_PreCueDistanceVsBehavior.svg
% Execution: Keep as a script. Run/F5 in MATLAB Editor.

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
S = load(fullfile(thisDir, '..', 'Temp', 'FigS4_PreCueStatePCA_Results.mat'));
M = S.M;

hitColor = [0.66, 0.32, 0.50];
missColor = [0.82, 0.72, 0.67];

% ---- 每鼠 hit/miss 均值（要求两组各 >=3 trial）----
keep = [];
dH = []; dMs = [];
for i = 1:numel(M)
	h = M(i).dPreTz(M(i).YT == 1); ms = M(i).dPreTz(M(i).YT == 0);
	if numel(h) >= 3 && numel(ms) >= 3 && std([h; ms]) > 0
		keep(end+1) = i; %#ok<SAGROW>
		dH(end+1) = mean(h); dMs(end+1) = mean(ms); %#ok<SAGROW>
	end
end
[pW, hW] = signrank(dH, dMs);
nUp = sum(dH > dMs);
fprintf('hit vs miss 线索前距离：%d 鼠可用，%d/%d 鼠 hit>miss，Wilcoxon p=%.4g %s\n', ...
	numel(keep), nUp, numel(keep), pW, iifS(hW==1,'(显著)','(不显著)'));

% ---- pooled 三分位命中率 ----
Rm = [];
for i = 1:numel(M)
	d = M(i).dPreTz; y = M(i).YT;
	o = isfinite(d);
	if sum(o) < 12, continue; end
	rk = tiedrank(d(o));
	bin = ceil(rk ./ (numel(rk)/3)); bin(bin>3) = 3; bin(bin<1) = 1;
	yo = y(o);
	r = nan(1, 3);
	for k = 1:3
		mk = bin == k;
		if any(mk), r(k) = mean(yo(mk)); end
	end
	if all(isfinite(r)), Rm = [Rm; r]; end %#ok<AGROW>
end
pF = friedman(Rm, 1, 'off');
[pHL, hHL] = signrank(Rm(:,3), Rm(:,1));
fprintf('三分位命中率：low %.3f mid %.3f high %.3f；Friedman p=%.4g；high-low 中位差 %+.3f，p=%.4g %s\n', ...
	mean(Rm(:,1)), mean(Rm(:,2)), mean(Rm(:,3)), pF, median(Rm(:,3)-Rm(:,1)), pHL, iifS(hHL==1,'(显著)','(不显著)'));

% ---- figure（左仿 Fig.5a/b bar+dot；右仿 ED Fig.9d 分箱概率 + 拟合曲线）----
f = figure('Color', 'w', 'Name', 'English FigS4D PreCueDistanceVsBehavior');
f.Units = 'centimeters';
f.Position(3:4) = [9, 4];
tl = tiledlayout(f, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');

% 左：Movement vs No movement 线索前距离（bar = 鼠均±SEM，dot = 每鼠）
ax = nexttile(tl);
hold(ax, 'on');
muG = [mean(dH), mean(dMs)];
seG = [std(dH)/sqrt(numel(dH)), std(dMs)/sqrt(numel(dMs))];
bar(ax, 1, muG(1), 0.5, 'EdgeColor', 'none', 'FaceColor', hitColor);
bar(ax, 2, muG(2), 0.5, 'EdgeColor', 'none', 'FaceColor', missColor);
errorbar(ax, [1, 2], muG, seG, '.', 'Color', [0.2, 0.2, 0.2], 'LineWidth', 0.75, 'CapSize', 3);
jitter = 0.16 * linspace(-0.5, 0.5, numel(dH))';
scatter(ax, 1+jitter, dH, 6, 0.65*hitColor, 'filled', 'MarkerEdgeColor', 'none');
scatter(ax, 2+jitter, dMs, 6, 0.65*missColor, 'filled', 'MarkerEdgeColor', 'none');
xlim(ax, [0.4, 2.6]);
set(ax, 'XTick', [1, 2], 'XTickLabel', ["Movement", "No movement"]);
ylabel(ax, 'Pre-cue distance (z)');
iStyleAxes(ax);

% 右：movement probability vs initial state 四分位箱（ED Fig.9d 样式）
% 此面板仅用 pre 距离做鼠内 z；不用几乎全 hit 的 Learned 数据强行训练文献 logistic decoder。
ax2 = nexttile(tl);
hold(ax2, 'on');
Xp = []; Yp = []; Xm = [];
for i = 1:numel(M)
	d0 = M(i).dPreT;
	o = isfinite(d0) & std(d0, 'omitnan') > 0;
	if sum(o) < 8, continue; end
	zz = (d0(o) - mean(d0(o))) / std(d0(o));
	Xp = [Xp; zz]; Yp = [Yp; M(i).YT(o)]; Xm = [Xm; i*ones(sum(o),1)]; %#ok<AGROW>
end
qs = quantile(Xp, [0.25, 0.5, 0.75]);
binI = 1 + sum(Xp(:) > qs, 2);
nBin = 4;
rateM = nan(numel(M), nBin); xM = nan(numel(M), nBin);
for kb = 1:nBin
	selB = binI == kb;
	for i = 1:numel(M)
		si = selB & Xm == i;
		if any(si)
			rateM(i, kb) = mean(Yp(si));
			xM(i, kb) = mean(Xp(si));
		end
	end
end
xC = mean(xM, 1, 'omitnan')';
xSE = (std(xM, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(xM), 1)))';
muR = mean(rateM, 1, 'omitnan')';
seR = (std(rateM, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(rateM), 1)))';
errorbar(ax2, xC, muR, xSE, xSE, seR, seR, 'o', 'LineStyle', 'none', ...
	'Color', hitColor, 'LineWidth', 0.6, 'MarkerSize', 3, 'MarkerFaceColor', hitColor, 'CapSize', 2);
glm = fitglm(table(Xp, Yp), 'Yp ~ Xp', 'Distribution', 'binomial');
pGlm = glm.Coefficients.pValue(2);
xf = linspace(min(Xp), max(Xp), 100)';
plot(ax2, xf, predict(glm, table(xf, 'VariableNames', {'Xp'})), '-', 'Color', hitColor, 'LineWidth', 1);
fprintf('pooled logistic：初始状态斜率 p=%.4g\n', pGlm);
xlabel(ax2, 'Initial state (pre-cue distance, z)');
ylabel(ax2, 'Movement probability');
ylim(ax2, [0, 1]); set(ax2, 'YTick', 0:0.5:1);
iStyleAxes(ax2);

svgPath = TransferLearning.ExportStandardFigure(f, 1, 'English_FigS4D_PreCueDistanceVsBehavior.svg');
fprintf('Wrote: %s\n', svgPath);
assignin('base', 'FigS4D_Stats', struct('pWilcoxon', pW, 'pFriedman', pF, 'pHighLow', pHL, ...
	'pLogistic', pGlm, 'Rm', Rm, 'dH', dH, 'dMs', dMs));

function iStyleAxes(ax)
box(ax, 'off');
ax.FontName = 'Arial'; ax.FontSize = 6; ax.LineWidth = 0.5;
ax.XColor = 'k'; ax.YColor = 'k'; ax.TickDir = 'out'; ax.TickLength = [0.025, 0.025];
ax.LabelFontSizeMultiplier = 1; ax.TitleFontSizeMultiplier = 1;
if ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
end

function s = iifS(c, a, b)
if c, s = a; else, s = b; end
end
