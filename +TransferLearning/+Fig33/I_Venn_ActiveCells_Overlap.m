% Fig3.3I：活跃细胞集合的 Venn（两个子图）
%
% Left:  Initial LightWater vs Learned LightWater
% Right: Learned AudioWater vs Transfer LightWater vs Final LightWater
%
% Active@1s definition:
%   NTATS(1s) > mean(-3~0s) + 3*std(-3~0s)
% computed on per-cell median trial trace from QueryNTATS (ZScore baseline indices 1:24).
%
% Notes:
% - Initial/Learned LightWater use the same merged sources as Fig3.7C (LAB + LAI with purity exclusion on LAI).
% - Transfer LightWater enforces your assertion: per-mouse only ONE session and NO AudioWater trials in that DateTime.
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.I_Venn_ActiveCells_Overlap

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3i_Venn_ActiveCells_Overlap.svg";

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

xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if nnz(baseMask) < 5
	error('Fig3_3i:BadBaselineMask', 'Too few samples in -3~0s baseline window.');
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig3_3i:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end
kSigma = 3;

% --- 1) Initial/Learned LightWater (merge sources like Fig3.7C)
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();

qNaiveLW = struct('Phase','Naive',  'Stimulus','LightWater');
qLearnLW = struct('Phase','Learned','Stimulus','LightWater');

badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
badLearn = iFindMiceWithAudioWaterInPhase(LAI, "Learned");
badMiceLAI = unique([badNaive; badLearn]);

qNaiveLW_LAI = qNaiveLW;
qLearnLW_LAI = qLearnLW;
qNaiveLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badMiceLAI);
qLearnLW_LAI.Mouse = iMiceInPhaseStimulus(LAI, "Learned", "LightWater", badMiceLAI);

G1_Naive = LAB.QueryNTATS(qNaiveLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Naive = LAI.QueryNTATS(qNaiveLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GNaiveLW = iVcatNtatsTables(G1_Naive, G2_Naive);

G1_Learn = LAB.QueryNTATS(qLearnLW, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
G2_Learn = LAI.QueryNTATS(qLearnLW_LAI, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GLearnedLW = iVcatNtatsTables(G1_Learn, G2_Learn);

G_LW = struct();
G_LW.NaiveLight = GNaiveLW;
G_LW.LearnedLight = GLearnedLW;
S_LW = UniExp.NtatsCellStrip(G_LW);
X_LW = iGetNtats3D(S_LW);
cellUID_LW = uint64(S_LW.CellUID);

actInit = iActiveMask(squeeze(X_LW(:,:,1)), idx1s, baseMask, kSigma);
actLearn = iActiveMask(squeeze(X_LW(:,:,2)), idx1s, baseMask, kSigma);
setInitLW = unique(cellUID_LW(actInit));
setLearnLW = unique(cellUID_LW(actLearn));

% --- 2) Learned/Transfer/Final for transfer experiment
ALB = TransferLearning.AudioLightBaseline();
iAssertTransferLightWaterSingleSessionPure(ALB);

GLearnedAudio = ALB.QueryNTATS(struct('Phase','Learned','Stimulus','AudioWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GTransferLW = ALB.QueryNTATS(struct('Phase','Transfer','Stimulus','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
GFinalLW = ALB.QueryNTATS(struct('Phase','Final','Stimulus','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

G_TF = struct();
G_TF.LearnedAudio = GLearnedAudio;
G_TF.TransferLight = GTransferLW;
G_TF.FinalLight = GFinalLW;
S_TF = UniExp.NtatsCellStrip(G_TF);
X_TF = iGetNtats3D(S_TF);
cellUID_TF = uint64(S_TF.CellUID);

actLearnAW = iActiveMask(squeeze(X_TF(:,:,1)), idx1s, baseMask, kSigma);
actTranLW = iActiveMask(squeeze(X_TF(:,:,2)), idx1s, baseMask, kSigma);
actFinalLW = iActiveMask(squeeze(X_TF(:,:,3)), idx1s, baseMask, kSigma);

setLearnAW = unique(cellUID_TF(actLearnAW));
setTranLW = unique(cellUID_TF(actTranLW));
setFinalLW = unique(cellUID_TF(actFinalLW));

assignin('base','Fig3_3i_BadMiceLAI', badMiceLAI);
assignin('base','Fig3_3i_Set_InitLW', setInitLW);
assignin('base','Fig3_3i_Set_LearnedLW', setLearnLW);
assignin('base','Fig3_3i_Set_LearnedAW', setLearnAW);
assignin('base','Fig3_3i_Set_TransferLW', setTranLW);
assignin('base','Fig3_3i_Set_FinalLW', setFinalLW);

% --- 3) Build Venn counts (use union as the universe; outside-all = 0)
% Left: 2-set
nA = numel(setdiff(setInitLW, setLearnLW));
nB = numel(setdiff(setLearnLW, setInitLW));
nAB = numel(intersect(setInitLW, setLearnLW));
M2 = [0, nB; nA, nAB];
den2 = numel(unique(cellUID_LW));
if den2 <= 0
	den2 = 1;
end
lab2 = compose('%.1f%%', 100*M2/den2);

% Right: 3-set (circle1=L-Audio, circle2=T-Light, circle3=F-Light)
L = setLearnAW;
T = setTranLW;
F = setFinalLW;

n000 = 0;
n100 = numel(setdiff(L, union(T, F)));
n010 = numel(setdiff(T, union(L, F)));
n001 = numel(setdiff(F, union(L, T)));
n110 = numel(setdiff(intersect(L, T), F));
n101 = numel(setdiff(intersect(L, F), T));
n011 = numel(setdiff(intersect(T, F), L));
n111 = numel(intersect(intersect(L, T), F));

T3 = zeros(2,2,2);
T3(1,1,1) = n000;
T3(2,1,1) = n100;
T3(1,2,1) = n010;
T3(1,1,2) = n001;
T3(2,2,1) = n110;
T3(2,1,2) = n101;
T3(1,2,2) = n011;
T3(2,2,2) = n111;

den3 = numel(unique(cellUID_TF));
if den3 <= 0
	den3 = 1;
end
lab3 = compose('%.1f%%', 100*T3/den3);

% --- 4) Plot
f = figure('Color','w', 'Name', 'Fig3.3I Venn');
try
	MATLAB.Graphics.FigureAspectRatio(98, 48, 1);
catch
end

Lyt = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','tight');

ax1 = nexttile(Lyt, 1);
axis(ax1, 'off');
title(ax1, 'Initial LW vs Learned LW');
hold(ax1, 'on');

cs2 = table([0.3,0.6,1.0; 1.0,0.6,0.2], [0.35;0.35], 'VariableNames', ["FaceColor","FaceAlpha"]);
tagStyle = struct('Color',[0 0 0], 'FontSize', 10);
[cir2, ~] = MATLAB.Graphics.Venn(M2, cs2, string(lab2), tagStyle);
legend(cir2, ["Init LW","Learned LW"], 'Location','best');

ax2 = nexttile(Lyt, 2);
axis(ax2, 'off');
title(ax2, 'Learned AW vs Transfer LW vs Final LW');
hold(ax2, 'on');

cs3 = table([0.2,0.7,0.9; 0.9,0.4,0.4; 0.4,0.8,0.4], [0.30;0.30;0.30], 'VariableNames', ["FaceColor","FaceAlpha"]);
cir3 = MATLAB.Graphics.Venn(T3, cs3, string(lab3), tagStyle);
legend(cir3, ["Learned AW","Transfer LW","Final LW"], 'Location','best');

% --- 5) Export
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

function mask = iActiveMask(X2, idx1s, baseMask, kSigma)
% X2: [nCell x nTime]
if ~ismatrix(X2)
	error('Fig3_3i:BadNTATS', 'Expected NTATS lane to be [nCell x nTime].');
end
baseMu = mean(X2(:, baseMask), 2, 'omitnan');
baseSd = std(X2(:, baseMask), 0, 2, 'omitnan');
v1 = X2(:, idx1s);
mask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma*baseSd));
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
		error('Fig3_3i:BadNTATS', 'Expected NTATS to be 3D numeric or NDTable.');
	end
	X = nt;
	return;
end

error('Fig3_3i:BadNTATS', 'Unsupported NTATS container type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
[d, idx] = min(abs(xsSec - tSec));
ok = isfinite(d) && (d <= tolSec);
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
if isempty(T) || ~isprop(DS, 'Trials')
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
	if any(TrStim(rows) == "AudioWater")
		bad(i) = true;
	end
end
badMice = mice(bad);
end

function G = iVcatNtatsTables(G1, G2)
if isempty(G1)
	G = G2;
	return;
end
if isempty(G2)
	G = G1;
	return;
end
G = [G1; G2];
end

function iAssertTransferLightWaterSingleSessionPure(DS)
T = DS.TableQuery(["Mouse","DateTime"], Phase="Transfer", Stimulus="LightWater");
if isempty(T)
	error('Fig3_3i:NoTransferLW', 'No Transfer LightWater trials found.');
end

T.Mouse = string(T.Mouse);
try
	T.DateTime = datetime(T.DateTime);
catch
end

mice = unique(T.Mouse);
badMulti = strings(0,1);
badEmpty = strings(0,1);
badMix = strings(0,1);

for i = 1:numel(mice)
	m = mice(i);
	dt = unique(T.DateTime(T.Mouse==m));
	dt = dt(~isnat(dt));
	if isempty(dt)
		badEmpty(end+1) = m; %#ok<AGROW>
		continue;
	end
	if numel(dt) ~= 1
		badMulti(end+1) = m; %#ok<AGROW>
		continue;
	end
	try
		Ts = DS.TableQuery("Stimulus", Mouse=m, DateTime=dt);
		st = string(Ts.Stimulus);
		if any(st == "AudioWater")
			badMix(end+1) = m; %#ok<AGROW>
		end
	catch
		badMix(end+1) = m; %#ok<AGROW>
	end
end

if ~isempty(badEmpty)
	error('Fig3_3i:TransferLWBadDateTime', 'Some mice have Transfer LW trials but missing DateTime: %s', strjoin(badEmpty, ', '));
end
if ~isempty(badMulti)
	error('Fig3_3i:TransferLWMulitpleSessions', 'Transfer LightWater is not a single session for mice: %s', strjoin(badMulti, ', '));
end
if ~isempty(badMix)
	error('Fig3_3i:TransferLWMixedStim', 'Transfer LightWater session contains AudioWater trials for mice: %s', strjoin(unique(badMix), ', '));
end
end
