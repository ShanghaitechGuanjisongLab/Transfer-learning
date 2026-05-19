% Fig381C current-mainline single-trial training workflow SVG.

svgName = '中文图Fig381C_SingleTrialTrainingWorkflow.svg';
iEnsureTransferLearningProject();
svgPath = TransferLearning.StandardFigureSvgPath(svgName);
iWriteSvg(svgPath, iSingleTrialWorkflowSvg());

fprintf('Wrote: %s\n', svgPath);
assignin('base', 'Fig381C_SingleTrialTrainingWorkflowSvgPath', svgPath);

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

function lines = iSingleTrialWorkflowSvg()
lines = [iSvgHeader(1280, 760, 'Current TH model single-trial training workflow');
	'<text x="54" y="58" class="figure-title">Current mainline model: one training trial</text>';
	'<text x="56" y="88" class="caption">Each session repeats this trial loop NumTrials = 30 times; pretraining and formal training use the same trial engine with different cue patterns and teaching scales.</text>';
	iBand(50, 120, 1180, 170, 'decision-band');
	iBand(50, 330, 1180, 250, 'learning-band');
	iBand(50, 615, 1180, 92, 'optional-band');
	iText(78, 150, 'Decision phase', 'band-title', 'start');
	iText(78, 360, 'Teaching and plasticity phase', 'band-title', 'start');
	iText(78, 646, 'Pretraining-only continuation', 'band-title', 'start');
	iStepBox(92, 184, 190, 78, 'cue-step', '1', 'Cue + noise', 'E cue + L2/3 I cue drive');
	iStepBox(340, 184, 220, 78, 'network-step', '2', 'Recurrent settling', 'RunInternalNetwork, 5 passes');
	iStepBox(620, 184, 220, 78, 'readout-step', '3', 'Readout decision', 'L5Read drive vs HitThreshold');
	iStepBox(902, 184, 220, 78, 'readout-step', '4', 'Hit / miss', 'trial outcome is recorded');
	iArrow(282, 223, 340, 223, 'flow-line', 'arrow');
	iArrow(560, 223, 620, 223, 'flow-line', 'arrow');
	iArrow(840, 223, 902, 223, 'flow-line', 'arrow');
	iStepBox(92, 400, 220, 86, 'scale-step', '5', 'Teaching scale', 'pretrain=1; formal THOff=0.4');
	iStepBox(368, 400, 260, 86, 'teach-step', '6', 'Set learning activity', 'moves toward readout target');
	iStepBox(690, 400, 230, 86, 'plastic-step', '7', 'Recurrent Hebb', 'postHistory vs internalHistory');
	iStepBox(980, 400, 210, 86, 'plastic-step', '8', 'Inhibitory Hebb', 'local I + L2/3 I-to-L5');
	iArrow(312, 443, 368, 443, 'flow-line', 'arrow');
	iArrow(628, 443, 690, 443, 'flow-line', 'arrow');
	iArrow(920, 443, 980, 443, 'flow-line', 'arrow');
	iCurve('M 730 262 C 720 310 290 305 205 400', 'phase-line', 'arrow');
	iLabelBackplate(438, 288, 420, 26);
	iText(645, 306, 'decision activity and internal history feed the teaching update', 'phase-label', 'middle');
	iText(140, 526, 'L23 and L5RewardRecv learning activity remain the cue-state activity.', 'note-text', 'start');
	iText(140, 550, 'L5Read learning activity = cue activity + scale x (readout target - cue activity).', 'note-text', 'start');
	iText(690, 526, 'L5Read inhibitory teaching = scale x inhibitory readout pattern.', 'note-text', 'start');
	iText(690, 550, 'Weights updated every trial: recurrent E-to-E, local WIE/WEI/WII, and L2/3 I-to-L5 projections.', 'note-text', 'start');
	iStepBox(340, 642, 260, 48, 'optional-step', '', 'Noise-cue backtraining', 'Run after teaching only during pretraining');
	iStepBox(710, 642, 270, 48, 'optional-step', '', 'Noise-first branch', 'requires NoiseFirstStateCarryover');
	iArrow(600, 666, 710, 666, 'optional-line', 'arrow');
	iText(1000, 666, 'default: off in mainline', 'note-text', 'start');
	'</svg>'
];
end

function lines = iSvgHeader(widthValue, heightValue, labelText)
lines = ["<?xml version=""1.0"" encoding=""UTF-8""?>";
	string(sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="%s">', widthValue, heightValue, widthValue, heightValue, iXml(labelText)));
	"<defs>";
	"<marker id=""arrow"" viewBox=""0 0 10 10"" refX=""9"" refY=""5"" markerWidth=""8"" markerHeight=""8"" orient=""auto-start-reverse""><path d=""M 0 0 L 10 5 L 0 10 z"" class=""marker-fill""/></marker>";
	"<style>";
	"svg{background:#ffffff;font-family:Arial,Helvetica,sans-serif;} .figure-title{font-size:30px;font-weight:700;fill:#20242a;} .caption{font-size:16px;fill:#5b6470;} .band-title{font-size:20px;font-weight:700;fill:#293241;} .step-title{font-size:17px;font-weight:700;fill:#1f2933;} .step-small{font-size:13px;fill:#52606d;} .badge-text{font-size:14px;font-weight:700;fill:#ffffff;} .note-text{font-size:14px;fill:#4b5563;} .phase-label{font-size:14px;fill:#2f5da8;font-weight:700;} .decision-band{fill:#f6f8fb;stroke:#d4dbe7;stroke-width:1.5;} .learning-band{fill:#f8fbf7;stroke:#d4e5d7;stroke-width:1.5;} .optional-band{fill:#fbf8f3;stroke:#ead7b7;stroke-width:1.5;} .cue-step{fill:#f5f7fb;stroke:#7c8798;stroke-width:2;} .network-step{fill:#e8f1ff;stroke:#2f5da8;stroke-width:2;} .readout-step{fill:#fff8e8;stroke:#b7791f;stroke-width:2;} .scale-step{fill:#eaf8f0;stroke:#2f8f5b;stroke-width:2;} .teach-step{fill:#edf7ff;stroke:#2b6cb0;stroke-width:2;} .plastic-step{fill:#fff0f0;stroke:#b0414a;stroke-width:2;} .optional-step{fill:#fffaf0;stroke:#c49a45;stroke-width:2;} .flow-line{fill:none;stroke:#344054;stroke-width:3;marker-end:url(#arrow);} .phase-line{fill:none;stroke:#2f5da8;stroke-width:3;stroke-dasharray:8 6;marker-end:url(#arrow);} .optional-line{fill:none;stroke:#9a6b21;stroke-width:2.5;stroke-dasharray:6 5;marker-end:url(#arrow);} .marker-fill{fill:#344054;} .badge{fill:#344054;}";
	"</style>";
	"</defs>";
	string(sprintf('<rect x="0" y="0" width="%d" height="%d" fill="#ffffff"/>', widthValue, heightValue))];
end

function node = iBand(posX, posY, widthValue, heightValue, className)
node = string(sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="8" class="%s"/>', posX, posY, widthValue, heightValue, className));
end

function lines = iStepBox(posX, posY, widthValue, heightValue, className, stepText, titleText, smallText)
lines = [iRect(posX, posY, widthValue, heightValue, 8, className);
	iBadge(posX + 22, posY + heightValue / 2, stepText);
	iText(posX + 48, posY + heightValue / 2 - 5, titleText, 'step-title', 'start');
	iText(posX + 48, posY + heightValue / 2 + 18, smallText, 'step-small', 'start')];
end

function node = iLabelBackplate(posX, posY, widthValue, heightValue)
node = string(sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="4" fill="#ffffff" opacity="0.92"/>', posX, posY, widthValue, heightValue));
end

function lines = iBadge(posX, posY, stepText)
if strlength(string(stepText)) == 0
	lines = strings(0, 1);
	return;
end
lines = [string(sprintf('<circle cx="%.1f" cy="%.1f" r="14" class="badge"/>', posX, posY));
	iText(posX, posY + 5, stepText, 'badge-text', 'middle')];
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
	error('Fig381C:CannotOpenSvg', 'Cannot open SVG path for writing: %s', svgPath);
end
cleanupObj = onCleanup(@() fclose(fileID));
for lineIndex = 1:numel(lines)
	fprintf(fileID, '%s\n', char(lines(lineIndex)));
end
clear cleanupObj;
end
