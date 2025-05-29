classdef(Abstract)TransferLearning
	%全局常量
	properties(Constant)
		FullCalcium=TransferLearning.iFullCalcium
		QueryNTATS=memoize(@TransferLearning.iQueryNTATS);
		PcaTable=memoize(@TransferLearning.iPcaTable);
	end
	methods(Static)
		function Clear()
			clearAllMemoizedCaches;
			clear TransferLearning;
		end
		function MB=MOpBaseline
			MB=UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202505\MOp全钙.v2.mat');
			MB.TagSplitTrial(seconds([-3,3]));
			%由于行为和水混用CD2通道导致多拆出了一个假回合
			MB.RemoveTrials(MB.TableQuery("TrialUID",DateTime=datetime('2022-08-06 20:26:00',TimeZone='local'),TrialIndex=31).TrialUID);

			%该日期行为记录了99回合，标通道拆出100回合，每个回合的刺激类型对不上
			MB.RemoveDateTimes(datetime('2023-01-13 09:39:00',TimeZone='local'));
			TrialDuration=seconds(6);
			LLP=MB.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			MB.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			MB.ResampleTrials(milliseconds(125),TrialDuration);
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
			GroupNtats=TransferLearning.FullCalcium.QueryNTATS(UniExp.ReadQueryTable(TransferLearning.ProjectPath('查询表.xlsx'),Sheetname),UniExp.Flags.dFdF0,1:30,UniExp.Flags.Median);
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
	end
end