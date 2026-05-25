% newSlopeVsHeterogeneity: Fig3C mice, Fig1B sigmoid slope, Fig3C heterogeneity

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202604';
svgName = 'newSlopeVsHeterogeneity.svg';
scriptCopyName = 'newSlopeVsHeterogeneity.m';
dataCsvName = 'newSlopeVsHeterogeneity_Data.csv';
statsCsvName = 'newSlopeVsHeterogeneity_Stats.csv';
naiveDataCsvName = 'newSlopeVsHeterogeneity_NaiveData.csv';
transferDataCsvName = 'newSlopeVsHeterogeneity_ContinualData.csv';

naiveMouseAllow = ["vtf0030"; "yqn0022"; "yqn0044"; "yqn0404"; "yqn0440"; "yqn1001"; "yqn1002"; "yqn1013"; "yqn2003"; "yqn2005"; "yqn3000"; "yqn3001"; "yqn3002"];
transferMouseAllow = ["vtf0233"; "vtf0352"; "vtf0353"; "vtf0354"; "vtf1233"; "yqn0133"; "yqn0411"; "yqn1018"];

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB = TransferLearning.LightAudioBaseline();
LAPB = TransferLearning.LAPureBehavior();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();
ALPB = TransferLearning.ALPureBehavior();

DS_LAB_F3C = LAB;
DS_LAI_F3C = LAI;
DS_T_F3C = ALB;

CellLAB = iCellLayerTable(DS_LAB_F3C, "LAB");
CellLAI = iCellLayerTable(DS_LAI_F3C, "LAI");
CellALB = iCellLayerTable(DS_T_F3C, "Transfer");

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('newSlopeVsHeterogeneity:No1s', 'Cannot find sample close to 1s in time axis.');
end

naiveAnchors = ["Naive", "Learned"];
transferAnchors = ["Transfer", "Final"];

naiveA = iLightWaterSessionsByMouse(LAB, "LightAudioBaseline", true, naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior", false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));
transferA = iLightWaterSessionsByMouse(ALB, "AudioLightBaseline", true, transferAnchors(1), transferAnchors(2));
transferB = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior", false, transferAnchors(1), transferAnchors(2));

naiveSess = [naiveA; naiveB; naiveC];
transferSess = [transferA; transferB];
naiveSess.Group(:) = "Naive";
transferSess.Group(:) = "Transfer";

iAssertNoCrossSourceDuplicateMice(naiveSess, "Naive");
iAssertNoCrossSourceDuplicateMice(transferSess, "Transfer");

allSessions = [naiveSess; transferSess];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
allSessions = sortrows(allSessions, ["Group", "Mouse", "DateTime"]);
allSessions = iAddSessionIndex(allSessions);

keepNaive = string(allSessions.Group) == "Naive" & ismember(string(allSessions.Mouse), naiveMouseAllow);
keepTransfer = string(allSessions.Group) == "Transfer" & ismember(string(allSessions.Mouse), transferMouseAllow);
allSessions = allSessions(keepNaive | keepTransfer, :);
if isempty(allSessions)
	error('newSlopeVsHeterogeneity:EmptySelectedSessions', 'No selected Fig3C mice remained after applying the allow list.');
end

sigmoidFitTable = iFitSigmoidPerMouse(allSessions);
if isempty(sigmoidFitTable)
	error('newSlopeVsHeterogeneity:NoSigmoidFits', 'No per-mouse sigmoid fit could be computed.');
end

layers = ["MOp2/3"; "MOp5"];
layerLabels = ["L2/3"; "L5"];
palette3 = TransferLearning.FigurePalette(3);
colorN = palette3(1,:);
colorT = palette3(2,:);
colorFit = palette3(3,:);

dataParts = cell(numel(layers), 1);
statsRows = table();

f = figure('Color', 'w', 'Name', 'newSlopeVsHeterogeneity');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperPositionMode = 'auto';
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');
xlabel(tl, 'Response heterogeneity', 'FontSize', 12);
hLegend = gobjects(2, 1);
axAll = gobjects(numel(layers), 1);

for iL = 1:numel(layers)
	layerName = layers(iL);
	layerLabel = layerLabels(iL);
	dataL = iBuildLayerData(layerName, layerLabel, sigmoidFitTable, DS_LAB_F3C, DS_LAI_F3C, DS_T_F3C, CellLAB, CellLAI, CellALB, idx1s, naiveMouseAllow, transferMouseAllow);
	dataParts{iL} = dataL;
	use = isfinite(dataL.Slope) & isfinite(dataL.Heterogeneity);
	if nnz(use) >= 3 && std(dataL.Heterogeneity(use)) > 0 && std(dataL.Slope(use)) > 0
		[rho, p] = corr(dataL.Heterogeneity(use), dataL.Slope(use), 'Type', 'Spearman');
	else
		rho = NaN;
		p = NaN;
	end
	statsRows = [statsRows; table(layerLabel, nnz(use & dataL.Group == "Naive"), nnz(use & dataL.Group == "Transfer"), rho, p, ...
		'VariableNames', {'Layer','NaiveN','TransferN','SpearmanRho','SpearmanP'})]; %#ok<AGROW>

	if ~isfinite(p)
		pLabel = 'p = NaN';
	elseif p < 0.001
		pLabel = 'p < 0.001';
	elseif p < 0.01
		pLabel = sprintf('p = %.3f', p);
	else
		pLabel = sprintf('p = %.2f', p);
	end

	ax = nexttile(tl, iL);
	hold(ax, 'on');
	ax.FontSize = 12;
	ax.LineWidth = 2;
	box(ax, 'off');

	maskN = use & (dataL.Group == "Naive");
	maskT = use & (dataL.Group == "Transfer");
	hN = scatter(ax, dataL.Heterogeneity(maskN), dataL.Slope(maskN), 10, colorN, 'o', 'filled', 'LineWidth', 0.2);
	hT = scatter(ax, dataL.Heterogeneity(maskT), dataL.Slope(maskT), 10, colorT, 's', 'filled', 'LineWidth', 0.2);
	if iL == 1
		hLegend = [hN; hT];
		ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
	else
		ax.YAxis.Visible = 'off';
	end
	if nnz(use) >= 2 && std(dataL.Heterogeneity(use)) > 0
		fitP = polyfit(dataL.Heterogeneity(use), dataL.Slope(use), 1);
		xFitLine = [min(dataL.Heterogeneity(use)), max(dataL.Heterogeneity(use))];
		plot(ax, xFitLine, polyval(fitP, xFitLine), '-', 'Color', colorFit, 'LineWidth', 2);
	end
	title(ax, layerLabel, 'FontSize', 12);
	text(ax, 0.97, 0.97, pLabel, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12);
	axAll(iL) = ax;

	fprintf('\n=== newSlopeVsHeterogeneity %s ===\n', layerLabel);
	fprintf('Naive mice: %d\n', nnz(maskN));
	fprintf('Transfer mice: %d\n', nnz(maskT));
	fprintf('Spearman ρ=%.3f, p=%.4g\n', rho, p);
end

MATLAB.Graphics.UnifyAxesLims(axAll(:), @ylim);
lgd = legend(hLegend, {'Naive', 'Continual'}, 'FontSize', 12, 'Box', 'off', 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

thisFile = mfilename('fullpath');
copyfile([thisFile, '.m'], fullfile(outDirUNC, scriptCopyName));

svgPath = fullfile(outDirUNC, svgName);
allAxes = findall(f, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end
svgTempPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
if ~strcmpi(svgTempPath, svgPath)
	copyfile(svgTempPath, svgPath);
end

dataTable = vertcat(dataParts{:});
writetable(dataTable, fullfile(outDirUNC, dataCsvName));
writetable(statsRows, fullfile(outDirUNC, statsCsvName));
naiveDataTable = dataTable(string(dataTable.Group) == "Naive", :);
transferDataTable = dataTable(string(dataTable.Group) == "Transfer", :);
writetable(naiveDataTable, fullfile(outDirUNC, naiveDataCsvName));
writetable(transferDataTable, fullfile(outDirUNC, transferDataCsvName));

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, dataCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, statsCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, naiveDataCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, transferDataCsvName));

assignin('base', 'newSlopeVsHeterogeneity_Data', dataTable);
assignin('base', 'newSlopeVsHeterogeneity_Stats', statsRows);
assignin('base', 'newSlopeVsHeterogeneity_SigmoidFit', sigmoidFitTable);
assignin('base', 'newSlopeVsHeterogeneity_NaiveData', naiveDataTable);
assignin('base', 'newSlopeVsHeterogeneity_ContinualData', transferDataTable);

function dataL = iBuildLayerData(layerName, layerLabel, sigmoidFitTable, LAB, LAI, ALB, CellLAB, CellLAI, CellALB, idx1s, naiveMouseAllow, transferMouseAllow)
	[sdNaive, miceNaive] = iNaiveHeterogeneityByLayer(LAB, LAI, CellLAB, CellLAI, idx1s, layerName, naiveMouseAllow);
	[sdTransfer, miceTransfer] = iTransferHeterogeneityByLayer(ALB, CellALB, idx1s, layerName, transferMouseAllow);
	dataNaive = iJoinSlopeAndHeterogeneity(sigmoidFitTable, miceNaive, sdNaive, "Naive", layerLabel);
	dataTransfer = iJoinSlopeAndHeterogeneity(sigmoidFitTable, miceTransfer, sdTransfer, "Transfer", layerLabel);
	dataL = [dataNaive; dataTransfer];
	dataL = sortrows(dataL, {'Group','Mouse'});
end

function dataOut = iJoinSlopeAndHeterogeneity(sigmoidFitTable, mice, sdVec, groupName, layerLabel)
	dataOut = table();
	if isempty(mice)
		return;
	end
	fitRows = string(sigmoidFitTable.Group) == string(groupName) & ismember(string(sigmoidFitTable.Mouse), mice);
	fitSub = sigmoidFitTable(fitRows, :);
	[tf, loc] = ismember(string(fitSub.Mouse), mice);
	fitSub = fitSub(tf, :);
	loc = loc(tf);
	dataOut.Layer = repmat(string(layerLabel), height(fitSub), 1);
	dataOut.Group = repmat(string(groupName), height(fitSub), 1);
	dataOut.Mouse = string(fitSub.Mouse);
	dataOut.Heterogeneity = sdVec(loc);
	dataOut.Slope = fitSub.Slope;
	dataOut.Lower = fitSub.Lower;
	dataOut.Upper = fitSub.Upper;
	dataOut.Midpoint = fitSub.Midpoint;
	dataOut.RSquared = fitSub.RSquared;
end

function [sdVec, miceKept] = iNaiveHeterogeneityByLayer(LAB, LAI, CellLAB, CellLAI, idx1s, layerName, mouseAllow)
	Sess = iGatherNaiveSessions_Fig3C(LAB, LAI);
	Sess = iExcludeAudioWaterSessions_Fig3C(Sess, LAB, LAI);
	Sess = iExcludeCeilingSessions_Fig3C(Sess);
	Sess = Sess(ismember(string(Sess.Mouse), mouseAllow), :);
	[SessUsed, miceAll] = iKeepAnalyzedSessions_Fig3C(Sess);
	if isempty(SessUsed)
		sdVec = [];
		miceKept = string.empty(0, 1);
		return;
	end
	rawParts = {};
	srcNames = ["LAB"; "LAI"];
	srcDS = {LAB; LAI};
	srcCellMaps = {CellLAB; CellLAI};
	for i = 1:2
		dts = unique(SessUsed.DateTime(SessUsed.Source == srcNames(i)));
		if isempty(dts)
			continue;
		end
		part = iBatchQueryRawNTS(srcDS{i}, dts);
		if isempty(part)
			continue;
		end
		part.Source = repmat(srcNames(i), height(part), 1);
		part = iAttachLayer(part, srcCellMaps{i});
		rawParts{end+1} = part; %#ok<AGROW>
	end
	if isempty(rawParts)
		sdAll = nan(numel(miceAll), 1);
	else
		medTbl = iPerSessionCellMedianTable(vertcat(rawParts{:}), idx1s, layerName, true);
		sdAll = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll, true);
	end
	keep = isfinite(sdAll);
	sdVec = sdAll(keep);
	miceKept = miceAll(keep);
end

function [sdVec, miceKept] = iTransferHeterogeneityByLayer(ALB, CellALB, idx1s, layerName, mouseAllow)
	Sess = iLightWaterSessions_Fig3C(ALB);
	Sess = iKeepPureLW_NoMustWarn_Fig3C(ALB, Sess);
	Sess = iKeepPhaseRange_Fig3C(ALB, Sess, "Transfer", "Final");
	Sess = iExcludeCeilingSessions_Fig3C(Sess);
	Sess = Sess(ismember(string(Sess.Mouse), mouseAllow), :);
	[SessUsed, miceAll] = iKeepAnalyzedSessions_Fig3C(Sess);
	if isempty(SessUsed)
		sdVec = [];
		miceKept = string.empty(0, 1);
		return;
	end
	rawTbl = iBatchQueryRawNTS(ALB, unique(SessUsed.DateTime));
	if isempty(rawTbl)
		sdAll = nan(numel(miceAll), 1);
	else
		rawTbl = iAttachLayer(rawTbl, CellALB);
		medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName, false);
		sdAll = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll, false);
	end
	keep = isfinite(sdAll);
	sdVec = sdAll(keep);
	miceKept = miceAll(keep);
end

function [SessUsed, mice] = iKeepAnalyzedSessions_Fig3C(Sess)
	if isempty(Sess)
		SessUsed = Sess;
		mice = string.empty(0, 1);
		return;
	end
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	mice = unique(string(Sess.Mouse));
	keepRows = false(height(Sess), 1);
	keepMouse = false(numel(mice), 1);
	for iM = 1:numel(mice)
		m = mice(iM);
		R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
		if height(R) < 2
			continue;
		end
		first100 = find(double(R.Performance) >= 1 - 1e-12, 1, 'first');
		if ~isempty(first100)
			if first100 == 1
				continue;
			end
			R = R(1:first100-1, :);
		end
		if height(R) < 2
			continue;
		end
		yi = double(R.Performance);
		if nnz(isfinite(yi)) < 2
			continue;
		end
		rows = string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime);
		if ismember('Source', Sess.Properties.VariableNames)
			rows = rows & ismember(string(Sess.Source), unique(string(R.Source)));
		end
		keepRows = keepRows | rows;
		keepMouse(iM) = true;
	end
	SessUsed = Sess(keepRows, :);
	mice = mice(keepMouse);
end

function fitTable = iFitSigmoidPerMouse(T)
	T = sortrows(T, {'Group','Mouse','DateTime'});
	mice = unique(string(T.Mouse), 'stable');
	groupPerMouse = strings(numel(mice), 1);
	lowerVec = nan(numel(mice), 1);
	upperVec = nan(numel(mice), 1);
	slopeVec = nan(numel(mice), 1);
	midpointVec = nan(numel(mice), 1);
	rSquaredVec = nan(numel(mice), 1);
	keep = false(numel(mice), 1);
	for iMouse = 1:numel(mice)
		mouseRows = string(T.Mouse) == mice(iMouse);
		mouseTable = T(mouseRows, :);
		mouseTable = sortrows(mouseTable, 'DateTime');
		groupPerMouse(iMouse) = string(mouseTable.Group(1));
		finiteRows = isfinite(double(mouseTable.Session)) & isfinite(double(mouseTable.Performance));
		mouseTable = mouseTable(finiteRows, :);
		if height(mouseTable) < 2
			continue;
		end
		if numel(unique(double(mouseTable.Performance))) < 2
			continue;
		end
		fitMouse = iFitSigmoidCurve(mouseTable, mice(iMouse));
		lowerVec(iMouse) = fitMouse.Lower;
		upperVec(iMouse) = fitMouse.Upper;
		slopeVec(iMouse) = fitMouse.Slope;
		midpointVec(iMouse) = fitMouse.Midpoint;
		rSquaredVec(iMouse) = fitMouse.RSquared;
		keep(iMouse) = true;
	end
	fitTable = table;
	fitTable.Group = groupPerMouse(keep);
	fitTable.Mouse = mice(keep);
	fitTable.Lower = lowerVec(keep);
	fitTable.Upper = upperVec(keep);
	fitTable.Slope = slopeVec(keep);
	fitTable.Midpoint = midpointVec(keep);
	fitTable.RSquared = rSquaredVec(keep);
	fitTable = sortrows(fitTable, {'Group','Mouse'});
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('newSlopeVsHeterogeneity:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
	end
	p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
	obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	p = fminsearch(obj, p0, opt);
	yHat = iSigmoidFromParams(p, xObs);
	SSE = sum((yObs - yHat).^2, 'omitnan');
	SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if SST == 0
		rSquared = NaN;
	else
		rSquared = 1 - SSE / SST;
	end
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	fitOut = struct;
	fitOut.Group = string(groupName);
	fitOut.ParamRaw = p;
	fitOut.Lower = lower;
	fitOut.Upper = upper;
	fitOut.Slope = slope;
	fitOut.Midpoint = midpoint;
	fitOut.SSE = SSE;
	fitOut.RSquared = rSquared;
	fitOut.XObserved = xObs;
	fitOut.YObserved = yObs;
end

function y = iSigmoidFromParams(p, x)
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 1 ./ (1 + exp(-p(1)));
	upper = 1;
	slope = exp(p(2));
	midpoint = exp(p(3));
end

function y = iLogit(x)
	x = min(max(x, 1e-6), 1 - 1e-6);
	y = log(x ./ (1 - x));
end

function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	if string(startPhase) == "Naive" || string(endPhase) == "Naive"
		badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
	else
		badMice = string.empty(0,1);
	end
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isempty(badMice)
		T = T(~ismember(T.Mouse, badMice), :);
	end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function T = iQueryLightWaterBehaviorAll(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end
	if isempty(T)
		return;
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	startPhase = string(startPhase);
	endPhase = string(endPhase);
	if isempty(S)
		return;
	end
	S.Mouse = string(S.Mouse);
	S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse','DateTime'});
	mice = unique(S.Mouse);
	keepRows = false(height(S), 1);
	for i = 1:numel(mice)
		m = mice(i);
		idx = find(S.Mouse == m);
		ph = S.Phase(idx);
		st = find(ph == startPhase, 1, 'first');
		if isempty(st)
			continue;
		end
		ed = find(ph == endPhase & (1:numel(ph))' >= st, 1, 'first');
		if isempty(ed)
			ed = numel(ph);
		end
		keepRows(idx(st:ed)) = true;
	end
	S = S(keepRows, :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	badMice = string.empty(0,1);
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = unique(string(Ta.Mouse));
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames)
		T.Phase = repmat(missing, height(T), 1);
	end
	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase'});
	end
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse','DateTime'});
	if useBehavior
		val = double(T.Behavior);
	else
		val = double(T.Performance);
	end
	[G, mouseList, dtList] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
	S = table(mouseList, dtList, perf, nBlocks, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end

function ph = iPickSessionPhase(phases)
	phases = string(phases);
	phases = phases(~ismissing(phases) & phases ~= "");
	if isempty(phases)
		ph = "";
		return;
	end
	[u, ~, ic] = unique(phases);
	counts = accumarray(ic, 1);
	[~, ix] = max(counts);
	ph = u(ix);
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	[G, mice] = findgroups(T.Mouse);
	nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
	dup = mice(nSrc > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup), 1);
		for i = 1:numel(dup)
			m = dup(i);
			srcs = unique(T.Source(T.Mouse == m));
			msgLines(i) = m + ": " + strjoin(srcs, ",");
		end
		error('newSlopeVsHeterogeneity:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	[G, mice] = findgroups(T.Mouse);
	nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
	dup = mice(nG > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup), 1);
		for i = 1:numel(dup)
			m = dup(i);
			gs = unique(T.Group(T.Mouse == m));
			msgLines(i) = m + ": " + strjoin(gs, ",");
		end
		error('newSlopeVsHeterogeneity:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
	end
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function S = iCellLayerTable(DS, sourceName)
	S = DS.Cells(:, {'Mouse','CellUID','ZLayer'});
	S.Mouse = string(S.Mouse);
	S.CellUID = uint64(S.CellUID);
	S.ZLayer = string(S.ZLayer);
	S.Source = repmat(string(sourceName), height(S), 1);
end

function T = iAttachLayer(T, cellMap)
	cellMap = cellMap(:, {'CellUID','ZLayer'});
	[~, loc] = ismember(T.CellUID, cellMap.CellUID);
	T.ZLayer = strings(height(T), 1);
	has = loc > 0;
	T.ZLayer(has) = cellMap.ZLayer(loc(has));
end

function [idx, ok] = iFindTimeIndex(xsSec, tSec, tolSec)
	[d, idx] = min(abs(xsSec(:) - tSec));
	ok = isfinite(d) && (d <= tolSec);
end

function medTbl = iPerSessionCellMedianTable(rawTbl, idx1s, layerName, hasSource)
	mask = string(rawTbl.ZLayer) == string(layerName);
	rawTbl = rawTbl(mask, :);
	if isempty(rawTbl)
		medTbl = table();
		return;
	end
	sig = double(rawTbl.TrialSignal);
	z1s = sig(:, idx1s);
	if hasSource
		[G, cellU, dtU, srcU] = findgroups(rawTbl.CellUID, rawTbl.DateTime, string(rawTbl.Source));
		med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
		medTbl = table(cellU, dtU, srcU, med1s, 'VariableNames', {'CellUID','DateTime','Source','Med1s'});
	else
		[G, cellU, dtU] = findgroups(rawTbl.CellUID, rawTbl.DateTime);
		med1s = splitapply(@(x) median(x, 'omitnan'), z1s, G);
		medTbl = table(cellU, dtU, med1s, 'VariableNames', {'CellUID','DateTime','Med1s'});
	end
end

function rawTbl = iBatchQueryRawNTS(DS, dts)
	q = struct('Stimulus', 'LightWater', 'DateTime', dts);
	try
		ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24, 'ExtraColumns', "DateTime");
	catch
		rawTbl = table();
		return;
	end
	if isempty(ntsCell) || isempty(ntsCell{1})
		rawTbl = table();
		return;
	end
	rawTbl = ntsCell{1};
	rawTbl.CellUID = uint64(rawTbl.CellUID);
	rawTbl.DateTime = iNormDT(datetime(rawTbl.DateTime));
end

function sdVec = iPerMouseResponseHeterogeneity(SessUsed, medTbl, miceAll, hasSource)
	sdVec = nan(numel(miceAll), 1);
	if isempty(medTbl)
		return;
	end
	for iM = 1:numel(miceAll)
		rowsSess = SessUsed(string(SessUsed.Mouse) == miceAll(iM), :);
		if isempty(rowsSess)
			continue;
		end
		if hasSource
			rowsMed = ismember(medTbl.DateTime, rowsSess.DateTime) & ismember(string(medTbl.Source), string(rowsSess.Source));
		else
			rowsMed = ismember(medTbl.DateTime, rowsSess.DateTime);
		end
		sub = medTbl(rowsMed, :);
		if isempty(sub)
			continue;
		end
		[~, ~, ic] = unique(sub.CellUID);
		meanPerCell = accumarray(ic, sub.Med1s, [], @mean);
		vals = meanPerCell(isfinite(meanPerCell) & meanPerCell >= -1 & meanPerCell <= 1);
		if numel(vals) >= 3
			sdVec(iM) = std(vals);
		end
	end
end

function Sess = iLightWaterSessions_Fig3C(DS)
	blockVars = string(DS.Blocks.Properties.VariableNames);
	if any(blockVars == "MustWarn")
		Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	else
		Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
		Blocks.MustWarn = strings(height(Blocks), 1);
	end
	Blocks.BlockUID = uint64(Blocks.BlockUID);
	Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
	Blocks.MustWarn = string(Blocks.MustWarn);
	DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
	DT.DateTime = iNormDT(datetime(DT.DateTime));
	DT.Mouse = string(DT.Mouse);
	DT.Phase = string(DT.Phase);
	Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
	Tr.BlockUID = uint64(Tr.BlockUID);
	TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
	if isempty(TrLW)
		Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
		return;
	end
	[G, bu] = findgroups(uint64(TrLW.BlockUID));
	lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
	perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
	T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
	keep = ismissing(T.MustWarn) | (T.MustWarn == "");
	T = T(keep, :);
	T = innerjoin(T, DT, 'Keys', 'DateTime');
	[G2, mouseList, dtList] = findgroups(T.Mouse, T.DateTime);
	perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
	phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
	Sess = table(mouseList, dtList, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn_Fig3C(DS, SessIn)
	SessOut = SessIn;
	if isempty(SessOut)
		return;
	end
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.BlockUID = uint64(Blocks.BlockUID);
	Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
	Tr = DS.Trials(:, {'BlockUID','Stimulus'});
	Tr.BlockUID = uint64(Tr.BlockUID);
	TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
	if isempty(TrAW)
		return;
	end
	blkAW = unique(uint64(TrAW.BlockUID));
	TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
	dtAW = unique(TAW.DateTime);
	SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange_Fig3C(DS, SessIn, phaseStart, phaseEnd)
	SessOut = SessIn;
	if isempty(SessOut)
		return;
	end
	DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
	DT.DateTime = iNormDT(datetime(DT.DateTime));
	DT.Mouse = string(DT.Mouse);
	DT.Phase = string(DT.Phase);
	keep = false(height(SessOut), 1);
	for m = unique(string(SessOut.Mouse))'
		dtM = DT(DT.Mouse == m, :);
		phDates = dtM.DateTime(dtM.Phase == phaseStart);
		endDates = dtM.DateTime(dtM.Phase == phaseEnd);
		if isempty(phDates) || isempty(endDates)
			continue;
		end
		startDT = min(phDates);
		endDT = max(endDates);
		rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
		keep = keep | rows;
	end
	SessOut = SessOut(keep, :);
end

function AllSess = iGatherNaiveSessions_Fig3C(LAB, LAI)
	AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
	for iDS = 1:2
		if iDS == 1
			DS = LAB;
			srcName = "LAB";
		else
			DS = LAI;
			srcName = "LAI";
		end
		T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
		T.Mouse = string(T.Mouse);
		T.DateTime = iNormDT(datetime(T.DateTime));
		T.Phase = string(T.Phase);
		Tr = DS.Trials;
		mice = unique(T.Mouse);
		for iM = 1:numel(mice)
			m = mice(iM);
			Tm = T(T.Mouse == m, :);
			phases = unique(Tm.Phase);
			if ~any(phases == "Naive")
				continue;
			end
			hasLearned = any(phases == "Learned");
			hasTransfer = any(phases == "Transfer");
			sessDTs = sort(unique(Tm.DateTime));
			sessPhase = strings(numel(sessDTs), 1);
			for ii = 1:numel(sessDTs)
				ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
				ph = ph(ph ~= "" & ~ismissing(ph));
				if isempty(ph)
					sessPhase(ii) = "";
					continue;
				end
				[u, ~, ic] = unique(ph);
				counts = accumarray(ic, 1);
				[~, mx] = max(counts);
				sessPhase(ii) = u(mx);
			end
			idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
			if hasLearned
				idxEnd = find(sessPhase == "Learned", 1, 'last');
			elseif hasTransfer
				idxEnd = find(sessPhase == "Transfer", 1, 'first') - 1;
			else
				idxEnd = numel(sessDTs);
			end
			if isempty(idxNaiveStart) || idxEnd < idxNaiveStart
				continue;
			end
			for k = idxNaiveStart:idxEnd
				dt = sessDTs(k);
				blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
				TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
				if isempty(TrSess)
					continue;
				end
				lwMask = string(TrSess.Stimulus) == "LightWater";
				if ~any(lwMask)
					continue;
				end
				perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
				if ~isfinite(perf)
					continue;
				end
				AllSess = [AllSess; table(m, dt, perf, srcName, 'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
			end
		end
	end
	AllSess = sortrows(AllSess, {'Mouse','DateTime'});
	[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows');
	AllSess = AllSess(ia, :);
end

function AllSess = iExcludeAudioWaterSessions_Fig3C(AllSess, LAB, LAI)
	keep = true(height(AllSess), 1);
	for i = 1:height(AllSess)
		if AllSess.Source(i) == "LAB"
			DS = LAB;
		else
			DS = LAI;
		end
		if iHasStimulus_Fig3C(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
			keep(i) = false;
		end
	end
	AllSess = AllSess(keep, :);
end

function SessOut = iExcludeCeilingSessions_Fig3C(SessIn)
	SessOut = sortrows(SessIn, {'Mouse','DateTime'});
	remove = false(height(SessOut), 1);
	for m = unique(SessOut.Mouse)'
		rows = find(SessOut.Mouse == m);
		p = double(SessOut.Performance(rows));
		i100 = find(p >= 1 - 1e-12, 1, 'first');
		if ~isempty(i100)
			remove(rows(i100:end)) = true;
		end
	end
	SessOut(remove, :) = [];
	perf = double(SessOut.Performance);
	SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function tf = iHasStimulus_Fig3C(DS, mouseName, dt, stim)
	tf = false;
	Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
	if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames)
		return;
	end
	st = unique(string(Tdt.Stimulus));
	st = st(~ismissing(st));
	tf = any(st == string(stim));
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function dt = iNormDT(dt)
	try
		if isdatetime(dt) && ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
	catch
	end
end