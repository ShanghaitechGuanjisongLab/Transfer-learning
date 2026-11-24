% 探针：12 h vs 7 d 的散度（Divergence）按层（MOp2/3、MOp5）拆分是否有显著性
%
% 口径与 英文图/Fig2F_Undelayed_DivergenceBarsByLayer.m、Fig1E 完全一致：
%   会话 = 各队列【首个 Transfer 期的 LightWater 会话】
%   散度 div = sqrt( sum(var(X,[],2)) / sum(mean(X,2).^2) )，X = cue+1 s 的 细胞×回合 矩阵
%   每层独立计算，要求该层细胞数 >= 3
%   每鼠一个值（同鼠多会话取均值，这里只有 1 个会话）
%
% 只打印统计结果，不出图。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
if ~any(strcmpi(strsplit(path, pathsep), 'd:\git\Transfer-Learning'))
	addpath('d:\git\Transfer-Learning');
end
warning('off', 'UniExp:Exception:Block_must_warn');

cohNames = ["12 h", "7 d"];
DS12 = TransferLearning.AudioLightBaseline();
DS7 = TransferLearning.Vacation7();

idxT = iFindTimeIndex(1.0);
D = cell(1, 2);
for k = 1:2
	if k == 1
		DS = DS12;
	else
		DS = DS7;
	end
	sess = iFirstTransferLWSessions(DS);
	rows = iSessionDivergenceByLayer(sess, "LightWater", idxT);
	D{k} = iCollapseByMouse(rows);
	fprintf('%s：%d 只鼠有散度\n', cohNames(k), height(D{k}));
end

fprintf('\n=== 12 h vs 7 d 散度（首个 Transfer 光水会话，cue+1 s）===\n');
for fld = ["DivL23", "DivL5"]
	a = D{1}.(fld);
	b = D{2}.(fld);
	a = a(isfinite(a));
	b = b(isfinite(b));
	if numel(a) < 2 || numel(b) < 2
		fprintf('%s：样本不足\n', fld);
		continue;
	end
	[pRank, ~] = TransferLearning.BehaviorSessions.iRanksumSafe(a, b);
	fprintf('%-8s 12h %.3f ± %.3f (n=%d) | 7d %.3f ± %.3f (n=%d) | ranksum p = %.4g\n', ...
		fld, mean(a), iSEM(a), numel(a), mean(b), iSEM(b), numel(b), pRank);
end

% 层内配对（同一批鼠的 L2/3 vs L5），仅作参考
for k = 1:2
	a = D{k}.DivL23;
	b = D{k}.DivL5;
	ok = isfinite(a) & isfinite(b);
	if nnz(ok) >= 3
		p = signrank(a(ok), b(ok));
		fprintf('%s 层内 L2/3 vs L5（配对 signrank, n=%d）：p = %.4g\n', cohNames(k), nnz(ok), p);
	end
end

assignin('base', 'Div12hVs7d_ByLayer', D);

%% ========== 局部函数（与 Fig2F 完全一致）==========
function rows = iSessionDivergenceByLayer(sessTable, stimNames, idxT)
rows = table(strings(0, 1), nan(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
for iS = 1:height(sessTable)
	DS = sessTable.DS(iS);
	m = sessTable.Mouse(iS);
	dt = sessTable.DateTime(iS);
	ntsCell = DS.QueryNTS(struct('Stimulus', stimNames, 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
	if isempty(nts)
		continue;
	end
	trialUIDs = unique(uint64(nts.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	[CTT, cellUIDs] = iBuildCtt(nts, trialUIDs);
	if isempty(CTT) || size(CTT, 1) < 3
		continue;
	end
	X = CTT(:, :, idxT);
	CellTbl = DS.Cells;
	CellTbl.CellUID = uint64(CellTbl.CellUID);
	CellTbl.Mouse = string(CellTbl.Mouse);
	CellTbl.ZLayer = string(CellTbl.ZLayer);
	cellMeta = CellTbl(CellTbl.Mouse == m, {'CellUID', 'ZLayer'});
	[tf, loc] = ismember(cellUIDs, cellMeta.CellUID);
	layers = strings(numel(cellUIDs), 1);
	layers(tf) = cellMeta.ZLayer(loc(tf));
	mask23 = layers == "MOp2/3";
	mask5 = layers == "MOp5";
	d23 = NaN;
	d5 = NaN;
	if sum(mask23) >= 3
		d23 = iDivFromX(X(mask23, :));
	end
	if sum(mask5) >= 3
		d5 = iDivFromX(X(mask5, :));
	end
	rows = [rows; table(string(m), d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'})]; %#ok<AGROW>
end
end

function [CTT, cellUIDs] = iBuildCtt(nts, trialUIDs)
allCells = unique(uint64(nts.CellUID));
traces = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iC = 1:numel(allCells)
	cid = allCells(iC);
	rowsC = uint64(nts.CellUID) == cid;
	uid = uint64(nts.TrialUID(rowsC));
	sig = double(nts.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue;
	end
	so = sig(loc, :);
	if any(~isfinite(so), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traces{nKeep} = so;
	keepUID(nKeep) = cid;
end
if nKeep < 3
	CTT = [];
	cellUIDs = uint64([]);
	return;
end
traces = traces(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = numel(trialUIDs);
nTime = size(traces{1}, 2);
CTT = nan(nKeep, nTrial, nTime);
for iC = 1:nKeep
	CTT(iC, :, :) = reshape(traces{iC}, 1, nTrial, nTime);
end
end

function div = iDivFromX(X)
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function rows = iCollapseByMouse(rows)
if isempty(rows)
	return;
end
[G, mouseU] = findgroups(rows.Mouse);
d23 = splitapply(@(v) mean(v, 'omitnan'), rows.DivL23, G);
d5 = splitapply(@(v) mean(v, 'omitnan'), rows.DivL5, G);
rows = table(mouseU, d23, d5, 'VariableNames', {'Mouse', 'DivL23', 'DivL5'});
end

function idx = iFindTimeIndex(targetSec)
xsSec = seconds(TransferLearning.Xs);
[~, idx] = min(abs(xsSec(:) - targetSec));
end

function sess = iFirstTransferLWSessions(DS)
sess = iEmptySessTable(DS);
T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex", "Behavior", "Stimulus"], Phase = "Transfer");
if isempty(T)
	return;
end
T = iTidyTrialTable(T);
T = T(T.Stimulus == "LightWater", :);
mice = unique(T.Mouse);
for i = 1:numel(mice)
	Tm = T(T.Mouse == mice(i), :);
	sess = [sess; table(DS, mice(i), min(Tm.DateTime), 'VariableNames', {'DS', 'Mouse', 'DateTime'})]; %#ok<AGROW>
end
end

function sess = iEmptySessTable(DS)
sess = table(repmat(DS, 0, 1), strings(0, 1), NaT(0, 1), 'VariableNames', {'DS', 'Mouse', 'DateTime'});
end

function T = iTidyTrialTable(T)
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
if ismember('Phase', T.Properties.VariableNames)
	T.Phase = string(T.Phase);
end
T.DateTime = datetime(T.DateTime);
if ~isempty(T.DateTime.TimeZone)
	T.DateTime.TimeZone = '';
end
end

function s = iSEM(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
	s = NaN;
else
	s = std(x) / sqrt(numel(x));
end
end
