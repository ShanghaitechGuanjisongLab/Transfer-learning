% 英文图1J：比较 Transfer 💡💧 Hit/Miss 在 1s 处的 z-score
%
% Data source:
% - Median z-score; 🔊💧 active cells only (active defined on Learned lane).
%
% Plot:
% - UniExp.BarScatterCompare (Hit vs Miss only)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图1.J_ZScore1s_HitMiss

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig1J_ZScore1s_HitMiss.svg";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

DS = TransferLearning.AudioLightBaseline();

laneOrder = ["NaiveAudio","LearnedAudio","TransferHit","TransferMiss"];

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;

% Find sample index closest to 1s
[~, idx1] = min(abs(xsSec - 1));
if abs(xsSec(idx1) - 1) > 0.25
	error('Fig1J:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end

qNaiveAudio   = struct('Phase','Naive',   'Stimulus','AudioWater');
qLearnedAudio = struct('Phase','Learned', 'Stimulus','AudioWater');
qTHit         = struct('Phase','Transfer','Stimulus','LightWater','Behavior',1);
qTMiss        = struct('Phase','Transfer','Stimulus','LightWater','Behavior',0);

G = struct();
G.NaiveAudio   = DS.QueryNTATS(qNaiveAudio,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = DS.QueryNTATS(qTHit,         UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = DS.QueryNTATS(qTMiss,        UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S, laneOrder);

XLearned = squeeze(X(:,:,2));
baseMu = mean(XLearned(:, baseMask), 2, 'omitnan');
baseSd = std(XLearned(:, baseMask), 0, 2, 'omitnan');
v1s = XLearned(:, idx1);
activeMask = isfinite(v1s) & isfinite(baseMu) & isfinite(baseSd) & (v1s > (baseMu + kSigma*baseSd));

nActiveCells = sum(activeMask);
fprintf('Active cells (🔊💧): %d / %d\n', nActiveCells, numel(activeMask));

X = X(activeMask, :, :);

% --- Extract 1s value
vHit  = X(:, idx1, 3);
vMiss = X(:, idx1, 4);

maskPair = isfinite(vHit) & isfinite(vMiss);
vHit  = vHit(maskPair);
vMiss = vMiss(maskPair);

assignin('base','Fig1J_ZScore1s', struct('TransferHit', vHit, 'TransferMiss', vMiss, ...
	'Idx1', idx1, 'XsSec', xsSec, 'MaskPair', maskPair, 'nActiveCells', nActiveCells));

% --- Plot via UniExp.BarScatterCompare (Hit vs Miss only)
Data = array2table([double(vHit(:)), double(vMiss(:))], ...
	'VariableNames', {'Hit','Miss'});

CompareGroup = table(["Hit","Miss"], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'English Fig1J z-score at 1s (Hit vs Miss)');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.5]; % 30mm x 45mm
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, ~, Bars, ErrorBars] = UniExp.BarScatterCompare(Data, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

% 设置条形和误差条边框粗细
for b = Bars(:)'
	b.LineWidth = 1;
end
for eb = ErrorBars.Object(:)'
	eb.LineWidth = 1;
end
ax.FontName = 'Segoe UI Emoji';
xlabel(ax, '💡💧', 'FontSize', 6, 'FontName', 'Segoe UI Emoji');
ylabel(ax, 'z-score at 1s', 'FontSize', 6);
title(ax, sprintf('🔊💧 active (%d cells)', nActiveCells), 'FontSize', 6, 'FontName', 'Segoe UI Emoji');
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

% --- Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers
function X = iGetNtats3D(S, ~)
if istable(S)
	nt = S.NTATS;
elseif isstruct(S) && isfield(S,'NTATS')
	nt = S.NTATS;
else
	nt = S;
end

if isa(nt, 'MATLAB.DataTypes.NDTable')
	try
		X = nt.Data.Data;
	catch
		X = nt{:,:,:}.Data;
	end
	return;
end

if isnumeric(nt)
	if ndims(nt) ~= 3
		error('Fig1J:BadZScore', 'Expected z-score to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig1J:BadZScore', 'Unsupported z-score container type: %s', class(nt));
end
