function T = iQueryLightWaterBlocks(DS, IncludeBlockUID)
if nargin < 2
	IncludeBlockUID = false;
end

varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
if IncludeBlockUID
	varsTry = [varsTry, "BlockUID"];
	varsFallback = [varsFallback, "BlockUID"];
end

try
	T = DS.TableQuery(varsTry, Stimulus="LightWater");
catch
	T = DS.TableQuery(varsFallback, Stimulus="LightWater");
end

if isempty(T)
	return;
end

if ~ismember('Stimulus', T.Properties.VariableNames)
	error('TransferLearning:BehaviorSessions:MissingStimulus', 'TableQuery result lacks Stimulus; cannot enforce Stimulus=LightWater.');
end
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "LightWater", :);
if ismember('Behavior', T.Properties.VariableNames) && ~ismember('Performance', T.Properties.VariableNames)
	T.Performance = T.Behavior;
end
end