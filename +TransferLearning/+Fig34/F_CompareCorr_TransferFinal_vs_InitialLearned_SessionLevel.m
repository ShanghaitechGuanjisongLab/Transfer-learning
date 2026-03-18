% 图3.4f：会话单位比较 Corr(session, correct)@1.5s（初始-学会 vs 迁移-最终）
%
% 定义（与 Fig37 一致）：
% - correct：Initial=Learned LightWater；Transfer=Final LightWater
% - session pool：复用 Fig37 builder dbg.Sessions 的 Included 且 pre-100% cutoff
% - corr：对共同细胞的 Pearson 相关（按层 MOp23/MOp5）
%
% Output:
% - SVG + CSV (UNC only)
%
% Execution:
%   TransferLearning.Fig34.F_CompareCorr_TransferFinal_vs_InitialLearned_SessionLevel

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
targetAtSec = 1.5;
subtractAtSec = NaN;
minCommonCells = 5;
excludeCorrectSessionItself = true;

svgName = "Fig3_4f_SessionCorrToCorrect_InitialVsTransfer_1p5s.svg";
csvBySessionName = "Fig3_4f_SessionCorrToCorrect_InitialVsTransfer_1p5s_BySession.csv";
csvStatsName = "Fig3_4f_SessionCorrToCorrect_InitialVsTransfer_1p5s_Stats.csv";

% --- ensure project loaded
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

% Build dbg tables using Fig37 builder (keeps session inclusion rules consistent).
[pairs, dbg] = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
	'TargetAtSec', double(targetAtSec), 'SubtractAtSec', double(subtractAtSec), 'ExcludeZeroHit', false, 'ActualSignalMode', "PrevA"); %#ok<ASGLU>
if isempty(dbg) || ~isfield(dbg,'Sessions') || ~isfield(dbg,'CorrectSession')
	error('Fig3_4f:NoDebug', 'Expected dbg.Sessions and dbg.CorrectSession from builder.');
end

xsSec = seconds(TransferLearning.Xs);
[dtMin, idxT] = min(abs(xsSec - double(targetAtSec)));
if isempty(idxT) || ~isfinite(dtMin) || dtMin > 0.25
	error('Fig3_4f:NoTargetSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(targetAtSec));
end
idxRef = [];
if isfinite(double(subtractAtSec))
	[dtMinRef, idxRef] = min(abs(xsSec - double(subtractAtSec)));
	if isempty(idxRef) || ~isfinite(dtMinRef) || dtMinRef > 0.25
		error('Fig3_4f:NoRefSample', 'Cannot find a sample close to %.3gs in TransferLearning.Xs.', double(subtractAtSec));
	end
end

% Spec matches builder (Initial sources and Transfer source).
spec = [ ...
	struct('Stage',"Initial",  'DataSet',@() TransferLearning.LightAudioBaseline(),  'Source',"LightAudioBaseline"), ...
	struct('Stage',"Initial",  'DataSet',@() TransferLearning.LAInterspersed(),     'Source',"LAInterspersed"), ...
	struct('Stage',"Transfer", 'DataSet',@() TransferLearning.AudioLightBaseline(), 'Source',"AudioLightBaseline") ...
];

BySession = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
	NaT(0,1), NaT(0,1), string.empty(0,1), nan(0,1), nan(0,1), ...
	nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Source','Stage','Mouse','ZKey','DateTimeSession','DateTimeCorrect','Phase','Hit','NTrials', ...
	'SessionOrdinal','NCellsCommon','Corr','FisherZ'});

for iS = 1:numel(spec)
	S = spec(iS);
	try
		DS = S.DataSet();
	catch
		continue;
	end
	if isempty(DS)
		continue;
	end
	if ~isprop(DS, 'Cells')
		continue;
	end
	C = DS.Cells;
	needC = {'Mouse','CellUID','ZLayer'};
	if isempty(C) || ~all(ismember(needC, C.Properties.VariableNames))
		continue;
	end
	try
		C.Mouse = string(C.Mouse);
		C.CellUID = uint64(C.CellUID);
		C.ZLayer = string(C.ZLayer);
	catch
	end

	Sess = dbg.Sessions;
	CorrSess = dbg.CorrectSession;
	maskSourceStage = (Sess.Source == string(S.Source)) & (Sess.Stage == string(S.Stage));
	maskCorrect = (CorrSess.Source == string(S.Source)) & (CorrSess.Stage == string(S.Stage));
	Ssub = Sess(maskSourceStage & Sess.Included == true & Sess.Excluded == false, :);
	Csub = CorrSess(maskCorrect, :);
	if isempty(Ssub) || isempty(Csub)
		continue;
	end

	mice = unique(Csub.Mouse);
	mice = mice(~ismissing(mice));
	for mouseName = mice(:)'
		mouse = string(mouseName);
		rowC = Csub(Csub.Mouse == mouse, :);
		if isempty(rowC)
			continue;
		end
		dtCorrect = rowC.DateTime(1);

		rowS = Ssub(Ssub.Mouse == mouse, :);
		if isempty(rowS)
			continue;
		end
		rowS = sortrows(rowS, {'DateTime'});

		cellAll = unique(uint64(C.CellUID(C.Mouse == mouse)));
		if isempty(cellAll)
			continue;
		end
		Cm = C(C.Mouse == mouse, {'CellUID','ZLayer'});

		[vCorrect, uidCorrect] = iSessionVals(DS, mouse, dtCorrect, cellAll, idxT, idxRef);
		if isempty(vCorrect)
			continue;
		end

		for iSess = 1:height(rowS)
			dtSess = rowS.DateTime(iSess);
			if excludeCorrectSessionItself && ~isnat(dtCorrect) && dtSess == dtCorrect
				continue;
			end
			[vSess, uidSess] = iSessionVals(DS, mouse, dtSess, cellAll, idxT, idxRef);
			if isempty(vSess)
				continue;
			end

			ph = "";
			hit = NaN;
			nTrials = NaN;
			if ismember('Phase', rowS.Properties.VariableNames)
				ph = string(rowS.Phase(iSess));
			end
			if ismember('Hit', rowS.Properties.VariableNames)
				hit = double(rowS.Hit(iSess));
			end
			if ismember('NTrials', rowS.Properties.VariableNames)
				nTrials = double(rowS.NTrials(iSess));
			end

			for zKey = ["MOp23","MOp5"]
				zkA = iCellZKey(Cm, uidSess);
				zkB = iCellZKey(Cm, uidCorrect);
				maskA = (zkA == zKey);
				maskB = (zkB == zKey);
				uidA = uidSess(maskA); valA = vSess(maskA);
				uidB = uidCorrect(maskB); valB = vCorrect(maskB);

				[r, n] = iPearsonOnCommon(uidA, valA, uidB, valB, double(minCommonCells));
				z = atanh(r);
				if ~isfinite(r)
					z = NaN;
				end
				BySession = [BySession; table(string(S.Source), string(S.Stage), mouse, string(zKey), dtSess, dtCorrect, string(ph), double(hit), double(nTrials), ...
					double(iSess), double(n), double(r), double(z), 'VariableNames', BySession.Properties.VariableNames)]; %#ok<AGROW>
			end
		end
	end
end

% Stats: compare Initial vs Transfer within each ZKey.
Stats = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'ZKey','NInitial','NTransfer','P_Ranksum_R','P_TTest_Z','DeltaMeanZ'});
for zKey = ["MOp23","MOp5"]
	A = BySession(BySession.ZKey == zKey & BySession.Stage == "Initial", :);
	B = BySession(BySession.ZKey == zKey & BySession.Stage == "Transfer", :);
	rA = double(A.Corr); rB = double(B.Corr);
	zA = double(A.FisherZ); zB = double(B.FisherZ);
	rA = rA(isfinite(rA)); rB = rB(isfinite(rB));
	zA = zA(isfinite(zA)); zB = zB(isfinite(zB));
	pRS = NaN; pT = NaN; dZ = NaN;
	if numel(rA) >= 3 && numel(rB) >= 3
		try
			pRS = ranksum(rA, rB);
		catch
		end
		try
			[~, pT] = ttest2(zA, zB);
		catch
		end
		dZ = mean(zB, 'omitnan') - mean(zA, 'omitnan');
	end
	Stats = [Stats; table(string(zKey), double(numel(rA)), double(numel(rB)), double(pRS), double(pT), double(dZ), ...
		'VariableNames', Stats.Properties.VariableNames)]; %#ok<AGROW>
end

assignin('base','Fig3_4f_SessionCorrToCorrect_BySession', BySession);
assignin('base','Fig3_4f_SessionCorrToCorrect_Stats', Stats);

% --- Plot
f = figure('Color','w', 'Name', 'Fig3.4f session corr to correct');
try
	MATLAB.Graphics.FigureAspectRatio(1, 1, 2/3);
catch
end

tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');

axs = gobjects(1,2);

zKeys = ["MOp23","MOp5"];
zLabels = ["MOp2/3","MOp5"];
for iZ = 1:numel(zKeys)
	zKey = zKeys(iZ);
	ax = nexttile(tl, iZ);
	axs(iZ) = ax;
	box(ax,'off'); grid(ax,'on'); hold(ax,'on');

	Ai = BySession(BySession.ZKey == zKey & BySession.Stage == "Initial", :);
	At = BySession(BySession.ZKey == zKey & BySession.Stage == "Transfer", :);
	y1 = double(Ai.Corr); y2 = double(At.Corr);
	y1 = y1(isfinite(y1)); y2 = y2(isfinite(y2));

	iJitterScatter(ax, 1, y1, [0.2 0.2 0.2]);
	iJitterScatter(ax, 2, y2, [0.1 0.3 0.8]);

	try
		boxchart(ax, ones(size(y1)), y1, 'BoxFaceColor',[0.8 0.8 0.8], 'MarkerStyle','none', 'BoxWidth',0.4);
		boxchart(ax, 2*ones(size(y2)), y2, 'BoxFaceColor',[0.7 0.8 1.0], 'MarkerStyle','none', 'BoxWidth',0.4);
	catch
		% boxchart may be unavailable on older versions
	end

	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {"Naive→L", "Trans→F"};
	title(ax, zLabels(iZ), 'Interpreter','none');

	% Subtitle removed by request (title already indicates layer). p-value shown via PLine.
	st = Stats(Stats.ZKey == zKey, :);
	if ~isempty(st) && isfinite(st.P_Ranksum_R)
		% p-value line via MATLAB.Graphics.PLine
		try
			yAnchor = [max(y1, [], 'omitnan'), max(y2, [], 'omitnan')];
			S = scatter(ax, [1 2], yAnchor, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
			try
				if isprop(S, 'HitTest'); S.HitTest = 'off'; end
				if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
				if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
			catch
			end
			Descriptors = table(S, 0, 0, ("p=" + sprintf('%.3g', st.P_Ranksum_R)), 0, ...
				'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
			MATLAB.Graphics.PLine(Descriptors);
			try, delete(S); catch, end
		catch
		end
	end
end

% Y label on tiledlayout; unify y limits; hide right-panel Y axis.
ylabel(tl, sprintf('Corr @%.1fs', double(targetAtSec)), 'Interpreter','none');
try
	MATLAB.Graphics.UnifyAxesLims(axs, 'y');
catch
end
try
	for iAx = 1:numel(axs)
		axs(iAx).YGrid = 'off';
		axs(iAx).YMinorGrid = 'off';
	end
catch
end
try
	axs(2).YTickLabel = [];
	axs(2).YLabel.String = '';
	axs(2).YTick = [];
catch
end

sgtitle(tl, 'Corr to learned/final', 'Interpreter','none');

% --- Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

try
	svgPath = fullfile(outDirUNC, svgName);
	TransferLearning.PrintFigure(f, string(svgPath));
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% NOTE: CSV export disabled by request.

%% --- local helpers (copied from Fig37 K scripts for consistency)

function [val, uid] = iSessionVals(DS, mouseName, dt, cellAll, idxT, idxRef)
	val = [];
	uid = uint64([]);
	try
		T = DS.TableQuery("TrialUID", Mouse=string(mouseName), Stimulus="LightWater", DateTime=dt);
	catch
		T = [];
	end
	if isempty(T) || ~ismember('TrialUID', T.Properties.VariableNames)
		return;
	end
	try
		trialUID = unique(uint64(T.TrialUID));
	catch
		trialUID = uint64([]);
	end
	trialUID = trialUID(:);
	if isempty(trialUID)
		return;
	end
	try
		q = struct('CellUID', uint64(cellAll(:)), 'TrialUID', uint64(trialUID(:)));
		G = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	uid = uint64(G.CellUID(:));
	A = G.NTATS;
	try
		if isa(A, 'MATLAB.DataTypes.NDTable')
			A = A.Data;
		end
	catch
	end
	% Fallbacks for other container types.
	if ~isnumeric(A)
		try
			A = A{:,:};
		catch
			try
				A = double(A);
			catch
				A = [];
			end
		end
	end
	if isempty(A)
		return;
	end
	try
		A = squeeze(A);
	catch
	end
	if ndims(A) >= 2
		try
			v = A(:, idxT);
		catch
			return;
		end
	else
		return;
	end
	v = double(v(:));
	if ~isempty(idxRef)
		try
			v = v - double(A(:, idxRef));
		catch
		end
	end
	val = v;
end

function zKey = iCellZKey(Cm, uid)
	zKey = strings(numel(uid), 1);
	try
		[tf, loc] = ismember(uint64(uid(:)), uint64(Cm.CellUID));
		z = strings(numel(uid), 1);
		z(~tf) = "";
		zz = string(Cm.ZLayer(loc(tf)));
		% Normalize common variants
		zz(zz == "MOp2/3") = "MOp23";
		zz(zz == "MOp23") = "MOp23";
		zz(zz == "MOp5") = "MOp5";
		z(tf) = zz;
		zKey = z;
	catch
		zKey(:) = "";
	end
end

function [r, nCommon] = iPearsonOnCommon(uidA, valA, uidB, valB, minCommon)
	r = NaN;
	nCommon = 0;
	uidA = uint64(uidA(:)); valA = double(valA(:));
	uidB = uint64(uidB(:)); valB = double(valB(:));
	[tf, loc] = ismember(uidA, uidB);
	if ~any(tf)
		return;
	end
	x = valA(tf);
	y = valB(loc(tf));
	use = isfinite(x) & isfinite(y);
	nCommon = nnz(use);
	if nCommon < minCommon
		return;
	end
	try
		r = corr(x(use), y(use), 'Type','Pearson');
	catch
		r = NaN;
	end
end

function iJitterScatter(ax, x0, y, color)
	y = double(y(:));
	use = isfinite(y);
	y = y(use);
	if isempty(y)
		return;
	end
	x = x0 + (rand(size(y)) - 0.5) * 0.18;
	scatter(ax, x, y, 18, 'filled', 'MarkerFaceColor', color, 'MarkerFaceAlpha', 0.65);
end

function outPath = iWriteTableWithRetry(T, outDir, fileName)
	maxTry = 10;
	lastME = [];
	outPath = fullfile(outDir, fileName);
	for k = 1:maxTry
		[p, n, e] = fileparts(outPath);
		if strlength(e) == 0
			e = ".csv";
		end
		tmpPath = fullfile(p, n + ".tmp_" + string(feature('getpid')) + "_" + string(datetime('now','Format','yyyyMMdd_HHmmssSSS')) + e);
		try
			writetable(T, tmpPath);
			try
				movefile(tmpPath, outPath, 'f');
			catch ME2
				% Likely target file is open/locked on UNC. Keep temp.
				warning(ME2.identifier, 'Cannot overwrite %s (locked?). Kept temp: %s', outPath, tmpPath);
				outPath = tmpPath;
				return;
			end
			return;
		catch ME
			lastME = ME;
			try
				if exist(tmpPath, 'file')
					delete(tmpPath);
				end
			catch
			end
			pause(0.5 * k);
		end
	end
	throw(lastME);
end
