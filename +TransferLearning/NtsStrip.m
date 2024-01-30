function [NtsTable,CellMedianPeakTime] = NtsStrip(NtsTable,ValidCells)
NtsTable=NtsTable(ismember(NtsTable.CellUID,ValidCells)&NtsTable.TrialRI<=20,:);
[~,NtsTable.PeakTime]=max(NtsTable.TrialSignal,[],2);
NtsTable.PeakTime=NtsTable.PeakTime/8-3;
NtsTable=NtsTable(:,["CellUID","PeakTime"]);
CellMedianPeakTime=groupsummary(NtsTable,"CellUID",'median',"PeakTime");