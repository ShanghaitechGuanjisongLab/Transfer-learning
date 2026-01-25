function B = iQueryLightWaterBlocks(DS, requirePhaseTransfer)
vars = ["Mouse","DateTime","Performance","Stimulus","Design","Phase"];
B = table();
try
    B = DS.TableQuery(vars, Stimulus="LightWater");
catch
    try
        B = DS.TableQuery(vars, Design="LightWater");
    catch
        B = table();
    end
end

if isempty(B)
    return;
end

if ~ismember('Mouse', B.Properties.VariableNames) || ~ismember('DateTime', B.Properties.VariableNames) || ~ismember('Performance', B.Properties.VariableNames)
    error('Fig3_5b:BehaviorMissingFields', 'Behavior query lacks required fields (Mouse/DateTime/Performance).');
end

if ismember('Stimulus', B.Properties.VariableNames)
    stim = string(B.Stimulus);
    B = B(stim == "LightWater", :);
end

if ismember('Design', B.Properties.VariableNames)
    des = string(B.Design);
    B = B(des == "LightWater", :);
end

% Phase 不在此处筛选；图2会单独选择 Phase==Transfer 的首个会话。
if nargin >= 2
    requirePhaseTransfer = logical(requirePhaseTransfer);
    if requirePhaseTransfer && ~ismember('Phase', B.Properties.VariableNames)
        error('Fig3_5b:MissingPhase', 'Behavior table has no Phase column; cannot run subplot-2 Transfer-only metric.');
    end
end
end
