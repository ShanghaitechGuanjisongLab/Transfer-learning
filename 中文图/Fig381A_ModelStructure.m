% Fig381A current-mainline static model-structure SVG.

svgName = '中文图Fig381A_ModelStructure.svg';
iEnsureTransferLearningProject();
svgPath = TransferLearning.StandardFigureSvgPath(svgName);
iWriteSvg(svgPath, iModelStructureSvg());

fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig381_ModelStructureSvgPath', svgPath);

function iEnsureTransferLearningProject()
if ~exist('TransferLearning', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	projectFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(projectFile, 'file')
		matlab.project.loadProject(projectFile);
	end
end
end

function lines = iModelStructureSvg()
lines = [iSvgHeader(1280, 720, 'Current TH model static circuit');
	'<text x="54" y="58" class="figure-title">Current mainline model: static circuit</text>';
	'<text x="56" y="88" class="caption">Model checked from +TransferLearning/+THModel: cue-driven cortical dynamics, readout teaching, and plastic inhibitory circuits.</text>';
	iRect(52, 130, 170, 88, 8, 'input-box');
	iText(137, 162, 'Cue input', 'box-title', 'middle');
	iText(137, 189, 'PreCue or Cue pattern', 'box-small', 'middle');
	iText(137, 211, 'to L2/3 E cells', 'box-tiny', 'middle');
	iRect(52, 270, 170, 88, 8, 'input-box');
	iText(137, 302, 'Cue-to-I input', 'box-title', 'middle');
	iText(137, 329, 'matched cue pattern', 'box-small', 'middle');
	iText(137, 351, 'to L2/3 I cells', 'box-tiny', 'middle');
	iRect(52, 560, 220, 102, 8, 'teach-box');
	iText(162, 592, 'Teaching scale', 'box-title', 'middle');
	iText(162, 619, 'pretrain = 1.0', 'box-small', 'middle');
	iText(162, 641, 'formal Naive/Transfer = 1.0', 'box-tiny', 'middle');
	iText(162, 660, 'formal TH inhibited = 0.4', 'box-tiny', 'middle');
	iRect(330, 188, 210, 100, 8, 'exc-box');
	iText(435, 222, 'L2/3 excitatory', 'box-title', 'middle');
	iText(435, 249, 'cue-responsive population', 'box-small', 'middle');
	iText(435, 272, 'NL23 = 96', 'box-tiny', 'middle');
	iRect(330, 326, 210, 90, 8, 'inh-box');
	iText(435, 358, 'L2/3 inhibitory', 'box-title', 'middle');
	iText(435, 383, 'local I pool, NIL23 = 24', 'box-small', 'middle');
	iText(435, 405, 'WEI/WIE/WII plastic', 'box-tiny', 'middle');
	iRect(640, 120, 240, 102, 8, 'exc-box');
	iText(760, 154, 'L5RewardRecv E', 'box-title', 'middle');
	iText(760, 181, 'recurrent schema pool', 'box-small', 'middle');
	iText(760, 204, 'NL5RewardRecv = 128', 'box-tiny', 'middle');
	iRect(640, 252, 240, 90, 8, 'inh-box');
	iText(760, 284, 'L5RewardRecv I', 'box-title', 'middle');
	iText(760, 309, 'local I pool, NIL5RewardRecv = 16', 'box-small', 'middle');
	iText(760, 331, 'WEI/WIE/WII plastic', 'box-tiny', 'middle');
	iRect(640, 472, 240, 102, 8, 'exc-box');
	iText(760, 506, 'L5Read E', 'box-title', 'middle');
	iText(760, 533, 'behavioural readout cells', 'box-small', 'middle');
	iText(760, 556, 'NL5Read = 64', 'box-tiny', 'middle');
	iRect(960, 332, 230, 104, 8, 'inh-box');
	iText(1075, 366, 'L5Read inhibitory', 'box-title', 'middle');
	iText(1075, 393, 'driven by L2/3 + L5RewardRecv', 'box-small', 'middle');
	iText(1075, 416, 'NIL5Read = 16', 'box-tiny', 'middle');
	iRect(1000, 524, 190, 90, 8, 'output-box');
	iText(1095, 557, 'Readout drive', 'box-title', 'middle');
	iText(1095, 584, 'thresholded to hit', 'box-small', 'middle');
	iText(1095, 606, 'lick / no lick', 'box-tiny', 'middle');
	iArrow(222, 174, 330, 232, 'exc-line', 'arrow');
	iArrow(222, 314, 330, 370, 'eto-i-line', 'arrow');
	iArrow(540, 238, 640, 170, 'recur-line', 'arrow');
	iArrow(640, 522, 540, 238, 'recur-line', 'arrow');
	iCurve('M 540 220 C 610 118 805 96 880 142', 'recur-line', 'arrow');
	iCurve('M 880 172 C 955 245 955 436 880 510', 'recur-line', 'arrow');
	iCurve('M 640 545 C 560 610 470 440 540 390', 'recur-line', 'arrow');
	iArrow(435, 288, 435, 326, 'eto-i-line', 'arrow');
	iArrow(435, 326, 435, 288, 'inhib-line', 'arrow');
	iArrow(760, 222, 760, 252, 'eto-i-line', 'arrow');
	iArrow(760, 252, 760, 222, 'inhib-line', 'arrow');
	iArrow(540, 374, 640, 295, 'inhib-line', 'arrow');
	iArrow(540, 374, 640, 522, 'inhib-line', 'arrow');
	iArrow(540, 238, 960, 366, 'eto-i-line', 'arrow');
	iArrow(880, 171, 960, 384, 'eto-i-line', 'arrow');
	iArrow(960, 404, 880, 522, 'inhib-line', 'arrow');
	iArrow(880, 522, 1000, 568, 'output-line', 'arrow');
	iArrow(272, 609, 640, 522, 'teach-line', 'arrow');
	iArrow(272, 628, 960, 384, 'teach-line', 'arrow');
	iText(576, 132, 'plastic recurrent E-to-E matrix', 'line-label', 'middle');
	iText(575, 450, 'L2/3 I projections to L5', 'line-label-red', 'middle');
	iText(1064, 306, 'readout-targeted inhibition', 'line-label-red', 'middle');
	iText(548, 666, 'teaching pulls L5Read activity and L5Read I target', 'line-label-green', 'middle');
	iText(202, 698, 'No explicit reward-cell population is used in the current mainline; reward/TH state is represented by TeachingSignalScale.', 'note-text', 'start');
	'</svg>'
];
end

function lines = iSvgHeader(widthValue, heightValue, labelText)
lines = ["<?xml version=""1.0"" encoding=""UTF-8""?>";
	string(sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="%s">', widthValue, heightValue, widthValue, heightValue, iXml(labelText)));
	"<defs>";
	"<marker id=""arrow"" viewBox=""0 0 10 10"" refX=""9"" refY=""5"" markerWidth=""8"" markerHeight=""8"" orient=""auto-start-reverse""><path d=""M 0 0 L 10 5 L 0 10 z"" class=""marker-fill""/></marker>";
	"<style>";
	"svg{background:#ffffff;font-family:Arial,Helvetica,sans-serif;} .figure-title{font-size:30px;font-weight:700;fill:#20242a;} .caption{font-size:16px;fill:#5b6470;} .box-title{font-size:19px;font-weight:700;fill:#1f2933;} .box-small{font-size:15px;fill:#374151;} .box-tiny{font-size:13px;fill:#64748b;} .line-label{font-size:13px;fill:#2f5da8;font-weight:700;} .line-label-red{font-size:13px;fill:#9b2f37;font-weight:700;} .line-label-green{font-size:13px;fill:#26734d;font-weight:700;} .note-text{font-size:14px;fill:#5b6470;} .input-box{fill:#f5f7fb;stroke:#8b95a5;stroke-width:2;} .teach-box{fill:#eaf8f0;stroke:#3f9d68;stroke-width:2;} .exc-box{fill:#e8f1ff;stroke:#2f5da8;stroke-width:2.5;} .inh-box{fill:#fff0f0;stroke:#b0414a;stroke-width:2.5;} .output-box{fill:#fff8e8;stroke:#b7791f;stroke-width:2.5;} .exc-line,.recur-line{fill:none;stroke:#2f5da8;stroke-width:3;marker-end:url(#arrow);} .recur-line{stroke-dasharray:8 6;} .eto-i-line{fill:none;stroke:#7c8798;stroke-width:2.6;marker-end:url(#arrow);} .inhib-line{fill:none;stroke:#b0414a;stroke-width:3;stroke-dasharray:7 6;marker-end:url(#arrow);} .teach-line{fill:none;stroke:#2f8f5b;stroke-width:3;stroke-dasharray:9 5;marker-end:url(#arrow);} .output-line{fill:none;stroke:#b7791f;stroke-width:3;marker-end:url(#arrow);} .marker-fill{fill:#344054;}";
	"</style>";
	"</defs>";
	string(sprintf('<rect x="0" y="0" width="%d" height="%d" fill="#ffffff"/>', widthValue, heightValue))];
end

function node = iRect(posX, posY, widthValue, heightValue, radiusValue, className)
node = string(sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" class="%s"/>', posX, posY, widthValue, heightValue, radiusValue, className));
end

function node = iText(posX, posY, textValue, className, anchor)
node = string(sprintf('<text x="%.1f" y="%.1f" class="%s" text-anchor="%s">%s</text>', posX, posY, className, anchor, iXml(textValue)));
end

function node = iArrow(startX, startY, endX, endY, className, markerName)
node = string(sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" class="%s" marker-end="url(#%s)"/>', startX, startY, endX, endY, className, markerName));
end

function node = iCurve(pathValue, className, markerName)
node = string(sprintf('<path d="%s" class="%s" marker-end="url(#%s)"/>', iXml(pathValue), className, markerName));
end

function encoded = iXml(textValue)
encoded = string(textValue);
encoded = replace(encoded, "&", "&amp;");
encoded = replace(encoded, "<", "&lt;");
encoded = replace(encoded, ">", "&gt;");
encoded = replace(encoded, '"', "&quot;");
encoded = char(encoded);
end

function iWriteSvg(svgPath, lines)
fileID = fopen(svgPath, 'w', 'n', 'UTF-8');
if fileID < 0
	error('Fig381A:CannotOpenSvg', 'Cannot open SVG path for writing: %s', svgPath);
end
cleanupObj = onCleanup(@() fclose(fileID));
for lineIndex = 1:numel(lines)
	fprintf(fileID, '%s\n', char(lines(lineIndex)));
end
clear cleanupObj;
end