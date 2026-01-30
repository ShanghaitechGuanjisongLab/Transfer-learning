
% 图3.6e：MultiShadowedLines 叠加比较（筛选：Learned 声水 1s 活跃细胞）
%   展示三条件：声水学会、光水迁移命中、光水迁移错失
%
% 每脚本一张子图，SVG only -> \\Data-Server-2\个人数据\张天夫\202601
%
% 运行：
%   TransferLearning.Fig36.E_SD0p3sVsLearningSpeed_RSPd

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_6e_RSPd_LearnedActive1s_Curves_Learned_vs_TransferHitMiss.svg";

% --- Ensure project loaded (for UniExp)
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

RSP = TransferLearning.RSPd();
xsSec = seconds(TransferLearning.Xs);

kSigma = 3;
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 3
	error('Fig3_6e:BadBaselineMask', 'Baseline window (-3~0s) has too few samples in TransferLearning.Xs.');
end

[dtMin1, idx1] = min(abs(xsSec - 1));
if isempty(idx1) || ~isfinite(dtMin1) || dtMin1 > 0.25
	error('Fig3_6e:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
end

% --- Queries
qLearnedAudio = struct('Phase','Learned','Stimulus','AudioWater','Design','AudioWater');
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});

G = struct();
G.LearnedAudio = RSP.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferHit  = RSP.QueryNTATS(QT_HM(1,:),   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferMiss = RSP.QueryNTATS(QT_HM(2,:),   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);

% --- Filter: only cells active@1s in Learned(AudioWater)
XL = double(squeeze(X(:,:,1)));
baseMu = mean(XL(:, baseMask), 2, 'omitnan');
baseSd = std(XL(:, baseMask), 0, 2, 'omitnan');
val1 = XL(:, idx1);
keep = isfinite(val1) & (val1 > (baseMu + kSigma .* baseSd));

X = X(keep, :, :);
if isempty(X)
	warning('Fig3_6e:NoCells', 'No learned-active@1s cells found; plotting empty placeholder.');
end

% --- Mean ± SEM across cells
meanL = mean(X(:,:,1), 1, 'omitnan');
meanH = mean(X(:,:,2), 1, 'omitnan');
meanM = mean(X(:,:,3), 1, 'omitnan');

semL = std(X(:,:,1), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(X(:,:,1)), 1)));
semH = std(X(:,:,2), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(X(:,:,2)), 1)));
semM = std(X(:,:,3), 0, 1, 'omitnan') ./ sqrt(max(1, sum(isfinite(X(:,:,3)), 1)));

f = figure('Color','w', 'Name', 'Fig3.6e learned-active@1s curves');
	MATLAB.Graphics.FigureAspectRatio(3,2,3/4);
ax = axes(f);

% Avoid exporting axes toolbar icons
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

hold(ax,'on');
box(ax,'off');
grid(ax,'on');

cols = [0.25 0.45 0.85; 0.85 0.35 0.20; 0.55 0.55 0.55];
meanCells = {meanL(:), meanH(:), meanM(:)};
semCells  = {semL(:),  semH(:),  semM(:)};

Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, X=xsSec(:), EdgeColors=cols);

TransferLearning.DrawCueWaterLines(ax);

labels = {'Learned','Tr Hit','Tr Miss'};
try
	lg = legend([Patches(1).Edge, Patches(2).Edge, Patches(3).Edge], labels, 'Location','best', 'Box','off');
	if isgraphics(lg) && isprop(lg, 'Interpreter')
		lg.Interpreter = 'none';
	end
catch
	lg = legend(labels, 'Location','best', 'Box','off');
	if isgraphics(lg) && isprop(lg, 'Interpreter')
		lg.Interpreter = 'none';
	end
end

xlabel(ax, 'Time from cue(:) water(|) (s)', 'Interpreter','none');
ylabel(ax, 'Mean z-score', 'Interpreter','none');
title(ax, sprintf('Learned(AudioWater) active@1s cells (n=%d)', size(X,1)), 'Interpreter','none');

try
	if ~isfolder(outDirUNC); mkdir(outDirUNC); end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% --- local helpers

function X = iGetNtats3D(S)
% Return numeric [nCell x nTime x nLane] NTATS.
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
		error('Fig3_6e:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_6e:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
