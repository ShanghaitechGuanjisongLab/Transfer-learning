function values = Zeros(sz)
if isscalar(sz)
	sz = [sz, 1];
end
if TransferLearning.THModel.UseGPU()
	values = gpuArray.zeros(sz(1), sz(2));
else
	values = zeros(sz);
end
end
