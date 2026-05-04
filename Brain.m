classdef Brain
	properties(Constant)
		%% 输出节点

		BehaviorActivator=1
		BehaviorInhibitor=2
		RewardActivator=3
		RewardInhibitor=4

		%% 输入节点

		RewardSmell=5
		BehaviorFeedback=6
		RewardTaste=7
		CueA=8
		CueB=9
		
		%% 计数器

		CalmdownBits=5
		TrialBits=5
		BlockBits=5
	end
	methods
		function Iterate(obj)
		end
	end
end