function [X2,Y2,Coefficients] = PolyFitLine(Xs,Ys)
[XEnd(1),XEnd(2)]=bounds(Xs);
[YEnd(1),YEnd(2)]=bounds(Ys);
Coefficients=fitlm(Xs,Ys).Coefficients;
Slope=Coefficients.Estimate("x1");
Intercept=Coefficients.Estimate("(Intercept)");
Y2=sort([XEnd*Slope+Intercept,YEnd]);
X2=sort([(YEnd-Intercept)/Slope,XEnd]);
X2=X2(2:3);
if Slope>0
	Y2=Y2(2:3);
else
	Y2=Y2([3,2]);
end