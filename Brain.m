classdef Brain<handle
	properties(Constant)
		%% 输出节点

		Behavior=1
		Reward=2

		NumOutputs=2

		%% 输入节点

		RewardSmell=1
		BehaviorFeedback=2
		RewardTaste=3
		CueA=4
		CueB=5

		NumBinaryInputs=5
		
		%% 格雷码计数器，模拟时间漂变

		TrialCells=6
		BlockCells=5

		%% 细胞计数：每个细胞搭配4个兴奋性和1个抑制性细胞，但抑制性突触强度是兴奋性的4倍

		ActivationRatio=4
		InhibitionRatio=1
		CortexOutputSize=Brain.OutputSize*Brain.IOScale
		NumInputs=Brain.NumBinaryInputs+Brain.TrialCells+Brain.BlockCells
		NumInhibitors=Brain.NumInputs+Brain.OutputSize
		NumActivators=Brain.NumInhibitors*Brain.ActivationRatio
		NumCortexCells=Brain.NumInhibitors+Brain.NumActivators
		NumIOCells=

		%% 细胞位置

		OutputActivationBits=1:Brain.CortexOutputSize
	end
	properties
		InputVector=false(Brain.NumInputs,1)
		OutputActivationMatrix=normrnd(0,Brain.InhibitionRatio,Brain.OutputSize,Brain.ActivationRatio,Brain.OutputSize)
		OutputInhibitionMatrix=normrnd(0,Brain.ActivationRatio,Brain.OutputSize,Brain.InhibitionRatio,Brain.OutputSize)
		CortexVector=zeros(Brain.NumCortexCells,1)
		CortexActivationMatrix=normrnd(0,Brain.InhibitionRatio,Brain.NumCortexCells,Brain.ActivationRatio)
	end
	methods
		function NextTrial(obj)
			persistent TrialBits
			if isempty(TrialBits)
				TrialBits=Brain.NumBinaryInputs+1:Brain.NumBinaryInputs+Brain.TrialCells;
			end
			obj.InputVector(TrialBits)=GrayPlus1(obj.InputVector(TrialBits));
		end
		function NextBlock(obj)
			persistent BlockBits
			if isempty(BlockBits)
				NonblockInputs=Brain.NumBinaryInputs+Brain.TrialCells;
				BlockBits=NonblockInputs+1:NonblockInputs+Brain.BlockCells;
			end
			obj.InputVector(BlockBits)=GrayPlus1(obj.InputVector(BlockBits));
		end
		function Iterate(obj)
			persistent OutputActivatorBits OutputInhibitorBits
			if isempty(OutputActivatorBits)
				CortexOutputActivatorSize=Brain.OutputSize*Brain.ActivationRatio;
				OutputActivatorBits=1:CortexOutputActivatorSize;
				OutputInhibitorBits=CortexOutputActivatorSize+1:CortexOutputActivatorSize+Brain.OutputSize*Brain.InhibitionRatio;
			end
			NewOutput=(atan(obj.OutputActivationMatrix(:,:))/pi+0.5)*Brain.InhibitionRatio*obj.CortexVector(OutputActivatorBits)-(atan(obj.OutputInhibitionMatrix(:,:))/pi+0.5)*Brain.ActivationRatio*obj.CortexVector(OutputInhibitorBits);
			obj.CortexVector=(atan(obj.CortexActivationMatrix(:,:))/pi+0.5)*Brain.InhibitionRatio*obj.CortexVector(CortexActivatorBits)-(atan(obj.CortexInhibitionMatrix(:,:))/pi+0.5)*Brain.ActivationRatio*obj.CortexVector(CortexInhibitorBits);
		end
	end
end
function Gray=GrayPlus1(Gray)
if bitand(nnz(Gray),1)
	Bit=find(Gray,1)+1;
	Gray(Bit)=~Gray(Bit);
else
	Gray(1)=~Gray(1);
end
end