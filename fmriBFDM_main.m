% fmriBlockFrequencyDirectionAnalysis.
%
% Code to analyze data collected at Mount Sinai using 12-second blocked
%  stimulus presentations of uniform field flicker between 2 and 64 Hz,
%  with different modulation directions (Light flux, L-M, and S) in
%  separate runs.

%% Housekeeping
clearvars; close all; clc;
warning on;

%% Hardcoded parameters of analysis

% Define data cache behavior
stimulusCacheBehavior='skip';
responseCacheBehavior='make';
packetCacheBehavior='skip';
kernelCacheBehavior='skip';
resultCacheBehavior='skip';

% Set the list of hashes that uniquely identify caches to load

stimStructCellArrayHash = '033020e56f4e86a857cb0513b76742cf';

responseStructCellArrayHash = {''};

packetCellArrayHash = {''};

kernelStructCellArrayHash = '4d49d67800895e0bf7d33f010a9f2bdf';

% Discover user name and find the Dropbox directory
[~, userName] = system('whoami');
userName = strtrim(userName);
dropboxAnalysisDir = ...
    fullfile('/Users', userName, ...
    '/Dropbox (Aguirre-Brainard Lab)/MELA_analysis/fmriBlockFrequencyDirectionAnalysis/');

% Set responseDataDir path used to make or load the response data files
switch responseCacheBehavior
    case 'make'
        responseDataDir = '/data/jag/MELA'; % running on the cluster
        %responseDataDir = fullfile('/Users', userName, 'ccnCluster/MELA'); % When cross-mounted
        responseStructCacheDir = 'MOUNT_SINAI/responseStructCache';
    case 'load'
        responseDataDir = dropboxAnalysisDir;
        responseStructCacheDir='responseStructCache';
end

% Establish basic directory names
packetCacheDir='packetCache';
stimulusStructCacheDir='stimulusStructCache';
kernelStructCacheDir='kernelStructCache';
resultsStructCacheDir='resultsStructCache';

% Define the regions of interest to be studied
regionTags={'V1_Full' 'V1_1' 'V1_2' 'V1_3' 'V1_4' 'V1_5' 'V1_6' ...
            'V23_Full' 'V23_1' 'V23_2' 'V23_3' 'V23_4' 'V23_5' 'V23_6' ...
            'LGN' };

kernelRegion='V1_Full';

%% Make or load the stimStructure
switch stimulusCacheBehavior
    case 'make'
        % inform the user
        fprintf('>> Creating stimulius structures for this experiment\n');
        
        % obtain the stimulus structures for all sessions and runs
        [stimStructCellArray] = fmriBFDM_LoadStimStructCellArray(userName);
        
        % calculate the hex MD5 hash for the responseCellArray
        stimStructCellArrayHash = DataHash(stimStructCellArray);
        
        % Set path to the stimStructCache and save it using the MD5 hash name
        stimStructCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, stimulusStructCacheDir, [stimStructCellArrayHash '.mat']);
        save(stimStructCacheFileName,'stimStructCellArray','-v7.3');
        fprintf(['Saved the stimStructCellArray with hash ID ' stimStructCellArrayHash '\n']);
    case 'load'
        fprintf('>> Loading cached stimulusStruct\n');
        stimStructCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, stimulusStructCacheDir, [stimStructCellArrayHash '.mat']);
        load(stimStructCacheFileName);
    case 'skip'
        fprintf('>> Skipping the stimStructCellArray\n');
    otherwise
        error('Please define a legal packetCacheBehavior');
end

%% Make the responseStructCellArrays, if requested
if strcmp (responseCacheBehavior,'make');
    for tt = 1:length(regionTags)
        % inform the user
        fprintf(['>> Creating response structures for the region >' regionTags{tt} '<\n']);
        clear responseStructCellArray % minimizing memory footprint across loops
        
        % obtain the response structures for all sessions and runs
        [responseStructCellArray] = fmriBFDM_LoadResponseStructCellArray(regionTags{tt}, responseDataDir);
        
        % calculate the hex MD5 hash for the responseCellArray
        responseStructCellArrayHash{tt} = DataHash(responseStructCellArray);
        
        % Set path to the responseStructCache and save it using the MD5 hash name
        responseStructCacheFileName=fullfile(responseDataDir, responseStructCacheDir, [regionTags{tt} '_' responseStructCellArrayHash{tt} '.mat']);
        save(responseStructCacheFileName,'responseStructCellArray','-v7.3');
        fprintf(['Saved the responseStruct with hash ID ' responseStructCellArrayHash{tt} '\n']);
    end % loop over regions
end % check if we are to make responseStructs


%% Make the packetCellArray, if requested
if strcmp (packetCacheBehavior,'make');
    for tt = 1:length(regionTags)
        
        % Load the responseStructs
        fprintf('>> Loading cached responseStruct\n');
        responseStructCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, responseStructCacheDir, [regionTags{tt} '_' responseStructCellArrayHash{tt} '.mat']);
        load(responseStructCacheFileName);
        
        % assemble the stimulus and response structures into packets
        [packetCellArray] = fmriBFDM_MakeAndCheckPacketCellArray( stimStructCellArray, responseStructCellArray );
        
        % Remove any packets with attention task hit rate below 60%
        [packetCellArray] = fmriBDFM_FilterPacketCellArrayByPerformance(packetCellArray,0.6);
        
        % Derive the HRF from the attention events for each packet, and store it in
        % packetCellArray{}.response.metaData.fourierFitToAttentionEvents.[values,timebase]
        [packetCellArray] = fmriBDFM_DeriveHRFsForPacketCellArray(packetCellArray);
        
        % calculate the hex MD5 hash for the packetCellArray
        packetCellArrayHash{tt} = DataHash(packetCellArray);
        
        % Set path to the packetCache and save it using the MD5 hash name
        packetCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, packetCacheDir, [regionTags{tt} '_' packetCellArrayHash{tt} '.mat']);
        save(packetCacheFileName,'packetCellArray','-v7.3');
        fprintf(['Saved the packetCellArray with hash ID ' packetCellArrayHash{tt} '\n']);
        
    end % loop over regions
end % check if we are to make packets


%% Make the kernelStruct for each subject, if requested
if strcmp (kernelCacheBehavior,'make');
    fprintf('>> Making the kernelStruct for each subject\n');
    
    % identify which packetCellArrayHash corresponds to the kernelRegion
    hashIDX=find(strcmp(regionTags,kernelRegion));
    
    % load the packetCellArray to be used for kernel definition
    packetCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, packetCacheDir,  [kernelRegion '_' packetCellArrayHash{hashIDX} '.mat']);
    load(packetCacheFileName);
    
    % Create an average HRF for each subject across all runs
    [hrfKernelStructCellArray] = fmriBDFN_CreateSubjectAverageHRFs(packetCellArray);
    
    % calculate the hex MD5 hash for the hrfKernelStructCellArray
    kernelStructCellArrayHash = DataHash(hrfKernelStructCellArray);
    
    % Set path to the packetCache and save it using the MD5 hash name
    kernelStructCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, kernelStructCacheDir, [kernelRegion '_' kernelStructCellArrayHash '.mat']);
    save(kernelStructCacheFileName,'hrfKernelStructCellArray','-v7.3');
    fprintf(['Saved the kerneStructCellArray with hash ID ' kernelStructCellArrayHash '\n']);
    
end % Check if kernelStruct generation is requested


%% Perform the analysis, if requested
if strcmp (resultCacheBehavior,'make');
    % Load the kernelStruct
    kernelStructCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, kernelStructCacheDir, [kernelRegion '_' kernelStructCellArrayHash '.mat']);
    load(kernelStructCacheFileName);
    
    % Loop over regions to be analyzed
    for tt = 1:length(regionTags)
        fprintf(['>> Analyzing region >' regionTags{tt} '<\n']);
        
        % Load the packet for this region
        packetCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, packetCacheDir, [regionTags{tt} '_' packetCellArrayHash{tt} '.mat']);
        load(packetCacheFileName);
        
        % Model and remove the attention events from the responses in each packet
        [packetCellArray] = fmriBDFM_RegressAttentionEventsFromPacketCellArray(packetCellArray, hrfKernelStructCellArray);
        
        % Perform cross-validated model comparison
        %            fmriBDFM_CalculateCrossValFits(packetCellArray, hrfKernelStructCellArray);
        
        % Fit the IAMP model to the average responses for each subject, modulation
        % direction, and stimulus order
        [fitResultsStructAvgResponseCellArray, plotHandles] = fmriBDFM_FitAverageResponsePackets(packetCellArray, hrfKernelStructCellArray);
        
        % Plot and save the TimeSeries
        for ss=1:length(plotHandles)
            fmriBDFM_suptitle(plotHandles(ss),['TimeSeries for S' strtrim(num2str(ss)) ', ROI-' regionTags{tt}]);
            plotFileName=fullfile(dropboxAnalysisDir, packetCacheDir, resultsStructCacheDir, ['TimeSeries_S' strtrim(num2str(ss)) '_ROI-' regionTags{tt} '_' packetCellArrayHash{tt} '.pdf']);
            saveas(plotHandles(ss), plotFileName, 'pdf');
            close(plotHandles(ss));
        end
        
        % calculate the hex MD5 hash for the fitResultsStructAvgResponseCellArray
        resultsStructCellArrayHash = DataHash(fitResultsStructAvgResponseCellArray);
        
        % Save the fitResultsStructAvgResponseCellArray
        resultsStructCacheFileName=fullfile(dropboxAnalysisDir, packetCacheDir, resultsStructCacheDir, [regionTags{tt} '_' packetCellArrayHash{tt} '.mat']);
        save(resultsStructCacheFileName,'fitResultsStructAvgResponseCellArray','-v7.3');
        
        % Plot and save the TTFs
        plotHandles = fmriBDFM_PlotTTFs(fitResultsStructAvgResponseCellArray);
        for ss=1:length(plotHandles)
            fmriBDFM_suptitle(plotHandles(ss),['TTFs for S' strtrim(num2str(ss)) ', ROI-' regionTags{tt}]);
            plotFileName=fullfile(dropboxAnalysisDir, packetCacheDir, resultsStructCacheDir, ['TTFs_S' strtrim(num2str(ss)) '_ROI-' regionTags{tt} '_' packetCellArrayHash{tt} '.pdf']);
            saveas(plotHandles(ss), plotFileName, 'pdf');
            close(plotHandles(ss));
        end
        
        % Plot the carry-over matrices
        plotHandles = fmriBDFM_AnalyzeCarryOverEffects(fitResultsStructAvgResponseCellArray);
        for ss=1:length(plotHandles)
            fmriBDFM_suptitle(plotHandles(ss),['CarryOver for S' strtrim(num2str(ss)) ', ROI-' regionTags{tt}]);
            plotFileName=fullfile(dropboxAnalysisDir, packetCacheDir, resultsStructCacheDir, ['CarryOver_S' strtrim(num2str(ss)) '_ROI-' regionTags{tt} '_' packetCellArrayHash{tt} '.pdf']);
            saveas(plotHandles(ss), plotFileName, 'pdf');
            close(plotHandles(ss));
        end
        
    end % loop over regions
end % Check if analysis is requested



