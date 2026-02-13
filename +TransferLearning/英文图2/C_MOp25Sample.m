Images=uint8(rescale(sqrt(single(Image5D.OirReader('C:\Users\vhtmf\Documents\MATLAB\Transfer-learning\+TransferLearning\英文图2\vtf1011.202512011016.Reference.3%16%.oir').ReadPixels)),0,255));
Images(:,:,3,:)=0;
Images(:,:,2,:)=Images(:,:,1,:);
Images(:,:,1,:)=0;
imwrite(Images(:,:,:,1),"C:\Users\vhtmf\Documents\MATLAB\Transfer-learning\整合\2层.png");
imwrite(Images(:,:,:,2),"C:\Users\vhtmf\Documents\MATLAB\Transfer-learning\整合\5层.png");

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
