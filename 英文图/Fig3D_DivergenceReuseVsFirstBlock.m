% English Fig3D：散度 / 复用率 与 first-block 命中率的相关性（12 h + 7 d 合并，按队列着色）
%
% 每只鼠一个点：
%   Divergence = 首个 Transfer 光水会话、cue+1 s、全部细胞的 sqrt(Σvar/Σmean²)（Fig2F/Fig1E 口径）
%   Reuse      = |Learned-AW 活跃 ∩ Transfer-LW 活跃| / |Learned-AW 活跃|（FigS1I 口径，3σ）
%   FirstBlock = 同一会话的命中率
% 统计：Spearman rho（双侧）+ 线性拟合线；参考管老师文献 Fig3d 的散点+拟合线+显著性标注
%
% 输出：English_Fig3D_DivergenceReuseVsFirstBlock.svg（12×4 cm，6 pt，两栏）

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

DS12 = TransferLearning.AudioLightBaseline();
DS7 = TransferLearning.Vacation7();
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end
baseMask = (xsSec >= -3) & (xsSec < 0);
[~, idx1s] = min(abs(xsSec(:) - 1));
kSigma = 3;

cohortName = ["12 h", "7 d"];
DSList = {DS12, DS7};
R = table(strings(0,1), strings(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Cohort','Mouse','Divergence','Reuse','FirstBlock'});

for k = 1:2
	DS = DSList{k};
	% Learned 阶段（声水）活跃细胞
	GLearned = DS.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	learnedTbl = iActiveTable(DS, GLearned, idx1s, baseMask, kSigma);
	% 每鼠首个 Transfer 光水会话
	firstT = iFirstTransferSession(DS);
	for i = 1:height(firstT)
		m = firstT.Mouse(i);
		dt = firstT.DateTime(i);
		la = unique(learnedTbl.CellUID(learnedTbl.Mouse == m & learnedTbl.IsActive));
		if isempty(la), continue; end
		% 该 transfer 会话的 NTATS（用于散度 + 活跃判定）
		ntsCell = DS.QueryNTS(struct('Stimulus','LightWater','Mouse',m,'DateTime',dt), ...
			UniExp.Flags.ZScore, 1:24);
		if iscell(ntsCell), nts = ntsCell{1}; else, nts = ntsCell; end
		if isempty(nts), continue; end
		trialUIDs = unique(uint64(nts.TrialUID), 'stable');
		if numel(trialUIDs) < 2, continue; end
		[CTT, cellUIDs] = iBuildCtt(nts, trialUIDs);
		if isempty(CTT), continue; end
		X = CTT(:, :, idx1s);
		div = iDivFromX(X);
		% 该会话的活跃细胞（同 3σ 判据，取全时间轴上的 cue+1s）
		Xb = reshape(CTT(:,:,baseMask), size(CTT,1), []);
		baseMu = mean(Xb, 2, 'omitnan');
		baseSd = std(Xb, 0, 2, 'omitnan');
		act = isfinite(X(:,1)) & isfinite(baseMu) & isfinite(baseSd) & ...
			(X(:,1) > baseMu + kSigma * baseSd);
		ta = cellUIDs(act);
		nBoth = numel(intersect(la, ta));
		reuse = nBoth / numel(la);
		% 首 block 命中率
		Tq = DS.TableQuery(["Mouse","DateTime","Stimulus","Behavior"], ...
			Mouse = m, Stimulus = "LightWater", DateTime = dt);
		if isempty(Tq), continue; end
		fb = mean(double(Tq.Behavior), 'omitnan');
		R = [R; table(cohortName(k), string(m), div, reuse, fb, ...
			'VariableNames', {'Cohort','Mouse','Divergence','Reuse','FirstBlock'})]; %#ok<AGROW>
	end
end

ok = isfinite(R.Divergence) & isfinite(R.Reuse) & isfinite(R.FirstBlock);
R = R(ok, :);
fprintf('\n=== Fig3D：%d 只鼠（12 h %d / 7 d %d）===\n', height(R), ...
	nnz(R.Cohort=="12 h"), nnz(R.Cohort=="7 d"));
fprintf('%-14s rho=%+.3f  p=%.4g\n', 'Divergence~FB', ...
	corr(R.Divergence, R.FirstBlock, 'type','Spearman'), ...
	corrP(R.Divergence, R.FirstBlock));
fprintf('%-14s rho=%+.3f  p=%.4g\n', 'Reuse~FB', ...
	corr(R.Reuse, R.FirstBlock, 'type','Spearman'), ...
	corrP(R.Reuse, R.FirstBlock));
for k = 1:2
	S = R(R.Cohort == cohortName(k), :);
	fprintf('  %s: n=%d  Div=%.3f  Reuse=%.3f  FB=%.3f\n', cohortName(k), height(S), ...
		mean(S.Divergence), mean(S.Reuse), mean(S.FirstBlock));
end

%% ---------- 画图 ----------
cCo = [TransferLearning.Color12h; TransferLearning.Color7d] / 255;
f = figure('Color','w','Name','English Fig3D divergence reuse vs first block');
f.Units = 'centimeters';
f.Position(3:4) = [12, 4.2];
f.PaperUnits = 'centimeters';
f.PaperSize = [12 4.2];
f.PaperPosition = [0 0 12 4.2];
f.PaperPositionMode = 'manual';
tl = tiledlayout(f, 1, 2, 'TileSpacing','compact','Padding','compact');

axA = nexttile(tl, 1);
hA = iScatterPanel(axA, R, 'Divergence', 'FirstBlock', cCo, cohortName);
lg = legend(axA, hA, cellstr(cohortName), 'Location', 'southwest', 'Box', 'off');
lg.FontSize = 6;
lg.ItemTokenSize = [8 6];

axB = nexttile(tl, 2);
iScatterPanel(axB, R, 'Reuse', 'FirstBlock', cCo, cohortName);
axB.YTickLabel = [];

TransferLearning.ExportStandardFigure(f, 1, 'English_Fig3D_DivergenceReuseVsFirstBlock.svg');
fprintf('Wrote: English_Fig3D_DivergenceReuseVsFirstBlock.svg\n');

assignin('base', 'Fig3D_DivReuseFirstBlock', R);

%% ================= 局部函数 =================
function h = iScatterPanel(ax, R, xName, yName, cCo, cohortName)
hold(ax,'on');
h = gobjects(2,1);
for k = 1:2
	use = R.Cohort == cohortName(k);
	h(k) = scatter(ax, R.(xName)(use), R.(yName)(use), 8, cCo(k,:), 'filled', ...
		'MarkerEdgeColor', cCo(k,:) * 0.55, 'LineWidth', 0.2);
end
x = double(R.(xName));
y = double(R.(yName));
if numel(x) >= 3 && std(x) > 0
	p = polyfit(x, y, 1);
	xx = linspace(min(x), max(x), 50).';
	plot(ax, xx, polyval(p, xx), '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8);
end
rho = corr(x, y, 'type','Spearman');
p = corrP(x, y);
text(ax, 0.95, 0.95, sprintf('\\rho = %.2f\n%s', rho, iStars(p)), 'Units','normalized', ...
	'HorizontalAlignment','right','VerticalAlignment','top','FontSize',6,'Color',[0.25 0.25 0.25]);
xlabel(ax, xName, 'FontSize', 6);
ylabel(ax, 'First block', 'FontSize', 6);
ax.FontSize = 6;
ax.LineWidth = 0.5;
box(ax,'off');
grid(ax,'off');
end

function s = iStars(p)
if ~isfinite(p), s = 'n.s.';
elseif p < 0.001, s = 'p < 0.001';
elseif p < 0.01, s = sprintf('p = %.3f', p);
elseif p < 0.05, s = sprintf('p = %.3f', p);
else, s = sprintf('p = %.2f (n.s.)', p);
end
end

function p = corrP(x, y)
%Spearman 的 t 近似 p 值（与 corr 的 type='Spearman' 一致）
x = double(x(:)); y = double(y(:));
ok = isfinite(x) & isfinite(y);
x = x(ok); y = y(ok);
n = numel(x);
if n < 4, p = NaN; return; end
r = corr(x, y, 'type','Spearman');
t = r * sqrt((n - 2) / max(1 - r^2, eps));
p = 2 * (1 - tcdf(abs(t), n - 2));
end

function T = iActiveTable(DS, G, idx1s, baseMask, kSigma)
T = table(strings(0,1), uint64.empty(0,1), false(0,1), 'VariableNames', {'Mouse','CellUID','IsActive'});
if isempty(G), return; end
S = UniExp.NtatsCellStrip(struct('Q', G));
X = iNtats3D(S);
if isempty(X), return; end
if size(X,3) > 1, XL = squeeze(X(:,:,1)); else, XL = squeeze(X); end
baseMu = mean(XL(:,baseMask), 2, 'omitnan');
baseSd = std(XL(:,baseMask), 0, 2, 'omitnan');
v1 = XL(:, idx1s);
act = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > baseMu + kSigma*baseSd);
uid = uint64(S.CellUID);
C = DS.Cells;
C.CellUID = uint64(C.CellUID);
C.Mouse = string(C.Mouse);
[~, loc] = ismember(uid, C.CellUID);
mice = strings(numel(uid), 1);
mice(loc > 0) = C.Mouse(loc(loc > 0));
T = table(mice, uid, logical(act), 'VariableNames', {'Mouse','CellUID','IsActive'});
end

function X = iNtats3D(S)
if istable(S), nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS'), nt = S.NTATS;
else, nt = S; end
if isa(nt,'MATLAB.DataTypes.NDTable')
	try, X = nt.Data.Data; catch, X = nt{:,:,:}.Data; end
	return;
end
X = nt;
end

function T = iFirstTransferSession(DS)
T = table(strings(0,1), NaT(0,1), 'VariableNames', {'Mouse','DateTime'});
Q = DS.TableQuery(["Mouse","DateTime","Stimulus"], Phase = "Transfer");
if isempty(Q), return; end
Q.Mouse = string(Q.Mouse);
Q.Stimulus = string(Q.Stimulus);
Q = Q(Q.Stimulus == "LightWater", :);
ms = unique(Q.Mouse, 'stable');
for i = 1:numel(ms)
	dt = Q.DateTime(Q.Mouse == ms(i));
	T = [T; table(ms(i), min(dt), 'VariableNames', {'Mouse','DateTime'})]; %#ok<AGROW>
end
end

function [CTT, cellUIDs] = iBuildCtt(nts, trialUIDs)
allCells = unique(uint64(nts.CellUID));
tr = cell(numel(allCells),1);
keep = zeros(numel(allCells),1,'uint64');
n = 0;
for i = 1:numel(allCells)
	rowsC = uint64(nts.CellUID) == allCells(i);
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC,:));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf), continue; end
	so = sig(loc,:);
	if any(~isfinite(so),'all'), continue; end
	n = n + 1; tr{n} = so; keep(n) = allCells(i);
end
if n < 3, CTT = []; cellUIDs = uint64([]); return; end
tr = tr(1:n); cellUIDs = keep(1:n);
nT = numel(trialUIDs); nTime = size(tr{1},2);
CTT = nan(n, nT, nTime);
for i = 1:n, CTT(i,:,:) = reshape(tr{i}, 1, nT, nTime); end
end

function div = iDivFromX(X)
sig = sum(mean(X,2).^2);
noi = sum(var(X,[],2));
if sig > 0, div = sqrt(noi/sig); else, div = NaN; end
end
