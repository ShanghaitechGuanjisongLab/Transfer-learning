function tf = UseGPU()
deviceManager = parallel.gpu.GPUDeviceManager.instance;
tf = ~isempty(deviceManager.SelectedDevice);
end
