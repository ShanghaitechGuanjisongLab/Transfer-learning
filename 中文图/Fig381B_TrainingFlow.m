% Fig381B task-flow SVG.

svgName = '中文图Fig381B_TrainingFlow.svg';

if ~exist('TransferLearning','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

svgPath = TransferLearning.StandardFigureSvgPath(svgName);
iWriteSvg(svgPath, iTrainingFlowSvg());

fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig381_TrainingFlowSvgPath', svgPath);

function lines = iTrainingFlowSvg()
lines = [iSvgHeader(1200, 590, 'Simulated inputs, cells, and outputs');
	{
	'<rect class="page" x="0" y="0" width="1200" height="590"/>'
	'<g transform="translate(0,-82)">'
	iRect(70, 128, 180, 96, 10, 'init-box')
	iText(160, 160, 'Cortical cells', 'box-title', 'middle')
	iText(160, 188, 'L2/3 and L5', 'box-small', 'middle')
	iText(160, 212, 'excitatory and inhibitory', 'box-tiny', 'middle')
	iRect(300, 128, 190, 96, 10, 'th-box')
	iText(395, 160, 'Task inputs', 'box-title', 'middle')
	iText(395, 188, 'sound or light cue', 'box-small', 'middle')
	iText(395, 212, 'TH input', 'box-tiny', 'middle')
	iArrow(250, 176, 300, 176, 'arrow dark', 'arrowDark')
	'<text class="lane-label red-text" x="78" y="303">Naive</text>'
	'<text class="lane-label blue-text" x="78" y="455">Transfer</text>'
	'<text class="lane-label dark-text" x="76" y="592">TH input</text>'
	'<text class="lane-label dark-text" x="76" y="622">absent</text>'
	iLaneBlock(190, 248, 'Light cue', 'TH input', 'L2/3 and L5 cells')
	iLaneBlock(190, 400, 'Sound cue', 'TH input', 'L2/3 and L5 cells')
	iLaneBlock(190, 552, 'Sound cue', 'TH input', 'L2/3 and L5 cells')
	iLaneBlock(440, 248, 'L2/3 cells', 'L5 cells', 'cortical activity')
	iLaneBlock(440, 400, 'Sound-linked cells', 'L2/3 and L5 cells', 'cortical activity')
	iLaneBlock(440, 552, 'Sound-linked cells', 'L2/3 and L5 cells', 'cortical activity')
	iFormalBlock(690, 238, 'Light cue', 'TH input', 'licking behavior', 'formal-red')
	iFormalBlock(690, 390, 'Light cue', 'TH input', 'licking behavior', 'formal-blue')
	iFormalBlock(690, 542, 'Light cue', 'TH input absent', 'licking behavior', 'formal-dark')
	iLaneBlock(970, 248, 'Licking behavior', 'cortical activity', 'L2/3 and L5 cells')
	iLaneBlock(970, 400, 'Licking behavior', 'cortical activity', 'L2/3 and L5 cells')
	iLaneBlock(970, 552, 'Licking behavior', 'cortical activity', 'L2/3 and L5 cells')
	iArrow(370, 296, 440, 296, 'arrow red', 'arrowRed')
	iArrow(370, 448, 440, 448, 'arrow blue', 'arrowBlue')
	iArrow(370, 600, 440, 600, 'arrow dark', 'arrowDark')
	iArrow(620, 296, 690, 296, 'arrow red', 'arrowRed')
	iArrow(620, 448, 690, 448, 'arrow blue', 'arrowBlue')
	iArrow(620, 600, 690, 600, 'arrow dark', 'arrowDark')
	iArrow(900, 296, 970, 296, 'arrow red', 'arrowRed')
	iArrow(900, 448, 970, 448, 'arrow blue', 'arrowBlue')
	iArrow(900, 600, 970, 600, 'arrow dark', 'arrowDark')
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
	'<marker id="arrowRed" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#dc2626"/></marker>'
	'<marker id="arrowBlue" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="strokeWidth"><path d="M 0 0 L 10 5 L 0 10 z" fill="#2563eb"/></marker>'
	'<style><![CDATA['
	'text { font-family: "Microsoft YaHei", "Noto Sans CJK SC", Arial, sans-serif; }'
	'.page { fill: #ffffff; }'
	'.box-title { font-size: 18px; font-weight: 700; fill: #111827; }'
	'.box-small { font-size: 15px; fill: #374151; }'
	'.box-tiny { font-size: 13px; fill: #6b7280; }'
	'.red-text { fill: #dc2626; } .blue-text { fill: #2563eb; } .dark-text { fill: #111827; }'
	'.lane-label { font-size: 22px; font-weight: 700; }'
	'.init-box { fill: #f9fafb; stroke: #4b5563; stroke-width: 2.2; }'
	'.th-box { fill: #ecfdf5; stroke: #15803d; stroke-width: 2.2; }'
	'.lane-box { fill: #ffffff; stroke: #d1d5db; stroke-width: 2; }'
	'.formal-red { fill: #fff1f2; stroke: #dc2626; stroke-width: 2.2; }'
	'.formal-blue { fill: #eff6ff; stroke: #2563eb; stroke-width: 2.2; }'
	'.formal-dark { fill: #f3f4f6; stroke: #111827; stroke-width: 2.2; }'
	'.arrow { fill: none; stroke-width: 2.7; stroke-linecap: round; stroke-linejoin: round; }'
	'.red { stroke: #dc2626; } .blue { stroke: #2563eb; } .dark { stroke: #1f2937; }'
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