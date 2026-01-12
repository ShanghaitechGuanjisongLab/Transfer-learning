classdef(Abstract)TransferLearning
	%全局常量
	properties(Constant)
		FullCalcium=TransferLearning.iFullCalcium
		QueryNTATS=memoize(@TransferLearning.iQueryNTATS);
		PcaTable=memoize(@TransferLearning.iPcaTable);
		Xs=seconds(linspace(-3,3,48)).';
	end
	properties(Constant,Access=private)
		MemoMOpBaseline=memoize(@TransferLearning.iMOpBaseline);
		MemoAudioLightBaseline=memoize(@TransferLearning.iAudioLightBaseline);
		MemoLightAudioBaseline=memoize(@TransferLearning.iLightAudioBaseline);
		MemoRSPd=memoize(@TransferLearning.iRSPd);
		MemoTHInhibit=memoize(@TransferLearning.iTHInhibit);
		MemoVacation7=memoize(@TransferLearning.iVacation7);
		MemoInterspersed=memoize(@TransferLearning.iInterspersed);
		MemoscFLARE=memoize(@TransferLearning.iscFLARE);
	end
	methods(Static)
		function Clear()
			clearAllMemoizedCaches;
			clear TransferLearning;
		end
		function MB=MOpBaseline
			TransferLearning.Exception.DataSet_deprecated.Warn("除非你想分析光声有穿插数据，否则请分别用AudioLightBaseline和LightAudioBaseline");
			MB=TransferLearning.MemoMOpBaseline();
		end
		function AL=AudioLightBaseline
			AL=TransferLearning.MemoAudioLightBaseline();
		end
		function LA=LightAudioBaseline
			LA=TransferLearning.MemoLightAudioBaseline();
		end
		function MS=MeanSem(Data,ReduceDimension,ConcatDimension)
			[Mean,Sem]=MATLAB.DataFun.MeanSem(Data,ReduceDimension);
			MS=cat(ConcatDimension,Mean,Sem);
		end
		function RSP=RSPd
			RSP=TransferLearning.MemoRSPd();
		end
		function Inhibit=THInhibit
			Inhibit=TransferLearning.MemoTHInhibit();
		end
		function V7Inhibit=Vacation7
			V7Inhibit=TransferLearning.MemoVacation7();
		end
		function I=Interspersed
			I=TransferLearning.MemoInterspersed();
		end
		function F=scFLARE
			F=TransferLearning.MemoscFLARE();
		end
		function DrawCueWaterLines(Ax)
			if nargin
				Ax={Ax};
			else
				Ax={};
			end
			xline(Ax{:},0,':');
			xline(Ax{:},1,'-');
		end
	end
	methods(Access=private,Static)
		function FC=iFullCalcium
			FC=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202408\全钙大模型v6.mat");
			FC.TrialSignals.ResampledSignal(:,41:end)=[];
		end
		function GroupNtats=iQueryNTATS(Sheetname,DifferentCells)
			arguments
				Sheetname
				DifferentCells=TransferLearning.Flags.Different_cells_replenished;
			end
			GroupNtats=TransferLearning.FullCalcium.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),Sheetname),UniExp.Flags.dFdF0,1:24,UniExp.Flags.Median);
			switch DifferentCells
				case TransferLearning.Flags.Different_cells_not_handled
				case TransferLearning.Flags.Different_cells_replenished
					try
						GroupNtats=UniExp.NtatsCellReplenish(GroupNtats);
					catch ME
						if ME.identifier~="UniExp:Exception:No_need_to_replenish"
							ME.rethrow;
						end
					end
				case TransferLearning.Flags.Different_cells_stripped
					GroupNtats=UniExp.NtatsCellStrip(GroupNtats);
				otherwise
					TransferLearning.Exception.Different_cell_processing_strategies_unknown.Throw;
			end
		end
		function PT=iPcaTable(Sheetname)
			PT=UniExp.LinearPca(TransferLearning.QueryNTATS(Sheetname,TransferLearning.Flags.Different_cells_replenished).NTATS,12);
		end
		function MB=iMOpBaseline
			MB=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202512\MOp全钙.v4.mat");
			MB.TagSplitTrial(seconds([-3,3]));
			%由于行为和水混用CD2通道导致多拆出了一个假回合
			MB.RemoveTrials(MB.TableQuery("TrialUID",DateTime=datetime('2022-08-06 20:26:00'),TrialIndex=31).TrialUID);

			%该日期行为记录了99回合，标通道拆出100回合，每个回合的刺激类型对不上
			MB.RemoveDateTimes(datetime('2023-01-13 09:39:00'));
			TrialDuration=seconds(6);
			LLP=MB.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			MB.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			MB.ResampleTrials(milliseconds(125),TrialDuration);
			MB.DateTimes.DateTime.TimeZone='';
			MB.Blocks.DateTime.TimeZone='';
		end
		function AL=iAudioLightBaseline
			AL=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202601\声光迁移MOp成像（含学会后三次）.v5.mat");
			AL.TagSplitTrial(seconds([-3,3]));

			%该日期行为记录了99回合，标通道拆出100回合，每个回合的刺激类型对不上
			AL.RemoveDateTimes(datetime('2023-01-13 09:39:00'));
			TrialDuration=seconds(6);
			LLP=AL.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			AL.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			AL.ResampleTrials(milliseconds(125),TrialDuration);
		end
		function LA=iLightAudioBaseline
			LA=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202512\光声迁移无穿插MOp成像（含学会后三次）.v3.mat");
			LA.TagSplitTrial(seconds([-3,3]));
			%由于行为和水混用CD2通道导致多拆出了一个假回合
			LA.RemoveTrials(LA.TableQuery("TrialUID",DateTime=datetime('2022-08-06 20:26:00'),TrialIndex=31).TrialUID);

			%该日期行为记录了99回合，标通道拆出100回合，每个回合的刺激类型对不上
			LA.RemoveDateTimes(datetime('2023-01-13 09:39:00'));
			TrialDuration=seconds(6);
			LLP=LA.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			LA.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			LA.ResampleTrials(milliseconds(125),TrialDuration);
		end
		function RSP=iRSPd
			RSP=UniExp.DataSet('\\data-server-2\个人数据\张天夫\202508\RSP-G6f观察RSP 声水转光水（含学会后三次和红参）.v2.mat');
			RSP.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=RSP.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			RSP.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			RSP.ResampleTrials(milliseconds(125),TrialDuration);
			RSP.Mice=unique(RSP.DateTimes(:,"Mouse"));
			RSP.Mice.Paradigm(:)="声光无穿插";
		end
		function Inhibit=iTHInhibit
			Inhibit=UniExp.DataSet('\\data-server-2\个人数据\张天夫\202507\PO抑制MOp成像.v3.mat');
			Inhibit.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=Inhibit.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			Inhibit.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			Inhibit.ResampleTrials(milliseconds(125),TrialDuration);
		end
		function V7Inhibit=iVacation7
			V7Inhibit=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202601\WT声光等待7天后迁移.v3.mat");
			V7Inhibit.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=V7Inhibit.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			V7Inhibit.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			V7Inhibit.ResampleTrials(milliseconds(125),TrialDuration);
		end
		function I=iInterspersed
			I=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202511\声光穿插迁移MOp成像v3.mat");
			I.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=I.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			I.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			I.ResampleTrials(milliseconds(125),TrialDuration);
			I.AddRepeatIndex;
		end
		function F=iscFLARE
			F=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202601\MOp+RSP scFLARE 化学抑制钙成像.v1.mat");
			F.TagSplitTrial(seconds([-3,3]));
			LLP=F.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			F.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			F.AddRepeatIndex;
		end
	end
end