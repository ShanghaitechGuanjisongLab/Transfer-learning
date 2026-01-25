function Run_B_MOpVsMCherry
% Run_B_MOpVsMCherry 以“函数调用”方式执行脚本 B_MOpVsMCherry。
% - B_MOpVsMCherry.m 必须是脚本（不得写成函数）
% - 不使用 run
% - 通过读取脚本文本并 evalin('base', ...) 执行（脚本内不得包含 local functions）

scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(scriptDir));
scriptPath = fullfile(scriptDir, 'B_MOpVsMCherry.m');

oldDir = pwd;
cleanupObj = onCleanup(@() cd(oldDir));
cd(rootDir);

code = fileread(scriptPath);

% 防御性去除 UTF-8 BOM（避免使用 if/end 块，提升兼容性）
code = regexprep(code, '^\x{FEFF}', '');

% 规范化换行符：避免 evalin 解析 CRLF/CR 时出现 block/end 匹配错误
code = strrep(code, sprintf('\r\n'), sprintf('\n'));
code = strrep(code, sprintf('\r'),   sprintf('\n'));

evalin('base', code);

