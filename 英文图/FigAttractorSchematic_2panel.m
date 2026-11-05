function FigAttractorSchematic_2panel()
%[text] (a)(c) 两块内容组成的双面板示意图（独立输出）
%
%   (a) 单一稳定不动点 + 带切向分量的回流（相图，解析构造）
%   (b) 两阶段旋转平面部分重叠（示意，灰色为交集）
%
% 内容与主图 FigAttractorSchematic 的 (a)(c) 一致，此处重新编号为 (a)(b)。
% 画布 12 × 4 cm（无 legend，按规范取 4 cm 高）；字号 Scale 1.5 ⇒ 9 pt。
%
% ⚠ 本项目未采用切换式潜变量模型；两个面板均为概念示意，几何形态忠实于实测
%   （Q≈0.3 过阻尼、两阶段几何不可区分 A.27、平面部分共享 A.25/A.26）。

if ~exist('TransferLearning','class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file'), matlab.project.loadProject(prjFile); end
end

cL   = TransferLearning.NaiveColor;
cT   = TransferLearning.TransferColor;
cCue = [0.60 0.15 0.15];

f = figure('Color','w','Name','FigAttractorSchematic_2panel');
f.Units = 'centimeters';
f.Position(3:4) = [12 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0 0 12 4];
f.PaperSize = [12 4];
layout = tiledlayout(f, 1, 2, 'TileSpacing','compact','Padding','compact');

% ================= (a) 单一稳定不动点 =================
ax = nexttile(layout, 1);
hold(ax,'on');

omObs = 0.32;                                   % Q ≈ 0.32
M  = -eye(2) + omObs*[0 -1; 1 0];
pFar = [1.10 0.45];
nT = 900; dt = 0.01;

patch(ax, [-1.55 1.55 1.55 -1.55], [-1.00 -1.00 1.00 1.00], [0.965 0.965 0.965], ...
	'EdgeColor','none');

% 流场（手绘箭头，方向无歧义）
[gx, gy] = meshgrid(linspace(-1.25,1.25,7), linspace(-0.65,0.65,4));
for ii = 1:numel(gx)
	p = [gx(ii), gy(ii)];
	v = (M*p.').';
	d = v/norm(v);
	qc = p + 0.18*d;
	plot(ax, [p(1) qc(1)], [p(2) qc(2)], '-', 'Color',[0.45 0.45 0.45], 'LineWidth',0.7);
	iArrow(ax, qc, d, 0.10, [0.45 0.45 0.45]);
end

% 轨迹
starts = [1.10 0.45; -0.95 0.52];
for k = 1:size(starts,1)
	x = starts(k,:).'; tr = zeros(nT,2);
	for t = 1:nT
		tr(t,:) = x.';
		x = x + dt*(M*x);
	end
	plot(ax, tr(:,1), tr(:,2), '-', 'Color',[0.12 0.12 0.12], 'LineWidth',0.8);
	for i1 = [70 165]
		i2 = i1 + 18;
		iArrow(ax, tr(i2,:), tr(i2,:)-tr(i1,:), 0.15, [0.12 0.12 0.12]);
	end
end

% cue
p0 = [0.03 0.03];
plot(ax, [p0(1) pFar(1)], [p0(2) pFar(2)], '-', 'Color',cCue, 'LineWidth',1.3);
iArrow(ax, pFar, pFar-p0, 0.18, cCue);
text(ax, 0.70,-0.12,'cue','Color',cCue,'HorizontalAlignment','center','VerticalAlignment','top');

% 不动点
plot(ax, 0, 0, 'o', 'MarkerSize',5.5, 'MarkerFaceColor',[0.05 0.05 0.05], 'MarkerEdgeColor','none');
text(ax, 0.10,-0.12,'x*','Color',[0.05 0.05 0.05],'HorizontalAlignment','left','VerticalAlignment','top');

xlim(ax,[-1.55 1.55]); ylim(ax,[-0.95 0.95]);
ax.XTick = []; ax.YTick = [];
ax.Box = 'on'; ax.XColor = [0.55 0.55 0.55]; ax.YColor = [0.55 0.55 0.55];
ax.LineWidth = 0.5;
xlabel(ax,'x_1'); ylabel(ax,'x_2');
title(ax,'(a) one stable fixed point');

% ================= (b) 两阶段旋转平面部分重叠 =================
ax = nexttile(layout, 2);
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
title(ax,'(b) planes shared in part');
text(ax,-0.45, 0.68,'Learned','Color',cL,'HorizontalAlignment','center','VerticalAlignment','bottom');
text(ax, 1.18, 0.44,'Transfer','Color',cT,'HorizontalAlignment','center','VerticalAlignment','bottom');

svgPath = TransferLearning.ExportStandardFigure(f, 1.5, 'FigAttractorSchematic_2panel.svg');
fprintf('Wrote: %s\n', svgPath);
end

%% ================= local functions =================
function p = iPoly(c, ang, sz)
R = [cosd(ang) -sind(ang); sind(ang) cosd(ang)];
base = [sz(1) sz(2); -sz(1) sz(2); -sz(1) -sz(2); sz(1) -sz(2)]/2;
p = (R*base.').' + c;
end

function iArrow(ax, p, dirv, L, col)
d = dirv(:).'; d = d/norm(d);
n = [-d(2) d(1)];
base = p - L*d;
W = 0.42*L;
a = base + W*n;
b = base - W*n;
patch(ax, [p(1) a(1) b(1)], [p(2) a(2) b(2)], col, 'EdgeColor','none');
end
