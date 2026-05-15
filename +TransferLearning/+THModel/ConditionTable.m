function Cond = ConditionTable()
Cond = table;
Cond.Name = ["Naive"; "Transfer"; "THOff"];
Cond.Label = ["Naive"; "Transfer"; "TH inhibited"];
Cond.Color = [1, 0, 0; 0, 0, 1; 0, 0, 0];
Cond.RewardInputLevel = [1.00; 1.00; 0.00];
end
