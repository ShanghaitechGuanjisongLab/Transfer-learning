function values = Randn(sz)
if isscalar(sz)
	sz = [sz, 1];
end
if TransferLearning.THModel.UseGPU()
	values = gpuArray.randn(sz(1), sz(2));
else
	values = randn(sz);
end
end
