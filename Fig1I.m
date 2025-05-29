MOpBaseline=TransferLearning.MOpBaseline; %[output:586fd88b] %[output:3860902b] %[output:2626c95e] %[output:6fe34788] %[output:80a2b9bb] %[output:68449229] %[output:5553088a] %[output:3cfdd4cb] %[output:6be0d93d] %[output:0362b30e] %[output:75f30377] %[output:01173181] %[output:5e6c50ea] %[output:0eb781ab] %[output:3fbfe582] %[output:12d873d2] %[output:8bfc8248] %[output:50ee1237] %[output:8e178ad0] %[output:0d8a1b46] %[output:2c79ab09] %[output:1c16d0e3] %[output:64249c2b] %[output:8d716eab] %[output:6821c933] %[output:985c76b9] %[output:6310c7ea] %[output:4895b10f] %[output:7c60c238] %[output:7160eebb] %[output:696547b6] %[output:64e6c83b] %[output:022d9fbd] %[output:8e192037] %[output:9ca58169] %[output:0dd4a479] %[output:10416780] %[output:214f7fb1] %[output:81a6cc8e] %[output:117316aa] %[output:6ebfc7ee] %[output:260aae6c] %[output:14c18fdf] %[output:328b46f2] %[output:6fa5798e] %[output:7f8333bb] %[output:5ea15c98] %[output:17859b65] %[output:61563195] %[output:2fc303a6] %[output:52cee486] %[output:36c8ff2e] %[output:46c075dd] %[output:21058b9f] %[output:6733fb1d] %[output:7c4ff375] %[output:39118675] %[output:68dec810] %[output:4ec51838] %[output:62ed4530] %[output:647cbde0] %[output:2b73eff7] %[output:36c1c65b] %[output:1a5c88eb] %[output:25499b9e] %[output:5a54821c] %[output:76f8f8a1] %[output:10260307] %[output:382bc863] %[output:881559a7] %[output:6a5e8dde] %[output:9da6c2f1] %[output:9b3bbad8] %[output:0939740c] %[output:136d9d90] %[output:1b3df31c] %[output:2b785d7a] %[output:9d0cccbf] %[output:88a08192] %[output:8fba78e4] %[output:332b77d1] %[output:5926f72c] %[output:0fd5aac6] %[output:933715c7] %[output:91c4e9a3] %[output:89e1c9ee] %[output:076a22f4] %[output:5921ba3f] %[output:2019ac3b] %[output:03f6e23e] %[output:5d8ba0c2] %[output:3e09fb08] %[output:11c3ceb3] %[output:7d0e56e9] %[output:8032179c] %[output:941e54e6] %[output:4b06b00f] %[output:14bc7c43] %[output:7dde388a] %[output:16e863a5] %[output:7b5edaa5] %[output:4e424c5d] %[output:9ce383ac] %[output:38adddd2] %[output:73cadac1] %[output:44824868] %[output:12a42b7c] %[output:37f4c64a] %[output:16b613a3] %[output:7d066595]
%%
GroupNtats=UniExp.NtatsCellStrip(MOpBaseline.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath("查询表.xlsx"),'Fig1GI'),UniExp.Flags.ZScore,1:24,UniExp.Flags.Median)); %[output:712e84b1]
PcaTable=UniExp.LinearPca(GroupNtats.NTATS,2);
LinesPC=table;
LinesPC.Points=permute(PcaTable.Score{:,:,["Naive","Learned","Transfer"]},[3,1,2]);
LinesPC.Color=GlobalOptimization.ColorAllocate(3,[1,1,1;1,1,1]);
Markers=table;
Markers.Index=[24;32];
Markers.Shape=('os')';
%%
Fig=figure; %[output:13ceb86b]
Lines=UniExp.SegmentFadePlot(LinesPC,Markers,PatchArguments={'LineWidth',2}); %[output:13ceb86b]
UniExp.PcAxLabels(table((1:2)',PcaTable.Explained,'VariableNames',["Index","Explained"],'RowNames',["X";"Y"])); %[output:13ceb86b]
legend(Lines,SubTitles,Interpreter='none',Location=MATLAB.Graphics.OptimizedLegendLocation(Lines)); %[output:3ad52656] %[output:13ceb86b]
title('●0s(cue) ■1s(water)'); %[output:13ceb86b]
MATLAB.Graphics.FigureAspectRatio(4,3,MATLAB.Flags.Narrow); %[output:13ceb86b]
print(Fig,TransferLearning.ProjectPath("Fig1I.svg"),"-dsvg"); %[output:13ceb86b]

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:586fd88b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：3"}}
%---
%[output:3860902b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：4"}}
%---
%[output:2626c95e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：5"}}
%---
%[output:6fe34788]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：6"}}
%---
%[output:80a2b9bb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：7"}}
%---
%[output:68449229]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：8"}}
%---
%[output:5553088a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：9"}}
%---
%[output:3cfdd4cb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：10"}}
%---
%[output:6be0d93d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：11"}}
%---
%[output:0362b30e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：12"}}
%---
%[output:75f30377]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：13"}}
%---
%[output:01173181]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：16"}}
%---
%[output:5e6c50ea]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：132"}}
%---
%[output:0eb781ab]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：133"}}
%---
%[output:3fbfe582]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：134"}}
%---
%[output:12d873d2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：135"}}
%---
%[output:8bfc8248]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：136"}}
%---
%[output:50ee1237]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：137"}}
%---
%[output:8e178ad0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：138"}}
%---
%[output:0d8a1b46]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：139"}}
%---
%[output:2c79ab09]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 142"}}
%---
%[output:1c16d0e3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：144"}}
%---
%[output:64249c2b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：145"}}
%---
%[output:8d716eab]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：146"}}
%---
%[output:6821c933]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：147"}}
%---
%[output:985c76b9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：150"}}
%---
%[output:6310c7ea]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 152"}}
%---
%[output:4895b10f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 19"}}
%---
%[output:7c60c238]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：22"}}
%---
%[output:7160eebb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：23"}}
%---
%[output:696547b6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：118"}}
%---
%[output:64e6c83b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：24"}}
%---
%[output:022d9fbd]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：25"}}
%---
%[output:8e192037]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：119"}}
%---
%[output:9ca58169]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：26"}}
%---
%[output:0dd4a479]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：27"}}
%---
%[output:10416780]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：28"}}
%---
%[output:214f7fb1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：120"}}
%---
%[output:81a6cc8e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：31"}}
%---
%[output:117316aa]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：32"}}
%---
%[output:6ebfc7ee]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：100"}}
%---
%[output:260aae6c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：121"}}
%---
%[output:14c18fdf]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：33"}}
%---
%[output:328b46f2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：34"}}
%---
%[output:6fa5798e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：101"}}
%---
%[output:7f8333bb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：122"}}
%---
%[output:5ea15c98]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：102"}}
%---
%[output:17859b65]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：123"}}
%---
%[output:61563195]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：124"}}
%---
%[output:2fc303a6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：103"}}
%---
%[output:52cee486]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：125"}}
%---
%[output:36c8ff2e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：126"}}
%---
%[output:46c075dd]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：104"}}
%---
%[output:21058b9f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：39"}}
%---
%[output:6733fb1d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：40"}}
%---
%[output:7c4ff375]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：43"}}
%---
%[output:39118675]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：44"}}
%---
%[output:68dec810]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：45"}}
%---
%[output:4ec51838]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：46"}}
%---
%[output:62ed4530]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：113"}}
%---
%[output:647cbde0]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：114"}}
%---
%[output:2b73eff7]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：115"}}
%---
%[output:36c1c65b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：116"}}
%---
%[output:1a5c88eb]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：117"}}
%---
%[output:25499b9e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：110"}}
%---
%[output:5a54821c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：111"}}
%---
%[output:76f8f8a1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：112"}}
%---
%[output:10260307]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：105"}}
%---
%[output:382bc863]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：106"}}
%---
%[output:881559a7]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：107"}}
%---
%[output:6a5e8dde]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：108"}}
%---
%[output:9da6c2f1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：109"}}
%---
%[output:9b3bbad8]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_more_than_existing_Trials：Block 66"}}
%---
%[output:0939740c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：168：最后一回合没拍到"}}
%---
%[output:136d9d90]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 168"}}
%---
%[output:1b3df31c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：240：CD1没记到"}}
%---
%[output:2b785d7a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 240"}}
%---
%[output:9d0cccbf]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：241：CD1没记到"}}
%---
%[output:88a08192]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 241"}}
%---
%[output:8fba78e4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：242：CD1没记到"}}
%---
%[output:332b77d1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 242"}}
%---
%[output:5926f72c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：243：CD1没记到"}}
%---
%[output:0fd5aac6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 243"}}
%---
%[output:933715c7]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：262：水滴漏了，没有拍到"}}
%---
%[output:91c4e9a3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_lacks_BlockTag：262"}}
%---
%[output:89e1c9ee]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 203"}}
%---
%[output:076a22f4]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 269"}}
%---
%[output:5921ba3f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 270"}}
%---
%[output:2019ac3b]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 271"}}
%---
%[output:03f6e23e]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 274"}}
%---
%[output:5d8ba0c2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 275"}}
%---
%[output:3e09fb08]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 204"}}
%---
%[output:11c3ceb3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 276"}}
%---
%[output:7d0e56e9]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 205"}}
%---
%[output:8032179c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 278"}}
%---
%[output:941e54e6]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 279"}}
%---
%[output:4b06b00f]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 280"}}
%---
%[output:14bc7c43]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 206"}}
%---
%[output:7dde388a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 281"}}
%---
%[output:16e863a5]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 282"}}
%---
%[output:7b5edaa5]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 283"}}
%---
%[output:4e424c5d]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 284"}}
%---
%[output:9ce383ac]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：129：2次中断拍摄，无法对齐回合"}}
%---
%[output:38adddd2]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 129"}}
%---
%[output:73cadac1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：209：中断两次，行为和钙对不上"}}
%---
%[output:44824868]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Split_trials_less_than_existing_Trials：Block 209"}}
%---
%[output:12a42b7c]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：299：中断两次，行为和钙对不上"}}
%---
%[output:37f4c64a]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：215：拍错Z层，舍弃信号"}}
%---
%[output:16b613a3]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:No_TagPeaks_found：Block 215"}}
%---
%[output:7d066595]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Blocks_of_different_Trial_splitting_methods：Block 3 4 5 6 7 8 9 10 11 12 13 22 23 24 25 26 27 28 31 33 34 39 46 100 101 102 103 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 129 132 133 134 135 136 137 138 139 144 145 146 147 168 262 将被忽略"}}
%---
%[output:712e84b1]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Numbers_of_cells_differ_among_groups：\n每组的细胞数不同，不同组之间可能不具有可比性，请确认筛选条件正确？分别有 4340(Learned) 3962(Naive) 4340(Transfer) 个细胞\n使用<a href=\"matlab:groupsummary(DataSet.Cells,'Mouse')\">groupsummary(DataSet.Cells,'Mouse')<\/a>查看每只鼠的细胞数"}}
%---
%[output:3ad52656]
%   data: {"dataType":"warning","outputData":{"text":"警告: 忽略额外的图例条目。"}}
%---
%[output:13ceb86b]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAb8AAAFRCAYAAADkXaOAAAAAAXNSR0IArs4c6QAAIABJREFUeF7tnW1oXde551cYuEXQ9INS54MnuMLgMONMcekLFWZaOYFAKLXhhnFl+0swrjFc4ojWqSS7bWy3xJJVuy9xOsU4QuSLX+qSS+NLoGRKIjoIdyCmZsa+xZ4aJTfVB\/vGZJwPpv2S4dnOc7y0tPc5+\/2stfdvg7Gks\/daz\/o965z\/eZ719sDHH3\/8seGCAAQgAAEItIjAA4hfi7xNUyEAAQhAICKA+NERIAABCECgdQQQv9a5nAZDAAIQgADiRx+AAAQgAIHWEUD8WudyGgwBCEAAAogffQACEIAABFpHAPFrnctpMAQgAAEIIH70geAJHD161Jw8eTJqx4YNG8zs7KwZHBxM3a6LFy+aM2fOmOnpaTMwMJD6uaw33r592+zbt88cOHDArFu3LuvjifdL+4eGhszo6GimMs+dO2cWFxfNxMREpud63Xz37l1z7dq1yBd5rqo45bGFZ5pLAPFrrm9b0TL5AD979mxH8EQIlpaWUgtZ3R+0ZQutCv\/U1FQm8bt+\/bo5cuSIOX78eKYvCr06lQjf5OSk2bhxYyZ73HLL5tTLbl5vHwHEr30+b0yLRbh27doVRS7Dw8NRu+L+1q3BVUU\/SXWqOGzfvr1jcx6HaDtv3bplVq1aZbZt25ZJbPJGi71sLUv8yuLUy15eby8BxK+9vg++5RK9jI+Pm5mZmWVpRPuDXUXi8uXLUXvttGiSUIog7t+\/v8NHo6q4+ty\/6Yf2hQsXVtSnBZYR1ahoP\/fcc7GRltSxY8eOThv27NnTSW+6NktZCwsLnWhZudiCKuUJV0kpS0rTLlsqEUZbtmyJbNG2b968uVOmnZpevXq1mZubi3ymkffXv\/518+Mf\/3iZf8rgFHwnpwGVEUD8KkNLwUUJuEIi5dkfqPYHsj3GJx+0csUJg74m0WLc8yIEJ06c6Hw4i1Ds3LnTHDt2zDz00EMrxNYWEnldIlFbNNy0rNiVJNp25KpibTOMG8+Mi7Tc8l2Rd8XOvV\/bLKx1PFC5Pf300ysY2MweeeSRZWKs9ongaVnC\/fnnn48YK7M1a9asSFV341S0b\/E8BBA\/+oC3BNwITA3VSKyX+O3evXuFGNmNdUWgV8quV+T3wQcfrJg4E1dmt9SsG6nmET9bXOIm1thfAKR810bhIulUae\/BgwcjE9z0sm2XzcUVv6SxRbWhm4+yprC97cgY5iUBxM9Lt2CUELBTZTYRTeH1Ej+JNGwBdSOnpHSfPYaY9CGvomJ\/8F+6dGlZutR+1p6Q0k1kyxA\/N2K2U57KVf63Z3naY5\/C\/Stf+Yr57W9\/a2RsUqIzd3KMa6emMl3xc9Ovrh9V\/OKY9\/oywrsEAkUIIH5F6PFspQR6iV+aMT810P6wVhF88803Y8e68orfa6+9lmqmadXiZzvFFh8VQTfyk\/v1i4Skd1966aUo4hM+eumSCE2JyozauLFQV\/zi0r62fd2iO8Sv0rdX6wtH\/FrfBfwFYH\/Q2laePn06mimZZ7an\/cy77767TPx6fdjGia2dYpTIz152kUS26rRnXL12lHzq1KnoFjvyU5t01qy8Ju19+eWXzZ07d8xTTz0VzSZ1o2UVTh3Di4v89LW4FGwaFklfRvztuVgWAgHELwQvtdhGVwBV+BRJt3V+ImbuBBRbBGSMzk3nueXZgvjkk09G5YlAyAeyvvbOO+8sm7yhr4uN9oQZFZaqJ7zEjfm5E33iFvW7awbt5RQ6O9Plo+2Ttuo9dl3KSF7XTQTs2aTKNE7gmPDS4jd+DU1H\/GqATBXVEui2w4srnvY0+6S1ZElLHWwxk7SflCW7tUgkpcst4sbs4gTbXloQlwYsMttTynPbYM+STVrYnySa7qYB7rIFSZXK33SWq6ZaNb0su+bYSyDEPk2Zdov84qLMansSpbeJAOLXJm\/T1hUEQl3kXtSVVS1yL2qXPs8i97JIUk4SAW\/EL2lBq\/0tM+4btC5Gzrq9E10CAkIg9O3N8nqxqu3N8trjPscC97JIUo7X4qdpEjs1Iwa7u0roDhOyoNkeD5B743b6wO0QSEOgrg\/auoW2V9vrjnp72aOv+8Yprd3cFxaBvkd+ImiyHdKmTZvMRx99tGyXh7iBc90T0R0P8D2NE1a3wFoIQAACzSbQd\/GTb90yC67XbhvuNHR3rVLc2qVmu47WQQACEIBAXgJ9Fz81PEn87N3v7ejOjfR8TeHkdQzPQQACEIBAdQRaI36yC71EmXKNjY1F\/7ggAAEIQKCdBLwXPz0Us2jac+3atebGjRvt9DKthgAEIACBZQS8FT+x0k5tuut+3DRnrwkviB89HwIQgAAElIDX4lfmUgfEj04PAQhAAAJBiJ9GfydPnozsLbLIHfGj00MAAhCAgHfiV7VLEL+qCVM+BCAAgXAIeJP2rBoZ4lc1YcqHAAQgEA4BxC8cX2EpBCAAAQiURADxKwkkxUAAAhCAQDgEEL9wfIWlEIAABCBQEgHErySQFAMBCEAAAuEQQPxifGVvhRaOK7G0CQRkk3dZ0sMFAQhUSwDxi+HLzNBqOx2lJxOg79E7IFAPAcQP8aunp1FLKgKIXypM3ASBwgQQP8SvcCeigPIIIH7lsaQkCHQjgPghfsbdNLyst4xsNr60tGSmp6fNwMBA5mL1jMcXXnjB\/OhHPzL22Y6ZC8v4wO3bt82+ffvMgQMHzLp16zI+nf92xC8\/O56EQBYCiB\/il6W\/pL73+vXr5uWXX47uf\/bZZ3MJiHvAcerKS7gR8SsBIkVAwGMCiF\/DxE9E58iRI+Yzn\/mMuXDhQtQ6e0NwEZT9+\/dHf1+9erWZm5szjzzyiJmcnIwiq\/n5eTM0NGRGR0ejeyR6k2tiYsJI2Tt37oyiuQ0bNpjZ2VkzODgY272lHr0WFxej5+VS+44fPx49Kyd3nDlzphMdyu8y21Zs27Rpk\/noo4+MG\/mlscMVL1tIxQ5tr7RDflZWmzdv7tQnf1NGEv0JC91kfWpqKmIktoyPj3fa2o1Jms8BIr80lLgHAsUJIH5pxG9+vjjpKksYGemUrsKwd+\/e6MPZTj1evnw5+l0\/oFXYnnvuuY4YSEEqRrZIPProo2bXrl2RiMl0\/G4pTUmjvvjii+aZZ54xDz30kDl8+LA5ePBgJHbdxO\/999+PxPXYsWORuIooyWWLn9qxbdu2Fe1zU6ti48jISGSvRKFSt9ghl9p06tSpjriLYGobpR477WmLp22ntE9tlnqKXohfUYI8D4F0BBC\/NOL3wAPpaPbrro8\/XiZ+EonMzMxEqUY3srJN1AOBbfGTD3N9Xu6VKFKitGvXri0TTlfE7HLltVdffdV8\/\/vfj8b6bBHqJn4izm4UKL\/b4if2qU0qpnZ7k9p39uxZ8+lPf9p84QtfMB988EEU4Wo0qs\/YY5+2+GlkvHHjxmURsUTIX\/ziFzu8yhgbTCt+Vz+6atY\/uL5fPY56IRA8AcSvgeJni4MtfhrJaYpPft+zZ4+xxU8jLkmBvvvuu0ZTlpqOtHHZKUFXdDS1qn+XejR1mmTf66+\/bhYWFpalQF3xk\/Ls6FXTm9\/97nfNK6+80klfSlpShElEeOvWreYPf\/iD+fKXvxy1SS9NW2oqV\/8uaeI48bO5Kbunn356mRgX\/UToJX63\/n7LXL1z1dz8203z2GceQwCLAuf51hJA\/NKIX2Bpz7TiEhf5SepO\/y5oNG3YLYK0EdqpQ00D2uNvdjQpkZudTiw78pNI7qWXXjKf\/\/zno7FDEcPXXnst+llSsm5E1yvyi5tt2i0CzvOp0kv8pMz5f5+PxE+uhz\/1sBn57P20d546eQYCbSSA+KURv4B6Rre0oh1ZyQe9jG+JQNmRn\/yu44arVq3qjA+6oiaiJalEd4KHiKQdmQk6FRVJG4oAxY3ryXIItUkixDLG\/KRuGev7\/e9\/H0WdUqaIoYifpGQ1EtZ0pka3buQn6UxbpNVOGXeU9thfNop2lTTiJ3Wc\/+v5ZVVtWrXJrPqHVUWr53kItIYA4tci8dMPbYmwRAh2795tfve7362YTaliJWlNe1zMnmWZlPK0Z4faaG2xfPPNN6MZp1KGCPCf\/vSnFbM95dkf\/vCH5i9\/+Yv5zne+s2ydX5rZnlq3K8Zinz2b1U7nSmpWLnl9y5Yt0YSbd955J5oR6872TErjFv3kSCt+dvpT6yQNWpQ+z7eJAOLXMPFrU+dtYlvTip+2XSa+XLlzpYOCNGgTewVtqoKA9+Jnr63Sb9sKwl6zpuuukiBl+VDJcm8VTqHM9hLI0\/dcASQCbG\/\/oeXpCXgtfknjLPbiYpnSL1fSdHdFkeVDJcu96VFzJwR6E8jT92zxI\/LrzZg7ICAEvBY\/d\/zI\/t3d+sody3Hdm+VDJcu9dCMIlEkga99zoz4mvpTpDcpqMgGvxS8u8rN3GBHH6ISMpIkWRH5N7r7Na1sW8UP4mud\/WlQfAa\/FTzDYez3qrDv5uxvp6do0d9eOtolf2evOyuiKcWv\/3HLFz88\/\/3xnZmXWeu1ZnbIbjb1TTNay8tzfq\/+lLTOt+CF8aYlyHwTiCXgtfvb+kWK+TD3XNVl5xE8RjI2NGfmXdKX9APKxU4UofroXqPCUBem6qXYWvnHrC7M8X\/TeOsVPljm8fevtjslMcCnqPZ5vIwFvxS8uWrA\/4OwNiTUSlP+J\/O6d6mCfmiCnJMglJxbo2XrKV9b8yWWvW7NPKfjBD34QLRRPOiXCXidnl69rBWVLMPn7e++919kU232j6V6gsg3Zz3\/+847t7jmD7kkN9no\/sV9skUX3buQXdxqDbYNbT7e1gXGnYsheocpYOSZxEVuuXr0abbcWN0O51xcvhK+NH9O0uQoCwYqfLJS2j8phwsu97mFHfvKhrLNgdSsvWViuO7poFK3H8ujMWfuUgm6nRMjpBnHlyxcQ9zQJEQf7aCW7M+vxR3oKhW6p1k38ZINrWSBvn+4QJ36yq43uRCM8kk5gsG3QsWY5h1C46QkV8nzcqRjSXjvys3na3F0ucQf8dhM\/hK+Kj0DKbCsBb8VPozk9CVzTnrrriPuBXeVSh8cf97t7vPXWffts8ZMvCHEbRbsnq7t7b9osbc7uKRFpNqKW7dK6nRRvH3+k5euJC93ET1rsnu5gn0ChY36ynVnS+YS2V+29S3\/9618b2dpN9h4VkbVPqHBFW7+A2eLnzkS2yxZ78mYo7D09SXX6\/Z7EOv8JeC1+durMTs0p1roWuQd0otGyyE+3EbO7oR5CK6lBTdXJ67pdWTdRcQ+fFfFzT2+Q8n\/yk5+Y733ve500Zzfxs1OXaqfaKJGRHjorImqLtBuF2aKvaU89Csk+isjetFsPppVUpWz1Jmf8SVT8m9\/8xjz11FOdkyBcMXZPxXAjP7tfum2SdL0txu5HRFLkx2bW\/n+YYmFYBLwWvzJR9hpLsety7w058rNTw9pGdzy126kLvTbKjivfFbtu4he3REVT2Lq\/pp6m4Eb7ZUZ+wkbGNtX38sVAhEo2wf7mN78ZbQDuRnRutBcXBbp9OE96nkXsZX4SUBYE7hFA\/GJ6Qhah9K0jJY356cbMkkaWtKaMZ+maSfkQP3HiRLTMIEvkZ4\/52eVLWtVOicqkmrgxv6QlECoyGrlpqtu20z2OSESlyJiftFvKf+ONN8w3vvGNaMapffq7e\/ySfSpGtzE\/l4ubhk0T+dljfSxi9+0dhz2hEkD8Gix+mqbU9KamE\/WDXFOWcnqCnKwgEVbcSelJ5wNKWtKe1WiX7872fPDBBzsRlCJPWp6gqdBjx45F9uhhs3JgrZyycODAgeiUBTtlKq\/J7wcPHsw821Ptccc33eUL9gxZ+1QMEXsV+LjZnjaXPJGfnfLc+h+3hvpZg90Q8IoA4tcw8fOqd2FMZgJu1sGO+ti3MzNOHoBAIgHED\/Hj7eERAVf87KiPlKdHjsKU4Akgfohf8J24SQ3oJn6kPJvkadrSbwKIH+LX7z5I\/RYBW\/xIedI1IFAdAcQP8auud1FyZgK2+JHyzIyPByCQmgDih\/il7izcWD0BW\/zO\/\/V8VCETXarnTg3tI4D4NUz83M2fq+zS9nIGneKftb5uxx3Z24LF7YMpdXU7xaLKEy56LVnIykHvV\/Ej5ZmXIM9BIB0BxA\/xS9dTYu4S4ZItwWRtnawdzHOlOeuvW7lNFT9Snnl6E89AID0BxK9h4ifnFMrek7Iryq9+9SvzyiuvmA8\/\/DDap1JOVXj00Uej0xDijjKSxexxRxe5e6zKUTxPPvlkpxx7X1BdkG4v7NbF7Ldu3TJf+tKXOscqCfq0kZ\/uqCJ2yxFJd+7ciRa7yyV2S7k\/\/elPO3uU6qkPcr9ti9xf9AijS5cudfY01WOJ8h5h5HY\/ifz++Oc\/ds7rI+WZ\/sOMOyGQhQDil0L85Fu4z9fIZ0c65tlpT\/c4Hf3Q73aU0d69e6OtvewjiWSrMt230o72pNJ9+\/ZFIqRio1umuUcaJZ3Snlb87NMQ3O3YRHDj7Jbt1+zdaWwfFj3CyE57FjnCKE785v7XnLn5t5vRS6zt8\/mdh20hE0D8UojfA\/\/8gNc+\/vgfP+4qfvapBnZDuh1lZI+32eKX9HyvUxbsc\/DcMiQSVdG0X1MbZC9SOVRXtzVLa3c38St6hJEtfkWOMIoTv6N\/OBr9majP67cdxgVOAPFrgfjpqQjSVDs9J78nHWXkTjaxT0PXQ2ndI4bsI5LsskUY9Xw9d+JKmsjv29\/+tpFNruWwXdnTs9spFLbdtvjJCQ1lHmHkil\/c0U5yqnyvI4y6iR9RX+CfrpjvNQHEL4X4hZ72VPHLcpRR0kxLW3gk1alpz24C123WZhrx6xX5JW283S3yE7cXOcLIFb+4o52kjqyzQmXMTyI\/Dqv1+nMT4xpAAPFLIX4h+TluzC9J\/LodZeSePq4HsKYd85Oyz549ayT60cNl3RPkhWsa8ZPnuo355RW\/IkcYJY35ZT3CKCnyYyuzkN512BoiAcSvYeKnk1rk6B+d7WmnPe1TxrsdZWSLnz3TUnDFpT3dI4Y0nSp\/TxP56exTdYfUIZemS20b7KON5J4k8dNn5B4RYXc5RpEjjPQU+7jZnlmOMIoTv3+5\/C9m\/YPrQ\/w8wWYIBEMA8WuY+AXT8woYmnQOYIEivXk05IOUvYGIIRBIQQDxQ\/xSdJP+3uKuM7Sjyv5aVn7tiF\/5TCkRAnEEED\/Ej3eGRwQQP4+cgSmNJuC9+NljVLKzhz1pwn5Nx16SvJXlQyXLvY3uHTSudgL0vdqRU2FLCXgtfjK2Y+8MIjPs5JIF0fZkBfmbTIfXdWBxvszyoSLr1aRuLgjUTWB4eDiaUMQFAQhUS8Br8eu2RsrdVaPXeqos4lctckqHwD0CbF5NT4BA\/wh4K369dvu3o0DB5\/7uIkX8+tfJqHklgasfXTVX7lyJXmAbM3oIBOon4LX4ye4hW7dujdZxLS0tRbv565ifG+lJJJi0y4ZgFfHTS04+kH9cEOgXAT2oVupnG7N+eYF620zAa\/GTDY\/XrFkTCZ5ck5OT0V6UMuaXR\/xu3LjRZl\/Tdk8I2FEf25h54hTMaB0B78XP3u3fXtwsGwbLJa+T9mxdvw22wbbwSSPYxixYV2J44AS8FT\/3wFHh3O2YHSa8BN4TW2C+K3ykO1vgdJroLQFvxU+I2TM6Ne2ZdBBrmUsdvPUWhgVL4Nbfb3VOZ5dGkO4M1pUY3hACXoufCqCelbZnz55OmtN9rcxF7g3xLc3whADC54kjMAMCFgHvxa8sb7HUoSySlJOFAMKXhRb3QqA+AohffaypqYUE7IXspDpb2AFosrcEED9vXYNhoROwhY+F7KF7E\/ubRgDxa5pHaY8XBNjBxQs3YAQEEgkgfnQOCJRMgCUNJQOlOAhUQADxqwAqRbaXAMLXXt\/T8rAIIH5h+QtrPSaA8HnsHEyDgEMA8aNLQKAEAixpKAEiRUCgRgKIX42wqaqZBBC+ZvqVVjWbAOLXbP\/SuhoIsJavBshUAYGSCSB+JQOluHYRQPja5W9a2xwCiF9zfElLaibAIvaagVMdBEokgPiVCJOi2kMA4WuPr2lpMwkgfs30K62qiIA7uUWq4Vy+imBTLAQqJID4VQiXoptFwF3Hx0bVzfIvrWkXAcSvXf6mtTkJIHw5wfEYBDwlgPh56hjM8ocAwuePL7AEAmURQPzKIkk5jSSA8DXSrTQKAgbxoxNAIIGAPaNTbmFiC10FAs0hgPg1x5e0pCQC7oxODqItCSzFQMAjAsGI38WLF83Ro0fN7OysGRwcjBCeO3fO7N+\/P\/p5amrKjI6OJqJdu3atuXHjhkfoMcVHAqQ5ffQKNkGgfAJBiN\/t27fNrl27otar+F2\/ft2Mj4+bmZmZ6O\/687p162IpIX7ld56mlYjwNc2jtAcCyQSCED+J8N544w1z586djvjJ3xYWFsz09LQZGBiIosKhoaHE6A\/x423QjQDCR\/+AQLsIeC9+EuG9+uqr5oknnjAnTpzoiJ+InVwTExPR\/+7vrhsRv3Z17CytdSe2sHg9Cz3uhUCYBLwXPxG1kZGRjsBp2tON9CQSXFxc7Igh4hdmh6zTajfak7qZ0VmnB6gLAv0j4LX4ySSX+fn5SNDcCS95xE8xj42NGfnH1V4CrvAxo7O9fYGWt5OAt+J39+5d8+KLL5pnnnnGyCSWOPEj7dnOTlu01YzvFSXI8xAIn4C34idjfTt37jRLS0vLKK9evdrMzc2ZS5cuLUtzMuEl\/M5YdQviTmRgfK9q6pQPAT8JeCt+Li438mOpg58dylerGN\/z1TPYBYH+EAhW\/AQXi9z702lCq5U0Z2gew14IVE8gGPErioKlDkUJhvk8yxjC9BtWQ6BqAohf1YQpvy8E4tKcjO\/1xRVUCgEvCSB+XroFo4oQYBlDEXo8C4F2EED82uHn1rSS8b3WuJqGQqAQAcSvED4e9oWALGO4euequfm3mx2TSHP64h3sgIB\/BBA\/\/3yCRRkJsIwhIzBuhwAEOMmdPhA2AdKcYfsP6yHQLwJEfv0iT72FCSB8hRFSAARaSwDxa63rw244whe2\/7AeAv0mUIr46Unrly9fjtqj+28mnarej0azyL0f1Kup0124zjFE1XCmVAg0mUAp4qdn7g0PD0esZN\/NI0eOmOPHj5vBwUEv+CF+XrihkBHuxtQcQ1QIJw9DoNUEMomfRHiHDx82Bw8e7IiaHD00OTlptm\/fbhC\/VvelShvPwvVK8VI4BFpHIJP4CR1Nca5Zs8ZMT0+bgYGBzt9Ie7au\/9TSYMb3asFMJRBoFYHM4qd09Ly9zZs3Ryet+36R9vTdQ\/H2IXxh+g2rIeA7gdzipw2Tc\/Z27NhhpqamzOjoqLftRfy8dU2iYQhfeD6ry+KrV41Zv76u2qiniQQKi59C0bP1Tp8+3Rn78wkY4ueTN3rbwlFEvRm19Q4RvitX7rX+sccQwbb2g6Ltzix+mu5cWlqK6t6wYYOZnZ3tTICRmZ8XLlwwc3NzhqUORd3TvufdGZ1CgKUM7esH3Vp8\/vzyVx9++J4ArloFJwikJ5BJ\/GSyy759+8yBAwc6wiZpz\/n5+WXjfjID9KWXXjK7d+9mqUN6X7T+TpYytL4LpAZgR3\/6ECKYGh83GpNtb8+04ucjWdKePnrlvk2M7\/ntHx+tu3XLGBHBm\/cP8iAV6qOjPLUpU+QnbeiV9vS0nQbx89MznLjup19CsipJBDdtIhUakh\/rtjWz+NVtYFn1IX5lkSynnDjRk5I5g68cvm0sRUTw7beXt1xSoSMjbaRBm3sR8Fr83Chzz549y8YWdYapNLLXUgvEr1dXqOd1RK8ezm2uxR0PZEZom3tDctszi59uZyZFyg4vcsn2ZjLDU69eQpTGFbqTjCygl23T9Pdt27ZF6wlFGMfHx83MzExUnP6cNMMU8UtDvbp7EL3q2FLySgJuFIgA0ktcApnFT5YyyDIHW\/jkFAfd5UVFSgSr7J1fpG65pFyJ+hYWFjpbrMlrQ0NDiQvtEb\/+dH4RPbmu3PlkYdYnZpDe7I8\/2lSrGwFu3dqm1tPWXgQyiZ8bjdnRlx1xyfIHESN7\/V8vQ9K8bouf\/bM86\/7ulof4pSFc7j1MZimXJ6VlJ2ALION\/2fk1+YlM4qcpz40bN0YRVtzSB4FVhfjp+N+xY8eiNKgb6UkkuLi4mBhtivjpNTY2ZuQfVzUEEL1quFJqPgLz8\/eXQ7AWMB\/DJj6VSfxU2Oy9PN30ozs2Vwa0uFRqHvG7ceNGGeZQRgKBJNGT29c\/yEaMdJz+EWBXmP6x97XmzOInDdEI0J7kog10tzsr2vCkMUTSnkXJlvc8k1nKY0lJ1RCI2xFGaiISrIZ3CKXmEr+6GtYtinTTnEx4qcsr9+tB9OpnTo3FCCQtiEcEi3EN8WlvxU+jS3smqQ2YpQ79626IXv\/YU3M5BLqJIIviy2Hseyneip+7wF1ByuG5eoI8i9zr7V6IXr28qa16Aq4IMiO0eua+1OCt+JUNiKUO+YkievnZ8WQYBHRCDOIXhr\/KsDKT+OkY3OXLl3vWXfbEl54V9rgB8ctGMGlxupTCAvVsLLnbfwKIn\/8+KtvCTOKnlUu68ezZs6UvYi+7cXZ5iF86uoheOk7c1SwCiF+z\/JmmNbnETwq2tzkbGBhIU1df70H8uuNPSm0S6fW121J5TQQQv5pAe1RNbvHzqA2pTEH84jF1G8+TJ1icnqp7cVPgBBC\/wB2Yw3zELwe00B8htRm6B7G\/bAKIX9lE\/S8P8fPfR6VZiOiVhpKCGkYA8WuYQ1M0B\/FLASn0WxjPC92D2F81AcSvasL+lY\/4+eeTUizqFeUxnlcKZgppCAHEryGOzNAMxC8DLN9v7SZ4Yjvr83z3IPb1iwDi1y\/y\/asX8esf+1JqvvX3W+bW326tOCndLhzRKwU1hTSYgH3kESe+N9jRVtMQvwD9nFbwVn1qlVn1D6sCbCEmQ6DOLAAPAAAbJklEQVReAvaRR489Zsx6jp+s1wF9qA3x6wP0PFUieHmo8QwE0hPQ6A\/xS88s5Dtzi5\/u8zkxMWGGh4eXMbh48WK0A8zs7KwZHBz0gk9oi9xF7ORKk9KU+1iM7kU3w4iACczPG3Pz5r0GkPoM2JEpTc8tfinL9+Y2X8VPIzoFJWJ382+fvAMT6MkYHoLnTdfCkIYQIPXZEEembAbilxJU0dtskUsjcG59CF5RD\/A8BHoTIPXZm1FT7sglfpLSPHnyZMQg7uiitqc9baG7cudK5r7y8KceNjJZRS9SmpkR8gAEchGwoz9Sn7kQBvNQZvFzT3PQ09RPnz7dGftrgvg9\/j8fj3Xips9uMgf\/08Flr+URO1fgmJkZzHsGQxtMgNRng53rNC2T+CVNchGx27Fjh5mamjKjo6PGJ\/E7fPhei48e\/aP56le\/ag4dMmZkpLeDH\/jnB+LFb9Um89Z\/fcvIgvK06UtNWUqBiFxv9twBgX4SYMF7P+nXV3cp4ifmqgBKBHhPbPo\/21OE79C\/fqJ+\/+Xte1TPHTKH\/tuIObg8eFtGXITtsf9xb1KJe4mQuZGffY8d0ZGurK8jUxMEyiJgR3+bNhmziqWyZaH1qpxM4qeitrS0ZKanp417iK0K4J49eyIxrHqpg6ZcxS6NOpWuTFve9KvDxoweWglcBPA\/H+wI4Pm\/no\/usTeA1r\/1Ej\/Ezqv+jDEQKEyA1GdhhEEUkFn8VAAvXLhg5ubmzLp165Y19O7du2ZyctK89957lYrf9evXzfj4uJmZmYnq15\/Vnsf3zpu3n9iU6ITH\/t+3zNbh9YnbgvUSP4kASWEG0ccxEgKZCZD6zIwsuAdyiZ8PrZSob2FhoROBSpp1aGgoGnOUSyasvH3rk1RnjMEP\/99vmZGRj1e+8m+PGfNv6835z30rtpmbPhnz84EBNkAAAtUQYNZnNVx9KjWX+MVNfNGITxoXlxItu9EidnLJDjMajdq\/9xS\/Tz1s1n9mfTRpZf3\/PmjMJ6Kndp7fHj\/h5eGbm8zI79+KbpNtkPSSvQDd38tuM+VBAAL1ECD1WQ\/nftaSWfwk3bhz506zd+\/eTpRlN0BEqY7xPjfSk0hwcXGxI4a9xM+FLqIm18uDbxnp+HJdyb5Eb4Uv4wQRkexnl6duCKQjQOozHadQ78osfm7EFdfwNPcUBdZL\/A7\/+bA59K8xk11SVPzxP95Ph6oQ2mJYpjjaEaQdPbKrfApHcQsEKiRA6rNCuB4UnUn8um1mbbeljnV+vdKeYk8eAcw7pueKZJxoZvW3HSHau00gjFlJcj8EshMg9ZmdWUhPBCt+bprTjQTVCfP\/Pm8O\/fmQ+ePFP5qJb94bH5RdWt7+5Yg59B8eN+b\/3J8ResgcMrIKvts6viLOLTOKVGEkWiziEZ6FQHcC7PXZ3B6SSfx0UsvGjRtjx\/sUkzsTswp8vZY6uHXGneogawFlx5e3P5kU+rF5wJhf\/tKYf\/qnKkzuWaadTs2bWiVa7ImZGyCQmgDHHKVGFdyNmcRPWifCdvbs2cQ1fGkFsgxS3Ra5pxE\/uUc698h\/HzXm17++94ioh2z\/4tGutnbEqN9ExdSsE3KIFsvodZTRJgKkPpvr7cziJygkxRi3yF3HBNesWVPLcocsbul5nt\/jj98LAUUhZD8j2ddIBNDzAbYyo0VNoXre5Cxu514IFCZA6rMwQi8LyCV+0hJd8iBbnem1evXq2F1ffGh5T\/GTEFBET3q6HVKJAHoUBaZlGRctZokUiRLTkua+phOwsy0BfhQ03T2525db\/HLX2KcHe4qfbZfsiG0rhaZC+2R72dUWiRYFBZNsyvYI5flMgNSnz97Jbxvil8ROvu7ZX\/nkUz+ANGj+rmCixf2i+Vkn22iUqN+KSZsW8QLP+kbg1q37k+L0y59vNmJPdgK5xK\/XSe7Zzaj+iUyRn5ojKiDTQe0r0DRoXsIqhPo9IG3qFEHMS5znfCRA6tNHrxSzKbP4xZ3k3m32ZzHzyns6l\/hp9Q1Pg2alXFQQmViTlTj395sAqc9+e6D8+jOJny5j2L59uxkeHo6siftb+WYWL7GQ+En1bhpU\/iZRITm+yDnuOGLWCJFxxOJ9nBKqI2CLn9TCIbfVsa6r5Ezi1+00h14L3+tqUFI9hcVPP+EbMhu0Dn8UnVgjNiKKdXiKOtIQsBe8P\/ywMSMjaZ7iHl8JIH55PNPCyTB5MCU9k3dijZQXt4MNwXeZ3qGsbgRIfzanfyB+eX0ZNxmGNGhemivSplJQ2tSpVsraxNz4eTADAXcSOF++MsDz6FbEr4gzRABJgxYh2PPZIqlTRLEnXm7IQYDxvxzQPHwkl\/hdvny5Z1M2bNiQuP9nz4cruKGUMb8ku0iDVuCx7kUiirUjp0KLgC2AjP+F2TUyiV+YTbxndaXiJxUQBXrTPdylGEVSqPKsprXs8UY31SVbw8ZdMitQ9knnah4BewIMi9\/D8y\/iV7bP3DWBLVsUXzbOMssrI1p07VFBdPdC0PtE\/N56q8xWUJYPBIj8fPBCMRsQv2L84p8mDVoF1crKjBPFrNGiPQnCNlRSYvbxkGmiyMoaSsGlELC3O5MCWfNXCtbaC0H8qkJOGrQqsn0p1z4lw97\/VEWym\/ilXQ9mz1bVD1W3sXLwCFd\/Cdi+Rvj664sitSN+ReileZat0dJQCv6eBx6Ib4Id+WVdupHn+BypL+4S0bSFExHN1+UY58vHzcenEL86vEIatA7Kfa0jSfzixvzcUzPcqFIaUtcMQlssEcjuXYhxvr6+xUqvHPErHWlCgaRB6yLdl3qyiF8aA6W7iBjJ+FLS1e21mzfT1JLunm4CKSW0IYpknC9dXwnpLsSvTm\/FCaDUz84wdXqhlXWpULr\/C4wyhFIEUifzNFEM7XQn43zNeAshfv3wY5wItuCw3H6gps70BMoUyCaJIenO9H0opDu9Fr\/r16+bnTt3mqWlpYjpnj17zMTERIfvuXPnzP79+6Pfp6amzOjoaCL7yhe55\/F63DFJrAvMQ5JnaiJgp1rlZ\/29V\/QYqhja6c66xmFrcmXrq\/FW\/Nzjk\/T3bdu2RSInwjg+Pm5mZmYiJ+rP69ati3Wql+InlhIFtv5N2BQAIhQ6eacpYsiyhqb0zpXt8Fb84pDLKfJySfQnUd\/CwoKZnp42AwMDRl4bGhpKjP68FT9taNwpEZIKZW+s5r77Gt4yH8XQjlx7jU2yrKHZHTRY8bOFUFzk\/u66zXvxU4M5Mb7Z77gWty6vGLrIkma5un\/vFX12c4WkOPV50p3N7LTBiJ+O\/x07dswMDw+viPQkElxcXFw2Jmi7TMRPr7GxMSP\/vL1IhXrrGgwrj0AWMSyv1uwlMbszO7MQnghC\/HS8T0RPJ7y4ac404nfjxo0QfHLfRjcKlDxM3MmZHB0Qll+xdgUBjdrSjhn2Qhi3001SmjMpkpTIj9MaepEO93VvxE\/E7OTJkxHJzZs3d8by4oQvLs3ZmLSn25fsKDBpA0mODgj3HYjlsQTsmaR6Q5x49Rq3K4JXbKiy\/CK28WxxAt6IX1xT3Bme9j1upBf8hJdevhTh+9a34u9C\/HrR43UIQAACywh4K3537941k5OTZvXq1bHjeI1Z6pClQ5a9h1aWurkXAhCAQIMIeCt+7gJ3ZW6nRINf5J61I\/U6OkAWyMeNCWath\/shAAEINJyAt+JXNvdgljp0a3g38dND49ghpuyuQ3kQgEADCSB+ITk1jfhpe9gsOyTPYisEIFAzAcSvZuCVVefuECOTYHSeNlPWKsNOwRCAQJgEEL8w\/ZZstcwKlfWAmgaVO1ms1DQv0x4IQKAgAcSvIEAvH5coUBYp2fs76bb6RIFeugyjIACBegkgfvXyrrc29\/hposB6+VMbBCDgLQHEz1vXlGiYvT29FEsUWCJcioIABEIkgPiF6LU8NsdFgYhgHpI8AwEINIAA4tcAJ2ZqghsFEglmwsfNEIBAMwggfs3wY7ZW6FkycQeeMTM0G0vuhgAEgiSA+AXptpKM7iaCpERLgkwxEICAjwQQPx+9UrdNiGDdxKkPAhDoMwHEr88O8K76JCEkHeqdqzAIAhDITwDxy8+u2U\/GiSCp0Gb7nNZBoEUEEL8WOTtXU+OWSMi+oewUkwsnD0EAAn4QQPz88IP\/VrhLJEiD+u8zLIQABBIJIH50jvQEZM\/QK1fu308aND077oQABLwigPh55Y4AjCENGoCTMBECEOhFAPHrRYjX4wmQBqVnQAACARNA\/AJ2Xt9NJw3adxdgAAQgkI9AMOJ38eJFc\/ToUTM7O2sGBwej1p47d87s378\/+nlqasqMjo4mUli7dq25ceNGPko8lUyANCi9AwIQCJBAEOJ3+\/Zts2vXrgivit\/169fN+Pi4mZmZif6uP69bty7WDYhfxb2TNGjFgCkeAhAok0AQ4icR3htvvGHu3LnTET\/528LCgpmenjYDAwNRVDg0NJQY\/SF+ZXabhLLi0qAjIzVUTBUQgAAEshHwXvwkwnv11VfNE088YU6cONERPxE7uSYmJqL\/3d9dDIhfto6R+27GAXOj40EIQKA+At6Ln4jayCfRgz3m50Z6EgkuLi52xBDxq68Tragpbms0FsX30SFUDQEIuAS8Fj+Z5DI\/Px8JmjvhJY\/4aePHxsaM\/OOqmADjgBUDpngIQCAvAW\/ET8Ts5MmTUTs2b95sXnjhBfOzn\/3MPPPMM0YmscSJH2nPvG6v8bl+p0Gl\/vXra2wwVUEAAiEQ8Eb8XFgy1rdz506ztLS07KXVq1ebubk5c+nSpWVpTia8eNzd+rEcQuqUf7IdGylXjzsHpkGgPwS8FT8Xhxv5sdShPx2mUK11p0Ht+rZuLWQ6D0MAAs0iEKz4iRtY5B5gZ6xzOYRdF9FfgJ0FkyFQHYFgxK8oApY6FCVY4vNuGrTK0yHOn79vONFfiU6kKAiETQDxC9t\/4Vpf13IIO\/oTkZVDePUgXg7kDbf\/YDkEChJA\/AoC5PGCBOoYB7SjP9dc0qEFHcjjEAiTAOIXpt+aZXXVyyHc8hHAZvUfWgOBHAQQvxzQeKQCAnUth5B65BJBvHnzfkM2bbqfDq2geRQJAQj4RQDx88sfWFNHGlQpuxEhAkj\/g0BrCCB+rXF1QA3t13IIQYQABtRRMBUC+QkgfvnZ8WSVBKoeB7Rtd+tiSUSVnqVsCHhBAPHzwg0YEUsgbhywqtmZLIinE0KgVQQQv1a5O9DGuuOAVS2Kt5dEkP4MtLNgNgTSEUD80nHirn4TiFuuULZAuQviOYW+316nfghURgDxqwwtBZdOoI5dYUh\/lu42CoSAjwQQPx+9gk3dCVQ9GcZOf0qKlQiQHgmBxhFA\/Brn0pY0qMoosI4Ua0vcRDMh4CsBxM9Xz2BXOgJVTYapUlzTtYy7IACBCgkgfhXCpeiaCMRFamUtiWAXmJqcSDUQqJcA4lcvb2qrikBcpFbGkgg7sixLUKtiQLkQgEBqAohfalTcGASBuCgwrwjai+yZ+BKE+zESAmkJIH5pSXFfWASSRDDLzE076it7TWFYNLEWAo0jgPg1zqU0qEMgLhUqL6ZJX7LgnY4EgUYTQPwa7V4aFxHIOh7o7inKRtd0JAg0joD34nfu3Dmzf\/\/+CPzmzZvN9PS0GRgYiH63X5uamjKjo6OJDlq7dq25ceNG4xxIgzIQSDseyCSXDFC5FQJhEvBa\/C5evGief\/55Mzc3Z9atW2eOHj0aUZ6YmDDXr1834+PjZmZmJvqb\/iz3xV2IX5gdtHSr06RCbZFkrK90F1AgBHwg4LX4idgNDQ3FRnQS9S0sLHQiwW73CmjEz4fu5pENSalQmRBjpz3TjA961CxMgQAE0hHwVvxu375tdu3aFUV5w8PDK1pjR4Hyovu7+wDil65DtO6upAXyV67cQ4H4ta5L0OB2EPBa\/Pbt22e2bt1qjhw5YpaWlpaN+bmRnkSCi4uLkVgmpT3172NjY0b+cUEgIpCUCkX86CAQaCwBr8VPIr81a9ZEqU25JicnzerVqyOByyN+THhpbD8up2FVbpNWjoWUAgEIlETAG\/ETMTt58mTULJnVKRNYnn322WVpT5kAI\/fNzs6aU6dORfdqpEfas6Qe0fZi3GUO7OzS9h5B+xtKwBvxc\/nevXs3ivS2b9\/eGfMT8Ttz5kwUCb7++uvL0pxMeGloD+1Xs+wz\/Vjn1y8vUC8EKiPgrfhJi+0ZnZr23LhxYzT7k6UOlfUJChYCEgGuWgULCECgoQS8Fj8VQF3kvmfPnmUTWljk3tBeSbMgAAEIVEzAe\/Erq\/0sdSiLJOVAAAIQCJ8A4he+D2kBBCAAAQhkJID4ZQTG7RCAAAQgED4BxC98H9ICCEAAAhDISADxywiM2yEAAQhAIHwCiF\/4PqQFEIAABCCQkQDilxEYt0MAAhCAQPgEEL\/wfUgLIAABCEAgIwHELyMwbocABCAAgfAJIH7h+5AWQAACEIBARgKIX0Zg3A4BCEAAAuETQPzC9yEtgAAEIACBjAQQv4zAuB0CEIAABMIngPiF70NaAAEIQAACGQkgfhmBcTsEIAABCIRPAPEL34e0AAIQgAAEMhJA\/DIC43YIQAACEAifAOIXvg9pAQQgAAEIZCSA+GUExu0QgAAEIBA+AcQvfB\/SAghAAAIQyEjAe\/E7evSoOXnyZNSsPXv2mImJiU4Tz507Z\/bv3x\/9PjU1ZUZHRxObv3btWnPjxo2MeLgdAhCAAASaSMBr8RNxW1hYMNPT0+bu3btm165dZtu2bZHIXb9+3YyPj5uZmZnIL\/rzunXrYv3kit8vfvELMzY21kSftqpN+LEZ7saP+LFuAl6Ln0R9cmm0Z\/9uC+PAwICR14aGhhKjP1f8iATr7mrV1Icfq+Fad6n4sW7i1dQXkh+9Fr+4yE+EcHh4OBK7JGGMcyviV01n73epIb3Z+s3K5\/rxo8\/eSW9bSH70WvwE+cWLF82OHTvM6tWrzdzcnNG0phvpiVAuLi4uGxO0XSZlSFlcEIAABCBQDQEJTE6fPl1N4SWX6rX4icAtLS1FY35yTU5Omo0bN0apzaziVzI3ioMABCAAgYAJeCN+9qzOzZs3RxNYnn322SiSk28TGgXKfbOzs+bUqVOZ0p4B+wjTIQABCECgZALeiJ\/brtu3b0ezO5PE780331yW5uw14aVkbhQHAQhAAAIBE\/BW\/IRpXNpTxv5EELMudQjYR5gOAQhAAAIlE\/Ba\/GRtn4zzXbhwIWp2kUXuJXOjOAhAAAIQCJiA1+IXMFdMhwAEIAABjwkgfh47B9MgAAEIQKAaAq0UP3tmqaxJ0dmk1SCm1DIIuClwNw2uE6QuX75sNmzYEM0IHhwcLKNqyiiJgIzTHzlyxBw\/fnyZb7q9H+WZnTt3RkueZBa4LHuSHZ24+kcgzo\/2+08ts\/db9tGPrRM\/WeiuyyWuXbvW+ZkPyv69mdLULG+uffv2mQMHDnQ2OrCfs3f8cXf\/SVM+91RLQD\/8Vq1ateyLSbf3o37hkbW9W7ZsWbbOt1prKT2JQJIfk77YSDm++rF14md\/MKpTtm\/fTvTn+fu925vLXRbT7V7Pm9lI8\/T0FZmwJmJnR+Xd3o\/2jG7Z2UmePXPmDNFfn3pJNz92842vfmyV+NnfQGSXGPf3PvUpqk1BwI4Q3CjdfXO5v6conlsqJCCp6EcffdTI\/5p1ER\/2ej+6Pu\/WByo0n6I\/IZDkR3nZPWjAhuarH1spfnakx+L4MN7b9tmNYrE9rudGer1SpGG0uHlWuh+CcZkX+\/3oRhNE9H70ibgvIfa4rVhpj8\/66kfEr8dRSH50N6ywNzzQI6x039f3339\/2UQKxM\/P\/oL4+emXrFYl+VE3INEvNfo74peVcAX390qzVFAlRVZEoNsOP6Q9K4JesNikD03drN59f\/qaLiuIIfjH06Sfu01kSvN8HZBaFfkJUDutwoSXOrpYNXXYKTCpwZ4JSnqsGuZFS01Kl+kh1O770fUjE16KeqCc59OIl+0rNzPjix9bJ34sdSjnDVBnKUkRu6ZV9EuN\/C\/7vrLUoU7vpK8r7kOTpQ7p+flyp+tHd7a1\/r5t27bo+DmWOvjiuU+iv5MnT0YWscjdI8d0McVd5O4ueGaRu\/9+TIoYWOTuv+9sC+P86C5yd\/dhZpF7WD7GWghAAAIQaCiB1qU9G+pHmgUBCEAAAhkIIH4ZYHErBCAAAQg0gwDi1ww\/0goIQAACEMhAAPHLAItbIQABCECgGQQQv2b4kVZAAAIQgEAGAohfBljcCgEIQAACzSCA+DXDj7SiAgJxB+hqNbLAfm5ubsXZgt02+HVNzLsTjayz2rFjx7Likg7wjdvqzX7ePnBUCsxrUwX4KRIClRJA\/CrFS+EhE+h25JWcMnH27NnO2XS6iFcW38suM3qJGLpn2KnIyAnl7uGuaXh1Oz7Gfl7tf+eddzpCbe\/GIccM7dq1K7J3eHg4elTsHRkZ4XzLNI7gnqAJIH5Buw\/jqyTQTfxsEZGoa3Jy0tjbrald7g738nc9nulrX\/uauXPnzrLDXdO0J+32bSrQUubMzEwUpdqRnZyOIXbrxtIi0vPz88vEO4093AOBEAkgfiF6DZtrIZBW\/B566CEzPj7eEZhuxtnHLX3wwQfLDnfViLBbWWkPYNYtqHSv017it2XLFvPiiy+aZ555ZkUqtxbYVAKBmgkgfjUDp7pwCHQTGjudee3atRUilqaVaXbHd8tR8fzwww+jk9Hlcsf77KjUFWY37amnYYgQE\/Wl8Rr3NIUA4tcUT9KO0gl0m\/BiC07eI1ryiJ+OLe7duzfaMV\/TqPb4o50WTTPhxY76RAR1Mo07GaZ0wBQIgT4SQPz6CJ+q\/SaQNcU4OztrBgcHUzcqj\/jFFW4fIfO5z31uWRSa5mBfGRtcXFw0u3fv7kyAyZLKTd1gboSARwQQP4+cgSl+EUgrfr0EJikyLEv8bDtFxPS4LpdmXCQnwnn48GFz8OBBI1HfkSNHzPHjx41Ohtm+fTszP\/3qllhTEgHErySQFNM8AmnFT1qeNAMzbranksojft3OUrOXLGgdvYRZoj65JIUaNxMU8Wtev6ZF9wggfvQECCQQyCJ+Wdf5SZV5xM89JVuFd2lpyUxPT0cRm311Ez876pN0bbeJMnQSCDSNAOLXNI\/SntIIZBE\/qTRugox74rxtXJz49YrU5Hn31OxudXQrT6LVoaGhzsQZFWQmvJTWhSjIYwKIn8fOwTQIQAACEKiGAOJXDVdKhQAEIAABjwkgfh47B9MgAAEIQKAaAv8fM2VDz4qPgbkAAAAASUVORK5CYII=","height":0,"width":0}}
%---
