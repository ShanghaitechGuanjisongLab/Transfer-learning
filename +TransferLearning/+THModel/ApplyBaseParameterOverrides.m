function Params = ApplyBaseParameterOverrides(Params)
if evalin('base', 'exist(''THParamOverrides'', ''var'')') ~= 1
	return;
end
paramOverrides = evalin('base', 'THParamOverrides');
if isempty(paramOverrides)
	return;
end
if ~isstruct(paramOverrides)
	error('THModel:InvalidParameterOverrides', 'THParamOverrides must be a scalar struct.');
end
tunableFieldNames = TransferLearning.THModel.TunableParameterNames();
fieldNames = fieldnames(paramOverrides);
for iField = 1:numel(fieldNames)
	fieldName = fieldNames{iField};
	if ~isfield(Params, fieldName)
		error('THModel:UnknownParameterOverride', 'Unknown THParamOverrides field: %s.', fieldName);
	end
	if ~any(string(fieldName) == tunableFieldNames)
		error('THModel:LockedParameterOverride', 'THParamOverrides may not override locked parameter: %s.', fieldName);
	end
	fieldValue = paramOverrides.(fieldName);
	if ~isnumeric(fieldValue) || ~isscalar(fieldValue) || ~isfinite(fieldValue)
		error('THModel:InvalidParameterOverrideValue', 'THParamOverrides.%s must be a finite numeric scalar.', fieldName);
	end
	Params.(fieldName) = fieldValue;
end
Params = TransferLearning.THModel.RefreshDerivedCellCounts(Params);
if Params.HitThreshold >= Params.ResponseScale
	error('THModel:InvalidDecisionThreshold', 'HitThreshold must be below ResponseScale.');
end
TransferLearning.THModel.ValidateParameterGrouping(Params);
end
