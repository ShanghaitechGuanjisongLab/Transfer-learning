function LMHPersistency(Level,LevelString,PrintPath,ScaleColor)
arguments
	Level
	LevelString
	PrintPath
	ScaleColor=false;
end
outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
try
	pp = string(PrintPath);
	if ~(startsWith(pp, "\\\\") || startsWith(pp, "//"))
		[~, name, ~] = fileparts(pp);
		pp = fullfile(outDirUNC, name);
	end
	PrintPath = pp;
	parentDir = fileparts(pp);
	if strlength(parentDir) > 0 && ~isfolder(parentDir)
		mkdir(parentDir);
	end
catch
end
figure;
Colors=GlobalOptimization.ColorAllocate(3,[1,1,1]);
Layout1=tiledlayout(1,5,TileSpacing='tight',Padding='tight');
Level=sortrows(Level,["ZLayer","PeakTime"]);
Num2=sum(Level.ZLayer=="MOp2/3");
Num5=sum(Level.ZLayer=="MOp5")+Num2;
if ScaleColor
	ScaleColor={UniExp.Flags.ScaleColor};
else
	ScaleColor={};
end
[~,Axes]=UniExp.LanearHeatmap(Level.NTATS(:,:,["Naive_cue1_water","Learned4_cue1_water","Transfer_cue2_water","Final_cue1_water","Final_cue2_water"]),UniExp.Flags.HideYAxis,ScaleColor{:},ImagescStyle={'XData',[-3,12]},Layout=Layout1,SubTitles=["Naive_task_A","Learned_task_A","Transfer_task_B","Final_task_A","Final_task_B"],LMHColor=[Colors(2,:,:);1,1,1;Colors(1,:,:)]);
Y=1:numel(Level.PeakTime);
arrayfun(@(Ax)line(Ax,Level.PeakTime(1:Num2),Y(1:Num2),Color=Colors(3,:,:)),Axes);
arrayfun(@(Ax)line(Ax,Level.PeakTime(Num2+1:Num5),Y(Num2+1:Num5),Color=Colors(3,:,:)),Axes);
title(Layout1,sprintf('Persistency of %s activity in learned_task_A',LevelString),Interpreter='none');
xlabel(Layout1,'Time (s) from cue');
ylabel(Layout1,'Cell',Interpreter='none');
CB=colorbar;
CB.Layout.Tile='east';
CB.Label.String='ΔF/F_0';
CB.FontSize = 12;
CB.Label.FontSize = 12;
set(findall(gcf, '-property', 'FontSize'), 'FontSize', 12);
MATLAB.Graphics.FigureAspectRatio(2025,931,MATLAB.Flags.Narrow);
CB.TickLabels=MATLAB.SignificantFixedpoint(2.^str2double(CB.TickLabels)-1,2);
TransferLearning.PrintFigure(gcf, string(PrintPath) + ".png");
TransferLearning.PrintFigure(gcf, string(PrintPath) + ".svg");