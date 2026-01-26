function SessSD = iRSPdSessionSD(RSP, Sess, idx0p3, idx1p5)
% TransferLearning.Fig36.iRSPdSessionSD
% Inter-cell SD within each Transfer session at given time indices.
% idx0p3 and idx1p5 are optional; pass [] to skip.

C = RSP.Cells(:, {'CellUID','ZLayer'});
C.ZLayer = string(C.ZLayer);

n = height(Sess);
Std0p3_23 = nan(n,1);
Std0p3_5  = nan(n,1);
Std1p5_23 = nan(n,1);
Std1p5_5  = nan(n,1);

need0p3 = ~isempty(idx0p3) && isnumeric(idx0p3) && isfinite(idx0p3);
need1p5 = ~isempty(idx1p5) && isnumeric(idx1p5) && isfinite(idx1p5);

for i = 1:n
	dt = Sess.DateTime(i);
	try
		dt.TimeZone = '';
	catch
	end
	try
		G = RSP.QueryNTATS(struct('DateTime', dt, 'Stimulus','LightWater','Design','LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		X = TransferLearning.Fig36.iNtatsData(G.NTATS);
		
		if need0p3
			x0p3 = X(:, idx0p3);
		else
			x0p3 = nan(size(X,1),1);
		end
		if need1p5
			x1p5 = X(:, idx1p5);
		else
			x1p5 = nan(size(X,1),1);
		end
		
		T = innerjoin(table(uint64(G.CellUID), x0p3, x1p5, 'VariableNames', {'CellUID','X0p3','X1p5'}), C, 'Keys','CellUID');
		m23 = (T.ZLayer=="RSPd2/3");
		m5  = (T.ZLayer=="RSPd5");
		
		if need0p3
			Std0p3_23(i) = std(double(T.X0p3(m23)), 0, 'omitnan');
			Std0p3_5(i)  = std(double(T.X0p3(m5)),  0, 'omitnan');
		end
		if need1p5
			Std1p5_23(i) = std(double(T.X1p5(m23)), 0, 'omitnan');
			Std1p5_5(i)  = std(double(T.X1p5(m5)),  0, 'omitnan');
		end
	catch
		% keep NaNs
	end
end

SessSD = Sess;
SessSD.StdCells0p3_RSPd23 = Std0p3_23;
SessSD.StdCells0p3_RSPd5  = Std0p3_5;
SessSD.StdCells1p5_RSPd23 = Std1p5_23;
SessSD.StdCells1p5_RSPd5  = Std1p5_5;
end
