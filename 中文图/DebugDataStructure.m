%% Debug data structure for MCC classifier
% Run this first to understand the data format

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);
prjRoot = fullfile(thisDir, '..');
addpath(prjRoot);

if ~exist('UniExp.DataSet','class')
	prjFile = fullfile(prjRoot, 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

fprintf('=== Checking TransferLearning.AudioLightBaseline ===\n');

% Create ALB
try
	ALB = TransferLearning.AudioLightBaseline();
	fprintf('ALB created successfully: %s\n', class(ALB));
catch ME
	fprintf('ERROR creating ALB: %s\n', ME.message);
	rethrow(ME);
end

% Check Xs
fprintf('\n=== Time axis ===\n');
xs = TransferLearning.Xs;
if isduration(xs)
	fprintf('Xs is duration: %s to %s, N=%d\n', ...
        char(xs(1)), char(xs(end)), numel(xs));
	xsSec = seconds(xs);
elseif isnumeric(xs)
	xsSec = xs;
	fprintf('Xs is numeric: %.2f to %.2f, N=%d\n', ...
        xs(1), xs(end), numel(xs));
else
	fprintf('Xs type: %s\n', class(xs));
	xsSec = [];
end

% Query trial behavior data
fprintf('\n=== Behavioral data (TableQuery) ===\n');
try
	T = ALB.TableQuery(["Mouse","DateTime","Stimulus","Phase","Behavior","Performance"], ...
        Stimulus="LightWater", Phase="Transfer");
	fprintf('TableQuery returned %d rows\n', height(T));
	if ~isempty(T)
		disp(T(1:min(5,end), :));
		fprintf('Behavior unique values: ');
		disp(unique(double(T.Behavior)));
	end
catch ME
	fprintf('TableQuery error: %s\n', ME.message);
end

% Query broader to see all available phases
try
	T_all = ALB.TableQuery(["Mouse","Phase","Stimulus"]);
	fprintf('\nAll available data:\n');
	[G_ph, phases] = findgroups(string(T_all.Phase), string(T_all.Stimulus));
	counts = splitapply(@numel, T_all.Mouse, G_ph);
	for i = 1:numel(phases)
		fprintf('  Phase=%s, Stimulus=%s: %d rows\n', ...
            phases{i}(1), phases{i}(2), counts(i));
	end
catch ME
	fprintf('Broad query error: %s\n', ME.message);
end

% Query NTATS (neural data)
fprintf('\n=== Neural data (QueryNTATS) ===\n');
try
	qALB = struct('Phase', 'Transfer', 'Stimulus', 'LightWater');
	G = ALB.QueryNTATS(qALB, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	fprintf('QueryNTATS returned:\n');
	if istable(G)
		fprintf('  Table with %d rows\n', height(G));
		fprintf('  Variables: %s\n', strjoin(string(G.Properties.VariableNames), ', '));
		if ismember('NTATS', string(G.Properties.VariableNames))
			nt = G.NTATS;
			fprintf('  NTATS class: %s\n', class(nt));
			if isa(nt, 'MATLAB.DataTypes.NDTable')
				fprintf('  NDTable size: %s\n', ...
                    strjoin(arrayfun(@num2str, size(nt.Data), 'UniformOutput', false), ' × '));
			elseif isnumeric(nt)
				fprintf('  Numeric size: %s\n', ...
                    strjoin(arrayfun(@num2str, size(nt), 'UniformOutput', false), ' × '));
			elseif iscell(nt)
				fprintf('  Cell array size: %s\n', ...
                    strjoin(arrayfun(@num2str, size(nt), 'UniformOutput', false), ' × '));
				fprintf('  First element class: %s\n', class(nt{1}));
				if isnumeric(nt{1})
					fprintf('  First element size: %s\n', ...
                        strjoin(arrayfun(@num2str, size(nt{1}), 'UniformOutput', false), ' × '));
				end
			end
		end
		if ismember('CellUID', string(G.Properties.VariableNames))
			fprintf('  Unique cells: %d\n', numel(unique(uint64(G.CellUID))));
		end
		if ismember('Mouse', string(G.Properties.VariableNames))
			fprintf('  Mice: %s\n', strjoin(unique(string(G.Mouse)), ', '));
		end
	end
catch ME
	fprintf('QueryNTATS error: %s\n', ME.message);
end

% Check Trials table
fprintf('\n=== Trials table ===\n');
try
	Tr = ALB.Trials;
	fprintf('Trials: %d rows\n', height(Tr));
	fprintf('Variables: %s\n', strjoin(string(Tr.Properties.VariableNames), ', '));
	disp(Tr(1:min(3,end), :));
catch ME
	fprintf('Trials error: %s\n', ME.message);
end

fprintf('\n=== Done ===\n');
