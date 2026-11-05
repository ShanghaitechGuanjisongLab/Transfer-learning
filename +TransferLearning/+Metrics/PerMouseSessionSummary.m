function T = PerMouseSessionSummary(sessions)
%PERMOUSESESSIONSSUMMARY 每只鼠的首会话命中率与达到 50% 所需会话数
%
%   T = TransferLearning.Metrics.PerMouseSessionSummary(sessions)
%
%   sessions：table，需含 Group、Mouse、DateTime、Performance（会话级，一行一个会话）。
%   达到 50% 用相邻两点线性插值；末次仍未达到者记为 max(Session)+1。
%
%   输出 T：Group | Mouse | FirstPerf | BlocksToHalf | NSessions

arguments
	sessions table
end

S = sessions(:, {'Group','Mouse','DateTime','Performance'});
S.Group = string(S.Group);
S.Mouse = string(S.Mouse);
S.DateTime = datetime(S.DateTime);
if ~isempty(S.DateTime.TimeZone)
	S.DateTime.TimeZone = '';
end
S = sortrows(S, {'Group','Mouse','DateTime'});

groups = unique(S.Group, 'stable');
rows = cell(0, 5);
for g = 1:numel(groups)
	R = S(S.Group == groups(g), :);
	mice = unique(R.Mouse, 'stable');
	for i = 1:numel(mice)
		M = R(R.Mouse == mice(i), :);
		y = double(M.Performance);
		x = (1:numel(y))';
		use = isfinite(y);
		y = y(use);
		x = x(use);
		if isempty(y)
			continue;
		end
		ic = find(y >= 0.5, 1, 'first');
		if isempty(ic)
			half = max(x) + 1;
		elseif ic == 1
			half = x(1);
		else
			half = x(ic - 1) + (0.5 - y(ic - 1)) / (y(ic) - y(ic - 1));
		end
		rows(end+1, :) = {groups(g), mice(i), y(1), half, numel(y)}; %#ok<AGROW>
	end
end

T = cell2table(rows, 'VariableNames', {'Group','Mouse','FirstPerf','BlocksToHalf','NSessions'});
T.Group = string(T.Group);
T.Mouse = string(T.Mouse);
T.FirstPerf = double(T.FirstPerf);
T.BlocksToHalf = double(T.BlocksToHalf);
T.NSessions = double(T.NSessions);
end
