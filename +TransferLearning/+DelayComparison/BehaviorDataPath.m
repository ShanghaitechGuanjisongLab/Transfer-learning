function P = BehaviorDataPath(Name)
%BEHAVIORDATAPATH Full path of the behaviour-only transfer-learning datasets.
%   Name is "L2A_L" (light->water naive, undelayed) or "A2L_L" (audio->light
%   transfer, undelayed), as used by Fig1B_LearningCurve_Sigmoid.
arguments
	Name (1,1) string {mustBeMember(Name, ["L2A_L","A2L_L"])}
end
root = "\\Data-Server-2\个人数据\杨青宁\202609\行为学数据";
P = fullfile(root, Name + "_0928.mat");
end
