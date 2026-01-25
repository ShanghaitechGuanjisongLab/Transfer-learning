function rows = iBuildCellCorr1s1p5_VsPerformance_Sessions()
% Build session table for Fig3.2f: CellCorr(1s,1.5s) vs Performance.
%
% This is a non-Scratch replacement for the legacy Scratch implementation.
%
% Returns table with variables:
%   Mouse, DateTime, Group, Source, ZLayer, NCells, CellCorr_1s1p5s, Performance
%
% Execution:
%   TransferLearning.Fig33.iBuildCellCorr1s1p5_VsPerformance_Sessions

rows = TransferLearning.Fig33.iBuildNVST_CellCorr_Sessions_1s_1p5s_ByLayer();
if isempty(rows)
	return;
end

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

rows.Performance = nan(height(rows), 1);

for i = 1:height(rows)
	src = string(rows.Source(i));
	mouse = string(rows.Mouse(i));
	dt = rows.DateTime(i);
	perf = NaN;
	if src == "LightAudioBaseline"
		perf = iSessionPerformance(LAB, mouse, dt);
	elseif src == "LAInterspersed"
		perf = iSessionPerformance(LAI, mouse, dt);
	elseif src == "AudioLightBaseline"
		perf = iSessionPerformance(ALB, mouse, dt);
	end
	rows.Performance(i) = perf;
end

rows.Performance = double(rows.Performance);

end

%% --- local helpers

function perf = iSessionPerformance(DS, mouse, dt)
	perf = NaN;
	try
		T = DS.TableQuery(["Mouse","DateTime","Performance"], Mouse=mouse, DateTime=dt, Stimulus="LightWater");
	catch
		T = [];
	end
	if isempty(T) || ~ismember('Performance', T.Properties.VariableNames)
		return;
	end
	p = double(T.Performance);
	perf = mean(p(isfinite(p)), 'omitnan');
end
