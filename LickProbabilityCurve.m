%舔水概率分布图
%Written by 梁鸿淞
%依赖统一实验分析作图v17.1.0
%作图，舔水概率分布曲线。dataSet，queryTable如例。标准差阴影（stdShadow），全概率（fullProbability）可选。全概率为将时间窗口内舔水概率之和设为1。
function LickProbabilityCurve(dataSet,queryTable,searchName,stdShadow,fullProbability,xLabel,yLabel,picTitle)

arguments
    dataSet=UniExp.DataSet("\\Data-Server-1\个人数据\张天夫\202401\全钙大模型v3.mat");
    queryTable=UniExp.ReadQueryTable("\\Data-Server-1\个人数据\张天夫\202312\统一模型查询表.xlsx","皮层分开线图");
    searchName=[]
    stdShadow=false
    fullProbability=false
    xLabel='Time (s)'
    yLabel='Lick Probability'
    picTitle='Lick Probability Curve'
end

%筛选目标Block包含的所有Trial的CD2归一化数据
searchLogical=ismember(queryTable.GroupName,categorical(searchName));
searchTable=queryTable(searchLogical,:);
DataSetNew=dataSet.TableQuery(["Mouse","TrialUID","CellUID"],searchTable);
trialUIDData=[];
for i=1:numel(searchName)
    trialUIDDataSlip=DataSetNew.(searchName(i)).TrialUID;
    trialUIDData=cat(1,trialUIDData,trialUIDDataSlip);
end
trialUIDData=unique(trialUIDData);
trialTagData=dataSet.TableQuery(["Mouse","TrialUID","NormalizedTags"],TrialUID=trialUIDData);
searchNoTrial=cellfun(@(X)isequaln(X,missing)||isempty(X),trialTagData.NormalizedTags);
trialData=trialTagData(~searchNoTrial,:);
trialNumber=max(size(trialData));
boundsMat=zeros(trialNumber,2);
[boundsMat(:,1),boundsMat(:,2)]=cellfun(@(X)bounds(X.CD2),trialData.NormalizedTags);

%以所有Trial的最小值为BasePoint=0，最大值为CertainPoint=1，对CD2数据进行线性转化
basePoint=min(boundsMat(:,1));
certainPiont=max(boundsMat(:,2));
allData=zeros(121,trialNumber);
for i = 1:trialNumber
    cd12data=trialData.NormalizedTags{i,1};
    allData(:,i)=(cd12data.CD2(1:121)-basePoint)/(certainPiont-basePoint);
end
stdMat=std(allData,[],2);
meanMat=mean(allData,2);

%全概率
if fullProbability
    meanMat=meanMat./sum(meanMat);
end

%标准差阴影
if stdShadow
else
    stdMat=0;
end

%画图
figure;
import MATLAB.Graphics.MultiShadowedLines
MultiShadowedLines(meanMat,stdMat,X=((1:121)/8-3)');
xline(0,'--r');
xline(1,'--b');
xlabel(xLabel);
ylabel(yLabel);
title(picTitle);
end