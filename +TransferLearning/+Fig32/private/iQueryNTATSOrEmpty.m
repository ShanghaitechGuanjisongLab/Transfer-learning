function G = iQueryNTATSOrEmpty(DS, query)
G = [];
try
	G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch ME
	warning(ME.identifier, 'QueryNTATS failed: %s', ME.message);
	G = [];
end
end
