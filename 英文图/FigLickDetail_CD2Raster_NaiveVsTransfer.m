% FigLickDetail: 舔水细节栅格图（Naive vs Transfer，多鼠叠加）
%
% 左：Naive（LAB = LightAudioBaseline + LAInterspersed 的首个纯光水会话）
% 右：Transfer（ALB = AudioLightBaseline 的首个 Transfer 纯光水会话）
%
% 图形：横轴 = 相对 cue 的时间（s）；纵轴 = 试次序号（session 内）；每舔一下画一条小竖线。
%       同一试次行上叠加**所有鼠**的舔水刻线（半透明），故同一行可见多只鼠的叠印。
%
% 数据来源：Blocks.BlockTags.CD2 —— 模拟舔水通道（基线≈512/513，舔水时抬到 ~580–760）。
%   采样率逐 block 估计（TransferLearning.BlockSampleRate）；本项目多数 block ≈8 Hz，
%   少数（yqn1130 / yqn0020 / yqn0240）≈30 Hz。⇒ 8 Hz 下单次舔（~100 ms）不可分辨，
%   一条刻线 = 一个**超阈值帧**（8 Hz 时等效 125 ms）。这是本数据的极限分辨率，勿读成单次舔。
%
% 口径：
%   · 只取 Design == "LightWater" 的块（排除 LLw / LAuW / AuAuw 等混合设计）
%   · 每只鼠取 Session == 1（与 Fig1g / FigS1B 同口径）；若该会话完全没有 CD2 标通道
%     （2022 年早期 4 只鼠的 session 无 BlockTags），则顺延到该鼠后续第一个可用会话
%   · 只取 Stimulus == "LightWater" 的试次；cue 帧下标取 Trials.SampleRange.Tag
%   · 舔水判定：CD2 − median(block) > 20（实测舔水帧 ≥ +60，噪声仅 ~0.1，故 20 很安全）
%   · 代表鼠只从**采样率 ≤ 15 Hz** 的鼠中选（本项目有 3 只鼠的 block 是 ≈30 Hz，
%     其刻线密度是 8 Hz 的 4 倍，混在同一面板里两组就不可比）；30 Hz 鼠仍计入全组统计
%
% 输出：SVG 到标准图目录（TransferLearning.StandardFigureSvgPath）
% 执行：直接 Run（脚本）

clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------------- 参数 ----------------
HALF_WIN_SEC = 3;        % 逐试次取的半窗（秒，cue 两侧）
LICK_DELTA   = 20;       % CD2 超过 block 基线多少算"正在舔"
WinSec       = [-1, 3];  % 显示窗
TICK_HALF_H  = 0.35;     % 刻线半高（单位：试次）；太小相邻行会糊成一片
MIN_TRIAL    = 5;        % 少于这么多可用试次则该会话不可用，顺延
N_REP        = 3;        % 每组只画**最接近组中位数**的 N 只鼠（设 Inf 则画全部）
FS_MAX_REP   = 15;       % 只从采样率 ≤ 此值的鼠中选代表鼠（避免 30 Hz 鼠的刻线比 8 Hz 密 4 倍，两组不可比）

GroupName  = ["Naive", "Transfer"];
GroupLabel = ["Naive", "Transfer"];   % 图上只用组名，不写 LAB/ALB 缩写与 n
GroupCol   = [TransferLearning.NaiveColor; TransferLearning.TransferColor];

%% ---------------- 数据源元信息 ----------------
SrcNames = ["LightAudioBaseline", "LAInterspersed", "AudioLightBaseline"];
Meta = struct();
for nm = SrcNames
	DS = iGetDS(nm);
	[bMouse, bPhase, bDesign] = TransferLearning.AlignBlockMeta(DS.Blocks, DS.DateTimes);
	r = TransferLearning.BlockSampleRate(DS, DS.Blocks, bMouse);
	key = matlab.lang.makeValidName(nm);
	% ⚠ 不能写 struct('DS', DS, ...)：struct() 会对 DataSet 调它的 struct 方法而报错
	Meta.(key).DS       = DS;
	Meta.(key).Mouse    = bMouse;
	Meta.(key).Phase    = bPhase;
	Meta.(key).Design   = string(bDesign);
	Meta.(key).Rate     = r;
	Meta.(key).DateTime = iNormDT(DS.Blocks.DateTime);
end

%% ---------------- 会话表（每鼠首个纯光水会话）----------------
Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
S1 = Sess(Sess.Session == 1 & ismember(Sess.Group, GroupName), :);
fprintf('首个纯光水会话：Naive %d 只，Transfer %d 只\n\n', ...
	sum(S1.Group == "Naive"), sum(S1.Group == "Transfer"));

%% ---------------- 逐鼠逐试次提取舔水刻线 ----------------
mice = unique(S1.Mouse, 'stable');
nMax = numel(mice);
MouseName = strings(nMax, 1);
GroupOf   = strings(nMax, 1);
NTrial    = zeros(nMax, 1);
CueFrac   = zeros(nMax, 1);
FsOf      = zeros(nMax, 1);
TickTime  = cell(nMax, 1);
TickRow   = cell(nMax, 1);
row = 0;

for iM = 1:nMax
	m = mice(iM);
	% ⚠ 用完整 Sess（不止 Session==1），这样某会话无标通道时可顺延到后续会话
	rows = Sess(Sess.Mouse == m & ismember(Sess.Group, GroupName), :);
	if isempty(rows), continue; end
	rows = sortrows(rows, {'Session','DateTime'});

	accepted = false;
	for iS = 1:height(rows)
		M = Meta.(matlab.lang.makeValidName(string(rows.Source(iS))));
		dt = iNormDT(rows.DateTime(iS));
		[tk, rw, nRow, nCueHit, fsMed] = iExtractSession(M, dt, HALF_WIN_SEC, LICK_DELTA);
		if nRow < MIN_TRIAL
			fprintf('  %-9s S%-3d %s：无可用的 Design=LightWater 标通道记录，顺延\n', ...
				string(m), rows.Session(iS), string(dt));
			continue;
		end
		row = row + 1;
		MouseName(row) = string(m);
		GroupOf(row)   = string(rows.Group(iS));
		NTrial(row)    = nRow;
		CueFrac(row)   = nCueHit / nRow;
		FsOf(row)      = fsMed;
		TickTime{row}  = tk;
		TickRow{row}   = rw;
		accepted = true;
		break;
	end
	if ~accepted
		fprintf('  %-9s 所有纯光水会话均无 CD2 标通道，整只排除\n', string(m));
	end
end

MouseName = MouseName(1:row);
GroupOf   = GroupOf(1:row);
NTrial    = NTrial(1:row);
CueFrac   = CueFrac(1:row);
FsOf      = FsOf(1:row);
TickTime  = TickTime(1:row);
TickRow   = TickRow(1:row);

T = table(MouseName, GroupOf, NTrial, FsOf, CueFrac, ...
	'VariableNames', {'Mouse','Group','NTrial','Fs','CueLickFrac'});

%% ---------------- 统计 ----------------
fprintf('\n%-10s %-9s %6s %10s\n', 'Mouse', 'Group', 'nTr', 'cueLick%');
for i = 1:height(T)
	fprintf('%-10s %-9s %6d %10.2f\n', T.Mouse(i), T.Group(i), T.NTrial(i), T.CueLickFrac(i));
end
a = T.CueLickFrac(T.Group == "Naive");
b = T.CueLickFrac(T.Group == "Transfer");
pCue = NaN;
if numel(a) > 1 && numel(b) > 1
	pCue = ranksum(a, b);
	fprintf('\ncue 期(0-1 s)舔水试次比例：Naive %.2f ± %.2f (n=%d) vs Transfer %.2f ± %.2f (n=%d), p = %.3g\n', ...
		mean(a), std(a) / sqrt(numel(a)), numel(a), mean(b), std(b) / sqrt(numel(b)), numel(b), pCue);
end

%% ---------------- 代表鼠筛选：最接近**组中位数**的 N_REP 只 ----------------
% 每鼠的超阈值帧"舔水概率"曲线：[-1,3] s 按 0.1 s 分箱，每箱 = 该鼠有多少比例的试次在此箱有舔
% ⚠ 直接用欧氏距离会被 1–3 s（各鼠都很像）的箱子主导，cue 期(0–1 s)的组间差异被淹没
%   ⇒ 逐时间箱用该组的 **median / (1.4826·MAD)** 稳健标准化（各箱等权），再算到组中位数(原点)的距离
%   用中位数而不是均值：Naive 组的 cue 期舔水呈双峰，均值落在两峰之间的空档里，中位数才稳
BinEdges = WinSec(1):0.1:WinSec(2);
nBin = numel(BinEdges) - 1;
P = zeros(row, nBin);
for i = 1:row
	tk = TickTime{i};
	rw = TickRow{i};
	for j = 1:NTrial(i)
		v = tk(rw == j);
		if isempty(v), continue; end
		h = histcounts(v, BinEdges);
		P(i, :) = P(i, :) + double(h > 0);   % 该试次该箱至少舔一帧
	end
	P(i, :) = P(i, :) / NTrial(i);
end

IsRep = false(row, 1);
DistToMedian = nan(row, 1);
fprintf('\n=== 代表鼠（每组取距离组中位数最近的 %d 只）===\n', N_REP);
for g = 1:2
	sel = find(GroupOf == GroupName(g));
	if isempty(sel), continue; end
	% 只在 8 Hz 鼠中选：30 Hz 鼠的刻线密度高 4 倍，混在一起两组就不可比
	cand = sel(FsOf(sel) <= FS_MAX_REP);
	if numel(cand) < min(N_REP, numel(sel))
		fprintf('    （%s：采样率 ≤ %g Hz 的鼠不够 %d 只，退回全组候选）\n', ...
			GroupName(g), FS_MAX_REP, N_REP);
		cand = sel;
	end
	X   = P(cand, :);
	med = median(X, 1);
	sc  = 1.4826 * median(abs(X - med), 1);   % 逐时间箱的稳健尺度
	sc(sc == 0) = 1;
	DistToMedian(cand) = sqrt(sum(((X - med) ./ sc).^2, 2));
	[~, ordD] = sort(DistToMedian(cand));
	nTake = min(N_REP, numel(cand));
	Pick = cand(ordD(1:nTake));
	IsRep(Pick) = true;
	fprintf('  %s（n=%d，候选 %d）：', GroupName(g), numel(sel), numel(cand));
	for k = 1:nTake
		fprintf('%s(d=%.2f, %.0fHz) ', MouseName(Pick(k)), DistToMedian(Pick(k)), FsOf(Pick(k)));
	end
	fprintf('\n    选中鼠 cue 期舔水比例 中位 %.2f vs 全组中位 %.2f\n', ...
		median(CueFrac(Pick)), median(CueFrac(sel)));
	% 该组在 cue 期是否双峰（中位鼠可能两边都不像）
	cf = CueFrac(sel);
	if any(cf > 0.35) && any(cf < 0.05)
		fprintf('    ⚠ 该组 cue 期舔水比例呈双峰（低 %.2f / 高 %.2f），中位鼠落在低谷一側\n', ...
			mean(cf(cf < 0.05)), mean(cf(cf > 0.35)));
	end
end

T = addvars(T, DistToMedian, IsRep, 'After', 'CueLickFrac');

%% ---------------- 出图 ----------------
% 作图规范：英文论文/英文图规范.md（高 4 cm；宽 1.5 cm 整倍；字号 6 pt；
%   多 tile 同 Y 轴只保留最左列 Y 轴、同 X 轴只保留最下行 X 轴；ylabel 写 Layout 级；
%   不手动设置 Y 轴刻度；两行 tile 的高可取基础高的 2 倍）
RowMax = max(NTrial(IsRep));
OrientationList  = ["horizontal", "vertical"];   % 同时出横版与竖版
ExportPreviewPng = true;                         % 顺带把 PNG 预览写到本目录

for Orientation = reshape(OrientationList, 1, [])
	f = figure('Color', 'w', 'Name', sprintf('Lick detail: CD2 raster (%s)', Orientation));
	f.Units = 'centimeters';
	if Orientation == "vertical"
		f.Position(3:4) = [4.5, 8.0];    % 单列两行 ⇒ 高取基础高 ×2
		L = tiledlayout(f, 2, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
	else
		f.Position(3:4) = [9.0, 4.0];
		L = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
	end

	RasterH = gobjects(0);   % 需在样式函数后单独设细线宽（否则被统一成 1 pt，刻线会变成方块）
	for g = 1:2
		ax = nexttile(L, g);
		hold(ax, 'on');
		c = GroupCol(g, :);

		selMice = find(GroupOf == GroupName(g) & IsRep);
		if isempty(selMice), selMice = find(GroupOf == GroupName(g)); end
		for i = selMice(:)'
			tkI = TickTime{i};
			rwI = TickRow{i};
			if isempty(tkI), continue; end
			% 每只鼠的行号都从 1 开始 ⇒ 天然叠印在同一批试次行上
			x = reshape([tkI.'; tkI.'; nan(1, numel(tkI))], [], 1);
			y = reshape([rwI.' - TICK_HALF_H; rwI.' + TICK_HALF_H; nan(1, numel(rwI))], [], 1);
			RasterH(end+1) = plot(ax, x, y, '-', 'Color', [c, 0.35], 'LineWidth', 0.4); %#ok<SAGROW>
		end

		xlim(ax, WinSec);
		ylim(ax, [0.4, RowMax + 0.6]);   % 两 tile Y 轴含义相同 ⇒ 统一极限
		title(ax, GroupLabel(g), 'FontWeight', 'normal');
		box(ax, 'off');
		TransferLearning.DrawCueWaterLines(ax);

		if Orientation == "vertical"
			% 两 tile X 轴相同 ⇒ 只保留下行 X 轴
			if g == 2
				xlabel(ax, 'Time from cue (s)');
			else
				ax.XAxis.Visible = 'off';
			end
		else
			% 横版：两 tile 同在一行，X 轴都保留；Y 轴相同 ⇒ 只保留最左列
			xlabel(ax, 'Time from cue (s)');
			if g == 2, ax.YAxis.Visible = 'off'; end
		end
	end
	ylabel(L, 'Trial');

	TransferLearning.Style.ApplyStandardFigureStyle(f, 1);
	% 样式函数会把所有线统一成 1 pt；舔水刻线是"梳齿"，必须细化，否则与行距相当会变方块
	for h = RasterH(:)'
		if isgraphics(h), h.LineWidth = 0.4; end
	end

	if Orientation == "vertical"
		svgName = 'English_FigLickDetail_CD2Raster_NaiveVsTransfer_vertical.svg';
		pngName = '_preview_CD2Raster_NaiveVsTransfer_vertical.png';
	else
		svgName = 'English_FigLickDetail_CD2Raster_NaiveVsTransfer.svg';
		pngName = '_preview_CD2Raster_NaiveVsTransfer.png';
	end
	svgPath = TransferLearning.StandardFigureSvgPath(svgName);
	print(f, svgPath, '-dsvg');
	fprintf('\nWrote: %s\n', svgPath);
	if ExportPreviewPng
		exportgraphics(f, fullfile(fileparts(mfilename('fullpath')), pngName), 'Resolution', 400);
	end
end
f = gcf;

assignin('base', 'LickDetail_CD2', T);
assignin('base', 'LickDetail_CD2_Ticks', struct('Time', {TickTime}, 'Row', {TickRow}));
assignin('base', 'LickDetail_CD2_p', pCue);

%% ================= 子函数 =================
function [tk, rw, nRow, nCueHit, fsMed] = iExtractSession(M, dt, halfWinSec, lickDelta)
% 取某 (鼠, 会话, 纯光水块) 下所有 LightWater 试次的舔水刻线
tk = zeros(0, 1);
rw = zeros(0, 1);
nRow = 0;
nCueHit = 0;
fsList = zeros(0, 1);
fsMed = NaN;
DS = M.DS;
bSel = find(M.DateTime == dt & M.Design == "LightWater");
if isempty(bSel), return; end

for iB = reshape(bSel, 1, [])
	bt = DS.Blocks.BlockTags{iB};
	if ~istable(bt) || ~ismember('CD2', bt.Properties.VariableNames), continue; end
	cd2 = double(bt.CD2(:).');
	if numel(cd2) < 10, continue; end

	fs = M.Rate(iB);
	if ~isfinite(fs) || fs <= 0, fs = 8; end
	fsList(end+1, 1) = fs;   %#ok<AGROW>
	base  = median(cd2);
	nHalf = round(halfWinSec * fs);

	tr = DS.Trials(DS.Trials.BlockUID == DS.Blocks.BlockUID(iB), :);
	if isempty(tr), continue; end
	[~, ord] = sort(double(tr.TrialIndex));
	tr = tr(ord, :);
	stim = string(tr.Stimulus);
	tag  = double(tr.SampleRange.Tag);

	for t = 1:height(tr)
		nRow = nRow + 1;
		if stim(t) ~= "LightWater", continue; end
		k = tag(t);
		if ~isfinite(k) || k <= 0, continue; end
		if k - nHalf < 1 || k + nHalf > numel(cd2), continue; end
		w  = cd2(k - nHalf : k + nHalf) - base;
		tt = (-nHalf:nHalf) / fs;
		sel = w > lickDelta;
		if ~any(sel), continue; end
		tk = [tk; tt(sel).'];                  %#ok<AGROW>
		rw = [rw; repmat(nRow, sum(sel), 1)];  %#ok<AGROW>
		% ⚠ 必须同为行向量再做逻辑与；一列一行会隐式展开成矩阵，if 判据会失效
		if any(sel & (tt >= 0) & (tt < 1)), nCueHit = nCueHit + 1; end
	end
end

if ~isempty(fsList), fsMed = median(fsList); end
end

function DS = iGetDS(name)
switch string(name)
	case "LightAudioBaseline"
		DS = TransferLearning.LightAudioBaseline();
	case "LAInterspersed"
		DS = TransferLearning.LAInterspersed();
	case "AudioLightBaseline"
		DS = TransferLearning.AudioLightBaseline();
	otherwise
		error('LickDetail:UnknownSource', 'Unknown source: %s', name);
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
try
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end
