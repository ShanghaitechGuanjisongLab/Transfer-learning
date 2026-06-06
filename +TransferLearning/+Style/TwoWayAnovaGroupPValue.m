function pValue = TwoWayAnovaGroupPValue(T, responseVarName, xVarName, groupVarName, mouseVarName)
if isempty(T)
	pValue = NaN;
	return;
end
if ~istable(T)
	error('TransferLearning:TwoWayAnovaGroupPValue:BadInput', 'Input must be a table.');
end
responseVarName = string(responseVarName);
xVarName = string(xVarName);
groupVarName = string(groupVarName);
mouseVarName = string(mouseVarName);
needVars = [responseVarName, xVarName, groupVarName, mouseVarName];
if ~all(ismember(needVars, string(T.Properties.VariableNames)))
	error('TransferLearning:TwoWayAnovaGroupPValue:MissingVar', 'Table must contain %s.', strjoin(needVars, ', '));
end
useRows = isfinite(double(T.(responseVarName))) & isfinite(double(T.(xVarName)));
if nnz(useRows) < 4
	pValue = NaN;
	return;
end
Tbl = table(double(T.(responseVarName)(useRows)), double(T.(xVarName)(useRows)), ...
	categorical(string(T.(groupVarName)(useRows))), categorical(string(T.(mouseVarName)(useRows))), ...
	'VariableNames', {'Response', 'XValue', 'Group', 'Mouse'});
lme = fitlme(Tbl, 'Response ~ XValue + Group + (1|Mouse)');
anovaTable = anova(lme);
groupRow = find(string(anovaTable.Term) == "Group", 1, 'first');
if isempty(groupRow)
	pValue = NaN;
else
	pValue = anovaTable.pValue(groupRow);
end
end