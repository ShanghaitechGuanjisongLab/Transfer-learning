% 英文图3E：Inter-cell SD@1s (session k+1) vs ΔHit，分 MOp2/3 和 MOp5 两个 tile
%
% Data scope (same session pairs as Fig3B):
% - All pure-LightWater sessions in AudioLightBaseline (Transfer → Final).
% - Exclude sessions with hit rate ≥ 100% and all subsequent sessions.
% - One point = one adjacent session pair (session k → session k+1).
% - ΔHit = Hit(k+1) − Hit(k).
% - x = inter-cell SD of median ZScore at 1s in session k+1, per layer.
%
% Layout: tiledlayout(1,2) — left MOp2/3, right MOp5.
% Style: scatter + fit line + Spearman (ref Fig3B).
%
% Execution:
%   TransferLearning.英文图3.E_SD1sVsDeltaHit_ByLayer

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig3E_SD1sVsDeltaHit_ByLayer.svg";

% --- Preconditions
DS = TransferLearning.AudioLightBaseline();

% --- Time axis
xs = TransferLearning.Xs;
if isduration(xs), xsSec = seconds(xs); else, xsSec = double(xs); end

[dtMin, idx1s] = min(abs(xsSec - 1));
if isempty(idx1s) || ~isfinite(dtMin) || dtMin > 0.25
	error('EnglishFig3E:No1s', 'Cannot find a sample close to 1s.');
end

% --- Session table: pure LightWater, ceiling excluded, adjacent pairs
Sess = iLightWaterSessions(DS);
Sess = iKeepPureLightWater(DS, Sess);
Sess = iExcludeCeiling(Sess);
SessSpeed = iSessionDeltaNextTable(Sess);

% --- Per-session SD@1s by layer (computed for session k+1)
NextKeys = SessSpeed(:, {'Mouse','DateTimeNext'});
NextKeys.Properties.VariableNames{'DateTimeNext'} = 'DateTime';
SDSess = iSessionSD1s_ByLayer(DS, NextKeys, idx1s);

% Join: SDSess.DateTime matches SessSpeed.DateTimeNext
SDSess.Properties.VariableNames{'DateTime'} = 'DateTimeNext';
J = innerjoin(SDSess, SessSpeed(:, {'Mouse','DateTimeNext','DateTime','Performance','PerformanceNext','Speed_DeltaNext'}), ...
	'Keys', {'Mouse','DateTimeNext'});
assignin('base', 'EnglishFig3E_Joined', J);

%% 
% --- Plot: tiledlayout 1×2
f = figure('Color', 'w', 'Name', 'English Fig3E SD@1s vs ΔHit by layer');
f.Units = 'centimeters';
f.Position(3:4) = [6.0, 4.0]; % 60mm × 40mm

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axs = gobjects(1, 2);

zLabels = ["MOp2/3", "MOp5"];
sdVars  = ["SD_1s_MOp23", "SD_1s_MOp5"];

for iZ = 1:2
	ax = nexttile(tl, iZ);
	axs(iZ) = ax;
	hold(ax, 'on');
	box(ax, 'off');
	grid(ax, 'off');
	ax.FontSize = 6;

	x = double(J.(sdVars(iZ)));
	y = double(J.Speed_DeltaNext);
	mask = isfinite(x) & isfinite(y);

	% Scatter
	scatter(ax, x(mask), y(mask), 8, [0 0.4470 0.7410], 'LineWidth', 0.2);

	% Fit line
	if nnz(mask) >= 2 && std(x(mask)) > 0
		pFit = polyfit(x(mask), y(mask), 1);
		xFit = [min(x(mask)) max(x(mask))];
		yFit = polyval(pFit, xFit);
		plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
	end

	% Spearman
	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rho, p] = corr(x(mask), y(mask), 'Type', 'Spearman');
	end

	if isfinite(p)
		if p < 0.001
			pStr = sprintf('p=%.1e', p);
		else
			pStr = sprintf('p=%.3f', p);
		end
		text(ax, 0.02, 0.98, sprintf('r=%.2f %s\nn=%d', rho, pStr, nnz(mask)), ...
			'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontSize', 6);
	end

	title(ax, zLabels(iZ), 'FontSize', 6, 'FontWeight', 'normal');
end

xlabel(tl, 'Inter-cell SD', 'FontSize', 6);
ylabel(tl, 'ΔHit', 'FontSize', 6);

% Unify Y axes
yl = cell2mat(arrayfun(@(a) ylim(a), axs, 'UniformOutput', false)');
ylAll = [min(yl(:,1)) max(yl(:,2))];
for k = 1:2, ylim(axs(k), ylAll); end

% Hide right-panel Y tick labels
axs(2).YTickLabel = [];

% --- Export SVG
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

%% ---- local helpers

function Tout = iSessionSD1s_ByLayer(DS, SessKey, idx1s)
% One row per session: inter-cell SD at 1s, per layer (MOp2/3, MOp5).
% Uses NTS (trial-level) → median across trials → std across cells.
minCells = 3;

Cells = DS.Cells;
Cells.CellUID = uint64(Cells.CellUID);
Cells.Mouse = string(Cells.Mouse);
Cells.ZLayer = string(Cells.ZLayer);

SessKey.Mouse = string(SessKey.Mouse);
SessKey.DateTime = datetime(SessKey.DateTime);
if isdatetime(SessKey.DateTime) && ~isempty(SessKey.DateTime.TimeZone)
	SessKey.DateTime.TimeZone = '';
end
SessKey = unique(SessKey(:, {'Mouse','DateTime'}), 'rows');

outMouse  = strings(0,1);
outDT     = NaT(0,1);
outSD23   = nan(0,1);
outSD5    = nan(0,1);
outN23    = nan(0,1);
outN5     = nan(0,1);

for i = 1:height(SessKey)
	m  = string(SessKey.Mouse(i));
	dt = SessKey.DateTime(i);

	q = struct('Mouse', m, 'DateTime', dt, 'Stimulus', 'LightWater');
	ntsCell = DS.QueryNTS(q, UniExp.Flags.ZScore, 1:24);
	if isempty(ntsCell) || isempty(ntsCell{1})
		continue;
	end
	nts = ntsCell{1};
	if ~istable(nts) || height(nts) == 0 || ~all(ismember(["CellUID","TrialSignal"], string(nts.Properties.VariableNames)))
		continue;
	end

	% Per-cell median signal → value at idx1s
	[uid, vals] = iCellMedianAt(nts, idx1s);
	if isempty(uid), continue; end

	cellT = table(uid, vals, 'VariableNames', {'CellUID','Val1s'});
	cellT = innerjoin(cellT, Cells(:, {'CellUID','Mouse','ZLayer'}), 'Keys', 'CellUID');
	cellT = cellT(cellT.Mouse == m, :);

	% MOp2/3
	v23 = double(cellT.Val1s(cellT.ZLayer == "MOp2/3"));
	v23 = v23(isfinite(v23));
	sd23 = NaN; n23 = numel(v23);
	if n23 >= minCells
		sd23 = std(v23, 0, 1);
	end

	% MOp5
	v5 = double(cellT.Val1s(cellT.ZLayer == "MOp5"));
	v5 = v5(isfinite(v5));
	sd5 = NaN; n5 = numel(v5);
	if n5 >= minCells
		sd5 = std(v5, 0, 1);
	end

	if ~isfinite(sd23) && ~isfinite(sd5)
		continue;
	end

	outMouse(end+1,1) = m;   %#ok<AGROW>
	outDT(end+1,1)    = dt;  %#ok<AGROW>
	outSD23(end+1,1)  = sd23; %#ok<AGROW>
	outSD5(end+1,1)   = sd5;  %#ok<AGROW>
	outN23(end+1,1)   = n23;  %#ok<AGROW>
	outN5(end+1,1)    = n5;   %#ok<AGROW>
end

Tout = table(outMouse, outDT, outN23, outSD23, outN5, outSD5, ...
	'VariableNames', {'Mouse','DateTime','NCells_MOp23','SD_1s_MOp23','NCells_MOp5','SD_1s_MOp5'});
end

function [cellUIDs, vals] = iCellMedianAt(nts, idxT)
% Per-cell value at idxT from trial-level signals, median across trials.
cellUIDs = unique(uint64(nts.CellUID));
vals = nan(numel(cellUIDs), 1);
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rows = (uint64(nts.CellUID) == cid);
	if nnz(rows) < 1, continue; end
	sig = double(nts.TrialSignal(rows, :));
	if isempty(sig) || ~ismatrix(sig), continue; end
	med = median(sig, 1, 'omitnan');
	if size(med, 2) >= idxT
		vals(iC) = med(idxT);
	end
end
end

function Sess = iLightWaterSessions(DS)
vars = ["Mouse","DateTime","BlockUID","Phase"];
Tblk = DS.TableQuery(vars);
if isempty(Tblk)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end
Tr = DS.Trials;
TrStim = string(Tr.Stimulus);
TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
if isempty(TrLW)
	Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
	return;
end
[G, bu] = findgroups(uint64(TrLW.BlockUID));
lwPerf = splitapply(@(x) mean(double(x),'omitnan'), TrLW.Behavior, G);
perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

Tblk.Mouse = string(Tblk.Mouse);
Tblk.DateTime = datetime(Tblk.DateTime);
if isdatetime(Tblk.DateTime) && ~isempty(Tblk.DateTime.TimeZone)
	Tblk.DateTime.TimeZone = '';
end
blkUID64 = uint64(Tblk.BlockUID);
[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
Tblk = Tblk(tf, :);
Tblk.LWPerf = perfByBlock.LWPerf(loc(tf));

[G2, mouse, dt] = findgroups(string(Tblk.Mouse), Tblk.DateTime);
perf = splitapply(@(x) mean(double(x),'omitnan'), Tblk.LWPerf, G2);
nBlocks = splitapply(@numel, Tblk.LWPerf, G2);
Sess = table(mouse, dt, perf, nBlocks, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession'});
Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLightWater(DS, SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
keep = true(height(SessOut), 1);
for i = 1:height(SessOut)
	m = string(SessOut.Mouse(i));
	dt = SessOut.DateTime(i);
	Ta = DS.TableQuery("Stimulus", Mouse=m, DateTime=dt, Stimulus="AudioWater");
	if ~isempty(Ta)
		keep(i) = false;
	end
end
SessOut = SessOut(keep, :);
end

function SessOut = iExcludeCeiling(SessIn)
SessOut = SessIn;
if isempty(SessOut), return; end
SessOut.Mouse = string(SessOut.Mouse);
SessOut = sortrows(SessOut, {'Mouse','DateTime'});
remove = false(height(SessOut), 1);
mice = unique(string(SessOut.Mouse));
for mi = 1:numel(mice)
	m = mice(mi);
	rows = find(SessOut.Mouse == m);
	p = double(SessOut.Performance(rows));
	i100 = find(isfinite(p) & p >= (1 - 1e-12), 1, 'first');
	if isempty(i100), continue; end
	remove(rows(i100:end)) = true;
end
SessOut(remove,:) = [];
perf = double(SessOut.Performance);
keep = isfinite(perf) & (perf >= -1e-12) & (perf < (1 - 1e-12));
SessOut = SessOut(keep, :);
end

function SessSpeed = iSessionDeltaNextTable(Sess)
SessSpeed = table(string.empty(0,1), NaT(0,1), nan(0,1), NaT(0,1), nan(0,1), nan(0,1), ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
if isempty(Sess), return; end
Sess = sortrows(Sess, {'Mouse','DateTime'});
Sess.Mouse = string(Sess.Mouse);
mice = unique(string(Sess.Mouse));
outMouse = strings(0,1); outDT = NaT(0,1); outPerf = nan(0,1);
outDT2 = NaT(0,1); outPerf2 = nan(0,1); outDN = nan(0,1);
for mi = 1:numel(mice)
	m = mice(mi);
	R = Sess(Sess.Mouse == m, :);
	perf = double(R.Performance); dt = R.DateTime;
	use = isfinite(perf) & ~ismissing(dt);
	perf = perf(use); dt = dt(use);
	if numel(perf) < 2, continue; end
	dn = diff(perf);
	outMouse = [outMouse; repmat(string(m), numel(dn), 1)]; %#ok<AGROW>
	outDT    = [outDT;    dt(1:end-1)];                      %#ok<AGROW>
	outPerf  = [outPerf;  perf(1:end-1)];                    %#ok<AGROW>
	outDT2   = [outDT2;   dt(2:end)];                        %#ok<AGROW>
	outPerf2 = [outPerf2; perf(2:end)];                      %#ok<AGROW>
	outDN    = [outDN;    dn(:)];                             %#ok<AGROW>
end
SessSpeed = table(outMouse, outDT, outPerf, outDT2, outPerf2, outDN, ...
	'VariableNames', {'Mouse','DateTime','Performance','DateTimeNext','PerformanceNext','Speed_DeltaNext'});
end
