function safe_evaluate(code, project_path)
% safe_evaluate - 带安全过滤的 MATLAB 代码评估
%   先通过 FilterEvaluate 审查代码，批准后才执行。
%   通过 --extension-file 注册为 MCP 工具后，
%   在 VS Code 工具权限中禁用内置 evaluate_matlab_code，
%   即可使此函数成为 Agent 通往 MATLAB 的唯一路径。
%
%   Input:
%       code         - 字符串，要执行的 MATLAB 代码
%       project_path - （可选）字符串，设置当前工作目录

    arguments
        code(1,1) string
        project_path(1,1) string = ""
    end

    % 1. 设置工作目录
    if strlength(project_path) > 0
        try
            cd(project_path);
        catch ME
            fprintf('Error changing to project folder: %s\n', ME.message);
        end
    end

    % 2. 过滤审查
    [Approved, Comment] = FilterEvaluate(code);

    if ~Approved
        fprintf('%s\n', Comment);
        return;
    end

    % 3. 批准后执行
    try
        evalin('base', code);
    catch ME
        fprintf('Error executing code: %s\n', ME.message);
    end
end
