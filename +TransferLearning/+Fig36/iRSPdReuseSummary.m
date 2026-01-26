function Summary = iRSPdReuseSummary(RSP, GLearn, GTran, XLearn, XTran, xsSec, baseMask, winMask)
% TransferLearning.Fig36.iRSPdReuseSummary
% Median-NTATS threshold reuse summary (per mouse×layer)
% Reuse rate: P(TransferActive | LearnedActive)

kSigma = 3;

learnedBaseMu = mean(XLearn(:, baseMask), 2, 'omitnan');
learnedBaseSd = std(XLearn(:, baseMask), 0, 2, 'omitnan');
learnedWinMx  = max(XLearn(:, winMask), [], 2, 'omitnan');
learnedActive = learnedWinMx > (learnedBaseMu + kSigma .* learnedBaseSd);

tranBaseMu = mean(XTran(:, baseMask), 2, 'omitnan');
tranBaseSd = std(XTran(:, baseMask), 0, 2, 'omitnan');
tranWinMx  = max(XTran(:, winMask), [], 2, 'omitnan');
tranActive = tranWinMx > (tranBaseMu + kSigma .* tranBaseSd);

% Hit/Miss in Transfer
QT_HM = table(categorical({'Hit';'Miss'}), categorical({'Transfer';'Transfer'}), categorical({'LightWater';'LightWater'}), categorical({'LightWater';'LightWater'}), {1;0}, ...
	'VariableNames', {'GroupName','Phase','Design','Stimulus','Behavior'});
try
	GTranHM = RSP.QueryNTATS(QT_HM, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
catch
	GTranHM = [];
end

XTranHit = nan(size(XTran));
XTranMiss = nan(size(XTran));
cellUIDTranHM = uint64([]);
if ~isempty(GTranHM) && height(GTranHM) > 0
	XTranHM = TransferLearning.Fig36.iNtatsData(GTranHM.NTATS);
	if ndims(XTranHM) == 3 && size(XTranHM,3) >= 2
		XTranHit = XTranHM(:,:,1);
		XTranMiss = XTranHM(:,:,2);
		cellUIDTranHM = uint64(GTranHM.CellUID);
	end
end

tranHitBaseMu = mean(XTranHit(:, baseMask), 2, 'omitnan');
tranHitBaseSd = std(XTranHit(:, baseMask), 0, 2, 'omitnan');
tranHitWinMx  = max(XTranHit(:, winMask), [], 2, 'omitnan');
tranActiveHit = tranHitWinMx > (tranHitBaseMu + kSigma .* tranHitBaseSd);

tranMissBaseMu = mean(XTranMiss(:, baseMask), 2, 'omitnan');
tranMissBaseSd = std(XTranMiss(:, baseMask), 0, 2, 'omitnan');
tranMissWinMx  = max(XTranMiss(:, winMask), [], 2, 'omitnan');
tranActiveMiss = tranMissWinMx > (tranMissBaseMu + kSigma .* tranMissBaseSd);

% Performance per mouse (Transfer)
PerfT = RSP.TableQuery(["Mouse","Performance"], Phase="Transfer", Design="LightWater");
PerfT.Mouse = string(PerfT.Mouse);
[gM, mKeys] = findgroups(PerfT.Mouse);
perfByMouse = table(mKeys, splitapply(@(p) mean(p, 'omitnan'), PerfT.Performance, gM), ...
	'VariableNames', {'Mouse','TransferPerformance'});

C = RSP.Cells;
learnedCell = table(uint64(GLearn.CellUID), double(learnedActive), 'VariableNames', {'CellUID','LearnedActive'});
transferCell = table(uint64(GTran.CellUID), double(tranActive), 'VariableNames', {'CellUID','TransferActive'});

transferCellHit = table(cellUIDTranHM, double(tranActiveHit), 'VariableNames', {'CellUID','TransferActiveHit'});
transferCellMiss = table(cellUIDTranHM, double(tranActiveMiss), 'VariableNames', {'CellUID','TransferActiveMiss'});

learnedCell = innerjoin(learnedCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
transferCell = innerjoin(transferCell, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
if ~isempty(transferCellHit)
	transferCellHit = innerjoin(transferCellHit, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
end
if ~isempty(transferCellMiss)
	transferCellMiss = innerjoin(transferCellMiss, C(:,{'CellUID','Mouse','ZLayer'}), 'Keys','CellUID');
end

learnedCell.Mouse = string(learnedCell.Mouse);
transferCell.Mouse = string(transferCell.Mouse);
transferCellHit.Mouse = string(transferCellHit.Mouse);
transferCellMiss.Mouse = string(transferCellMiss.Mouse);

learnedCell.ZLayer = string(learnedCell.ZLayer);
transferCell.ZLayer = string(transferCell.ZLayer);
transferCellHit.ZLayer = string(transferCellHit.ZLayer);
transferCellMiss.ZLayer = string(transferCellMiss.ZLayer);

medLT = innerjoin(learnedCell(:,{'Mouse','ZLayer','CellUID','LearnedActive'}), transferCell(:,{'Mouse','ZLayer','CellUID','TransferActive'}), ...
	'Keys', {'Mouse','ZLayer','CellUID'});

medLT = outerjoin(medLT, transferCellHit(:,{'Mouse','ZLayer','CellUID','TransferActiveHit'}), ...
	'Keys', {'Mouse','ZLayer','CellUID'}, 'MergeKeys', true, 'Type', 'left');
medLT = outerjoin(medLT, transferCellMiss(:,{'Mouse','ZLayer','CellUID','TransferActiveMiss'}), ...
	'Keys', {'Mouse','ZLayer','CellUID'}, 'MergeKeys', true, 'Type', 'left');

mouseZ = unique(medLT(:,{'Mouse','ZLayer'}));
maxRows = height(mouseZ);

sumMouse = strings(maxRows,1);
sumZ = strings(maxRows,1);
sumPerf = nan(maxRows,1);
sumN = nan(maxRows,1);
sumReuse = nan(maxRows,1);
sumReuseHit = nan(maxRows,1);
sumReuseMiss = nan(maxRows,1);
rowN = 0;

for i = 1:height(mouseZ)
	m = string(mouseZ.Mouse(i));
	z = string(mouseZ.ZLayer(i));
	rows = (string(medLT.Mouse)==m) & (string(medLT.ZLayer)==z);
	if nnz(rows) < 10
		continue;
	end
	LA = logical(medLT.LearnedActive(rows));
	TA = logical(medLT.TransferActive(rows));
	
	reuse = mean(double(TA(LA)), 'omitnan');
	
	reuseHit = NaN;
	if ismember('TransferActiveHit', medLT.Properties.VariableNames)
		taHit = medLT.TransferActiveHit(rows);
		den = LA & isfinite(taHit);
		if nnz(den) > 0
			reuseHit = mean(taHit(den), 'omitnan');
		end
	end
	
	reuseMiss = NaN;
	if ismember('TransferActiveMiss', medLT.Properties.VariableNames)
		taMiss = medLT.TransferActiveMiss(rows);
		den = LA & isfinite(taMiss);
		if nnz(den) > 0
			reuseMiss = mean(taMiss(den), 'omitnan');
		end
	end
	
	perf = perfByMouse.TransferPerformance(perfByMouse.Mouse==m);
	if isempty(perf)
		perf = NaN;
	else
		perf = perf(1);
	end
	
	rowN = rowN + 1;
	sumMouse(rowN) = m;
	sumZ(rowN) = z;
	sumPerf(rowN) = perf;
	sumN(rowN) = nnz(rows);
	sumReuse(rowN) = reuse;
	sumReuseHit(rowN) = reuseHit;
	sumReuseMiss(rowN) = reuseMiss;
end

Summary = table(sumMouse(1:rowN), sumZ(1:rowN), sumPerf(1:rowN), sumN(1:rowN), sumReuse(1:rowN), sumReuseHit(1:rowN), sumReuseMiss(1:rowN), ...
	'VariableNames', {'Mouse','ZLayer','TransferPerformance','NCells','ReuseRate','ReuseRate_Hit','ReuseRate_Miss'});
end
