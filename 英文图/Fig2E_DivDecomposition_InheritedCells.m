Image=single(gpuArray(Image5D.OirReader(TransferLearning.ProjectPath('英文图\英文图2\vtf1011.202512011016.Reference.3%16%.oir')).ReadPixels)).^(1/2);
Image(:,:,2,:)=Image;
Image(:,:,[1,3],:)=0;
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
imwrite(rescale(Image(:,:,:,1)), fullfile(outDirUNC, '图2E.2层.png'));
imwrite(rescale(Image(:,:,:,2)), fullfile(outDirUNC, '图2E.5层.png'));

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
