function PrepareOfficialMNIST()
dataRoot = "D:\训练数据";
rawDir = fullfile(dataRoot, "raw", "mnist");
if ~isfolder(rawDir)
    mkdir(rawDir);
end

baseUrl = "https://storage.googleapis.com/cvdf-datasets/mnist/";
files = ["train-images-idx3-ubyte.gz", "train-labels-idx1-ubyte.gz", ...
         "t10k-images-idx3-ubyte.gz", "t10k-labels-idx1-ubyte.gz"];

for f = files
    gzPath = fullfile(rawDir, f);
    rawPath = strrep(gzPath, ".gz", "");

    if ~isfile(rawPath)
        if ~isfile(gzPath)
            fprintf("Downloading %s...\n", f);
            websave(gzPath, baseUrl + f);
        end
        fprintf("Extracting %s...\n", f);
        gunzip(gzPath, rawDir);
    end
end

disp("MNIST dataset ready.");
end
