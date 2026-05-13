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
lines = [iSvgHeader(620, 236, 'TH model single-trial training workflow');
	{
	'<rect class="page" x="0" y="0" width="620" height="236"/>'
	'<rect class="decision-band" x="12" y="10" width="596" height="58" rx="6"/>'
	'<rect class="learning-band" x="12" y="86" width="596" height="58" rx="6"/>'
	'<rect class="suppression-band" x="12" y="162" width="596" height="54" rx="6"/>'
	iArrow(98, 50, 122, 50, 'arrow dark', 'arrowDark')
	iArrow(192, 50, 216, 50, 'arrow blue', 'arrowBlue')
	iArrow(306, 50, 330, 50, 'arrow blue', 'arrowBlue')
	iArrow(456, 50, 500, 50, 'arrow dark', 'arrowDark')
	iArrow(550, 62, 560, 112, 'arrow green', 'arrowGreen')
	iArrow(520, 126, 504, 126, 'arrow green', 'arrowGreen')
	iArrow(388, 126, 372, 126, 'arrow green', 'arrowGreen')
	iArrow(260, 126, 244, 126, 'arrow orange', 'arrowOrange')
	iArrow(150, 126, 134, 126, 'arrow orange', 'arrowOrange')
	iArrow(79, 138, 79, 188, 'arrow gray', 'arrowGray')
	iArrow(134, 201, 196, 201, 'arrow gray', 'arrowGray')
	iArrow(328, 201, 430, 201, 'arrow dark', 'arrowDark')
	iText(22, 28, 'Decision phase', 'band-title', 'start')
	iText(22, 104, 'Learning phase', 'band-title', 'start')
	iText(226, 180, 'Closed-loop suppression', 'band-title', 'start')
	iStepBox(24, 39, 74, 22, 'state-box', '1', 'Trial state')
	iStepBox(122, 39, 70, 22, 'cue-box', '2', 'Cue input')
	iStepBox(216, 39, 90, 22, 'cue-box', '3', 'Cue-L2/3 map')
	iStepBox(330, 39, 126, 22, 'network-box', '4', 'Recurrent decision')
	iStepBox(500, 39, 100, 22, 'behavior-box', '5', 'Hit threshold')
	iStepBox(520, 115, 80, 22, 'teacher-box', '6', 'Reward input')
	iStepBox(388, 115, 116, 22, 'readout-box', '7', 'Readout teaching')
	iStepBox(260, 115, 112, 22, 'network-box', '8', 'Continued network')
	iStepBox(150, 115, 94, 22, 'update-box', '9', 'Hebbian updates')
	iStepBox(24, 115, 110, 22, 'trace-box', '10', 'Inhibitory plasticity')
	iStepBox(24, 190, 110, 22, 'gate-box', '11', 'Random-cue probe')
	iStepBox(196, 190, 132, 22, 'readout-box', '12', 'Readout-silent training')
	iStepBox(430, 190, 86, 22, 'state-box', '13', 'Next trial')
	'</svg>'
	}];
end

function lines = iSvgHeader(widthValue, heightValue, labelText)
lines = {
	sprintf('<?xml version="1.0" encoding="UTF-8"?>')
	sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="%s">', widthValue, heightValue, widthValue, heightValue, iXml(labelText))
	'<defs>'
	'<marker id="arrowDark" markerWidth="6" markerHeight="6" refX="5.6" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 6 3 L 0 6 z" fill="#1f2937"/></marker>'
	'<marker id="arrowOrange" markerWidth="6" markerHeight="6" refX="5.6" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 6 3 L 0 6 z" fill="#d87916"/></marker>'
	'<marker id="arrowGreen" markerWidth="6" markerHeight="6" refX="5.6" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 6 3 L 0 6 z" fill="#15803d"/></marker>'
	'<marker id="arrowBlue" markerWidth="6" markerHeight="6" refX="5.6" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 6 3 L 0 6 z" fill="#2563eb"/></marker>'
	'<marker id="arrowGray" markerWidth="6" markerHeight="6" refX="5.6" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 6 3 L 0 6 z" fill="#6b7280"/></marker>'
	'<style><![CDATA['
	'text { font-family: "Microsoft YaHei", "Noto Sans CJK SC", Arial, sans-serif; }'
	'.page { fill: #ffffff; }'
	'.decision-band { fill: #f8fafc; stroke: #cbd5e1; stroke-width: 0.5pt; }'
	'.learning-band { fill: #f6fef9; stroke: #bbf7d0; stroke-width: 0.5pt; }'
	'.suppression-band { fill: #fff7ed; stroke: #fed7aa; stroke-width: 0.5pt; }'
	'.band-title { font-size: 6pt; font-weight: 700; fill: #374151; }'
	'.step-title { font-size: 6pt; font-weight: 700; fill: #111827; }'
	'.badge-text { font-size: 6pt; font-weight: 700; fill: #ffffff; }'
	'.state-box { fill: #f9fafb; stroke: #475569; stroke-width: 0.5pt; }'
	'.gate-box { fill: #fff7ed; stroke: #d87916; stroke-width: 0.5pt; }'
	'.cue-box { fill: #eff6ff; stroke: #2563eb; stroke-width: 0.5pt; }'
	'.network-box { fill: #eef2ff; stroke: #4f46e5; stroke-width: 0.5pt; }'
	'.behavior-box { fill: #fefce8; stroke: #ca8a04; stroke-width: 0.5pt; }'
	'.teacher-box { fill: #ecfdf5; stroke: #15803d; stroke-width: 0.5pt; }'
	'.readout-box { fill: #fdf4ff; stroke: #a21caf; stroke-width: 0.5pt; }'
	'.trace-box { fill: #f0fdfa; stroke: #0f766e; stroke-width: 0.5pt; }'
	'.update-box { fill: #fff7ed; stroke: #d87916; stroke-width: 0.5pt; }'
	'.badge { fill: #111827; stroke: none; }'
	'.arrow { fill: none; stroke-width: 0.5pt; stroke-linecap: round; stroke-linejoin: round; }'
	'.dash { stroke-dasharray: 8 7; }'
	'.orange { stroke: #d87916; } .green { stroke: #15803d; } .blue { stroke: #2563eb; } .dark { stroke: #1f2937; } .gray { stroke: #6b7280; }'
	']]></style>'
	'</defs>'
	};
end

function lines = iStepBox(x, y, widthValue, heightValue, className, stepText, titleText)
lines = {
	iRect(x, y, widthValue, heightValue, 4, className)
	iBadge(x + 11, y + heightValue / 2, stepText)
	iText(x + 23, y + heightValue / 2 + 3, titleText, 'step-title', 'start')
	};
end

function lines = iBadge(x, y, stepText)
lines = {
	sprintf('<circle class="badge" cx="%.1f" cy="%.1f" r="7"/>', x, y)
	iText(x, y + 2.7, stepText, 'badge-text', 'middle')
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