% Fig381A model-structure SVG.

svgName = '中文图Fig381A_ModelStructure.svg';

if ~exist('TransferLearning','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
iWriteSvg(svgPath, iModelStructureSvg());

fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig381_ModelStructureSvgPath', svgPath);

function lines = iModelStructureSvg()
lines = [iSvgHeader(1200, 620, 'Simulated cortical circuit');
	{
	'<rect class="page" x="0" y="0" width="1200" height="620"/>'
	'<g transform="translate(0,-82)">'
	'<rect class="layer-box" x="285" y="128" width="520" height="242" rx="16"/>'
	'<rect class="layer-box" x="285" y="420" width="520" height="242" rx="16"/>'
	iText(310, 160, 'L2/3', 'layer-title', 'start')
	iText(300, 410, 'L5', 'layer-title', 'start')
	iRect(70, 218, 170, 96, 10, 'cue-box')
	iRect(70, 512, 170, 96, 10, 'th-box')
	iRect(328, 205, 190, 108, 12, 'e-node')
	iRect(590, 205, 170, 108, 12, 'i-node')
	iRect(326, 512, 205, 108, 12, 'e-node')
	iRect(585, 512, 195, 108, 12, 'read-node')
	iRect(326, 438, 205, 54, 12, 'i-node')
	iRect(585, 438, 195, 54, 12, 'i-node')
	iRect(845, 430, 130, 72, 10, 'out-box')
	iText(155, 252, 'Light cue', 'box-title', 'middle')
	iText(155, 280, 'sensory input', 'box-small', 'middle')
	iText(155, 306, 'sound or light', 'box-tiny', 'middle')
	iText(155, 546, 'TH input', 'box-title', 'middle')
	iText(155, 574, 'thalamic input', 'box-small', 'middle')
	iText(155, 600, 'available or blocked', 'box-tiny', 'middle')
	iText(423, 234, 'L2/3 excitatory cells', 'box-title', 'middle')
	iText(423, 262, 'cue-responsive cells', 'box-small', 'middle')
	iText(423, 289, '96 cells', 'box-tiny', 'middle')
	iDots(372, 302, 'e-dot')
	iText(675, 234, 'L2/3 inhibitory cells', 'box-title', 'middle')
	iText(675, 262, 'local inhibitory cells', 'box-small', 'middle')
	iText(675, 289, '24 cells', 'box-tiny', 'middle')
	iDots(625, 302, 'i-dot')
	iText(428, 541, 'TH-recipient excitatory cells', 'box-title', 'middle')
	iText(428, 569, 'TH-linked population', 'box-small', 'middle')
	iText(428, 596, '128 cells', 'box-tiny', 'middle')
	iDots(365, 608, 'e-dot')
	iText(683, 541, 'Output excitatory cells', 'box-title', 'middle')
	iText(683, 569, 'lick-response population', 'box-small', 'middle')
	iText(683, 596, '64 cells', 'box-tiny', 'middle')
	iDots(622, 608, 'e-dot')
	iText(428, 461, 'Local inhibitory cells', 'box-small', 'middle')
	iText(428, 482, '16 cells', 'box-tiny', 'middle')
	iText(683, 461, 'Output inhibitory cells', 'box-small', 'middle')
	iText(683, 482, '16 cells', 'box-tiny', 'middle')
	iText(910, 458, 'Behavior', 'box-title', 'middle')
	iText(910, 485, 'lick or no lick', 'box-small', 'middle')
	iArrow(240, 266, 328, 266, 'arrow orange', 'arrowOrange')
	iArrow(240, 560, 326, 560, 'arrow green', 'arrowGreen')
	iArrow(518, 252, 590, 252, 'arrow blue', 'arrowBlue')
	iArrow(590, 280, 518, 280, 'arrow dark', 'arrowDark')
	iCurve('M 737 207 C 786 194, 788 316, 737 306', 'arrow gray thin', 'arrowGray')
	iArrow(430, 512, 430, 492, 'arrow blue', 'arrowBlue')
	iArrow(395, 492, 395, 512, 'arrow dark', 'arrowDark')
	iCurve('M 520 438 C 552 420, 552 510, 520 492', 'arrow gray thin', 'arrowGray')
	iCurve('M 510 292 C 582 360, 650 390, 682 438', 'arrow blue dash', 'arrowBlue')
	iCurve('M 510 560 C 590 520, 625 488, 682 438', 'arrow blue dash', 'arrowBlue')
	iArrow(683, 492, 683, 512, 'arrow dark', 'arrowDark')
	iCurve('M 760 438 C 805 420, 807 507, 760 492', 'arrow gray thin', 'arrowGray')
	iCurve('M 510 313 C 560 390, 620 455, 630 512', 'arrow orange', 'arrowOrange')
	iCurve('M 520 560 C 548 545, 558 545, 585 560', 'arrow orange', 'arrowOrange')
	iCurve('M 610 512 C 555 420, 506 355, 470 313', 'arrow orange dash', 'arrowOrange')
	iArrow(780, 566, 845, 466, 'arrow dark', 'arrowDark')
	'</g>'
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
	'.box-title { font-size: 18px; font-weight: 700; fill: #111827; }'
	'.box-small { font-size: 15px; fill: #374151; }'
	'.box-tiny { font-size: 13px; fill: #6b7280; }'
	'.layer-title { font-size: 24px; font-weight: 700; fill: #111827; }'
	'.cue-box { fill: #eef6ff; stroke: #2563eb; stroke-width: 2.2; }'
	'.th-box { fill: #ecfdf5; stroke: #15803d; stroke-width: 2.2; }'
	'.out-box { fill: #f9fafb; stroke: #111827; stroke-width: 2.2; }'
	'.layer-box { fill: #ffffff; stroke: #cbd5e1; stroke-width: 2; }'
	'.e-node { fill: #fff7ed; stroke: #d87916; stroke-width: 2.2; }'
	'.i-node { fill: #eff6ff; stroke: #2563eb; stroke-width: 2.2; }'
	'.read-node { fill: #fefce8; stroke: #ca8a04; stroke-width: 2.2; }'
	'.arrow { fill: none; stroke-width: 2.7; stroke-linecap: round; stroke-linejoin: round; }'
	'.thin { stroke-width: 1.9; } .dash { stroke-dasharray: 7 6; }'
	'.orange { stroke: #d87916; } .green { stroke: #15803d; } .blue { stroke: #2563eb; } .dark { stroke: #1f2937; } .gray { stroke: #6b7280; }'
	'.e-dot { fill: #f59e0b; stroke: #92400e; stroke-width: 0.8; }'
	'.i-dot { fill: #60a5fa; stroke: #1d4ed8; stroke-width: 0.8; }'
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

function lines = iDots(x, y, className)
lines = {
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x, y)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 17, y - 9)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 34, y)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 51, y - 9)
	sprintf('<circle class="%s" cx="%.1f" cy="%.1f" r="5.5"/>', className, x + 68, y)
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