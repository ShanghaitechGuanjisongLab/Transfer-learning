MB=TransferLearning.MOpBaseline; %[output:6275bb82] %[output:40fea16a] %[output:1f58df22] %[output:9638be48] %[output:32e62f35] %[output:3a4c0668] %[output:07c437ed] %[output:9e64f5a3] %[output:096d4e25] %[output:677d38f9] %[output:757a9b53] %[output:1763956b] %[output:863610e4] %[output:96b8958a] %[output:65cad5c4] %[output:98704a38] %[output:2510da82] %[output:3b13d037] %[output:17d1e92e] %[output:137efdca] %[output:633eef18] %[output:37ee971f] %[output:1f5982ba] %[output:7dab99fc] %[output:56c8e95a] %[output:9153c7bc] %[output:42ffedea] %[output:112a1f39] %[output:9a78d1ac] %[output:13fb07af] %[output:797690bb] %[output:413e6966] %[output:3863c130] %[output:7e555ffd] %[output:64a78960] %[output:231e7289] %[output:7de75c8f] %[output:1f05828f] %[output:0efaa7b0] %[output:51b2d8d8] %[output:11dab547] %[output:952999ab] %[output:610b30c8] %[output:52dc5091] %[output:7ea85267] %[output:3f5e8f01] %[output:201a1c8a] %[output:5236a96a] %[output:1efc0fd8] %[output:050bcb77] %[output:33fa6d90] %[output:5e56fba6] %[output:664ef418] %[output:5f402d2b] %[output:25c075f8] %[output:8af30f11] %[output:0a2d3cae] %[output:53d99ea6] %[output:74e83fe9] %[output:30c744bb] %[output:16e33913] %[output:79348548] %[output:6d43a117] %[output:2cb73d7f] %[output:9d0e034f] %[output:9569d620] %[output:947454a0] %[output:0b68a264] %[output:50c458db] %[output:5bd0becb] %[output:7c04342e] %[output:2aac026c] %[output:61f64123] %[output:480f21e8] %[output:57d4cabf] %[output:2cd14c53] %[output:9db30031] %[output:23410af3] %[output:82b6535f] %[output:554c36a9] %[output:383605b9] %[output:3695d8cd] %[output:19f782c8] %[output:3217e649] %[output:0ab1d240] %[output:2735fbb6] %[output:23b48b5d] %[output:828ea01d] %[output:047f0880] %[output:07fda7e1] %[output:65a282db] %[output:9b34906c] %[output:8758dfbe] %[output:7ad11bd8] %[output:41256114] %[output:796e5f3d] %[output:04dd6082] %[output:2487a3ca] %[output:97384d38] %[output:294906b9] %[output:2e5881ee] %[output:0935cf4c] %[output:058eea20] %[output:3af46b34] %[output:8701125b] %[output:6a2eaeef] %[output:1fb61af9] %[output:4fc5cbae] %[output:851e508e] %[output:0ef349e9]
%%
V7=TransferLearning.Vacation7;
%%
V7GroupNtats=MB.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('尝试查询表.xlsx'),"CellReuse.V7"),UniExp.Flags.ZScore,1:24,UniExp.Flags.Median);
for P=["NaiveLight","LearnedLight","LearnedAudio","TransferLight","FinalLight"]
    Table=GroupNtats.(P);
    Table.CueResponsor=max(Table.NTATS(:,25:32),[],2)>std(Table.NTATS(:,1:24),[],2)*3;
    Table.WaterResponsor=max(Table.NTATS(:,33:end),[],2)>std(Table.NTATS(:,1:32),[],2)*3;
    Table.Phase(:)=P;
    GroupNtats.(P)=Table;
end
GroupNtats=[GroupNtats.NaiveLight;GroupNtats.LearnedLight;GroupNtats.LearnedAudio;GroupNtats.TransferLight;GroupNtats.FinalLight];
[~,Index]=ismember(GroupNtats.CellUID,MB.Cells.CellUID);
GroupNtats(:,["ZLayer","Mouse"])=MB.Cells(Index,["ZLayer","Mouse"]);
%%
GroupNtats=MB.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('尝试查询表.xlsx'),"LearnerMentor"),UniExp.Flags.ZScore,1:24,UniExp.Flags.Median); %[output:5a8831cf]
for P=["NaiveLight","LearnedLight","LearnedAudio","TransferLight","FinalLight"]
    Table=GroupNtats.(P);
    Table.CueResponsor=max(Table.NTATS(:,25:32),[],2)>std(Table.NTATS(:,1:24),[],2)*3;
    Table.WaterResponsor=max(Table.NTATS(:,33:end),[],2)>std(Table.NTATS(:,1:32),[],2)*3;
    Table.Phase(:)=P;
    GroupNtats.(P)=Table;
end
GroupNtats=[GroupNtats.NaiveLight;GroupNtats.LearnedLight;GroupNtats.LearnedAudio;GroupNtats.TransferLight;GroupNtats.FinalLight];
[~,Index]=ismember(GroupNtats.CellUID,MB.Cells.CellUID);
GroupNtats(:,["ZLayer","Mouse"])=MB.Cells(Index,["ZLayer","Mouse"]);
%%
% [NaiveLearnedActive,NaveLearnedRate]=ActiveSplit(GroupNtats,"NaiveLight","LearnedLight");
%%
[TransferLearnedActiveMeanLine,TransferLearnedRate,TransferLearnedActive]=ActiveSplit(GroupNtats,"TransferLight","LearnedAudio","CueResponsor");
%%

%%
TransferPerformance=MB.TableQuery(["Mouse","Performance"],Design="LightWater",Phase="Transfer",Paradigm="声光无穿插");
%%
NaivePerformance=MB.TableQuery(["Mouse","Performance","Design"],Phase="Naive",Paradigm="光声无穿插");
%%
[LearnedTransferOr,LTOverallOr]=OverlapRate(GroupNtats,"LearnedAudio","TransferLight","CueResponsor");
LearnedTransferOr.Phase(:)="LT";
[NaiveLearnedOr,NLOverallOr]=OverlapRate(GroupNtats,"NaiveLight","LearnedLight","CueResponsor");
NaiveLearnedOr.Phase(:)="NL";
AnovaTable=[NaiveLearnedOr;LearnedTransferOr];
OrComparison=UniExp.TabularAnovaN("OverlapRate",AnovaTable(:,["ZLayer","Phase","OverlapRate"]),Model=array2table([true,true],VariableNames=["ZLayer","Phase"]),Comparison=table(["MOp2/3","MOp2/3";"MOp5","MOp5"],["NL","LT";"NL","LT"],'VariableNames',["ZLayer","Phase"])); %[output:128efadc] %[output:34c5ffb6] %[output:43c2f191]
%%
L2=TransferLearnedActive(TransferLearnedActive.ZLayer=="MOp2/3",["Active","PeakValue"]);
%%
TransferLearnedActiveMeanLine.fun1_NTATS
Axes=gobjects(2,2);
%%
Fig=figure;
Layout=tiledlayout(2,2,TileSpacing='tight',Padding='tight');
Axes(1,1)=nexttile;
%%
RSPd=TransferLearning.RSPd; %[output:4b39deef] %[output:0f39152d] %[output:87d1d499]
RSPdGroupNtats=RSPd.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('尝试查询表.xlsx'),"CellReuse.RSPd"),UniExp.Flags.ZScore,1:24,UniExp.Flags.Median);
%%
RSPdGroupNtats.CueResponsor=max(RSPdGroupNtats.NTATS(:,25:32,:),[],2)>std(RSPdGroupNtats.NTATS(:,1:24,:),[],2).*3;
[~,Index]=ismember(RSPdGroupNtats.CellUID,RSPd.Cells.CellUID);
RSPdGroupNtats(:,["ZLayer","Mouse"])=RSPd.Cells(Index,["ZLayer","Mouse"]);
%%
nnz(all(RSPdGroupNtats.CueResponsor.Data,3))./nnz(any(RSPdGroupNtats.CueResponsor.Data,3)) %[output:9387cf6c]
%%
RSPdOverlapRate=groupsummary(RSPdGroupNtats,["Mouse","ZLayer"],@(D)nnz(all(D.Data,3))./nnz(any(D.Data,3)),"CueResponsor");
%%
RSPdPerformance=RSPd.TableQuery(["Mouse","Performance"],Phase="Transfer",Design="LightWater");
%%
RSPdOverlapPerformance=innerjoin(RSPdOverlapRate,RSPdPerformance,Keys="Mouse");
%%
function [MeanLines,SplitRate,NtatsToShow]=ActiveSplit(GroupNtats,ShowPhase,SplitPhase,ActiveColumn)
NtatsToShow=table;
ShowPhase=GroupNtats(GroupNtats.Phase==ShowPhase & GroupNtats.(ActiveColumn),["CellUID","NTATS","ZLayer"]);
SplitPhase=GroupNtats(GroupNtats.Phase==SplitPhase,["CellUID",ActiveColumn]);
NtatsToShow.CellUID=intersect(ShowPhase.CellUID,SplitPhase.CellUID);
[~,Index]=ismember(NtatsToShow.CellUID,ShowPhase.CellUID);
NtatsToShow(:,["NTATS","ZLayer"])=ShowPhase(Index,["NTATS","ZLayer"]);
[~,Index]=ismember(NtatsToShow.CellUID,SplitPhase.CellUID);
NtatsToShow.(ActiveColumn)=SplitPhase.(ActiveColumn)(Index);
SplitRate=groupsummary(NtatsToShow,"ZLayer",'mean',ActiveColumn);
NtatsToShow.PeakValue=max(NtatsToShow.NTATS,[],2);
MeanLines=groupsummary(NtatsToShow,[ActiveColumn,"ZLayer"],@TransferLearning.MeanSem1,"NTATS");
end
function [MouseOr,OverallOr]=OverlapRate(GroupNtats,PhaseA,PhaseB,ActiveColumn)
PhaseA=GroupNtats(GroupNtats.Phase==PhaseA&GroupNtats.(ActiveColumn),["CellUID","ZLayer","Mouse"]);
PhaseB=GroupNtats(GroupNtats.Phase==PhaseB&GroupNtats.(ActiveColumn),["CellUID","ZLayer","Mouse"]);
OverallOr=numel(intersect(PhaseA.CellUID,PhaseB.CellUID))/numel(union(PhaseA.CellUID,PhaseB.CellUID));
PhaseA=groupsummary(PhaseA,["ZLayer","Mouse"],@(C){C},"CellUID");
PhaseB=groupsummary(PhaseB,["ZLayer","Mouse"],@(C){C},"CellUID");
MouseOr=innerjoin(PhaseA,PhaseB,Keys=["ZLayer","Mouse"]);
MouseOr.OverlapRate=cellfun(@(A,B)numel(intersect(A,B))/numel(union(A,B)),MouseOr.fun1_CellUID_PhaseA,MouseOr.fun1_CellUID_PhaseB);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:6275bb82]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：3"}}
%---
%[output:40fea16a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：4"}}
%---
%[output:1f58df22]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：5"}}
%---
%[output:9638be48]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：6"}}
%---
%[output:32e62f35]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：7"}}
%---
%[output:3a4c0668]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：8"}}
%---
%[output:07c437ed]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：9"}}
%---
%[output:9e64f5a3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：10"}}
%---
%[output:096d4e25]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：11"}}
%---
%[output:677d38f9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：12"}}
%---
%[output:757a9b53]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：13"}}
%---
%[output:1763956b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：16"}}
%---
%[output:863610e4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：132"}}
%---
%[output:96b8958a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：133"}}
%---
%[output:65cad5c4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：134"}}
%---
%[output:98704a38]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：135"}}
%---
%[output:2510da82]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：136"}}
%---
%[output:3b13d037]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：137"}}
%---
%[output:17d1e92e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：138"}}
%---
%[output:137efdca]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：139"}}
%---
%[output:633eef18]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 142"}}
%---
%[output:37ee971f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：144"}}
%---
%[output:1f5982ba]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：145"}}
%---
%[output:7dab99fc]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：146"}}
%---
%[output:56c8e95a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：147"}}
%---
%[output:9153c7bc]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：150"}}
%---
%[output:42ffedea]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 152"}}
%---
%[output:112a1f39]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 19"}}
%---
%[output:9a78d1ac]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：22"}}
%---
%[output:13fb07af]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：23"}}
%---
%[output:797690bb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：118"}}
%---
%[output:413e6966]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：24"}}
%---
%[output:3863c130]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：25"}}
%---
%[output:7e555ffd]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：119"}}
%---
%[output:64a78960]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：26"}}
%---
%[output:231e7289]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：27"}}
%---
%[output:7de75c8f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：28"}}
%---
%[output:1f05828f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：120"}}
%---
%[output:0efaa7b0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：31"}}
%---
%[output:51b2d8d8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：32"}}
%---
%[output:11dab547]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：100"}}
%---
%[output:952999ab]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：121"}}
%---
%[output:610b30c8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：33"}}
%---
%[output:52dc5091]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：34"}}
%---
%[output:7ea85267]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：101"}}
%---
%[output:3f5e8f01]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：122"}}
%---
%[output:201a1c8a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：102"}}
%---
%[output:5236a96a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：123"}}
%---
%[output:1efc0fd8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：124"}}
%---
%[output:050bcb77]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：103"}}
%---
%[output:33fa6d90]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：125"}}
%---
%[output:5e56fba6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：126"}}
%---
%[output:664ef418]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：104"}}
%---
%[output:5f402d2b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：39"}}
%---
%[output:25c075f8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：40"}}
%---
%[output:8af30f11]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：43"}}
%---
%[output:0a2d3cae]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：44"}}
%---
%[output:53d99ea6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：45"}}
%---
%[output:74e83fe9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：46"}}
%---
%[output:30c744bb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：113"}}
%---
%[output:16e33913]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：114"}}
%---
%[output:79348548]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：115"}}
%---
%[output:6d43a117]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：116"}}
%---
%[output:2cb73d7f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：117"}}
%---
%[output:9d0e034f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：110"}}
%---
%[output:9569d620]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：111"}}
%---
%[output:947454a0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：112"}}
%---
%[output:0b68a264]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：105"}}
%---
%[output:50c458db]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：106"}}
%---
%[output:5bd0becb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：107"}}
%---
%[output:7c04342e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：108"}}
%---
%[output:2aac026c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：109"}}
%---
%[output:61f64123]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 66"}}
%---
%[output:480f21e8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：168：最后一回合没拍到"}}
%---
%[output:57d4cabf]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 168"}}
%---
%[output:2cd14c53]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：240：CD1没记到"}}
%---
%[output:9db30031]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 240"}}
%---
%[output:23410af3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：241：CD1没记到"}}
%---
%[output:82b6535f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 241"}}
%---
%[output:554c36a9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：242：CD1没记到"}}
%---
%[output:383605b9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 242"}}
%---
%[output:3695d8cd]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：243：CD1没记到"}}
%---
%[output:19f782c8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 243"}}
%---
%[output:3217e649]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：262：水滴漏了，没有拍到"}}
%---
%[output:0ab1d240]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：262"}}
%---
%[output:2735fbb6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 203"}}
%---
%[output:23b48b5d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 269"}}
%---
%[output:828ea01d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 270"}}
%---
%[output:047f0880]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 271"}}
%---
%[output:07fda7e1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 274"}}
%---
%[output:65a282db]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 275"}}
%---
%[output:9b34906c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 204"}}
%---
%[output:8758dfbe]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 276"}}
%---
%[output:7ad11bd8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 205"}}
%---
%[output:41256114]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 278"}}
%---
%[output:796e5f3d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 279"}}
%---
%[output:04dd6082]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 280"}}
%---
%[output:2487a3ca]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 206"}}
%---
%[output:97384d38]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 281"}}
%---
%[output:294906b9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 282"}}
%---
%[output:2e5881ee]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 283"}}
%---
%[output:0935cf4c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 284"}}
%---
%[output:058eea20]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：129：2次中断拍摄，无法对齐回合"}}
%---
%[output:3af46b34]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 129"}}
%---
%[output:8701125b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：209：中断两次，行为和钙对不上"}}
%---
%[output:6a2eaeef]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 209"}}
%---
%[output:1fb61af9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：299：中断两次，行为和钙对不上"}}
%---
%[output:4fc5cbae]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：215：拍错Z层，舍弃信号"}}
%---
%[output:851e508e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 215"}}
%---
%[output:0ef349e9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Blocks_of_different_Trial_splitting_methods：Block 3 4 5 6 7 8 9 10 11 12 13 22 23 24 25 26 27 28 31 33 34 39 46 100 101 102 103 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 129 132 133 134 135 136 137 138 139 144 145 146 147 168 262 将被忽略"}}
%---
%[output:5a8831cf]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Numbers_of_cells_differ_among_groups：\n每组的细胞数不同，不同组之间可能不具有可比性，请确认筛选条件正确？分别有 4901(FinalLight) 4902(LearnedAudio) 2706(LearnedLight) 2706(NaiveLight) 4900(TransferLight) 个细胞\n使用<a href=\"matlab:groupsummary(DataSet.Cells,'Mouse')\">groupsummary(DataSet.Cells,'Mouse')<\/a>查看每只鼠的细胞数"}}
%---
%[output:128efadc]
%   data: {"dataType":"warning","outputData":{"text":"警告: 分组变量 1 有缺失的类别。如果您要忽略数据中不存在的类别，请考虑使用 droplevels。"}}
%---
%[output:34c5ffb6]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAjAAAADCCAIAAADYVm8DAAAAB3RJTUUH6QkVCxoZT1uYzAAAIABJREFUeJzt3XtYE+eeB\/AXCJfhpkQugiKXWMVDEC0n1dpKPfpURdxmN+I5ovYo9JTKWh\/7gC36SF1PF1bpU9Ntu2ys9oBVvGyLqVlFvBytRaviVD3I4AWJogiIxYlyG8BI9o\/36WxOuJyoaEf9fv5KJpPJO28m83svk984tLa2EgAAgF+b469dAAAAAEIQkAAAQCIQkOB51N7e\/sMPP2zZssVsNvexWldXV2VlZVVVlfXC06dP\/\/DDD3fu3OnxLW1tbY2NjV1dXfSpxWJpbGxsb2\/vvmZLS8vmzZt37drV2dnZ\/dXbt283Nzfbuz8AzwQEJHgeNTU1\/fd\/\/7dOp6uoqOhjNaPRmJaWtmzZsuvXr9Mlzc3NX3\/99dKlS8+cOWOxWLq\/5ciRI5MmTVq+fLkgCF1dXXl5eZMmTSoqKuq+cmdnZ3Fx8YkTJ+7fv0+XmM3m69ev79y5c8GCBa+99tqSJUvq6+v7Y3cBng6yX7sAAL8CPz+\/N954Izc39+rVq9HR0d1XOH369IkTJywWi5eXV3l5+ccffxwREUEIqa+vP3z4cGhoaFlZ2fnz519++eWYmBjxXXfu3Pnuu+9kMll8fDzDMISQ119\/fffu3fn5+WPHjg0PD++jSGfPnn3rrbdob0kmk7300kv\/\/M\/\/TDcC8JxAQIJnn9FoTE1Nraur6\/5SZmZmZmam+DQoKEin0ykUimvXrq1fv15cfuTIkSNHjohPq6ur\/\/KXv9D1xYBksViKiopOnDgxefLkF198kS4MDg5+8803\/+3f\/m3jxo2ZmZkeHh6EELPZ3NLS0tTUdP\/+\/c7Ozjt37nR0dHR2dnZ2dv7+97\/XaDQKhQKhCJ5DCEjw7JPJZKGhoYMGDSKEdHR0XLlyxdHRMTw83NnZ2WZNLy8vmUxGCImLi5s0aZK4\/MyZM++9997s2bMXL17s6Pj\/A93WYePkyZO5ubne3t5vvfWWl5cXXejg4DB9+vSTJ0\/u3r17yJAhixYtkslk165dEwPk+fPnDx48GBUVtXDhQkKIUqlUKpWPpxoApA4BCZ59ISEhGzZsoI9pb2nQoEG5ublyuby3tzAMo9Pp8vLyrBd+++233377rfg0OTk5LS2NPr506VJ2dnZTU9OKFStGjx5t\/S4PD4+UlJQLFy589dVXTk5Ob7\/9tpeX1+zZs6urqw0Gw\/DhwydNmiSXy11dXQkhgiDwPG9TEvSW4DmBgATPl66urq6uLk9Pz+6nfplM5uXl5eDgQJ+OHj160aJFhJA7d+7s3r3b3d09Pj7ezc1NXJ\/OKhFCKioq0tLSamtrZTLZzp079+zZ0\/1zm5ubzWbzli1bXnrppZiYmLfffnvLli0Gg8HLy2vu3Ln+\/v4syxJC1qxZs2bNGus3fvTRRxqNpl\/rAECiEJDg+XLnzp2bN2\/evHlz2rRpNi8tXLgwPT2dEHLr1i2DwdDR0UGXC4LQ2toaGBhIR\/NEFy9evHr1qlqt\/s1vfrN48eJDhw61tbWdOHGix88dPHjwvHnzYmNj6fRSS0vLqVOnCCFnz5799NNPxXmsSZMmRUREXLx4kV6tFxERERIS0q8VACBdCEjwfKEXUtNzvfVCg8Hg6OhIu0fNzc3ffvutzUUQVVVVNn9IIoQEBQVNnjzZ39\/\/n\/7pn2bMmNHW1mY2m+mE07x589555x1CSEtLy4cffmgymd58882hQ4fSN16+fJkGJDc3t+Li4t\/+9re+vr6EkAULFqhUKr1ef+TIkcmTJ6NvBM8VBCR4jpjNZo7jCCGzZ89+7bXXxOU\/\/PCDwWDw8\/OjT0NCQr755hs6uPfll19u37597ty5KSkp1pczUI6Ojp6enoQQBwcHmUzm7e1Nfol5kZGR4hxVZ2enh4eHu7u7+FSv10dGRt66dWv48OFeXl6Ojo63b99+vDsPIHkISPAcqaurO378eHh4uEKhsF5OgwG9JpsQIpPJBg4caLFYdu3aRa9i2LZt27Zt22y2FhUVlZubazOOd+fOnSNHjvj5+Y0cObK3Ypw4cWL37t1paWnFxcWurq6pqak+Pj5btmwZPHjwwIED+2VPAZ5GyNQAzwuz2azX66urqydOnDh48GDrl6qrqwkhwcHB4pLOzs7t27f\/+c9\/dnd3j4uLi4qKioqKGjJkCCFkyJAh4lObPpPFYjl06FBpaemrr74aFhZGFzY1Nd25c8fX19fFxYUucXFxeeWVV2JjY+lTHx8fJyen2traAQMG0D4WwPMJPSR4LnR1dRkMhk2bNoWGhs6aNcu6W9PS0nL16lXr3kldXd3atWsPHz7s7e2dlZX1u9\/9js4t6fX6VatWvfPOOz1O7dCBuI8\/\/tjPzy8xMVEMP01NTTzPe3p6in97iomJCQ0Npdd5UyaTieO44cOHIyDB8wwBCZ59bW1t69ev37x5s7u7+7vvvhseHn7\/\/v1jx46Vl5cTQm7dunX06FGVShUQEEDXd3Z2bmpqGj58uL+\/\/8aNGzdu3EiX08vEv\/zyS\/HfSF5eXitXrgwMDDx+\/PiXX35ZXl7u7e394Ycfjho1qr6+fvfu3Z2dnWfOnGltbQ0LCxMjkIuLS2BgoPVF56dPn7506VJCQgL+cgTPMwQkePaZzeaff\/55wIABy5cvp1d7Ozk5+fv7f\/vtt3T2aNCgQcnJyWLvxM\/PT6vVurm5rV+\/3ua\/sYSQ2tra2tpa+jgoKMhsNjs7O5tMpgsXLsTExHzwwQeRkZGEkIEDBxqNxqKiIkLI8OHDJ0+e3Fvx2tvbz58\/Hx4e\/sorrzyGvQd4ajjgjrHwPGhsbLx3715gYKC4hCaUo\/eJePRsCJ2dnTU1NWFhYdazSi0tLZ2dnfRKPJtrH+hbysvLXV1dIyIinJyc7t69O2DAADo2eOPGjevXrw8bNky8TBzgeYCABAAAkoCr7AAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBLsDUhGo3Hq1KlKpTIjI2Pr1q2PtUxPo\/6tH61Wq1Qqp06dqtVqjUZjv5TQHjzPJyYm6vX6f1g2pVKp1Wr78aP1ev3UqVPFndVqtdZP+\/FTxMLTO7Q+eWIFUhkZGYIgPNZPFA9OelDZWauCIGRkZNjzLVtvn\/q16haednalDhIEwWAw7NixQy6X03zJj7lUT5n+rR+WZUNDQzmO43l+5cqV\/VRGu8jl8qysrO63oRPxPB8QEEBvKdS\/4uLiSktLDQZDWlqa0WhsaGjIzs62uUnEIzIajY2NjRzHCYKwevXqftzyA0lNTfX39581axbDMDzPb9q06XF\/okKhyM7OJoSoVCr6iampqf8wMwXDMBkZGcXFxTbL6RGelpbW4\/bpCv28A\/DceOAhO41GQ49F2oASG0Ri45ouT0xM5HlefLx\/\/36lUkkXEqtGYkFBwf79+8nfN137fSefJFo\/tM0oVktGRsaxY8emTp2amJgo1sY\/\/N3K5XKdTkdPymL9FBQU0C33b7HF7fd2B25CCMuysbGxa9aseaCGtv0CAgL8\/f2NRuPJkyfFzG8sy9r0JGiVWpdBq9WmpqampqZaH2N9YBgmJyeHnj3F7W\/YsOEf9g77kSAIBQUFDMOkpaU9yYSqcrk8ICDAZDL1\/cMU66G1tZX+zMV1NBpNaGhojz9VlmVZltVoNLRuAR6UXQGJYRi1Wj1nzhzr84JOp0tISOA4jmXZffv2mUymrKwsDw8P+mufOXMmsfrlHz58mGXZ7du3y+VysQfAsmx5eXlrayvLstXV1RzHcRwXGhr61PX3u9eP2GaUy+V5eXlRUVExMTGLFi2aPXt2VlbWqVOnSkpK2traehyrUalU1dXV1kMfYv3QGlu0aFH\/\/uBttt9bNimVSlVSUrJixQqO4w4cONC\/3RdqwoQJhw4d8vX1pfdaNRqN+\/btY1mW47iEhASxtZ6dnc1xnE6no5251NRUb2\/v5ORkjuNoa6DHjSsUCl9fX+sTrvX2W1paVCrVk7lleHl5eWxsLM01\/oQJgmCxWHx8fLr\/MPV6Pf1hchxXXV1Nj73vv\/+e\/syzsrJyc3PpEavRaOhP1TosJSUlJSUlPfk9gmeJvT0khUJx4MABel7Q6XS0raRUKgkhDMNMnz69j2ZpQEBARkaG2AzkeT46Opr8Eq40Gk1NTU1eXh49U6xatero0aOPultPnE399LiOh4cH3fGXXnqp70ZxWlqaGOmNRiPP82q1mhDCMExKSop4Y9P+8ri3b7+BAwd6eHiI4Zbn+f\/5n\/9RqVRKpTIpKam0tFQQBJPJtGjRIqVSqVarxdgZFRVFj8a+0TOpeMLleX769On0u1i4cKF4+4nHLSoqqqSkJCoq6sl8HJWUlKRUKlUq1ciRI+kuW\/8wBUGorq6eNGkSXVmtVtNf9MyZM+nXoVAowsPDxSYUHbijLQC6JD8\/Pz8\/\/0nuETx77ApIRqNxw4YN9LFcLo+MjKQdf\/Ho5HmeNmnF9Y8dO9bb1uRyeVlZmfWS6OjodevWcb+wHp5+KnSvH+tXOY57oLbwhg0baBufYZjw8HAfHx+5XG4wGOirBoOh3\/PhPu7tP5B58+aJx5JCoaAdMionJ4dhmJMnT+7YsYPjOIPB8ECxU6\/Xi51vegzL5fJ9+\/bRw\/jIkSMNDQ39vju9YRhm\/vz5T3KwLj8\/n1Zjj91rhmEiIyNNJhN9Kv6ijx07Ro9Go9F45coVhmHosJ7NNBKlUqkwWAePwt4eUmFhIe3BZGZm0mNu\/PjxdJBKqVRWVFQoFIqgoKDDhw\/Tdby9vXNycurq6hITE9esWRMbGysOQFkPSdHBE4VCUVFRYb3kMe7x49G9fhQKBf3p5uXlNTU1rVq1Kj09PTMzk+f5devW0cGx7jPGhJCWlha1Wk23xjCMXC5XqVR0eESpVLa2topnYTpT9eizbjbbX79+Pf2m6MSSeBK3nkOynqqxWe3hFBcX5+XlLV68mOd5lmWTkpJWrlxpMpkYhhEPDLqnI0aMoIeTWq1OT09nWba4uHjt2rW0467ValeuXNnbqB3tJYhHrEKhmD59Ou2BlZaWij2k\/qrYHul0urVr16pUqidwfR1FqyUpKUmcdaPzcN1\/mJmZmbR+CgsLFQpFTk6Ot7c3XZiZmbl48WI66WXTajQajStXrqR1+9SNt4Ok4PYTTxmj0VhVVUXvMgf9iOf54uLiefPm\/doFAXh+4Y6xTxO9Xr9q1SpCCO02\/drFeXbQPhkhhGGYJ3NdAwB0hx4SAABIAlIHAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJDi88cYbYmKb+Pj41atXFxcX0z+7UPn5+XK5PDU1ta6uji5JTk5OS0vTarV5eXl0SVBQkE6nKysrs3mjQqFYvHjxE96+TqezeSMhBNt\/oO0vXLjQni8O2+97+3Ye2M\/e9p+67F8gEfgfEgAASAKG7AAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBIQkAAAQBIcCSEsy5aUlBQUFAiC0ONKgiBkZGQof8GyLM\/ziYmJ9Kler38yZdXr9WIZMjIyBEHQ6\/WJiYk8zz+ZAvRBrJC+a4NlWaVSOXXqVKPRaL1EqVRa74hWq7VehxBiNBqnTp1qvX3xS3mSNSAWg2XZx7H97vXTI3okWO84LZhWq6VPrY9P69JqtVrr7fe2Wr\/vkZ0\/E61WS3eh3wv20MennQeeTf0DPBxHQkhlZSXDMH5+fgzD9LZeVFQUy7Icx61YsUKhUMjl8u3bt69YsaKkpOSJ3fJZo9HQT+Q4LiEhobi4WKPRzJw588l8et8KCwuzsrI4jmtsbOztZMrz\/NGjR1mW3bFjh8FgEMN\/fn4+x3Hbt2+Xy+WEEKPRGBkZmZ6eLr5REASDwbBjxw7r7RcXFyckJHAcl5WVVVhY+Ph3kRiNxk8++WTHjh0lJSVHjx7trfny0Hqrn+7FaGxstNnxkydPrl+\/PiAgQFxt5syZHMdxHJefn0+XsCwbGhrKcZz19ruv9jj2qO8DQyyep6enuAv9W7CHOz7tP\/C61z\/AQ3BMTExcs2ZNUlJSenp6b60nhmHmz5\/PMIxer2cYhp43u7PuSNE2HW2X0ZYUbXzp9freVsvIyCgoKBB7P6TPZpdCoRBPWIWFhT02e3vriOzfv7+31R6OIAghISEKhYIQMmXKlKqqqh5XM5lMU6dOpRUYGRkp5v7qvmvTpk2zWejv70+bCyEhIXSJRqNRqVSEEB8fHw8Pj0cpv50UCoVOp+vt2390dtaPIAhTpkyh5fHw8KCN9Hnz5g0cOFBcRy6Xz5s3jz6urKykX41KpaKNJ4Zh\/P39e1utH8nl8rS0NJsvrkc0GIitq\/4t2KMcn3YeeDb1D\/BwHPPy8pKTk9etW5efn993X4dl2erq6r7XefPNNzmOKykpqaysJITI5XKVSpWWliaXy5VK5R\/+8Ifo6GidTkdbWCzLHj16lOd5uVxO0zXeunWL47icnBz6G1AoFAcOHOgxUaPJZPL19SWENDQ0tLS0cByn0+nEX1p2drb1EkEQLl26RBuqqampKpVKEITc3FzaZuy7PW4PQRAqKir+4RZ4nqfVYiMpKanvuMgwzMiRI1UqlVKprKiosD490R0ZP378Qxf+gdDGxJw5c9RqdR\/96YfTW\/3YqKystH+Ikq5pE0R1Ot3IkSOty9\/jav2IZVmbL85GYWGhWq12c3OzWd4vBXvo41M6Bx48J2R2rkdbcKmpqT2+ajQaq6qqVCpVdnY2TSGcnJxMX1Kr1du2bVMqlRzHeXh4BAUFNTQ0JCUlie+dOHEi\/b1FRUXNmjWr72I0NDTExsbSlXNzcwkhAQEBcXFx1uuYTCYx9\/BHH31ECGEYxt3dnTbr6BsFQTh\/\/rxaraZvCQoKUqvVD90OFVvcfZPL5d3PpCqViuM4QgjP88XFxT2WQQyoDMPs37\/faDTS1XieX7x4cVpaWr837XvDMExOTg7P8zk5ORkZGf17Bu+xfroLDg62f5tGo3HEiBHiU0EQVq9ePW7cOHow9LZa\/9Lr9aWlpatXr+5tBZ7nv\/\/++88\/\/5w+HTFihFi8finYQx+f0jnw4DkhS05OFrPQf\/TRRz12gGhraO7cuQzD0NjTfUyJEMKybFZWlkKhoOdWupCOq7As+8MPP9AtTJ48OSUl5eEO5YCAgJKSkr7PgydPntyxY4dcLqdFpQs1Gg3dNaPRyLLstGnTZs6cmZub2y+nVIZhHBwcBEFgGKaqqmr48OE9rubj49PY2EgIEQTh559\/jo2NFQThk08+mTt3rkKhMJlMfWReF2f4hgwZQpewLLty5UqdThcUFFRQUDBr1qx+77LYoCO6Go2GYRhPT0+TydS\/Aal7\/fS4mlwup1+rPb2HyspKsb1iNBpTU1Ozs7NVKtXWrVvj4uLE91qv1o9o\/AsICMjJyaGj0zaBkKIzsuSXRon1Ov1SsIc+Pok0Djx4fjjm5eUtX7783\/\/93w0GQ2\/DcWJ\/QqlUqtXq1tZWOgGzZs2a2NhYceHw4cNTU1OVSmVsbOyaNWvEGSm1Wp2VleXh4SEO5WdmZtIZHTpOZTQa1Wr12rVrVSpV9yt8xDkklmXpJ4qTTHq9fs2aNbTNvmHDhvT0dJZlR4wYIZaKLrG+ZikzM5P+4MePHz9nzpzuV7g9HHFr1iMbNuWXy+UMwyiVSpVKRYeMGIZZvHgxrY3MzMyEhATyy3RXenq6Wq2mBWMYprW1lRZ1y5YtQUFBhJCjR4\/W1dWp1WqVSiU2KR4rjUZTXV1Nyx8ZGfk4Zlxs6ocup9fUiVeaKRSKiooKpVI5Z84cOmREBxLpUWd9PZhNxCorK6urq6MDpHv27BE\/9\/GN19XV1Z09ezYvL0+pVFqPCvQ4OWo0GufMmbNmzRpxT\/uxYD0enzYV2+Pxac+B11v9Azwoh3PnzlVVVTU2Nlo3GPsXz\/MrV65ctmwZOvgAANAbmUKheHxxgg5ZFBUVEUJef\/11BCQAAOgN7hgLAACSgNRBAAAgCQhIAAAgCQhIAAAgCXYFJJqSUoTLOruzM3mlzYW21m8Ur2W3vkjdJqummHxTZDQaExMTHzH1UY\/ErJrWn0jL\/+jJlnrz0MlVe6x\/MUmV9f8EbCpWfCMSgwL86uwKSKmpqcuXL6epdwwGw5PJnPZ0sTN5pSAINrky6b+JxXSxdKGYWNP6P5I2yTfJL0lX4+Pj+313rLNqhoaG0tO3mNX00ZMt9ehRkqt2r396hSdNUkWTUdH6t85ZZf1GcTcB4NfyAEN2giAUFBQEBQXRNA20sbl\/\/37awGRZljZvCwoKaLOUtlXFhrbYnu1xtaeanckrrTNmdqdUKvuI9DbJN6ni4uKJEyf6+fk9bMF7xTAMzUBI\/j5VD82waWcqmgf10MlVe6x\/GuN7zIzAMMzUqVNNJhMhxMPDw8fHhzxgRiIAeBzsDUjl5eWxsbHWGQE0Gk1+fv66detoA1OlUqlUKoPBsHnzZtos1Wg0NIECbWhnZWXRJHLdV3s8u\/bk2Jm8skdi3gqVSnX48GG6kT179tiMjnZPvkk7Cj2ecPuR0Wjct2+fUqkkVikSbDIp9JeHTq7aY\/3zPE9LLg7QiZkIaJYHuhExhQHNGd+vOwQAD8be5KpRUVEZGRl79+61WZ6dnW3zd9f09HTr1JDjxo2jDW2FQhEeHk4Tatms9rR7lB6DTR4zmq+FLiGEbN26lZ43uyffLCsr+\/zzz+nC+Pj41atX93uEYFlWq9Xm5ubSLdMbNXEcJwjCzp07lUpl\/37iQydX7bH+KyoqPDw8bEorpjTcv38\/PSzFzId0RPqZOSYBnkYPMGRH74okCIJWq7WzN2B91yJBECwWyzOZh1FMXkkI6SN5Zd+OHDlC8zrr9XraMRIEoaGhgfwStOh9PVasWEFPmhqNhs4zrVu3LiUlpd8rVqvVFhYW5uXlmUwmegcp8kuGTXo7x\/79ONItuSfNnNadGLfEVG891r9arfb09KSlHTNmjPUWeJ6vqKig2\/f19aVVR7fT7zsFAPazKyDpdDqa+ZQmTqVnSa1Wm5SURFNV0iuU9Ho9zWcqXtdkPUgijvN0X+3x7uITYU9yVfqUVpp4IZl43Vd1dbUYacQcpuK9OUhPyTcJIVqtNj09fcOGDf1bjfSGikVFRSqVimbOJYQEBQVt2bKFlra1tbXfT98PnVyV9FT\/CoXC19eXlvbAgQP0ogY632l9Pyd6yy6a3La3EAgATwZSBwEAgCTgj7EAACAJCEgAACAJCEgAACAJCEgAACAJCEgAACAJCEgAACAJdgUk8b8y1CP+eYj+HeTxZYz+VdiZ7ZvmTe++73q9XqxV69zq4n+YaALA7tt\/rOm3aUmsv+7u2coBAPqLXQHJw8PDYDAYDIZ169aVlJRYJ5y2sX\/\/\/n94ZqR5B9LT0x+spNJmT7ZvlmVDQ0O7Z8s2Go3V1dVRUVH0aUBAQElJCc3LQKtaTINts329Xl9dXc1x3IEDB2wSOD06rVZLSztu3DiO40gv2coBAPqLXQFp2rRp4vlOLpenpaUxDCPebIY2menT9PR0tVpt3awWm\/bPTFKG7uzM9q1SqWgiNevca\/RGD3PmzBFXmzdvHs3OYDQaaTIhsc7JL\/m2yS\/hIS0t7THtVFpamk3e276zlQMAPKKHn0PS6XQ0XTfLsvv27aurq8vJyVm3bp3BYBDvQEMIGTRoEG3vT548ubcbCjztHjTbt06nE1Pj0FtI0Dsg2KisrLTp97AsK6bGMZlMDQ0N3e+h149oY0LMaQQA8Fg9ZECieS1pun6GYaZPn95bnua\/\/e1vsbGxSqVy3bp1D11KibM\/2zftR4aGhtJTvCAIpaWlSUlJKpVq7dq14g36iFXmUHGJXq8vLCxMTU0VV6D3suM4LjIy8nHMIalUKnrnumfgnlUAIH0PGZDkcnlAQIDYJ+B53vrUSQjRarV6vV68RyfHcc\/YpJE1O7N9G41GtVqdkJCg0WjofSUYhsnJyaG9zOXLl8fFxVmvTMfryC9hrLq6WlyZEEKTkNIVoqKi+jfVKc\/zGRkZNCgGBwdXV1f348YBAHpk7\/2QtFptXl4eIWTTpk25ublyuZzmV6ajcMnJyfQ2snK5XK1W0yV0BqKhoUG871lUVFRubu6RI0dWrVolbjk\/P\/8ZGBESa0OsCkKI0WhMTU2dPn06nekpKyurq6tLSkoihERFRYnhh+f5xYsXl5eXu7u7i9M2lZWV4gp1dXVnz56tq6ujXwG9rIBhGLVaTT+UVmw\/7o5cLk9JSbHZON0d+o0HBQXpdLp+v5ICAJ5nyPYNAACSgD\/GAgCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJCCVtJ7wAAAPj0lEQVQgAQCAJCAgAQCAJCAgAQCAJCAgAQCAJDitXLny1y4DSIvZbC4oKBgyZIi7u3t5efnJkycjIiK6ryYIwhdffDFy5EiGYWyWZ2ZmDhw4sLS09MKFC6NGjdLr9TYPrNf\/8ccf79+\/7+bmRrdmNpt37tw5bNgwNzc3rVZbX19P1+\/s7Lx7967QTUdHh4uLi4ODg3UBPvvss6FDhw4YMMD6g1paWq5du7Znz56SkpIxY8bIZLJHrCie53U63ZgxYxwcHJqamtra2miRCCHOzs7iagcOHLh9+\/aQIUN6245YkxzHlZaWWtePxWLJy8vz9fUdMGBAU1PTxo0blUql9capysrKS5cu1VhxcHBwc3PrscasK+306dN6vf7U32tqagoPDyeE\/PTTT7dv3\/b393dwcNi6devQoUPr6upYlh0+fLhYpRcvXty1a5eHh0dtbW1zczPHcaGhoY9YsfDcetTfJDx7KisrOzo6Bg4cSAjhOC4yMlJ8qaOj47PPPjt79iwhpKur6+bNm8ePH6fnRy8vr5UrV4aEhHAcN27cOJVKVVNTY8\/HjRgxYtOmTfPnzyeEWCyWoqKisLAwGktSU1N1Oh3P83K5vLa2tqioiL7lzJkz4eHhtITe3t4ajcbd3b2pqamrq4uuEBkZee7cOU9PT\/rU09Pz2rVr33\/\/fWNj4yuvvDJx4sRdu3bl5+d7enq2tLQkJSVpNJpHqTGe5w0GQ0dHB3368ssvR0VF7d2798aNG2JpT506Ja7\/8ssvx8TEiE8FQQgICJDL5UeOHAkODhaXm83m+vr6trY2V1dXQRBqa2tlMll7e3t7e7uLi8vt27ezs7Obm5u9vLzee++9iIiIy5cvHz16dOHChY6OjgzDWNcYIaS8vNzd3V2hUIiVRquFflniakaj8dChQ\/Txb37zm6+\/\/vr48eP37t07d+5cfX19e3u7yWS6fPlyfHy82Wz+\/vvvr1y5smTJEldX1127dk2cOLG9vf1RahKecw6tra2\/dhlAQjo7O7\/66qt\/+Zd\/qaysDA8P\/\/jjjxsbGwkhHR0dsbGx7733nrimIAg6nW7hwoVyudx64SeffDJ37lyFQqHX6wkhGo2m+wO6ckdHx+bNm6uqqgghJpPp0qVLYWFhAQEB9NWkpKSIiAjrt+zdu3fIkCHR0dEbNmyYMmVKeHj45s2bx40bFxER0dLSotfrm5qa2tvb\/\/a3v\/32t7+17gDFx8eHhYURQvR6fXBwsEqlEh+wLFtTU\/MQASkvL2\/v3r0\/\/\/zziBEjMjMzQ0JCrF+1WCzNzc1ms7m8vPzSpUsJCQnWrzIMI3Yr9Xr9qlWrxJeioqJyc3NplRqNxoMHD44ePfry5cteXl5NTU0+Pj5+fn4tLS01NTVvvfWW+BWYzWaDwXD+\/HkXF5fg4OChQ4fOmDHDxcVF3OyVK1e++OKLlStX+vr6WpdEr9efPn06MDBQXHLnzp0BAwYsWbJEXEI7VdeuXQsKCuro6GhpaRk8eDDdBbEAN27c+POf\/2yxWARBGDhw4NixY5cuXerq6vqgtQrPOfSQ4P\/RDsr9+\/cPHjwoCMLNmzcTEhJee+01YtVwNhqNH3zwgYuLi3UPSexn1NXVEUKCgoLs+ThXV9e3337bYrFwHLdjxw5XV9ehQ4c6OTn98Y9\/9Pf3p+tER0dv27YtLi6OYRilUvnNN9+II1o3b968e\/cuHVzy9PT84x\/\/SAi5ceNGV1dXamqqzdkwLy\/v4MGDPM+7uLgEBgaGh4db90UeQnJy8tixY9evX5+Tk\/PTTz\/t3r1bfIn2P7y9vZubm\/\/3f\/\/X29t727Zt4qvx8fHWIZzGwuDgYKVSuXPnzlmzZlkPgYaFhU2YMMHZ2XnPnj1eXl5z5851cXFpbGxsaGiwLkxzc\/OwYcMWLFhQV1fn7e29adOm+\/fvi682NjZ++umnTk5OlZWV7u7u7u7u9uzg7du39+zZEx8f397efv369WvXrh07dszb25sQ8sILLwwbNqyioiIvL+\/mzZtlZWWBgYGffvrpvXv3qqqqpk2b9sC1CUAIQUACaw4ODi+++OKwYcN27dq1dOlSFxeXAwcOXL16lXYvxD7HtGnTUlJSrHtItJ9BCOF53sPDw2ZWqTdms7miooLOGC1btiw\/P3\/hwoVdXV3bt293d3efN2+em5ubj49PS0uLIAgMwwQFBUVGRra1tdG3V1VVTZkyxbofQAjp6Oi4du3axo0b6VNnZ+eZM2cOGTIkOTlZo9Gkp6fPmDFDo9F89913j1hXZrP52LFjt2\/f1uv1Go3mxRdfPHfuXG1tbVxcnKOjo7u7u9ls3rJlS11d3ZIlS+h5nBBSXFzc2NhI61PU2NgYHR0tCIKDg4NN1bW1tfE839raOmrUqLFjxxYWFv7+97+nM0Pdi9TS0vLjjz\/GxcVZLzSZTJ9\/\/nlMTExNTY2Li8vq1asXLFhAh2EFQZg0adKkSZO6b6qpqUkul0+ePLmkpCQyMvLMmTP19fWEkJs3bxJCOjs7hw8fPm3atFGjRqWlpaWkpAQEBLi7u1+9erW5uZnneUdHR09Pz0efpYPnDY4Y+DsBAQEHDhyYNWtWR0eHq6vrlClT1q9fP3v2bAcHB3Favqys7L\/+67\/MZvOZM2e6urrc3Nzq6+utJ0Xs5OTk5Onp+f7773t5eXV2dsrl8q6uLl9f3yVLlty+fdvR8f8vAW1qavqP\/\/iP2tpaQsjmzZtv3ry5b98+sQ\/0+uuvJycn08e3bt2aOHHi1KlT6dOtW7eKsxo\/\/fSTl5fX8ePH7ezA9a2uru7+\/fvjx4+PiIhoamq6fv06wzAymYzjuJiYGLPZrNPp\/P39Q0JCli1bJl6GwPN8VlaW9XYEQWhpafHx8TGZTDbjaYSQhoaGixcvXrt2zcvLa8SIEWVlZSzL+vv723Oup13Pr7766k9\/+pO7u\/u2bdsiIyNXrFjxn\/\/5n+PGjYuLi7t9+\/b169fb2toYhmloaDh79qwYzLy9vSMiIoKDg4cMGXL69OmgoCCVSiWTyUwmU1hYWFVVVXNzs5+f39GjRwcNGvTXv\/7VxcXFy8urpqamtrb25s2brq6uarVa7OYC2AkBCf5OYWHhsWPHBEEYPXp0TEyMj4\/PwoULjx07FhoaSlvlISEh2dnZdNKC4zi5XL5s2TJPT087e0XWWltbf\/zxx6amJkJIR0fH8ePHGxsb3dzc6KvixA8hxNvb+5NPPhHfSOeQ6Py8NbPZzLLs66+\/TsfELBaLi4uLk5MTIeTWrVtXr14dN25caGgoz\/Pd595ramoOHjw4YcKEHi8ptNHZ2WkwGH73u98dOnRo7NixFy9e5Hk+MDDQ2dm5tbX17Nmzr7zyyoIFC1xcXOrr6z\/44ANxjI5OiYkEQVi9enVRUVFeXp5YJ9YTWuKQHb1wLi4urrCw0N3dPTAw0GKx8Dx\/9erVZcuWxcfHe3p60iv9xPeeO3fu4MGDH374oa+vr9FopAt9fHxWrFixd+9ek8k0dOhQuVz+l7\/85c033xw8eHB5eTldRyaThYSEyGQyi8VSUFBACPH09Kyqqrp7925bW9utW7d8fHwIIZcvXxYEYcSIEXPnzvXz83Nycvrqq68sFktSUpKHhwchpK2tbe\/evd7e3pMnT0ZvCeyBowT+zvz58+kFby0tLXQ0LDAwcPbs2SzL0pAjk8lcXFy+\/vprPz+\/+fPnv\/baa7m5uampqfScK5fLW1tb6QjbP\/wsceLHYrEYDAaz2Ww2m8XTGWUymeyPdleuXOns7BQDlSAIzc3N3t7e9+7d++abb6ZNm1ZeXi6TyeLj4\/V6fWtrKx0NI4Q0NTWxLDt\/\/vySkhIvL68+LtGmXFxcFixYcO\/ePUKI2Ww+depUXFwcndd58cUXDQbD+PHjBw4cKAjCzz\/\/nJKS0lsPiWGYlJQUhUKRkpLSW5S15uXllZSUxLIsna05ePDgu+++q1Ao6J6ePHkyICDgzp078fHxzs7O0dHR0dHR3Tfi5uYmxrzq6upTp06p1eoeP66mpubWrVsvv\/wyy7IeHh5jxow5d+6cTCarqakZMWLErVu3pk6dWlhY6OrqKpPJLl++3NLS8uqrr\/7000903vGvf\/1rbGzs3bt3T506NWHChL6rFIAgIIGN4uLi7777zs3NbcyYMW+88YY4iFRZWRkREdHZ2Xnw4MEDBw786U9\/UigU69evVygU77\/\/\/saNG11dXf\/whz\/Q0bC6urq+T6yirq6umpqaLVu2+Pn5paenX7hwYdWqVQkJCTExMTQclpWVRUZG2hOQbty4kZub++6774qzSo2NjXQyw9nZOTk5mf6tSlz\/4MGDHMeJg40ymczJycnZ2dlisdhTcm9vb57nCSENDQ1hYWHBwcE0IPn4+AwaNKi9vZ1edO7n5\/f+++\/31kOiO+jr6ysO3Nm8umnTpk2bNhFCFi5cSAjp6OiQyWQXLlwYM2bMCy+88MILL9DVnJ2dT548yfP8nDlzdu7c6eDgYDNN1aPm5uaioqKlS5fm5uaGhYV5eXmJvcP79++3t7fv3bt3ypQpZrPZ19dXo9HU19e\/8cYbQUFB+\/fvJ4S8+uqr4lTW5cuXv\/7666VLl7q7u3\/xxRcDBgyIjo52dHR0cnJC3wjsh8u+4e+0tbW5ublZz98UFRUVFBSoVKp33nnH2dnZaDQqFAoXF5eOjo6tW7dqNJqBAwdaLBaj0Tho0CAfHx\/7L6S+ffv2Z599FhwcPH369KFDh9I\/t7a3t5eWlu7evVuj0YwdO7b7leWEkO3bt0+YMMH6SuuWlpZvvvlm+vTpNCKyLKvVan19fRctWmT9P6r9+\/cHBgaOHj36xo0bDMMMGjSos7Pz\/v37DMNcvHjxxIkT48aNGzVqlPXfbPtw584dvV4\/b948FxeXgoKCU6dOLVu2zLpU1lV048aN7OxsV1fXDz74wM5JrFu3bjU0NERFRYlLWJYtLS0dNmzYjBkzxBN9Y2Pjpk2bZsyYQUtusVhOnTrl6Oho\/e+ia9eu7d69++233xYn3rq6ug4ePOjr6xsTE9PZ2Xnu3LkzZ850dnbSV4OCgmbMmGE0Gl944YWLFy\/W19fTa+fu3bu3devW69ev\/+u\/\/quvry\/dQZVKdfTo0cTERBpQm5ubCwsL4+LiXF1di4uLfX19J02aZHPtCUCPEJCgn9F5kYSEBOsT4sPRarWhoaGP+K9VAHhaICABAIAkILkqAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIAgISAABIwv8BWWbfN\/20eQ8AAAAASUVORK5CYII=","height":194,"width":560}}
%---
%[output:43c2f191]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAjAAAAFRCAYAAABqsZcNAAAAAXNSR0IArs4c6QAAIABJREFUeF7tnQn0FVeV7o+z0AYjSLQRIw5ETYwgqCCKRBGjtqBG0wy2IiLiECARwhgloGESUJJoRCQYWxlsGyUogogr2EoTuxODmqigSCNBWwSVqDj71nfe2\/ft\/\/nXeMeqXV+txQLurTrD70xf7b3PuQ\/6+9\/\/\/nfHiwRIgARIgARIgARKROBBFDAlai0WlQRIgARIgARIwBOggGFHIAESIAESIAESKB0BCpjSNRkLTAIkQAIkQAIkQAHDPkACJEACJEACJFA6AhQwpWsyFpgESIAESIAESIAChn2ABEig5QT+\/Oc\/u4c+9KHuQQ96UJe8\/vjHP7rvfOc77uEPf7i75JJL\/D1p1w9\/+EP3q1\/9yl188cWuV69eabd3+b6RZ7NmhDz+8Ic\/dKvPyZMn3Y9\/\/GP33Oc+1\/Xo0SNrcv6+v\/zlL+6OO+5wF110kXviE5\/YjSPu+elPf+rOnDnjnvnMZ3qeuM6ePetOnTrln5HPwoz\/9Kc\/+Wef9KQnZeKfq+C8mQRaSIACpoVwmTQJkIBzhw8fdldffbWbMmWKe\/3rX+9++9vfuvvuu88vyg888IBbvXq1u+CCC9y0adP8IvuIRzzCPfvZz\/Z\/R10rV650t99+u7vxxhvdk5\/85C63QBgkiQM8u3PnTrdp0yY3cODAbsmfO3fOzZ8\/39+T9Ro0aJDbuHGj6927t38EeUCsrFixolYWCLWlS5e6Xbt2uU984hNu6NChXZLftm2bW7BgQZfPNm\/e7IYPH+4\/+\/a3v+3e8pa3uDe84Q1u0aJF7sEPfnC34q1Zs8Z99rOfdZ\/85Ce9iMF18OBB9+Y3v9nhu7Fjx0ZW6dixY27q1Klu9OjRvu6\/+c1v3Pve9z534sSJLvf379\/f1+Exj3lMVjS8jwRaSoACpqV4mTgJkAAECxbQz3zmM+7aa691l112mfvABz7grQN4+\/\/Rj37kHvnIR7oBAwb4hTltoYRAWL9+fSTY5cuXu\/Hjx\/vvfvnLX7of\/OAH3YQCFvU5c+a4JzzhCbXvzjvvPG8x+dvf\/ubFESwSuCBoduzY4cv0ohe9yH3jG9\/wC\/trXvOamjh59KMf7f75n\/\/ZPepRj4oUMDhq63Of+5wXBbj69evnRdtznvOcWv7\/9V\/\/5dPGBevS5z\/\/ebdhwwYvYH7xi1+4mTNnum9961sO5fzgBz\/oxowZ08UKI8ILz4twQr64F2LspptuchdeeKFPH1YwpCPWrk996lPuIx\/5iBdhz3rWs7wVB4IG9US9ccm\/tVBjzyaBThOggOl0CzB\/EqgAAYiY66+\/3g0bNsxbEfbs2eO+\/\/3v1wQCRMDLXvYy97CHPcxbD17xilfEUoGAgSAIRQgegBsE7hJcECqTJk3KRBfWCVn4f\/7zn7vt27c7WE2yCBgIm+c973neugLRgcUewmzkyJHeYrF371733ve+173zne\/0dYeIQ92XLFnixo0b50WbuNIe\/\/jHe\/fT3Llz3apVqxy4oJ7333+\/Fz2f\/vSn3Re\/+EWf3pVXXumtVFGCDlah97\/\/\/W7evHk+L31BQIkFCnWdPn26e+ELX+gtYA95yEO8ZQwCBuIJz+NCHuBJAZOpO\/GmNhGggGkTaGZDAlUnAOsG3v7xZ\/fu3ZkEDKwIcDNhUZUL1oSvfOUr3VxIofuoHgsMrBJHjhzx7i6UEzE2sBDhb1gjIE5gOXra057mrTWIaYFQgNUHAgaWIbhkcCFGB2IBFpArrrjCXXfddd5Kg5gUuIG++tWvupe\/\/OVe5CBfiIYJEya4pzzlKV60XHXVVQ5upKNHj3oLCYQS8kZ+\/\/7v\/157FmIEPPAMLCtwRx0\/ftyNGDHCCx6IEFi3cH3961\/35cQzcL+B5Ze\/\/GX38Y9\/3P+Nst5www2+TBQwVR+xxa8\/BUzx24glJIHSEhAxgJgQXFiQ77nnHm+BwRXlQsLnsAa86lWv8haQrDEp2n0UBywtBgbPSZlnzJjhXTXaGqEtEadPn\/ZCB\/dpt9Xb3\/52b8mAmwn3I9YGaf7ud7+rFQviYfDgwV7MrFu3zkGoiYCBFQnWGVikvvCFL3jXFgSKXH369KmJI1i1PvzhD3exjmiLjLYs4XmIG4gWCBhYX5AnrDyIQYJQQ6wSLDvgf+jQoS4Yw1if0nZKFtwMAQoYM03JipBA8Qj85Cc\/8a4jWC7wbwgYBIFi4U66xBUkAuZ73\/tezcIQPoddP7AaaAETFRSbRkcWe5S1HgsM0kewLYJmIVYmTpzoXUYQB4ijgZtILombgRUH1h3E3CBPxAb97Gc\/c4hL+ehHP+pjgyAsJD4Gz8Nt9NrXvtZbW\/AHggXfI6gZ6UKg3H333W7WrFneJQcLFiw9sPKAC9oAgcQoD6w5j3vc47z1BTE5iFXCjjEIG7i2YPXBhfRRVrqQ0noRv28nAQqYdtJmXiRQUQISjyI7a7IG4oqAgUskbvGUtLWAkXiUEDfECXbZPPWpT\/XiQF9DhgzxsScIopUYGHyPHVP79u3zu3TgFgoviYGBFeXmm292H\/rQh7xo+etf\/+pFFfKC1QR579+\/3\/3Lv\/yLd4khUPcFL3iBj\/kRqw\/cNigftpa\/6U1vcm984xu92IMrCm63vn37+ngVxNUgD1hFIDrCoGZ8jngclBvxMrDSwKKFeyFGhCXKAcGDuJpbbrnFb9OWIF66kCo6WEtUbQqYEjUWi0oCZSUQJWB03AbqJYGqiOUQl4wIGDyvd\/5oDngOgiN0ISFeBOIDFp+nP\/3p\/pHQhRTeg2BjbEWGiMAFqwNEAKxHiGN57GMfG9kEKBssI+9617v8tnG4fxCwDPfPwoULfeAuBAf+hssIVpF3vOMd7mMf+5jfUg13DdxGEEG4EL+DvODSQTwKnoHbDeV997vf7Z99yUte4uNkEOwbxsBALEGkwAIze\/ZsH5eDOBdYYCQYF5YfCEpYfSDekDfifmDNQhvAxQX3GC6IHLj+aIEp6wi0WW4KGJvtylqRQKEIaAGDg9yirAZSYC1EGomBEasGXEN6N40+Bya8B9YXOQMF4gULP8qgLTYQERA02IYtggbPQLhAEMAlg4Bi7GqCGwYCBp\/BmoLYEpQFVhC4jbCzSLZfS\/3hfkIZEagLcQKrEFxRuL70pS95FxXcchA\/2PYc7hAK\/w+3FuJysAsKcS\/YWg5LEYQfzpaBhQcxObAGvfjFL3aXXnqpF2KMgSnUEGJhIghQwLBbkAAJtJyACBhYDrBNGO4VxGlI3AYKAFGA807wRywwcHFgocf24vCAOgQA44KVAffgXuzgkSuLgEFsDWJPIBBE5MjzEBmwdjzjGc9wa9eu9W4cWE4gHr75zW\/Wzk2R+yF28DnKgjgW2ZYNsQCX0OLFi2suJQgRCJuXvvSlvtxw4cBFdNddd\/ndTnJmC2JUli1b5uNkcC9cRRBDv\/71r2viJ03AIH1YdBAvgzxxoWy4sIsK4gxsIdh+\/\/vf+\/aB0KIFpuXDghk0SIACpkGAfJwESCCdwNe+9jX3tre9zd+I03jhqsBZLlGXtsDIKbFws0DUQABhEcbiKifTYtcMXC24IIjgqsGVRcCIsMJZKFrAwIWEE23htpHD8BDHgrgZWC4gRmAJ0T+NABeMHB6nT+KFmMFzcoItAnSxhRpuIfkMIgeWkFGjRnkLCLZNQ0jAfYTPEfuCU4phQYElRXZpoZ4QMLfeeqvf2o174g6dg3UJlhjE8SAuRixMYADhhb9xyCAsPnBNMQYmvV\/zjs4SoIDpLH\/mTgLmCcBqgWPyEafxnve8x1s8EFQqO2dgGcA9sMDgPtwDsQLLAawPcKVATMDVgmdf97rX+dgMuG1wSBusEoh1gbiBxQR\/9HkusoU7CbQIGDl3BuIB569APEBsRP20ANwucE8h\/gW7puR4f\/kpAQgiiDF9JL+IBggNWFokcBjxM\/LTCgiixdZxxNDAfQVLlVxwX8HCA6sJznmB2ABLLWBwr5xmjDIdOHDAW18QwwKBh7Tf+ta3OrE+YTs4YnVe+cpXeisTrEWwEMnpw0hPTiDGicNwhcEixosEOk2AAqbTLcD8ScA4AYgCxIbAiiBH4Gu3B6wQsnsHwgO7Z2CJQOwG3EkInoVgweKN7b34nSRYEGAdgTsHAabYdYOFGQs+RA9iU\/SJunGIJQBYW2AgtCCG5IJQgWXi1a9+tV\/oITDww4r4aQTsjgqP9k8SMGE5tIDBtmbUC5YpWHtghUH68rMG4bM4cRgn+UK83HvvvZG\/UyQWIcTL4Hr+859fs1IhYBlWKogh+VHMtNOL9Sm+xrstq1cCAhQwJWgkFpEEyk5An8KLuuDsFggS+dFGLNKIi8EPIsJaIK4ZnEmCf0PYIA0surDEwLIQphn3i9dJ7OS0Xogr2amEIFpYhGAVwbkqUT+ciDQhDhAz0rNnzy6upLhfo87ShqgfYntQx7hfj86Sjr4Hog5\/wDGpPnnT5f0k0GkCFDCdbgHmTwIkQAIkQAIkkJsABUxuZHyABEiABEiABEig0wQoYDrdAsyfBEiABEiABEggNwEKmNzI+AAJkAAJkAAJkECnCVDAdLoFmH8mApMmTfLnVPAiARIgARLIRwBn+mAnoLWLAsZaixqtD05YxbkcVi\/Wr9wty\/Zj+xWZgNX+SQFT5F7HstUIWB2AUkHWr9ydne3H9isyAav9kwKmyL2OZauMgMGx8rNmzTLb4qxfuZuW7Vfu9qOAKXf7sfQlJ2B1AJa8WVh8EiCBEhCwOn\/SAlOCzsciOv8rw5ZjYNjGJEACJNAqAlbnTwqYVvUYpttUAlYHYFMhMTESIAESiCBgdf6kgGF3LwUBqwOwFPBZSBIggVITsDp\/UsCUultWp\/BWB2B1WpA1JQES6BQBq\/MnBUynehTzzUXA6gDMBYE3kwAJkEAdBKzOnxQwdXQGPtJ+AlYHYPtJMkcSIIGqEbA6f1LAVK0nl7S+VgdgSZuDxSYBEigRAavzZ6EEzMqVK9369eu7dYuxY8e6FStWuBMnTri5c+e6VatWuYEDBxay+xw5ciSxjPh+ypQp7uTJk77806dPd\/PmzYusy7Zt29yCBQu6fYfftMBvW5w7d87Nnz\/fjRgxwo0fP74QPM6cOeOmTp3qy6frJWWdOHGi\/w51O3DggG\/XHj16pJbd6gBMrThvIAESIIEGCVidPwslYMI2ChfoNHHQYBs35fGkMsrijoUdi7j8f8KECZECJGqRxw8azpkzx23atMn179+\/sALm1KlTvowiNClgmtK9mAgJkAAJ5CZAAZMbWeMPwCIDS4W8pZddwEQRQR1xRVlhogSMFnXjxo0rrIDp1auXO\/\/882ttRwHT+HhgCiRAAiRQDwEKmHqoNfAMLA1Y3Ddu3Oh69+7tU0oTMLJI7ty5098\/aNAg\/\/zp06fdsmXL3Jo1a3xa4WKKe7X7Srt1UA5xayH\/a665xl177bXdalavm6sZAgZWjn379rlDhw7V6izMUP5JkybVyrt8+fKatUfXWcov7hzt6urXr1\/NmiJWI+SlL7mnT58+3oU0bdo0t2HDBifWJQqYBgYDHyUBEiCBBghQwDQAL++jsniuXr3au1rkShMwsFgcO3bMWzOiLBUSf4F0tKDRlg7kpeNKRABI3ElaXdLKqJ+Pq6fck9WFdPz4cS\/UID5QdogJMIDYmD17tlu4cKF35WhRePjwYbdly5aahQRiZsCAAV7chK6uKDEZx0E\/K8JQl40xMGk9iN+TAAmQQHMJUMA0l2dsaiI8ZBEOF\/ysQbxhfIkWN1FCRxZW5IcFWxZ3WBpCS1ASiqwCJi7YVaddTxBvmkVn69atXuxAwMAyEyXMdP0hiqIsVlkEDMSnlGfmzJleXDUiYCRP\/Gqz5V9ubtNQYzYkQAKGCeAXxPFHLou\/JVe4IF4s2rLIihskqwVGu0sggPr27VtzYWirC1wbo0aN6hJIG7pExP2EhV4LmNAlI2XL40LKIl6QbtpOnahdSFrAhC61kSNHurNnz9bccmFdRMzECSe4n8aMGeNdRGkuJAlUFivT0qVL3Y4dOxoSMBYHoOH5k1UjARIoCAFaYNrQEGnWi6Tvw8U87v+XX36527Nnj1u8eHFsPIyuah73CZ5Lq0PazqPQApO01ThNwIRlT6qLFo6heylP04fuJxFiu3fv9skgvojbqPMQ5b0kQAIk0BgBCpjG+KU+nWVhzyJgxPUk1gUdtCqWhTBgNbR06N1PzXQhJbnHogA1aoGJ2nIt8TJ79+7tcg6LdhuhnLCyhFaUMCYpqsxRAkZbgrSVh+fApA4L3kACJEACDROggGkYYXICca4ZPCU7XPBvfQicpCi7hnQa+Ewu2aIs7owZM2Z0O3dF78gR9xFcWPVYYOLKeMUVV0SWXwQVFnoddNuogNHCAQwRzAv3mRwEqOusdxqJJUnXQwvBpJaMEjC4PwyGTovvCfOwOgBbPKyYPAmQAAk4q\/Nn4WJgWtnXwl05rcyr3rR37drldwwV9aTheuvV6HNWB2CjXPg8CZAACaQRsDp\/VkrAhLtr0hq93d\/DYoIAZpydkuV4\/XaXr5P5WR2AnWTKvEmABKpBwOr8WRkBA3cJDrjTx9tXo+vaqKXVAWijdVgLEiCBIhOwOn9WRsAUuXOxbOkErA7A9JrzDhIgARJojIDV+ZMCprF+wafbRMDqAGwTPmZDAiRQYQJW508KmAp36jJV3eoALFMbsKwkQALlJGB1\/qSAKWd\/rFyprQ7AyjUkK0wCJNB2AlbnTwqYtnclZlgPAasDsB4WfIYESIAE8hCwOn9SwOTpBby3YwSsDsCOAWXGJEAClSFgdf6kgKlMFy53Ra0OwHK3CktPAiRQBgJW508KmDL0PpbR7FHYbFoSIAESaDUBCphWE2b6JJBAwOoAZKOTAAmQQKsJWJ0\/aYFpdc9h+k0hYHUANgUOEyEBEiCBCr4AUsCw25eCAAVMKZqJhSQBEiggAavzJwVMATsbi9SdgNUByLYmARIggVYTsDp\/UsC0uucw\/aYQsDoAmwKHiZAACZAAXUjsAyRQTAIUMMVsF5aKBEig+ASszp+0wBS\/77GEznEbNXsBCZAACdRJgAKmTnB8jASaQcDqAGwGG6ZBAiRAAkkErM6ftMCw35eCgNUBWAr4LCQJkECpCVidPylgSt0tq1N4qwOwOi3ImpIACXSKgNX5kwKmUz2K+eYiYHUA5oLAm0mABEigDgJW508KmDo6Ax9pPwGrA7D9JJkjCZBA1QhYnT8pYKrWk0taX6sDsKTNwWKTAAmUiIDV+bNQAmblypVu\/fr13brF2LFj3YoVK9yJEyfc3Llz3apVq9zAgQML2X2OHDmSWMYzZ864qVOnukOHDtXKv3z5cjd+\/Phu9dm2bZtbsGBBt883b97shg8f7s6dO+fmz5\/vRowYEfl8JwBJ\/VC+efPm1YogZZ04caIvO+p24MAB3649evRILarVAZhacd5AAiRAAg0SsDp\/FkrAhG0ULtBp4qDBNm7K42llxPfLli1za9ascb17907MM2qRP3jwoJszZ47btGmT69+\/f2EFzKlTp3wZRWhSwDSlezEREiABEshNgAImN7LGH4BF5uTJk7W39DRx0HiOjaeQVkYIkC1btmSyPEQJGC3qxo0bV1gB06tXL3f++efX6kkB03jfYgokQAIkUA8BCph6qDXwDBZ6CJiNGzfWLBVp4kAWyZ07d\/qcBw0a5J8\/ffp0F6tHuJjiXu2+mj59es39gXKIWwv5X3PNNe7aa6\/tVrOsbq48rpOsAgZWjn379nm3lNRZrDso\/6RJk2rl1e4qXWcpv7hzUNcpU6Z4AdmvX7+aNSXKBYbE5Z4+ffp4F9m0adPchg0b3IQJE7x7iwKmgcHAR0mABEigAQIUMA3Ay\/uoLJ6rV6\/28RJypQkYLPjHjh3z4iPKUiHxF6EbRwsF5KXjSkQASNxJWl3SyhjG+YTCQaef1YV0\/PhxL9QgPlB2iAkwgNiYPXu2W7hwoXflaFF4+PDhLpYglGvAgAFebIhIQRrgHyUm4zjoZ0UY6rIxBiatB\/F7EiABEmguAQqY5vKMTU2EhyzC+sY0caDvlYVULABa3EQJHVlYkYZ288CqEVqCklAklTGsW1JdkUc9QbwoKy4dQCvlRXpbt271YgcCBpaZKGEWurmiLFZZBAzEj5Rn5syZXlw1ImAkz1mzZjn84UUCJEACJBBNYN26dQ5\/5Dp69Kg5VIUL4tWLbBjkmiZgtLsEAqhv3741F4a2usC1MWrUKG9diHOJiCsGC70WMKFLRnpEVhdS2IOSrBtp7qaoXUhawIQutZEjR7qzZ8\/W3HJhXUTMxAknuJ\/GjBnTbRcV6hS6kMR6I9a0pUuXuh07djQkYCwOQHMzCitEAiRQOAK0wLShSdIEShbrhmwpDhd3+f\/ll1\/u9uzZ4xYvXuxja9KsC3ncJ0CUVocoARMX1NuogAnLniaWtHUma6BxWJ\/Q\/SSWpN27d\/tbEV\/EbdRtGEzMggRIgAT+HwEKmBZ3hdDlE5VdFgEjriexLuigVbEshHEnoVDQu5+a6UIKF\/e0OjdDwIRbriVeZu\/evV3OYdFuI4g6BOKGVpQwJimqjaIEjLYEaSsPz4Fp8aBi8iRAAiTgnKOAaXE3iHPNaPcE\/i07Y3RxZNeQTgOfySXxIOLOmDFjRreD33Rwrd7JU48FJqmMoctK73gKg24bFTBaOEDYIZgX7jM5CFDXWe80EkuSrkfcYXtZLDC4JwyGTovvCdO1OgBbPKyYPAmQAAlQwFjoA6FAKGKddu3a5XcMFfWk4U4xo4DpFHnmSwIkUHYCVufPwgXxtrKj5DlErpXliEsbFhPEoWDnVJbj9TtRxk7laXUAdoon8yUBEqgOAavzZ2UEDNwlOOBOH29fne5b\/ppaHYDlbxnWgARIoOgErM6flREwRe9gLF8yAasDkO1OAiRAAq0mYHX+pIBpdc9h+k0hYHUANgUOEyEBEiCBBAJW508KGHb7UhCwOgBLAZ+FJAESKDUBq\/MnBUypu2V1Cm91AFanBVlTEiCBThGwOn9SwHSqRzHfXASsDsBcEHgzCZAACdRBwOr8SQFTR2fgI+0nYHUAtp8kcyQBEqgaAavzJwVM1XpySetrdQCWtDlYbBIggRIRsDp\/UsCUqBNWuahWB2CV25R1JwESaA8Bq\/MnBUx7+g9zaZCA1QHYIBY+TgIkQAKpBKzOnxQwqU3PG4pAwOoALAJbloEESMA2AavzJwWM7X5rpnZWB6CZBmJFSIAECkvA6vxJAVPYLseCaQJWByBbmQRIgARaTcDq\/EkB0+qew\/SbQsDqAGwKHCZCAiRAAgkErM6fFDDs9qUgYHUAlgI+C0kCJFBqAlbnTwqYUnfL6hTe6gCsTguypiRAAp0iYHX+pIDpVI9ivrkIWB2AuSDwZhIgARKog4DV+ZMCpo7OwEfaT8DqAGw\/SeZIAiRQNQJW508KmKr15JLW1+oALGlzsNgkQAIlImB1\/qSAKVEnrHJRrQ7AKrcp604CJNAeAlbnTwqY9vQf5tIgAasDsEEsfJwESIAEUglYnT8pYFKbnjcUgYDVAVgEtiwDCZCAbQJW508KGNv91kztrA5AMw3EipAACRSWgNX5syZgjhw54qZMmeJOnjzZrRE2b97shg8f7lauXOm\/mzdvXmEbCmVcv369kzJLQc+cOeOmTp3qTp065TZt2uQGDhxYq8O2bdvcggULav9fvny5Gz9+fOY6huymT5\/ehRHyXrJkiVu8eLFPE+U4dOiQ\/3dSXmG5pEBSt3Pnzrn58+e7ESNG5Cpv5orVcaNwRn\/R\/UTKOnHiRN+XULcDBw64FStWuB49eqTmZHUAplacN9RNYN26dbVn77zzTjdr1iw3bNiwutPjgyRQVgJW589EC8zBgwe9aNm4caPr3bt3aQTMfffd5y6++OIuCyjqMmnSJNevX78uAgb1g2iThVQWWnTULIurLNhYrLEwy\/8nTJhQExUQOLfddpu75ppr3NKlS2uCQ4TP6tWr\/bPhFbXIox5z5szxdejfv39hBUwoFClgyjr1lbPcIl4gWuSK+qyctWOpSSAfgcoJmKjFtSwWmAceeMDdf\/\/9bs2aNV544YIY+O53v+vuvfdet2rVKm+BCQWadIlQlOTrKq6b0EPeuEKrTpoFJUrA6GfGjRtXWAHTq1cvd\/7553cThrTA5O1NvD8vAVhbMLa1eKGIyUuR91siUCkBE7ewpgkYcd+g4bWlA58PGDCgtoBjctmyZUttcdOukrFjx9Y+h4hatmyZw2K4c+dOb3XYvn27\/3d4aTfXBRdc4O655x4niyXqc8MNN3jLx4YNG2oCJqk++jsROqNHj3Zr1671WYcuKl0e\/WxoedD3oX5z586tlSeLBSZKwECM7du3z7ulBg0aVLOYIT2xPEna2mWl20tzx73aLabbUsSduMAkXbmnT58+3kU2bdo0z1osUbTAWJoOi10XWFoxPuMuWGKixE2xa8XSkUD9BColYEK3imBLWvBDURIKAC1YtKBJclPJIjpjxozMMR6StpQZVg9x4Vx55ZXu+uuv94Ihzf2irR9YrDEpSmyLduPoWBq98ItbSMe\/iDVIFnMIsTBeRnfRrC6k48ePe9GCWBLExEBMwKWFvGfPnu0WLlzYzeJ0+PDhLiJSt0logYqzVEUNJ\/0svhcXpJStEQuM5IfFp6gLEN7+dexF\/VMOn6yXAPprlEtW0kv7vt58+Vx2AohFKuoYzl6LYt+JeUjPRUePHi12gesoXbcYmKTFOc0CI\/nLAh21kOINXS+qoXVGrC5w\/5w+fTrRQhFVX0lvyJAhPu5k0aJF7vbbb3fHjh1zV1xxRS29vAJG4k4gWOIsVFEBrOC5f\/\/+yMDnkFNYn3qCeJPaCOlt3brVix0IGHlTDSf7UIwmWZHCMofiR8ozc+ZML64aETBlGIAQMLw6SyBNoNAC09n2Qe4Mpm5vG1QAvaL1AAAgAElEQVTCAhMVgKoxJy2Oocuhb9++\/i1IdqJECQukjUUtdAmJOwLfaxeLtlyEza9dSHBXjRkzxgulq6++2t16661+4YR40unldSFJMLNYFrRbLG73TVz8i34b1IHSaRYY\/X2UkIpyXwnfkSNHurNnz9ZcTKF7SRjGCSe4n8BV76KS8oQuJAlqln6B4OUdO3aYFzDtnZaYWxSBpGBdfId5iQso+06VCFRCwKRZWLIu+LLA428RMPJWP3jwYNezZ8+aSyi0wOhOlRYjkmSBgesIaeuA3tCikzWIN7RKhcIhTvhJ7M3kyZO7bNvOKlLSthqnCZiwfkmuoNA6o11+eQZ6VAA00t69e7dPBi4zbqPOQ5T31kOAu5DqocZnrBIwL2D0AiaxGmFjpgkY2Y584sQJf6YMAkNFwOjgTx0AGy6quhyNuJAgYMTCIHEmUYIoyzZqSUcCYKO2Mou7LBRg4sZCDEhW4SNpNEPAhFuuJV5m7969Xc5h0W4jlBNWltCKErfdW9c5SsBoy5m28vAcGKvTZTHqJfFI2trCuItitA1L0V4CpgVMkmtG3pqxmOldK6HrAP+Xg\/AgXGBpwU4gfZYKnsdCqV0xeE67LPSOl0YtMOFiGpde2kF2IrIuvPDCmrtLFuK4AwDBADE3eFYf6Bbu4tFBvGHQbaMCRrcruCKYN9yFhUP\/cIXn44T1ynq4X9wWdBGBaW6quN1dVgdge6cx5kYCJFBFAlbnz7b+lAAWZATTFvkk36jOnWcXTqODY9euXd7dFO5uajTdsj9vdQCWvV1YfhIggeITsDp\/tk3A5NnJUrTu0C4BA0bYJYSzU7Icr180Tq0sj9UB2EpmTJsESIAEQMDq\/NkWASPuCB0TU6Zu1S4BUyYm7S6r1QHYbo7MjwRIoHoErM6fbREw1esurHGzCVgdgM3mxPRIgARIICRgdf6kgGFfLwUBqwOwFPBZSBIggVITsDp\/UsCUultWp\/BWB2B1WpA1JQES6BQBq\/MnBUynehTzzUXA6gDMBYE3kwAJkEAdBKzOnxQwdXQGPtJ+AlYHYPtJMkcSIIGqEbA6f1LAVK0nl7S+VgdgSZuDxSYBEigRAavzJwVMiTphlYtqdQBWuU1ZdxIggfYQsDp\/UsC0p\/8wlwYJWB2ADWLh4yRAAiSQSsDq\/EkBk9r0vKEIBKwOwCKwZRlIgARsE7A6f1LA2O63ZmpndQCaaSBWhARIoLAErM6fFDCF7XIsmCZgdQCylUmABEig1QSszp8UMK3uOUy\/KQSsDsCmwGEiJEACJJBAwOr8SQHDbl8KAlYHYCngs5AkQAKlJmB1\/qSAKXW3rE7hrQ7A6rQga0oCJNApAlbnTwqYTvUo5puLgNUBmAsCbyYBEiCBOghYnT8pYOroDHyk\/QSsDsD2k2SOJEACVSNgdf6kgKlaTy5pfa0OwJI2B4tNAiRQIgJW508KmBJ1wioX1eoArHKbsu4kQALtIWB1\/qSAaU\/\/YS4NErA6ABvEwsdJgARIIJWA1fmTAia16XlDEQhYHYBFYMsykAAJ2CZgdf6kgLHdb83UzuoANNNArAgJkEBhCVidP+sSMEeOHHFTpkxxJ0+e7NZgmzdvdsOHD3crV670382bN6+wjbpt2za3YMECt3z5cjd+\/PhaOc+dO+fmz5\/vdu7c6aQ+8uXBgwfdpEmTavdOnz49Vx3PnDnjpk6d6g4dOlRLI8xfvpDyhQClTFLOESNGdCl\/J4FL\/dAHdNtLWSdOnOj7B+p24MABt2LFCtejR4\/UIlsdgKkVr9AN69atq9X2zjvvdLNmzXLDhg2rEAFWlQRaQ8Dq\/FmXgIlCjIUdomXjxo2ud+\/epREwW7dudZdccolbtGhRbSHVAk0LGCy6uF\/qCA6oM+quP0vqgkh72bJlbs2aNZ5T0hW1yCOvOXPmuE2bNrn+\/ft7oVVEAXPq1ClfxoEDB\/oqUsC0ZmKykqqIF4gWuaI+s1Jf1oME2kmAAiaBtiz4q1ev9m\/XsrDj76JbYGAFOHv2rFu4cGFtsYVI2LJlizt+\/LgvP+qEOs6dO9etWrWqdp9emLOKCEk7i+UhSsBoq8u4ceMKK2B69erlzj\/\/\/JqFhQKmndNVufKCtQXjQosXiphytSFLW2wCFDAx7RPnxkhzIYWuGHGj4LkBAwbUXCLhgq+tI\/369au95Us58Nn69eu9m+YXv\/iFdwOFl1hVIBCOHTvmv9Z5ogyXXnqp27BhQ03AJLk89HdwDeH50aNHu7Vr1\/q0QytOVtdJVgEDK8e+ffu8W2rQoEFdrEFxnEVkghWusWPHdnHnxHGOcoHheWmLPn36ePbTpk3z\/CZMmODbkgKm2BNcJ0sHlyzGSNwFS0yUuOlkmZk3CZSJAAVMTGthsUYsTGhRSBIwWARnz55ds3po99Phw4e99UPS04JGFk+xiujnEEcBdwquLNYN3CcCZtSoUW7\/\/v1erCCPJUuWuJkzZ3pXjeSVVJ+w\/JiQJTZGu3wgNJCOiIYo4aAxZ3UhwVIEF5YwgJiQujSbc5rbS7eRiCRdtkZiYIQNFrNmLWjy9l+mychaWdEGSbEuad9b41HE+jRrvBWxblbLBOGv48qOHj1qrqoNxcCEi7Omk2aBCRdqiS3B57Lo4m0+XIC1uNFv9bA85I0HEQEDawFEy+LFi50IKLiLrrrqqroEjMSoQLBEuXxEYGirUZSrrZ4g3iTuOoYH9ZQ3X3H7SZuEVq\/QepI0CkKRKeWBIET7NCJgWjEAKWA6P6elCZS07ztfA\/slwBzBgOrytjMtMEHbyUIlLoKwaZMWUr3LB8+NHDnSx6HoAGC4dIYMGeJuu+22WoBt3IIO91MYDxLmocsXupD04gpLDPIeM2aMd4WIBSavCykM9NUuKl2WMPg5zQKjv49y32nuaZxD95Lmgt1Z4QXOwkXvosJ9oQtJxw5hx9rSpUvdjh07Cidgyjsl2Sl5UrAuvuPiaaetWZPOEKCACbinWViyulzgkggXcbEADB482PXs2TM2HiZtMU\/rKmKBwWIrAkUCeiWWI28Qb2iVStvqnBTUm7bVOE3ARHHVO8XirGChGy+No\/4+tMDgO9Rj9+7d\/ja41riNOg\/RatzLXUjVaGfWsjMEKGAU96jtxHksMFFbgSWOA4JGB4rqANhwcdS7nxpxIUGkSFpDhw71MTQQB9oCIwtx2jZqsWpIULKuayiK0qxYzRAw4ZZr4bx3794u57BoIRXWPWqXWdwwjBIwUefqpNUtTN\/qAOzMdFbMXOEqgpDRrgrGXhSzrViqchGwOn\/mjoFJcs3IGzYEQRisqt0Mcn4JdgjB9YAtzNixorcox52vEh6iJ0IhzdIR1d20BSZ8PmohRhppB9mJ1ePCCy+s7YCKEmHigtEH4YXBzWmLfJoFRrdVFGfdRnpHF+oZxzlt2KZxS3NThQcHSn5WB2AaT35PAiRAAo0SsDp\/5hYwjYLM+rwWF1mfKcJ9STEtWcq3a9cuf86MHACX5Zkq3GN1AFah7VhHEiCBzhKwOn8WUsDk2fXS2W7RPfdGBAzqDRcVAqOzHK9ftLq3sjxWB2ArmTFtEiABEgABq\/Nn4QSMuC5wsFqRT\/GNGxaNCBgOtXgCVgcg25wESIAEWk3A6vxZOAHT6oZk+uUkYHUAlrM1WGoSIIEyEbA6f1LAlKkXVrisVgdghZuUVScBEmgTAavzJwVMmzoQs2mMgNUB2BgVPk0CJEAC6QSszp8UMOltzzsKQMDqACwAWhaBBEjAOAGr8ycFjPGOa6V6VgeglfZhPUiABIpLwOr8SQFT3D7HkikCVgcgG5kESIAEWk3A6vxJAdPqnsP0m0LA6gBsChwmQgIkQAIJBKzOnxQw7PalIGB1AJYCPgtJAiRQagJW508KmFJ3y+oU3uoArE4LsqYkQAKdImB1\/qSA6VSPYr65CFgdgLkg8GYSIAESqIOA1fmTAqaOzsBH2k\/A6gBsP0nmSAIkUDUCVudPCpiq9eSS1tfqACxpc7DYJEACJSJgdf6kgClRJ6xyUa0OwCq3KetOAiTQHgJW508KmPb0H+bSIAGrA7BBLHycBEiABFIJWJ0\/KWBSm543FIGA1QFYBLYsAwmQgG0CVudPChjb\/dZM7awOQDMNxIqQAAkUloDV+ZMCprBdjgXTBKwOQLYyCZAACbSagNX5kwKm1T2H6TeFgNUB2BQ4TIQESIAEEghYnT8pYNjtS0HA6gAsBXwWkgRIoNQErM6fFDCl7pbVKbzVAVidFmRNSYAEOkXA6vxJAdOpHsV8cxGwOgBzQeDNJEACJFAHAavzZyEFzJEjR9yUKVPcyZMnuzXV5s2b3fDhw93KlSv9d\/PmzaujOdvzSFoZ8f369et9Yfr16+c2bdrkBg4c2K1wcTymT59eq\/\/Bgwc9k40bN7revXu3p4IpuWzbts0dOHDArVixwvXo0cPffe7cOTd\/\/ny3c+fOyKeXL1\/uxo8f3+07qwOwEA3FQpAACZgmYHX+LKSAiepJ4QKdJg6K0BuTyhgu7vj\/1q1bIwUIBMzcuXPdqlWragLnzJkzburUqW7ChAl+wS+LgNHtImJmxIgRkaJF32t1ABahn7IMJEACtglYnT9LIWDEArF69WpvfcFVdgETDpcokSL3xH2nRdChQ4dKYYGhgLE9UbJ2JEACxSNAAdOhNol7S08TMHHuGXw+YMCA2hs\/LBdbtmypuTm0u0a7dfD5smXLXK9evbz7A+6e7du3R7pC6nFzNUvAjB492q1du9a3lnbHhK6bQYMG1aw9oYtKyi9NrllqtxUE1IIFC7r1DLknyoVEAdOhgcRsSYAEKkuAAqZDTY\/FE7EwOo4izQITihItdqK+E0EjbhnE1cDSo90yp0+f9nE5M2bMSHV36IUf\/84SpxNXTzyf1YU0adKkmmhB2efMmVOLq4GYOHbsmC+LFoXjxo3zMSkTJ070dRahtmbNGh9Lo0UIyoJ7s7h8cC8FTIcGDbMlARIgAUWAAqYD3SFchHUR0iwwcq8s1rCmYPGGSJk9e7ZbuHCh69OnT+3fCJ4NxY08i8Ud94ZxKGlIspYRC\/1NN93U1CDeJIuOjp8RAYO6hCJR119cdyGjJAbNFjCS16xZsxz+8CIBEiABEogmsG7dOoc\/ch09etQcqsLGwIRBqiH5JHEQuoH69u3rrQtiCRE30pAhQ9xtt93mFi1a5HfJxLlE4IrBvVrAJO2myeNCShMvcRaYkEcYxBsKGHwPCw0uiDkwkQDgsC5jx471YgafI1AY8TX6EvfT3r176UIyNyWwQiRAAtYI0ALT5hZNs14kfR9+F\/5frAiDBw92PXv2jI2H0VVOsmjEoUmrQ9LOo7x5JwmY\/v37d3H9JO3+ibLOiHspbxdotgXG4htEXqa8nwRIgATyEqCAyUusgfuzLOxpAkbiZk6cOOFjV2BVEAuMLNKwLOiA1TAGRu9+arYLKck9FqLLIp6yCBhxo4k1BpalMWPGeCuLxP2EbqNQhCTF6oTlpoBpYBDwURIgARJoEgEKmCaBTEsm7aAz2eGid8ZImrJrCP+Xg\/AgXGBpueeee7rEeOB5LOThwW\/hjhzZyZNFRIR1SyojdjDJIXb6ORFUOug2S955XEhgKBeES1hnvdMI9+l66N1LaW0Z55KTOvIcmDSC\/J4ESIAEGidAAdM4w0KloAVCoQr2\/woDaxC2a0+ePLmIxWt7mawOwLaDZIYkQAKVI2B1\/ixsEG8re1jU7ppW5ldP2rCo4JLdP\/WkYekZqwPQUhuxLiRAAsUkYHX+rJyAEXeJjokpZpdjqTQBqwOQrUwCJEACrSZgdf6snIBpdUdh+q0hYHUAtoYWUyUBEiCB\/0\/A6vxJAcNeXgoCVgdgKeCzkCRAAqUmYHX+pIApdbesTuGtDsDqtCBrSgIk0CkCVudPCphO9Sjmm4uA1QGYCwJvJgESIIE6CFidPylg6ugMfKT9BKwOwPaTZI4kQAJVI2B1\/qSAqVpPLml9rQ7AkjYHi00CJFAiAlbnTwqYEnXCKhfV6gCscpuy7iRAAu0hYHX+pIBpT\/9hLg0SsDoAG8TCx0mABEgglYDV+ZMCJrXpeUMRCFgdgEVgyzKQAAnYJmB1\/qSAsd1vzdTO6gA000CsCAmQQGEJWJ0\/KWAK2+VYME3A6gBkK5MACZBAqwlYnT8pYFrdc5h+UwhYHYBNgcNESIAESCCBgNX5kwKG3b4UBKwOwFLAZyFJgARKTcDq\/EkBU+puWZ3CWx2A1WlB1pQESKBTBKzOnxQwnepRzDcXAasDMBcE3kwCJEACdRCwOn9SwNTRGfhI+wlYHYDtJ8kcSYAEqkbA6vxJAVO1nlzS+lodgCVtDhabBEigRASszp8UMCXqhFUuqtUBWOU2Zd1JgATaQ8Dq\/EkB057+w1waJGB1ADaIhY+TAAmQQCoBq\/MnBUxq0\/OGIhCwOgCLwJZlIAESsE3A6vxJAWO735qpndUBaKaBWBESIIHCErA6fxZSwBw5csRNmTLFnTx5sluH2Lx5sxs+fLhbuXKl\/27evHmF7TRpZdy2bZtbsGBBrfyDBg1yGzdudL179+5Spzge06dPr9X\/4MGDnknU850ChPodOHDArVixwvXo0cMX49y5c27+\/Plu586dkcVavny5Gz9+fLfvrA7ATrUN8yUBEqgOAavzZyEFTFS3ChfoNHFQhK6ZVkZ8P2DAgMgFW5cfAmbu3Llu1apVbuDAgf6rM2fOuKlTp7oJEyb458siYHS9RMyMGDEilYHVAViEfsoykAAJ2CZgdf4shYARC8Tq1au99QVXmjgoQndMKqMs3hMnTqzVKa7MUQIG92oLx6FDh0phgaGAKULPZBlIgASqRIACpkOtHfeWniZg8P369et9qfv16+c2bdrkrReh1QOWiy1bttTcHNpdo5\/D58uWLXO9evXy7g+kt3379khXSBY3l1hQ4AITUdYMATN69Gi3du1an5R2x4SuG+2uCl1UUn4pj2ap3VahC0zul3uiXEgUMB0aSMyWBEigsgQoYDrU9Fg8EQuj4yjSLDChKNFiJ+o7ceOEokK7ZU6fPu3jcmbMmJHq7tALP\/4dFacTFdcSCgdJJ6sLadKkSTXRgrLPmTOnJtwgJo4dO+bLokXhuHHjfEyKWIJEqK1Zs8bH4mgRgvLg3iwun9BCJDEwFDAdGkjMlgRIoLIEKGA60PThIqyLkGaBkXtlsYY1BYs3RMrs2bPdwoULXZ8+fWr\/hnUmFDfazYN7wziUNCRJZQzrllTXeoJ449xOKLOOnxEBg89DkRjl5goZJTFotgVG8po1a5bDH14kQAIkQALRBNatW+fwR66jR4+aQ1XYGJgwSDUknyQOQjdQ3759vZtGLCHiRhoyZIi77bbb3KJFi\/wumTiXCFwxuFcLmKTdNFlcSGF9kgJak8SIpBMG8YbP4HtYaHBBzIGJBACHdRk7dqwXM\/gcgcKIr9GXuJ\/27t3bZReV3EMXkrl5ghUiARIoMQFaYNrceGkWlqTvw+\/C\/4sVYfDgwa5nz541l1CSdSGLiMgjsuIETFRQb5a8kwRM\/\/79u7h+ksRSlHUmS6BxVPdotgXG4htEm4cVsyMBEqggAQqYNjY6Fr6tW7cmnmmSJmAkbubEiRM+dgVWBbHAyCINy4KOOwljYPTup2a7kMLFPanOzRIw4kYTawwsS2PGjPFWFgkmDt1GYTnjYpIoYNo4QJgVCZAACeQgQAGTA1Yjt6YddCbuCb0zRvKTXUP4vxyEB+ECS8s999zTJcYDz2MhDw9+C+NNZCdPFhERZYGRnVBhGRFzo11WescT7tVBt1nyzuNCAkO5IFzCOuudRrhPs447bC9OwOiD+uQeEY08B6aRkcJnSYAESCAbAQqYbJxKc5cWCEUsNKxB2K49efLkIhav7WWyOgDbDpIZkgAJVI6A1fmzsEG8rexheQ6Ra2U5ktKGRQVX2hkxnSpfu\/O1OgDbzZH5kQAJVI+A1fmzcgJG3CU6JqZ63bl8NbY6AMvXEiwxCZBA2QhYnT8rJ2DK1vFY3v9LwOoAZPuSAAmQQKsJWJ0\/KWBa3XOYflMIWB2ATYHDREiABEgggYDV+ZMCht2+FASsDsBSwGchSYAESk3A6vxJAVPqblmdwlsdgNVpQdaUBEigUwSszp8UMJ3qUcw3FwGrAzAXBN5MAiRAAnUQsDp\/UsDU0Rn4SPsJWB2A7SfJHEmABKpGwOr8SQFTtZ5c0vpaHYAlbQ4WmwRIoEQErM6fFDAl6oRVLqrVAVjlNmXdSYAE2kPA6vxJAdOe\/sNcGiRgdQA2iIWPkwAJkEAqAavzJwVMatPzhiIQsDoAi8CWZSABErBNwOr8SQFju9+aqZ3VAWimgVgREiCBwhKwOn9SwBS2y7FgmoDVAchWJgESIIFWE7A6f1LAtLrnMP2mELA6AJsCh4mQAAmQQAIBq\/MnBQy7fSkIWB2ApYDPQpIACZSagNX5kwKm1N2yOoW3OgCr04KsKQmQQKcIWJ0\/KWA61aOYby4CVgdgLgi8mQRIgATqIGB1\/qSAqaMz8JH2E7A6ANtPkjmSAAlUjYDV+ZMCpmo9uaT1tToAS9ocLDYJkECJCFidPylgStQJq1xUqwOwym3KupMACbSHgNX5kwKmPf2HuTRIwOoAbBALHycBEiCBVAJW508KmNSm5w1FIGB1ABaBLctAAiRgm4DV+ZMCxna\/NVM7qwPQTAOxIiRAAoUlYHX+jBQwK1eudOvXr+\/WGGPHjnUrVqxwt99+uztw4ID\/d48ePQrZaEeOHHFTpkxxQ4cO7VbObdu2uQULFrjp06e7efPm1cp\/5swZN3XqVHfo0CH\/2aBBg9zGjRtd7969M9UxfF54aUbIG9f48eOdlCMtL6nLyZMnu5RDl\/\/gwYMO7ZanvJkq1cBNqF\/YT86dO+fmz5\/vdu7cGZny8uXLPZvwsjoAG8DLR0mgEATWrVtXK8edd97pZs2a5YYNG1aIsrEQ\/5eA1fkzkwVGFp0RI0bUFt4yCJi5c+e6Xr16ueuuu84NHDjQN6ReQLUAEJGwevVqN3z4cH8vRMGkSZPc5s2ba5\/FDYiQkfy\/X79+XUQSRMaoUaN8Mlpw4N8QKFGiEGVDXVatWlWrh4ilCRMm+DYpi4DR\/EJmSZON1QHICZYEykxAxAtEi1xRn5W5jhbKbnX+zCRgwsU16s26aI2MRX\/ZsmVewIjwQhmx8C9ZssQXV8RF0kLaSF3DZyXvxYsXd7PqJAmQKAGD8uv0YTUqgwWGAqZoI4XlIYH6CMDagnlLixeKmPpYtvqpygqYqIU1bVEPXR5i6RBRsWbNGr+Ai3CYOHGit3CELhht+cDi\/MADD7g77rjDu4WuuOIK7yIKL3HbnDhxwguYK6+80u3Zs6dm2UB99u\/fX3sMLqQ4gYCb9Hf9+\/f37g9Yc\/bt2+ddTVFuIkk85IS8t2zZEmllQf1waZeWpJNHwIwePdqtXbvWP6rdMaHrRrvHwvYKLU7apaitVtoFpttB7knrJ7TAtHraYvok0DoCYp2OywGWmChx07oSMeU4ApUUMFFulfDNP4yBCUVJlAAQwaIFDdKBOBBrSbhoYxGFAMga4yFpw3104403OrF6iAtHRAwEQ5L1Q0QV7sOijzLeddddbtOmTU4ETegmEksP4mnExSPc8LeO8RA3FdJAmuLq0h0xqwsJE4qIFqQ7Z86cWpoQE8eOHfMCSQuHcePG+TpFtQlEphYhKJNuo7TpotkCRvLDpMiJMY0+v2+UACwMOr6j0fSsPY85RtztUXVL+94ajzz1QYxQq+cw9F3df48ePZqniKW4N9aFFBfDkSZgwlonLaR6UQ2tM0gHYmPAgAF+wU+yUESR1ult2LDBx51cdNFFbvbs2W7hwoVu+\/bt\/rF6BIwWLFHiR9ghfYlpwWc33HCDmzx5cqRICTmFAgbWpjxBvElWJR0\/IwJGl1XyDsUoPk+yIoXt0GwBY3EAlmKWqHAhIWJ4RRNIEyi0wCT3nHYGOlfOAoPFZ+vWrZEWj7SFSbscYLXAJQGoUcICKl4sEWGTizsiFDBx94cuJLir9u7d660PEDHiwoFVRgRMXheSjqmJc4uFgiAp\/gX3JrlTksonvEIhFT6jeUGA9e3bt2YdCt1LwhCf611Zkpe4n8AVu7ni2iytn9CFxKWRBMpLIClYF99hXm\/nIl1ekq0veaUETNqCmbQwhc+G\/5dF6\/LLL\/exKeLaibLA6GZtxAJz+vTpbgG9Or2sQbwoD1wocRYYcYNFuZQk9iYqxgXpaldVaJZNaw+xjOgg3ijXnQivpPpGWWfEvZR3mFHA5CXG+0mgXAS4C6kc7VUZARNuz41qnjQBA3eHbEfGooozP3R8hwR\/6gDYcFENy9GIgBFhIbEriDMJ08uyjVrKePz4cW+ZCgVL0lZoib3RW7S14EiyeDVLwIiwEmsM4mXGjBnjrSwQVihb6DYK2zqpjmFfoYApx+TGUpJAIwQkVkhbW1od39FIeav4bGUETJxrBo0ugaZ33313pOtAdq9oF9LNN9\/sEIMiCyTSEbEwY8aMLgGt4S4kveOlEQETBqNCeESll3aQnSzu5513nt8NhZiULO4WMLjlllu6xb\/oXTxhEG8YHxSeAxMOwjwuJHCVS3Zh6Rib8IC\/0CWYNZA6bpeS9BO6kKo4lbLOJEAC7SZQGQHTDrAQChJMG7Xrph1lqCePPAtuPenrZ8AIlisE\/fKye5Ik25YESIAEWk2AAqaJhPPsZGlitg0n1U4BA0a4krYpNlyhEiVgdQCWqAlYVBIggZISsDp\/ZjqJt5ltFhUT08z0W5lWOwVMK+tRxrStDsAytgXLTAIkUC4CVufPtguYcjU7S1sUAlYHYFH4shwkQAJ2CVidPylg7PZZUzWzOgBNNRIrQwIkUEgCVudPCphCdjcWKiRgdQCypUmABEig1QSszp8UMK3uOUy\/KQSsDqcUwZIAACAASURBVMCmwGEiJEACJJBAwOr8SQHDbl8KAlYHYCngs5AkQAKlJmB1\/qSAKXW3rE7hrQ7A6rQga0oCJNApAlbnTwqYTvUo5puLgNUBmAsCbyYBEiCBOghYnT8pYOroDHyk\/QSsDsD2k2SOJEACVSNgdf6kgKlaTy5pfa0OwJI2B4tNAiRQIgJW508KmBJ1wioX1eoArHKbsu4kQALtIWB1\/qSAaU\/\/YS4NErA6ABvEwsdJgARIIJWA1fmTAia16XlDEQhYHYBFYMsykAAJ2CZgdf6kgLHdb83UzuoANNNArAgJkEBhCVidPylgCtvlWDBNwOoAZCuTAAmQQKsJWJ0\/KWBa3XOYflMIWB2ATYHDREiABEgggYDV+ZMCht2+FASsDsBSwGchSYAESk3A6vxJAVPqblmdwlsdgNVpQdaUBEigUwSszp8UMJ3qUcw3FwGrAzAXBN5MAiRAAnUQsDp\/UsDU0Rn4SPsJWB2A7SfJHEmABKpGwOr8SQFTtZ5c0vpaHYAlbQ4WmwRIoEQErM6fFDAl6oRVLqrVAVjlNmXdSYAE2kPA6vzZsIBZuXKlW79+fbdWGDt2rFuxYoU7ceKEmzt3rlu1apUbOHBge1orZy5HjhxxU6ZMcUOHDvVl7tGjRy2Fbdu2uQULFrjp06e7efPm1T4\/d+6cmz9\/vtu5c6f\/rF+\/fm7Tpk256ihpS6KDBg1yGzdudL179+5SAynfyZMnu3yuy3Tw4EGHtoh6PieOpt2O+h04cKAL05BbmNny5cvd+PHju5XB6gBsGmwmVCOwbt262r\/vvPNON2vWLDds2DASIoHKErA6fzYsYMIeIQvUiBEj\/EKExbcMAgZl7NWrl7vuuutqIkQvtlosnDlzxk2dOtVNmDChttiKyJgxY0bkAhw1ciA4BgwYkHp\/FMOwDGURMJpD2FeSZherA7CyM2qLKi7iBaJFrqjPWpQ9kyWBQhKwOn82XcBgUYalQCwZZREwy5Yt8wJGhBd6IUTCkiVLahYWscCgjri0RQb\/zyMiZPGeOHGiGz58eGKnj2OoLRyHDh0qhQWGAqaQ85uJQsHagjGoxQtFjImmZSUaJEABkwFg1AKeJmBCl4K4UU6fPu0gKtasWeNdKlELvnZfhe4UcWsh\/2uuucZde+213Wqg3VzI68orr3R79uypiS\/UZ\/\/+\/bXnIFjE8oF\/h8JDf4d6wMUEt9m+ffscBIbkBxdVUjphQfMImNGjR7u1a9f6JLQ7Jo4z2IYuqs2bN3epWxzn0AUm5Za2iHIhUcBkGEi8pS4CkyZNcui7cRcsMVHipq7M+BAJlIgABUxKY8kiuHr16i6LX5qAwSJ37Ngxb83QLoVx48Z5ASAWCqSjBY1eHFE03CvWEwgPmczSrBt4VtKG++jGG290ixcv9qIJC\/eoUaNqIgZlTKpPVPnvuusuHxvTv39\/X0bEykg6iLvRcS2hcBDkWV1IqLOIFjCYM2dOLS6nFZzTxm+zBYzkh0WoiguRWBjSuFf1e\/BJinVJ+76q3FBvzJOME7LVAyDYdTzY0aNHbVXQOdcUF5Is3LI4a0ppAkbfG8Z16EU3agHW7hcs2Fu2bPHWk7zuFC2ONmzY4EXLRRdd5GbPnu0WLlzotm\/f7otZj4DRTLSF6vDhw10ERig4Qoah2MH3SUG8Sdw1ZxGKSC8MYI6yemnOOtg5amQ0W8BYHIB5ZxQ9IeV91vr9aQIl7XvrfNLqV8WXgjQmVr6nBSahJbFQbd26NXYHTVIQr1hLkDwW+759+9aCY6OEBd4UZAGGUNGXuJ8gDvSOHJ2Hvj90IcFdtXfvXm8RgogRQQSrjAiYvC4kHVMTWpF0WZICWrOIwNB9Fz6TxDl0LwkXfI5g5TjOYIUdWuFFF5KVaa9c9UgK1sV3tDKUqz1Z2uYRoICJYZm2uGZ1uWDHUriIy\/8vv\/xyH5sirp20ANg8wbSolhYWEnujA3rDoN0sQbywTmiXEfJJKldSndIYR6WtnxH3lYipJLEUZZ3JEmhMC0zzJhumVD8B7kKqnx2ftEuAAiaibaO2E4e3ZREw4mYRK4EOPpVAUR0AizxC94Te\/dSIC0mEh8SuIAg3FCxZtlGLSDh+\/Li3TIWCJix\/I1asrAImivOYMWO8lUWCkkMhlcSZLiS7E16ZawZXEYSMjumge6TMLcqyN0qAAiaCYJxrBrfKwW74d1L8hk4Drge5ZIty0vkqeneMPgSuEQsMgnejFm2UK89BdiIEzjvvPHfHHXf4YN0oESYumPAgPB3z06gFBiIsiXO4Cyk8tC+Oc9qgitulJMHKPAcmjSC\/JwESIIHGCVDANM6wrhRg7ZBg2qKe5BtVsTyLc9TzqDdO+Z08eXJd3Kw9ZHUAWmsn1ocESKB4BKzOn03ZhdTK5sqz66WV5cibdqMCBvXGlWUbeN6ylfF+qwOwjG3BMpMACZSLgNX5s9ACBq4LWCHy\/sZQEbpWowKmCHUoUhmsDsAiMWZZSIAEbBKwOn8WWsDY7EqsVT0ErA7AeljwGRIgARLIQ8Dq\/EkBk6cX8N6OEbA6ADsGlBmTAAlUhoDV+ZMCpjJduNwVtToAy90qLD0JkEAZCFidPylgytD7WEZndQCyaUmABEig1QSszp8UMK3uOUy\/KQSsDsCmwGEiJEACJJBAwOr8SQHDbl8KAlYHoMDHybGWT4tl\/UoxzGILyfYrd\/tZnT8pYMrdLytTeqsDUBqQ9St3V2b7sf2KTMBq\/6SAKXKvY9lqBKwOQAoYG52c\/bPc7cj2K2f7UcCUs90qV+pJkyb533PiRQIkQAIkkI8ATnTHb9BZuyhgrLUo60MCJEACJEACFSBAAVOBRmYVSYAESIAESMAaAQoYay3K+pAACZAACZBABQhQwFSgkVlFEiABEiABErBGgALGWouyPiRAAiRAAiRQAQIUMBVoZFaRBEiABEiABKwRoICx1qKsDwmQAAmQAAlUgAAFTAUauehVXLlypVu\/fr0vJs4qwJkFcVfSvdu2bXMLFiyoPTpo0CC3ceNG17t378IiyFP3IlXizJkzburUqe7QoUMuC+e4ep47d87Nnz\/f7dy5s1a96dOnu3nz5hWpur4sR44ccVOmTHEnT550Y8eOdStWrHA9evRILCfOLtqyZUume9td4bxtiPJJe02cOLE2TsvShnnaT\/fXfv36uU2bNrmBAwe2u4kS88vTfrruSFSPsbK0XxQMCphCdcnqFQYTPCYLCI3Dhw\/X\/h0lOtLuRToDBgxw48ePLwXItPoUuRJgjQtCQ\/87qsxJ9cQkPHv2bLdw4cLCLRC6LjLJjxgxwo0bN86LLvw7qa+h3jiAMavYaXd752lDLV4gNvWLRhnaME\/74UXowIEDNdGJ\/2\/durVwL0NZ20+EDsYqXg7l\/xMmTPD9twztFzc2KGDaPWswvy4E9CCMervTNyfdm\/ZsEbHnqXuRyh9OiHi7W7ZsmVuzZk2ktSupnmnPFqXeKOfcuXPdqlWrvNBKs6ygzljoL7vsMvfAAw8UzgKTtw3lDX7o0KHu+PHjXriKpbQMbZi3\/XS\/C58tQp\/M235hmfWYLEP7UcAUodexDF0I6LcivAmE\/497A466NxzQRUedp+5Fq0s4oSdN8Gn11NaZIrv6wnKmlRvfY4EP3+aL0pZ52hBlvv\/++33R4TKD61ALmDQWRahz3vYruoDJ235JAqYM7UcBU4RRxDJEChjtT49zA0VZWPS9oY8XGaXF03SyOdLq08mypeUdvrElmaDT6lmWuKXQ4pL1rbXIAkZbzbK6EaJeFMrQhvW2H8YC5hnEPWWJeUobO836Ps8YDPOUuXL16tU1kV222EGpE11IzepRTCc3gbTFLcoCEyd2MEHNmTOnFmwX\/j934Vr8QJ66t7gouZPPM3mm1TNcHIq4WABQvQtgFQRMGdqwkfa76aabChfEm2cM6gEuAhTWQQmUL0P70QKTe5rmA80moCP7Edj4vve9zy1durQWDNmICyksa1Jaza5XPemluVbqSbNdz+QxX+etZxHjDUTASLA5XF1Zze5FFjA6picr9yyu2qxptau\/1tt+aLsiihfUJ88YFM5R4iWqDYrYfhQw7RwtzCszAe0GSgvEzXNvWlqZC9jCG\/PUp4XFyJ106G5Ic6fkqWdaWrkL26QHwnKlBfFKtkUVMHnbMFwEdQxMiLiIbZi3\/Yq680i3g969l8Y83HmUNCzS0mrSkGpKMnQhNQUjE6mXQJ6txEn3lmXro+aUp+718m3Vc1m3cIZvv3qrPAJC9XZkEZ04d6No58Dk2YarmRdVwKCMedowTsDEWdiK1oZ52q\/o7mdpi6ztlzSuytJ+tMC0aiZnug0TiDvkLCqwMOngNx1MWNTDp0JYSfVpGGwLE0g6RCvKOhFXz\/AQraKemQKUOlA8LCf63rFjx7oJryILmLxtCAZRLqSytGHW9tN9VQ+hom0KyNp+J06cqB3AqOsjfRif6cMkizwGwymNFpgWTvJMmgRIgARIgARIoDUEKGBaw5WpkgAJkAAJkAAJtJAABUwL4TJpEiABEiABEiCB1hCggGkNV6ZKAiRAAiRAAiTQQgIUMC2Ey6RJgARIgARIgARaQ4ACpjVczaT6pz\/9yT384Q9vuD5nz571P2r3uMc9zj30oQ\/NlN4f\/\/hH9\/vf\/96df\/757kEPelCmZ3DT3\/\/+d\/fLX\/7SPeYxj8mclyT+u9\/9zj\/\/qEc9KnN+uPEvf\/mL+8lPfuLr16tXr9qzP\/vZz9zDHvYw16dPn1x1QN3xR6eFRH\/1q1+5Rz\/60e7BD35wZPmiyg\/2P\/zhD93Tn\/70bukhkb\/97W\/+T9gu+Ow3v\/mNe+QjH+l\/A6fZF\/oWyhvW59SpUz6\/tDZA2XCf7p8\/\/elP3c9\/\/nP37Gc\/2z3iEY9odpGZHgmQQIEIUMAUqDGKVpRf\/OIX7j3veY\/\/vYzJkye78847zy+gOEEXW\/PkwiJ7\/fXXuyc\/+cmxVdi\/f797\/\/vf7z7xiU+4AQMGZKpq1DNY9LBd9e6773Y7duzwouDDH\/6wu+CCC2ppYgGbPn26e9vb3uawJTDP9alPfcp95Stf8Wk+9rGPdbt373bf\/\/73uySBhfGKK65wj3\/842ufg8vb3\/529+Y3v7mWJ0QN6owFFueaZBVuEA4f+chH3H\/+53+6devWub59+\/p8pF6veMUrfP2iRAx+AXnLli3+eQg4XEkna\/71r391H\/\/4x31e+G0UzTHt8Ktvf\/vb\/iRludCus2bN8sILIiS8UA+IKLmiTrPFs0izZ8+eicxw33vf+173xCc+0V111VU1cbh161b3zW9+0\/9uzT\/8wz9kanqIKGwjfc5znuPe+ta3ZnqGN5FAqwj89re\/dZ\/97Gf9y4Nc6OeXX365n5cw94XXtGnT3Kte9Sr\/cdTzUWVFmuPGjau9AOAlJ2rcxtUT8yBeFP785z93K28am9e85jXuKU95Stptqd9TwKQiqu4NsER85zvfcfjRNyzGH\/vYx9xDHvIQ\/2u0r371q\/1ihF+pve222\/xCO3DgQA8LIuP22293eBuW61vf+paDIHr5y18eadEJRQGsNThpEp8\/85nP9OW49957a7+K+4xnPMONGjXK\/3nWs57V5W0dZ29s377dveAFL3A33nhjYgNCCMihaRAhWIAnTJhQmwxwJgTK\/qIXvcing3uwQIKF1Bef44A2\/CDamjVragINguOd73ynu\/rqq30581yYSLAwX3bZZe4d73iHX6BRLwgsCI4nPOEJ3ZLDxIXfg7rkkku6LOppR4OjXWbOnOnTXLJkSY0lygARiHpBxIYXBMiiRYt8nvixu02bNvk\/YL9+\/fpu92vW+DJKwHzve99z1157rfvgBz\/o2zXukvte97rXebGSdC1fvtzhF8zjLljJ0KfRN5\/73OfG3vekJz3JC6aoK+7sENwr52pgTBw4cKBQPwqY1iez\/GRC+EOqSeeIhGfG6Pz12U1pfTat3K3+Xupx\/Phxt3HjRhf+kro+ZC4LQ11evDhg3CEPWD9hQcVYWLx4sR+fsEpffPHF\/hGIh69+9au+\/0oflxcPmaOjWGAuwQuQ\/oHKpD4clcagQYN83XEh\/6c+9amR85J+FnXCiyfWi6g5JW+7UcDkJVbB+7EwYjGDhQWiBAvqBz7wAf\/GGjXR4O141apVtTcFDEA8hw6OARl1hVYcLILo5Lfccou77777vHCAkLnnnnvcvn37IicNpAtBBUsIBvNLXvIS9z\/\/8z+R+WEA44JIEKsAPkPaECEQTrCc6IkI94f11YdJ6Yxw6BWYQRCFV9KCCqEIoQYBh4kJFpFLL73Uu1rAA6LspS99qbfKaGsG8hCLFdoGb2loB1xg9+Uvf9m98pWvrFll8Ll+C4IAw+++wAJx6623egvbH\/7wB\/fjH\/\/YL9ralYU3QfQBPTF\/4QtfcD\/4wQ+8xSmr6yac2NHPIJa+9KUvdWMmkyUWCrHS4CaITzDDhckREzyECBjJBTdTkgsMYggTMNKO659IS7\/lZpkGZGGfMWOG749FPtQurj5pi2\/4y8ZIJ+kHOZN+o0wf33\/69Gmnf6spC+923qOFWNR4blTA6J8JkIMhRcCMGDGiJlaieNYrYKL4YWzhBfYb3\/iGf3GKsp5n+X0sSTvPvVnakwImC6WK3oPOC5UurgpYZGDaxOKMN2y4UDCBYZGGW+miiy7yFhrENMiFNNauXeuOHj3qXRRpcQ14DospLBd46wh\/wj7pN0qQFxZh\/Ek7NTMUJnBLXXPNNb4eEA1YdDCBQhTIQpkkYN797ne7IUOGeLMvrBl4\/nOf+5wXH2984xtrC+wNN9zgrTFxFgGZkPCm3r9\/\/249D+4llHXSpEldTn0V6xHcRhAX4AbhCGvYj370I\/+mhlicpz3taTULGOoKEaovbX4OhU\/4tieLG4QVRBME0T\/90z+ljpYo0TdlyhTfNyC00F\/wNi4XxBhcYvKmizaB8IS4hWVM3Hzydjdy5MjamyBEL1xuSRcE0yc\/+Uk\/QYvbLbUSKTdIO+I26cMWBUxUnZKsJ0kCRi9uiBkrg4D59a9\/7UU+LI\/aIttKAYN5Rlzj4BnOKcIR4z+MoZNuixcUCKFwfg279de+9jU\/n+DFJG7O0u2GF0a8hERdKDPaFGM36be08ow9Cpg8tCp0L95yofhhIkVng\/UE4uVDH\/qQX+Tf8IY3eLcGLAXokP\/xH\/\/h6UCtwwUjF5Q7FncMJMSURF36zVbcGXDbRJmikwSM5IUyQcAgoBaxORjIcon1QE8wuB91gjAYNmyYdxHBt4vP4HMO3SHa1B2+Ucj\/UVdYgz760Y\/W3lqy\/EJ22u8BRX0PYQmXFtwuIbO77rrLveUtb\/EWHFhtsFBjUZcLljGxUiHGCe4nidWBQEHb4xlY38Lyi4DB2yKsVhAemNB1XEzY3mjr0aNHe5cg\/qCd4IICe1h+YLkbOnRol4lXWwEgUiEQ0T9EpIZuPskTljsItqTfVQI7cEO7odzNCFhH\/igTyq3dC1kETGjGl76GNMMFPeptVj8f9lO004tf\/GK\/GMGidd111\/mXD7j\/wkv60aFDh3xdotwkcdNhMwUMYjRQXlzhz4OAL4S8vrQ1JPw+yoWpn9fPJrlT0O\/AT37HC30XDEN3DMqFvpdmxQo5prmQEOcWXrrsWawcSVYySRsxbhib2JyA9sfYhks7FPk6P3DBPBF1YV7BCxXmAAqYComJTlUVLpCbb77Z7dq1y1s1vvvd7\/oFARYEHUCKRQUiQHbvyCIgVg1MgoiVCF0e6MwbNmxwr33ta726xxs+3uQhRCAksOhikoVVRy4MXlg2ENsilh4IKVgXMKEg+BPlhPjCWxwmaAQgI74DCwisGhg8WsCgHHj7Rj1gdfjv\/\/7vWpwJ7sPbirx9hDE\/cQIGFiSINqSHBRlWnVYJGFis4AIBd221Qn1QfpQRVhjs5kKMhw561b8fFYofBMSi7dEHUJcwqFcmZgg8iBy005ve9CZvQcOFoEARKBBHuHQciZ7YkT6sdIhHgehEf4HQQdvKfWgjEbDob8gXfvSwjaSvfP3rX\/dlShIwsDghUB2TdZTFS489Eb9p41EWztAKmCZgwu+1FQdiGgJLuw80P\/lhTP0jivpHCTEW0EcuvPDC1LduXb+8iy+eTXrJSBoDWvTBhQSrHMaOtmChT2IxjXIxIV\/MU7CGhIIvHKdhGdMC1sM21\/UYM2aMZ4sXN5knGrXAQKRjPGLewjiC2M\/rQsK8m3QlxSqJeMHcCOGCuDRYKjGfoW6DBw+uBc5rtphfxAWu84Z4QdwO5iSwooBJm0X4fVMIQJSgA2PxgwUmzjwIAYEJVi\/0eOPD81j0sSjB9KmvKPMnBh0+h1UAbhQsfFgIki6Jj0BwGy64bzBAQjN02q+3YuFFwO3ChQtrQbuNxMDAPQMmiCVBbAYWY4gsMJKg4LiJMeotS9+r3yYxKcAigTcl\/C0TPmI7kC\/uhQsGQg6CEVYlbe5GuuEbmezygUiUHVQyUSHAEK4ivbjhDRS7giAsJdA1bfGL+h79BQIWnNB\/EKR75513us985jO+XuiLsNKBq0yCjVhgINIhiNFGcZe4zmANgPhLusK4F31vmoCJSlc\/EwYB676JfGH9hCVMB5TKPXjrDRfZLBNEWhuGacSJN7kvKYhXxzlFxdakBfbq7yFwYD0IXTsoh5Rh4sSJXQJJ89Q1yhqp82tUwETFwMACh\/kJViOMC10XLWzl+AOMJVjQMW4ljg47KmGBxQsDRAXmV31EBZ5F7B1eIPBygBcSCHy4\/yFAYGXFLkcIasxjSCO0wGDs6kBjvfFBhDQFTJbRx3uaQgBvqXDDiFsJrhlM5tLxYbFApxb3BDosFDusNBjU6KxR\/liJ54BgCP2rMnFntcDIWSJJfvQkAQORhUkDiy+sGBBSsKIgmBiLG0QRLogELJ4Y0BABkl8YAyMTAKxQ73rXu\/yuAphf094+dBAv8sPiiQUcbzw6figqiFcvdtgejTc2WMxgyUAbYIH7t3\/7N18PMNfbukMBgzcw1B\/CB2\/BuOBuwlsxrGSY3PSEjwkd9YRQhQsOkyeeg3sGaeMPvpe0kJ5+Hn0Bk6kEACN\/9B8sRLDEYVIVYRa+TTdigckyQNB3IVwg2pJ2M0XFvdQjYELXh7wpwxIobqRwIYhyp0jeELAiYPIuHHkWdSlDUpB6Fiskyh0lVqI+C+OpxM0Ea5r+hWUt+OMC75GvFlFJfSOqHnoMye7Hel1IcQIG\/VDv9gnj0jCOMMYxV6C\/6jlB9x\/wwdjERgfEjOESizvmcsTtoQywiGLMY77DmMf8hBdKzAFwTSNuECxkXtOuNRkrut0oYLLMOLynqQTEbQNXAgIqMSjRoWFFkJgVuHywyMuiCBGDHR26c4fb5tJ2JERtOU0yT6PSoYCBcIBbCWXBAEbsTuhCQjnwGYJB4ebCTh+YQp\/3vOd5V1I9MTB6oYAIwqQCawg+T1pE8MYEaxfMxnCFgTFYQ0RhYYBJGRMNguswQWlRI5MVhApcP5\/+9Kd9DA7ehmThAyMwwUQocUz4TE++cM\/AhI1JDvEHsoMHogJtjHgbiDxZ3FAfuKiwxRsBhTDjY0KDGEG6sPogvgWTrT4PR1wcEGd4M8QZQRJr88UvftFbc9AOCA7HDqckAaO3ukvnT4uBiTrjJxw44A8OqI+2zEUNsLS+mWaBEXeejvUInwFP7ASBK07HpqTlHRUXEW5\/1nXKGwOTRbzEWQyiWKYJGDyDhRWWPxFMcRYaLe4gZHCGk16Uo\/LPEwMTbl+GKwkvLrjqFTDob9oFhPZAmSEqXvjCF9biUKK2USPuTcYhrJkyj2oBg5cRzGsIwMdmDLyk4uUDAfJ4+cILKl4goixheDnB+EQQPSx+eKGlgGnqksvEmkVAziPBoMdAlZ0+6MCwrkCtw0+KxUYfgib5J0XEZ7HA5NmFFCVgdAwMvhfLRegaggUG30n8DgapBHjKRBT1ZhgXA6NFCgQSJgNMtpiAkHfowkHaco7L85\/\/fH8Im\/j7IQohJCAW4f7BpAWBgW3RODhPLGFYxDBhYYLDfSJw9G4iWKpgUYDAQUC2uLJEwMCShIkMeSANmJo\/\/\/nPe0sIRAKscBB1CFIWAYNnMBliFxImQ1htMLlhEpdFFpYrvLVBUGHCg0BD\/nfccYe78sorvbUHb2d79uzxkyr6EgQDgqlRLwgcuKhCk3UjMTAQYsgv6YLlAnEjsCiiXBBTUVea6wTPJAmYODEfWsaQD8YcrFX4I\/E9Ot4lqm9lCeyMq5cWSvXWXZ5rlgUGL1LhC04aA+mvsDygPXXMSt75Mq4eEoeDuQR9s14Bo2NgUDa0NWLEMBYlJi1OEMoxAxDecCeGAgbjFWMUc5F2ZWNegOVWB+lGCRjki7kRawFCB6JcSGgf2bSBly+8ROEFhRaYvD2N99dNQHa3YIeRPtlVn9eBN2YE1cWdriudO+pQpTCIVxc0brLP86YJn23cEfqhgJETfvHWA3cFFlzUGdaTLAJGzLqylTfqoCY5uRaL+D\/+4z92axcs0tiyCOGAeBwRMJiExI0HSxLEBA7Jg9BAPnLgmzCD0Pzf\/\/1fLxTgfgq3Q+PETrylvexlL\/NCAZYe+LRxgQtiZ2BRk8PyZKFHeigfLCa4QveCHD4IAQVhhbxl8YNYxfk8sPygXfAmjPQwiUIUoK9BBOOQK8RZIVBc3ElhW0W5kOqxwGQdGLBAYvLFHzkVWT8r5ZEFKy7dLAJGB+GKRUYHW2r3hw4SjnJf6cBUCTRttgspboGLY9BMAaPHh5QD+SLuJSoGRvcjHfArgi8Ui0n9I64eOsZH3FZ53HDyIoNzlTA+5bRvOSYBVmEdhB9XDrws4aUJFpVQwGDewIsMrHhpP9GSpX2jBAzGNna84UI5kBc+g0hKc6NnHZe4j9uo89Cq2L1Y\/LHoYNLD4WAwQeKcDrgmsOAj+RxjXwAAA51JREFUkGzv3r1egb\/+9a\/3b\/xYnPShYVFvfrJrCao87lwUHQODBUSO1YZbABH5eNuXfPRZH0lvmhjs+IO3DLEuoG6yEwWDHQs3FnjEamASRPAoLh2cDAsEuCBwDpYSDMgwxkfOWIFlB9YMuLGwAMIqgUC48DwcOTAKEw9cRnI2CQSK3n4OUYA3MIgruGWw7VnKFrdAJgU\/wmIDPzbqDGsL3ECwtsEvDmsU3uLAHuIEF9jhTRALIvqDfjtHrAosO+CC+kIkyfktSBsLCywqYIsJGfXSEygYYtcQ2lV+mwn3wdIHASyBi9LGCGhEPiizbiMZptiFBB8+xFSe30ZCm8HahbojL8RhQbRp95eeCpLiT3CfuITwVhoVBC\/fy9upuA4gXNDP0Zd0MCqYI89wa3NUgKy4VxqxwIRblaXuEFAYM1GnLuOecLsx+mmzBAxEh3bzgCHGDT4Ty4reYYfyhLtu0r6vR8DgGVn0kZ9YYJIYpp1IK1ZvzL1ymBzmX8xbeiME5ujwZ17wm3AYV3jBlJc0\/Fsf2Ji0uy6vgJFdSHjp0qdWI29cmEtwWKbECDa6pFLANErQ8POwCGDnEaLQsbBioYZ5EQsCDgeDWVMWLSwiiN\/AgqXNklETJwYVBABO1UUaCP4ND1SLEzBRuLMKGH0mCkyfEDFww0T9+GNSoJ+UAYuDTBoYlGEdcJ8cU48YDlhdYL7GAh91gSUmG9wHCxDe4BBboi+4UBCHApcLLh2IW6+AgTsQizTEGCw\/WCwxWYpoCcuKHQ0QYzjAK8q9IIIQliy8RcJPLtuoswwX+Q2pf\/3Xf\/W342cjsEjKhChtgz4EwaR\/lysqfQgRBF5nPaQujA3BWy\/auhm\/3ZKl\/mn3hBaptPs7\/T144o\/8Vk+ny1O2\/PHbbOi\/cKfrnzSBKwhCFmML4wOW2PA3lLLUNemwx7wCJk6M6XkQGwviTvXNUl59DwVMXmIVvR+LPFR00jHx8L3irT3clgfVjcVRx5dgccRCBUtE1OFheLOA5SLc5peGX7YQ6vzkGX1eTdrx8mn5FPH7OGZSb7AMf1AS36Hdsv7woa533K9J4x6IGLRf0i9nJzEUaxnuCftIUhsXsV2aWSaIN71DpZlptyotCGu4ENIsDa3Kv+zpYu7FfKlP1ZXPkubQZtRb5o6o+VTSzzIeW1VeCphmtDLTIAESIIEWExCXR9qPU7a4GLmTx4+9wp0S\/uBh7oT4AAkEBP4PCLax3POE+nYAAAAASUVORK5CYII=","height":337,"width":560}}
%---
%[output:4b39deef]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 33"}}
%---
%[output:0f39152d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：65"}}
%---
%[output:87d1d499]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Blocks_of_different_Trial_splitting_methods：Block 33 将被忽略"}}
%---
%[output:9387cf6c]
%   data: {"dataType":"textualVariable","outputData":{"name":"ans","value":"0.1095"}}
%---
