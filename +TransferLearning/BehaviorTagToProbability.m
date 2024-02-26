function [Mean,Sem] = BehaviorTagToProbability(Table,Min,Max)
[Mean,Sem]=MATLAB.DataFun.MeanSem(splitapply(@(T)mean(T,1),Table.NormalizedTags,findgroups(Table.Mouse)),1);
Delta=Max-Min;
Mean=(Mean-Min)/Delta;
Sem=Sem/Delta;