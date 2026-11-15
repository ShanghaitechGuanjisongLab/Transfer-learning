% Fig1 神经反应热图 2×3（仅保留 Learned 阶段活跃细胞）
%
%  行 1  12 h : TransferLearning.AudioLightBaseline（11 只）
%  行 2  7 d  : TransferLearning.Vacation7        （6 只）
%  列 1  naive (audio only)  : Phase Naive    + Stimulus AudioOnly
%  列 2  learned (audio water): Phase Learned  + Stimulus AudioWater
%  列 3  transfer            : Phase Transfer + Stimulus LightWater
%
% 细胞筛选（沿用 英文图/Fig2O… 里 iIsActiveAt1s 的定义）：
%   以线索前 3 s 为基线，某细胞在 1 s 处的 z-score 超过
%   mean(baseline z) + 3*SD(baseline z) 即判为「Learned 阶段活跃」。
%   三列画同一批细胞（CellUID 跨阶段可对齐），行按 Learned 曲线的峰值时间排序。
%
% 数值：每试次用线索前 3 s 基线标准化，再在细胞内对试次取【中位数】；
%   直接画 z 值（不再逐行二次 z-score），幅度可比；六面板共用对称色标。
%
% 尺寸：排版 90×68 mm、6 pt → 导出 180×136 mm、12 pt（Scale 2）。
clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end

%% 参数
kSigma = 3;        %活跃阈值：baseline mean + kSigma * baseline SD
climPct = 95;      %色标取 |z| 的百分位（越小颜色越饱和）
dsList   = {TransferLearning.AudioLightBaseline(), TransferLearning.Vacation7()};
phaseCol = ["Naive", "Learned", "Transfer"];
stimCol  = ["AudioOnly", "AudioWater", "LightWater"];
titCol   = ["Naive (audio only)", "Learned (audio water)", "12 h transfer", ...
	"Naive (audio only)", "Learned (audio water)", "7 d transfer"];

xs = TransferLearning.Xs;
if isduration(xs), xs = seconds(xs); else, xs = double(xs); end
baseMask = xs < 0;                          %线索前 3 s 作为基线
[~, idx1s] = min(abs(xs - 1));              %1 s 处的采样点

%% 逐数据集 × 阶段算「细胞 × 时间」的试次平均 z-score
%注意：不用 QueryNTS(UniExp.Flags.ZScore)，Vacation7 里有细胞基线为 0 会直接抛
%「归一化数据出现NaN」。这里自己按同一规则算：每试次用线索前 3 s 做基线标准化，
%再在细胞内对试次取平均。
MuAll = cell(2, 3);
UIDAll = cell(2, 3);
for r = 1:2
	DS = dsList{r};
	T  = DS.Trials(:, {'TrialUID', 'BlockUID', 'Stimulus'});
	B  = DS.Blocks(:, {'BlockUID', 'DateTime'});
	DT = DS.DateTimes(:, {'DateTime', 'Phase'});
	T  = innerjoin(T, B, 'Keys', 'BlockUID');
	T  = innerjoin(T, DT, 'Keys', 'DateTime');
	for c = 1:3
		keep = string(T.Phase) == phaseCol(c) & string(T.Stimulus) == stimCol(c);
		trialIDs = uint64(T.TrialUID(keep));
		TS = DS.TrialSignals;
		sel = ismember(uint64(TS.TrialUID), trialIDs);
		sig = double(TS.ResampledSignal(sel, :));
		cid = uint64(TS.CellUID(sel));
		%每试次按线索前基线标准化
		bMu = mean(sig(:, baseMask), 2, 'omitnan');
		bSd = std(sig(:, baseMask), 0, 2, 'omitnan');
		ok = isfinite(bMu) & isfinite(bSd) & bSd > 0;
		z = (sig(ok, :) - bMu(ok)) ./ bSd(ok);
		cid = cid(ok);
		if isempty(z)
			MuAll{r, c} = zeros(0, numel(xs));
			UIDAll{r, c} = uint64.empty(0, 1);
			fprintf('行%d %-10s : 无数据\n', r, phaseCol(c) + "/" + stimCol(c));
			continue;
		end
		[G, uid] = findgroups(cid);
		%跨试次取中位数（与项目 QueryNTATS 的 UniExp.Flags.Median 口径一致）
		mu = splitapply(@(x) median(x, 1, 'omitnan'), z, G);
		MuAll{r, c} = mu;
		UIDAll{r, c} = uid;
		fprintf('行%d %-10s : 细胞 %4d，试次 %6d\n', r, ...
			phaseCol(c) + "/" + stimCol(c), height(mu), height(z));
	end
end

%% 用 Learned 阶段判定活跃细胞
%与 英文图/Fig2O… 的 iIsActiveAt1s 完全一致：对【试次平均后的曲线】取基线段的
%均值与标准差（沿时间），1 s 处超过 mean(base)+3*SD(base) 即活跃。
M = cell(2, 3);
for r = 1:2
	muL = MuAll{r, 2};
	uidL = UIDAll{r, 2};
	baseMu = mean(muL(:, baseMask), 2, 'omitnan');
	baseSd = std(muL(:, baseMask), 0, 2, 'omitnan');
	v1 = muL(:, idx1s);
	active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > baseMu + kSigma .* baseSd);

	common = uidL;
	for c = [1 3]
		common = intersect(common, UIDAll{r, c});
	end
	sel = active & ismember(uidL, common);
	uidSel = uidL(sel);
	fprintf('\n行 %d：Learned 活跃 %d / %d；三列共有且活跃 %d 个\n', ...
		r, nnz(active), numel(active), numel(uidSel));

	muLsel = MuAll{r, 2}(sel, :);
	[~, ipk] = max(muLsel, [], 2);
	pk = max(muLsel, [], 2);
	[~, ord] = sortrows([ipk, -pk]);
	uidSel = uidSel(ord);
	for c = 1:3
		[~, loc] = ismember(uidSel, UIDAll{r, c});
		M{r, c} = MuAll{r, c}(loc, :);
	end
end

%只展示 -1 ~ 2 s（计算仍用完整 3 s 基线做 z-score 与活跃判定）
%左右各多带一个采样点，否则 -1 / 2 的刻度与 1 s 的虚线会压在边框上
xKeep = xs >= -1.125 & xs <= 2.125;
xsShow = xs(xKeep);
for r = 1:2
	for c = 1:3
		M{r, c} = M{r, c}(:, xKeep);
	end
end

%共用色标（与 Fig1J / Fig3A 的 volshow 热图同一套蓝-白-红）
nMap = 256;	nHalf = nMap / 2;
blueWhiteRed = [linspace(0,1,nHalf)', linspace(0,1,nHalf)', ones(nHalf,1); ...
				 ones(nHalf,1), linspace(1,0,nHalf)', linspace(1,0,nHalf)'];
vv = cellfun(@(x) x(:), M, 'UniformOutput', false);
allV = vertcat(vv{:});
cMax = prctile(abs(allV(isfinite(allV))), climPct);
cMax = max(cMax, 0.5);
fprintf('色标范围 ±%.2f（|z| 的 %d 分位）\n', cMax, climPct);

%% 画图
figW = 9.0; figH = 6.8; figScale = 2;
f = figure('Color', 'w', 'Name', 'Fig1 learned-active response heatmap 2x3');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH] * figScale;
t = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

for r = 1:2
	for c = 1:3
		ax = nexttile(t, (r - 1) * 3 + c);
		imagesc(ax, xsShow, 1:size(M{r, c}, 1), M{r, c});
		axis(ax, 'xy');
		%两条参考虚线：0 s（线索开始）用点线，1 s 用短线
		xline(ax, 0, ':', 'Color', [0 0 0], 'LineWidth', 0.5, 'HandleVisibility', 'off');
		xline(ax, 1, '--', 'Color', [0 0 0], 'LineWidth', 0.5, 'HandleVisibility', 'off');
		clim(ax, [-cMax cMax]);
		colormap(ax, blueWhiteRed);
		ax.XLim = [xsShow(1) xsShow(end)];
		if r == 2
			xlabel(ax, 'Time (s)');
		else
			ax.XTickLabel = [];
		end
		if c == 1
			ylabel(ax, 'Learned-active cells');
		else
			ax.YTickLabel = [];
		end
		title(ax, titCol((r - 1) * 3 + c), 'FontWeight', 'normal');
		ax.XTick = [-1 0 1 2];
		ax.XTickLabelRotation = 0;
		box(ax, 'off');
		axForCb = ax;	end
end

cb = colorbar(axForCb);
cb.Layout.Tile = 'east';
cb.Label.String = 'z-score';
cb.Label.FontSize = 6;

f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH] * figScale;
f.PaperPosition = [0 0 figW figH] * figScale;
f.PaperPositionMode = 'manual';
p = TransferLearning.ExportStandardFigure(f, figScale, 'English_Fig1_ResponseHeatmap_2x3.svg');
fprintf('\nWrote: %s\n', p);
