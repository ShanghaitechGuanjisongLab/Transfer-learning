# Copilot instructions for this workspace

## MATLAB execution policy (strict)

- NEVER run MATLAB through terminal commands such as:
  - `matlab -batch ...`
  - `matlab -r ...`
  - any `run_in_terminal` call that invokes `matlab`
- ALWAYS use MATLAB MCP tools instead:
  - `mcp_mcp-wrapper_matlabRemote_run_matlab_file`
  - `mcp_mcp-wrapper_matlabRemote_evaluate_matlab_code`
  - `mcp_mcp-wrapper_matlabRemote_check_matlab_code`
  - `mcp_mcp-wrapper_matlabRemote_run_matlab_test_file`
- If MATLAB MCP is unavailable, STOP and ask the user instead of falling back to terminal MATLAB.

## Safety fallback

- Do not bypass this policy unless the user explicitly asks to disable it for the current task.
