function []=plotModelFit(stimulusStruct,responseStruct,modelResponseStruct)

% function plotLinModelFits(timeSamples,timeSeriesAvgAct,timeSeriesAvgModel,startTimes,stimValuesCell,stimValuesMat,timeSeriesStd)
%
% specialized function for making plots

plot(modelResponseStruct.timebase/1000,modelResponseStruct.values,'-r', 'LineWidth',2);
 hold on
 plot(responseStruct.timebase/1000,responseStruct.values,'-k', 'LineWidth',1);
fill([modelResponseStruct.timebase/1000 fliplr(modelResponseStruct.timebase/1000)], ...
     [responseStruct.values+responseStruct.sem fliplr(responseStruct.values-responseStruct.sem)],'k','FaceAlpha',0.15,'EdgeColor','none');
yLims = get(gca,'YLim'); xLims = get(gca,'XLim');
ylim([-2,2]);
ylabel('% change');
xlabel('time [sec]'); 
gribble = 1;