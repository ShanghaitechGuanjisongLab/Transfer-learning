% English Fig2B: behavior decoder transfers to light, cue decoder does not
%
% 2x2 layout (2 lines per panel, 1.5 s window), copied from
% 信息编码/Cfg2Figure_15.m:
%   row 1 = Cue decoder (trained on AudioOnly + LightOnly calibration)
%   row 2 = Choice decoder (trained on AudioWater hit/miss)
%   col 1 = Stage1 in-training probability tendency
%   col 2 = Stage2 held-out Transfer LightWater probability tendency
% Key claim: in Stage2 the choice decoder separates light hit from light
% miss, whereas the cue decoder's two lines stay at chance (~0.5).
%
% Outputs (SVG):
%   - English_Fig2B_DecoderTransfer.svg
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

data = TransferLearning.BuildCueChoiceDecoderData();
tVec = data.tVec;
nTfull = numel(tVec);
K = 5;
met = 2;

% ---------- decode per mouse per time point ----------
nCue = numel(data.cue);
nCh = numel(data.choice);
pSt1Cue = nan(nCue, 2, nTfull);
pSt2Cue = nan(nCue, 2, nTfull);
for i = 1:nCue
	r = data.cue{i};
	for iT = 1:nTfull
		Ftr = r.X2(:, :, iT);
		[sOOF, ~] = iCvPredict(Ftr, r.y2, K, met);
		pAOOF = 1 ./ (1 + exp(sOOF));
		pSt1Cue(i, 1, iT) = mean(pAOOF(r.typ2 == 1));   % audio only
		pSt1Cue(i, 2, iT) = mean(pAOOF(r.typ2 == 2));   % light only
		bal = iBalanceTrain(r.y2);
		[sT, ~] = iGlmDecode(Ftr(bal, :), r.y2(bal), r.Xt(:, :, iT));
		pAT = 1 ./ (1 + exp(sT));
		pSt2Cue(i, 1, iT) = mean(pAT(r.behT == 1));     % light hit
		pSt2Cue(i, 2, iT) = mean(pAT(r.behT == 0));     % light miss
	end
end
pSt1Ch = nan(nCh, 2, nTfull);
pSt2Ch = nan(nCh, 2, nTfull);
for i = 1:nCh
	r = data.choice{i};
	okB = ~isnan(r.behTr2);
	for iT = 1:nTfull
		Ftr = r.Xtr2(okB, :, iT);
		yb = r.behTr2(okB);
		[sOOF, ~] = iCvPredict(Ftr, yb, K, met);
		phO = 1 ./ (1 + exp(-sOOF));
		pSt1Ch(i, 1, iT) = mean(phO(yb == 1));          % audio hit
		pSt1Ch(i, 2, iT) = mean(phO(yb == 0));          % audio miss
		bal = iBalanceTrain(yb);
		[sT, ~] = iGlmDecode(Ftr(bal, :), yb(bal), r.Xte(:, :, iT));
		phT = 1 ./ (1 + exp(-sT));
		pSt2Ch(i, 1, iT) = mean(phT(r.behTe == 1));     % light hit
		pSt2Ch(i, 2, iT) = mean(phT(r.behTe == 0));     % light miss
	end
end

% ---------- figure ----------
f = figure('Color', 'w', 'Name', 'English Fig2B decoder transfer');
f.Units = 'centimeters';
f.Position(3:4) = [12, 9];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 9];
f.PaperPositionMode = 'auto';

stC1 = {[0.85 0.33 0.10], [0.10 0.45 0.70]};
stC1a = {[0.30 0.60 0.20], [0.70 0.30 0.70]};
stN2 = {'light hit', 'light miss'};

axGrid = gobjects(2, 2);
for r = 1:2
	for c = 1:2
		ax = subplot(2, 2, (r - 1) * 2 + c);
		hold(ax, 'on');
		axGrid(r, c) = ax;
		if c == 1
			if r == 1
				P = pSt1Cue;
				stN = {'audio only', 'light only'};
				stC = stC1a;
				ylbl = 'P(audio) tendency';
			else
				P = pSt1Ch;
				stN = {'audio hit', 'audio miss'};
				stC = stC1;
				ylbl = 'P(hit) tendency';
			end
		else
			if r == 1
				P = pSt2Cue;
				ylbl = 'P(audio) tendency';
			else
				P = pSt2Ch;
				ylbl = 'P(hit) tendency';
			end
			stN = stN2;
			stC = stC1;
		end
		for s = 1:2
			v = squeeze(P(:, s, :));
			if all(isnan(v(:)))
				continue;
			end
			mn = mean(v, 1, 'omitnan');
			se = std(v, 0, 1, 'omitnan') / sqrt(sum(~isnan(v(:, 1))));
			iShadedError(ax, tVec, mn, se, stC{s}, 1.4, stN{s});
		end
		iSigStars(ax, tVec, squeeze(P(:, 1, :)), squeeze(P(:, 2, :)), 0.02, stC{1});
		ylabel(ax, ylbl, 'FontSize', 8);
		ylim(ax, [0 1]);
		yline(ax, 0.5, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility', 'off');
		xline(ax, 1, '-.', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, 'HandleVisibility', 'off');
		if r == 2
			xlabel(ax, 'Time from stimulus (s)', 'FontSize', 8);
		end
		legend(ax, 'Location', 'northwest', 'Box', 'off', 'FontSize', 7);
		box(ax, 'off');
		ax.FontSize = 7;
		ax.LineWidth = 1;
		ax.Color = 'none';
	end
end
text(axGrid(1, 1), 0.5, 1.16, 'Stage1 (trained task)', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
text(axGrid(1, 2), 0.5, 1.16, 'Stage2 (transfer light-water)', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
text(axGrid(1, 1), -0.3, 0.5, 'Cue decoder', 'Units', 'normalized', 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 8);
text(axGrid(2, 1), -0.3, 0.5, 'Behavior decoder', 'Units', 'normalized', 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 8);

if isprop(axGrid(1,1), 'Toolbar') && ~isempty(axGrid(1,1).Toolbar)
	axGrid(1,1).Toolbar.Visible = 'off';
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'English_Fig2B_DecoderTransfer.svg');
fprintf('Wrote: %s\n', svgPath);

% ---------- statistics: Stage2 separation, BH-FDR over time points ----------
fprintf('\n=== Fig2B Stage2 (transfer) hit vs miss, paired t-test per time point ===\n');
for r = 1:2
	if r == 1
		P = pSt2Cue;
		name = 'Cue decoder';
	else
		P = pSt2Ch;
		name = 'Behavior decoder';
	end
	pRaw = nan(1, nTfull);
	for iT = 1:nTfull
		a = squeeze(P(:, 1, iT));
		b = squeeze(P(:, 2, iT));
		ok = isfinite(a) & isfinite(b);
		if sum(ok) < 4
			continue;
		end
		[~, pRaw(iT)] = ttest(a(ok), b(ok));
	end
	okP = isfinite(pRaw);
	pBH = nan(1, nTfull);
	pBH(okP) = mafdr(pRaw(okP));
	nNom = sum(pRaw < 0.05, 'omitnan');
	nFdr = sum(pBH < 0.05, 'omitnan');
	fprintf('%s: nominal p<0.05 at %d/%d time points; BH-FDR q<0.05 at %d\n', name, nNom, nTfull, nFdr);
end

assignin('base', 'Fig2B_DecoderTendency', struct('pSt1Cue', pSt1Cue, 'pSt2Cue', pSt2Cue, 'pSt1Ch', pSt1Ch, 'pSt2Ch', pSt2Ch, 'tVec', tVec, 'nCue', nCue, 'nCh', nCh));

%% ========== local functions ==========
function iSigStars(ax, tVec, v1, v2, yoff, col)
hold(ax, 'on');
m1 = mean(v1, 1, 'omitnan');
m2 = mean(v2, 1, 'omitnan');
for iT = 1:numel(tVec)
	a = v1(:, iT);
	b = v2(:, iT);
	ok = ~isnan(a) & ~isnan(b);
	if sum(ok) < 4
		continue;
	end
	[~, pp] = ttest(a(ok), b(ok));
	if pp < 0.05
		y = max(m1(iT), m2(iT)) + yoff;
		text(ax, tVec(iT), y, '*', 'Color', col, 'FontSize', 9, ...
			'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
	end
end
end

function iShadedError(ax, x, mn, se, col, lw, dn)
x = x(:)';
mn = mn(:)';
se = se(:)';
ok = ~isnan(mn) & ~isnan(se);
x = x(ok);
mn = mn(ok);
se = se(ok);
if isempty(x)
	return;
end
hold(ax, 'on');
fill(ax, [x fliplr(x)], [mn + se fliplr(mn - se)], col, ...
	'FaceAlpha', 0.25, 'EdgeColor', 'none', 'HandleVisibility', 'off');
plot(ax, x, mn, '-', 'Color', col, 'LineWidth', lw, 'DisplayName', dn);
end

function [sOOF, pOOF] = iCvPredict(F, y, K, met)
n = size(F, 1);
sOOF = nan(n, 1);
pOOF = nan(n, 1);
perm = randperm(n);
foldSize = ceil(n / K);
for k = 1:K
	te = false(n, 1);
	idx = (k - 1) * foldSize + 1 : min(k * foldSize, n);
	te(perm(idx)) = true;
	tr = ~te;
	if sum(y(te) == 1) < 1 || sum(y(te) == 0) < 1
		maj = mode(y(tr));
		sOOF(te) = 2 * maj - 1;
		pOOF(te) = maj;
		continue;
	end
	bal = iBalanceTrain(y(tr));
	idxTr = find(tr);
	if met == 1
		[sOOF(te), pOOF(te)] = iLinDecode(F(idxTr(bal), :), y(idxTr(bal)), F(te, :));
	else
		[sOOF(te), pOOF(te)] = iGlmDecode(F(idxTr(bal), :), y(idxTr(bal)), F(te, :));
	end
end
end

function bal = iBalanceTrain(y)
idx1 = find(y == 1);
idx0 = find(y == 0);
n = min(numel(idx1), numel(idx0));
idx1 = idx1(randperm(numel(idx1), n));
idx0 = idx0(randperm(numel(idx0), n));
bal = [idx1; idx0];
end

function [score, pred] = iLinDecode(Ftr, ytr, Fte)
mu = mean(Ftr, 1);
sd = std(Ftr, 0, 1);
sd(sd == 0) = 1;
Ftrs = (Ftr - mu) ./ sd;
Ftes = (Fte - mu) ./ sd;
w = pinv([ones(size(Ftrs, 1), 1), Ftrs]) * (2 * ytr - 1);
score = [ones(size(Ftes, 1), 1), Ftes] * w;
pred = double(score >= 0);
end

function [score, pred] = iGlmDecode(Ftr, ytr, Fte)
m0 = mean(Ftr(ytr == 0, :), 1);
m1 = mean(Ftr(ytr == 1, :), 1);
s0 = std(Ftr(ytr == 0, :), 0, 1);
s1 = std(Ftr(ytr == 1, :), 0, 1);
sp = sqrt((s0.^2 + s1.^2) / 2);
sp(sp == 0) = 1;
score = sum((Fte - m0).^2 ./ (2 * sp.^2) - (Fte - m1).^2 ./ (2 * sp.^2), 2);
pred = double(score >= 0);
end
