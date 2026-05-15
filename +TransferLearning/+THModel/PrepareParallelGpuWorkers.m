function pool = PrepareParallelGpuWorkers(numWorkers, numGpuWorkers)
hasRequestedWorkerCount = nargin >= 1 && ~isempty(numWorkers);
if nargin < 1 || isempty(numWorkers)
	pool = gcp('nocreate');
	if isempty(pool)
		numWorkers = max(1, feature('numcores'));
	end
end
if nargin < 2 || isempty(numGpuWorkers)
	numGpuWorkers = 0;
end

pool = gcp('nocreate');
if ~isempty(which('ParallelComputing.ParPool'))
	if hasRequestedWorkerCount || isempty(pool)
		ParallelComputing.ParPool(numWorkers);
		pool = gcp('nocreate');
	end
elseif hasRequestedWorkerCount && ~isempty(pool) && pool.NumWorkers ~= numWorkers
	delete(pool);
	pool = [];
end

if isempty(pool)
	parpool('local', numWorkers);
	pool = gcp('nocreate');
end

spmd
	assignedGpuDeviceCount = min(numGpuWorkers, gpuDeviceCount);
	if spmdIndex <= assignedGpuDeviceCount
		gpuDevice(spmdIndex);
	else
		gpuDevice([]);
	end
end
end