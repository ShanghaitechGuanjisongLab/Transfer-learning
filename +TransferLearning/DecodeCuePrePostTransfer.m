function R = DecodeCuePrePostTransfer(Task, tVec, NPerm)
% Cue pre/post decoder trained on window averages and read out at every time
% point of one or more held-out trial sets.
%
% Decoder (identical rule to 信息编码/CueModel.m and the English Fig3D pipeline
% CueModel_TransferAudioToLight.m):
%   Per trial, mean population z-scored activity in the pre window (-1..0 s) and
%   in the post window (0..1 s); label pre = 0 / post = 1; LASSO logistic
%   regression with Lambda = 0.02/sqrt(2*nTrialTrain).
%   Stage1 = 5-fold trial-aware cross-validation on the training trials (the pre
%   and post sample of a trial always fall in the same fold, so no sample is
%   ever both trained on and tested).
%   Stage2 = the decoder trained on ALL training trials, applied unchanged to
%   each held-out test set, read out at every time point of tVec.
%   Nulls = label-shuffled permutations, shuffling TRAINING labels only
%   (NPerm iterations, default 200; per-time-point p and 95th percentile band).
%
% The RNG consumption order of this function is the same as the original local
% iDecodePrePost (one randperm for the folds, then per permutation one label
% shuffle, one full fit, the test readouts, then the 5 CV fits), so calling it
% with the same rng seed reproduces the Fig3D numbers for a single test set.
%
% Input:
%   Task  - struct with fields
%           .DS      (numeric id, optional)
%           .Mouse   (char)
%           .NCells  (numeric)
%           .CellUIDs(uint64 column vector, cell order of the matrices)
%           .preTr, .postTr   (nTr x nCells window averages)
%           .XTrT             (nTr x nCells x nT per-time-point traces)
%           .Tests   (struct array: .Name char, .preTe, .postTe, .XTeT)
%           A task without .Tests but with .preTe/.postTe/.XTeT is treated as a
%           single test set named 'Test' (the Fig3D task layout).
%   tVec  - time grid (1 x nT, seconds), the read-out grid of XTrT/XTeT
%   NPerm - number of label permutations (default 200)
%
% Output R (one struct per mouse):
%   .DS .Mouse .nCells .nTr .tVec .cellUIDs .w .bias .lambda
%   Stage1: .s1Acc .s1p .pPostS1T .fracPostS1T .pByT1 .null95S1 .pMaxStat1
%   Stage2: .Tests(k) with .name .nTe .acc .p .pPostByT .fracPostByT .pByT
%           .null95 .pMaxStat; for a single test set these are also mirrored to
%           the Fig3D field names .s2Acc .s2p .pPostByT .fracPostByT .pByT
%           .null95 .pMaxStat.

	arguments
		Task (1,1) struct
		tVec (1,:) double
		NPerm (1,1) double {mustBePositive, mustBeInteger} = 200
	end

	if ~isfield(Task, 'Tests')
		Task.Tests = struct('Name', 'Test', 'preTe', {Task.preTe}, 'postTe', {Task.postTe}, 'XTeT', {Task.XTeT});
	end
	nTest = numel(Task.Tests);
	if isfield(Task, 'DS')
		iDS = Task.DS;
	else
		iDS = NaN;
	end

	% ---------- training samples ----------
	preTr = Task.preTr;
	postTr = Task.postTr;
	nTr = size(preTr, 1);
	xTrAll = [preTr; postTr];
	yTrAll = [zeros(nTr, 1); ones(nTr, 1)];
	mu = mean(xTrAll, 1);
	sd = std(xTrAll, 0, 1);
	sd(sd == 0) = 1;
	xTrS = (xTrAll - mu) ./ sd;
	xTrS(isnan(xTrS)) = 0;
	lam = 0.02 / sqrt(nTr * 2);
	mdl = fitclinear(xTrS, yTrAll, ...
		'Learner', 'logistic', 'Regularization', 'lasso', 'Lambda', lam);
	w = mdl.Beta;
	b0 = mdl.Bias;
	nT = numel(tVec);

	% ---------- Stage2 observed (all training trials -> each test set) ----------
	accTe = zeros(nTest, 1);
	pPostTe = cell(nTest, 1);
	fracPostTe = cell(nTest, 1);
	nTe = zeros(nTest, 1);
	yTeAllS = cell(nTest, 1);
	xTeS = cell(nTest, 1);
	for k = 1:nTest
		Tk = Task.Tests(k);
		nTe(k) = size(Tk.preTe, 1);
		xTeAll = [Tk.preTe; Tk.postTe];
		yTeAll = [zeros(nTe(k), 1); ones(nTe(k), 1)];
		zTe = (xTeAll - mu) ./ sd;
		zTe(isnan(zTe)) = 0;
		xTeS{k} = zTe;
		yTeAllS{k} = yTeAll;
		labelTe = predict(mdl, zTe);
		accTe(k) = mean(labelTe == yTeAll);
		pS2 = iTimePointReadoutFull(Tk.XTeT, mu, sd, w, b0, nT);
		pPostTe{k} = mean(pS2, 1);
		fracPostTe{k} = mean(pS2 >= 0.5, 1);
	end

	% ---------- Stage1: 5-fold trial-aware CV on the training trials ----------
	K = 5;
	perm = randperm(nTr);
	foldSize = ceil(nTr / K);
	foldTET = cell(K, 1);
	foldMdl = cell(K, 1);
	predCv = zeros(2 * nTr, 1);
	trueCv = [zeros(nTr, 1); ones(nTr, 1)];
	for k = 1:K
		idxT = (k - 1) * foldSize + 1:min(k * foldSize, nTr);
		teT = false(nTr, 1);
		teT(perm(idxT)) = true;
		teI = [teT; teT];
		mF = fitclinear(xTrS(~teI, :), yTrAll(~teI), ...
			'Learner', 'logistic', 'Regularization', 'lasso', 'Lambda', lam);
		predCv(teI) = predict(mF, xTrS(teI, :));
		foldTET{k} = teT;
		foldMdl{k} = mF;
	end
	accCv = mean(predCv == trueCv);
	pPostS1 = iTimePointReadout(Task.XTrT, mu, sd, foldTET, foldMdl, nT);
	pPostS1T = mean(pPostS1, 1, 'omitnan');
	fracPostS1T = mean(pPostS1 >= 0.5, 1, 'omitnan');

	% ---------- permutation nulls (shuffle TRAINING labels only) ----------
	saTe = zeros(NPerm, nTest);
	nullPP = nan(NPerm, nT, nTest);
	saCv = zeros(NPerm, 1);
	nullS1 = nan(NPerm, nT);
	for iS = 1:NPerm
		sy = yTrAll(randperm(nTr * 2));
		mS = fitclinear(xTrS, sy, ...
			'Learner', 'logistic', 'Regularization', 'lasso', 'Lambda', lam);
		for k = 1:nTest
			labelS = predict(mS, xTeS{k});
			saTe(iS, k) = mean(labelS == yTeAllS{k});
			pSh = iTimePointReadoutFull(Task.Tests(k).XTeT, mu, sd, mS.Beta, mS.Bias, nT);
			nullPP(iS, :, k) = mean(pSh, 1);
		end
		predS = zeros(2 * nTr, 1);
		foldMdlS = cell(K, 1);
		for k = 1:K
			teI = [foldTET{k}; foldTET{k}];
			mF = fitclinear(xTrS(~teI, :), sy(~teI), ...
				'Learner', 'logistic', 'Regularization', 'lasso', 'Lambda', lam);
			predS(teI) = predict(mF, xTrS(teI, :));
			foldMdlS{k} = mF;
		end
		saCv(iS) = mean(predS == trueCv);
		nullS1(iS, :) = mean(iTimePointReadout(Task.XTrT, mu, sd, foldTET, foldMdlS, nT), 1, 'omitnan');
	end

	pCv = (sum(saCv >= accCv) + 1) / (NPerm + 1);
	pByT1 = (sum(nullS1 >= pPostS1T, 1) + 1) / (NPerm + 1);
	null95S1 = prctile(nullS1, 95, 1);
	pMaxStat1 = (sum(max(nullS1, [], 2) >= max(pPostS1T)) + 1) / (NPerm + 1);

	Tests = repmat(struct('name', "", 'nTe', 0, 'acc', NaN, 'p', NaN, 'pPostByT', [], ...
		'fracPostByT', [], 'pByT', [], 'null95', [], 'pMaxStat', NaN), nTest, 1);
	for k = 1:nTest
		nk = squeeze(nullPP(:, :, k));
		pByT = (sum(nk >= pPostTe{k}, 1) + 1) / (NPerm + 1);
		Tests(k) = struct('name', string(Task.Tests(k).Name), 'nTe', nTe(k), ...
			'acc', accTe(k), 'p', (sum(saTe(:, k) >= accTe(k)) + 1) / (NPerm + 1), ...
			'pPostByT', pPostTe{k}, 'fracPostByT', fracPostTe{k}, ...
			'pByT', pByT, 'null95', prctile(nk, 95, 1), ...
			'pMaxStat', (sum(max(nk, [], 2) >= max(pPostTe{k})) + 1) / (NPerm + 1));
	end

	R = struct('DS', iDS, 'Mouse', Task.Mouse, 'nCells', Task.NCells, 'nTr', nTr, ...
		'tVec', tVec, 'cellUIDs', Task.CellUIDs, 'w', w, 'bias', b0, 'lambda', lam, ...
		'nPerm', NPerm, ...
		's1Acc', accCv, 's1p', pCv, 'pPostS1T', pPostS1T, 'fracPostS1T', fracPostS1T, ...
		'pByT1', pByT1, 'null95S1', null95S1, 'pMaxStat1', pMaxStat1, ...
		'Tests', Tests);
	if nTest == 1
		% Fig3D-compatible aliases for the single-test case
		R.s2Acc = Tests(1).acc;
		R.s2p = Tests(1).p;
		R.pPostByT = Tests(1).pPostByT;
		R.fracPostByT = Tests(1).fracPostByT;
		R.pByT = Tests(1).pByT;
		R.null95 = Tests(1).null95;
		R.pMaxStat = Tests(1).pMaxStat;
	end
end

function pS = iTimePointReadoutFull(XT, mu, sd, w, b0, nT)
% Read one decoder out at every time point: P(post) per trial x time point.
	pS = zeros(size(XT, 1), nT);
	for iT = 1:nT
		F = squeeze(XT(:, :, iT));
		Fs = (F - mu) ./ sd;
		Fs(isnan(Fs)) = 0;
		pS(:, iT) = 1 ./ (1 + exp(-(Fs * w + b0)));
	end
end

function pS = iTimePointReadout(XT, mu, sd, foldTET, foldMdl, nT)
% Per-fold out-of-fold P(post) at every time point, one row per training trial
% (rows outside the fold stay NaN; both samples of a trial share one fold).
	nTr = size(XT, 1);
	pS = nan(nTr, nT);
	for k = 1:numel(foldMdl)
		teT = foldTET{k};
		wF = foldMdl{k}.Beta;
		bF = foldMdl{k}.Bias;
		for iT = 1:nT
			F = squeeze(XT(:, :, iT));
			Fs = (F - mu) ./ sd;
			Fs(isnan(Fs)) = 0;
			pS(teT, iT) = 1 ./ (1 + exp(-(Fs(teT, :) * wF + bF)));
		end
	end
end
