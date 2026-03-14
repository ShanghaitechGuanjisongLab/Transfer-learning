Image=single(gpuArray(Image5D.OirReader(TransferLearning.ProjectPath('+TransferLearning\英文图2\vtf1011.202512011016.Reference.3%16%.oir')).ReadPixels)).^(1/2);
Image(:,:,2,:)=Image;
Image(:,:,[1,3],:)=0;
imwrite(rescale(Image(:,:,:,1)),'\\Data-Server-2\个人数据\张天夫\202602\图2E.2层.png');
imwrite(rescale(Image(:,:,:,2)),'\\Data-Server-2\个人数据\张天夫\202602\图2E.5层.png');

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
