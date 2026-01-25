% 图3.5g：对图3.5f的两组在 1s 处进行统计比较（BarScatterCompare，显示P值线，不显示散点）
%
% Groups (same definition as Fig3.5f):
% - Cells are first filtered as active in Phase=Learned, Stimulus=AudioWater.
% - Then split by whether they are active in Phase=Transfer, Stimulus=LightWater (ALL trials).
%
% Measure:
% - NTATS@1s in Phase=Learned, Stimulus=AudioWater
%
% Plot:
% - UniExp.BarScatterCompare(Data, false, CompareGroup)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.G_NTATS1s_BarScatter_FromFig35F_LearnedAudio_SplitByTransferLWActive

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_5g_NTATS1s_LearnedAudio_SplitByTransferLWActive_BarScatter.svg";

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

% --- 1) Time axis and masks
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_5g:BadActiveMasks', 'Too few samples in baseline/response window.');
end
kSigma = 3;

[~, idx1] = min(abs(xsSec - 1));

% --- 2) Query 2 lanes (Median ZScore NTATS)
qLearnedAudio = struct('Phase','Learned',  'Stimulus','AudioWater');
qTransferLW   = struct('Phase','Transfer', 'Stimulus','LightWater');

G = struct();
G.LearnedAudio = DS.QueryNTATS(qLearnedAudio, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G.TransferLW   = DS.QueryNTATS(qTransferLW,   UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

S = UniExp.NtatsCellStrip(G);
X = iGetNtats3D(S);
if isempty(X) || size(X,3) < 2
	error('Fig3_5g:BadNTATS', 'Expected NTATS to be [nCell x nTime x 2] for LearnedAudio/TransferLW.');
end

% --- 3) Active masks (same as Fig3.5f)
XLearn = squeeze(X(:,:,1));
XTran  = squeeze(X(:,:,2));

activeLearned = iActiveMask(XLearn, baseMask, respMask, kSigma);
activeTransfer = iActiveMask(XTran, baseMask, respMask, kSigma);

keep = activeLearned;
if nnz(keep) == 0
	error('Fig3_5g:Empty', 'No learned-active cells after filtering.');
end

isActiveInTransfer = activeTransfer(keep);

vAt1s = XLearn(keep, idx1);
vAt1s = double(vAt1s(:));

vActive = vAt1s(isActiveInTransfer);
vInactive = vAt1s(~isActiveInTransfer);
vActive = vActive(isfinite(vActive));
vInactive = vInactive(isfinite(vInactive));

if isempty(vActive) || isempty(vInactive)
	error('Fig3_5g:EmptyGroup', 'Empty group at 1s after filtering (active=%d, inactive=%d).', numel(vActive), numel(vInactive));
end

Fig3_5g = struct();
Fig3_5g.Idx1 = idx1;
Fig3_5g.XsSec = xsSec;
Fig3_5g.ActiveMaskLearned = activeLearned;
Fig3_5g.ActiveMaskTransfer = activeTransfer;
Fig3_5g.ValuesActive = vActive;
Fig3_5g.ValuesInactive = vInactive;
assignin('base','Fig3_5g', Fig3_5g);

% --- 4) Plot via UniExp.BarScatterCompare (no scatter)
Data = struct();
Data.Active = vActive;
Data.Inactive = vInactive;

CompareGroup = table(["Active", "Inactive"], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig3.5g NTATS@1s');
MATLAB.Graphics.FigureAspectRatio(8,5,1/3);
tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

UniExp.BarScatterCompare(Data, false, CompareGroup);
ylabel('NTATS@1s (z-score)');
title('NTATS at 1s');

ax = gca;
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

% --- 5) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers

function activeMask = iActiveMask(XLane, baseMask, respMask, kSigma)
baseMu = mean(XLane(:, baseMask), 2, 'omitnan');
baseSd = std(XLane(:, baseMask), 0, 2, 'omitnan');
respMax = max(XLane(:, respMask), [], 2, 'omitnan');
activeMask = isfinite(respMax) & isfinite(baseMu) & isfinite(baseSd) & (respMax > (baseMu + kSigma*baseSd));
end

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
		error('Fig3_5g:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_5g:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
