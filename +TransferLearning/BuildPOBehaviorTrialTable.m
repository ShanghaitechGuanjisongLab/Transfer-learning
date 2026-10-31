function TrialTable = BuildPOBehaviorTrialTable()
% Trial-level light-water learning data for PO behavior-only mice.
% Match Fig4C: Design="LightWater", Expression="溢出", Recall excluded.

poMatPath = "\\Data-Server-2\个人数据\张天夫\202610\化学遗传抑制PO.v2.mat";
PO = UniExp.DataSet(poMatPath);
T = PO.TableQuery(["Mouse","DateTime","BlockUID","TrialUID","TrialIndex", ...
	"Stimulus","Behavior","Phase"],Design="LightWater",Expression="溢出");
T.Mouse = string(T.Mouse);
T.Phase = string(T.Phase);
T.Stimulus = string(T.Stimulus);
T.Behavior = double(T.Behavior);
T = T(T.Phase ~= "Recall" & T.Stimulus == "LightWater" & isfinite(T.Behavior),:);
T.Group = repmat("THInhibit",height(T),1);
T.Source = repmat("POBehaviorOnly",height(T),1);
T.Block = zeros(height(T),1);
for mouse = unique(T.Mouse).'
	mask = T.Mouse == mouse;
	[~,~,index] = unique(T.DateTime(mask));
	T.Block(mask) = index;
end
TrialTable = T;
end
