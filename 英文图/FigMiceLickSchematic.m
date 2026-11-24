% FigMiceLickSchematic — 示意图：上=小鼠舔水，下=各自的 CD2 舔水信号
%
% 版式（画布 40 × 31.2 mm，viewBox 151.18 × 118）：
%   左列：小鼠「舔水」形态（吐舌 + 水嘴 + 水滴 + 声波 cue）  → 下方信号轨（有舔）
%   右列：小鼠「不舔」形态（无舌 + 水嘴）                  → 下方信号轨（无舔）
%   两条信号轨都在 cue 处标一条灰色竖虚线 + "cue" 文字，窗口 = cue −1 ~ +2 s
%
% 小鼠图形来自手绘模板 `英文图/micelicksample_template.svg`（Inkscape）。
%   脚本不改动模板，只在**各 group 的 transform 前**叠一层 translate/scale（0.85），
%   把原来并排的两只鼠分别缩到左右两列，因此原始 path 全部保留、仍可用 Inkscape 编辑。
%
% 信号 = 真实的 CD2 模拟舔水通道：
%   数据源 AudioLightBaseline 的 yqn1130（该 block ≈29.8 Hz，全库唯一能分辨单次舔的采样率）
%   左 = 该会话里第一个「cue 后有舔」的试次；右 = 第一个「cue 后无舔」的试次
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

MOUSE      = "yqn1130";
WIN        = [-1, 2];    % 相对 cue 的显示窗（秒）
N_PTS      = 90;         % 采样点数
LICK_DELTA = 20;         % CD2 高于基线多少算舔

% 画布
VB_W = 151.18;  VB_H = 118;      % 40 × 31.2 mm
% 两只鼠的缩放与平移（模板坐标 → 画布坐标）
SC   = 0.85;
T1   = sprintf('translate(2.05,0.65) scale(%.2f)', SC);    % 鼠1：原 x 2.3~40.1（含舌）
T2   = sprintf('translate(29.50,0.65) scale(%.2f)', SC);   % 鼠2：原 x 57.1~94.9
% 信号轨
S1X0 = 4;   S1X1 = 72;      % 左列信号
S2X0 = 78;  S2X1 = 146;     % 右列信号
SIG_TOP = 66;  SIG_BASE = 100;
AX_W = 0.67;  TR_W = 1.33;  FS = 7;  FS_BIG = 8;
CUE_X_FRAC = -WIN(1) / (WIN(2) - WIN(1));   % cue 在窗口中的相对位置（=1/3）

%% ---------------- 取两条真实 CD2 片段 ----------------
% 左列：yqn1130（≈30 Hz，能分辨单次舔）的「cue 后有舔」试次
% 右列：任意 Transfer 鼠的「cue 后完全无舔」试次（实测只有 vtf0354 / vtf0353 有，
%       无舔信号本来就是平的，采样率高低无所谓）
DS = TransferLearning.AudioLightBaseline();
[bMouse, bPhase, bDesign] = TransferLearning.AlignBlockMeta(DS.Blocks, DS.DateTimes);
bDT = datetime(DS.Blocks.DateTime);
if ~isempty(bDT.TimeZone), bDT.TimeZone = ''; end
bD = string(bDesign);
rBlk = TransferLearning.BlockSampleRate(DS, DS.Blocks, bMouse);

Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
Sess = Sess(Sess.Group == "Transfer", :);
allMice = unique(Sess.Mouse, 'stable');

[segLick,  fsL, baseL, mL] = iFindTrial(DS, bDT, bD, rBlk, Sess, MOUSE,     true,  WIN, N_PTS, LICK_DELTA);
[segQuiet, fsQ, baseQ, mQ] = iFindTrial(DS, bDT, bD, rBlk, Sess, allMice.',  false, WIN, N_PTS, LICK_DELTA);
if isempty(segLick)
	error('FigMiceLickSchematic:NoSignal', '找不到有舔的 CD2 片段');
end
if isempty(segQuiet)
	warning('FigMiceLickSchematic:NoQuiet', '找不到「cue 后完全无舔」的试次，右列改用平线');
	segQuiet = zeros(numel(segLick), 1); fsQ = fsL; baseQ = baseL; mQ = "—";
end
segLick  = segLick(:);
segQuiet = segQuiet(:);
amp = max(abs(segLick));      % 两条共用同一刻度，保证可比
if amp <= 0, amp = 1; end

fprintf('左列：%s，fs = %.1f Hz，峰值 %.0f（基线 %.0f）\n', mL, fsL, amp, baseL);
fprintf('右列：%s，fs = %.1f Hz，峰值 %.0f（基线 %.0f）\n', mQ, fsQ, max(abs(segQuiet)), baseQ);
fprintf('窗口 %.0f~%.0f s，cue 在 %.0f%% 处\n', WIN(1), WIN(2), 100*CUE_X_FRAC);

%% ---------------- 生成信号组 ----------------
sig = cell(1, 2);
for k = 1:2
	if k == 1
		seg = segLick;  x0 = S1X0; x1 = S1X1; withAxis = true;
	else
		seg = segQuiet; x0 = S2X0; x1 = S2X1; withAxis = false;
	end
	n = numel(seg);
	xs = x0 + (0:n-1)' / (n-1) * (x1 - x0);
	ys = SIG_BASE - seg / amp * (SIG_BASE - SIG_TOP);
	pts = sprintf('%.2f,%.2f ', [xs ys].');
	xCue = x0 + CUE_X_FRAC * (x1 - x0);

	s = '<g id="licksignal" inkscape:label="CD2 lick signal">\n';
	if withAxis
		s = [s sprintf(...
			'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#000000;stroke-width:%.2f;stroke-linecap:square"/>\n', ...
			x0, SIG_TOP, x0, SIG_BASE, AX_W)]; %#ok<AGROW>
	end
	s = [s sprintf(...
		'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#000000;stroke-width:%.2f;stroke-linecap:square"/>\n', ...
		x0, SIG_BASE, x1, SIG_BASE, AX_W)];
	s = [s sprintf(...
		'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#808080;stroke-width:%.2f;stroke-dasharray:1.6,1.6"/>\n', ...
		xCue, SIG_TOP, xCue, SIG_BASE, AX_W)];
	s = [s sprintf(...
		'  <polyline points="%s" style="fill:none;stroke:#333333;stroke-width:%.2f;stroke-linejoin:round;stroke-linecap:round"/>\n', ...
		pts, TR_W)];
	s = [s sprintf(...
		'  <text x="%.2f" y="%.2f" xml:space="preserve" style="font-size:%dpx;font-family:Arial;fill:#666666;text-anchor:middle">cue</text>\n', ...
		xCue, SIG_TOP - 3, FS)];
	if withAxis
		% 放在 cue 文字上方一行（同排放会撞车；左侧竖排位置不够）
		s = [s sprintf(...
			'  <text x="%.2f" y="%.2f" xml:space="preserve" style="font-size:%dpx;font-family:Arial;fill:#000000;text-anchor:start">CD2</text>\n', ...
			x0 + 1.5, SIG_TOP - 11, FS_BIG)];
	end
	s = [s '</g>\n'];
	sig{k} = s;
end

% 1 s 比例尺（挂在第二条信号右端下方）
scaleLen = (S2X1 - S2X0) / (WIN(2) - WIN(1));
sx = S2X1 - scaleLen;  sy = SIG_BASE + 5.5;
ScaleGroup = sprintf([ ...
	'<g id="lickscale" inkscape:label="scale bar">\n' ...
	'  <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" style="stroke:#000000;stroke-width:%.2f;stroke-linecap:square"/>\n' ...
	'  <text x="%.2f" y="%.2f" xml:space="preserve" style="font-size:%dpx;font-family:Arial;fill:#000000;text-anchor:middle">1 s</text>\n' ...
	'</g>\n'], ...
	sx, sy, S2X1, sy, AX_W, (sx + S2X1) / 2, sy + 7, FS);

%% ---------------- 合成 SVG ----------------
txt = iReadUtf8(TemplatePath);
% 幂等：删掉上一次插入的内容
txt = regexprep(txt, '<g\s+id="licksignal"[\s\S]*?</g>\s*', '');
txt = regexprep(txt, '<g\s+id="lickscale"[\s\S]*?</g>\s*', '');
txt = regexprep(txt, '<rect x="0" y="0" width="151\.18"[^>]*/>', '');
% 画布尺寸
txt = strrep(txt, 'viewBox="0 0 151.18111 151.1811"', sprintf('viewBox="0 0 %g %g"', VB_W, VB_H));
txt = strrep(txt, 'height="40mm"', 'height="31.2mm"');
% 把两只鼠分别缩到左右两列（在原 transform 之前叠一层）
txt = regexprep(txt, '(<g\s+id="g1")', ['$1' newline '   transform="' T1 '"'], 'once');
txt = regexprep(txt, '(<g\s+id="g27"[\s\S]{0,300}?transform=")', ['$1' T1 ' '], 'once');
txt = regexprep(txt, '(<g\s+id="g38-2"[\s\S]{0,300}?transform=")', ['$1' T1 ' '], 'once');
txt = regexprep(txt, '(<g\s+id="g97-0-1-9-4-3"[\s\S]{0,300}?transform=")', ['$1' T2 ' '], 'once');
txt = regexprep(txt, '(<g\s+id="g27-3"[\s\S]{0,300}?transform=")', ['$1' T2 ' '], 'once');
% 白底（放在 layer 之前，最底层）
bgRect = sprintf('<rect x="0" y="0" width="%.2f" height="%.2f" style="fill:#ffffff;stroke:none"/>', VB_W, VB_H);
txt = regexprep(txt, '(<g\s+inkscape:label="[^"]*"[\s\S]{0,120}?inkscape:groupmode="layer")', [bgRect '$1'], 'once');
% 追加信号组
kEnd = strfind(txt, '</svg>');
kEnd = kEnd(end);
newTxt = [txt(1:kEnd-1), sig{1}, sig{2}, ScaleGroup, txt(kEnd:end)];

iWriteUtf8(PreviewPath, newTxt);
iWriteUtf8(OutPath, newTxt);
fprintf('Wrote:\n  %s\n  %s\n', OutPath, PreviewPath);

%% ================= 子函数 =================
function [seg, fs, base, whichMouse] = iFindTrial(DS, bDT, bD, rBlk, Sess, mice, wantLick, win, nPts, del)
% 在给定鼠列表中按会话顺序找第一个满足「窗口内是否有舔」的试次
seg = []; fs = NaN; base = NaN; whichMouse = "—";
for iM = 1:numel(mice)
	m = mice(iM);
	S = Sess(Sess.Mouse == m, :);
	if isempty(S), continue; end
	S = sortrows(S, {'Session','DateTime'});
	for iS = 1:height(S)
		dt = iNormDT(S.DateTime(iS));
		bSel = find(bDT == dt & bD == "LightWater");
		for iB = reshape(bSel, 1, [])
			bt = DS.Blocks.BlockTags{iB};
			if ~istable(bt) || ~ismember('CD2', bt.Properties.VariableNames), continue; end
			c = double(bt.CD2(:).');
			if numel(c) < 200, continue; end
			f = rBlk(iB);
			if ~isfinite(f) || f <= 0, f = 30; end
			b0 = median(c);
			nPre = round(-win(1) * f);
			tr = DS.Trials(DS.Trials.BlockUID == DS.Blocks.BlockUID(iB), :);
			if isempty(tr), continue; end
			[~, ord] = sort(double(tr.TrialIndex));
			tr = tr(ord, :);
			stim = string(tr.Stimulus);
			tg = double(tr.SampleRange.Tag);
			for k = 1:height(tr)
				if stim(k) ~= "LightWater", continue; end
				i0 = tg(k) - nPre;
				i1 = i0 + nPts - 1;
				if i0 < 1 || i1 > numel(c), continue; end
				s = c(i0:i1) - b0;
				if wantLick == any(s > del)
					seg = s(:); fs = f; base = b0; whichMouse = m;
					return
				end
			end
		end
	end
end
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
