% Debug: which mice have P(T|F)=0 and show the two sessions used
%
% This script finds mice with Prob23==0 in
%   TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer
% then exports one figure per mouse with two heatmap panels (Transfer LW vs Final LW).
%
% Output:
%   \Data-Server-2\个人数据\张天夫\202601\Fig3_3_debug_PTgivenF0_*.svg
%
% Execution:
%   TransferLearning.Fig33.Debug_PTgivenF0_WhichMice_Heatmaps

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

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

warnIds = [
	"UniExp:Exception:Block_must_warn"
	"UniExp:Exception:Split_trials_less_than_existing_Trials"
	"UniExp:Exception:No_TagPeaks_found"
];
for w = warnIds'
	try, warning('off', w); catch, end %#ok<CTCH>
end

RT = TransferLearning.Fig37.iBuildProb_TransferHitMissGivenFinal_1s_PerMouseLayer();
RT.Mouse = string(RT.Mouse);

% Figure panels use Prob23/Prob5 as P(T|F) for MOp2/3 and MOp5.
% You observed exactly 2 mice at P(T|F)=0 on the plot: that matches Prob23==0.
Z = RT(isfinite(RT.Prob23) & RT.Prob23==0, :);
if isempty(Z)
	error('Debug_PTgivenF0:None', 'No mice with Prob23==0 found.');
end

mice = unique(Z.Mouse);
fprintf('Mice with P(T|F) (Prob23) == 0: %s\n', strjoin(mice, ', '));

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if ~isduration(xs)
	xs = seconds(xs);
end
xsSec = seconds(xs);

xMask = (xsSec >= 0) & (xsSec <= 1.5);
if nnz(xMask) < 5
	error('Debug_PTgivenF0:BadTimeMask', 'Too few samples in 0~1.5s window.');
end

[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Debug_PTgivenF0:No1s', 'Cannot find sample close to 1s in TransferLearning.Xs.');
end

for iM = 1:numel(mice)
	m = mice(iM);
	row = Z(Z.Mouse==m, :);
	dtT = row.DateTimeTransfer(1);
	dtF = row.DateTimeFinal(1);

	metaT = iGetSessionMeta(DS, m, dtT, "Transfer", "LightWater");
	metaF = iGetSessionMeta(DS, m, dtF, "Final", "LightWater");

	fprintf('\nMouse %s\n', m);
	fprintf('  Transfer: %s  Phase=%s  Design=%s\n', string(dtT), metaT.Phase, metaT.Design);
	fprintf('  Final:    %s  Phase=%s  Design=%s\n', string(dtF), metaF.Phase, metaF.Design);

	ST = iQuerySession(DS, m, 'Transfer', 'LightWater', dtT);
	SF = iQuerySession(DS, m, 'Final',    'LightWater', dtF);

	% Align to common cells (this matches the conditional probability's universe)
	cellT = uint64(ST.CellUID);
	cellF = uint64(SF.CellUID);
	common = intersect(cellF, cellT);
	if isempty(common)
		warning('Debug_PTgivenF0:NoCommonCells', 'Mouse %s has no common cells between sessions.', m);
		continue;
	end

	% Use Final session order as reference, sort by Final NTATS@1s descending
	[tfF, idxF] = ismember(common, cellF);
	[tfT, idxT] = ismember(common, cellT);
	idxF = idxF(tfF & tfT);
	idxT = idxT(tfF & tfT);
	common = common(tfF & tfT);

	XF = iNtats2D(SF.NTATS);
	XT = iNtats2D(ST.NTATS);

	vF1 = XF(idxF, idx1s);
	[~, ord] = sort(vF1, 'descend', 'MissingPlacement','last');
	idxF = idxF(ord);
	idxT = idxT(ord);
	common = common(ord);

	XF = XF(idxF, xMask);
	XT = XT(idxT, xMask);

	% CLim: mimic Fig3.3A (non-symmetric sqrt-scale, rounded)
	cl = iSqrtCLimNonSym([XF(:); XT(:)]);

	% Export one figure per mouse (mimic Fig3.3A)
	base = "Fig3_3_debug_PTgivenF0_" + m;
	svgName = base + "_TransferVsFinal_" + iDateTag(dtT) + "_" + iDateTag(dtF) + ".svg";

	lanes = cat(3, XT, XF);
	panelTitles = [
		"Transfer LW  " + iDateTag(dtT) + "  " + metaT.Design
		"Final LW  "    + iDateTag(dtF) + "  " + metaF.Design
	];

	sg = sprintf('%s  P(T|F)=0  (Prob23==0)', m);
	iExportMouseTwoPanelHeatmap(outDirUNC, svgName, lanes, seconds(xsSec(xMask)), cl, sg, panelTitles, common);
end

fprintf('\nDone.\n');

%% --- helpers

function S = iQuerySession(DS, mouse, phase, stimulus, dt)
	q = struct('Mouse',mouse,'Phase',phase,'Stimulus',stimulus,'DateTime',dt);
	S = DS.QueryNTATS(q, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	if ~istable(S) || ~all(ismember({'CellUID','NTATS'}, S.Properties.VariableNames))
		error('Debug_PTgivenF0:BadQuery', 'Unexpected QueryNTATS output for %s %s.', phase, stimulus);
	end
end

function meta = iGetSessionMeta(DS, mouse, dt, phase, stimulus)
	meta = struct('Phase', string(phase), 'Design', "");
	try
		T = DS.TableQuery(["Mouse","DateTime","Phase","Design"], Mouse=mouse, DateTime=dt, Phase=phase, Stimulus=stimulus);
		if ~isempty(T) && any(strcmp(T.Properties.VariableNames,'Design'))
			d = unique(string(T.Design));
			d = d(d ~= "" & d ~= "<missing>");
			if isempty(d)
				meta.Design = "<missing>";
			elseif numel(d) == 1
				meta.Design = d;
			else
				meta.Design = strjoin(d, "|");
			end
		else
			meta.Design = "<unknown>";
		end
	catch
		meta.Design = "<query_failed>";
	end
end

function iExportMouseTwoPanelHeatmap(outDirUNC, svgName, laneData, xs, cl, sgtitleStr, panelTitles, cellUID)
	% laneData: [nCell x nTime x 2]
	if ndims(laneData) ~= 3 || size(laneData,3) ~= 2
		error('Debug_PTgivenF0:BadLaneData', 'Expected laneData to be [nCell x nTime x 2].');
	end

	f = figure('Color','w','Name',sgtitleStr);
	try
		MATLAB.Graphics.FigureAspectRatio(1,1,1/2);
	catch
	end

	Layout = tiledlayout(f, 1, 2, 'TileSpacing','none', 'Padding','tight');
	try
		[~, Axes] = UniExp.LanearHeatmap( ...
			laneData, ...
			SubTitles=string(panelTitles), ...
			Flags=[UniExp.Flags.HideYAxis, UniExp.Flags.SymmetricColormap], ...
			CLim=cl, ...
			Layout=Layout, ...
			ImagescStyle={'XData', seconds([0, 1.5])}, ...
			LMHColor=[0,0,1;1,1,1;1,0,0]);
	catch
		Axes = gobjects(2,1);
		laneDisp = sign(laneData) .* sqrt(abs(laneData));
		for iL = 1:2
			ax = nexttile(Layout, iL);
			Axes(iL) = ax;
			imagesc(ax, xs, 1:size(laneData,1), laneDisp(:,:,iL));
			set(ax,'YDir','normal');
			title(ax, panelTitles(iL), 'Interpreter','none');
			clim(ax, cl);
			colormap(ax, 'parula');
		end
	end

	xlabel(Layout, 'Time (s)');
	ylabel(Layout, sprintf('%d cells', size(laneData,1)));
	try
		sgtitle(Layout, sgtitleStr, 'Interpreter','none');
	catch
	end

	CB = colorbar;
	CB.Layout.Tile = 'east';
	CB.Label.String = 'z-score';

	for iA = 1:numel(Axes)
		A = Axes(iA);
		if ~isgraphics(A)
			continue;
		end
		xline(A, 0, ':k');
		xline(A, 1, '-k');
		A.TickDir = 'in';
		box(A, 'on');
		try
			if isprop(A, 'Toolbar') && ~isempty(A.Toolbar)
				A.Toolbar.Visible = 'off';
			end
		catch
		end
	end

	% keep a mapping for troubleshooting
	assignin('base', matlab.lang.makeValidName(svgName + "_CellUID"), cellUID);

	try
		if ~isfolder(outDirUNC)
			mkdir(outDirUNC);
		end
	catch
	end

	svgPath = fullfile(outDirUNC, svgName);
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
end

function X = iNtats2D(nt)
	% Supports numeric and MATLAB.DataTypes.NDTable.
	if isnumeric(nt)
		X = nt;
		return;
	end
	if isa(nt, 'MATLAB.DataTypes.NDTable')
		X = nt{:,:};
		return;
	end
	error('Debug_PTgivenF0:BadNTATS', 'Unsupported NTATS type: %s', class(nt));
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
	[delta, idx] = min(abs(xsSec - targetSec));
	ok = isfinite(delta) && (delta <= tolSec);
end

function cl = iSymmetricCLim(v)
	v = v(isfinite(v));
	if isempty(v)
		cl = [-1 1];
		return;
	end
	m = max(abs(v));
	if ~isfinite(m) || m<=0
		m = 1;
	end
	cl = [-m m];
end

function CLim = iSqrtCLimNonSym(v)
% Non-symmetric sqrt-scale CLim (rounded), mimicking Fig3.3A.
v = v(isfinite(v));
if isempty(v)
	CLim = [-1, 1];
	return;
end
negV = min(v);
posV = max(v);
if ~isfinite(negV)
	negV = -1;
end
if ~isfinite(posV)
	posV = 1;
end

climLowAbs  = iNiceLimit(sqrt(abs(min(negV, 0))));
climHighAbs = iNiceLimit(sqrt(abs(max(posV, 0))));
if climLowAbs <= 0
	climLowAbs = 1;
end
if climHighAbs <= 0
	climHighAbs = 1;
end
CLim = [-climLowAbs, climHighAbs];
end

function lim = iNiceLimit(x)
% Round x to a "nice" axis limit.
if ~isfinite(x) || x <= 0
	lim = 1;
	return;
end
pow = 10^floor(log10(x));
mant = x / pow;
if mant <= 1
	m = 1;
elseif mant <= 2
	m = 2;
elseif mant <= 5
	m = 5;
else
	m = 10;
end
lim = m * pow;
end

function tag = iDateTag(dt)
	try
		if isdatetime(dt)
			tag = string(dt, 'yyyyMMdd_HHmmss');
			return;
		end
	catch
	end
	tag = "UnknownDT";
end

function iExportHeatmap(outDirUNC, svgName, X, xsSec, cl, titleStr, cellUID)
	f = figure('Color','w','Name',titleStr);
	try
		MATLAB.Graphics.FigureAspectRatio(1,1,1/2);
	catch
	end

	ax = axes(f);
	imagesc(ax, xsSec, 1:size(X,1), X);
	set(ax,'YDir','normal');
	try
		cmap = redblue;
		colormap(ax, cmap);
	catch
		colormap(ax, 'parula');
	end
	clim(ax, cl);
	xline(ax, 0, ':k');
	xline(ax, 1, '-k');
	xlabel(ax,'Time (s)');
	ylabel(ax, sprintf('Cells (n=%d)', size(X,1)));
	title(ax, titleStr, 'Interpreter','none');
	cb = colorbar(ax);
	cb.Label.String = 'z-score';

	% keep a mapping for troubleshooting
	assignin('base', matlab.lang.makeValidName(svgName + "_CellUID"), cellUID);

	try
		if ~isfolder(outDirUNC)
			mkdir(outDirUNC);
		end
	catch
	end

	svgPath = fullfile(outDirUNC, svgName);
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
end
