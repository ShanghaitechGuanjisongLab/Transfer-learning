% 机制模型总图（不编号）：两层分工，图形为主。MOp2/3 engram 活动降低跨回合散度（回合间噪声下降、时间稳定），
% 支撑早期表现；MOp5 接受 TH 调制形成稳定的细胞间分工（异质性升高），提高学习速度。
% 两个度量都画成“细胞×回合”矩阵的前后对照：上排看列（回合）是否一致，下排看行（细胞）是否分化。
% 右侧结果按真实指标口径画：早期表现=首会话首个 block 命中率（水平柱，每鼠一点）；
% 学习速度=逐鼠 sigmoid 拟合的命中率- block 曲线（斜率）。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end

TealHex = iHex(TransferLearning.ColorLearned);
MauveHex = iHex(TransferLearning.ColorTH);
DarkHex = '#6E6A86';
InkHex = '#292832';
PaleHex = '#EDE9F2';
EdgeHex = '#CFC8DB';
AxisHex = '#B9B3C6';

Lines = strings(0, 1);
Lines(end+1) = '<?xml version="1.0" encoding="UTF-8"?>';
Lines(end+1) = '<svg xmlns="http://www.w3.org/2000/svg" width="159mm" height="96mm" viewBox="0 0 1060 640">';
Lines(end+1) = '<rect width="1060" height="640" fill="white"/>';
Lines(end+1) = sprintf('<style>text{font-family:Helvetica,Arial,sans-serif;fill:%s}.layer{font-size:28px;font-weight:600}.sub{font-size:17px;fill:%s}.label{font-size:19px}.tiny{font-size:15px;fill:#8A849B}.th{font-size:21px;font-weight:700;fill:%s}</style>', InkHex, DarkHex, iHex(0.7 * TransferLearning.ColorTH));
Lines(end+1) = '<defs>';
Lines(end+1) = sprintf('<marker id="arrowTeal" markerWidth="9" markerHeight="9" refX="7" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 Z" fill="%s"/></marker>', TealHex);
Lines(end+1) = sprintf('<marker id="arrowDark" markerWidth="9" markerHeight="9" refX="7" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 Z" fill="%s"/></marker>', DarkHex);
Lines(end+1) = sprintf('<marker id="arrowMauve" markerUnits="userSpaceOnUse" markerWidth="14" markerHeight="14" refX="10" refY="7" orient="auto"><path d="M0 0 L14 7 L0 14 Z" fill="%s"/></marker>', MauveHex);
Lines(end+1) = '</defs>';

Lines(end+1) = '<line x1="30" y1="330" x2="1030" y2="330" stroke="#E6E0F0" stroke-width="2"/>';

% ---------- MOp2/3：engram 活动 → 散度下降 ----------
Lines(end+1) = sprintf('<text x="42" y="86" class="layer">MOp2/3</text>');
Lines(end+1) = '<text x="42" y="112" class="sub">engram</text>';

EngramColors = [1 0; 0 1; 1 1; 0 0];
for RowIndex = 1:3
	for ColIndex = 1:3
		Cx = 145 + 30 * (ColIndex - 1);
		Cy = 170 + 30 * (RowIndex - 1);
		if any(EngramColors(:, 1) == RowIndex - 1 & EngramColors(:, 2) == ColIndex - 1)
			Lines(end+1) = sprintf('<circle cx="%g" cy="%g" r="11" fill="%s" stroke="#ffffff" stroke-width="2"/>', Cx, Cy, TealHex);
		else
			Lines(end+1) = sprintf('<circle cx="%g" cy="%g" r="11" fill="%s" stroke="%s" stroke-width="2"/>', Cx, Cy, PaleHex, EdgeHex);
		end
	end
end

Lines(end+1) = sprintf('<path d="M240 200 L310 200" fill="none" stroke="%s" stroke-width="2.6" marker-end="url(#arrowTeal)"/>', TealHex);
Lines(end+1) = '<text x="270" y="184" class="sub" text-anchor="middle">activity</text>';

% 细胞×回合矩阵：左=回合间噪声大（列间不一致）；右=列间一致 → 散度低（时间稳定、噪音小）
Lane1Base = TransferLearning.ColorLearned / 255;
Lane1Profile = [0.50 0.62 0.72 0.76 0.68 0.56 0.46];
Pitch = 15;
CellSize = 13;
Lane1Y = 138;
for RowIndex = 1:7
	for ColIndex = 1:6
		Value = 0.55 + 0.22 * sin(RowIndex * 2.7 + ColIndex * 3.1);
		CellHex = iHex((1 - Value * (1 - Lane1Base)) * 255);
		Lines(end+1) = sprintf('<rect x="%g" y="%g" width="%g" height="%g" rx="2.5" fill="%s"/>', ...
			320 + Pitch * (ColIndex - 1), Lane1Y + Pitch * (RowIndex - 1), CellSize, CellSize, CellHex);
	end
end
for RowIndex = 1:7
	for ColIndex = 1:6
		Value = Lane1Profile(RowIndex) + 0.01 * sin(RowIndex * 1.7 + ColIndex * 2.1);
		CellHex = iHex((1 - Value * (1 - Lane1Base)) * 255);
		Lines(end+1) = sprintf('<rect x="%g" y="%g" width="%g" height="%g" rx="2.5" fill="%s"/>', ...
			462 + Pitch * (ColIndex - 1), Lane1Y + Pitch * (RowIndex - 1), CellSize, CellSize, CellHex);
	end
end
Lines(end+1) = sprintf('<path d="M418 190 L452 190" fill="none" stroke="%s" stroke-width="2.4" marker-end="url(#arrowDark)"/>', DarkHex);
Lines(end+1) = sprintf('<path d="M462 262 L462 256 M462 259 L550 259 M550 262 L550 256" fill="none" stroke="%s" stroke-width="1.8"/>', DarkHex);
Lines(end+1) = '<text x="506" y="280" class="tiny" text-anchor="middle">trials</text>';
Lines(end+1) = '<text x="506" y="116" class="label" text-anchor="middle">divergence</text>';
Lines(end+1) = sprintf('<path d="M570 100 L570 115 M564 109 L570 116 L576 109" fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>', InkHex);

Lines(end+1) = sprintf('<path d="M578 199 L662 199" fill="none" stroke="%s" stroke-width="2.4" marker-end="url(#arrowDark)"/>', DarkHex);

% 早期表现 = 首会话首个 block 的命中率（每鼠一个值），画成水平柱而非 trial 曲线
Lines(end+1) = sprintf('<path d="M700 138 L700 268 L1000 268" fill="none" stroke="%s" stroke-width="2"/>', AxisHex);
Lines(end+1) = sprintf('<path d="M700 268 L700 262 M700 138 L700 144" fill="none" stroke="%s" stroke-width="2"/>', AxisHex);
BarValues = [0.45 0.86];
BarX = [780 900];
BarColors = {PaleHex, TealHex};
JitterPattern = [0.9 -0.7 0.2 -0.3 0.55];
for BarIndex = 1:2
	BarHeight = 130 * BarValues(BarIndex);
	Lines(end+1) = sprintf('<rect x="%g" y="%g" width="64" height="%g" fill="%s" fill-opacity="0.9"/>', ...
		BarX(BarIndex) - 32, 268 - BarHeight, BarHeight, BarColors{BarIndex});
	for DotIndex = 1:5
		DotY = 268 - 130 * (BarValues(BarIndex) + 0.035 * JitterPattern(DotIndex));
		Lines(end+1) = sprintf('<circle cx="%g" cy="%g" r="3" fill="%s" fill-opacity="0.75"/>', ...
			BarX(BarIndex) - 24 + 12 * (DotIndex - 1), DotY, InkHex);
	end
end
Lines(end+1) = '<text x="860" y="100" class="label" text-anchor="middle">early performance</text>';
Lines(end+1) = '<text x="860" y="292" class="tiny" text-anchor="middle">first block hit rate</text>';

% ---------- MOp5：TH 调制 → 响应异质性 ----------
Lines(end+1) = sprintf('<text x="42" y="391" class="layer">MOp5</text>');

L5Circles = [140 470 15 0.35; 176 466 9 0.55; 208 478 13 0.45; 132 505 10 0.70; ...
	166 504 16 0.90; 205 508 8 0.60; 146 540 12 0.50; 182 536 14 0.75; 214 540 10 0.65];
for CircleIndex = 1:size(L5Circles, 1)
	Lines(end+1) = sprintf('<circle cx="%g" cy="%g" r="%g" fill="%s" fill-opacity="%g" stroke="#ffffff" stroke-width="1.6"/>', ...
		L5Circles(CircleIndex, 1), L5Circles(CircleIndex, 2), L5Circles(CircleIndex, 3), DarkHex, L5Circles(CircleIndex, 4));
end

Lines(end+1) = sprintf('<path d="M45 505 L112 505" fill="none" stroke="%s" stroke-width="4.2" marker-end="url(#arrowMauve)"/>', MauveHex);
Lines(end+1) = '<text x="78" y="490" class="th" text-anchor="middle">TH</text>';

Lines(end+1) = sprintf('<path d="M232 505 L312 505" fill="none" stroke="%s" stroke-width="2.4" marker-end="url(#arrowDark)"/>', DarkHex);

% 细胞×回合矩阵：左=细胞间无分工（行间一致）；右=行间稳定分化、列内一致 → 异质性高（可复用记忆网络）
Lane2Base = [110 106 134] / 255;
Lane2Profile = [0.98 0.18 0.80 0.42 1.00 0.58 0.28];
Lane2Y = 444;
for RowIndex = 1:7
	for ColIndex = 1:6
		Value = 0.50 + 0.03 * sin(RowIndex * 2.7 + ColIndex * 3.1);
		CellHex = iHex((1 - Value * (1 - Lane2Base)) * 255);
		Lines(end+1) = sprintf('<rect x="%g" y="%g" width="%g" height="%g" rx="2.5" fill="%s"/>', ...
			320 + Pitch * (ColIndex - 1), Lane2Y + Pitch * (RowIndex - 1), CellSize, CellSize, CellHex);
	end
end
for RowIndex = 1:7
	for ColIndex = 1:6
		Value = Lane2Profile(RowIndex) + 0.02 * cos(RowIndex * 2.3 + ColIndex * 1.9);
		CellHex = iHex((1 - Value * (1 - Lane2Base)) * 255);
		Lines(end+1) = sprintf('<rect x="%g" y="%g" width="%g" height="%g" rx="2.5" fill="%s"/>', ...
			462 + Pitch * (ColIndex - 1), Lane2Y + Pitch * (RowIndex - 1), CellSize, CellSize, CellHex);
	end
end
Lines(end+1) = sprintf('<path d="M418 495 L452 495" fill="none" stroke="%s" stroke-width="2.4" marker-end="url(#arrowDark)"/>', DarkHex);
Lines(end+1) = sprintf('<path d="M550 444 L556 444 M553 444 L553 547 M550 547 L556 547" fill="none" stroke="%s" stroke-width="1.8"/>', DarkHex);
Lines(end+1) = '<text x="566" y="492" class="tiny" text-anchor="start">cells</text>';
Lines(end+1) = '<text x="506" y="424" class="label" text-anchor="middle">heterogeneity</text>';
Lines(end+1) = sprintf('<path d="M582 424 L582 409 M576 415 L582 408 L588 415" fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>', InkHex);

Lines(end+1) = sprintf('<path d="M600 505 L662 505" fill="none" stroke="%s" stroke-width="2.4" marker-end="url(#arrowDark)"/>', DarkHex);

Lines(end+1) = sprintf('<path d="M700 405 L700 590 L1000 590" fill="none" stroke="%s" stroke-width="2"/>', AxisHex);
SlowPath = 'M700 590 L714 590 L730 588 L748 582 L766 572 L784 558 L802 540 L820 520 L840 500 L862 482 L886 468 L915 458 L950 452 L1000 450';
FastPath = 'M700 590 L712 588 L726 582 L740 568 L754 548 L768 522 L782 494 L796 468 L812 446 L830 428 L852 416 L880 409 L915 406 L1000 406';
Lines(end+1) = sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="2.6" stroke-dasharray="7 5" stroke-linecap="round"/>', SlowPath, iHex(0.55 * TransferLearning.ColorTH + 0.45 * 255));
Lines(end+1) = sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round"/>', FastPath, MauveHex);
Lines(end+1) = '<text x="860" y="382" class="label" text-anchor="middle">learning speed</text>';
Lines(end+1) = '<text x="860" y="614" class="tiny" text-anchor="middle">blocks</text>';
Lines(end+1) = '<text x="994" y="398" class="tiny" text-anchor="end">TH</text>';
Lines(end+1) = '<text x="994" y="442" class="tiny" text-anchor="end">TH blocked</text>';
Lines(end+1) = '<text x="694" y="404" class="tiny" text-anchor="end">hit rate</text>';
Lines(end+1) = '<text x="694" y="142" class="tiny" text-anchor="end">hit rate</text>';

Lines(end+1) = '</svg>';

SvgPath = TransferLearning.StandardFigureSvgPath('English_FigMechanismModel.svg');
FileID = fopen(SvgPath, 'w', 'n', 'UTF-8');
assert(FileID >= 0, '无法写入机制模型SVG。');
FileCleanup = onCleanup(@()fclose(FileID));
fprintf(FileID, '%s\n', Lines);
clear FileCleanup;
assignin('base', 'MechanismModelSvgPath', SvgPath);
fprintf('已导出：%s\n', SvgPath);

function Hex = iHex(Color)
Hex = sprintf('#%02X%02X%02X', round(Color));
end
