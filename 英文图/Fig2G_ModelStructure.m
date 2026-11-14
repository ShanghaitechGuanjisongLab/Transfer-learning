% 英文图2G：重制中文Fig381A，结构名称不变，数量和配色由当前模型与语义常量生成。
ThisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	matlab.project.loadProject(fullfile(ThisDir, '..', 'Transferlearning.prj'));
end
Params = TransferLearning.THModel.DefaultParams();
ExcHex = RgbHex(TransferLearning.ColorMiss);
InhHex = RgbHex(TransferLearning.ColorNaive);
CueHex = RgbHex(TransferLearning.ColorAudio);
TeachHex = RgbHex(TransferLearning.ColorTH);
ReadHex = RgbHex(TransferLearning.ColorHit);
Nodes = {
  45, 150, 175, 85, 'Cue input', sprintf('N = %d', Params.NCueInput), CueHex;
  45, 290, 175, 85, 'Cue-to-I input', 'Matched cue pattern', CueHex;
  45, 445, 220, 100, 'Teaching input', sprintf('TH inhibited: %.2g', Params.THOffTeachingSignalScale), TeachHex;
  310, 145, 190, 85, 'L2/3 excitatory', sprintf('N = %d', Params.NL23), ExcHex;
  310, 285, 190, 85, 'L2/3 inhibitory', sprintf('N = %d', Params.NIL23), InhHex;
  625, 65, 210, 85, 'L5 schema E', sprintf('N = %d', Params.NL5RewardRecv), ExcHex;
  625, 180, 210, 85, 'L5 schema I', sprintf('N = %d', Params.NIL5RewardRecv), InhHex;
  625, 365, 210, 85, 'L5 readout E', sprintf('N = %d', Params.NL5Read), ExcHex;
  970, 290, 210, 85, 'L5 readout I', sprintf('N = %d', Params.NIL5Read), InhHex;
  970, 435, 210, 85, 'Readout', 'Lick / no lick', ReadHex};
Edges = {
 'M220 192 L310 185', CueHex;
 'M220 332 L310 327', CueHex;
 'M405 230 L405 285', ExcHex;
 'M420 285 L420 230', InhHex;
 'M500 177 L625 107', ExcHex;
 'M625 124 L500 207', ExcHex;
 'M730 150 L730 180', ExcHex;
 'M746 180 L746 150', InhHex;
 'M500 327 C570 315 570 160 625 125', InhHex;
 'M500 342 L625 407', InhHex;
 'M500 214 C560 260 570 340 625 392', ExcHex;
 'M625 428 C535 450 555 265 500 220', ExcHex;
 'M815 150 C915 215 915 320 815 365', ExcHex;
 'M785 365 C870 300 865 215 785 150', ExcHex;
 'M500 192 L970 317', ExcHex;
 'M835 107 L970 332', ExcHex;
 'M970 352 L835 407', InhHex;
 'M835 407 L970 475', ReadHex;
 'M265 488 C440 555 540 465 625 428', TeachHex;
 'M265 518 C530 590 880 490 970 370', TeachHex};
Lines = ["<?xml version=""1.0"" encoding=""UTF-8""?>"; "<svg xmlns=""http://www.w3.org/2000/svg"" width=""180mm"" height=""87mm"" viewBox=""0 0 1240 600"">"; "<rect width=""1240"" height=""600"" fill=""white""/>"; "<style>text{font-family:Helvetica,Arial,sans-serif;fill:#292832;letter-spacing:0}.title{font-size:28px;font-weight:600}.label{font-size:21px}.count{font-size:17px}</style>"; "<text x=""45"" y=""40"" class=""title"">Recurrent circuit</text>"];
for EdgeIndex = 1:size(Edges, 1)
	Lines(end+1) = sprintf('<path d="%s" fill="none" stroke="%s" stroke-width="2.5" marker-end="url(#a%d)"/>', Edges{EdgeIndex, 1}, Edges{EdgeIndex, 2}, EdgeIndex);
	Lines(end+1) = sprintf('<defs><marker id="a%d" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0 0 L6 3.5 L0 7 Z" fill="%s"/></marker></defs>', EdgeIndex, Edges{EdgeIndex, 2});
end
for NodeIndex = 1:size(Nodes, 1)
	X = Nodes{NodeIndex, 1}; Y = Nodes{NodeIndex, 2}; Width = Nodes{NodeIndex, 3}; Height = Nodes{NodeIndex, 4};
	Lines(end+1) = sprintf('<rect x="%g" y="%g" width="%g" height="%g" rx="6" fill="%s" stroke="#ffffff" stroke-width="2"/>', X, Y, Width, Height, Nodes{NodeIndex, 7});
	Lines(end+1) = sprintf('<text x="%g" y="%g" text-anchor="middle" class="label">%s</text>', X+Width/2, Y+34, Nodes{NodeIndex, 5});
	Lines(end+1) = sprintf('<text x="%g" y="%g" text-anchor="middle" class="count">%s</text>', X+Width/2, Y+62, Nodes{NodeIndex, 6});
end
Lines(end+1) = '<text x="310" y="570" class="count">Plastic E-to-E recurrent matrix and local inhibitory circuits</text>';
Lines(end+1) = '</svg>';
SvgPath = TransferLearning.StandardFigureSvgPath('English_Fig2G_ModelStructure.svg');
FileID = fopen(SvgPath, 'w', 'n', 'UTF-8');
assert(FileID >= 0, '无法写入模型结构SVG。');
FileCleanup = onCleanup(@()fclose(FileID));
fprintf(FileID, '%s\n', Lines);
clear FileCleanup;
assignin('base', 'Fig2G_ModelStructureParams', Params);
fprintf('已导出：%s\n', SvgPath);

function Hex = RgbHex(Color)
Hex = sprintf('#%02X%02X%02X', round(Color));
end