function PcaLegend=TransferHitMiss(FigureFlag,PCs,PcaAx)
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
		SheetName='光声迁移命中错失';
		SubTitles=["Learned light-water","Transfer audio-water hit","Transfer audio-water miss"];
	case Flags.AudioLight
		SheetName='声光迁移命中错失';
		SubTitles=["Learned audio-water","Transfer light-water hit","Transfer light-water miss"];
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
[PcaCoeff,PcaScore]=UnifiedPcaModel(GroupNtats);
Explained=PcaScore.Explained(PCs);
if FullNewPca
	figure;
else
	PcaAx={PcaAx};
end
PcaLegend=legend(UniExp.SegmentFadePlot(table(permute(PcaScore.Score{PCs,:,["Learned","Transfer_hit","Transfer_miss"]},[3,1,2]),GlobalOptimization.ColorAllocate(3,[1,1,1;1,1,1]),'VariableNames',["Points","Color"]),table([24;32;48],('os^')','VariableNames',["Index","Shape"]),PcaAx{:},PatchArguments={'LineWidth',2}),SubTitles,Interpreter='none');
UniExp.PcAxLabels(table(PCs',Explained,'VariableNames',["Index","Explained"],'RowNames',["X";"Y";"Z"]),PcaAx{:});
UniExp.PcaRotate(PcaAx{:},Explained);
if FullNewPca
	title('Transfer hit & miss ●0s(cue) ■1s(water) ▲3s');
	MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
	print(ProjectPath(sprintf('%s.PCA.png',SheetName)),'-dpng','-r300');
end
figure;
[~,Index]=maxk(PcaCoeff.Coeff(:,2),uint8(height(PcaCoeff)/20),ComparisonMethod='abs');
[~,Index]=ismember(PcaCoeff.CellUID(Index),GroupNtats.CellUID);
GroupNtats=GroupNtats(Index,:);
NtatsData=UniExp.HeatmapSort(GroupNtats).NTATS{:,:,["Learned","Transfer_hit","Transfer_miss"]};
Layout=BasicHeatmap(2.^NtatsData-1,SubTitles,[0,0,1;1,0,0;0,0.681,0],false,CLim=[-2,2]);
Target=Flags(bitand(FigureFlag,Flags.Target));
if Target==Flags.PPT
	title(Layout,'Top 5% cells of PC2 |coeff|');
end
MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
print(ProjectPath(sprintf('%s.Top5.%s.svg',SheetName,Target)),'-dsvg');
[Mean,Sem]=MATLAB.DataFun.MeanSem(NtatsData,1);
Xs=linspace(-3,12,size(Mean,2))';
figure;
CurveLayout=tiledlayout(2,2,TileSpacing='tight',Padding='tight');
Axes=gobjects(3,1);
for A=1:3
	Axes(A)=nexttile;
	MATLAB.Graphics.MultiShadowedLines(2.^Mean(:,:,A)'-1,2.^Sem(:,:,A)'-1,X=Xs);
	CueLine=xline(0,':k');
	WaterLine=xline(1,'-k');
	title(SubTitles(A));
end
L=legend([CueLine,WaterLine],["Cue","Water"]);
L.Layout.Tile=4;
title(CurveLayout,'Top 5% cells of PC2 |coeff|');
ylabel(CurveLayout,'ΔF/F_0 ±SEM');
xlabel(CurveLayout,'Time (s) from cue');
MATLAB.Graphics.FigureAspectRatio(8,5,MATLAB.Flags.Narrow);
MATLAB.UnifyYLims(Axes);
print(TransferLearning.ProjectPath(sprintf('%s.线图.%s.svg',SheetName,Target)),'-dsvg');
end