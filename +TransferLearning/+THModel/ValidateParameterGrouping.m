function ValidateParameterGrouping(Params)
paramFieldNames = string(fieldnames(Params));
lockedFieldNames = TransferLearning.THModel.LockedParameterNames();
tunableFieldNames = TransferLearning.THModel.TunableParameterNames();
groupedFieldNames = [lockedFieldNames(:); tunableFieldNames(:)];
if numel(unique(groupedFieldNames)) ~= numel(groupedFieldNames)
	error('THModel:DuplicateParameterGrouping', 'A parameter is listed in both locked/tunable groups or repeated within a group.');
end
unclassifiedFieldNames = setdiff(paramFieldNames, groupedFieldNames);
if ~isempty(unclassifiedFieldNames)
	error('THModel:UnclassifiedParameter', 'Params fields must be classified as locked or tunable: %s.', strjoin(unclassifiedFieldNames, ', '));
end
staleFieldNames = setdiff(groupedFieldNames, paramFieldNames);
if ~isempty(staleFieldNames)
	error('THModel:StaleParameterGrouping', 'Parameter grouping lists unknown Params fields: %s.', strjoin(staleFieldNames, ', '));
end
end
