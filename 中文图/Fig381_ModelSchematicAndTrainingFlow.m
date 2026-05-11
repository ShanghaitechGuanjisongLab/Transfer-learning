% Fig381A/B model schematic and training-flow SVGs.
%
% Output: two SVG files through the standard Chinese figure output path.

svgNameA = '中文图Fig381A_ModelStructure.svg';
svgNameB = '中文图Fig381B_TrainingFlow.svg';

if ~exist('TransferLearning','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

svgPathA = TransferLearning.StandardFigureSvgPath(svgNameA);
svgPathB = TransferLearning.StandardFigureSvgPath(svgNameB);

iWriteSvg(svgPathA, iModelStructureSvg());
iWriteSvg(svgPathB, iTrainingFlowSvg());

fprintf('Wrote: %s\n', svgPathA);
fprintf('Wrote: %s\n', svgPathB);

assignin('base', 'Fig381_ModelStructureSvgPath', svgPathA);
assignin('base', 'Fig381_TrainingFlowSvgPath', svgPathB);

function lines = iModelStructureSvg()
lines = [iSvgHeader(1200, 780, '中文图381A 模型结构');
	{
	'<rect class="page" x="0" y="0" width="1200" height="780"/>'
	'<text class="panel" x="52" y="70">A</text>'
	'<text class="title" x="105" y="64">中文图381A  主线模型结构</text>'
	'<text class="subtitle" x="105" y="96">显式区分 L2/3 与 L5 的兴奋性细胞、抑制性细胞池，并标出 EE/EI/IE/II 连接的目标亚群</text>'
	'<rect class="layer-box" x="285" y="128" width="520" height="242" rx="16"/>'
	'<rect class="layer-box" x="285" y="420" width="520" height="242" rx="16"/>'
	iText(310, 160, 'L2/3', 'layer-title', 'start')
	iText(310, 452, 'L5', 'layer-title', 'start')
	iRect(70, 218, 170, 96, 10, 'cue-box')
	iRect(70, 512, 170, 96, 10, 'reward-box')
	iRect(328, 205, 190, 108, 12, 'e-node')
	iRect(590, 205, 170, 108, 12, 'i-node')
	iRect(326, 512, 205, 108, 12, 'e-node')
	iRect(585, 512, 195, 108, 12, 'read-node')
	iRect(326, 438, 205, 54, 12, 'i-node')
	iRect(585, 438, 195, 54, 12, 'i-node')
	iRect(845, 430, 130, 72, 10, 'out-box')
	iRect(845, 130, 130, 86, 10, 'gain-box')
	'<rect class="table-box" x="828" y="535" width="325" height="195" rx="12"/>'
	iText(155, 252, 'CueInput', 'box-title', 'middle')
	iText(155, 280, '新任务线索', 'box-small', 'middle')
	iText(155, 306, 'PreCue / Cue', 'box-tiny', 'middle')
	iText(155, 546, 'Reward', 'box-title', 'middle')
	iText(155, 574, '水奖励输入', 'box-small', 'middle')
	iText(155, 600, 'TH gated', 'box-tiny', 'middle')
	iText(423, 234, 'L2/3 E', 'box-title', 'middle')
	iText(423, 262, '线索表征细胞', 'box-small', 'middle')
	iText(423, 289, 'NL23 = 96', 'box-tiny', 'middle')
	iDots(372, 302, 'e-dot')
	iText(675, 234, 'L2/3 I', 'box-title', 'middle')
	iText(675, 262, '局部抑制池', 'box-small', 'middle')
	iText(675, 289, 'NIL23 = 24', 'box-tiny', 'middle')
	iDots(625, 302, 'i-dot')
	iText(428, 541, 'L5RewardRecv E', 'box-title', 'middle')
	iText(428, 569, '奖励接收细胞', 'box-small', 'middle')
	iText(428, 596, 'NL5RewardRecv = 128', 'box-tiny', 'middle')
	iDots(365, 608, 'e-dot')
	iText(683, 541, 'L5Read E', 'box-title', 'middle')
	iText(683, 569, '行为读出细胞', 'box-small', 'middle')
	iText(683, 596, 'NL5Read = 64', 'box-tiny', 'middle')
	iDots(622, 608, 'e-dot')
	iText(428, 461, 'L5RewardRecv I', 'box-small', 'middle')
	iText(428, 482, 'NIL5RewardRecv = 16', 'box-tiny', 'middle')
	iText(683, 461, 'L5Read I', 'box-small', 'middle')
	iText(683, 482, 'NIL5Read = 16', 'box-tiny', 'middle')
	iText(910, 458, 'Hit / Miss', 'box-title', 'middle')
	iText(910, 485, 'threshold', 'box-small', 'middle')
	iText(910, 158, 'FormalHebbGain_i', 'box-title', 'middle')
	iText(910, 184, '鼠级学习速度差异', 'box-small', 'middle')
	iText(910, 206, '只乘正式训练 η', 'box-tiny', 'middle')
	iArrow(240, 266, 328, 266, 'arrow orange', 'arrowOrange')
	iBadge(275, 246, '1', 'orange-badge')
	iArrow(240, 560, 326, 560, 'arrow green', 'arrowGreen')
	iBadge(275, 540, '2', 'green-badge')
	iArrow(518, 252, 590, 252, 'arrow blue', 'arrowBlue')
	iArrow(590, 280, 518, 280, 'arrow dark', 'arrowDark')
	iBadge(554, 233, '4', 'blue-badge')
	iBadge(554, 302, '5', 'dark-badge')
	iCurve('M 737 207 C 786 194, 788 316, 737 306', 'arrow gray thin', 'arrowGray')
	iBadge(785, 260, '6', 'gray-badge')
	iArrow(430, 512, 430, 492, 'arrow blue', 'arrowBlue')
	iArrow(395, 492, 395, 512, 'arrow dark', 'arrowDark')
	iBadge(456, 501, '7', 'blue-badge')
	iBadge(372, 501, '8', 'dark-badge')
	iCurve('M 520 438 C 552 420, 552 510, 520 492', 'arrow gray thin', 'arrowGray')
	iBadge(555, 466, '9', 'gray-badge')
	iCurve('M 510 292 C 582 360, 650 390, 682 438', 'arrow blue dash', 'arrowBlue')
	iCurve('M 510 560 C 590 520, 625 488, 682 438', 'arrow blue dash', 'arrowBlue')
	iArrow(683, 492, 683, 512, 'arrow dark', 'arrowDark')
	iBadge(640, 402, '10', 'blue-badge')
	iBadge(704, 503, '11', 'dark-badge')
	iCurve('M 760 438 C 805 420, 807 507, 760 492', 'arrow gray thin', 'arrowGray')
	iBadge(810, 465, '12', 'gray-badge')
	iCurve('M 510 313 C 560 390, 620 455, 630 512', 'arrow orange', 'arrowOrange')
	iCurve('M 520 560 C 548 545, 558 545, 585 560', 'arrow orange', 'arrowOrange')
	iCurve('M 610 512 C 555 420, 506 355, 470 313', 'arrow orange dash', 'arrowOrange')
	iBadge(575, 448, '3', 'orange-badge')
	iArrow(780, 566, 845, 466, 'arrow dark', 'arrowDark')
	iBadge(812, 514, '13', 'dark-badge')
	iCurve('M 815 560 C 880 420, 875 300, 865 216', 'arrow purple dash', 'arrowPurple')
	iBadge(840, 360, 'η', 'purple-badge')
	iText(850, 565, '连接指向表', 'note-title', 'start')
	iConnectionRow(850, 590, '1', 'orange-badge', 'CueInput → L2/3 E')
	iConnectionRow(850, 612, '2', 'green-badge', 'Reward → L5RewardRecv E')
	iConnectionRow(850, 634, '3', 'orange-badge', 'EE recurrent: L2/3 E + L5 E')
	iConnectionRow(850, 656, '4/7/10', 'blue-badge', 'EI: E → 对应 I pool')
	iConnectionRow(850, 678, '5/8/11', 'dark-badge', 'IE: I pool → 对应 E')
	iConnectionRow(850, 700, '6/9/12', 'gray-badge', 'II: I pool → 同池 I')
	iConnectionRow(850, 722, '13', 'dark-badge', 'L5Read E → 行为输出')
	'<rect class="note" x="70" y="695" width="735" height="54" rx="10"/>'
	iText(95, 727, '正式训练更新：η = HebbRate × FormalHebbGain(mouse) × reward-gated scale；TH inhibited 令 reward/TH teaching 输入为 0。', 'note-text', 'start')
	iText(95, 748, '四类连接按亚群收集权重分布：EE、EI、IE、II；兴奋性可塑权重若小于 0 自动归零。', 'note-text', 'start')
	'</svg>'
	}];
end

function lines = iTrainingFlowSvg()
lines = [iSvgHeader(1200, 820, '中文图381B 训练流程');
	{
	'<rect class="page" x="0" y="0" width="1200" height="820"/>'
	'<text class="panel" x="52" y="70">B</text>'
	'<text class="title" x="105" y="64">中文图381B  主线模型训练流程</text>'
	'<text class="subtitle" x="105" y="96">三组共享同一正式训练任务；Transfer/TH inhibited 先完成预训练，TH inhibited 在正式训练中关闭 reward/TH 教学输入</text>'
	iRect(70, 128, 180, 96, 10, 'init-box')
	iText(160, 160, '初始化每只鼠', 'box-title', 'middle')
	iText(160, 188, '随机 pattern 与权重', 'box-small', 'middle')
	iText(160, 212, 'EE / EI / IE / II', 'box-tiny', 'middle')
	iRect(300, 128, 190, 96, 10, 'gain-box')
	iText(395, 160, '鼠级差异', 'box-title', 'middle')
	iText(395, 188, 'FormalHebbGain_i', 'box-small', 'middle')
	iText(395, 212, '只影响正式训练', 'box-tiny', 'middle')
	iArrow(250, 176, 300, 176, 'arrow dark', 'arrowDark')
	'<text class="lane-label red-text" x="78" y="303">Naive</text>'
	'<text class="lane-label blue-text" x="78" y="455">Transfer</text>'
	'<text class="lane-label dark-text" x="78" y="607">TH inhibited</text>'
	iLaneBlock(190, 248, '无预训练', '从新任务开始', 'cue/light')
	iLaneBlock(190, 400, 'PreCue 预训练', 'ceiling reached', 'schema consolidated')
	iLaneBlock(190, 552, 'PreCue 预训练', 'ceiling reached', 'schema consolidated')
	iLaneBlock(440, 248, '正式训练前', '记录权重 / 异质性', 'Before formal')
	iLaneBlock(440, 400, '正式训练前', 'schema 权重已形成', 'Before formal')
	iLaneBlock(440, 552, '正式训练前', 'schema 权重已形成', 'Before formal')
	iFormalBlock(690, 238, 'LightWater 正式训练', 'RewardInputLevel = 1', 'η × FormalHebbGain_i', 'formal-red')
	iFormalBlock(690, 390, 'LightWater 正式训练', 'RewardInputLevel = 1', '迁移 + reward/TH intact', 'formal-blue')
	iFormalBlock(690, 542, 'LightWater 正式训练', 'RewardInputLevel = 0', 'reward/TH inhibited', 'formal-dark')
	iLaneBlock(970, 248, '输出', 'performance / H23 / H5', 'weight SD + sigmoid')
	iLaneBlock(970, 400, '输出', 'Transfer advantage', 'weight SD + sigmoid')
	iLaneBlock(970, 552, '输出', 'THOff comparison', 'weight SD + sigmoid')
	iArrow(370, 296, 440, 296, 'arrow red', 'arrowRed')
	iArrow(370, 448, 440, 448, 'arrow blue', 'arrowBlue')
	iArrow(370, 600, 440, 600, 'arrow dark', 'arrowDark')
	iArrow(620, 296, 690, 296, 'arrow red', 'arrowRed')
	iArrow(620, 448, 690, 448, 'arrow blue', 'arrowBlue')
	iArrow(620, 600, 690, 600, 'arrow dark', 'arrowDark')
	iArrow(900, 296, 970, 296, 'arrow red', 'arrowRed')
	iArrow(900, 448, 970, 448, 'arrow blue', 'arrowBlue')
	iArrow(900, 600, 970, 600, 'arrow dark', 'arrowDark')
	'<rect class="loop-box" x="300" y="690" width="835" height="86" rx="12"/>'
	iText(322, 724, '每个正式训练 session 内部：', 'note-title', 'start')
	iText(512, 724, '1 决策期 cue+noise → hard threshold', 'note-text', 'start')
	iText(512, 750, '2 学习期 reward/readout clamp → Hebbian EE + WIE/WEI/WII plasticity → overnight consolidation', 'note-text', 'start')
	iCurve('M 790 634 C 760 675, 760 675, 785 690', 'arrow gray dash', 'arrowGray')
	iText(835, 668, '8 sessions loop', 'edge-label', 'middle')
	'<rect class="note" x="70" y="690" width="185" height="86" rx="12"/>'
	iText(92, 722, '固定验收门槛', 'note-title', 'start')
	iText(92, 747, 'NumSessions 固定', 'note-text', 'start')
	iText(92, 771, 'HitThreshold 固定', 'note-text', 'start')
	'</svg>'
	}];
end

function lines = iSvgHeader(widthValue, heightValue, titleText)
lines = {
	sprintf('<?xml version="1.0" encoding="UTF-8"?>')
	sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="%s">', widthValue, heightValue, widthValue, heightValue, iXml(titleText))
	'<defs>'
	'<marker id="arrowDark" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#1f2937"/></marker>'
	'<marker id="arrowOrange" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#d87916"/></marker>'
	'<marker id="arrowGreen" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#15803d"/></marker>'
	'<marker id="arrowBlue" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#2563eb"/></marker>'
	'<marker id="arrowRed" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#dc2626"/></marker>'
	'<marker id="arrowGray" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#6b7280"/></marker>'
	'<marker id="arrowPurple" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#7c3aed"/></marker>'
	'<style><![CDATA['
	'text { font-family: "Microsoft YaHei", "Noto Sans CJK SC", Arial, sans-serif; }'
	'.page { fill: #ffffff; }'
	'.panel { font-size: 46px; font-weight: 700; fill: #111827; }'
	'.title { font-size: 28px; font-weight: 700; fill: #111827; }'
	'.subtitle { font-size: 17px; fill: #4b5563; }'
	'.box-title { font-size: 18px; font-weight: 700; fill: #111827; }'
	'.box-small { font-size: 15px; fill: #374151; }'
	'.box-tiny { font-size: 13px; fill: #6b7280; }'
	'.edge-label { font-size: 13px; fill: #4b5563; }'
	'.note-title { font-size: 15px; font-weight: 700; fill: #111827; }'
	'.note-text { font-size: 14px; fill: #374151; }'
	'.green-text { fill: #15803d; } .red-text { fill: #dc2626; } .blue-text { fill: #2563eb; } .orange-text { fill: #d87916; } .purple-text { fill: #7c3aed; } .dark-text { fill: #111827; }'
	'.layer-title { font-size: 24px; font-weight: 700; fill: #111827; }'
	'.lane-label { font-size: 22px; font-weight: 700; }'
	'.cue-box { fill: #eef6ff; stroke: #2563eb; stroke-width: 2.2; }'
	'.reward-box { fill: #ecfdf5; stroke: #15803d; stroke-width: 2.2; }'
	'.exc-box { fill: #f8fbff; stroke: #2563eb; stroke-width: 2.2; }'
	'.read-box { fill: #fff7ed; stroke: #d87916; stroke-width: 2.2; }'
	'.out-box { fill: #f9fafb; stroke: #111827; stroke-width: 2.2; }'
	'.gate-box { fill: #ecfdf5; stroke: #15803d; stroke-width: 2.2; }'
	'.gain-box { fill: #f5f3ff; stroke: #7c3aed; stroke-width: 2.2; }'
	'.layer-box { fill: #ffffff; stroke: #cbd5e1; stroke-width: 2; }'
	'.table-box { fill: #ffffff; stroke: #cbd5e1; stroke-width: 1.8; }'
	'.e-node { fill: #fff7ed; stroke: #d87916; stroke-width: 2.2; }'
	'.i-node { fill: #eff6ff; stroke: #2563eb; stroke-width: 2.2; }'
	'.read-node { fill: #fefce8; stroke: #ca8a04; stroke-width: 2.2; }'
	'.init-box { fill: #f9fafb; stroke: #4b5563; stroke-width: 2.2; }'
	'.lane-box { fill: #ffffff; stroke: #d1d5db; stroke-width: 2; }'
	'.formal-red { fill: #fff1f2; stroke: #dc2626; stroke-width: 2.2; }'
	'.formal-blue { fill: #eff6ff; stroke: #2563eb; stroke-width: 2.2; }'
	'.formal-dark { fill: #f3f4f6; stroke: #111827; stroke-width: 2.2; }'
	'.note { fill: #f9fafb; stroke: #d1d5db; stroke-width: 1.6; }'
	'.loop-box { fill: #f8fafc; stroke: #94a3b8; stroke-width: 1.8; }'
	'.inh { fill: #111827; stroke: #111827; stroke-width: 1.5; }'
	'.inh-text { font-size: 20px; font-weight: 700; fill: #ffffff; }'
	'.arrow { fill: none; stroke-width: 2.7; stroke-linecap: round; stroke-linejoin: round; }'
	'.thin { stroke-width: 1.9; } .dash { stroke-dasharray: 7 6; }'
	'.orange { stroke: #d87916; } .green { stroke: #15803d; } .blue { stroke: #2563eb; } .red { stroke: #dc2626; } .dark { stroke: #1f2937; } .gray { stroke: #6b7280; } .purple { stroke: #7c3aed; }'
	'.e-dot { fill: #f59e0b; stroke: #92400e; stroke-width: 0.8; }'
	'.i-dot { fill: #60a5fa; stroke: #1d4ed8; stroke-width: 0.8; }'
	'.orange-badge { fill: #d87916; stroke: #ffffff; stroke-width: 1.4; }'
	'.green-badge { fill: #15803d; stroke: #ffffff; stroke-width: 1.4; }'
	'.blue-badge { fill: #2563eb; stroke: #ffffff; stroke-width: 1.4; }'
	'.dark-badge { fill: #1f2937; stroke: #ffffff; stroke-width: 1.4; }'
	'.gray-badge { fill: #6b7280; stroke: #ffffff; stroke-width: 1.4; }'
	'.purple-badge { fill: #7c3aed; stroke: #ffffff; stroke-width: 1.4; }'
	'.badge-text { font-size: 11px; font-weight: 700; fill: #ffffff; }'
	']]></style>'
	'</defs>'
	};
end

function node = iRect(x, y, widthValue, heightValue, rx, className)
node = sprintf('<rect class="%s" x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f"/>', className, x, y, widthValue, heightValue, rx);
end

function node = iText(x, y, textValue, className, anchor)
node = sprintf('<text class="%s" x="%.1f" y="%.1f" text-anchor="%s">%s</text>', className, x, y, anchor, iXml(textValue));
end

function node = iArrow(x1, y1, x2, y2, className, markerName)
node = sprintf('<line class="%s" x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" marker-end="url(#%s)"/>', className, x1, y1, x2, y2, markerName);
end

function node = iCurve(pathValue, className, markerName)
node = sprintf('<path class="%s" d="%s" marker-end="url(#%s)"/>', className, pathValue, markerName);
end

function lines = iBadge(x, y, labelText, className)
lines = {
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="13"/>', className, x, y)
	iText(x, y + 4, labelText, 'badge-text', 'middle')
	};
end

function lines = iDots(x, y, className)
lines = {
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x, y)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 17, y - 9)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 34, y)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 51, y - 9)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 68, y)
	};
end

function lines = iConnectionRow(x, y, badgeText, badgeClass, rowText)
lines = {
	iBadge(x + 12, y - 4, badgeText, badgeClass)
	iText(x + 34, y, rowText, 'edge-label', 'start')
	};
end

function lines = iLaneBlock(x, y, titleText, line1, line2)
lines = {
	iRect(x, y, 180, 96, 10, 'lane-box')
	iText(x + 90, y + 33, titleText, 'box-title', 'middle')
	iText(x + 90, y + 61, line1, 'box-small', 'middle')
	iText(x + 90, y + 84, line2, 'box-tiny', 'middle')
	};
end

function lines = iFormalBlock(x, y, titleText, line1, line2, className)
lines = {
	iRect(x, y, 210, 116, 10, className)
	iText(x + 105, y + 39, titleText, 'box-title', 'middle')
	iText(x + 105, y + 70, line1, 'box-small', 'middle')
	iText(x + 105, y + 96, line2, 'box-tiny', 'middle')
	};
end

function encoded = iXml(textValue)
encoded = string(textValue);
encoded = replace(encoded, '&', '&amp;');
encoded = replace(encoded, '<', '&lt;');
encoded = replace(encoded, '>', '&gt;');
encoded = replace(encoded, '"', '&quot;');
encoded = char(encoded);
end

function iWriteSvg(svgPath, lines)
fid = fopen(svgPath, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
iWriteLines(fid, lines);
clear cleaner
end

function iWriteLines(fid, lines)
for iLine = 1:numel(lines)
	lineValue = lines{iLine};
	if iscell(lineValue)
		iWriteLines(fid, lineValue);
	else
		fprintf(fid, '%s\n', lineValue);
	end
end
end