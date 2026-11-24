% 英文图5K：机制模型（基于手绘 5K.svg 重排）。两层分工：
% MOp2/3 engram 被复用 → 表现跨 trial 一致（散度低）→ 首块命中率高；
% MOp5 受 TH 调制 → 细胞间稳定分工（异质性高）→ 学习更快。
% 两个指标共用同一种 "cell × trial" 热图：上半看列（trial）是否一致，下半看行（cell）是否分化。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end

Components = iHex(TransferLearning.ColorLearned);
NaiveHex = iHex(TransferLearning.ColorNaive);
ThHex = iHex(TransferLearning.ColorTH);
ThDarkHex = iHex(0.72 * TransferLearning.ColorTH);
InkHex = '#292832';
GreyHex = '#6E6A86';
RuleHex = '#E4DFEC';
AxisHex = '#B9B3C6';
Cells = 6.5;
Gap = 0.6;
HeatW = 3 * Cells + 2 * Gap;
HeatH = 4 * Cells + 3 * Gap;
Heat1X = 32;
Heat2X = Heat1X + HeatW + 5;
Heat1Y = 12;
Heat2Y = 62;

Lines = strings(0, 1);
Lines(end+1) = '<?xml version="1.0" encoding="UTF-8"?>';
Lines(end+1) = '<svg xmlns="http://www.w3.org/2000/svg" width="140mm" height="98mm" viewBox="0 0 140 98">';
Lines(end+1) = '<rect width="140" height="98" fill="white"/>';
Lines(end+1) = sprintf(['<style>text{font-family:Helvetica,Arial,sans-serif;fill:%s}' ...
	'.layer{font-size:3px;font-weight:600}.sub{font-size:2.2px;fill:%s}' ...
	'.head{font-size:2.3px}.note{font-size:1.9px;fill:%s}.mini{font-size:1.75px;fill:%s}</style>'], ...
	InkHex, GreyHex, GreyHex, GreyHex);
Lines(end+1) = '<defs>';
Lines(end+1) = sprintf('<marker id="arrowGrey" markerUnits="userSpaceOnUse" markerWidth="2.6" markerHeight="2.6" refX="2.1" refY="1.3" orient="auto"><path d="M0 0 L2.6 1.3 L0 2.6 Z" fill="%s"/></marker>', GreyHex);
Lines(end+1) = sprintf('<marker id="arrowTh" markerUnits="userSpaceOnUse" markerWidth="2.6" markerHeight="2.6" refX="2.1" refY="1.3" orient="auto"><path d="M0 0 L2.6 1.3 L0 2.6 Z" fill="%s"/></marker>', ThHex);
Lines(end+1) = '</defs>';

Lines(end+1) = sprintf('<line x1="3" y1="48" x2="137" y2="48" stroke="%s" stroke-width="0.5"/>', RuleHex);

% ---------- 上半：MOp2/3 engram → trial 间一致 ----------
Lines(end+1) = '<text x="3" y="6.6" class="layer">MOp2/3</text>';
Lines(end+1) = '<text x="3" y="9.4" class="sub">engram</text>';

EngramMarks = [6.5 26 1; 11.5 26 1; 16.5 26 1; 21.5 26 0];
for MarkIndex = 1:4
	if EngramMarks(MarkIndex, 3) > 0
		Lines(end+1) = sprintf('<circle cx="%g" cy="%g" r="2.4" fill="%s"/>', ...
			EngramMarks(MarkIndex, 1), EngramMarks(MarkIndex, 2), Components);
	else
		Lines(end+1) = sprintf('<circle cx="%g" cy="%g" r="2.4" fill="none" stroke="%s" stroke-width="0.45"/>', ...
			EngramMarks(MarkIndex, 1), EngramMarks(MarkIndex, 2), GreyHex);
	end
end
Lines(end+1) = sprintf('<path d="M25 26 L30.5 26" fill="none" stroke="%s" stroke-width="0.55" marker-end="url(#arrowGrey)"/>', GreyHex);

Lines(end+1) = '<text x="42.35" y="6.6" class="head" text-anchor="middle">12h transfer</text>';
Lines(end+1) = '<text x="42.35" y="9.4" class="note" text-anchor="middle">trials consistent</text>';
Lines(end+1) = '<text x="68.05" y="6.6" class="head" text-anchor="middle">naive / 7d</text>';
Lines(end+1) = '<text x="68.05" y="9.4" class="note" text-anchor="middle">trials vary</text>';

ConsistentPattern = [0.88 0.88 0.88; 0.80 0.80 0.80; 0.92 0.92 0.92; 0.76 0.76 0.76];
VaryingPattern = [0.90 0.25 0.60; 0.30 0.85 0.40; 0.65 0.35 0.95; 0.45 0.90 0.20];
Lines = iHeatmap(Lines, Heat1X, Heat1Y, Cells, Gap, TransferLearning.ColorLearned, ConsistentPattern);
Lines = iHeatmap(Lines, Heat2X, Heat1Y, Cells, Gap, TransferLearning.ColorNaive, VaryingPattern);

Lines(end+1) = sprintf('<path d="M80.5 26 L87.5 26" fill="none" stroke="%s" stroke-width="0.55" marker-end="url(#arrowGrey)"/>', GreyHex);

Lines(end+1) = sprintf('<path d="M91 9 L91 40 L134 40" fill="none" stroke="%s" stroke-width="0.5"/>', AxisHex);
Lines(end+1) = sprintf('<rect x="101" y="11" width="9" height="29" fill="%s"/>', Components);
Lines(end+1) = sprintf('<rect x="116" y="27" width="9" height="13" fill="%s"/>', NaiveHex);
Lines(end+1) = '<text x="113" y="4.2" class="head" text-anchor="middle">early performance</text>';
Lines(end+1) = '<text x="113" y="6.9" class="note" text-anchor="middle">first-block hit rate</text>';

% ---------- 下半：MOp5 TH 调制 → 细胞间分工 ----------
Lines(end+1) = '<text x="3" y="56.6" class="layer">MOp5</text>';
Lines(end+1) = '<text x="3" y="59.4" class="sub">TH modulation</text>';
Lines(end+1) = sprintf('<circle cx="6.5" cy="76" r="1.3" fill="%s"/>', ThHex);
Lines(end+1) = sprintf(['<path d="M9 76 L30.5 76" fill="none" stroke="%s" stroke-width="0.6" ' ...
	'stroke-dasharray="2 1.2" marker-end="url(#arrowTh)"/>'], ThHex);

Lines(end+1) = '<text x="42.35" y="56.6" class="head" text-anchor="middle">TH intact</text>';
Lines(end+1) = '<text x="42.35" y="59.4" class="note" text-anchor="middle">cells specialized</text>';
Lines(end+1) = '<text x="68.05" y="56.6" class="head" text-anchor="middle">TH inhibited</text>';
Lines(end+1) = '<text x="68.05" y="59.4" class="note" text-anchor="middle">cells uniform</text>';

SpecializedPattern = [1.00 1.00 1.00; 0.16 0.16 0.16; 0.80 0.80 0.80; 0.34 0.34 0.34];
UniformPattern = 0.42 * ones(4, 3);
Lines = iHeatmap(Lines, Heat1X, Heat2Y, Cells, Gap, TransferLearning.ColorTH, SpecializedPattern);
Lines = iHeatmap(Lines, Heat2X, Heat2Y, Cells, Gap, TransferLearning.ColorTH, UniformPattern);

Lines(end+1) = sprintf('<path d="M80.5 76 L87.5 76" fill="none" stroke="%s" stroke-width="0.55" marker-end="url(#arrowGrey)"/>', GreyHex);

Lines(end+1) = sprintf('<path d="M91 59.5 L91 89.8 L134 89.8" fill="none" stroke="%s" stroke-width="0.5"/>', AxisHex);
FastPath = 'M91 89.8 C96 88.8 101 86 106 79 C111 72 113 65 119 63 C124 62 128 62 132 62';
SlowPath = 'M91 89.8 C99 89.8 105 88.8 111 86 C117 83 124 80 132 79';
Lines(end+1) = sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="0.55" stroke-dasharray="2 1.2"/>', SlowPath, GreyHex);
Lines(end+1) = sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="0.85" stroke-linecap="round"/>', FastPath, ThDarkHex);
Lines(end+1) = '<text x="113" y="56" class="head" text-anchor="middle">learning speed</text>';
Lines(end+1) = '<text x="113" y="93.4" class="note" text-anchor="middle">blocks</text>';
Lines(end+1) = sprintf('<line x1="94" y1="63.4" x2="99.5" y2="63.4" stroke="%s" stroke-width="0.85"/>', ThDarkHex);
Lines(end+1) = '<text x="101" y="64.1" class="mini">intact</text>';
Lines(end+1) = sprintf('<line x1="94" y1="67.4" x2="99.5" y2="67.4" stroke="%s" stroke-width="0.55" stroke-dasharray="2 1.2"/>', GreyHex);
Lines(end+1) = '<text x="101" y="68.1" class="mini">blocked</text>';

Lines(end+1) = '</svg>';

SvgPath = TransferLearning.StandardFigureSvgPath('English_Fig5K_MechanismModel.svg');
FileID = fopen(SvgPath, 'w', 'n', 'UTF-8');
assert(FileID >= 0, '无法写入机制模型SVG：%s', SvgPath);
fprintf(FileID, '%s\n', Lines);
fclose(FileID);
fprintf('已导出：%s\n', SvgPath);
assignin('base', 'Fig5K_MechanismSvgPath', SvgPath);

function Lines = iHeatmap(Lines, X0, Y0, CellSize, Gap, BaseColor, Values)
[NumRow, NumCol] = size(Values);
for RowIndex = 1:NumRow
	for ColIndex = 1:NumCol
		Value = min(max(Values(RowIndex, ColIndex), 0), 1);
		Hex = iRampHex(BaseColor, Value);
		X = X0 + (ColIndex - 1) * (CellSize + Gap);
		Y = Y0 + (RowIndex - 1) * (CellSize + Gap);
		Lines(end+1) = sprintf('<rect x="%.2f" y="%.2f" width="%g" height="%g" rx="0.5" fill="%s"/>', ...
			X, Y, CellSize, CellSize, Hex);
	end
end
end

function Hex = iRampHex(BaseColor, Value)
LightColor = [251 249 254];
Rgb = LightColor / 255 + Value * (BaseColor / 255 - LightColor / 255);
Hex = sprintf('#%02X%02X%02X', round(Rgb * 255));
end

function Hex = iHex(Color)
Hex = sprintf('#%02X%02X%02X', round(Color));
end
