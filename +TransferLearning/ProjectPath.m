function PP = ProjectPath
persistent Cache
if isempty(Cache)
	Cache=fileparts(fileparts(mfilename('fullpath')));
end
PP=Cache;