classdef(Abstract)TransferLearning
	%全局常量
	properties(Constant)
		FullCalcium=TransferLearning.iFullCalcium
		QueryNTATS=memoize(@TransferLearning.iQueryNTATS);
		PcaTable=memoize(@TransferLearning.iPcaTable);
		Xs=seconds(linspace(-3,3,48)).';
		MOpBaseline=memoize(@TransferLearning.iMOpBaseline);
		AudioLightBaseline=memoize(@TransferLearning.iAudioLightBaseline);
		LightAudioBaseline=memoize(@TransferLearning.iLightAudioBaseline);
		RSPd=memoize(@TransferLearning.iRSPd);
		THInhibit=memoize(@TransferLearning.iTHInhibit);
		Vacation7=memoize(@TransferLearning.iVacation7);
		ALInterspersed=memoize(@TransferLearning.iALInterspersed);
		LAInterspersed=memoize(@TransferLearning.iLAInterspersed);
		scFLARE=memoize(@TransferLearning.iscFLARE);
		ALPureBehavior=memoize(@()UniExp.DataSet("\\data-server-2\个人数据\张天夫\202511\基本迁移行为 声水转光水.v2.mat"));
		LAPureBehavior=memoize(@()UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202601\基本迁移行为 光水转声水.v3.mat"));
		Fig35=TransferLearning.iFig35;
		Fig37=TransferLearning.iFig37;
		Fig351=TransferLearning.iFig351;
		Fig341=TransferLearning.iFig341;
	end
	methods(Static)
		function Clear()
			clearAllMemoizedCaches;
			clear TransferLearning;
		end
		function MS=MeanSem(Data,ReduceDimension,ConcatDimension)
			[Mean,Sem]=MATLAB.DataFun.MeanSem(Data,ReduceDimension);
			MS=cat(ConcatDimension,Mean,Sem);
		end
		function P=ProjectPath(varargin)
			Root=fileparts(mfilename('fullpath'));
			P=fullfile(Root,varargin{:});
		end
		function C=FigurePalette(N)
			arguments
				N (1,1) double {mustBeInteger,mustBePositive}
			end
			Base=[1,0,0;0,0,1;0,0,0;0,0.6809,0];
			if N<=size(Base,1)
				C=Base(1:N,:);
				return;
			end
			RepeatCount=ceil(N/size(Base,1));
			C=repmat(Base,RepeatCount,1);
			C=C(1:N,:);
		end
		function PrintFigure(Fig, Path, Options)
			arguments
				Fig (1,1) matlab.ui.Figure
				Path {mustBeTextScalar}
				Options.ForceLegendOrColorbar (1,1) logical = false
			end
			Path=char(string(Path));
			OutDir=fileparts(Path);
			if ~isempty(OutDir) && ~isfolder(OutDir)
				mkdir(OutDir);
			end
			OldInvertHardcopy=Fig.InvertHardcopy;
			Cleaner=onCleanup(@()set(Fig,'InvertHardcopy',OldInvertHardcopy));
			Fig.InvertHardcopy='off';
			if Options.ForceLegendOrColorbar
				drawnow;
			end
			print(Fig, Path, '-dsvg');
		end
		function DrawCueWaterLines(Ax)
			if nargin
				Ax={Ax};
			else
				Ax={};
			end
			CueLine = xline(Ax{:},0,':');
			WaterLine = xline(Ax{:},1,'-');
			for h = [CueLine, WaterLine]
				try
					h.HandleVisibility = 'off';
				catch
				end
				try
					h.Annotation.LegendInformation.IconDisplayStyle = 'off';
				catch
				end
				try
					if isprop(h, 'PickableParts'); h.PickableParts = 'none'; end
					if isprop(h, 'HitTest'); h.HitTest = 'off'; end
				catch
				end
			end
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
			AL=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202512\声光迁移MOp成像（含学会后三次）.v5.mat");
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
			Inhibit=UniExp.DataSet("\\Data-Server-2\个人数据\杨青宁\202603\PO抑制MOp成像.v5.mat");
			Inhibit.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=Inhibit.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			Inhibit.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			Inhibit.ResampleTrials(milliseconds(125),TrialDuration);
            Inhibit.AddBehavior;
		end
		function V7Inhibit=iVacation7
			V7Inhibit=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202601\WT声光等待7天后迁移.v3.mat");
			V7Inhibit.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=V7Inhibit.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			V7Inhibit.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			V7Inhibit.ResampleTrials(milliseconds(125),TrialDuration);
		end
		function I=iALInterspersed
			I=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202511\声光穿插迁移MOp成像v3.mat");
			I.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=I.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			I.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			I.ResampleTrials(milliseconds(125),TrialDuration);
			I.AddRepeatIndex;
		end
		function I=iLAInterspersed
			I=UniExp.DataSet("\\data-server-2\个人数据\张天夫\202601\光声迁移MOp成像有穿插.v5.mat");
			I.TagSplitTrial(seconds([-3,3]));
			TrialDuration=seconds(6);
			LLP=I.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			I.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			I.ResampleTrials(milliseconds(125),TrialDuration);
			I.AddRepeatIndex;
			I.Mice=unique(I.DateTimes(:,"Mouse"));
			I.Mice.Paradigm(:)="光声有穿插";
		end
		function F=iscFLARE
			F=UniExp.DataSet("\\Data-Server-2\个人数据\张天夫\202601\MOp+RSP scFLARE 化学抑制钙成像.v1.mat");
			F.TagSplitTrial(seconds([-3,3]));
			LLP=F.CheckForLightLeakage(seconds([0,0.2]),["LightOnly","LightWater"]);
			F.LightLeakageInterpolation(LLP.BlockUID(LLP.Probability>0.95),seconds([0,0.2]),["LightOnly","LightWater"]);
			F.AddRepeatIndex;
		end
		function S=iFig35
			S=builtin('struct', ...
				'iQueryLightWaterBlocks',@(DS,UseBehavior)TransferLearning.iFig35QueryLightWaterBlocks(DS,UseBehavior), ...
				'iNormalizeDateTime',@(dt)TransferLearning.iFig35NormalizeDateTime(dt), ...
				'iSessionizeByDateTime',@(T)TransferLearning.iFig35SessionizeByDateTime(T), ...
				'iAddSessionIndex',@(T)TransferLearning.iFig35AddSessionIndex(T), ...
				'iRanksumSafe',@(x,y)TransferLearning.iFig35RanksumSafe(x,y), ...
				'iPerMouseTable',@(Sess)TransferLearning.iFig35PerMouseTable(Sess), ...
				'iAddFirstTransferPerf',@(PerMouse,Sess)TransferLearning.iFig35AddFirstTransferPerf(PerMouse,Sess));
		end
		function S=iFig351
			S=builtin('struct', ...
				'BuildStartSessionBlockTagMetrics',@()TransferLearning.iBuildStartSessionBlockTagMetrics());
		end
		function S=iFig341
			S=builtin('struct', ...
				'BuildStateSpaceSummary',@(varargin)TransferLearningFig341Compat.BuildStateSpaceSummary(varargin{:}), ...
				'PlotMetricByLayer',@(varargin)TransferLearningFig341Compat.PlotMetricByLayer(varargin{:}));
		end
		function S=iFig37
			S=builtin('struct', ...
				'iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer',@(varargin)TransferLearning.iFig37BuildProbTransferGivenLearnedAudio1sPerMouseLayer(varargin{:}));
		end
		function T=iFig35QueryLightWaterBlocks(DS,UseBehavior)
			arguments
				DS
				UseBehavior (1,1) logical = false
			end
			if UseBehavior
				varsTry=["Mouse","DateTime","Stimulus","Phase","Behavior","Performance"];
				varsFallback=["Mouse","DateTime","Stimulus","Phase","Behavior"];
			else
				varsTry=["Mouse","DateTime","Stimulus","Phase","Performance"];
				varsFallback=varsTry;
			end
			try
				T=DS.TableQuery(varsTry,Stimulus="LightWater");
			catch
				T=DS.TableQuery(varsFallback,Stimulus="LightWater");
			end
			if isempty(T)
				return;
			end
			T.Stimulus=string(T.Stimulus);
			T=T(T.Stimulus=="LightWater",:);
			if ismember('Behavior',T.Properties.VariableNames) && ~ismember('Performance',T.Properties.VariableNames)
				T.Performance=double(T.Behavior);
			end
		end
		function dt=iFig35NormalizeDateTime(dt)
			dt=datetime(dt);
			if isdatetime(dt) && ~isempty(dt.TimeZone)
				dt.TimeZone='';
			end
		end
		function S=iFig35SessionizeByDateTime(T)
			useBehavior=ismember('Behavior',string(T.Properties.VariableNames));
			if ~ismember('Phase',T.Properties.VariableNames)
				T.Phase=repmat(missing,height(T),1);
			end
			if useBehavior
				T=T(:,{'Mouse','DateTime','Behavior','Phase','Group'});
			else
				T=T(:,{'Mouse','DateTime','Performance','Phase','Group'});
			end
			T.Mouse=string(T.Mouse);
			T.Group=string(T.Group);
			T=sortrows(T,{'Group','Mouse','DateTime'});
			if useBehavior
				val=double(T.Behavior);
			else
				val=double(T.Performance);
			end
			[G,groupKeys,mouseKeys,dtKeys]=findgroups(T.Group,T.Mouse,T.DateTime);
			perf=splitapply(@(x)mean(x,'omitnan'),val,G);
			phaseSession=splitapply(@(x)TransferLearning.iFig35PickSessionPhase(x),string(T.Phase),G);
			S=table(groupKeys,mouseKeys,dtKeys,perf,phaseSession,'VariableNames',{'Group','Mouse','DateTime','Performance','Phase'});
		end
		function ph=iFig35PickSessionPhase(phases)
			phases=string(phases);
			phases=phases(~ismissing(phases) & phases~="");
			if isempty(phases)
				ph="";
				return;
			end
			[u,~,ic]=unique(phases);
			counts=accumarray(ic,1);
			[~,ix]=max(counts);
			ph=u(ix);
		end
		function T=iFig35AddSessionIndex(T)
			T.Group=string(T.Group);
			T.Mouse=string(T.Mouse);
			T=sortrows(T,{'Group','Mouse','DateTime'});
			[G,~]=findgroups(T.Group,T.Mouse);
			sessCell=splitapply(@(x){(1:numel(x))'},T.DateTime,G);
			T.Session=vertcat(sessCell{:});
		end
		function [p,h]=iFig35RanksumSafe(x,y)
			x=double(x(:));
			y=double(y(:));
			x=x(isfinite(x));
			y=y(isfinite(y));
			if isempty(x) || isempty(y)
				p=NaN;
				h=NaN;
				return;
			end
			[p,h]=ranksum(x,y);
		end
		function PerMouse=iFig35PerMouseTable(Sess)
			PerMouse=unique(Sess(:,{'Group','Mouse'}),'rows','stable');
		end
		function PerMouse=iFig35AddFirstTransferPerf(PerMouse,Sess)
			if ~ismember('Session',Sess.Properties.VariableNames)
				Sess=TransferLearning.iFig35AddSessionIndex(Sess);
			end
			PerMouse.TransferFirstPerf=nan(height(PerMouse),1);
			for i=1:height(PerMouse)
				isRow=string(Sess.Group)==string(PerMouse.Group(i)) & string(Sess.Mouse)==string(PerMouse.Mouse(i));
				S1=Sess(isRow,:);
				if isempty(S1)
					continue;
				end
				S1=sortrows(S1,{'Session','DateTime'});
				ix=[];
				if ismember('Phase',S1.Properties.VariableNames)
					ix=find(string(S1.Phase)=="Transfer",1,'first');
				end
				if isempty(ix)
					ix=find(S1.Session==1,1,'first');
				end
				if isempty(ix)
					ix=1;
				end
				PerMouse.TransferFirstPerf(i)=double(S1.Performance(ix));
			end
		end
		function Sess=iBuildStartSessionBlockTagMetrics
			initialLAB=TransferLearning.iBuildStartSessionsForDataset(TransferLearning.LightAudioBaseline(),"Naive","LightWater","Naive","LightAudioBaseline",strings(0,1));
			badNaive=TransferLearning.iFindMiceWithAudioWaterInPhase(TransferLearning.LAInterspersed(),"Naive");
			initialLAI=TransferLearning.iBuildStartSessionsForDataset(TransferLearning.LAInterspersed(),"Naive","LightWater","Naive","LAInterspersed",badNaive);
			transferALB=TransferLearning.iBuildStartSessionsForDataset(TransferLearning.AudioLightBaseline(),"Transfer","LightWater","Transfer","AudioLightBaseline",strings(0,1));
			Sess=[initialLAB;initialLAI;transferALB];
			Sess=sortrows(Sess,{'Group','Mouse','DateTime'});
		end
		function Sess=iBuildStartSessionsForDataset(DS,PhaseName,StimulusName,GroupName,SourceName,ExcludeMice)
			arguments
				DS
				PhaseName (1,1) string
				StimulusName (1,1) string
				GroupName (1,1) string
				SourceName (1,1) string
				ExcludeMice (:,1) string
			end
			Q=DS.TableQuery(["Mouse","DateTime","BlockUID"],Phase=char(PhaseName),Stimulus=char(StimulusName));
			if isempty(Q)
				Sess=table;
				return;
			end
			Q.Mouse=string(Q.Mouse);
			Q.DateTime=TransferLearning.iFig35NormalizeDateTime(Q.DateTime);
			Q=unique(Q(:,{'Mouse','DateTime','BlockUID'}),'rows');
			if ~isempty(ExcludeMice)
				Q=Q(~ismember(Q.Mouse,ExcludeMice),:);
			end
			firstRows=splitapply(@(dt){min(dt)},Q.DateTime,findgroups(Q.Mouse));
			firstDt=vertcat(firstRows{:});
			mouseList=unique(Q.Mouse,'stable');
			keep=ismember(Q.DateTime,firstDt) & ismember(Q.Mouse,mouseList);
			Q=Q(keep,:);
			[G,mice,dts]=findgroups(Q.Mouse,Q.DateTime);
			blockCells=splitapply(@(x){x},uint64(Q.BlockUID),G);
			DT=DS.DateTimes(:,{'DateTime','SeriesInterval'});
			DT.DateTime=TransferLearning.iFig35NormalizeDateTime(DT.DateTime);
			DT=unique(DT,'rows','stable');
			seriesCell=arrayfun(@(dt)DT.SeriesInterval(find(DT.DateTime==dt,1,'first')),dts,'UniformOutput',false);
			seriesInterval=vertcat(seriesCell{:});
			SessionDurationSec=nan(numel(blockCells),1);
			SessionLickSec=nan(numel(blockCells),1);
			SessionLickFraction=nan(numel(blockCells),1);
			RepGapSec=nan(numel(blockCells),1);
			RepIntervalLickSec=nan(numel(blockCells),1);
			CD1State=cell(numel(blockCells),1);
			CD2State=cell(numel(blockCells),1);
			RepPeak1Index=nan(numel(blockCells),1);
			RepPeak2Index=nan(numel(blockCells),1);
			for i=1:numel(blockCells)
				M=TransferLearning.iSessionBlockTagMetrics(DS,blockCells{i},seconds(seriesInterval(i)));
				SessionDurationSec(i)=M.SessionDurationSec;
				SessionLickSec(i)=M.SessionLickSec;
				SessionLickFraction(i)=M.SessionLickFraction;
				RepGapSec(i)=M.RepGapSec;
				RepIntervalLickSec(i)=M.RepIntervalLickSec;
				CD1State{i}=M.CD1State;
				CD2State{i}=M.CD2State;
				RepPeak1Index(i)=M.RepPeak1Index;
				RepPeak2Index(i)=M.RepPeak2Index;
			end
			Sess=table(mice,repmat(GroupName,numel(mice),1),repmat(SourceName,numel(mice),1),dts,seconds(seriesInterval),SessionDurationSec,SessionLickSec,SessionLickFraction,RepGapSec,RepIntervalLickSec,CD1State,CD2State,RepPeak1Index,RepPeak2Index, ...
				'VariableNames',{'Mouse','Group','Source','DateTime','SeriesIntervalSec','SessionDurationSec','SessionLickSec','SessionLickFraction','RepGapSec','RepIntervalLickSec','CD1State','CD2State','RepPeak1Index','RepPeak2Index'});
		end
		function M=iSessionBlockTagMetrics(DS,BlockUIDs,SeriesIntervalSec)
			blockUIDs=uint64(BlockUIDs(:));
			allCd1=[];
			allCd2=[];
			for bu=blockUIDs.'
				ix=find(uint64(DS.Blocks.BlockUID)==bu,1,'first');
				if isempty(ix)
					continue;
				end
				bt=DS.Blocks.BlockTags{ix};
				allCd1=[allCd1;double(bt.CD1(:))]; %#ok<AGROW>
				allCd2=[allCd2;double(bt.CD2(:))]; %#ok<AGROW>
			end
			cd1State=TransferLearning.iLogicalChannelState(allCd1);
			cd2State=TransferLearning.iLogicalChannelState(allCd2);
			starts=find(diff([false;cd1State])>0);
			if numel(starts)>=2
				[gaps,ix]=max(diff(starts)*SeriesIntervalSec);
				p1=starts(ix);
				p2=starts(ix+1);
				repGapSec=gaps;
				repIntervalLickSec=sum(cd2State(p1:p2-1))*SeriesIntervalSec;
			else
				p1=1;
				p2=max(2,numel(cd1State));
				repGapSec=(p2-p1)*SeriesIntervalSec;
				repIntervalLickSec=sum(cd2State(max(1,p1):max(1,p2-1)))*SeriesIntervalSec;
			end
			M=builtin('struct', ...
				'SessionDurationSec',numel(cd2State)*SeriesIntervalSec, ...
				'SessionLickSec',sum(cd2State)*SeriesIntervalSec, ...
				'SessionLickFraction',sum(cd2State)/max(numel(cd2State),1), ...
				'RepGapSec',repGapSec, ...
				'RepIntervalLickSec',repIntervalLickSec, ...
				'CD1State',cd1State, ...
				'CD2State',cd2State, ...
				'RepPeak1Index',p1, ...
				'RepPeak2Index',p2);
		end
		function state=iLogicalChannelState(x)
			x=double(x(:));
			if isempty(x)
				state=false(0,1);
				return;
			end
			lo=quantile(x,0.1);
			hi=quantile(x,0.9);
			thr=(lo+hi)/2;
			state=x>thr;
		end
		function badMice=iFindMiceWithAudioWaterInPhase(DS,PhaseName)
			T=DS.TableQuery(["Mouse","BlockUID"],Phase=char(PhaseName));
			if isempty(T)
				badMice=strings(0,1);
				return;
			end
			Tr=DS.Trials;
			TrStim=string(Tr.Stimulus);
			TrBU=uint64(Tr.BlockUID);
			T.Mouse=string(T.Mouse);
			blkBU=uint64(T.BlockUID);
			mice=unique(T.Mouse);
			bad=false(size(mice));
			for i=1:numel(mice)
				bu=blkBU(T.Mouse==mice(i));
				rows=ismember(TrBU,bu);
				bad(i)=any(TrStim(rows)=="AudioWater");
			end
			badMice=mice(bad);
		end
		function R=iFig37BuildProbTransferGivenLearnedAudio1sPerMouseLayer(varargin)
			Parser=inputParser;
			Parser.addParameter('DataSet',TransferLearning.AudioLightBaseline());
			Parser.addParameter('Source',"AudioLightBaseline");
			Parser.parse(varargin{:});
			Options=Parser.Results;

			DS=Options.DataSet;
			xs=TransferLearning.Xs;
			if isduration(xs)
				xsSec=seconds(xs);
			else
				xsSec=double(xs);
			end
			baseMask=(xsSec>=-3) & (xsSec<0);
			[idx1s,ok1s]=TransferLearning.iFig37FindTimeIndex(xsSec,1,0.25);
			if ~ok1s
				error('iBuildProb:No1s','Cannot find sample close to 1 s.');
			end
			kSigma=3;

			TLearn=DS.TableQuery(["Mouse","DateTime"],Phase="Learned",Stimulus="AudioWater",Design="AudioWater");
			TTran=DS.TableQuery(["Mouse","DateTime","Behavior"],Phase="Transfer",Stimulus="LightWater",Design="LightWater");
			if isempty(TLearn) || isempty(TTran)
				R=TransferLearning.iFig37EmptyResult();
				return;
			end

			TLearn.Mouse=string(TLearn.Mouse);
			TLearn.DateTime=TransferLearning.iFig35NormalizeDateTime(TLearn.DateTime);
			TTran.Mouse=string(TTran.Mouse);
			TTran.DateTime=TransferLearning.iFig35NormalizeDateTime(TTran.DateTime);

			dtLearnT=groupsummary(TLearn,"Mouse","max","DateTime");
			dtLearnT.Properties.VariableNames{end}='DateTimeLearned';
			dtTranT=groupsummary(TTran(:,["Mouse","DateTime"]),"Mouse","min","DateTime");
			dtTranT.Properties.VariableNames{end}='DateTimeTransfer';

			Sess=innerjoin(dtLearnT(:,["Mouse","DateTimeLearned"]),dtTranT(:,["Mouse","DateTimeTransfer"]),'Keys','Mouse');
			if isempty(Sess)
				R=TransferLearning.iFig37EmptyResult();
				return;
			end

			CellMeta=DS.Cells(:,["CellUID","ZLayer"]);
			CellMeta.CellUID=uint64(CellMeta.CellUID);
			CellMeta.ZLayer=string(CellMeta.ZLayer);

			Rows=TransferLearning.iFig37EmptyResult();
			for iRow=1:height(Sess)
				mouseName=string(Sess.Mouse(iRow));
				dtLearned=Sess.DateTimeLearned(iRow);
				dtTransfer=Sess.DateTimeTransfer(iRow);
				behMask=TTran.Mouse==mouseName & TTran.DateTime==dtTransfer;
				behSession=double(TTran.Behavior(behMask));

				GLearn=DS.QueryNTATS(struct('Mouse',mouseName,'DateTime',dtLearned,'Phase','Learned','Stimulus','AudioWater','Design','AudioWater'),UniExp.Flags.ZScore,1:24,UniExp.Flags.Median);
				GTran=DS.QueryNTATS(struct('Mouse',mouseName,'DateTime',dtTransfer,'Phase','Transfer','Stimulus','LightWater','Design','LightWater'),UniExp.Flags.ZScore,1:24,UniExp.Flags.Median);

				[XLearn,cellLearn]=TransferLearning.iFig37ExtractNtats2D(GLearn);
				[XTran,cellTran]=TransferLearning.iFig37ExtractNtats2D(GTran);
				if isempty(XLearn) || isempty(XTran)
					continue;
				end

				[commonCells,idxL,idxT]=intersect(cellLearn,cellTran,'stable');
				if isempty(commonCells)
					continue;
				end

				XLearn=XLearn(idxL,:);
				XTran=XTran(idxT,:);
				cellLayers=TransferLearning.iFig37MapLayer(CellMeta,commonCells);

				learnedActive=TransferLearning.iFig37IsActiveAt1s(XLearn,baseMask,idx1s,kSigma);
				transferActive=TransferLearning.iFig37IsActiveAt1s(XTran,baseMask,idx1s,kSigma);

				mask23=TransferLearning.iFig37IsLayer23(cellLayers);
				mask5=TransferLearning.iFig37IsLayer5(cellLayers);

				[n23,prob23]=TransferLearning.iFig37ConditionalProb(learnedActive,transferActive,mask23);
				[n5,prob5]=TransferLearning.iFig37ConditionalProb(learnedActive,transferActive,mask5);
				probHit23=NaN;
				probHit5=NaN;
				probMiss23=NaN;
				probMiss5=NaN;
				if any(behSession==1) && any(behSession==0)
					QHM=table(["Hit";"Miss"],repmat(categorical("Transfer"),2,1),repmat(categorical("LightWater"),2,1),repmat(categorical("LightWater"),2,1),[1;0],repmat(mouseName,2,1),repmat(dtTransfer,2,1), ...
						'VariableNames',{'GroupName','Phase','Design','Stimulus','Behavior','Mouse','DateTime'});
					GTranHM=DS.QueryNTATS(QHM,UniExp.Flags.ZScore,1:24,UniExp.Flags.Median);
					[XHM,cellHM]=TransferLearning.iFig37ExtractNtats3D(GTranHM);
					if ~isempty(XHM)
						[commonHM,idxCommon,idxHM]=intersect(commonCells,cellHM,'stable');
						if ~isempty(commonHM)
							learnedActiveHM=learnedActive(idxCommon);
							mask23HM=mask23(idxCommon);
							mask5HM=mask5(idxCommon);
							XHit=XHM(idxHM,:,1);
							XMiss=XHM(idxHM,:,2);
							transferActiveHit=TransferLearning.iFig37IsActiveAt1s(XHit,baseMask,idx1s,kSigma);
							transferActiveMiss=TransferLearning.iFig37IsActiveAt1s(XMiss,baseMask,idx1s,kSigma);
							[~,probHit23]=TransferLearning.iFig37ConditionalProb(learnedActiveHM,transferActiveHit,mask23HM);
							[~,probHit5]=TransferLearning.iFig37ConditionalProb(learnedActiveHM,transferActiveHit,mask5HM);
							[~,probMiss23]=TransferLearning.iFig37ConditionalProb(learnedActiveHM,transferActiveMiss,mask23HM);
							[~,probMiss5]=TransferLearning.iFig37ConditionalProb(learnedActiveHM,transferActiveMiss,mask5HM);
						end
					end
				end

				transferHitRate=mean(behSession,'omitnan');
				Rows=[Rows;table(mouseName,dtLearned,dtTransfer,transferHitRate,n23,n5,prob23,prob5,probHit23,probHit5,probMiss23,probMiss5,string(Options.Source), ...
					'VariableNames',TransferLearning.iFig37EmptyResult().Properties.VariableNames)]; %#ok<AGROW>
			end
			R=Rows;
		end
		function T=iFig37EmptyResult
			T=table(strings(0,1),NaT(0,1),NaT(0,1),nan(0,1),nan(0,1),nan(0,1),nan(0,1),nan(0,1),nan(0,1),nan(0,1),nan(0,1),nan(0,1),strings(0,1), ...
				'VariableNames',{'Mouse','DateTimeLearned','DateTimeTransfer','TransferHitRate','NLearnedActive23','NLearnedActive5','Prob23','Prob5','ProbHit23','ProbHit5','ProbMiss23','ProbMiss5','Source'});
		end
		function [X,cellUID]=iFig37ExtractNtats2D(G)
			cellUID=uint64([]);
			X=[];
			if isempty(G)
				return;
			end
			nt=G.NTATS;
			cellUID=uint64(G.CellUID);
			if isa(nt,'MATLAB.DataTypes.NDTable')
				X=nt.Data;
			else
				X=nt;
			end
			X=double(X);
			if ndims(X)==3
				X=squeeze(X(:,:,1));
			end
		end
		function [X,cellUID]=iFig37ExtractNtats3D(G)
			cellUID=uint64([]);
			X=[];
			if isempty(G)
				return;
			end
			nt=G.NTATS;
			cellUID=uint64(G.CellUID);
			if isa(nt,'MATLAB.DataTypes.NDTable')
				X=nt.Data;
			else
				X=nt;
			end
			X=double(X);
			if ndims(X)~=3
				error('iBuildProb:BadHMShape','Expected hit/miss NTATS to be 3-D.');
			end
		end
		function active=iFig37IsActiveAt1s(X,baseMask,idx1s,kSigma)
			baseMu=mean(X(:,baseMask),2,'omitnan');
			baseSd=std(X(:,baseMask),0,2,'omitnan');
			v1=X(:,idx1s);
			active=isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1>(baseMu+kSigma.*baseSd));
		end
		function [nLearned,prob]=iFig37ConditionalProb(learnedActive,transferActive,layerMask)
			use=layerMask & learnedActive;
			nLearned=nnz(use);
			if nLearned<1
				prob=NaN;
			else
				prob=mean(double(transferActive(use)),'omitnan');
			end
		end
		function layers=iFig37MapLayer(CellMeta,cellUID)
			[tf,loc]=ismember(cellUID,CellMeta.CellUID);
			layers=strings(size(cellUID));
			layers(tf)=CellMeta.ZLayer(loc(tf));
		end
		function tf=iFig37IsLayer23(layers)
			layers=lower(strtrim(layers));
			tf=contains(layers,"2/3") | contains(layers,"23");
		end
		function tf=iFig37IsLayer5(layers)
			layers=lower(strtrim(layers));
			tf=contains(layers,"5");
		end
		function [idx,ok]=iFig37FindTimeIndex(xsSec,targetSec,tolSec)
			[d,idx]=min(abs(xsSec(:)-targetSec));
			ok=isfinite(d) && (d<=tolSec);
		end
	end
end