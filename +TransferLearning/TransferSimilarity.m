function [PcaLegend,NumMice]=TransferSimilarity(FigureFlag,PCs,varargin)
PcaAx={};
HeatmapScale=MATLAB.Flags.Narrow;
for V=1:numel(varargin)
	Arg=varargin{V};
	if isa(Arg,'matlab.graphics.axis.Axes')
		PcaAx={Arg};
	else
		HeatmapScale=Arg;
	end
end
FullNewPca=isempty(PcaAx);
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
persistent NtatsDictionary
if isempty(NtatsDictionary)
	NtatsDictionary=dictionary;
end
try
	GroupNtats=NtatsDictionary{SheetName};
catch ME
	if any(ME.identifier==["MATLAB:dictionary:UnconfiguredLookupNotSupported","MATLAB:dictionary:ScalarKeyNotFound"])
		GroupNtats=DataSet.QueryNTATS(UniExp.ReadQueryTable(ProjectPath('查询表.xlsx'),SheetName),UniExp.Flags.log2FdF0,1:24,UniExp.Flags.Median);
		try
			GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);
		catch ME
			if ME.identifier~="UniExp:Exceptions:No_need_to_replenish"
				ME.rethrow;
			end
		end
		NtatsDictionary{SheetName}=GroupNtats;
	else
		ME.rethrow;
	end
end
Layout=BasicHeatmap(2.^UniExp.HeatmapSort(GroupNtats,["Naive","Learned"]).NTATS{:,:,GroupOrder}-1,SubTitles,[0,0,1;1,0,0;0,0.681,0],false,CLim=[-2,2]);
NumMice=numel(unique(DataSet.Cells.Mouse(ismember(DataSet.Cells.CellUID,GroupNtats.CellUID))));
Target=Flags(bitand(FigureFlag,Flags.Target));
switch Target
	case Flags.Article
		MATLAB.Graphics.FigureAspectRatio(1,2,HeatmapScale);
	case Flags.PPT
		title(Layout,Title);
		MATLAB.Graphics.FigureAspectRatio(8,5,HeatmapScale);
end
print(ProjectPath(sprintf('%s.热图.%s.svg',SheetName,Target)),'-dsvg');
[~,PcaScore]=UnifiedPcaModel(GroupNtats);
Explained=PcaScore.Explained(PCs);
if FullNewPca
	figure;
end
PcaLegend=legend(UniExp.SegmentFadePlot(table(permute(PcaScore.Score{PCs,:,["Naive","Learned","Transfer"]},[3,1,2]),GlobalOptimization.ColorAllocate(3,[1,1,1;1,1,1]),'VariableNames',["Points","Color"]),table([24;32;48],('os^')','VariableNames',["Index","Shape"]),PcaAx{:},PatchArguments={'LineWidth',2}),Legends,Interpreter='none');
UniExp.PcAxLabels(table(PCs',Explained,'VariableNames',["Index","Explained"],'RowNames',["X";"Y";"Z"]),PcaAx{:});
UniExp.PcaRotate(PcaAx{:},Explained);
if FullNewPca
	title('●0s(cue) ■1s(water) ▲3s');
	MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
	print(ProjectPath(sprintf('%s.PCA.png',SheetName)),'-dpng','-r300');
end
end