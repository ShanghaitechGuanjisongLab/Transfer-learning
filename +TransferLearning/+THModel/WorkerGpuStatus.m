function Status = WorkerGpuStatus()
pool = gcp('nocreate');
if isempty(pool)
	Status = table(0, gpuDeviceCount, false, NaN, string(missing), ...
		'VariableNames', {'Worker','GpuDeviceCount','UseGPU','GPUIndex','GPUName'});
	return;
end

spmd
	usesGpu = TransferLearning.THModel.UseGPU();
	gpuIndex = NaN;
	gpuName = string(missing);
	if usesGpu
		device = gpuDevice;
		gpuIndex = device.Index;
		gpuName = string(device.Name);
	end
	workerStatus = table(spmdIndex, gpuDeviceCount, usesGpu, gpuIndex, gpuName, ...
		'VariableNames', {'Worker','GpuDeviceCount','UseGPU','GPUIndex','GPUName'});
end

statusCells = cell(pool.NumWorkers, 1);
for iWorker = 1:pool.NumWorkers
	statusCells{iWorker} = workerStatus{iWorker};
end
Status = vertcat(statusCells{:});
end