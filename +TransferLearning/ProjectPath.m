function PP = ProjectPath(varargin)
persistent Cache
if isempty(Cache)
	Cache=fileparts(fileparts(mfilename('fullpath')));
end
PP=fullfile(Cache,varargin{:});