% 图3.5e：两组细胞的 NTATS@1s 非配对比较（不显示散点，显示P值线）
%
% Group A:
% - Active cells defined in Phase=Final, Stimulus=LightWater
% - Measure NTATS@1s in Phase=Transfer, Stimulus=LightWater (ALL trials)
%
% Group B:
% - Active cells defined in Phase=Learned, Stimulus=LightWater
% - Measure NTATS@1s in Phase=Naive, Stimulus=LightWater
%
% Active-cell criterion (per definition phase):
% - max(0~1s) > mean(-3~0s) + 3*std(-3~0s)
%
% Data sources:
% - Group A: AudioLightBaseline
% - Group B: LightAudioBaseline + LAInterspersed (exclude mice whose LightWater blocks mix AudioWater)
%
% Plot:
% - UniExp.BarScatterCompare(Data, false, CompareGroup)
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig35.E_NTATS1s_BarScatter_FinalActiveTransferLW_vs_LearnedActiveNaiveLW

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2f_NTATS1s_FinalActive_TransferLW_vs_LearnedActive_NaiveLW_BarScatter.svg";

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

% --- 1) Time axis & masks
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

baseMask = (xsSec >= -3) & (xsSec < 0);
respMask = (xsSec >= 0) & (xsSec <= 1);
if nnz(baseMask) < 5 || nnz(respMask) < 2
	error('Fig3_5e:BadActiveMasks', 'Too few samples in baseline/response window.');
end
kSigma = 3;

[~, idx1] = min(abs(xsSec - 1));

% --- 2) Group A: Final-active -> Transfer LW NTATS@1s
ALB = TransferLearning.AudioLightBaseline();

qFinalLW = struct('Phase','Final', 'Stimulus','LightWater');
qTransferLW = struct('Phase','Transfer', 'Stimulus','LightWater');

GA = struct();
GA.FinalLW = ALB.QueryNTATS(qFinalLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GA.TransferLW = ALB.QueryNTATS(qTransferLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

SA = UniExp.NtatsCellStrip(GA);
XA = iGetNtats3D(SA);

XFinal = squeeze(XA(:,:,1));
activeFinal = iActiveMask(XFinal, baseMask, respMask, kSigma);

vFinalToTransfer = XA(activeFinal, idx1, 2);
vFinalToTransfer = double(vFinalToTransfer(:));
vFinalToTransfer = vFinalToTransfer(isfinite(vFinalToTransfer));

% --- 3) Group B: Learned-active -> Naive LW NTATS@1s
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

qNaiveLW = struct('Phase','Naive', 'Stimulus','LightWater');
qLearnLW = struct('Phase','Learned', 'Stimulus','LightWater');

% LAInterspersed purity: exclude mice whose LightWater blocks mix AudioWater
badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
badLearn = iFindMiceWithAudioWaterInPhase(LAI, "Learned");
badMiceLAI = unique([badNaive; badLearn]);

qNaiveLW_LAI = qNaiveLW;
qLearnLW_LAI = qLearnLW;
qNaiveLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badMiceLAI);
qLearnLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Learned", "LightWater", badMiceLAI);

GB = struct();

G1_Naive = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Naive = LAI.QueryNTATS(qNaiveLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GB.NaiveLW = iVcatNtatsTables(G1_Naive, G2_Naive);

G1_Learn = LAB.QueryNTATS(qLearnLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Learn = LAI.QueryNTATS(qLearnLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GB.LearnedLW = iVcatNtatsTables(G1_Learn, G2_Learn);

SB = UniExp.NtatsCellStrip(GB);
XB = iGetNtats3D(SB);

XLearned = squeeze(XB(:,:,2));
activeLearned = iActiveMask(XLearned, baseMask, respMask, kSigma);

vLearnedToNaive = XB(activeLearned, idx1, 1);
vLearnedToNaive = double(vLearnedToNaive(:));
vLearnedToNaive = vLearnedToNaive(isfinite(vLearnedToNaive));

if isempty(vFinalToTransfer) || isempty(vLearnedToNaive)
	error('Fig3_5e:EmptyGroup', 'Empty group after active-cell filtering (A=%d, B=%d).', numel(vFinalToTransfer), numel(vLearnedToNaive));
end

Fig3_5e_NTATS1s = struct();
Fig3_5e_NTATS1s.FinalActive_ToTransferLW = vFinalToTransfer;
Fig3_5e_NTATS1s.LearnedActive_ToNaiveLW = vLearnedToNaive;
Fig3_5e_NTATS1s.Idx1 = idx1;
Fig3_5e_NTATS1s.XsSec = xsSec;
Fig3_5e_NTATS1s.BadMiceLAI = badMiceLAI;
assignin('base','Fig3_5e_NTATS1s', Fig3_5e_NTATS1s);

% --- 4) Plot via UniExp.BarScatterCompare (no scatter; unpaired)
Data = struct();
Data.Final2Transfer = vFinalToTransfer;
Data.Learned2Naive  = vLearnedToNaive;

CompareGroup = table(["Final2Transfer", "Learned2Naive"], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'Fig3.5e NTATS@1s');
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

function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
excludeMice = string(excludeMice(:));
try
	T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
	if isempty(T)
		mice = string.empty(0,1);
		return;
	end
	mice = unique(string(T.Mouse));
	mice = mice(~ismember(mice, excludeMice));
catch
	mice = string.empty(0,1);
end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
try
	T = DS.TableQuery(["Mouse","BlockUID"], Phase=phaseName);
catch
	badMice = strings(0,1);
	return;
end
if isempty(T)
	badMice = strings(0,1);
	return;
end
if ~isprop(DS, 'Trials')
	badMice = strings(0,1);
	return;
end
Tr = DS.Trials;
if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
	badMice = strings(0,1);
	return;
end

TrStim = string(Tr.Stimulus);
TrBU = uint64(Tr.BlockUID);
T.Mouse = string(T.Mouse);
blkBU = uint64(T.BlockUID);

mice = unique(T.Mouse);
bad = false(size(mice));
for i = 1:numel(mice)
	m = mice(i);
	bu = blkBU(T.Mouse == m);
	rows = ismember(TrBU, bu);
	if ~any(rows)
		bad(i) = false;
		continue;
	end
	st = TrStim(rows);
	bad(i) = any(st == "AudioWater") && any(st == "LightWater");
end
badMice = mice(bad);
end

function T = iVcatNtatsTables(A, B)
if isempty(A)
	T = B;
	return;
end
if isempty(B)
	T = A;
	return;
end

try
	T = [A; B];
catch
	% fail safe: keep the one with more rows
	if height(A) >= height(B)
		T = A;
	else
		T = B;
	end
end
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
		error('Fig3_5e:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_5e:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end
