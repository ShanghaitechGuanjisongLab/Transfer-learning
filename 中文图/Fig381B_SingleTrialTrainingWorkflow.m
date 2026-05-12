% Fig381B single-trial training workflow SVG.

svgName = '中文图Fig381B_SingleTrialTrainingWorkflow.svg';

if ~exist('TransferLearning','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
iWriteSvg(svgPath, iSingleTrialWorkflowSvg());

fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig381B_SingleTrialTrainingWorkflowSvgPath', svgPath);

function lines = iSingleTrialWorkflowSvg()
lines = [iSvgHeader(1500, 760, 'TH model single-trial training workflow');
	{
	'<rect class="page" x="0" y="0" width="1500" height="760"/>'
	'<rect class="decision-band" x="38" y="112" width="1424" height="220" rx="18"/>'
	'<rect class="learning-band" x="38" y="372" width="1424" height="244" rx="18"/>'
	iText(70, 68, 'TH 模型单试次训练流程', 'main-title', 'start')
	iText(70, 94, '每个 trial 先静息门控，再做线索决策；随后用教师 readout 与 reward-mode TH 输入更新 recurrent 矩阵。', 'subtitle', 'start')
	iText(64, 146, '决策路径', 'band-title', 'start')
	iText(64, 406, '监督学习路径', 'band-title', 'start')
	iText(64, 646, 'trial 间保留', 'band-title muted', 'start')
	iStepBox(70, 174, 190, 112, 'state-box', '1', '试次初始状态', {'Mouse state'; 'W / Z / eligibility'; '继承上一试次'})
	iStepBox(302, 174, 218, 112, 'gate-box', '2', '静息基线门控', {'no-cue rest'; '若 readout 误触发'; '先抑制到阈值下'})
	iStepBox(562, 174, 248, 112, 'cue-box', '3', '线索驱动', {'PreCue 或 Cue L2/3 mask'; 'CueL23Gain + noise'; '接入上一静息状态'})
	iStepBox(852, 174, 262, 112, 'network-box', '4', '循环决策网络', {'L2/3 - L5 recurrent passes'; '记录 readout similarity trace'; 'InternalRecurrentPasses + 1'})
	iStepBox(1156, 174, 216, 112, 'behavior-box', '5', '行为判定', {'max(trace) >= threshold'; '记录 hit / miss'; '写入 session performance'})
	iStepBox(562, 432, 270, 124, 'teacher-box', '6', '教师 readout + TH', {'L5Read = target pattern'; 'reward-mode TH input'; 'TeacherReadoutPasses'})
	iStepBox(876, 432, 250, 124, 'trace-box', '7', '资格迹整合', {'decision history'; '+ teacher history'; 'EligibilityDecay'})
	iStepBox(1170, 432, 240, 124, 'update-box', '8', '突触权重更新', {'Z += eta * directed trace'; 'W = accumulator map'; 'E/I columns obey sign'})
	iText(304, 676, '新的 W_InternalToInternal 与 Z_InternalToInternal 进入下一 trial；session 内学习因此逐试次累积。', 'loop-note', 'start')
	iArrow(260, 230, 302, 230, 'arrow dark', 'arrowDark')
	iArrow(520, 230, 562, 230, 'arrow dark', 'arrowDark')
	iArrow(810, 230, 852, 230, 'arrow blue', 'arrowBlue')
	iArrow(1114, 230, 1156, 230, 'arrow dark', 'arrowDark')
	iCurve('M 983 286 C 983 348, 678 356, 678 432', 'arrow green', 'arrowGreen')
	iArrow(832, 494, 876, 494, 'arrow green', 'arrowGreen')
	iArrow(1126, 494, 1170, 494, 'arrow orange', 'arrowOrange')
	iCurve('M 1290 556 C 1290 636, 232 636, 232 286', 'arrow orange dash', 'arrowOrange')
	iCurve('M 412 286 C 412 332, 1115 332, 1238 432', 'arrow gray dash', 'arrowGray')
	iText(610, 354, '决策活动历史', 'flow-label', 'middle')
	iText(898, 354, 'baseline 误触发抑制也会写回 Mouse', 'flow-label gray-text', 'middle')
	iText(1112, 616, '更新后状态回流到下一试次', 'flow-label orange-text', 'middle')
	iMiniCircuit(900, 620)
	'</svg>'
	}];
end

function lines = iSvgHeader(widthValue, heightValue, labelText)
lines = {
	sprintf('<?xml version="1.0" encoding="UTF-8"?>')
	sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="%s">', widthValue, heightValue, widthValue, heightValue, iXml(labelText))
	'<defs>'
	'<marker id="arrowDark" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#1f2937"/></marker>'
	'<marker id="arrowOrange" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#d87916"/></marker>'
	'<marker id="arrowGreen" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#15803d"/></marker>'
	'<marker id="arrowBlue" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#2563eb"/></marker>'
	'<marker id="arrowGray" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#6b7280"/></marker>'
	'<style><![CDATA['
	'text { font-family: "Microsoft YaHei", "Noto Sans CJK SC", Arial, sans-serif; }'
	'.page { fill: #ffffff; }'
	'.decision-band { fill: #f8fafc; stroke: #cbd5e1; stroke-width: 1.8; }'
	'.learning-band { fill: #f6fef9; stroke: #bbf7d0; stroke-width: 1.8; }'
	'.main-title { font-size: 30px; font-weight: 700; fill: #111827; }'
	'.subtitle { font-size: 16px; fill: #4b5563; }'
	'.band-title { font-size: 18px; font-weight: 700; fill: #111827; }'
	'.muted { fill: #6b7280; }'
	'.step-title { font-size: 18px; font-weight: 700; fill: #111827; }'
	'.step-small { font-size: 14px; fill: #374151; }'
	'.step-tiny { font-size: 13px; fill: #6b7280; }'
	'.badge-text { font-size: 14px; font-weight: 700; fill: #ffffff; }'
	'.state-box { fill: #f9fafb; stroke: #475569; stroke-width: 2.1; }'
	'.gate-box { fill: #fff7ed; stroke: #d87916; stroke-width: 2.1; }'
	'.cue-box { fill: #eff6ff; stroke: #2563eb; stroke-width: 2.1; }'
	'.network-box { fill: #eef2ff; stroke: #4f46e5; stroke-width: 2.1; }'
	'.behavior-box { fill: #fefce8; stroke: #ca8a04; stroke-width: 2.1; }'
	'.teacher-box { fill: #ecfdf5; stroke: #15803d; stroke-width: 2.1; }'
	'.trace-box { fill: #f0fdfa; stroke: #0f766e; stroke-width: 2.1; }'
	'.update-box { fill: #fff7ed; stroke: #d87916; stroke-width: 2.1; }'
	'.badge { fill: #111827; stroke: none; }'
	'.flow-label { font-size: 13px; fill: #374151; }'
	'.gray-text { fill: #6b7280; }'
	'.orange-text { fill: #b45309; }'
	'.loop-note { font-size: 15px; fill: #374151; }'
	'.arrow { fill: none; stroke-width: 2.9; stroke-linecap: round; stroke-linejoin: round; }'
	'.dash { stroke-dasharray: 8 7; }'
	'.orange { stroke: #d87916; } .green { stroke: #15803d; } .blue { stroke: #2563eb; } .dark { stroke: #1f2937; } .gray { stroke: #6b7280; }'
	'.mini-node { fill: #ffffff; stroke: #64748b; stroke-width: 1.6; }'
	'.mini-label { font-size: 12px; fill: #475569; }'
	']]></style>'
	'</defs>'
	};
end

function lines = iStepBox(x, y, widthValue, heightValue, className, stepText, titleText, detailLines)
lines = {
	iRect(x, y, widthValue, heightValue, 12, className)
	iBadge(x + 22, y + 24, stepText)
	iText(x + 48, y + 31, titleText, 'step-title', 'start')
	};
for iDetail = 1:numel(detailLines)
	classNameDetail = 'step-small';
	if iDetail >= 3
		classNameDetail = 'step-tiny';
	end
	lines{end + 1} = iText(x + widthValue / 2, y + 58 + 23 * (iDetail - 1), detailLines{iDetail}, classNameDetail, 'middle'); %#ok<AGROW>
end
end

function lines = iBadge(x, y, stepText)
lines = {
	sprintf('<circle class="badge" cx="%.1f" cy="%.1f" r="16"/>', x, y)
	iText(x, y + 5, stepText, 'badge-text', 'middle')
	};
end

function lines = iMiniCircuit(x, y)
lines = {
	'<g transform="translate(900,620)">'
	'<rect class="mini-node" x="0" y="0" width="94" height="42" rx="8"/>'
	'<rect class="mini-node" x="130" y="0" width="124" height="42" rx="8"/>'
	'<rect class="mini-node" x="290" y="0" width="94" height="42" rx="8"/>'
	iText(47, 27, 'L2/3', 'mini-label', 'middle')
	iText(192, 27, 'L5 TH-recipient', 'mini-label', 'middle')
	iText(337, 27, 'L5 Read', 'mini-label', 'middle')
	iArrow(94, 21, 130, 21, 'arrow blue', 'arrowBlue')
	iArrow(254, 21, 290, 21, 'arrow orange', 'arrowOrange')
	'</g>'
	};
if x ~= 900 || y ~= 620
	lines{1} = sprintf('<g transform="translate(%.1f,%.1f)">', x, y);
end
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