function PrepareOfficialCIFAR10TaskAB()
dataRoot = "D:\训练数据";
rawDir = fullfile(dataRoot, "raw", "cifar10");
if ~isfolder(rawDir)
    mkdir(rawDir);
end

url = "https://cave.cs.toronto.edu/kriz/cifar-10-matlab.tar.gz";
archivePath = fullfile(rawDir, "cifar-10-matlab.tar.gz");
extractDir = fullfile(rawDir, "cifar-10-batches-mat");

if ~isfile(archivePath)
    fprintf("Downloading CIFAR-10 archive with progress...\n");
    downloadCmd = sprintf('curl -L --progress-bar -o "%s" "%s"', archivePath, url);
    [status, cmdout] = system(downloadCmd);
    if strlength(string(cmdout)) > 0
        fprintf("%s\n", cmdout);
    end
    assert(status == 0, "Download failed. Please check network and retry.");
end

if ~isfolder(extractDir)
    untar(archivePath, rawDir);
end

meta = load(fullfile(extractDir, "batches.meta.mat"));
classNames = string(meta.label_names);
disp("CIFAR-10 archive is ready for in-memory training.");
disp("Extract directory:");
disp(extractDir);
disp("Class names:");
disp(classNames');
end
