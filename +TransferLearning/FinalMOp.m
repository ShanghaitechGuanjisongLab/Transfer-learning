function [PcaLegend,NumMice]=FinalMOp(FigureFlag,PCs,PcaAx)
arguments
	FigureFlag
	PCs
	PcaAx={}
end
FullNewPca=isempty(PcaAx);
import TransferLearning.*
DataSet=FullCalcium;
switch bitand(FigureFlag,Flags.Paradigm)
	case Flags.LightAudio
		SheetName='光声最终MOp';
		SubTitles=["Learned light-water","Transfer audio-water","Final audio-water"];
	case Flags.AudioLight
		SheetName='声光最终MOp';
		SubTitles=["Learned audio-water","Transfer light-water","Final light-water"];
	otherwise
		Exception.Unsupported_paradigm.Throw;
end
GroupNtats=TransferLearning.NtatsFromSheetname(SheetName);
Layout=BasicHeatmap(2.^UniExp.HeatmapSort(GroupNtats,["Transfer","Final"]).NTATS{:,:,["Learned","Transfer","Final"]}-1,SubTitles,[0,0,1;1,0,0;0,0.681,0],false,CLim=[-2,2]);
NumMice=numel(unique(DataSet.Cells.Mouse(ismember(DataSet.Cells.CellUID,GroupNtats.CellUID))));
Target=Flags(bitand(FigureFlag,Flags.Target));
switch Target
	case Flags.Article
		MATLAB.Graphics.FigureAspectRatio(1,1,1);
	case Flags.PPT
		title(Layout,'Reinforced final network');
		MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
end
print(ProjectPath(sprintf('%s.热图.%s.svg',SheetName,Target)),'-dsvg');
[~,PcaScore]=UnifiedPcaModel(GroupNtats);
Explained=PcaScore.Explained(PCs);
if FullNewPca
	figure;
else
	PcaAx={PcaAx};
end
PcaLegend=legend(UniExp.SegmentFadePlot(table(permute(PcaScore.Score{PCs,:,["Learned","Transfer","Final"]},[3,1,2]),GlobalOptimization.ColorAllocate(3,[1,1,1;1,1,1]),'VariableNames',["Points","Color"]),table([24;32],('os')','VariableNames',["Index","Shape"]),PcaAx{:},PatchArguments={'LineWidth',2}),SubTitles,Interpreter='none');
UniExp.PcAxLabels(table(PCs',Explained,'VariableNames',["Index","Explained"],'RowNames',["X";"Y";"Z"]),PcaAx{:});
UniExp.PcaRotate(PcaAx{:},Explained);
if FullNewPca
	title('Reinforced final network ●0s(cue) ■1s(water)');
	MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
	print(ProjectPath(sprintf('%s.PCA.png',SheetName)),'-dpng','-r300');
end
end