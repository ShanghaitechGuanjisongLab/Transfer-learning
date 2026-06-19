% Legacy wrapper for split Chinese Fig44C/E scripts.

thisFile = mfilename('fullpath');
thisDir = fileparts(thisFile);

run(fullfile(thisDir, 'Fig44C_InitialTransferLight_1s_BarScatter.m'));
run(fullfile(thisDir, 'Fig44E_InitialTransferLight_DivByLayer.m'));
