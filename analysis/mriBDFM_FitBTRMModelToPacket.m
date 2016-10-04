function [paramsFit] = mriBDFM_FitBTRMModelToPacket(thePacket, hrfKernelStruct)
% function [packetCellArray] = mriBDFM_FitModelToPacketCellArray(thePacket, hrfKernelStructCellArray)
%

% Construct the model object
temporalFit = tfeBTRM('verbosity','high');

% grab the average hrf and prepare it as a kernel
check = diff(thePacket.response.timebase);
responseDeltaT = check(1);
nSamples = ceil((hrfKernelStruct.timebase(end)-hrfKernelStruct.timebase(1))/responseDeltaT);
newKernelTimebase = hrfKernelStruct.timebase(1):responseDeltaT:(hrfKernelStruct.timebase(1)+nSamples*responseDeltaT);
hrfKernelStruct = temporalFit.resampleTimebase(hrfKernelStruct,newKernelTimebase);
thePacket.kernel=prepareHRFKernel(hrfKernelStruct);

% downsample the stimulus values to 100 ms deltaT
totalResponseDuration=thePacket.response.metaData.TRmsecs * ...
    length(thePacket.response.values);
newStimulusTimebase=linspace(0,totalResponseDuration-100,totalResponseDuration/100);
thePacket.stimulus=temporalFit.resampleTimebase(thePacket.stimulus,newStimulusTimebase);

% How many trial instances are in this packet?
defaultParamsInfo.nInstances = size(thePacket.stimulus.values,1);

% Define an empty locking matrix
paramLockMatrix=[];

% Perform the fit
[paramsFit,~,modelResponseStruct] = ...
    temporalFit.fitResponse(thePacket,...
    'defaultParamsInfo', defaultParamsInfo, ...
    'paramLockMatrix',paramLockMatrix);

temporalFit.plot(thePacket.response);
temporalFit.plot(modelResponseStruct,'NewWindow',false);

clear temporalFit