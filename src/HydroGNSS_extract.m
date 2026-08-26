
function ReflectionCoefficientAtSP=HydroGNSS_extract(init_SM_Day,final_SM_Day, configurationPath) ; 
%%0..utctimefixed
close all
clear global
clearvars -except  init_SM_Day final_SM_Day configurationPath

global namelogfile logfileID  ; 
global ReflectionCoefficientAtSP Sigma0 ; 
% clear ReflectionCoefficientAtSP Sigma0 

ex=exist('configurationPath') ;
if ex ==0
    mode="GUI" ;
    
    [configurationfile configurationPath] = uigetfile('../*.cfg', 'Select input configuration file') ; 
    configurationPath= [ configurationPath configurationfile]  ; 
else
    if ~isfile(configurationPath)
        throw(MException('INPUT:ERROR', "Cannot find configuration file. Please check the command line and try again."))
    end
    mode="input" ;
end

%    

[ProcessingSatellite, DataInputRootPath, DataOutputRootPath, Outfileprefix, LogsOutputRootPath, LatSouth, LatNorth, LonWest, LonEast, Dayinit, Dayfinal, DDM, DataFilter] = ReadConfFile(configurationPath);

%% ==============================
% Load L2OP sea mask (cmask equivalent)
% ===============================

seaMaskFile= [extractBefore(configurationPath, max(regexp(configurationPath, '\')-5)) '\Auxiliary\' 'SEA_MASK_20240212.mat'];

% --- check BEFORE loading
if ~isfile(seaMaskFile)
    error('SEA mask file not found: %s', seaMaskFile);
end

% --- load file
S = load(seaMaskFile);

SpatialResolution = 25;   % or 12.5 / 9 / 36 depending on dataset

% --- select correct resolution mask
switch SpatialResolution

    case 9
        seaMask = S.SEA_MASK_9km;

    case 12.5
        seaMask = S.SEA_MASK_12_5km;

    case 25
        seaMask = S.SEA_MASK_25km;

    case 36
        seaMask = S.SEA_MASK_36km;

    otherwise
        error('Unsupported SpatialResolution: %g', SpatialResolution);
end

% --- store dimensions (important for grid mapping)
[nCols,nRows] = size(seaMask);

disp('SEA mask loaded successfully');
disp([nRows, nCols]);

switch mode
    case "GUI" 
%
% ****** get inputs from GUI
%
    disp('GUI mode')
% *************  Start GUI 
Answer{1}= char(ProcessingSatellite) ;    Answer{7}=char(string(LatNorth)) ;
Answer{2}=char(DataInputRootPath)  ;      Answer{8}= char(string(LonWest)) ;
Answer{3}=char(DataOutputRootPath)  ;     Answer{9}= char(string(LonEast)) ;
Answer{5}=char(Outfileprefix)  ;          Answer{10}= char(Dayinit) ;
Answer{4}=char(LogsOutputRootPath)  ;     Answer{11}=char(Dayfinal) ;
Answer{6}=char(string(LatSouth))  ;       Answer{12}= char(DDM) ;
Answer{13}= char(DataFilter) ;
% ****** get inputs from GUI
prompt={ 'ProcessingSatellite [HydroGNSS-1 | HydeoGNSS-2 | Both]: ',...
         'DataInputRootPath: ',...
         'DataOutputRootPath: ',...
         'LogsOutputRootPath: ', ...
         'Outfileprefix: ',...
         'Southernmost latitude: ', ...
         'Northernmost latitude: ', ...
         'Westernmost longitude: ', ...
         'Easternmost longitude:', ...
         'First day to extract: ', ...
         'Last day to extract: ', ...
         'DDM [Yes/No]:', ...
         'Data geographical filter [Land | All]'}  ; 
opts.Resize='on';
opts.WindowStyle='normal';
opts.Interpreter='tex';
name='HydroGNSS L1B data extraction';
numlines=[1 90; 1 90; 1 90; 1 90; 1 40; 1 40 ; 1 40; 1 40; 1 40; 1 40; 1 40; 1 40; 1 40] ; 
defaultanswer={Answer{1},Answer{2},...
                 Answer{3},Answer{4},Answer{5},Answer{6},Answer{7},...
                 Answer{8},Answer{9},Answer{10},...
                 Answer{11},Answer{12}, Answer{13} };
Answer=inputdlg(prompt,name,numlines,defaultanswer,opts);

ProcessingSatellite= Answer{1};
DataInputRootPath= Answer{2};
DataOutputRootPath= Answer{3};
Outfileprefix= Answer{5};
LogsOutputRootPath=Answer{4} ; 
LatSouth= str2num(Answer{6}) ; 
LatNorth= str2num(Answer{7}) ;
LonWest=   str2num(Answer{8}) ; ...
LonEast=   str2num(Answer{9}) ;
Dayinit=Answer{10} ;
Dayfinal=Answer{11} ;
DDM=Answer{12} ;
DataFilter=Answer{13} ;

%
% ****** Save GUI input into Input Configuration File 
% save('../conf/Configuration.mat', 'Answer', '-append') ;

WriteConfig(configurationPath, ProcessingSatellite, DataInputRootPath, DataOutputRootPath, LogsOutputRootPath, Outfileprefix, LatSouth, LatNorth, LonWest, LonEast, Dayinit, Dayfinal, DDM, DataFilter);


% switch mode
    case "input" 
    disp('input mode')

[ProcessingSatellite, DataInputRootPath, DataOutputRootPath, Outfileprefix, LogsOutputRootPath, LatSouth, LatNorth, LonWest, LonEast, dummy1, dummy2, DDM, DataFilter] = ReadConfFile(configurationPath);

%scrivere il configuration
% WriteConfig(configurationPath, ProcessingSatellite, DataInputRootPath, DataOutputRootPath, LogsOutputRootPath, Outfileprefix, LatSouth, LatNorth, LonWest, LonEast, Dayinit, Dayfinal, DDM);


end

Dayinit = datetime(Dayinit, 'InputFormat', 'yyyy-MM-dd''T''HH:mm') ;
Dayfinal = datetime(Dayfinal, 'InputFormat', 'yyyy-MM-dd''T''HH:mm') ;
%%
% Set and open the log file
%
if ~exist(char(LogsOutputRootPath), 'dir')
        throw(MException('INPUT:ERROR', "Logs directory does not exist: " + string(LogsOutputRootPath)))
end
%
% Check the output directory here too, before any data is read, so that a wrong
% path fails immediately instead of at the final save() once the run is over.
if ~exist(char(DataOutputRootPath), 'dir')
        throw(MException('INPUT:ERROR', "Output directory does not exist: " + string(DataOutputRootPath)))
end
%
logfile= datetime('now','Format','yyyyMMddHHmmss') ; 
logfile=char(logfile) ;
namelogfile=[char(Outfileprefix) '_' logfile '.log'] ;
logfileID = fopen([char(LogsOutputRootPath) '\' namelogfile], 'a+') ; 
fopen(logfileID) ; 
global namelogfile logfileID  ; 
%
%%
%%%% find out HydroGNSS file folder and names for the specified time frame
% endDate=Dayfinal+hours(3) ; % Needed since the six hour block H00 starts on the previous day at 23:00:00
% startDate=Dayinit+hours(3) ;
endDate=Dayfinal ; 
startDate=Dayinit ;

% numdays=ceil(juliandate(endDate)-juliandate(startDate)+1) ; %devo mettere +1 ???????
numdays=ceil(juliandate(endDate)-juliandate(startDate)) ; %devo mettere +1 ???????

% L2OPfolder_sixtot="" ; 
% for ii=1:numdays
% timeproduct=startDate+day(ii-1) ; 
%     for kk=1:4
%     timeproductsix=timeproduct+hours((kk-1)*6) ; 
%     timeproduct_sixtot(ii, kk)=timeproductsix ; 
%     [tyear, tmonth, tday]=ymd(timeproductsix) ; 
%     [thour, tmin, tsec]=hms(timeproductsix) ;
% 
%     six=6*fix(thour/6) ;
%     sixhour=char(string(six)) ; 
%         if tday< 10, charday=['0' char(string(tday))] ; else charday= char(string(tday)); end
%         if tmonth< 10, charmonth=['0' char(string(tmonth))] ; else charmonth= char(string(tmonth)); end
% 
%         if six >= 12 
%         L2OPfoldername=[char(DataInputRootPath) '\' char(ProcessingSatellite) '\DataRelease\L1A_L1B\' char(string(tyear)) '-' charmonth '\' charday '\H' sixhour '\'] ;
%         else
%         L2OPfoldername=[char(DataInputRootPath) '\' char(ProcessingSatellite) '\DataRelease\L1A_L1B\' char(string(tyear)) '-' charmonth '\' charday '\H0' sixhour '\'] ;
%         end
%    % L2OPfolder_sixtot(ii+ii*(kk-1))=string(L2OPfoldername) ; % vector with full folder path of L2OP product files
%    if exist(L2OPfoldername)>0 & exist([L2OPfoldername 'metadata_L1_merged.nc']) >0
%     L2OPfolder_sixtot(ii, kk)=string(L2OPfoldername) ; % matrix [num of days x 4 six hour block per day] vector with full folder path of L2OP product files
%    else
%     L2OPfolder_sixtot(ii, kk)=missing ;  
%         disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: six hour block ' L2OPfoldername ' does not exist or does not contain metadata. Program continuing']) ; 
%         fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: six hour block does not exist or does not contain metadata. Program continuing']) ; 
%         fprintf(logfileID,'\n') ; 
%    end
% 
%     % end 
%     end
% end
% 
% %%
% 
% GoodSixhour=find(ismissing(L2OPfolder_sixtot)==0)  ;  
% L2OPfolder_sixtot=L2OPfolder_sixtot(GoodSixhour) ;
% timeproduct_sixtot=timeproduct_sixtot(GoodSixhour) ; 
% numGoodSixhour=length(GoodSixhour) ; 


DataTag=0; Track_ID=0; IND_sixhours=0 ; 
SM_Time_resolution=ceil(juliandate(endDate)-juliandate(startDate)) ;
readDDM=DDM; DDMs_name='DDMs.nc'; L1b_ProcessorVersion=' ' ; L1a_ProcessorVersion=' ';
metadata_name='metadata_L1_merged.nc' ; Day_to_process=Dayinit; 
Both=0 ; 
if strcmpi(ProcessingSatellite, 'Both')
    Both=1 ;
    ProcessingSatellite='HydroGNSS-1' ; 
    Path_HydroGNSS_Data=[char(DataInputRootPath), '\', char(ProcessingSatellite), '\DataRelease\L1A_L1B'] ; 
    [DataTag, noday, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion]=read_L1Bproduct(DataTag, Dayinit,...
    SM_Time_resolution,Path_HydroGNSS_Data, metadata_name, readDDM, ...
    DDMs_name, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion) ;
    ProcessingSatellite='HydroGNSS-2' ; 
    Path_HydroGNSS_Data=[char(DataInputRootPath), '\', char(ProcessingSatellite), '\DataRelease\L1A_L1B'] ; 
    [DataTag, noday, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion]=read_L1Bproduct(DataTag, Dayinit,...
    SM_Time_resolution,Path_HydroGNSS_Data, metadata_name, readDDM, ...
    DDMs_name, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion) ;
else
    Path_HydroGNSS_Data=[char(DataInputRootPath), '\', char(ProcessingSatellite), '\DataRelease\L1A_L1B'] ; 
    [DataTag, noday, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion]=read_L1Bproduct(DataTag, Dayinit,...
    SM_Time_resolution,Path_HydroGNSS_Data, metadata_name, readDDM, ...
    DDMs_name, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion) ;
end % end if ProcessingSatellite == Both
% end

%% Crete output variables and save

[a NumOfTracks]=size(ReflectionCoefficientAtSP) ; 

numOfSP=0 ;  timeUTC=[] ; SAT=[] ; 
for ii=1:NumOfTracks
    SAT=[SAT , string(ReflectionCoefficientAtSP(ii).Satellite)] ;
    numOfSP=numOfSP+length(ReflectionCoefficientAtSP(ii).SpecularPointLat) ; 
end
%_1_L
%_1_R
reflectivityLinear_5_Ldb=single(NaN(numOfSP,1)) ; reflectivityLinear_5_Rdb=single(NaN(numOfSP,1)) ;
timeUTC=[]; time = single([]); specularPointLat=[]; specularPointLon=[]; Landtypesub=[] ; 
ReceiverSubSatLatitude_all = []; ReceiverSubSatLongitude_all= []; ReceiverPositionX_all = []; THETA=[] ; Onboardspeclat=[] ;Onboardspeclon=[] ; constellation = strings(numOfSP,1); teWidth=single([]); spAzimuthAngleDegOrbit=[] ;dayOfYear=single([]); secondOfDay=single([]);  
reflectivityLinear_1_L=single(NaN(numOfSP,1)) ;reflectivityLinear_1_R=single(NaN(numOfSP,1)) ; 
reflectivityLinear_L1_L=single(NaN(numOfSP,1)) ; reflectivityLinear_L1_R=single(NaN(numOfSP,1)) ;
reflectivityLinear_E1_L=single(NaN(numOfSP,1)) ; reflectivityLinear_E1_R=single(NaN(numOfSP,1)) ;
reflectivityLinear_5_L=single(NaN(numOfSP,1)) ; reflectivityLinear_5_R=single(NaN(numOfSP,1)) ; 

SNR_1_L=single(NaN(numOfSP,1)) ; SNR_1_R=single(NaN(numOfSP,1)) ;
SNR_L1_L=single(NaN(numOfSP,1)) ; SNR_L1_R=single(NaN(numOfSP,1)) ; SNR_5_L=single(NaN(numOfSP,1)) ; 
SNR_5_R=single(NaN(numOfSP,1)) ; SNR_E1_L=single(NaN(numOfSP,1)) ; SNR_E1_R=single(NaN(numOfSP,1));...

DirectSignalInDDM_1_R = single(NaN(numOfSP,1)) ; DirectSignalInDDM_1_L = single(NaN(numOfSP,1));
DirectSignalInDDM_L1_R = single(NaN(numOfSP,1)) ; DirectSignalInDDM_L1_L = single(NaN(numOfSP,1)); DirectSignalInDDM_5_R = single(NaN(numOfSP,1)) ; DirectSignalInDDM_5_L = single(NaN(numOfSP,1)); DirectSignalInDDM_E1_R = single(NaN(numOfSP,1)) ; DirectSignalInDDM_E1_L = single(NaN(numOfSP,1)); DirectSignalInDDM_E5_R = single(NaN(numOfSP,1)) ; DirectSignalInDDM_E5_L = single(NaN(numOfSP,1));

EIRP_1 = single(NaN(numOfSP,1)) ; 
EIRP_L1 = single(NaN(numOfSP,1)) ; EIRP_L5 = single(NaN(numOfSP,1)) ;EIRP_L1 = single(NaN(numOfSP,1)) ; EIRP_L5 = single(NaN(numOfSP,1)) ; EIRP_E1 = single(NaN(numOfSP,1)) ; EIRP_5 = single(NaN(numOfSP,1)) ; ...

coherencyRatio_1_R = single(NaN(numOfSP,1)) ; coherencyRatio_1_L = single(NaN(numOfSP,1));
coherencyRatio_L1_R = single(NaN(numOfSP,1)) ; coherencyRatio_L1_L = single(NaN(numOfSP,1)); coherencyRatio_L5_R = single(NaN(numOfSP,1)) ; coherencyRatio_L5_L = single(NaN(numOfSP,1)); coherencyRatio_E1_R = single(NaN(numOfSP,1)) ; coherencyRatio_E1_L = single(NaN(numOfSP,1)); coherencyRatio_5_R = single(NaN(numOfSP,1)) ; coherencyRatio_5_L = single(NaN(numOfSP,1));...

ReflectionCoefficientAtSP_CM1_1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM1_1_L = single(NaN(numOfSP,1));
ReflectionCoefficientAtSP_CM1_L1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM1_L1_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM1_L5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM1_L5_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM1_E1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM1_E1_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM1_5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM1_5_L = single(NaN(numOfSP,1));...

ReflectionCoefficientAtSP_CM2_1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM2_1_L = single(NaN(numOfSP,1));
ReflectionCoefficientAtSP_CM2_L1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM2_L1_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM2_L5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM2_L5_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM2_E1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM2_E1_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM2_5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM2_5_L = single(NaN(numOfSP,1));...

ReflectionCoefficientAtSP_CM3_1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM3_1_L = single(NaN(numOfSP,1));
ReflectionCoefficientAtSP_CM3_L1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM3_L1_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM3_L5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM3_L5_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM3_E1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM3_E1_L = single(NaN(numOfSP,1)); ReflectionCoefficientAtSP_CM3_5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientAtSP_CM3_5_L = single(NaN(numOfSP,1));...

ReflectionCoefficientUnbounded_1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientUnbounded_1_L = single(NaN(numOfSP,1));
ReflectionCoefficientUnbounded_L1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientUnbounded_L1_L = single(NaN(numOfSP,1)); ReflectionCoefficientUnbounded_L5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientUnbounded_L5_L = single(NaN(numOfSP,1)); ReflectionCoefficientUnbounded_E1_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientUnbounded_E1_L = single(NaN(numOfSP,1)); ReflectionCoefficientUnbounded_5_R = single(NaN(numOfSP,1)) ; ReflectionCoefficientUnbounded_5_L = single(NaN(numOfSP,1));...

rxAntennaGain_1_R = single(NaN(numOfSP,1)) ; rxAntennaGain_1_L = single(NaN(numOfSP,1));
rxAntennaGain_L1_R = single(NaN(numOfSP,1)) ; rxAntennaGain_L1_L = single(NaN(numOfSP,1)); rxAntennaGain_L5_R = single(NaN(numOfSP,1)) ; rxAntennaGain_L5_L = single(NaN(numOfSP,1)); rxAntennaGain_E1_R = single(NaN(numOfSP,1)) ; rxAntennaGain_E1_L = single(NaN(numOfSP,1)); rxAntennaGain_5_R = single(NaN(numOfSP,1)) ; rxAntennaGain_5_L = single(NaN(numOfSP,1));...

qualityControlFlags_1_R = single(NaN(numOfSP,1)) ; qualityControlFlags_1_L = single(NaN(numOfSP,1));
qualityControlFlags_L1_R = single(NaN(numOfSP,1)) ; qualityControlFlags_L1_L = single(NaN(numOfSP,1)); qualityControlFlags_5_R = single(NaN(numOfSP,1)) ; qualityControlFlags_5_L = single(NaN(numOfSP,1)); qualityControlFlags_E1_R = single(NaN(numOfSP,1)) ; qualityControlFlags_E1_L = single(NaN(numOfSP,1)); qualityControlFlags_E5_R = single(NaN(numOfSP,1)) ; qualityControlFlags_E5_L = single(NaN(numOfSP,1));

NBRCS_1_R = single(NaN(numOfSP,1)) ; NBRCS_1_L = single(NaN(numOfSP,1));
NBRCS_L1_R = single(NaN(numOfSP,1)) ; NBRCS_L1_L = single(NaN(numOfSP,1)); NBRCS_5_R = single(NaN(numOfSP,1)) ; NBRCS_5_L = single(NaN(numOfSP,1)); NBRCS_E1_R = single(NaN(numOfSP,1)) ; NBRCS_E1_L = single(NaN(numOfSP,1)); NBRCS_E5_R = single(NaN(numOfSP,1)) ; NBRCS_E5_L = single(NaN(numOfSP,1)); 

powerRatio_1_R = single(NaN(numOfSP,1)) ; powerRatio_1_L = single(NaN(numOfSP,1));
powerRatio_L1_R = single(NaN(numOfSP,1)) ; powerRatio_L1_L = single(NaN(numOfSP,1)); powerRatio_5_R = single(NaN(numOfSP,1)) ; powerRatio_5_L = single(NaN(numOfSP,1)); powerRatio_E1_R = single(NaN(numOfSP,1)) ; powerRatio_E1_L = single(NaN(numOfSP,1)); powerRatio_E5_R = single(NaN(numOfSP,1)) ; powerRatio_E5_L = single(NaN(numOfSP,1)); 

NoiseKurtosis=single(NaN(numOfSP,1));PRN=single(NaN(numOfSP,1));SVN=single(NaN(numOfSP,1));GNSSConstellation = single(NaN(numOfSP,1));QC_pass_flag=single(NaN(numOfSP,1)); 

kurtosisDDM_1_R = single(NaN(numOfSP,1)) ; kurtosisDDM_1_L = single(NaN(numOfSP,1)); 
kurtosisDDM_L1_R = single(NaN(numOfSP,1)) ; kurtosisDDM_L1_L = single(NaN(numOfSP,1)); kurtosisDDM_5_R = single(NaN(numOfSP,1)) ; kurtosisDDM_5_L = single(NaN(numOfSP,1)); kurtosisDDM_E1_R = single(NaN(numOfSP,1)) ; kurtosisDDM_E1_L = single(NaN(numOfSP,1)); kurtosisDDM_E5_R = single(NaN(numOfSP,1)) ; kurtosisDDM_E5_L = single(NaN(numOfSP,1));

kurtosisDopp0_1_R = single(NaN(numOfSP,1)) ; kurtosisDopp0_1_L = single(NaN(numOfSP,1));
kurtosisDopp0_L1_R = single(NaN(numOfSP,1)) ; kurtosisDopp0_L1_L = single(NaN(numOfSP,1)); kurtosisDopp0_5_R = single(NaN(numOfSP,1)) ; kurtosisDopp0_5_L = single(NaN(numOfSP,1)); kurtosisDopp0_E1_R = single(NaN(numOfSP,1)) ; kurtosisDopp0_E1_L = single(NaN(numOfSP,1)); kurtosisDopp0_E5_R = single(NaN(numOfSP,1)) ; kurtosisDopp0_E5_L = single(NaN(numOfSP,1));

noiseFloorCounts_1_R = single(NaN(numOfSP,1)) ; noiseFloorCounts_1_L = single(NaN(numOfSP,1));
noiseFloorCounts_L1_R = single(NaN(numOfSP,1)) ; noiseFloorCounts_L1_L = single(NaN(numOfSP,1)); noiseFloorCounts_5_R = single(NaN(numOfSP,1)) ; noiseFloorCounts_5_L = single(NaN(numOfSP,1)); noiseFloorCounts_E1_R = single(NaN(numOfSP,1)) ; noiseFloorCounts_E1_L = single(NaN(numOfSP,1)); noiseFloorCounts_E5_R = single(NaN(numOfSP,1)) ; noiseFloorCounts_E5_L = single(NaN(numOfSP,1));

powerAnalogW_1_R = single(NaN(numOfSP,1)); powerAnalogW_1_L = single(NaN(numOfSP,1));
powerAnalogW_L1_R = single(NaN(numOfSP,1)); powerAnalogW_L1_L = single(NaN(numOfSP,1)); powerAnalogW_5_R = single(NaN(numOfSP,1)); powerAnalogW_5_L = single(NaN(numOfSP,1)); powerAnalogW_E1_R = single(NaN(numOfSP,1)); powerAnalogW_E1_L = single(NaN(numOfSP,1)); powerAnalogW_E5_R = single(NaN(numOfSP,1)); powerAnalogW_E5_L = single(NaN(numOfSP,1));

powerAnalogWdbw_L1_R = single(NaN(numOfSP,1)); powerAnalogWdbw_L1_L = single(NaN(numOfSP,1)); powerAnalogWdbw_5_R = single(NaN(numOfSP,1)); powerAnalogWdbw_5_L = single(NaN(numOfSP,1)); powerAnalogWdbw_E1_R = single(NaN(numOfSP,1)); powerAnalogWdbw_E1_L = single(NaN(numOfSP,1)); powerAnalogWdbw_E5_R = single(NaN(numOfSP,1)); powerAnalogWdbw_E5_L = single(NaN(numOfSP,1)); 
powerAnalogWdbw_1_R = single(NaN(numOfSP,1)); powerAnalogWdbw_1_L = single(NaN(numOfSP,1));

notToBeUsed_1_L= single(NaN(numOfSP,1)); notToBeUsed_1_R= single(NaN(numOfSP,1)); 
notToBeUsed_5_L= single(NaN(numOfSP,1)); notToBeUsed_5_R= single(NaN(numOfSP,1)); 
notToBeUsed_E1_L= single(NaN(numOfSP,1)); notToBeUsed_E1_R= single(NaN(numOfSP,1)); 
notToBeUsed_L1_L= single(NaN(numOfSP,1));notToBeUsed_L1_R= single(NaN(numOfSP,1));
SixHourDir=string([]) ; 

GPSindex=find(SAT=="GPS") ;
Galileoindex=find(SAT=="Galileo") ; 

fintrack=0 ; 
%dayOfYear = [];
%secondOfDay = [];
Year = single([]);


format long g   % <-- ADD this at the top of your script

for kk = 1:NumOfTracks
       t_track = ReflectionCoefficientAtSP(kk).time;  % original per-point time vector

    % --- Keep numeric time as in file (full precision)
    time = [time; t_track(:)];

    % --- Convert to full UTC datetime
% Inside your loop
t_track = ReflectionCoefficientAtSP(kk).time;  % numeric seconds

% --- Keep numeric time
time = [time; t_track(:)];


dt_full = datetime(t_track, 'ConvertFrom', 'datenum');  % full precision
timeUTC = [timeUTC; dt_full];

% Set display format for the entire timeUTC array
timeUTC.Format = 'yyyy-MM-dd HH:mm:ss';

% Additional variables
dayOfYear = [dayOfYear; day(dt_full,'dayofyear')];
secondOfDay = [secondOfDay; hour(dt_full)*3600 + minute(dt_full)*60 + second(dt_full)];
Year = [Year; year(dt_full)];

    ReceiverSubSatLatitude_all = [ReceiverSubSatLatitude_all ; ReflectionCoefficientAtSP(kk).ReceiverSubSatLatitude];
    ReceiverSubSatLongitude_all = [ReceiverSubSatLongitude_all ; ReflectionCoefficientAtSP(kk).ReceiverSubSatLongitude];

    ReceiverPositionX_all = [ReceiverPositionX_all ; ReflectionCoefficientAtSP(kk).ReceiverPositionX];
    specularPointLat=[specularPointLat ; ReflectionCoefficientAtSP(kk).SpecularPointLat] ; 
    specularPointLon=[specularPointLon ; ReflectionCoefficientAtSP(kk).SpecularPointLon] ; 
    THETA=[THETA ; ReflectionCoefficientAtSP(kk).SPIncidenceAngle] ;
    Onboardspeclat=[Onboardspeclat ; ReflectionCoefficientAtSP(kk).OnBoardSpecularPointLat] ;
    Onboardspeclon=[Onboardspeclon ; ReflectionCoefficientAtSP(kk).OnBoardSpecularPointLon] ;
    spAzimuthAngleDegOrbit=[spAzimuthAngleDegOrbit ; ReflectionCoefficientAtSP(kk).SPAzimuthORF] ;
    % --- Always save LandType
    Landtypesub = [Landtypesub ; ReflectionCoefficientAtSP(kk).LandType];
    sizetrack= length(t_track) ; 
    SixHourDir=[SixHourDir ; repmat(ReflectionCoefficientAtSP(kk).SixHourDir, sizetrack,1)] ; 
    sizetrack=length(ReflectionCoefficientAtSP(kk).time) ; 
    intrack=fintrack+1 ; 
    fintrack=intrack+sizetrack-1 ; 



%        if isfield(ReflectionCoefficientAtSP(kk), 'EIRP') && ...
%       ~ismissing(ReflectionCoefficientAtSP(kk).EIRP)
%         EIRP(intrack:fintrack) = ReflectionCoefficientAtSP(kk).EIRP;
%         end
%         if isfield(ReflectionCoefficientAtSP(kk), 'EIRP_CM1') && ...
%        ~ismissing(ReflectionCoefficientAtSP(kk).EIRP_CM1)
%         EIRP_CM1(intrack:fintrack) = ReflectionCoefficientAtSP(kk).EIRP_CM1;
%         end
%         if isfield(ReflectionCoefficientAtSP(kk),'EIRP_CM2')&&~ismissing(ReflectionCoefficientAtSP(kk).EIRP_CM2),EIRP_CM2(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_CM2;end;if isfield(ReflectionCoefficientAtSP(kk),'EIRP_CM3')&&~ismissing(ReflectionCoefficientAtSP(kk).EIRP_CM3),EIRP_CM3(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_CM3;end;if isfield(ReflectionCoefficientAtSP(kk),'NoiseKurtosis')&&~ismissing(ReflectionCoefficientAtSP(kk).NoiseKurtosis),NoiseKurtosis(intrack:fintrack)=ReflectionCoefficientAtSP(kk).NoiseKurtosis;end;if isfield(ReflectionCoefficientAtSP(kk),'HighNoiseKurtosis')&&~ismissing(ReflectionCoefficientAtSP(kk).HighNoiseKurtosis),HighNoiseKurtosis(intrack:fintrack)=ReflectionCoefficientAtSP(kk).HighNoiseKurtosis;end;
if isfield(ReflectionCoefficientAtSP(kk),'PRN')&&~ismissing(ReflectionCoefficientAtSP(kk).PRN),PRN(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PRN;end;
if isfield(ReflectionCoefficientAtSP(kk),'SVN')&&~ismissing(ReflectionCoefficientAtSP(kk).SVN),SVN(intrack:fintrack)=ReflectionCoefficientAtSP(kk).SVN;end;
if isfield(ReflectionCoefficientAtSP(kk),'QC_pass_flag')&&~ismissing(ReflectionCoefficientAtSP(kk).QC_pass_flag),QC_pass_flag(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QC_pass_flag;end;
if isfield(ReflectionCoefficientAtSP(kk),'GNSSConstellation_units')&&~ismissing(ReflectionCoefficientAtSP(kk).GNSSConstellation_units),GNSSConstellation(intrack:fintrack)=ReflectionCoefficientAtSP(kk).GNSSConstellation_units;end;


  switch SAT(kk) ; 
    case "GPS"
   % Add constellation label for GPS
    %constellation = [constellation; repmat({'GPS'}, length(refl_coeff.Latitude), 1)];

  % 
    if min(ismissing(ReflectionCoefficientAtSP(kk).L1_LHCP))==0 , reflectivityLinear_1_L(intrack:fintrack)=10.^(ReflectionCoefficientAtSP(kk).L1_LHCP/10) ;...
            SNR_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).SNR_L1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).L1_RHCP))==0, reflectivityLinear_1_R(intrack:fintrack)=10.^(ReflectionCoefficientAtSP(kk).L1_RHCP/10) ;...
            SNR_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).SNR_L1_RHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).L5_LHCP))==0, reflectivityLinear_5_L(intrack:fintrack)= 10.^(ReflectionCoefficientAtSP(kk).L5_LHCP/10) ;...
        SNR_5_L(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_L5_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).L5_RHCP))==0, reflectivityLinear_5_R(intrack:fintrack)= 10.^(ReflectionCoefficientAtSP(kk).L5_RHCP/10) ;...
        SNR_5_R(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_L5_RHCP ; end
    %testlines
       if min(ismissing(ReflectionCoefficientAtSP(kk).L5_LHCP))==0, reflectivityLinear_5_Ldb(intrack:fintrack)= ReflectionCoefficientAtSP(kk).L5_LHCP ;...
        SNR_5_L(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_L5_LHCP ; 
           if length(ReflectionCoefficientAtSP(kk).L5_LHCP) ~= sizetrack ; 
           disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: GPS L5 size inconcistency at kk=' char(string(kk)) '; day ' char(datetime(Year, Month, Day)) ' block ' char(Dir_Day(jj))]) ;
           fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: GPS L5 size inconcistency at kk=' char(string(kk)) '; day ' char(datetime(Year, Month, Day)) ' block ' char(Dir_Day(jj))]) ; 
           fprintf(logfileID,'\n') ;    
           end
       end
    if min(ismissing(ReflectionCoefficientAtSP(kk).L5_RHCP))==0, reflectivityLinear_5_Rdb(intrack:fintrack)= ReflectionCoefficientAtSP(kk).L5_RHCP ;...
        SNR_5_R(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_L5_RHCP ; end

    %EIRP lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).EIRP_L1_LHCP))==0 , EIRP_1(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_L1_LHCP ; end

 %    if min(ismissing(ReflectionCoefficientAtSP(kk).EIRP_L5_LHCP))==0 , EIRP_L5(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_L5_LHCP ; end
      if min(ismissing(ReflectionCoefficientAtSP(kk).EIRP_L5_LHCP))==0 , EIRP_5(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_L5_LHCP ; end

     %DirectSignalInDDM lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L1_LHCP))==0 , DirectSignalInDDM_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L1_RHCP))==0 , DirectSignalInDDM_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L5_LHCP))==0 , DirectSignalInDDM_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L5_RHCP))==0 , DirectSignalInDDM_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_L5_RHCP ; end


     %rxAntenna Gain lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_L1_LHCP))==0 , rxAntennaGain_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_L1_RHCP))==0 , rxAntennaGain_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_L5_LHCP))==0 , rxAntennaGain_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_L5_RHCP))==0 , rxAntennaGain_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_L5_RHCP ; end
  
        %coherency Gain lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_L1_LHCP))==0 , coherencyRatio_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_L1_RHCP))==0 , coherencyRatio_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_L5_LHCP))==0 , coherencyRatio_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_L5_RHCP))==0 , coherencyRatio_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_L5_RHCP ; end
   
     % ReflectionCoefficientUnbounded lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L1_LHCP))==0 , ReflectionCoefficientUnbounded_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L1_RHCP))==0 , ReflectionCoefficientUnbounded_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L5_LHCP))==0 , ReflectionCoefficientUnbounded_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L5_RHCP))==0 , ReflectionCoefficientUnbounded_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_L5_RHCP ; end

     % ReflectionCoefficientAtSP_CM1 lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L1_LHCP))==0 , ReflectionCoefficientAtSP_CM1_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L1_RHCP))==0 , ReflectionCoefficientAtSP_CM1_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L5_LHCP))==0 , ReflectionCoefficientAtSP_CM1_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L5_RHCP))==0 , ReflectionCoefficientAtSP_CM1_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_L5_RHCP ; end

          % ReflectionCoefficientAtSP_CM2 lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L1_LHCP))==0 , ReflectionCoefficientAtSP_CM2_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L1_RHCP))==0 , ReflectionCoefficientAtSP_CM2_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L5_LHCP))==0 , ReflectionCoefficientAtSP_CM2_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L5_RHCP))==0 , ReflectionCoefficientAtSP_CM2_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_L5_RHCP ; end

          % ReflectionCoefficientAtSP_CM3 lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L1_LHCP))==0 , ReflectionCoefficientAtSP_CM3_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L1_RHCP))==0 , ReflectionCoefficientAtSP_CM3_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L5_LHCP))==0 , ReflectionCoefficientAtSP_CM3_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L5_RHCP))==0 , ReflectionCoefficientAtSP_CM3_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_L5_RHCP ; end


    %QualityControlFlag lines
%     if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_L1_LHCP))==0 , qualityControlFlags_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_L1_LHCP ; end
%     if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_L1_RHCP))==0 , qualityControlFlags_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_L1_RHCP ; end

%     if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_L5_LHCP))==0 , qualityControlFlags_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_L5_LHCP ; end
%     if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_L5_RHCP))==0 , qualityControlFlags_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_L5_RHCP ; end
  

     %PowerAnalog_W lines
if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_L1_LHCP))==0 , powerAnalogWdbw_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_L1_LHCP ; end
if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_L1_RHCP))==0 , powerAnalogWdbw_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_L1_RHCP ; end

if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_L5_LHCP))==0 , powerAnalogWdbw_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_L5_LHCP ; end
if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_L5_RHCP))==0 , powerAnalogWdbw_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_L5_RHCP ; end


     %MeanNoise lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_L1_LHCP))==0 , noiseFloorCounts_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_L1_RHCP))==0 , noiseFloorCounts_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_L5_LHCP))==0 , noiseFloorCounts_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_L5_RHCP))==0 , noiseFloorCounts_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_L5_RHCP ; end
   
     %powerRatio lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L1_LHCP))==0 , powerRatio_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L1_RHCP))==0 , powerRatio_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L5_LHCP))==0 , powerRatio_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L5_RHCP))==0 , powerRatio_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_L5_RHCP ; end

     %Sigma0 lines
    if min(ismissing(Sigma0(kk).NBRCS_L1_LHCP))==0 , NBRCS_1_L(intrack:fintrack)=Sigma0(kk).NBRCS_L1_LHCP ; end
    if min(ismissing(Sigma0(kk).NBRCS_L1_RHCP))==0 , NBRCS_1_R(intrack:fintrack)=Sigma0(kk).NBRCS_L1_RHCP ; end

    if min(ismissing(Sigma0(kk).NBRCS_L5_LHCP))==0 , NBRCS_5_L(intrack:fintrack)=Sigma0(kk).NBRCS_L5_LHCP ; end
     if min(ismissing(Sigma0(kk).NBRCS_L5_RHCP))==0 , NBRCS_5_R(intrack:fintrack)=Sigma0(kk).NBRCS_L5_RHCP ; end

      %HighNoiseKurtosis lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L1_LHCP))==0 , kurtosisDDM_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L1_RHCP))==0 , kurtosisDDM_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L5_LHCP))==0 , kurtosisDDM_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L5_RHCP))==0 , kurtosisDDM_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_L5_RHCP ; end

           %NoiseKurtosis lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L1_LHCP))==0 , kurtosisDopp0_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L1_RHCP))==0 , kurtosisDopp0_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L5_LHCP))==0 , kurtosisDopp0_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L5_RHCP))==0 , kurtosisDopp0_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_L5_RHCP ; end


     case "Galileo"
    
    % Add constellation label for Galileo
    %constellation = [constellation; repmat({'Galileo'}, length(refl_coeff.Latitude), 1)];

    if min(ismissing(ReflectionCoefficientAtSP(kk).E1_LHCP))==0, reflectivityLinear_1_L(intrack:fintrack)=10.^(ReflectionCoefficientAtSP(kk).E1_LHCP/10) ;...
        SNR_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).SNR_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).E1_RHCP))==0, reflectivityLinear_1_R(intrack:fintrack)=10.^(ReflectionCoefficientAtSP(kk).E1_RHCP/10) ;...
            SNR_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).SNR_E1_RHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).E5_LHCP))==0, reflectivityLinear_5_L(intrack:fintrack)= 10.^(ReflectionCoefficientAtSP(kk).E5_LHCP/10) ;...
            SNR_5_L(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_E5_LHCP ; 
           if length(ReflectionCoefficientAtSP(kk).E5_LHCP) ~= sizetrack ; 
           disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: Galile E5 size inconcistency at kk=' char(string(kk)) '; day ' char(datetime(Year, Month, Day)) ' block ' char(Dir_Day(jj))]) ;
           fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: Galile E5 size inconcistency at kk=' char(string(kk)) '; day ' char(datetime(Year, Month, Day)) ' block ' char(Dir_Day(jj))]) ; 
           fprintf(logfileID,'\n') ;    
           end
    end
    if min(ismissing(ReflectionCoefficientAtSP(kk).E5_RHCP))==0, reflectivityLinear_5_R(intrack:fintrack)= 10.^(ReflectionCoefficientAtSP(kk).E5_RHCP/10) ;...
            SNR_5_R(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_E5_RHCP ; end
 %testlins
    if min(ismissing(ReflectionCoefficientAtSP(kk).E5_LHCP))==0, reflectivityLinear_5_Ldb(intrack:fintrack)= ReflectionCoefficientAtSP(kk).E5_LHCP ;...
            SNR_5_L(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_E5_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).E5_RHCP))==0, reflectivityLinear_5_Rdb(intrack:fintrack)= ReflectionCoefficientAtSP(kk).E5_RHCP ;...
            SNR_5_R(intrack:fintrack)= ReflectionCoefficientAtSP(kk).SNR_E5_RHCP ; end

   %EIRP lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).EIRP_E1_LHCP))==0 , EIRP_1(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_E1_LHCP ; end
 %   if min(ismissing(ReflectionCoefficientAtSP(kk).EIRP_E5_LHCP))==0 , EIRP_E5(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_E5_LHCP ; end
   if min(ismissing(ReflectionCoefficientAtSP(kk).EIRP_E5_LHCP))==0 , EIRP_5(intrack:fintrack)=ReflectionCoefficientAtSP(kk).EIRP_E5_LHCP ; end


      %DirectSignalInDDM lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E1_LHCP))==0 , DirectSignalInDDM_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E1_RHCP))==0 , DirectSignalInDDM_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E5_LHCP))==0 , DirectSignalInDDM_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E5_RHCP))==0 , DirectSignalInDDM_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).DirectSignalInDDM_E5_RHCP ; end


     %Rx Antenna gain lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_E1_LHCP))==0 , rxAntennaGain_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_E1_RHCP))==0 , rxAntennaGain_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_E5_LHCP))==0 , rxAntennaGain_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).rxAntennaGain_E5_RHCP))==0 , rxAntennaGain_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).rxAntennaGain_E5_RHCP ; end

        %Coherency gain lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_E1_LHCP))==0 , coherencyRatio_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_E1_RHCP))==0 , coherencyRatio_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_E5_LHCP))==0 , coherencyRatio_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).coherencyRatio_E5_RHCP))==0 , coherencyRatio_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).coherencyRatio_E5_RHCP ; end

       %ReflectionCoefficientUnbounded lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E1_LHCP))==0 , ReflectionCoefficientUnbounded_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E1_RHCP))==0 , ReflectionCoefficientUnbounded_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E5_LHCP))==0 , ReflectionCoefficientUnbounded_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E5_RHCP))==0 , ReflectionCoefficientUnbounded_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientUnbounded_E5_RHCP ; end


     %ReflectionCoefficientAtSP_CM1 lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E1_LHCP))==0 , ReflectionCoefficientAtSP_CM1_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E1_RHCP))==0 , ReflectionCoefficientAtSP_CM1_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E5_LHCP))==0 , ReflectionCoefficientAtSP_CM1_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E5_RHCP))==0 , ReflectionCoefficientAtSP_CM1_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM1_E5_RHCP ; end

      %ReflectionCoefficientAtSP_CM2 lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E1_LHCP))==0 , ReflectionCoefficientAtSP_CM2_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E1_RHCP))==0 , ReflectionCoefficientAtSP_CM2_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E5_LHCP))==0 , ReflectionCoefficientAtSP_CM2_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E5_RHCP))==0 , ReflectionCoefficientAtSP_CM2_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM2_E5_RHCP ; end

      %ReflectionCoefficientAtSP_CM3 lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E1_LHCP))==0 , ReflectionCoefficientAtSP_CM3_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E1_RHCP))==0 , ReflectionCoefficientAtSP_CM3_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E5_LHCP))==0 , ReflectionCoefficientAtSP_CM3_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E5_RHCP))==0 , ReflectionCoefficientAtSP_CM3_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).ReflectionCoefficientAtSP_CM3_E5_RHCP ; end


     %Quality control flag lines
  %  if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_E1_LHCP))==0 , qualityControlFlags_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_E1_LHCP ; end
  %  if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_E1_RHCP))==0 , qualityControlFlags_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_E1_RHCP ; end

  %  if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_E5_LHCP))==0 , qualityControlFlags_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_E5_LHCP ; end
  %  if min(ismissing(ReflectionCoefficientAtSP(kk).QualityControlFlags_E5_RHCP))==0 , qualityControlFlags_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).QualityControlFlags_E5_RHCP ; end


%PowerAnalog_W lines
if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_E1_LHCP))==0 , powerAnalogWdbw_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_E1_LHCP ; end
if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_E1_RHCP))==0 , powerAnalogWdbw_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_E1_RHCP ; end

if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_E5_LHCP))==0 , powerAnalogWdbw_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_E5_LHCP ; end
if min(ismissing(ReflectionCoefficientAtSP(kk).PowerAnalog_W_E5_RHCP))==0 , powerAnalogWdbw_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerAnalog_W_E5_RHCP ; end


   
     %MeanNoise lines
    if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_E1_LHCP))==0 , noiseFloorCounts_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_E1_LHCP ; end
    if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_E1_RHCP))==0 , noiseFloorCounts_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_E5_LHCP))==0 , noiseFloorCounts_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).noise_floor_Counts_E5_RHCP))==0 , noiseFloorCounts_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).noise_floor_Counts_E5_RHCP ; end


          %PowerSpreadRatio lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E1_LHCP))==0 , powerRatio_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E1_RHCP))==0 , powerRatio_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E5_LHCP))==0 , powerRatio_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E5_RHCP))==0 , powerRatio_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).PowerSpreadRatio_E5_RHCP ; end

     %HighNoiseKurtosis lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E1_LHCP))==0 , kurtosisDDM_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E1_RHCP))==0 , kurtosisDDM_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E5_LHCP))==0 , kurtosisDDM_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E5_RHCP))==0 , kurtosisDDM_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DDM_E5_RHCP ; end

     %NoiseKurtosis lines
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E1_LHCP))==0 , kurtosisDopp0_1_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E1_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E1_RHCP))==0 , kurtosisDopp0_1_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E1_RHCP ; end

     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E5_LHCP))==0 , kurtosisDopp0_5_L(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E5_LHCP ; end
     if min(ismissing(ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E5_RHCP))==0 , kurtosisDopp0_5_R(intrack:fintrack)=ReflectionCoefficientAtSP(kk).Kurtosis_DOPP_0_E5_RHCP ; end

     %Sigma0 lines
     if min(ismissing(Sigma0(kk).NBRCS_E1_LHCP))==0 , NBRCS_1_L(intrack:fintrack)=Sigma0(kk).NBRCS_E1_LHCP ; end
     if min(ismissing(Sigma0(kk).NBRCS_E1_RHCP))==0 , NBRCS_1_R(intrack:fintrack)=Sigma0(kk).NBRCS_E1_RHCP ; end

     if min(ismissing(Sigma0(kk).NBRCS_E5_LHCP))==0 , NBRCS_5_L(intrack:fintrack)=Sigma0(kk).NBRCS_E5_LHCP ; end
     if min(ismissing(Sigma0(kk).NBRCS_E5_RHCP))==0 , NBRCS_5_R(intrack:fintrack)=Sigma0(kk).NBRCS_E5_RHCP ; end


  end % end case over the satgellite
end % end fir over the tracks

% Sigma0 carries the raw DDM arrays for every track and is not read past this
% point (last use is in the loop above). Release it before the land filter and
% the save, which are the peak-memory part of the run. "clear global" is needed:
% a plain "clear" would only drop the local link and leave the data allocated.
% ReflectionCoefficientAtSP cannot be released here, it is this function's
% declared return value.
clear global Sigma0

%  
Nameout=[char(Outfileprefix) '_' char(datetime('now','Format','yy-MM-dd_HH-mm'),'yy-MM-dd_HH-mm') '.mat'] ; 
%
%QualityControlFlags = QC_pass_flag;  % create the new variable
pseudoRandomNoise = PRN;
receivingSpacecraft = SVN;
transmittingSpacecraft = SAT;
%Kurtosis_DDM = HighNoiseKurtosis; 
%Kurtosis_DOPP_0 = NoiseKurtosis;
incidenceAngleDeg = THETA;
%spAzimuthAngleDegOrbit = SPAzimuthARF



% Initialize string array of same size as GNSSConstellation
constellation = strings(size(GNSSConstellation));  

% Assign values based on GNSSConstellation
constellation(GNSSConstellation == 0) = "GPS";
constellation(GNSSConstellation == 2) = "Galileo";

% Optional: mark unknowns
constellation(~(GNSSConstellation==0 | GNSSConstellation==2)) = "Unknown";

%powerAnalogW_L1_R = 10.^(powerAnalogWdbw_L1_R / 10);
%powerAnalogW_L1_L = 10.^(powerAnalogWdbw_L1_L / 10);
%powerAnalogW_E1_R = 10.^(powerAnalogWdbw_E1_R / 10);
%powerAnalogW_E1_L = 10.^(powerAnalogWdbw_E1_L / 10);
powerAnalogW_5_R  = 10.^(powerAnalogWdbw_5_R  / 10);
powerAnalogW_5_L  = 10.^(powerAnalogWdbw_5_L  / 10);
powerAnalogW_1_L  = 10.^(powerAnalogWdbw_1_L  / 10);
powerAnalogW_1_R  = 10.^(powerAnalogWdbw_1_R  / 10);

notToBeUsed_5_L  = single( (kurtosisDopp0_5_L  == 1) | (DirectSignalInDDM_5_L  == 1) );
notToBeUsed_5_R  = single( (kurtosisDopp0_5_R  == 1) | (DirectSignalInDDM_5_R  == 1) );

notToBeUsed_1_L = single( (kurtosisDopp0_1_L == 1) | (DirectSignalInDDM_1_L == 1) );
notToBeUsed_1_R = single( (kurtosisDopp0_1_R == 1) | (DirectSignalInDDM_1_R == 1) );

%notToBeUsed_L1_L = single( (kurtosisDopp0_L1_L == 1) | (DirectSignalInDDM_L1_L == 1) );
%notToBeUsed_L1_R = single( (kurtosisDopp0_L1_R == 1) | (DirectSignalInDDM_L1_R == 1) );
%%%%%%%%%%%%%%%%%%% select Land data is require
%Water=210, Snow_and_ice=220
if strcmpi(DataFilter, 'Land') 
LandSPindx=find(Landtypesub<210) ; 
%
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: selecting land data with LandType < 210']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: selectin land data with LandType < 210']) ; 
    fprintf(logfileID,'\n') ;    

% -------------------------------
% NEW: Ocean mask logic (HydroGNSS_extract version)
% -------------------------------

validLL = ~(isnan(specularPointLat) | isnan(specularPointLon));

if ~any(validLL)
    return;
end

% [idxCols, idxRows] = Utilities.easeconv_grid( ...
[idxCols, idxRows] = easeconv_grid3( ...
    specularPointLat(validLL), ...
    specularPointLon(validLL), ...
    SpatialResolution);

disp('seaMask size:');
disp(size(seaMask));

disp('idxRows range:');
disp([min(idxRows), max(idxRows)]);

disp('idxCols range:');
disp([min(idxCols), max(idxCols)]);

nRows = size(seaMask,2);
nCols = size(seaMask,1);

% Clip indices to mask size
idxRows = min(max(idxRows,1), nRows);
idxCols = min(max(idxCols,1), nCols);

% ✅ ADD THIS (sanity check)
assert(all(idxRows >= 1 & idxRows <= nRows), 'Row indices out of range');
assert(all(idxCols >= 1 & idxCols <= nCols), 'Column indices out of range');

% Safe indexing. seaMask is [nCols x nRows] (see the size() call where the mask is
% loaded) and easeconv_grid3 returns the column first, so the subscripts go in
% that order: dimension 1 is indexed by idxCols, dimension 2 by idxRows.
linearIdx = sub2ind([nCols, nRows], idxCols, idxRows);
validIdx = find(validLL);

isOceanValid = isnan(seaMask(linearIdx));

oceanIdx = validIdx(isOceanValid);
% safer reconstruction (recommended)
% LandSPindx = intersect(LandSPindx, validIdx(~isOceanValid));
LandSPindx = validIdx(~isOceanValid);

fprintf('Total valid points: %d\n', length(validIdx));
fprintf('Ocean points: %d\n', sum(isOceanValid));
fprintf('Land points: %d\n', sum(~isOceanValid));
origLand = Landtypesub < 210;

fprintf('Original land count: %d\n', sum(origLand));
fprintf('Mask-only land count: %d\n', sum(~isOceanValid));
fprintf('Combined land count: %d\n', length(LandSPindx));

%Onboardspeclat','Onboardspeclon
ReceiverSubSatLatitude_all = ReceiverSubSatLatitude_all(LandSPindx);
ReceiverSubSatLongitude_all = ReceiverSubSatLongitude_all(LandSPindx);
ReceiverPositionX_all = ReceiverPositionX_all(LandSPindx);
Onboardspeclat=Onboardspeclat(LandSPindx) ;
Onboardspeclon=Onboardspeclon(LandSPindx) ;
specularPointLat=specularPointLat(LandSPindx) ;
specularPointLon=specularPointLon(LandSPindx) ;
% specularPointLat=specularPointLat(LandSPindx) ;
% specularPointLon=specularPointLon(LandSPindx) ;

Landtypesub=Landtypesub(LandSPindx) ;
SixHourDir=SixHourDir(LandSPindx) ;
incidenceAngleDeg=incidenceAngleDeg(LandSPindx) ;
spAzimuthAngleDegOrbit=spAzimuthAngleDegOrbit(LandSPindx) ;
dayOfYear=dayOfYear(LandSPindx) ;
secondOfDay=secondOfDay(LandSPindx) ;
timeUTC=timeUTC(LandSPindx) ;
reflectivityLinear_1_L=reflectivityLinear_1_L(LandSPindx) ;
reflectivityLinear_1_R=reflectivityLinear_1_R(LandSPindx) ;
reflectivityLinear_5_L=reflectivityLinear_5_L(LandSPindx) ;
reflectivityLinear_5_R=reflectivityLinear_5_R(LandSPindx) ;
SNR_5_L=SNR_5_L(LandSPindx) ;
SNR_5_R=SNR_5_R(LandSPindx) ;
SNR_1_L=SNR_1_L(LandSPindx) ;
SNR_1_R=SNR_1_R(LandSPindx) ;
EIRP_1=EIRP_1(LandSPindx) ;
EIRP_5=EIRP_5(LandSPindx) ;
rxAntennaGain_1_R=rxAntennaGain_1_R(LandSPindx) ;
rxAntennaGain_1_L=rxAntennaGain_1_L(LandSPindx) ;
rxAntennaGain_5_R=rxAntennaGain_5_R(LandSPindx) ;
rxAntennaGain_5_L=rxAntennaGain_5_L(LandSPindx) ;
ReflectionCoefficientAtSP_CM1_1_R=ReflectionCoefficientAtSP_CM1_1_R(LandSPindx) ;
ReflectionCoefficientAtSP_CM1_1_L=ReflectionCoefficientAtSP_CM1_1_L(LandSPindx) ;
ReflectionCoefficientAtSP_CM1_5_R=ReflectionCoefficientAtSP_CM1_5_R(LandSPindx) ;
ReflectionCoefficientAtSP_CM1_5_L=ReflectionCoefficientAtSP_CM1_5_L(LandSPindx) ;
ReflectionCoefficientAtSP_CM2_1_R=ReflectionCoefficientAtSP_CM2_1_R(LandSPindx) ;
ReflectionCoefficientAtSP_CM2_1_L=ReflectionCoefficientAtSP_CM2_1_L(LandSPindx) ;
ReflectionCoefficientAtSP_CM2_5_R=ReflectionCoefficientAtSP_CM2_5_R(LandSPindx) ;
ReflectionCoefficientAtSP_CM2_5_L=ReflectionCoefficientAtSP_CM2_5_L(LandSPindx) ;
ReflectionCoefficientAtSP_CM3_1_R=ReflectionCoefficientAtSP_CM3_1_R(LandSPindx) ;
ReflectionCoefficientAtSP_CM3_1_L=ReflectionCoefficientAtSP_CM3_1_L(LandSPindx) ;
ReflectionCoefficientAtSP_CM3_5_R=ReflectionCoefficientAtSP_CM3_5_R(LandSPindx) ;
ReflectionCoefficientAtSP_CM3_5_L=ReflectionCoefficientAtSP_CM3_5_L(LandSPindx) ;
ReflectionCoefficientUnbounded_1_R=ReflectionCoefficientUnbounded_1_R(LandSPindx) ;
ReflectionCoefficientUnbounded_1_L=ReflectionCoefficientUnbounded_1_L(LandSPindx) ;
ReflectionCoefficientUnbounded_5_R=ReflectionCoefficientUnbounded_5_R(LandSPindx) ;
ReflectionCoefficientUnbounded_5_L=ReflectionCoefficientUnbounded_5_L(LandSPindx) ;
coherencyRatio_1_R=coherencyRatio_1_R(LandSPindx) ;
coherencyRatio_1_L=coherencyRatio_1_L(LandSPindx) ;
coherencyRatio_5_R=coherencyRatio_5_R(LandSPindx) ;
coherencyRatio_5_L=coherencyRatio_5_L(LandSPindx) ;
qualityControlFlags_1_R=qualityControlFlags_1_R(LandSPindx) ;
qualityControlFlags_1_L=qualityControlFlags_1_L(LandSPindx) ;
qualityControlFlags_5_R=qualityControlFlags_5_R(LandSPindx) ;
qualityControlFlags_5_L=qualityControlFlags_5_L(LandSPindx) ;
powerAnalogW_1_R=powerAnalogW_1_R(LandSPindx) ;
powerAnalogW_1_L=powerAnalogW_1_L(LandSPindx) ;
powerAnalogW_5_R=powerAnalogW_5_R(LandSPindx) ;
powerAnalogW_5_L=powerAnalogW_5_L(LandSPindx) ;
NBRCS_1_R=NBRCS_1_R(LandSPindx) ;
NBRCS_1_L=NBRCS_1_L(LandSPindx) ;
NBRCS_5_R=NBRCS_5_R(LandSPindx) ;
NBRCS_5_L=NBRCS_5_L(LandSPindx) ;
powerRatio_1_R=powerRatio_1_R(LandSPindx) ;
powerRatio_1_L=powerRatio_1_L(LandSPindx) ;
powerRatio_5_R=powerRatio_5_R(LandSPindx) ;
powerRatio_5_L=powerRatio_5_L(LandSPindx) ;
kurtosisDDM_1_R=kurtosisDDM_1_R(LandSPindx) ;
kurtosisDDM_1_L=kurtosisDDM_1_L(LandSPindx) ;
kurtosisDDM_5_R=kurtosisDDM_5_R(LandSPindx) ;
kurtosisDDM_5_L=kurtosisDDM_5_L(LandSPindx) ;
kurtosisDopp0_1_R=kurtosisDopp0_1_R(LandSPindx) ;
kurtosisDopp0_1_L=kurtosisDopp0_1_L(LandSPindx) ;
kurtosisDopp0_5_R=kurtosisDopp0_5_R(LandSPindx) ;
kurtosisDopp0_5_L=kurtosisDopp0_5_L(LandSPindx) ;
pseudoRandomNoise=pseudoRandomNoise(LandSPindx) ;
receivingSpacecraft=receivingSpacecraft(LandSPindx) ;
constellation=constellation(LandSPindx) ;
noiseFloorCounts_1_R=noiseFloorCounts_1_R(LandSPindx) ;
noiseFloorCounts_1_L=noiseFloorCounts_1_L(LandSPindx) ;
noiseFloorCounts_5_R=noiseFloorCounts_5_R(LandSPindx) ;
noiseFloorCounts_5_L=noiseFloorCounts_5_L(LandSPindx) ;
notToBeUsed_5_L=notToBeUsed_5_L(LandSPindx) ;
notToBeUsed_5_R=notToBeUsed_5_R(LandSPindx) ;
notToBeUsed_1_L=notToBeUsed_1_L(LandSPindx) ;
notToBeUsed_1_R=notToBeUsed_1_R(LandSPindx) ; 
else
%
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: keeping all data over land and ocean']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: keeping all data over land and ocean']) ; 
    fprintf(logfileID,'\n') ;    
%
end
%
%%%%%%%%%%%%%%%%%% end select land data

save([char(DataOutputRootPath) '\' Nameout], 'ReceiverSubSatLatitude_all',...
    'ReceiverSubSatLongitude_all','ReceiverPositionX_all','Onboardspeclat',...
    'Onboardspeclon','specularPointLat', 'specularPointLon', 'incidenceAngleDeg',...
    'spAzimuthAngleDegOrbit', 'dayOfYear',  'secondOfDay', 'Landtypesub', 'SixHourDir', 'timeUTC',...
    'reflectivityLinear_1_L', 'reflectivityLinear_1_R', ...
    'reflectivityLinear_5_L', 'reflectivityLinear_5_R',...
    'SNR_5_L', 'SNR_5_R', 'SNR_1_L', 'SNR_1_R', ...
    'EIRP_1','EIRP_5',...
    'rxAntennaGain_1_R','rxAntennaGain_1_L','rxAntennaGain_5_R','rxAntennaGain_5_L', ...
    'ReflectionCoefficientAtSP_CM1_1_R','ReflectionCoefficientAtSP_CM1_1_L','ReflectionCoefficientAtSP_CM1_5_R','ReflectionCoefficientAtSP_CM1_5_L', ...
    'ReflectionCoefficientAtSP_CM2_1_R','ReflectionCoefficientAtSP_CM2_1_L','ReflectionCoefficientAtSP_CM2_5_R','ReflectionCoefficientAtSP_CM2_5_L', ...
    'ReflectionCoefficientAtSP_CM3_1_R','ReflectionCoefficientAtSP_CM3_1_L','ReflectionCoefficientAtSP_CM3_5_R','ReflectionCoefficientAtSP_CM3_5_L', ...
    'ReflectionCoefficientUnbounded_1_R','ReflectionCoefficientUnbounded_1_L','ReflectionCoefficientUnbounded_5_R','ReflectionCoefficientUnbounded_5_L', ...
    'coherencyRatio_1_R','coherencyRatio_1_L', 'coherencyRatio_5_R','coherencyRatio_5_L', ...
    'qualityControlFlags_1_R','qualityControlFlags_1_L','qualityControlFlags_5_R','qualityControlFlags_5_L', ...
    'powerAnalogW_1_R','powerAnalogW_1_L','powerAnalogW_5_R','powerAnalogW_5_L',...
    'NBRCS_1_R','NBRCS_1_L','NBRCS_5_R','NBRCS_5_L', ...
    'powerRatio_1_R','powerRatio_1_L','powerRatio_5_R','powerRatio_5_L', ...
    'kurtosisDDM_1_R','kurtosisDDM_1_L','kurtosisDDM_5_R','kurtosisDDM_5_L',...
    'kurtosisDopp0_1_R','kurtosisDopp0_1_L','kurtosisDopp0_5_R','kurtosisDopp0_5_L',...
    'pseudoRandomNoise', 'receivingSpacecraft', 'constellation', ...
    'noiseFloorCounts_1_R','noiseFloorCounts_1_L','noiseFloorCounts_5_R','noiseFloorCounts_5_L', ...
    'notToBeUsed_5_L','notToBeUsed_5_R','notToBeUsed_1_L','notToBeUsed_1_R') ; 


 disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: End of program']) ; 
 %fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: End of program']) ; 
 %fprintf(logfileID,'\n') ; 