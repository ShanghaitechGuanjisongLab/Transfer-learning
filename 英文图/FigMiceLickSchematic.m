% FigMiceLickSchematic — 示意图：小鼠舔水 + 其 CD2 舔水信号
%
% 版式（画布 40 × 31.2 mm，viewBox 151.18 × 118）：
%   上半：小鼠「舔水」形态（吐舌 + 水嘴 + 水滴 + 声波 cue），水平居中
%   下半：一条 CD2 信号轨，窗口 = cue −1 ~ +2 s，cue 处灰色竖虚线 + "cue" 文字
%
% 小鼠图形来自手绘模板 `英文图/micelicksample_template.svg`（Inkscape）。
%   脚本保留左侧那只鼠（g1 / g27 / g38-2），删掉右侧并排的第二只（g97-0-1-9-4-3 / g27-3）；
%   原始 path 一个不改，仍可用 Inkscape 编辑。
%
% 信号 = 真实的 CD2 模拟舔水通道：
%   数据源 AudioLightBaseline；优先用 ≈30 Hz 的鼠（yqn1130 / yqn0020 / yqn0240，
%   全库只有这几块能分辨单次舔），取「cue 后最早开始舔」的试次（预期性舔）。
%
% 输出（覆盖式，可重复运行）：
%   \\Data-Server-2\个人数据\杨青宁\202611\micelicksample.svg
%   工作区预览 英文图\_preview_micelicksample.svg
%
% 执行：直接 Run（脚本）

clear variables; close all;
cd('d:\git\Transfer-Learning');
if ~exist('UniExp.DataSet', 'class')
	matlab.project.loadProject('d:\git\Transfer-Learning\Transferlearning.prj');
end
warning('off', 'UniExp:Exception:Block_must_warn');

%% ---------------- 参数 ----------------
TemplatePath = TransferLearning.ProjectPath('英文图', 'micelicksample_template.svg');
OutPath      = '\\Data-Server-2\个人数据\杨青宁\202611\micelicksample.svg';
PreviewPath  = TransferLearning.ProjectPath('英文图', '_preview_micelicksample.svg');

FAST_MICE  = ["yqn2200", "yqn2202", "yqn2201", "yqn2203"];   % delay 组（ALDelayed），前两只 ≈15.2 Hz
DESIGN     = "LightLearnWater";   % delay 版光水（舔才给水）
WIN        = [-1, 2];    % 搜索窗（相对 cue，秒）；实际绘制时会裁掉尾部平台
LICK_DELTA = 20;         % CD2 高于基线多少算舔
LAT_MIN    = 0.25;       % 首舔不得早于此（排除 cue 电学串扰伪迹）
LAT_MAX    = 0.55;       % 首舔必须落在此前（典型预期性舔，早于 1 s 给水）
PRE_QUIET  = 0.30;       % cue 前这么多秒必须安静
TAIL_SEC   = 0.15;       % 最后一个舔之后再留一点尾巴
MIN_POST   = 0.85;       % cue 后至少画这么久（防止窗口过短）

% 画布
VB_W = 151.18;  VB_H = 118;      % 40 × 31.2 mm
% 小鼠：保留左侧那只（模板 bbox x 2.3~49.3、y 6.3~52.3，含舌/水嘴/声波），水平居中
MOUSE_X0 = 2.3;  MOUSE_X1 = 49.3;
MOUSE_Y0 = 6.3;
SC = 1.1;
TX = VB_W/2 - SC*(MOUSE_X0 + MOUSE_X1)/2;
TY = 4 - SC*MOUSE_Y0;
T1 = sprintf('translate(%.2f,%.2f) scale(%.2f)', TX, TY, SC);
% 信号轨
SX0 = 6;  SX1 = 146;
SIG_TOP = 66;  SIG_BASE = 100;
AX_W = 0.67;  TR_W = 1.33;  FS = 7;

%% ---------------- 取 CD2 片段（cue 后预期性舔）----------------
DS = TransferLearning.ALDelayed();
B = DS.Blocks;
bDT = datetime(B.DateTime); if ~isempty(bDT.TimeZone), bDT.TimeZone = ''; end
DT = DS.DateTimes;
dtDT = datetime(DT.DateTime); if ~isempty(dtDT.TimeZone), dtDT.TimeZone = ''; end
[tfM, locM] = ismember(bDT, dtDT);
bMouse = strings(height(B), 1);
bMouse(tfM) = string(DT.Mouse(locM(tfM)));
bD = string(B.Design);
rBlk = TransferLearning.BlockSampleRate(DS, B, bMouse);

[seg, fs, base, mL, lat, nPre] = iFindEarliestLick(DS, bMouse, bD, bDT, rBlk, FAST_MICE, DESIGN, ...
	WIN, LICK_DELTA, LAT_MIN, LAT_MAX, PRE_QUIET, TAIL_SEC, MIN_POST);
if isempty(seg)
	error('FigMiceLickSchematic:NoSignal', 'delay 组里找不到符合条件的 CD2 片段');
end
seg = seg(:);
amp = max(abs(seg));
if amp <= 0, amp = 1; end
CUE_X_FRAC = nPre / (numel(seg) - 1);
postSec = (numel(seg) - 1 - nPre) / fs;

fprintf('信号：%s，fs = %.1f Hz，首舔在 cue 后 %.2f s，峰值 %.0f（基线 %.0f）\n', mL, fs, lat, amp, base);
fprintf('显示窗 cue −1 ~ +%.2f s（已裁掉尾部平台），cue 在 %.0f%% 处\n', postSec, 100*CUE_X_FRAC);

%% ---------------- 生成信号组 ----------------
n = numel(seg);
xs = SX0 + (0:n-1)' / (n-1) * (SX1 - SX0);
ys = SIG_BASE - seg / amp * (SIG_BASE - SIG_TOP);
pts = sprintf('%.2f,%.2f ', [xs ys].');
xCue = SX0 + CUE_X_FRAC * (SX1 - SX0);

% 1 s 比例尺（横跨 SX1-SX0 对应实际时长）
scaleLen = (SX1 - SX0) / (postSec - WIN(1));
sx = SX1 - scaleLen;
sy = SIG_BASE + 5.5;

SignalGroup = sprintf([ ...
	'<g id="licksignal" inkscape:label="CD2 lick signal">\n' ...
	'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#000000;stroke-width:%.2f;stroke-linecap:square"/>\n' ...
	'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#000000;stroke-width:%.2f;stroke-linecap:square"/>\n' ...
	'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#808080;stroke-width:%.2f;stroke-dasharray:1.6,1.6"/>\n' ...
	'  <polyline points="%s" style="fill:none;stroke:#333333;stroke-width:%.2f;stroke-linejoin:round;stroke-linecap:round"/>\n' ...
	'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#000000;stroke-width:%.2f;stroke-linecap:square"/>\n' ...
	'  <text x="%.2f" y="%.2f" xml:space="preserve" style="font-size:%dpx;font-family:Arial;fill:#666666;text-anchor:middle">cue</text>\n' ...
	'  <text x="%.2f" y="%.2f" xml:space="preserve" style="font-size:%dpx;font-family:Arial;fill:#000000;text-anchor:start">CD2</text>\n' ...
	'  <text x="%.2f" y="%.2f" xml:space="preserve" style="font-size:%dpx;font-family:Arial;fill:#000000;text-anchor:middle">1 s</text>\n' ...
	'</g>\n'], ...
	SX0, SIG_TOP, SX0, SIG_BASE, AX_W, ...
	SX0, SIG_BASE, SX1, SIG_BASE, AX_W, ...
	xCue, SIG_TOP, xCue, SIG_BASE, AX_W, ...
	pts, TR_W, ...
	sx, sy, SX1, sy, AX_W, ...
	xCue, SIG_TOP - 3, FS, ...
	SX0 + 1.5, SIG_BASE + 6.5, FS, ...
	(sx + SX1) / 2, sy + 7, FS);

%% ---------------- 合成 SVG ----------------
txt = iReadUtf8(TemplatePath);
% 幂等：删掉上一次插入的内容与右列小鼠
txt = regexprep(txt, '<g\s+id="licksignal"[\s\S]*?</g>\s*', '');
txt = regexprep(txt, '<rect x="0" y="0" width="151\.18"[^>]*/>', '');
txt = iRemoveGroup(txt, 'g97-0-1-9-4-3');   % 右侧并排的第二只鼠
txt = iRemoveGroup(txt, 'g27-3');           % 它的水嘴
% 画布尺寸
txt = strrep(txt, 'viewBox="0 0 151.18111 151.1811"', sprintf('viewBox="0 0 %g %g"', VB_W, VB_H));
txt = strrep(txt, 'height="40mm"', 'height="31.2mm"');
% 唯一那只鼠：居中（在原 transform 之前叠一层）
txt = regexprep(txt, '(<g\s+id="g1")', ['$1' newline '   transform="' T1 '"'], 'once');
txt = regexprep(txt, '(<g\s+id="g27"[\s\S]{0,300}?transform=")', ['$1' T1 ' '], 'once');
txt = regexprep(txt, '(<g\s+id="g38-2"[\s\S]{0,300}?transform=")', ['$1' T1 ' '], 'once');
% 水滴（path1-3-9）也是同一只鼠的一部分，必须一起平移/缩放
txt = regexprep(txt, '(<path\s+id="path1-3-9")', ['$1' newline '   transform="' T1 '"'], 'once');
% 白底
bgRect = sprintf('<rect x="0" y="0" width="%.2f" height="%.2f" style="fill:#ffffff;stroke:none"/>', VB_W, VB_H);
txt = regexprep(txt, '(<g\s+inkscape:label="[^"]*"[\s\S]{0,120}?inkscape:groupmode="layer")', [bgRect '$1'], 'once');
% 追加信号组
kEnd = strfind(txt, '</svg>');
newTxt = [txt(1:kEnd(end)-1), SignalGroup, txt(kEnd(end):end)];

iWriteUtf8(PreviewPath, newTxt);
iWriteUtf8(OutPath, newTxt);
fprintf('Wrote:\n  %s\n  %s\n', OutPath, PreviewPath);

%% ================= 子函数 =================
function [seg, fs, base, whichMouse, lat, nPre] = iFindEarliestLick(DS, bMouse, bD, bDT, rBlk, mice, designName, win, del, latMin, latMax, preQuiet, tailSec, minPost)
% 在给定鼠列表中找「cue 后预期性舔」的试次（首舔落在 [latMin, latMax]，cue 前安静）
%   返回的 seg 已裁掉「最后一个舔之后的平台期」（只留 tailSec 尾巴，且至少到 cue+minPost）
seg = []; fs = NaN; base = NaN; whichMouse = "—"; lat = NaN; nPre = NaN;
bestLat = inf;
for iM = 1:numel(mice)
	m = mice(iM);
	rows = find(bMouse == m & bD == designName);
	if isempty(rows), continue; end
	[~, ord] = sort(bDT(rows));
	rows = rows(ord);
	for iB = reshape(rows, 1, [])
		bt = DS.Blocks.BlockTags{iB};
		if ~istable(bt) || ~ismember('CD2', bt.Properties.VariableNames), continue; end
		c = double(bt.CD2(:).');
		if numel(c) < 200, continue; end
		f = rBlk(iB);
		if ~isfinite(f) || f <= 0, f = 30; end
		b0 = median(c);
		nPre = round(-win(1) * f);
		nWin = round((win(2) - win(1)) * f);
		tr = DS.Trials(DS.Trials.BlockUID == DS.Blocks.BlockUID(iB), :);
		if isempty(tr), continue; end
		[~, ordt] = sort(double(tr.TrialIndex));
		tr = tr(ordt, :);
		stim = string(tr.Stimulus);
		tg = double(tr.SampleRange.Tag);
		for k = 1:height(tr)
			if stim(k) ~= designName, continue; end
			i0 = tg(k) - nPre;
			i1 = i0 + nWin - 1;
			if i0 < 1 || i1 > numel(c), continue; end
			s = c(i0:i1) - b0;
			preN = min(round(preQuiet * f), nPre);
			if any(s(1:preN) > del), continue; end
			idx = find(s > del, 1, 'first');
			if isempty(idx), continue; end
			tLat = (idx - 1) / f + win(1);    % 相对 cue 的秒数
			if tLat < latMin || tLat > latMax || tLat >= bestLat, continue; end
			% 裁掉尾部平台：到最后一个舔 + tailSec，且至少到 cue+minPost
			idxLast = find(s > del, 1, 'last');
			tailN   = max(2, round(tailSec * f));
			minEnd  = nPre + round(minPost * f) + 1;
			iKeep   = min(numel(s), max(idxLast + tailN, minEnd));
			bestLat = tLat;
			seg = s(1:iKeep).'; fs = f; base = b0; whichMouse = m; lat = tLat;
		end
	end
	if ~isempty(seg), break; end   % 按鼠优先级
end
if isempty(seg), lat = NaN; nPre = NaN; end
end

function txt = iRemoveGroup(txt, id)
% 删除 <g id="..."> ... </g>（按 <g / </g> 计数配对，支持嵌套）
k0 = regexp(txt, ['<g\s+id="' regexptranslate('escape', id) '"'], 'once');
if isempty(k0), return; end
[tokS, tokE] = regexp(txt, '<g[\s>]|</g>');
i0 = find(tokS == k0, 1);
if isempty(i0), return; end
depth = 0; iEnd = [];
for i = i0:numel(tokS)
	if strncmp(txt(tokS(i):tokE(i)), '<g', 2)
		depth = depth + 1;
	else
		depth = depth - 1;
	end
	if depth == 0
		iEnd = tokE(i);
		break
	end
end
if isempty(iEnd), return; end
txt = [txt(1:k0-1), txt(iEnd+1:end)];
end

function s = iReadUtf8(p)
fid = fopen(p, 'r', 'n', 'UTF-8');
if fid < 0, error('FigMiceLickSchematic:Read', '无法读取 %s', p); end
s = fread(fid, Inf, '*char').';
fclose(fid);
end

function iWriteUtf8(p, s)
fid = fopen(p, 'w', 'n', 'UTF-8');
if fid < 0, error('FigMiceLickSchematic:Write', '无法写入 %s', p); end
fwrite(fid, s, 'char');
fclose(fid);
end

function dt = iNormDT(dt)
dt = datetime(dt);
try
	if ~isempty(dt.TimeZone), dt.TimeZone = ''; end
catch
end
end
