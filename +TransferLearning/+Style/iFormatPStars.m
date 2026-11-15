function pStr = iFormatPStars(pValue)
% 显著性标记（bar 图 P 值文字用）：只给显著性上星，不显著写 n.s.
%   **** p<1e-4   *** p<0.001   ** p<0.01   * p<0.05   其余 n.s.
% 与 iFormatPText（写具体 p 值）并存，避免改动其余 70+ 张图的既有输出。
if nargin < 1 || ~isfinite(pValue)
	pStr = "";
	return;
end
if pValue < 1e-4
	pStr = "****";
elseif pValue < 1e-3
	pStr = "***";
elseif pValue < 1e-2
	pStr = "**";
elseif pValue < 0.05
	pStr = "*";
else
	pStr = "n.s.";
end
end
