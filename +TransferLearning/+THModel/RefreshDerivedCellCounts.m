function Params = RefreshDerivedCellCounts(Params)
Params.NCueInput = Params.NL23;
Params.NL5 = Params.NL5RewardRecv + Params.NL5Read;
Params.NL23L5 = Params.NL23 + Params.NL5;
end
