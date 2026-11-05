function p = LocalCachePath(path)
%LOCALCACHEPATH 网络数据路径不可用时回退到 UniExp.DataSet 的本地缓存副本
%
%   p = TransferLearning.LocalCachePath(path)
%
%   UniExp.DataSet 构造时会把 \\ 开头的网络文件复制到 tempdir 再加载，
%   因此本地 tempdir 中常留有同名副本。服务器目录被清理后，可用此函数
%   让分析脚本继续运行。
%
%   行为：
%     1. 网络路径存在 -> 原样返回；
%     2. 不存在但 tempdir 有同名文件 -> 返回本地副本并给出 warning；
%     3. 都不存在 -> 报错。
%
%   注意：tempdir 可能被系统清理，重要数据应另存到稳定位置。

arguments
	path {mustBeTextScalar}
end

p = char(string(path));
if exist(p, 'file') == 2
	return;
end

[~, name, ext] = fileparts(p);
candidate = char(fullfile(tempdir, string(name) + string(ext)));
if exist(candidate, 'file') == 2
	warning('TransferLearning:LocalCachePath:Fallback', ...
		'Network data unavailable, falling back to local cache copy:\n  requested: %s\n  using    : %s', p, candidate);
	p = candidate;
	return;
end

error('TransferLearning:LocalCachePath:Missing', ...
	'Data file found neither on the server nor in the local cache:\n  %s', p);
end
