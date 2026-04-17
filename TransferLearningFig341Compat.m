classdef(Abstract)TransferLearningFig341Compat
	methods(Static)
		function Data = BuildStateSpaceSummary(forceRebuild, normFlag)
			arguments
				forceRebuild (1,1) logical = false
				normFlag = UniExp.Flags.No_special_operation
			end

			persistent Cache CacheNormFlag
			if ~forceRebuild && ~isempty(Cache) && isequal(CacheNormFlag, normFlag)
				Data = Cache;
				return;
			end

			xs = TransferLearning.Xs;
			if isduration(xs)
				xsSec = seconds(xs);
			else
				xsSec = double(xs);
			end
			[idx1s, ok1s] = TransferLearningFig341Compat.iFindTimeIndex(xsSec, 1, 0.25);
			if ~ok1s
				error('Fig341:Bad1sIndex', 'Cannot find sample close to 1 s.');
			end

			Specs = [ ...
				builtin('struct', 'Group', "Naive", 'Source', "LAB", 'DS', TransferLearning.LightAudioBaseline(), 'StartPhase', "Naive", 'EndPhase', "Learned")
				builtin('struct', 'Group', "Naive", 'Source', "LAI", 'DS', TransferLearning.LAInterspersed(), 'StartPhase', "Naive", 'EndPhase', "Learned")
				builtin('struct', 'Group', "Transfer", 'Source', "ALB", 'DS', TransferLearning.AudioLightBaseline(), 'StartPhase', "Transfer", 'EndPhase', "Final")
				builtin('struct', 'Group', "Transfer", 'Source', "ALI", 'DS', TransferLearning.ALInterspersed(), 'StartPhase', "Transfer", 'EndPhase', "Final")
			];

			sessionParts = cell(numel(Specs), 1);
			for iSpec = 1:numel(Specs)
				sessionParts{iSpec} = TransferLearningFig341Compat.iBuildLearningSessionsForSource(Specs(iSpec));
			end
			allSessions = vertcat(sessionParts{:});
			allSessions = sortrows(allSessions, {'Group', 'Mouse', 'DateTime'});

			TransferLearningFig341Compat.iAssertNoCrossSourceDuplicateMice(allSessions(allSessions.Group == "Naive", :), "Naive");
			TransferLearningFig341Compat.iAssertNoCrossSourceDuplicateMice(allSessions(allSessions.Group == "Transfer", :), "Transfer");
			TransferLearningFig341Compat.iAssertNoMouseAppearsInMultipleGroups(allSessions);

			stateRows = repmat(TransferLearningFig341Compat.iEmptyMouseState(), 0, 1);
			metricRows = repmat(TransferLearningFig341Compat.iEmptyMetricRow(), 0, 1);
			for iSpec = 1:numel(Specs)
				Ssrc = allSessions(allSessions.Source == Specs(iSpec).Source, :);
				mice = unique(Ssrc.Mouse);
				for iMouse = 1:numel(mice)
					mouseId = mice(iMouse);
					Sm = Ssrc(Ssrc.Mouse == mouseId, :);
					if height(Sm) < 2
						continue;
					end
					[R, Sm] = TransferLearningFig341Compat.iQueryMouseNtats(Specs(iSpec).DS, Sm, normFlag);
					if height(Sm) < 2 || isempty(R) || height(R) < 2
						continue;
					end
					X = TransferLearningFig341Compat.iNtatsTo3D(R.NTATS);
					if isempty(X) || size(X, 3) ~= height(Sm)
						continue;
					end
					cellUID = uint64(R.CellUID);
					layers = TransferLearningFig341Compat.iLookupLayers(Specs(iSpec).DS, cellUID);
					[pointsAll, explainedAll] = TransferLearningFig341Compat.iSessionPointsFromNtats(X, idx1s);
					if size(pointsAll, 1) ~= height(Sm)
						continue;
					end

					st = TransferLearningFig341Compat.iEmptyMouseState();
					st.Mouse = mouseId;
					st.Group = Specs(iSpec).Group;
					st.Source = Specs(iSpec).Source;
					st.SessionTable = Sm;
					st.CellUID = cellUID;
					st.Layers = layers;
					st.NTATS = X;
					st.Points = pointsAll;
					st.Explained = explainedAll;
					stateRows(end + 1) = st; %#ok<AGROW>

					for zLayer = ["MOp2/3", "MOp5"]
						mask = layers == zLayer;
						if nnz(mask) < 2
							continue;
						end
						[pointsLayer, explainedLayer] = TransferLearningFig341Compat.iSessionPointsFromNtats(X(mask, :, :), idx1s);
						if size(pointsLayer, 1) ~= height(Sm)
							continue;
						end
						[pathLen, directLen, ratioVal, avgStep, effStep] = TransferLearningFig341Compat.iMetricsFromPoints(pointsLayer);
						row = TransferLearningFig341Compat.iEmptyMetricRow();
						row.Mouse = mouseId;
						row.Group = Specs(iSpec).Group;
						row.Source = Specs(iSpec).Source;
						row.ZLayer = zLayer;
						row.NSession = height(Sm);
						row.PathLength = pathLen;
						row.DirectLength = directLen;
						row.PathOverDirect = ratioVal;
						row.AverageStep = avgStep;
						row.EffectiveStep = effStep;
						row.Points = {pointsLayer};
						row.Explained = {explainedLayer};
						metricRows(end + 1) = row; %#ok<AGROW>
					end
				end
			end

			if isempty(stateRows)
				error('Fig341:NoMouseState', 'No mouse-level NTATS state-space data were built.');
			end
			if isempty(metricRows)
				error('Fig341:NoMetrics', 'No layer metrics were built.');
			end

			Metrics = struct2table(metricRows);
			MouseStates = stateRows;
			Rep = TransferLearningFig341Compat.iSelectRepresentatives(MouseStates, idx1s, xsSec);

			Data = struct();
			Data.XsSec = xsSec;
			Data.Index1s = idx1s;
			Data.Sessions = allSessions;
			Data.MouseStates = MouseStates;
			Data.Metrics = Metrics;
			Data.Representative = Rep;
			Data.NormFlag = normFlag;

			Cache = Data;
			CacheNormFlag = normFlag;
		end

		function [f, summaryTbl] = PlotMetricByLayer(Data, metricField, figName, yLabelText, svgName)
			arguments
				Data struct
				metricField (1,1) string
				figName (1,1) string
				yLabelText (1,1) string
				svgName (1,1) string
			end

			palette2 = TransferLearning.FigurePalette(2);
			colorNaive = palette2(1, :);
			colorTransfer = palette2(2, :);

			f = figure('Color', 'w', 'Name', char(figName));
			f.Units = 'centimeters';
			f.Position(3:4) = [3, 4];
			f.PaperUnits = 'centimeters';
			f.PaperPositionMode = 'manual';
			f.PaperPosition = [0, 0, 3, 4];
			f.PaperSize = [3, 4];

			Layout = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
			summaryTbl = table();
			axList = gobjects(2, 1);
			pLineAll = gobjects(0, 1);
			pTextAll = gobjects(0, 1);

			for iLayer = 1:2
				if iLayer == 1
					zLayer = "MOp2/3";
				else
					zLayer = "MOp5";
				end
				M = Data.Metrics(Data.Metrics.ZLayer == zLayer, :);
				naiveVals = double(M.(metricField)(M.Group == "Naive"));
				tranVals = double(M.(metricField)(M.Group == "Transfer"));
				naiveVals = naiveVals(isfinite(naiveVals));
				tranVals = tranVals(isfinite(tranVals));
				if isempty(naiveVals) || isempty(tranVals)
					error('Fig341:EmptyMetricLayer', 'Metric %s for %s is empty.', char(metricField), char(zLayer));
				end

				ax = nexttile(Layout, iLayer);
				axList(iLayer) = ax;
				[~, optional, Bars, ErrorBars] = UniExp.BarScatterCompare({naiveVals, tranVals}, false, table([1 2], 'VariableNames', {'GroupPair'}));
				delete(findobj(ax, 'Type', 'Scatter'));
				for eb = ErrorBars.Object(:)'
					eb.LineWidth = 1;
				end
				ax.FontSize = 6;
				ax.LineWidth = 1;
				ax.FontName = 'Arial';
				ax.TickDir = 'out';
				box(ax, 'off');
				grid(ax, 'off');
				if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
					ax.Toolbar.Visible = 'off';
				end
				ax.XTick = [1 2];
				ax.XTickLabel = {'Naive', 'Transfer'};
				if iLayer == 1
					title(ax, 'MOp2/3', 'FontSize', 6, 'FontWeight', 'normal');
					ax.XAxis.Visible = 'off';
				else
					title(ax, 'MOp5', 'FontSize', 6, 'FontWeight', 'normal');
					ax.XAxis.Visible = 'on';
				end
				xlabel(ax, '');
				for pt = TransferLearningFig341Compat.iFindPText(optional)'
					pt.FontSize = 6;
				end
				[pLineAll, pTextAll] = TransferLearningFig341Compat.iAppendPLineHandles(optional, pLineAll, pTextAll);
				TransferLearningFig341Compat.iStyleBars(Bars, colorNaive, colorTransfer);

				row = table(zLayer, mean(naiveVals), mean(tranVals), numel(naiveVals), numel(tranVals), ...
					'VariableNames', {'ZLayer', 'NaiveMean', 'TransferMean', 'NaiveN', 'TransferN'});
				summaryTbl = [summaryTbl; row]; %#ok<AGROW>
			end

			ylabel(Layout, yLabelText, 'FontSize', 6);
			MATLAB.Graphics.UnifyAxesLims(axList, @ylim);
			if ~isempty(pLineAll) || ~isempty(pTextAll)
				MATLAB.Graphics.PLineRetune(pLineAll, pTextAll);
			end

			outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
			if ~isfolder(outDirUNC)
				mkdir(outDirUNC);
			end
			svgPath = fullfile(outDirUNC, char(svgName));
			TransferLearning.PrintFigure(f, svgPath);
			fprintf('Wrote: %s\n', svgPath);
		end
	end

	methods(Static, Access = private)
		function Sess = iBuildLearningSessionsForSource(spec)
			T = spec.DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Phase", "Behavior", "Performance"]);
			if isempty(T)
				Sess = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), strings(0,1), strings(0,1), false(0,1), ...
					'VariableNames', {'Mouse','DateTime','Performance','Phase','Group','Source','IsMixedAudio'});
				return;
			end

			T.Mouse = string(T.Mouse);
			T.DateTime = TransferLearningFig341Compat.iNormalizeDateTime(T.DateTime);
			T.Stimulus = string(T.Stimulus);
			T.Phase = string(T.Phase);

			[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
			phaseCell = splitapply(@(x) {TransferLearningFig341Compat.iPickSessionPhase(x)}, T.Phase, G);
			phaseVals = string(vertcat(phaseCell{:}));
			nSess = max(G);
			perf = nan(nSess, 1);
			isMixed = false(nSess, 1);

			for gi = 1:nSess
				R = T(G == gi, :);
				if ~any(R.Stimulus == "LightWater")
					continue;
				end
				isMixed(gi) = any(R.Stimulus == "AudioWater");
				lightRows = R(R.Stimulus == "LightWater", :);
				if all(R.Stimulus == "LightWater") && any(isfinite(double(R.Performance)))
					perf(gi) = mean(double(R.Performance), 'omitnan');
				else
					perf(gi) = mean(double(lightRows.Behavior), 'omitnan');
				end
			end

			Sess = table(mouseKeys, dtKeys, perf, phaseVals, repmat(spec.Group, nSess, 1), repmat(spec.Source, nSess, 1), isMixed, ...
				'VariableNames', {'Mouse','DateTime','Performance','Phase','Group','Source','IsMixedAudio'});
			Sess = Sess(isfinite(Sess.Performance), :);
			Sess = sortrows(Sess, {'Mouse', 'DateTime'});
			Sess = TransferLearningFig341Compat.iSelectSessionsBetweenPhases(Sess, spec.StartPhase, spec.EndPhase);
			Sess = Sess(~Sess.IsMixedAudio, :);
			Sess = TransferLearningFig341Compat.iTrimAfterCeilingKeepFirst(Sess);
		end

		function Sess = iSelectSessionsBetweenPhases(Sess, startPhase, endPhase)
			if isempty(Sess)
				return;
			end
			Sess = sortrows(Sess, {'Mouse', 'DateTime'});
			mice = unique(Sess.Mouse);
			keep = false(height(Sess), 1);
			for iMouse = 1:numel(mice)
				idx = find(Sess.Mouse == mice(iMouse));
				ph = Sess.Phase(idx);
				st = find(ph == string(startPhase), 1, 'first');
				if isempty(st)
					continue;
				end
				ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
				if isempty(ed)
					ed = numel(ph);
				end
				keep(idx(st:ed)) = true;
			end
			Sess = Sess(keep, :);
		end

		function Sess = iTrimAfterCeilingKeepFirst(Sess)
			if isempty(Sess)
				return;
			end
			Sess = sortrows(Sess, {'Mouse', 'DateTime'});
			mice = unique(Sess.Mouse);
			keep = false(height(Sess), 1);
			for iMouse = 1:numel(mice)
				idx = find(Sess.Mouse == mice(iMouse));
				p = double(Sess.Performance(idx));
				k = find(isfinite(p) & p >= 1 - 1e-12, 1, 'first');
				if isempty(k)
					keep(idx) = true;
				else
					keep(idx(1:k)) = true;
				end
			end
			Sess = Sess(keep, :);
		end

		function [R, SessKeep] = iQueryMouseNtats(DS, Sess, normFlag)
			Q = Sess(:, {'Mouse', 'DateTime'});
			Q.Stimulus = repmat("LightWater", height(Q), 1);
			Q = Q(:, {'Mouse', 'DateTime', 'Stimulus'});
			R = table();
			SessKeep = Sess;
			try
				raw = DS.QueryNTATS(Q, normFlag, 1:24, UniExp.Flags.Median);
			catch ME
				if ME.identifier ~= "UniExp:Exception:Empty_group"
					rethrow(ME);
				end
				[keepMask, parts] = TransferLearningFig341Compat.iQueryNtatsIgnoringEmptyGroups(DS, Q, normFlag);
				SessKeep = Sess(keepMask, :);
				if height(SessKeep) < 2
					R = table();
					return;
				end
				raw = parts;
			end

			R = TransferLearningFig341Compat.iNtatsResultToTable(raw);
			if isempty(R) || ~ismember('NTATS', string(R.Properties.VariableNames)) || ~ismember('CellUID', string(R.Properties.VariableNames))
				R = table();
				SessKeep = SessKeep([], :);
				return;
			end
			X = TransferLearningFig341Compat.iNtatsTo3D(R.NTATS);
			if isempty(X) || size(X, 3) ~= height(SessKeep)
				R = table();
				SessKeep = SessKeep([], :);
			end
		end

		function [keepMask, parts] = iQueryNtatsIgnoringEmptyGroups(DS, Q, normFlag)
			nGroup = height(Q);
			parts = cell(nGroup, 1);
			keepMask = false(nGroup, 1);
			for iGroup = 1:nGroup
				try
					parts{iGroup} = DS.QueryNTATS(Q(iGroup, :), normFlag, 1:24, UniExp.Flags.Median);
					keepMask(iGroup) = true;
				catch ME
					if ME.identifier ~= "UniExp:Exception:Empty_group"
						rethrow(ME);
					end
				end
			end
			parts = parts(keepMask);
		end

		function R = iNtatsResultToTable(raw)
			R = table();
			if isempty(raw)
				return;
			end
			S = UniExp.NtatsCellStrip(raw);
			if isempty(S) || ~istable(S) || ~all(ismember({'CellUID','NTATS'}, string(S.Properties.VariableNames)))
				return;
			end
			X = TransferLearningFig341Compat.iNtatsTo3D(S.NTATS);
			if isempty(X)
				return;
			end
			R = table(uint64(S.CellUID), MATLAB.DataTypes.NDTable(X), 'VariableNames', {'CellUID','NTATS'});
		end

		function X = iNtatsTo3D(nt)
			X = [];
			if isa(nt, 'MATLAB.DataTypes.NDTable')
				X = nt{:,:,:};
				if ismatrix(X)
					X = reshape(X, size(X, 1), size(X, 2), 1);
				end
				return;
			end
			if isnumeric(nt)
				X = double(nt);
				if ismatrix(X)
					X = reshape(X, size(X, 1), size(X, 2), 1);
				end
				return;
			end
			if istable(nt) && ismember('NTATS', nt.Properties.VariableNames)
				X = TransferLearningFig341Compat.iNtatsTo3D(nt.NTATS);
				return;
			end
			if iscell(nt)
				if isempty(nt)
					return;
				end
				parts = cellfun(@TransferLearningFig341Compat.iNtatsCellToMatrix, nt, 'UniformOutput', false);
				if any(cellfun(@isempty, parts))
					return;
				end
				nCell = size(parts{1}, 1);
				nTime = size(parts{1}, 2);
				X = nan(nCell, nTime, numel(parts));
				for i = 1:numel(parts)
					if ~isequal(size(parts{i}), [nCell, nTime])
						X = [];
						return;
					end
					X(:, :, i) = parts{i};
				end
			end
		end

		function X = iNtatsCellToMatrix(nt)
			X = [];
			if isa(nt, 'MATLAB.DataTypes.NDTable')
				X = nt{:,:};
				return;
			end
			if isnumeric(nt)
				X = double(nt);
				return;
			end
			if istable(nt) && ismember('NTATS', nt.Properties.VariableNames)
				X = TransferLearningFig341Compat.iNtatsCellToMatrix(nt.NTATS);
				return;
			end
			if iscell(nt)
				if isempty(nt)
					return;
				end
				rows = cellfun(@TransferLearningFig341Compat.iOneNtatsRow, nt, 'UniformOutput', false);
				if any(cellfun(@isempty, rows))
					return;
				end
				X = vertcat(rows{:});
			end
		end

		function row = iOneNtatsRow(one)
			row = [];
			if isa(one, 'MATLAB.DataTypes.NDTable')
				row = one{:,:};
				return;
			end
			if isnumeric(one)
				row = double(one);
			end
		end

		function layers = iLookupLayers(DS, cellUID)
			C = DS.Cells(:, intersect(["CellUID", "ZLayer"], string(DS.Cells.Properties.VariableNames), 'stable'));
			if ~all(ismember(["CellUID", "ZLayer"], string(C.Properties.VariableNames)))
				error('Fig341:MissingLayerMeta', 'Cells table for %s lacks CellUID/ZLayer.', class(DS));
			end
			C.CellUID = uint64(C.CellUID);
			C.ZLayer = string(C.ZLayer);
			[tf, loc] = ismember(cellUID, C.CellUID);
			layers = strings(size(cellUID));
			layers(tf) = C.ZLayer(loc(tf));
		end

		function [points, explained] = iSessionPointsFromNtats(X, idx1s)
			if isempty(X)
				points = nan(0, 2);
				explained = [NaN NaN];
				return;
			end
			if ndims(X) == 2
				X = reshape(X, size(X, 1), size(X, 2), 1);
			end
			if idx1s > size(X, 2)
				points = nan(size(X, 3), 2);
				explained = [NaN NaN];
				return;
			end
			vals = squeeze(X(:, idx1s, :));
			if isa(vals, 'MATLAB.DataTypes.NDTable')
				vals = double(vals.Data);
			end
			if isvector(vals)
				vals = reshape(vals, size(X, 1), size(X, 3));
			end
			sessionByCell = vals';
			validCols = all(isfinite(sessionByCell), 1);
			sessionByCell = sessionByCell(:, validCols);
			if size(sessionByCell, 2) < 1 || size(sessionByCell, 1) < 2
				points = nan(size(X, 3), 2);
				explained = [NaN NaN];
				return;
			end
			sessionByCell = sessionByCell - mean(sessionByCell, 1, 'omitnan');
			[u, s, ~] = svd(sessionByCell, 'econ');
			score = u * s;
			latent = diag(s).^2;
			if numel(latent) >= 1 && sum(latent) > 0
				explAll = latent ./ sum(latent) * 100;
			else
				explAll = NaN(size(latent));
			end
			points = zeros(size(sessionByCell, 1), 2);
			points(:, 1:min(2, size(score, 2))) = score(:, 1:min(2, size(score, 2)));
			explained = nan(1, 2);
			explained(1:min(2, numel(explAll))) = explAll(1:min(2, numel(explAll)));
		end

		function [pathLen, directLen, ratioVal, avgStep, effStep] = iMetricsFromPoints(points)
			dp = diff(points, 1, 1);
			stepLens = sqrt(sum(dp.^2, 2));
			pathLen = sum(stepLens, 'omitnan');
			directLen = sqrt(sum((points(end, :) - points(1, :)).^2, 2));
			if isfinite(pathLen) && isfinite(directLen) && directLen > 0
				ratioVal = pathLen / directLen;
			else
				ratioVal = NaN;
			end
			nStep = size(points, 1) - 1;
			if nStep >= 1
				avgStep = pathLen / nStep;
				effStep = directLen / nStep;
			else
				avgStep = NaN;
				effStep = NaN;
			end
		end

		function Rep = iSelectRepresentatives(MouseStates, idx1s, xsSec)
			naiveRows = MouseStates(string({MouseStates.Group})' == "Naive");
			transferRows = MouseStates(string({MouseStates.Group})' == "Transfer");

			naiveHasSetback = arrayfun(@(s) height(s.SessionTable) >= 6 && TransferLearningFig341Compat.iHasBehaviorSetback(s.SessionTable.Performance), naiveRows);
			naiveN = arrayfun(@(s) height(s.SessionTable), naiveRows);
			minNaiveN = min(naiveN(naiveHasSetback), [], 'omitnan');
			if ~isfinite(minNaiveN)
				error('Fig341:NoNaiveMouseSetback', 'No Naive mouse reaches criterion with at least 6 sessions and a behavioral setback.');
			end

			bestNaiveScore = -inf;
			bestNaiveMouse = TransferLearningFig341Compat.iEmptyMouseState();
			bestNaiveCellUID = uint64(0);
			bestNaiveSignals = [];
			for i = 1:numel(naiveRows)
				st = naiveRows(i);
				if ~naiveHasSetback(i) || height(st.SessionTable) ~= minNaiveN
					continue;
				end
				vals = squeeze(st.NTATS(:, idx1s, :));
				if isvector(vals)
					vals = reshape(vals, size(st.NTATS, 1), size(st.NTATS, 3));
				end
				peakBeforeCeilingMask = TransferLearningFig341Compat.iNaivePeakBeforeLastCeiling(vals, st.SessionTable.Performance);
				extremeMask = max(vals, [], 2) > 1 & min(vals, [], 2) < -1;
				candidateMask = peakBeforeCeilingMask & extremeMask;
				if ~any(candidateMask)
					continue;
				end
				rangeVal = max(vals, [], 2) - min(vals, [], 2);
				rangeVal(~candidateMask) = -inf;
				[cScore, cIdx] = max(rangeVal);
				if isfinite(cScore) && cScore > bestNaiveScore
					bestNaiveScore = cScore;
					bestNaiveMouse = st;
					bestNaiveCellUID = st.CellUID(cIdx);
					bestNaiveSignals = squeeze(st.NTATS(cIdx, :, :))';
				end
			end

			transferIsIncreasing = arrayfun(@(s) height(s.SessionTable) >= 3 && TransferLearningFig341Compat.iIsStrictlyIncreasing(s.SessionTable.Performance), transferRows);
			transferN = arrayfun(@(s) height(s.SessionTable), transferRows);
			minTransferN = min(transferN(transferIsIncreasing), [], 'omitnan');
			if ~isfinite(minTransferN)
				error('Fig341:NoTransferMouseIncreasing', 'No Transfer mouse reaches criterion with at least 3 sessions and strictly increasing behavior.');
			end

			bestTransferScore = -inf;
			bestTransferMouse = TransferLearningFig341Compat.iEmptyMouseState();
			bestTransferCellUID = uint64(0);
			bestTransferSignals = [];
			for i = 1:numel(transferRows)
				st = transferRows(i);
				if ~transferIsIncreasing(i) || height(st.SessionTable) ~= minTransferN
					continue;
				end
				vals = squeeze(st.NTATS(:, idx1s, :));
				if isvector(vals)
					vals = reshape(vals, size(st.NTATS, 1), size(st.NTATS, 3));
				end
				monoMask = all(diff(vals, 1, 2) > 0, 2);
				if ~any(monoMask)
					continue;
				end
				inc = vals(:, end) - vals(:, 1);
				inc(~monoMask) = -inf;
				[cScore, cIdx] = max(inc);
				if isfinite(cScore) && cScore > bestTransferScore
					bestTransferScore = cScore;
					bestTransferMouse = st;
					bestTransferCellUID = st.CellUID(cIdx);
					bestTransferSignals = squeeze(st.NTATS(cIdx, :, :))';
				end
			end

			if bestNaiveCellUID == 0 || bestTransferCellUID == 0
				error('Fig341:NoRepresentative', 'Cannot find representative Naive/Transfer cell pair for panel A.');
			end

			Rep = struct();
			Rep.NaiveCell = struct('Mouse', bestNaiveMouse.Mouse, 'Source', bestNaiveMouse.Source, 'CellUID', bestNaiveCellUID, ...
				'SessionTable', bestNaiveMouse.SessionTable, 'Signals', bestNaiveSignals, 'Points', bestNaiveMouse.Points, 'Explained', bestNaiveMouse.Explained);
			Rep.TransferCell = struct('Mouse', bestTransferMouse.Mouse, 'Source', bestTransferMouse.Source, 'CellUID', bestTransferCellUID, ...
				'SessionTable', bestTransferMouse.SessionTable, 'Signals', bestTransferSignals, 'Points', bestTransferMouse.Points, 'Explained', bestTransferMouse.Explained);
			Rep.XsSec = xsSec;
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

		function dt = iNormalizeDateTime(dt)
			dt = datetime(dt);
			if isdatetime(dt) && ~isempty(dt.TimeZone)
				dt.TimeZone = '';
			end
		end

		function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
			[d, idx] = min(abs(xsSec - targetSec));
			ok = isfinite(d) && d <= tolSec;
		end

		function tf = iHasBehaviorSetback(performance)
			perf = double(performance(:));
			perf = perf(isfinite(perf));
			tf = numel(perf) >= 2 && any(diff(perf) < 0);
		end

		function mask = iNaivePeakBeforeLastCeiling(vals, performance)
			if isempty(vals)
				mask = false(0, 1);
				return;
			end
			perf = double(performance(:));
			nCell = size(vals, 1);
			nSess = size(vals, 2);
			mask = true(nCell, 1);
			if numel(perf) ~= nSess || nSess < 2 || ~isfinite(perf(end)) || perf(end) < 1
				return;
			end
			globalMax = max(vals, [], 2);
			prevMax = max(vals(:, 1:end-1), [], 2);
			tol = 1e-9;
			mask = prevMax >= (globalMax - tol);
		end

		function tf = iIsStrictlyIncreasing(values)
			vals = double(values(:));
			if numel(vals) < 2 || any(~isfinite(vals))
				tf = false;
				return;
			end
			tf = all(diff(vals) > 0);
		end

		function row = iEmptyMetricRow()
			row = builtin('struct', 'Mouse', "", 'Group', "", 'Source', "", 'ZLayer', "", 'NSession', NaN, ...
				'PathLength', NaN, 'DirectLength', NaN, 'PathOverDirect', NaN, 'AverageStep', NaN, 'EffectiveStep', NaN, ...
				'Points', {zeros(0, 2)}, 'Explained', {nan(1, 2)});
		end

		function st = iEmptyMouseState()
			st = builtin('struct', 'Mouse', "", 'Group', "", 'Source', "", 'SessionTable', table(), 'CellUID', uint64([]), ...
				'Layers', strings(0,1), 'NTATS', zeros(0, 0, 0), 'Points', zeros(0, 2), 'Explained', nan(1, 2));
		end

		function iAssertNoCrossSourceDuplicateMice(T, groupName)
			if isempty(T)
				return;
			end
			U = unique(T(:, {'Mouse', 'Source'}));
			[mice, ~, g] = unique(U.Mouse);
			nSrc = splitapply(@(x) numel(unique(x)), U.Source, g);
			bad = mice(nSrc > 1);
			if ~isempty(bad)
				error('Fig341:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.', char(string(groupName)));
			end
		end

		function iAssertNoMouseAppearsInMultipleGroups(T)
			if isempty(T)
				return;
			end
			[mice, ~, g] = unique(T.Mouse);
			nGrp = splitapply(@(x) numel(unique(x)), T.Group, g);
			bad = mice(nGrp > 1);
			if ~isempty(bad)
				error('Fig341:MouseInMultipleGroups', 'Some mice appear in multiple groups.');
			end
		end

		function pText = iFindPText(optional)
			pText = gobjects(0, 1);
			if isstruct(optional) && isfield(optional, 'MultiCompare') && istable(optional.MultiCompare) && ismember('PText', optional.MultiCompare.Properties.VariableNames)
				pText = optional.MultiCompare.PText;
			end
		end

		function iStyleBars(Bars, colorNaive, colorTransfer)
			if isscalar(Bars)
				Bars.FaceColor = 'flat';
				nBar = numel(Bars.YData);
				Bars.CData = repmat([colorNaive; colorTransfer], ceil(nBar / 2), 1);
				Bars.CData = Bars.CData(1:nBar, :);
				Bars.BarWidth = 0.5;
				Bars.LineWidth = 1;
				Bars.EdgeColor = 'none';
				if isprop(Bars, 'BaseLine') && isgraphics(Bars.BaseLine)
					Bars.BaseLine.LineWidth = 1;
				end
				try
					Bars.FaceAlpha = 1/3;
				catch
				end
			else
				if numel(Bars) >= 2
					Bars(1).FaceColor = colorNaive;
					Bars(2).FaceColor = colorTransfer;
					for B = Bars(:)'
						B.LineWidth = 1;
						B.EdgeColor = 'none';
						if isprop(B, 'BaseLine') && isgraphics(B.BaseLine)
							B.BaseLine.LineWidth = 1;
						end
					end
					try
						Bars(1).FaceAlpha = 1/3;
						Bars(2).FaceAlpha = 1/3;
					catch
					end
				end
			end
		end

		function [pLineAll, pTextAll] = iAppendPLineHandles(optional, pLineAll, pTextAll)
			if ~isstruct(optional) || ~isfield(optional, 'MultiCompare') || ~istable(optional.MultiCompare)
				return;
			end
			mc = optional.MultiCompare;
			if ismember('PLine', mc.Properties.VariableNames)
				pLine = mc.PLine;
				pLine = pLine(isgraphics(pLine));
				for pl = pLine(:)'
					pl.LineWidth = 1;
				end
				if ~isempty(pLine)
					pLineAll(end+1:end+numel(pLine), 1) = pLine(:); %#ok<AGROW>
				end
			end
			if ismember('PText', mc.Properties.VariableNames)
				pText = mc.PText;
				pText = pText(isgraphics(pText));
				if ~isempty(pText)
					pTextAll(end+1:end+numel(pText), 1) = pText(:); %#ok<AGROW>
				end
			end
		end
	end
end