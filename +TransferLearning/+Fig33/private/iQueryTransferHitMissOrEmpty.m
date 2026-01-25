function G = iQueryTransferHitMissOrEmpty(DS)
G = [];
QT = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Stimulus','Behavior'});
try
	G = DS.QueryNTATS(QT, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch ME
	warning(ME.identifier, 'QueryNTATS Transfer Hit/Miss failed: %s', ME.message);
	G = [];
end
end
