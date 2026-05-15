function values = GatherValue(values)
if isa(values, 'gpuArray')
	values = gather(values);
end
end
