% FigS1B_LickDetail_EventLogLicks: 舔水细节图（单次舔）—— 用 EventLog 的「舔」事件
%
% 与 FigLickDetail_CD2Raster_NaiveVsTransfer.m 的区别
%   · CD2 模拟通道只有 ≈8 Hz（个别 30 Hz）⇒ 单次舔（~100 ms）不可分辨，一条刻线 = 一个超阈值帧
%   · EventLog 的「舔」事件是 ≈400 Hz 的"正在舔"指示 ⇒ 去抖 50 ms 后可还原**单次舔**，
%     这才是"每舔一下画一条小竖线"的正解
%
% ⚠ 覆盖范围（2026-11-03 实测）
%   LightAudioBaseline（LAB，6 只）+ LAInterspersed（LAI，12 只）：**舔事件数为 0**
%   AudioLightBaseline（ALB，11 只）：只有 yqn0133 / yqn0411 / yqn1018 有舔事件（11.8万 / 7.9万 / 8.1万条）
%   ⇒ 本图只能画 **Transfer 组 3 只鼠**，无法与 Naive 组对比。
%   （纯行为库 ALPureBehavior/LAPureBehavior 的 .mat 已不在网络盘，无法补数据）
%
% 图形：横轴 = 相对 cue 的时间（s，−1～3）；纵轴 = 试次序号；
%       每舔一下一条小竖线；同一试次行上叠加 3 只鼠（半透明）。
%
% 口径：每鼠首个 Design=LightWater 的 Transfer 会话；cue 时刻取
%       TransferLearning.BuildTrialTiming 的 CueTime（块内秒）。
%
% 执行：直接 Run（脚本）

clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------------- 参数 ----------------
DEBOUNCE_SEC = 0.05;     % 相邻「舔」事件 < 50 ms 视为同一次舔
WinSec       = [-1, 3];  % 显示窗（相对 cue）
MIN_TRIAL    = 5;

GroupCol = TransferLearning.TransferColor;

%% ---------------- 数据 ----------------
DS = TransferLearning.AudioLightBaseline();
[bMouse, bPhase, bDesign] = TransferLearning.AlignBlockMeta(DS.Blocks, DS.DateTimes);
bDesign = string(bDesign);
bPhase  = string(bPhase);
bDT     = iNormDT(DS.Blocks.DateTime);
TT      = TransferLearning.BuildTrialTiming(DS);

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
S1 = Sess(Sess.Session == 1 & Sess.Group == "Transfer", :);
S1 = S1(S1.Source == "AudioLightBaseline", :);
fprintf('Transfer 组首个纯光水会话：%d 只\n', height(S1));

%% ---------------- 逐鼠逐试次提取单次舔 ----------------
mice = unique(S1.Mouse, 'stable');
nMax = numel(mice);
MouseName = strings(nMax, 1);
NTrial    = zeros(nMax, 1);
NAll      = zeros(nMax, 1);
LatMed    = nan(nMax, 1);
TickTime  = cell(nMax, 1);
TickRow   = cell(nMax, 1);
row = 0;

for iM = 1:nMax
	m = mice(iM);
	dt = iNormDT(S1.DateTime(S1.Mouse == m));
	dt = dt(1);
	bSel = find(bDT == dt & bDesign == "LightWater");
	if isempty(bSel)
		fprintf('  %-9s：该会话无 Design=LightWater 块，跳过\n', string(m));
		continue;
	end

	% 各 block 的 cue 时刻（块内秒）与次序
	cueList = zeros(0, 1);
	uidList = zeros(0, 1);
	triIdx  = zeros(0, 1);
	for iB = reshape(bSel, 1, [])
		uid = DS.Blocks.BlockUID(iB);
		Tb = TT(TT.BlockUID == uid, :);
		ok = isfinite(Tb.CueTime);
		[~, locT] = ismember(Tb.TrialUID, DS.Trials.TrialUID);
		idxAll = double(DS.Trials.TrialIndex);
		cueList = [cueList; Tb.CueTime(ok)];      %#ok<AGROW>
		uidList = [uidList; repmat(uid, sum(ok), 1)]; %#ok<AGROW>
		triIdx  = [triIdx;  idxAll(locT(ok))];    %#ok<AGROW>
	end
	if isempty(cueList), continue; end

	tk = zeros(0, 1);
	rw = zeros(0, 1);
	nRow = 0;

	for iB = reshape(bSel, 1, [])
		uid = DS.Blocks.BlockUID(iB);
		E = DS.Blocks.EventLog{iB};
		if ~istimetable(E) || isempty(E), continue; end
		ev = string(E.Event);
		et = seconds(E.Time);
		lick = et(ev == "舔");
		lick = sort(lick(:));
		if isempty(lick), continue; end
		% 去抖：间隔 < 50 ms 的连续事件并成一次舔
		lick = lick([true; diff(lick) > DEBOUNCE_SEC]);

		isThis = uidList == uid;
		cues = cueList(isThis);
		ti   = triIdx(isThis);
		[~, ord] = sort(ti);
		cues = cues(ord);

		for j = 1:numel(cues)
			nRow = nRow + 1;
			rel = lick - cues(j);
			v = rel(rel >= WinSec(1) & rel <= WinSec(2));
			if isempty(v), continue; end
			tk = [tk; v];                       %#ok<AGROW>
			rw = [rw; repmat(nRow, numel(v), 1)]; %#ok<AGROW>
		end
	end

	if nRow < MIN_TRIAL || isempty(tk)
		fprintf('  %-9s：无可用舔事件（试次 %d，舔 %d），跳过\n', string(m), nRow, numel(tk));
		continue;
	end

	row = row + 1;
	MouseName(row) = string(m);
	NTrial(row)    = nRow;
	NAll(row)      = numel(tk);
	% 每回合首舔潜伏
	firstLat = nan(nRow, 1);
	for j = 1:nRow
		v = tk(rw == j);
		if ~isempty(v), firstLat(j) = v(1); end
	end
	LatMed(row)   = median(firstLat, 'omitnan');
	TickTime{row} = tk;
	TickRow{row}  = rw;

	% 保存首舔潜伏用于打印
	TmpLat.(matlab.lang.makeValidName(string(m))) = firstLat;
end

MouseName = MouseName(1:row);
NTrial    = NTrial(1:row);
NAll      = NAll(1:row);
LatMed    = LatMed(1:row);
TickTime  = TickTime(1:row);
TickRow   = TickRow(1:row);

T = table(MouseName, NTrial, NAll, LatMed, 'VariableNames', {'Mouse','NTrial','NLick','FirstLickMed'});
disp(T)
fprintf('合计 %d 只鼠 / %d 试次 / %d 次舔（去抖 %.0f ms）\n\n', row, sum(NTrial), sum(NAll), DEBOUNCE_SEC * 1000);

%% ---------------- 出图 ----------------
RowMax = max(NTrial);
f = figure('Color', 'w', 'Name', 'Lick detail: EventLog single licks (Transfer, 3 mice)');
f.Units = 'centimeters';
% 作图规范：英文论文/英文图规范.md（高 4 cm；宽 1.5 cm 整倍；字号 6 pt）
f.Position(3:4) = [4.5, 4.0];

ax = axes(f);
hold(ax, 'on');
c = GroupCol;
TICK_HALF_H = 0.35;
RasterH = gobjects(0);   % 样式函数会把线统一成 1 pt，刻线需事后细化

for i = 1:row
	tkI = TickTime{i};
	rwI = TickRow{i};
	x = reshape([tkI.'; tkI.'; nan(1, numel(tkI))], [], 1);
	y = reshape([rwI.' - TICK_HALF_H; rwI.' + TICK_HALF_H; nan(1, numel(rwI))], [], 1);
	RasterH(end+1) = plot(ax, x, y, '-', 'Color', [c, 0.45], 'LineWidth', 0.4); %#ok<SAGROW>
end

xlim(ax, WinSec);
ylim(ax, [0.4, RowMax + 0.6]);
xlabel(ax, 'Time from cue (s)');
ylabel(ax, 'Trial');
title(ax, sprintf('Transfer (ALB), n = %d', row), 'FontWeight', 'normal');
box(ax, 'off');
TransferLearning.DrawCueWaterLines(ax);

TransferLearning.Style.ApplyStandardFigureStyle(f, 1);
for h = RasterH(:)'
	if isgraphics(h), h.LineWidth = 0.4; end
end

svgPath = TransferLearning.StandardFigureSvgPath('English_FigS1B_LickDetail_EventLogSingleLicks.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'LickDetail_EventLog', T);
assignin('base', 'LickDetail_EventLog_Ticks', struct('Time', {TickTime}, 'Row', {TickRow}, 'Mouse', {MouseName}));

%% ================= 子函数 =================
function dt = iNormDT(dt)
dt = datetime(dt);
try
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end
