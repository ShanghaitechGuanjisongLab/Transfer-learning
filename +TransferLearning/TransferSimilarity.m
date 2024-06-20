function [PcaLegend,NumMice]=TransferSimilarity(FigureFlag,PCs,options)
arguments
	FigureFlag
	PCs
	options.PcaAx
	options.HeatmapScale=MATLAB.Flags.Narrow
end
if isfield(options,'PcaAx')
	PcaAx={options.PcaAx};
else
	PcaAx={};
end
if isfield(options,'CorrelationAx')
	CorrelationAx={options.CorrelationAx};
else
	CorrelationAx={};
end
import TransferLearning.*
DataSet=FullCalcium;
switch bitand(FigureFlag,Flags.Paradigm)
	case Flags.LightAudio
		SheetName='光声迁移MOp';
		Title='Similar activity in MOp learned & transfer';
		SubTitles=["Naive light-water","Learned light-water","Transfer audio-water"];
		Legends=SubTitles;
		GroupOrder=["Naive","Learned","Transfer"];
	case Flags.AudioLight
		switch bitand(FigureFlag,Flags.BrainRegion)
			case Flags.MOp
				SheetName='声光迁移MOp';
				Title='Similar activity in MOp learned & transfer';
			case Flags.RSPd
				SheetName='声光迁移RSPd';
				Title='Non-similar RSPd activity';
			otherwise
				Exception.Unrecorded_brain_region.Throw;
		end
		SubTitles=["Naive audio-water","Learned audio-water","Transfer light-water","Naive audio-water first 10"];
		Legends=["Naive audio-water","Learned audio-water","Transfer light-water"];
		GroupOrder=["Naive","Learned","Transfer","Naive10"];
		%Naive10放在最后保证前三种颜色一致
	otherwise
		Exception.Unsupported_paradigm.Throw;
end
GroupNtats=NtatsFromSheetname(SheetName);
Layout=BasicHeatmap(2.^UniExp.HeatmapSort(GroupNtats,["Naive","Learned"]).NTATS{:,:,GroupOrder}-1,SubTitles,[0,0,1;1,0,0;0,0.681,0],false,CLim=[-2,2]);
NumMice=numel(unique(DataSet.Cells.Mouse(ismember(DataSet.Cells.CellUID,GroupNtats.CellUID))));
Target=Flags(bitand(FigureFlag,Flags.Target));
switch Target
	case Flags.Article
		MATLAB.Graphics.FigureAspectRatio(1,2,options.HeatmapScale);
	case Flags.PPT
		title(Layout,Title);
		MATLAB.Graphics.FigureAspectRatio(8,5,options.HeatmapScale);
end
print(ProjectPath(sprintf('%s.热图.%s.svg',SheetName,Target)),'-dsvg');
[~,PcaScore]=UnifiedPcaModel(GroupNtats);
Explained=PcaScore.Explained(PCs);
FullNew=isempty(PcaAx);
if FullNew
	figure;
end
PcaLegend=legend(UniExp.SegmentFadePlot(table(permute(PcaScore.Score{PCs,:,["Naive","Learned","Transfer"]},[3,1,2]),GlobalOptimization.ColorAllocate(3,[1,1,1;1,1,1]),'VariableNames',["Points","Color"]),table([24;32],('os')','VariableNames',["Index","Shape"]),PcaAx{:},PatchArguments={'LineWidth',2}),Legends,Interpreter='none');
UniExp.PcAxLabels(table(PCs',Explained,'VariableNames',["Index","Explained"],'RowNames',["X";"Y";"Z"]),PcaAx{:});
UniExp.PcaRotate(PcaAx{:},Explained);
if FullNew
	title('●0s(cue) ■1s(water)');
	MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
	print(ProjectPath(sprintf('%s.PCA.png',SheetName)),'-dpng','-r300');
end