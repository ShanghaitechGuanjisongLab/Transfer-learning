function FigAttractorSchematic()
%[text] 吸引子样结构与跨阶段相似性（12 x 8 cm，2x2）
%
% 画风来源
%   潜空间相图（phase portrait）的通用画法，**不依赖任何切换/分段模型**：
%   浅灰底 + 箭头流场（flow field）+ **实心圆点标不动点**
%   + 细实线轨迹 + 淡灰坐标框。本节 (a) 按此画。
%   (b) 用组间实证对比的通行画法：逐鼠散点 + 中位数横线 + 零参考线（非示意图）。
%
% ⚠ 方法声明：本项目**未采用切换式潜变量模型**（Stage 1 的 rSLDS pilot 未产出可用结论，
%   主分析链是 TICA/PCA + VAR(1)）。正文/图注不得声称使用该类模型，本图也不得归因于其文献。
%
% 面板
%   (a) 单一稳定不动点；cue（深红粗箭头）把状态推远，随后沿非梯度路径回流（黑）
%   (b) 分阶段的"扣弧后超出线性平稳零模型"的量（逐鼠，MOp2/3，P1），**真实数据**
%   (c) 两阶段的旋转平面部分重叠
%   (d) cross 占阶段内天花板的比例，六种条件（m=2/4 × P0/P1/P2）——**真实数据**
%
% 为什么 (a) 只有一幅、不按阶段分画
%   A.27（Step43）：Learned 与 Transfer 在 dist / tau1 / tau_ratio / Q / rho / rho_rot
%   六个几何量、三档预处理上**没有任何一项稳健不同**。两阶段回归几何实测不可区分，
%   故不能画成两幅不同形状；差异用 (b) 的统计位置表达。
%   几何也表达不了它：omega 相差 0.15 时 4 mm 尺度上轨迹偏差 < 0.4 mm。
%
% 口径
%   弯曲幅度取 Q ≈ 0.32（实测 0.16–0.35，过阻尼、非振荡）。
%   非梯度（切向）分量由**流场箭头本身**表达：箭头并非径向指向 x*，而是带切向倾斜。
%   (b) 数据 = results/_fig_excess_by_phase.csv（Step44 从 _step32_m6_variants.json 导出）。
%   **不表示"已证明吸引子存在"**。
%   字号：Scale 1.5 ⇒ 9 pt。Scale 2（12 pt）在 12 cm × 4 块下会图例溢出、轴标签相撞。

if ~exist('TransferLearning','class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file'), matlab.project.loadProject(prjFile); end
end

cL    = TransferLearning.NaiveColor;
cT    = TransferLearning.TransferColor;
cF    = [0.25 0.25 0.25];
cCue  = [0.60 0.15 0.15];
cNull = [0.55 0.55 0.55];
cObs  = [0.25 0.55 0.30];
cCeil = [0.85 0.45 0.15];

f = figure('Color','w','Name','FigAttractorSchematic');
f.Units = 'centimeters';
f.Position(3:4) = [12 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0 0 12 8];
f.PaperSize = [12 8];
layout = tiledlayout(f, 2, 2, 'TileSpacing','compact','Padding','compact');

% ================= (a) 潜空间流场 + 不动点（相图） =================
ax = nexttile(layout, 1);
hold(ax,'on');

omObs = 0.32;                                   % Q ≈ 0.32
M  = -eye(2) + omObs*[0 -1; 1 0];
pFar = [1.10 0.45];
nT = 900; dt = 0.01;

% 浅灰底：仅衬托流场，**不代表状态分区**（本分析无离散状态）
patch(ax, [-1.55 1.55 1.55 -1.55], [-1.00 -1.00 1.00 1.00], [0.965 0.965 0.965], ...
	'EdgeColor','none');

% 箭头流场（方向：4 象限均匀指向 x*，带切向倾斜）
% 箭头流场（手绘：plot 线段 + iArrow 实心三角；与轨迹箭头同一套逻辑，方向无歧义）
[gx, gy] = meshgrid(linspace(-1.25,1.25,7), linspace(-0.65,0.65,4));
hField = gobjects(1,1);
for ii = 1:numel(gx)
	p = [gx(ii), gy(ii)];
	v = (M*p.').';
	d = v/norm(v);
	qc = p + 0.18*d;
	h = plot(ax, [p(1) qc(1)], [p(2) qc(2)], '-', 'Color',[0.45 0.45 0.45], 'LineWidth',0.7);
	iArrow(ax, qc, d, 0.10, [0.45 0.45 0.45]);
	if ii == 1, hField = h; end
end

% 轨迹（两个起点，细线 + 方向箭头）
starts = [1.10 0.45; -0.95 0.52];
hTraj = gobjects(1,1);
for k = 1:size(starts,1)
	x = starts(k,:).'; tr = zeros(nT,2);
	for t = 1:nT
		tr(t,:) = x.';
		x = x + dt*(M*x);
	end
	h = plot(ax, tr(:,1), tr(:,2), '-', 'Color',[0.12 0.12 0.12], 'LineWidth',0.8);
	if k == 1, hTraj = h; end
	for i1 = [70 165]
		i2 = i1 + 18;
		iArrow(ax, tr(i2,:), tr(i2,:)-tr(i1,:), 0.15, [0.12 0.12 0.12]);
	end
end

% cue：静息态 -> 远端状态（input 画成直线粗箭头，文献惯例）
pFar = starts(1,:);
p0   = [0.03 0.03];
hCue = plot(ax, [p0(1) pFar(1)], [p0(2) pFar(2)], '-', 'Color',cCue, 'LineWidth',1.3);
iArrow(ax, pFar, pFar-p0, 0.18, cCue);
text(ax, 0.70,-0.12,'cue','Color',cCue,'HorizontalAlignment','center','VerticalAlignment','top');

% 不动点（实心圆点）是 VAR(1) 的不动点，不是切换模型的状态中心
hFix = plot(ax, 0, 0, 'o', 'MarkerSize',5.5, 'MarkerFaceColor',[0.05 0.05 0.05], 'MarkerEdgeColor','none');
text(ax, 0.10,-0.12,'x*','Color',[0.05 0.05 0.05],'HorizontalAlignment','left','VerticalAlignment','top');

xlim(ax,[-1.55 1.55]); ylim(ax,[-0.95 0.95]);
ax.XTick = []; ax.YTick = [];
ax.Box = 'on'; ax.XColor = [0.55 0.55 0.55]; ax.YColor = [0.55 0.55 0.55];
ax.LineWidth = 0.5;
xlabel(ax,'x_1'); ylabel(ax,'x_2');
title(ax,'(a) one stable fixed point');

% ================= (b) 分阶段：扣弧后超出零模型的量（真实数据） =================
ax = nexttile(layout, 2);
hold(ax,'on');
T = readtable(fullfile(fileparts(mfilename('fullpath')), '..', 'rslds', 'results', ...
	'_fig_excess_by_phase.csv'), 'Delimiter', ',', 'VariableNamingRule','preserve');
phases = ["Learned","Transfer","Final"];
cols   = [cL; cT; cF];
pv     = [0.21 0.0029 0.0029];          % 各阶段 vs 自身零模型（A.18.1, P1）
ylim_hi = max(T.res_excess)*1.35;
plot(ax, [0.3 3.7], [0 0], '--', 'Color',[0.55 0.55 0.55], 'LineWidth',0.6);
for i = 1:3
	v = T.res_excess(strcmp(string(T.phase), phases(i)));
	v = v(:);
	n = numel(v);
	xj = i + 0.13*linspace(-1,1,n).';       % 确定性抖动
	hSc(i) = plot(ax, xj, v, 'o', 'MarkerSize',3.2, 'MarkerFaceColor',cols(i,:), ...
		'MarkerEdgeColor','none');
	plot(ax, [i-0.28 i+0.28], median(v)*[1 1], '-', 'Color',[0.05 0.05 0.05], 'LineWidth',1.1);
	% 显著性标记
	if pv(i) < 0.05
		sym = '**';
	else
		sym = 'n.s.';
	end
	text(ax, i, ylim_hi*0.94, sym, 'Color',cols(i,:), 'HorizontalAlignment','center', ...
		'VerticalAlignment','top');
end
xlim(ax,[0.35 3.65]); ylim(ax,[min(0,min(T.res_excess))*1.25 ylim_hi]);
ax.XTick = 1:3;
ax.XTickLabel = {'Learned','Transfer','Final'};
ax.XTickLabelRotation = 0;
ax.Box = 'off';
ylabel(ax,'excess over null');
title(ax,'(b) beyond linear prediction');

% ================= (c) 两阶段旋转平面部分重叠 =================
ax = nexttile(layout, 3);
hold(ax,'on');
pS = iPoly([-0.30 0.10], 17, [1.80 0.90]);
pT = iPoly([ 0.38 -0.10], -12, [1.80 0.90]);
patch(ax, pS(:,1), pS(:,2), cL, 'FaceAlpha',0.13,'EdgeColor',cL,'LineWidth',0.9);
patch(ax, pT(:,1), pT(:,2), cT, 'FaceAlpha',0.13,'EdgeColor',cT,'LineWidth',0.9);
inter = intersect(polyshape(pS(:,1),pS(:,2)), polyshape(pT(:,1),pT(:,2)));
if ~isempty(inter.Vertices)
	plot(ax, inter, 'FaceColor',[0.20 0.20 0.20], 'FaceAlpha',0.18, 'EdgeColor','none');
end
axis(ax,'equal'); xlim(ax,[-1.55 1.55]); ylim(ax,[-0.95 0.95]); axis(ax,'off');
title(ax,'(c) planes shared in part');
text(ax,-0.45, 0.68,'Learned','Color',cL,'HorizontalAlignment','center','VerticalAlignment','bottom');
text(ax, 1.18, 0.44,'Transfer','Color',cT,'HorizontalAlignment','center','VerticalAlignment','bottom');

% ================= (d) 共享比例：六种条件（实测） =================
ax = nexttile(layout, 4);
hold(ax,'on');
S = readtable(fullfile(fileparts(mfilename('fullpath')), '..', 'rslds', 'results', ...
	'_step41_fig.csv'), 'Delimiter', ',', 'VariableNamingRule','preserve');
varNames = {'P0','P1','P2'};
cM2 = [0.55 0.75 0.60];
cM4 = [0.18 0.42 0.26];
plot(ax,[0.45 3.55],[1 1],'--','Color',[0.55 0.55 0.55],'LineWidth',0.6);
for j = 1:3
	for i = 1:2
		mm = 2*i;
		vv = S.ratio(S.m == mm & strcmp(string(S.variant), varNames{j}));
		xc = j + (i-1.5)*0.22;
		xj = xc + 0.05*linspace(-1,1,numel(vv)).';
		if i == 1, col = cM2; else, col = cM4; end
		plot(ax, xj, vv, 'o','MarkerSize',3, 'MarkerFaceColor',col, 'MarkerEdgeColor','none');
		plot(ax, [xc-0.09 xc+0.09], median(vv)*[1 1], '-', 'Color',[0.05 0.05 0.05], 'LineWidth',1.0);
	end
end
xlim(ax,[0.45 3.55]); ylim(ax,[0 1.10]);
ax.XTick = 1:3; ax.XTickLabel = varNames; ax.XTickLabelRotation = 0; ax.Box = 'off';
ylabel(ax,'cross / ceiling');
title(ax,'(d) share of the ceiling');
hM2 = plot(ax, nan, nan, 'o','MarkerSize',3.5, 'MarkerFaceColor',cM2, 'MarkerEdgeColor','none');
hM4 = plot(ax, nan, nan, 'o','MarkerSize',3.5, 'MarkerFaceColor',cM4, 'MarkerEdgeColor','none');
lgd = legend(ax, [hM2 hM4], {'top 2 planes','top 4 planes'}, ...
	'Location','southoutside','Orientation','horizontal','Box','off');
lgd.ItemTokenSize = [5 5];

% ================= 不再用 figure 级图例（会跨到 (b)） =================
% (a) 的四个元素已就地标注：x* / cue / 轨迹带方向三角，流场用一行小字。

svgPath = TransferLearning.ExportStandardFigure(f, 1.5, 'FigAttractorSchematic.svg');
fprintf('Wrote: %s\n', svgPath);
end

%% ================= local functions =================
function h = hackCueMarker(ax, col)
h = plot(ax, nan, nan, '-', 'Color',col, 'LineWidth',1.3);
end

function p = iPoly(c, ang, sz)
R = [cosd(ang) -sind(ang); sind(ang) cosd(ang)];
base = [sz(1) sz(2); -sz(1) sz(2); -sz(1) -sz(2); sz(1) -sz(2)]/2;
p = (R*base.').' + c;
end

function iArrow(ax, p, dirv, L, col)
% 实心三角箭头（tip = p）。quiver 关闭自动缩放时头长 = MaxHeadSize x 向量长，
% 短向量下等于不可见，故不用 quiver。
d = dirv(:).'; d = d/norm(d);
n = [-d(2) d(1)];
base = p - L*d;
W = 0.42*L;
a = base + W*n;
b = base - W*n;
patch(ax, [p(1) a(1) b(1)], [p(2) a(2) b(2)], col, 'EdgeColor','none');
end
