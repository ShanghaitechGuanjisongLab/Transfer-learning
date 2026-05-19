% THInhibitoryHeterogeneitySimulation_OriginalMainlineBackup
%
% Branch entry for the pre-NoiseFirst mainline trial sequence.
% NoiseFirst state carryover is now the default mainline path; this script
% explicitly disables it for backup comparisons against the previous trial
% order.

branchTag = "OriginalMainlineBackup";
mainlinePath = fullfile(fileparts(mfilename('fullpath')), 'THInhibitoryHeterogeneitySimulation.m');

[hadBranchFlag, previousBranchFlag] = iReadBaseValue('THNoiseFirstStateCarryoverBranch');
[hadOutputNameSuffix, previousOutputNameSuffix] = iReadBaseValue('THOutputNameSuffix');

assignin('base', 'THNoiseFirstStateCarryoverBranch', false);
assignin('base', 'THOutputNameSuffix', iAppendBranchTag(previousOutputNameSuffix, hadOutputNameSuffix, branchTag));

try
	run(mainlinePath);
catch ME
	iRestoreBaseValue('THNoiseFirstStateCarryoverBranch', hadBranchFlag, previousBranchFlag);
	iRestoreBaseValue('THOutputNameSuffix', hadOutputNameSuffix, previousOutputNameSuffix);
	rethrow(ME);
end

iRestoreBaseValue('THNoiseFirstStateCarryoverBranch', hadBranchFlag, previousBranchFlag);
iRestoreBaseValue('THOutputNameSuffix', hadOutputNameSuffix, previousOutputNameSuffix);

function [hadValue, value] = iReadBaseValue(variableName)
hadValue = evalin('base', sprintf('exist(''%s'', ''var'') == 1', variableName));
if hadValue
	value = evalin('base', variableName);
else
	value = [];
end
end

function suffix = iAppendBranchTag(previousSuffix, hadPreviousSuffix, branchTag)
if hadPreviousSuffix
	suffix = strtrim(string(previousSuffix));
else
	suffix = "";
end
if strlength(suffix) == 0
	suffix = branchTag;
elseif suffix ~= branchTag && ~endsWith(suffix, "_" + branchTag)
	suffix = suffix + "_" + branchTag;
end
end

function iRestoreBaseValue(variableName, hadValue, value)
if hadValue
	assignin('base', variableName, value);
else
	evalin('base', sprintf('clear(''%s'')', variableName));
end
end