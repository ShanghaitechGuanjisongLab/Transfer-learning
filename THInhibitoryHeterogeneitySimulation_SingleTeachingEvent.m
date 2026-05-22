% THInhibitoryHeterogeneitySimulation_SingleTeachingEvent
%
% Branch entry for one teaching event per trial: hit trials receive teaching
% at the hit state, miss trials after the full decision window.

branchTag = "SingleTeachingEvent";
mainlinePath = fullfile(fileparts(mfilename('fullpath')), 'THInhibitoryHeterogeneitySimulation.m');
overridePath = fullfile(fileparts(mfilename('fullpath')), 'BranchOverrides', 'SingleTeachingEvent');

[hadNoiseFirstFlag, previousNoiseFirstFlag] = iReadBaseValue('THNoiseFirstStateCarryoverBranch');
[hadOutputNameSuffix, previousOutputNameSuffix] = iReadBaseValue('THOutputNameSuffix');

assignin('base', 'THNoiseFirstStateCarryoverBranch', true);
assignin('base', 'THOutputNameSuffix', iAppendBranchTag(previousOutputNameSuffix, hadOutputNameSuffix, branchTag));
addpath(overridePath, '-begin');

cleanupBaseValues = onCleanup(@() iRestoreBranchState(overridePath, hadNoiseFirstFlag, previousNoiseFirstFlag, hadOutputNameSuffix, previousOutputNameSuffix));
run(mainlinePath);
clear cleanupBaseValues;

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

function iRestoreBranchState(overridePath, hadNoiseFirstFlag, previousNoiseFirstFlag, hadOutputNameSuffix, previousOutputNameSuffix)
rmpath(overridePath);
iRestoreBaseValue('THNoiseFirstStateCarryoverBranch', hadNoiseFirstFlag, previousNoiseFirstFlag);
iRestoreBaseValue('THOutputNameSuffix', hadOutputNameSuffix, previousOutputNameSuffix);
end
