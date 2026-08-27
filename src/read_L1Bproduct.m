%syed
function [DataTag, noday, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion]=read_L1Bproduct(DataTag, Day_to_process,...
    SM_Time_resolution, Path_HydroGNSS_Data, metadata_name, readDDM, ...
    DDMs_name, Track_ID, IND_sixhours, L1b_ProcessorVersion, L1a_ProcessorVersion,...
    LatSouth, LatNorth, LonWest, LonEast) ; 
%
% Track_ID: ID of the track written in the output structure which
% starts from the one the previous day
noday=0 ;
% Geographic box from the configuration, applied while reading so that points
% outside the area of interest are never accumulated. The bounds are kept in the
% caller's convention; only the product longitudes are normalised, at the point
% of comparison, so a global box (-180..180) still passes everything.
LatSouth = double(LatSouth) ; LatNorth = double(LatNorth) ;
LonWest  = double(LonWest)  ; LonEast  = double(LonEast)  ; 
global namelogfile logfileID  ; 
global ReflectionCoefficientAtSP Sigma0 ; 
%a
% ReflectionCoefficientAtSP={}  ; removed as it is initialized outside
% Sigma0={}  ; ReflectionCoefficientAtSP
% DataTag="" ; 
%
% ***********  loop on number of days to process for a single map
formatSpec='%02u' ; 
for j=1: SM_Time_resolution ; 
    SM_Day=Day_to_process+j-1  ; 
Month=month(SM_Day)  ; Day=day(SM_Day)   ; Year=year(SM_Day)   ; 
Path_L1B_day=[char(Path_HydroGNSS_Data), '\', num2str(Year), '-', num2str(Month, formatSpec),'\', num2str(Day,formatSpec)] ;
%
if exist(Path_L1B_day)==0 ; %, disp(['Directory of day ' char(SM_Day) ' does not exist. Skipped']), 
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: Directory of day ' char(SM_Day) ' does not exist. Skipped']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: Directory of day ' char(SM_Day) ' does not exist. Skipped']) ; 
    fprintf(logfileID,'\n') ; 
noday=1; 
continue 
end 


%
D=dir(Path_L1B_day) ; 
Num_sixhours=0 ; 
if length(D)==0 % , disp(['No L1B data found in directory of day ' char(SM_Day)]), 
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: No L1B data found in directory of day ' char(SM_Day) '. Skipped']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: Directory of day ' char(SM_Day) ' does not exist. Skipped']) ; 
    fprintf(logfileID,'\n') ; 
    noday=1 ; 
    return 
end; 
for jj=3:length(D)  ; % 
% if D(jj).isdir==1 & exist([Path_L1B_day,'\',char(D(jj).name),'\',metadata_name])>0, Num_sixhours=Num_sixhours+1 ;  end  ;  ; 
if D(jj).isdir==1, Num_sixhours=Num_sixhours+1 ;  end  ;  ; 
end   

if Num_sixhours < 4
disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: less than 4 blocks when: Year=', num2str(Year), ' Month=', num2str(Month), ' Day=', num2str(Day), ' Num_sixhours=', num2str(Num_sixhours)]) ;
fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: less than four 6-hour blocks when: Year=', num2str(Year), ' Month=', num2str(Month), ' Day=', num2str(Day), ' Num_sixhours=', num2str(Num_sixhours)]) ; 
fprintf(logfileID,'\n') ;
end

% Num_sixhours=length(D)-2 ; 
% disp(['Reading Year=', num2str(Year), ' Month=', num2str(Month), ' Day=', num2str(Day), ' Num_sixhours=', num2str(Num_sixhours)]) ; 
disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: Reading Year=', num2str(Year), ' Month=', num2str(Month), ' Day=', num2str(Day), ' Num_sixhours=', num2str(Num_sixhours)]) ;
fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: Reading Year=', num2str(Year), ' Month=', num2str(Month), ' Day=', num2str(Day), ' Num_sixhours=', num2str(Num_sixhours)]) ; 
fprintf(logfileID,'\n') ;
%
% create string array with all 6-hours segments within one day 
Dir_Day=[] ; 
% DataTag=[] ; 
for jj=3:Num_sixhours+2 ; 
        Dir_Day= [Dir_Day ; D(jj).name];
end
Dir_Day=string(Dir_Day) ; 

% toc
% disp('Initiate reading loop of 6-hours') ; 
% ***************  loop on 6-hours segments within one day 
DataTag="" ; 
for jj=1:Num_sixhours  ; 
%
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: initiate reading loop of 6-hours: ' char(Dir_Day(jj))]) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: initiate reading loop of 6-hours: ' char(Dir_Day(jj))]) ; 
    fprintf(logfileID,'\n') ;    
%
if exist([Path_L1B_day,'\',char(Dir_Day(jj)),'\',metadata_name])==0
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: metadata file on ' char(datetime(Year, Month, Day)) ' block ' char(Dir_Day(jj)) ' does not exist. Program continuing']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: metadata file on ' char(datetime(Year, Month, Day)) ' block ' char(Dir_Day(jj)) ' does not exist. Program continuing']) ; 
    fprintf(logfileID,'\n') ;    
    continue
end
%

% 
% % % L1a_AlgorithmVersion = ncreadatt([Path_L1B_day,'\',char(Dir_Day(jj)),'\',metadata_name], '/', 'L1a_AlgorithmVersion');

%
infometa=ncinfo([Path_L1B_day,'\',char(Dir_Day(jj)),'\',metadata_name]) ; 
[a, Num_Groups]=size(infometa.Groups) ; 
% Num_Groups= length(netcdf.inqGrps(ncid)) ; 

IND_sixhours=IND_sixhours+1  ; 
[a b ]= size(infometa.Attributes) ; % b is the numbero of elements in main Attribute to find the "DataTag" 
for jk=1:b ,  if infometa.Attributes(jk).Name == "DataTag" , ind=jk; end, end
DataTag(IND_sixhours)=convertCharsToStrings(infometa.Attributes(ind).Value) ; 
%
% Per-block state. Drop the group-id caches left by the previous 6-hour block:
% they are indexed by track number, so a block with fewer tracks would otherwise
% keep stale ids pointing into a file that has already been closed.
clear channelNcids coinNcids channelNcids2 coinNcids2
ncid2 = -1 ;                 % DDM file handle; -1 means "not open"
readDDMsinglefile = "No" ;   % re-decided below for this block
%
% A corrupt metadata file must not abort the run any more than a corrupt DDM file.
try
ncid = netcdf.open(fullfile([Path_L1B_day,'\',char(Dir_Day(jj))],metadata_name), 'NC_NOWRITE');
catch ME
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: cannot open metadata file in block ' char(Dir_Day(jj)) ' on ' char(datetime(Year, Month, Day)) ': ' ME.message '. Block skipped, program continuing']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: cannot open metadata file in block ' char(Dir_Day(jj)) ' on ' char(datetime(Year, Month, Day)) ': ' ME.message '. Block skipped, program continuing']) ;
    fprintf(logfileID,'\n') ;
    continue
end
%
% Everything from here to the matching catch runs with ncid open, so any failure
% has to go through the catch or the handle leaks. Leaked handles accumulate over
% a long run until the OS limit is hit and netcdf.open starts failing.
try
% trackNcids = netcdf.inqGrps(ncid);
%  for track = 1:length(trackNcids)
%     channelNcids{track} = netcdf.inqGrps(trackNcids(track));    % ??? valkuare se fare un solo vettore che deve avere dumensiobni varabilim2x2 o 2x4
%     for chan = 1:length(netcdf.inqGrps(trackNcids(track)))
%         coinNcids{track}(chan,:) = netcdf.inqGrps(channelNcids{track}(chan));
%     end
%  end

trackNcids = netcdf.inqGrps(ncid);

for track = 1:length(trackNcids)
    
    channelNcids{track} = netcdf.inqGrps(trackNcids(track));
    
    for chan = 1:length(channelNcids{track})
        
        coinNcids{track}{chan} = netcdf.inqGrps(channelNcids{track}(chan));
        
    end
end
% Init reading time and RX position for all the entire data vector MP: this
% may be shifted before for 
L1b_ProcessorVersion = netcdf.getAtt(ncid,netcdf.getConstant("NC_GLOBAL"),'L1b_ProcessorVersion');
L1a_ProcessorVersion = netcdf.getAtt(ncid,netcdf.getConstant("NC_GLOBAL"),'L1a_ProcessorVersion');

%%%%%  from here we read gloabal (all tracks) quantities. It could be
%%%%%  removed ?????????????
varID=netcdf.inqVarID(ncid, 'IntegrationMidPointTime')  ;
read=netcdf.getVar(ncid,varID)  ;
IntegrationMidPointTimetot=read ; 

varID=netcdf.inqVarID(ncid, 'ReceiverPositionX')  ;
read=netcdf.getVar(ncid,varID)  ;
ReceiverPositionXtot=read ; 

varID=netcdf.inqVarID(ncid, 'ReceiverSubSatLatitude')  ;
read=netcdf.getVar(ncid,varID)  ;
ReceiverSubSatLatitudetot=read ; 

varID=netcdf.inqVarID(ncid, 'ReceiverSubSatLongitude')  ;
read=netcdf.getVar(ncid,varID)  ;
ReceiverSubSatLongitudetot=read ; 

varID=netcdf.inqVarID(ncid, 'ReceiverPositionY')  ;
read=netcdf.getVar(ncid,varID)  ;
ReceiverPositionYtot=read ; 

varID=netcdf.inqVarID(ncid, 'ReceiverPositionZ') ;
read=netcdf.getVar(ncid,varID)  ;
ReceiverPositionZtot=read ; 
% End reading RX position for all the entire data vector
%%%%% to here ?????
%%  if to open DDM file if exists and readDDM is Yes
if readDDM=="No" | readDDM=="N" , readDDMsinglefile="No" ; 
elseif exist(fullfile([Path_L1B_day,'\',char(Dir_Day(jj))],DDMs_name)) ==0 & readDDM=="Yes" | exist(fullfile([Path_L1B_day,'\',char(Dir_Day(jj))],DDMs_name)) ==0 & readDDM=="Y"; 
disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: DDM file does not exist in group ' char(string(Year)) '-' char(string(Month)) '-' char(string(Day)) '/' char(Dir_Day(jj)) '. Set DDM to "No"']) ;
fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: DDM file does not exist in group ' char(string(Year)) '-' char(string(Month)) '-' char(string(Day)) '/' char(Dir_Day(jj)) '. Set DDM to "No"']) ;
fprintf(logfileID,'\n') ;
readDDMsinglefile="No" ; 
elseif exist(fullfile([Path_L1B_day,'\',char(Dir_Day(jj))],DDMs_name)) >0 & readDDM=="Yes" |  exist(fullfile([Path_L1B_day,'\',char(Dir_Day(jj))],DDMs_name)) >0 & readDDM=="Y" 
readDDMsinglefile="Yes" ;
% A corrupt or truncated DDMs.nc must not take the whole run down: fall back to
% metadata-only for this block instead.
try
ncid2 = netcdf.open(fullfile([Path_L1B_day,'\',char(Dir_Day(jj))],DDMs_name), 'NC_NOWRITE');
% trackNcids2 = netcdf.inqGrps(ncid2);
% for track = 1:length(trackNcids2)
%     channelNcids2(track,:) = netcdf.inqGrps(trackNcids2(track));
%     for chan = 1:length(channelNcids2(track,:))
%         coinNcids2{track}(chan,:) = netcdf.inqGrps(channelNcids2(chan));
%     end
%  end
% 
% end
trackNcids2 = netcdf.inqGrps(ncid2);

for track = 1:length(trackNcids2)
    
    % channels inside each track
    channelNcids2{track} = netcdf.inqGrps(trackNcids2(track));
    
    for chan = 1:length(channelNcids2{track})
        
        % subgroups inside each channel (can be 1 or more!)
        coinNcids2{track}{chan} = netcdf.inqGrps(channelNcids2{track}(chan));
        
    end
end
disp(size(coinNcids2))
disp(length(coinNcids2{1}))
disp(coinNcids2{1}{1})
catch ME
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: cannot read DDM file in block ' char(Dir_Day(jj)) ': ' ME.message '. Continuing without DDMs for this block']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: cannot read DDM file in block ' char(Dir_Day(jj)) ': ' ME.message '. Continuing without DDMs for this block']) ;
    fprintf(logfileID,'\n') ;
    if ncid2 >= 0 , try, netcdf.close(ncid2) ; catch, end , end
    ncid2 = -1 ;
    readDDMsinglefile = "No" ;
end
end 
%%  end if to open DDM file if exists and readDDM is Yes
% toc
% disp('Initiate reading loop over groups') ; 
disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: Initiate reading tracks of group ' char(string(Year)) '-' char(string(Month)) '-' char(string(Day)) '/' char(Dir_Day(jj))]) ;
fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: Initiate reading tracks of group ' char(string(Year)) '-' char(string(Month)) '-' char(string(Day)) '/' char(Dir_Day(jj))]) ;
fprintf(logfileID,'\n') ;



% loop on Groups (i.e., tracks) within each 6-hours segment 
% Num_Groups=2 ; % WARNTING: this is to read only one group and speed up
firstsampleInGroup=1 ; % integer identifying the first sample of a track in the entire data vector   
for kk=1:Num_Groups ; 
% toc
% disp(['Reading Six-hour ', num2str(jj), ' of ', num2str(Num_sixhours), ' - Group/Track ', num2str(kk), ' of ', num2str(Num_Groups)]) ; 
disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: Reading Six-hour block ', char(Dir_Day(jj)), ' (', num2str(jj), ' of ', num2str(Num_sixhours), ') on ' char(datetime(Year, Month, Day)) '. Group/Track ', num2str(kk), ' of ', num2str(Num_Groups)]) ;
fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' INFO: Reading Six-hour block ', char(Dir_Day(jj)), ' (', num2str(jj), ' of ', num2str(Num_sixhours), ') on ' char(datetime(Year, Month, Day)) '. Group/Track ', num2str(kk), ' of ', num2str(Num_Groups)]) ; 
fprintf(logfileID,'\n') ;
%
[a NumberOfChannels]=size(infometa.Groups(kk).Groups) ; 
%
if NumberOfChannels > 0
% Case of HydroGNSS with several channels. Read specular point data
%
% Geographic filter, part 1 of 2. Read just the specular point coordinates and
% drop the whole track when none of its points fall inside the configured box.
% Doing this before Track_ID is incremented keeps the numbering gap-free, and
% doing it before the channel loop means a rejected track costs two small reads
% instead of ~100 variables plus its DDMs.
varIdGeo = netcdf.inqVarID(trackNcids(kk), 'SpecularPointLat');
spLatGeo = double(netcdf.getVar(trackNcids(kk), varIdGeo)) ;
varIdGeo = netcdf.inqVarID(trackNcids(kk), 'SpecularPointLon');
spLonGeo = double(netcdf.getVar(trackNcids(kk), varIdGeo)) ;
% Normalise to [-180,180) so the test holds whether the product stores 0..360.
spLonGeo = mod(spLonGeo + 180, 360) - 180 ;
if LonWest <= LonEast
    inLonGeo = spLonGeo >= LonWest & spLonGeo <= LonEast ;
else
    % Box crosses the antimeridian, so the in-range longitudes are the union.
    inLonGeo = spLonGeo >= LonWest | spLonGeo <= LonEast ;
end
keepGeo = spLatGeo >= LatSouth & spLatGeo <= LatNorth & inLonGeo ;
keepGeo = keepGeo(:) ;
if ~any(keepGeo)
    continue
end
%
Track_ID=Track_ID+1 ;
% [c d]=size(num2str(Track_ID)) ; 
% groupname='000000'; groupname(6-d+1:end)=num2str(Track_ID) ;
% ReflectionCoefficientAtSP(Track_ID).Name= groupname ; 
ReflectionCoefficientAtSP(Track_ID).Name=['Track n. ', num2str(Track_ID)] ; 
% ReflectionCoefficientAtSP(Track_ID).PRN=infometa.Groups(kk).Attributes(7).Value  ; 
ReflectionCoefficientAtSP(Track_ID).PRN=netcdf.getAtt(trackNcids(kk),netcdf.getConstant("NC_GLOBAL"),'PRN') ;
% ReflectionCoefficientAtSP(Track_ID).GNSSConstellation_units=infometa.Groups(kk).Attributes(5).Value  ; 
ReflectionCoefficientAtSP(Track_ID).GNSSConstellation_units=netcdf.getAtt(trackNcids(kk),netcdf.getConstant("NC_GLOBAL"),'GNSSConstellation') ;
% ReflectionCoefficientAtSP(Track_ID).SVN=infometa.Groups(kk).Attributes(8).Value  ; 
ReflectionCoefficientAtSP(Track_ID).SVN=netcdf.getAtt(trackNcids(kk),netcdf.getConstant("NC_GLOBAL"),'SVN') ;
% ReflectionCoefficientAtSP(Track_ID).TrackIDOrbit=infometa.Groups(kk).Attributes(2).Value  ; 
%%%%%% ReflectionCoefficientAtSP(Track_ID).TrackIDOrbit=netcdf.getAtt(trackNcids(kk),netcdf.getConstant("NC_GLOBAL"),'TrackIDOrbit') ;
%
varIdTime = netcdf.inqVarID(trackNcids(kk), 'IntegrationMidPointTime');
read=netcdf.getVar(trackNcids(kk), varIdTime);
[sizeGroup b]=size(read) ; % get the size of the group (or track) 

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name],...
%     [infometa.Groups(kk).Name, '/IntegrationMidPointTime']) ; 
ReflectionCoefficientAtSP(Track_ID).time=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'SpecularPointLat');
read=netcdf.getVar(trackNcids(kk), varId);

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name],...
%     [infometa.Groups(kk).Name, '/SpecularPointLat']) ; 
ReflectionCoefficientAtSP(Track_ID).SpecularPointLat=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'SpecularPointLon');
read=netcdf.getVar(trackNcids(kk), varId);

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name],...
%     [infometa.Groups(kk).Name, '/SpecularPointLon']) ;
ReflectionCoefficientAtSP(Track_ID).SpecularPointLon=read ; 
%
varId = netcdf.inqVarID(trackNcids(kk), 'LandType');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).LandType=read ; 
%
% Init calculate ranges 
%
varId = netcdf.inqVarID(trackNcids(kk), 'SpecularPointPositionX');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).SpecularPointPositionX=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'SpecularPointPositionY');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).SpecularPointPositionY=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'SpecularPointPositionZ');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).SpecularPointPositionZ=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'TransmitterPositionX');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).TransmitterPositionX=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'TransmitterPositionY');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).TransmitterPositionY=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'TransmitterPositionZ');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).TransmitterPositionZ=read ; 
% Extract the RX position at the correct time
%
ReceiverPositionX=zeros(sizeGroup,1)  ; 
ReceiverPositionY=zeros(sizeGroup,1)  ; 
ReceiverPositionZ=zeros(sizeGroup,1)  ; 

ReceiverSubSatLatitude=zeros(sizeGroup,1)  ;
ReceiverSubSatLongitude=zeros(sizeGroup,1)  ;
%
% for ii=1: sizeGroup   %%%% ???? This look could be removed by reading variable into groups
% indicesTime=find(IntegrationMidPointTimetot==ReflectionCoefficientAtSP(Track_ID).time(ii) ) ; 
% %
% ReceiverPositionX(ii)= ReceiverPositionXtot(indicesTime(1)) ; 
% ReceiverPositionY(ii)= ReceiverPositionYtot(indicesTime(1)) ; 
% ReceiverPositionZ(ii)= ReceiverPositionZtot(indicesTime(1)) ;
% 
% ReceiverSubSatLatitude(ii)= ReceiverSubSatLatitudetot(indicesTime(1)) ; 
% ReceiverSubSatLongitude(ii)= ReceiverSubSatLongitudetot(indicesTime(1)) ; 
% %
% end 
% idx = firstsampleInGroup:(firstsampleInGroup + sizeGroup - 1);
% 
% ReceiverPositionX = ReceiverPositionXtot(idx);
% ReceiverPositionY = ReceiverPositionYtot(idx);
% ReceiverPositionZ = ReceiverPositionZtot(idx);
% 
% ReceiverSubSatLatitude  = ReceiverSubSatLatitudetot(idx);
% ReceiverSubSatLongitude = ReceiverSubSatLongitudetot(idx);
% Reset index for each 6-hour block (IMPORTANT)
lastIdx = 1;

for ii = 1:sizeGroup

    % restrict search to forward direction only
    searchRange = lastIdx:length(IntegrationMidPointTimetot);

    % find closest time match
    [~, localIdx] = min(abs(IntegrationMidPointTimetot(searchRange) - ...
        ReflectionCoefficientAtSP(Track_ID).time(ii)));

    % convert back to global index
    idxTime = searchRange(localIdx);

    % assign receiver positions
    ReceiverPositionX(ii) = ReceiverPositionXtot(idxTime);
    ReceiverPositionY(ii) = ReceiverPositionYtot(idxTime);
    ReceiverPositionZ(ii) = ReceiverPositionZtot(idxTime);

    ReceiverSubSatLatitude(ii)  = ReceiverSubSatLatitudetot(idxTime);
    ReceiverSubSatLongitude(ii) = ReceiverSubSatLongitudetot(idxTime);

    % move pointer forward
    lastIdx = idxTime;

end
%
ReflectionCoefficientAtSP(Track_ID).ReceiverPositionX=...
      ReceiverPositionX; 
ReflectionCoefficientAtSP(Track_ID).ReceiverPositionY=...
      ReceiverPositionY ;  
ReflectionCoefficientAtSP(Track_ID).ReceiverPositionZ=...
      ReceiverPositionZ ;  

ReflectionCoefficientAtSP(Track_ID).ReceiverSubSatLatitude=...
      ReceiverSubSatLatitude; 
ReflectionCoefficientAtSP(Track_ID).ReceiverSubSatLongitude=...
      ReceiverSubSatLongitude; 
firstsampleInGroup = firstsampleInGroup + sizeGroup;
%
% ReflectionCoefficientAtSP(Track_ID).ReceiverPositionX=...
%     ReceiverPositionXtot(firstsampleInGroup: firstsampleInGroup+sizeGroup-1) ;  
% 
% ReflectionCoefficientAtSP(Track_ID).ReceiverPositionY=...
%     ReceiverPositionYtot(firstsampleInGroup: firstsampleInGroup+sizeGroup-1) ;  
% 
% ReflectionCoefficientAtSP(Track_ID).ReceiverPositionZ=...
%     ReceiverPositionZtot(firstsampleInGroup: firstsampleInGroup+sizeGroup-1) ;  
% %
% firstsampleInGroup=firstsampleInGroup+sizeGroup ; 
%
% End calculate ranges 
%
varId = netcdf.inqVarID(trackNcids(kk), 'SPIncidenceAngle');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).SPIncidenceAngle= read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'OnBoardSpecularPointLat');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).OnBoardSpecularPointLat= read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'OnBoardSpecularPointLon');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).OnBoardSpecularPointLon= read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'SPAzimuthORF');
read=netcdf.getVar(trackNcids(kk), varId);
ReflectionCoefficientAtSP(Track_ID).SPAzimuthORF= read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'SPAzimuthARF');
read=netcdf.getVar(trackNcids(kk), varId);
% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name],...
%     [infometa.Groups(kk).Name,'/SPAzimuthARF']) ;
ReflectionCoefficientAtSP(Track_ID).PAzimuthARF=read ; 

varId = netcdf.inqVarID(trackNcids(kk), 'ReflectionHeight');
read=netcdf.getVar(trackNcids(kk), varId);
% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name],...
%     [infometa.Groups(kk).Name,'/ReflectionHeight']) ;
ReflectionCoefficientAtSP(Track_ID).ReflectionHeight= read ; 
% Identify six hor directory to write 
ReflectionCoefficientAtSP(Track_ID).SixHourDir=string([num2str(Year),'-', num2str(Month, formatSpec),'\',num2str(Day,formatSpec), '\',char(Dir_Day(jj))]) ;  
%
% ii count the channels in each track 
for ii=1:NumberOfChannels ; % Loop on reading of variables inside incoherent group of each channel 'ii' (max 4) in track 'kk' 
%
% Find polarization and channel (Galileo E1, E5 or GPS L1, L5)
Polarization=infometa.Groups(kk).Groups(ii).Attributes(4).Value ; % polarization LHCP or RHCP
% Change by Mauro to fix bug on name of signal without undescore
infometa.Groups(kk).Groups(ii).Attributes(3).Value=replace(infometa.Groups(kk).Groups(ii).Attributes(3).Value, ' ', '_') ; 
% end change
%r
Signal=split(infometa.Groups(kk).Groups(ii).Attributes(3).Value, '_') ; 
ReflectionCoefficientAtSP(Track_ID).Satellite=Signal{1} ; 
Signal_Pol=[Signal{2}, '_', Polarization] ; 
switch Signal{1} 
    case 'GPS'
        switch Signal_Pol 
            case 'L1_LHCP' 
%                 ['ReflectionCoefficientAtSP', '.', Signal{2}, '_', Polarization] 

% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ;
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from "incoherent measurement variables"
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_L1_LHCP=FlagL1b  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).L1_LHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L1_LHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_L1_LHCP=read  ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L1_LHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L1_LHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_L1_LHCP=read ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_L1_LHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L1_LHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L1_LHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_L1_LHCP=read ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_L1_LHCP=read ; 

%varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
%read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
%ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_L1_LHCP=read ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_L1_LHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_L1_LHCP=read ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_L1_LHCP=read ; 
if readDDMsinglefile=="Yes" || readDDMsinglefile=="Y"
    
    varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
    read = netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

%     if length(coinNcids2{kk}{ii}) == 2 
%         
%         varId = netcdf.inqVarID(coinNcids2{kk}{ii}(2), 'CoherentIntegrationMidPointTime'); 
%         read = netcdf.getVar(coinNcids2{kk}{ii}(2), varId, 'double');
%         ReflectionCoefficientAtSP(Track_ID).CoherentIntegrationMidPointTime = read; 
%         
%         varId = netcdf.inqVarID(coinNcids2{kk}{ii}(2), 'IValues'); 
%         read = netcdf.getVar(coinNcids2{kk}{ii}(2), varId);
%         
%         varId = netcdf.inqVarID(coinNcids2{kk}{ii}(2), 'QValues'); 
%         read2 = netcdf.getVar(coinNcids2{kk}{ii}(2), varId);
%         
%         ReflectionCoefficientAtSP(Track_ID).Complex = complex(read, read2); 
% 
%         % --- Latitudes ---
%         found = false;
%         for sub = 1:length(coinNcids2{kk}{ii})
%             try
%                 varId = netcdf.inqVarID(coinNcids2{kk}{ii}(sub), 'Latitudes_CoherentInt');
%                 read = netcdf.getVar(coinNcids2{kk}{ii}(sub), varId);
%                 ReflectionCoefficientAtSP(Track_ID).Latitudes_CoherentInt = read;
%                 found = true;
%                 break
%             catch
%             end
%         end
%         if ~found
%             ReflectionCoefficientAtSP(Track_ID).Latitudes_CoherentInt = [];
%         end
% 
%         % --- Longitudes ---
%         found = false;
%         for sub = 1:length(coinNcids2{kk}{ii})
%             try
%                 varId = netcdf.inqVarID(coinNcids2{kk}{ii}(sub), 'Longitudes_CoherentInt');
%                 read = netcdf.getVar(coinNcids2{kk}{ii}(sub), varId);
%                 ReflectionCoefficientAtSP(Track_ID).Longitudes_CoherentInt = read;
%                 found = true;
%                 break
%             catch
%             end
%         end
%         if ~found
%             ReflectionCoefficientAtSP(Track_ID).Longitudes_CoherentInt = [];
%         end
% 
%     end

    Sigma0(Track_ID).DDMs = read; 

end

            case 'L1_RHCP'

% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_L1_RHCP=FlagL1b  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).L1_RHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L1_RHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_L1_RHCP=read  ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L1_RHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L1_RHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_L1_RHCP=read ;   

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L1_RHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L1_RHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_L1_RHCP=read ;



varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_L1_RHCP=read ;   


% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_L1_RHCP=read ; 


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_L1_RHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_L1_RHCP=read ;   

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_L1_RHCP=read ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_L1_RHCP=read ;   


if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"

varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;

Sigma0(Track_ID).DDMs=read ; 
end
            case 'L5_LHCP' 

                % Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_L5_LHCP=FlagL1b  ; 

% April 2023 %end 
% Read flags for each channel 
%
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).L5_LHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L5_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L5_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L5_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L5_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L5_LHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L5_LHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_L5_LHCP=read  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_L5_LHCP=read ;

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L5_LHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L5_LHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_L5_LHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_L5_LHCP=read ;

% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_L5_LHCP=read ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_L5_LHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_L5_LHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_L5_LHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_L5_LHCP= read ; 

if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"

varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;
Sigma0(Track_ID).DDMs=read ; 
end

            case 'L5_RHCP' 

% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 


% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_L5_RHCP=FlagL1b  ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).L5_RHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_L5_RHCP=nan ;
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_L5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_L5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_L5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L5_RHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_L5_RHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_L5_RHCP=read  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_L5_RHCP=read ;

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L5_RHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_L5_RHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_L5_RHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_L5_RHCP=read ;


% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_L5_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_L5_RHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_L5_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_L5_RHCP=read ;

%
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/Sigma0']) ;
Sigma0(Track_ID).NBRCS_L5_RHCP=read ; 

if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"

varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;
Sigma0(Track_ID).DDMs=read ; 
end

      otherwise
%         disp('NO GPS signal') 
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: NO GPS signal']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: NO GPS signal']) ; 
    fprintf(logfileID,'\n') ;

      end  % end switch case GPS 
    
case 'Galileo'
    
    switch Signal_Pol 
      case 'E1_LHCP' 
%                 ['ReflectionCoefficientAtSP', '.', Signal{2}, '_', Polarization] 
% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_E1_LHCP=FlagL1b  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).E1_LHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E1_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E1_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E1_LHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E1_LHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_E1_LHCP=read  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_E1_LHCP=read ;

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E1_LHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E1_LHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_E1_LHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_E1_LHCP=read ;

% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_E1_LHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_E1_LHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_E1_LHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_E1_LHCP=read ;



varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_E1_LHCP=read ; 

if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"

varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;
Sigma0(Track_ID).DDMs=read ; 
end

      case 'E1_RHCP'

% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_E1_RHCP=FlagL1b  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');          
ReflectionCoefficientAtSP(Track_ID).E1_RHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E1_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E1_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E1_RHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E1_RHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_E1_RHCP=read  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_E1_RHCP=read ;

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E1_RHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E1_RHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_E1_RHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_E1_RHCP=read ;

% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_E1_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_E1_RHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_E1_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_E1_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_E1_RHCP=read ;       

if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"

varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;
Sigma0(Track_ID).DDMs=read ; 
end

        case 'E5_LHCP' 
            
% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_E5_LHCP=FlagL1b  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');               
ReflectionCoefficientAtSP(Track_ID).E5_LHCP= read ; 


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E5_LHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E5_LHCP=nan ;     
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E5_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E5_LHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E5_LHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E5_LHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E5_LHCP=nan ; 
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_E5_LHCP=read  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_E5_LHCP=read ;

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E5_LHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E5_LHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_E5_LHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_E5_LHCP=read ;

% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_E5_LHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_E5_LHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_E5_LHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_E5_LHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_E5_LHCP=read ; 

if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"

varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;
Sigma0(Track_ID).DDMs=read ; 
end
        case 'E5_RHCP' 
    
% Read flags for each channel 
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varIdch =netcdf.inqGrps(channelNcids{kk}(ii)) ; 
varId=netcdf.inqVarID(varIdch(1), 'DirectSignalInDDM') ; 
read=netcdf.getVar(varIdch(1), varId) ; 
FlagL1b=read ; 

% April 2023 % reading 'LowAGSP', 'LowSNR', 'VeryLowSNR', and 'HighNoiseKurtosis' from incoherent measurement variables
% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowAGSP') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*2 ; 

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'LowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*4 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'VeryLowSNR') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*8 ;

% varIdch = netcdf.inqGrps(channelNcids(kk,ii));
varId=netcdf.inqVarID(varIdch(1), 'HighNoiseKurtosis') ; 
read=netcdf.getVar(varIdch(1), varId) ;
FlagL1b=FlagL1b+read.*16 ;
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DDM_E5_RHCP=FlagL1b  ;
              
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).E5_RHCP=read ; 

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM1');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM1_E5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM2');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM2_E5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientAtSP_CM3');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientAtSP_CM3_E5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'ReflectionCoefficientUnbounded');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E5_RHCP=read ; 
catch
ReflectionCoefficientAtSP(Track_ID).ReflectionCoefficientUnbounded_E5_RHCP=nan ; 
end

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'PowerSpreadRatio');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E5_RHCP=read  ; 
catch
ReflectionCoefficientAtSP(Track_ID).PowerSpreadRatio_E5_RHCP=nan ; 
end 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DDMSNRAtPeakSingleDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).SNR_E5_RHCP=read  ; 

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'EIRP');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).EIRP_E5_RHCP=read ;

try
varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Coherency');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E5_RHCP=read ;
catch
ReflectionCoefficientAtSP(Track_ID).coherencyRatio_E5_RHCP=nan ;
end

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'DirectSignalInDDM');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).DirectSignalInDDM_E5_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'AntennaGainTowardsSpecularPoint');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).rxAntennaGain_E5_RHCP=read ;

% varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'QC_pass_flag');
% read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
% ReflectionCoefficientAtSP(Track_ID).QualityControlFlags_E5_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeasuredReflectedSignalPower');
read = netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).PowerAnalog_W_E5_RHCP = read;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'MeanNoise');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).noise_floor_Counts_E5_RHCP=read ;

varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'NoiseKurtosis');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
ReflectionCoefficientAtSP(Track_ID).Kurtosis_DOPP_0_E5_RHCP=read ;


varId = netcdf.inqVarID(coinNcids{kk}{ii}(1), 'Sigma0');
read=netcdf.getVar(coinNcids{kk}{ii}(1), varId, 'double');
Sigma0(Track_ID).NBRCS_E5_RHCP=read ; 

if readDDMsinglefile=="Yes" | readDDMsinglefile=="Y"
    
varId = netcdf.inqVarID(coinNcids2{kk}{ii}(1), 'DDM');  
read=netcdf.getVar(coinNcids2{kk}{ii}(1), varId, 'uint16');

% read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', DDMs_name],...
%     [infometa.Groups(kk).Name,'/', infometa.Groups(kk).Groups(ii).Name,...
%     '/Incoherent/DDM']) ;
Sigma0(Track_ID).DDMs=read ; 
end

      otherwise
%         disp('NO Galileo signal') 
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: NO Galileo signal']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: NO Galileo signal']) ; 
    fprintf(logfileID,'\n') ;

    end  % end switch case Galileo
    otherwise
%         disp('NO TX constellation') 
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: NO TX constellation']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' WARNING: NO TX constellation']) ; 
    fprintf(logfileID,'\n') ;

 end  % end switch between signals / pol 
% ReflectionCoefficientAtSP(Track_ID).Satellite=Signal{1} ; 
end       % end loop on channels
%
% Geographic filter, part 2 of 2. Every variable for this track has now been
% read, so trim them all down to the points inside the box. Whole-track metadata
% is left alone; see subsetTrackToPoints at the end of this file.
if ~all(keepGeo)
    ReflectionCoefficientAtSP(Track_ID) = subsetTrackToPoints(ReflectionCoefficientAtSP(Track_ID), keepGeo, sizeGroup, Track_ID) ;
    if Track_ID <= numel(Sigma0)
        Sigma0(Track_ID) = subsetTrackToPoints(Sigma0(Track_ID), keepGeo, sizeGroup, Track_ID) ;
    end
end
        

elseif NumberOfChannels== 0  ; 
read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/IntegrationMidPointTime']) ; 
IntegrationMidPointTime=[IntegrationMidPointTime, read'] ;  
read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/SpecularPointLat']) ; 
SpecularPointLat=[SpecularPointLat, read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/SpecularPointLon']) ;
SpecularPointLon=[SpecularPointLon, read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/SPIncidenceAngle']) ;
SPIncidenceAngle=[SPIncidenceAngle read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/OnBoardSpecularPointLat']) ;
OnBoardSpecularPointLat=[OnBoardSpecularPointLat read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/OnBoardSpecularPointLon']) ;
OnBoardSpecularPointLon=[OnBoardSpecularPointLon read'] ; 


read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/PAzimuthARF']) ;
PAzimuthARF=[PAzimuthARF read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/ReflectionHeight']) ;
ReflectionHeight=[ReflectionHeight read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\', metadata_name], ['/',...
    infometa.Groups(kk).Name,'/DDMSNRAtPeakSingleDDM']) ; 
DDMSNRAtPeakSingleDDM=[DDMSNRAtPeakSingleDDM, read'] ; 

read=ncread([Path_L1B_day,'\',char(Dir_Day(jj)),'\DDMs.nc'], ['/',...
    infometa.Groups(kk).Name,'/DDM']) ; 
DDM=cat(3, DDM, read) ; 
% Reading DDMs

% [column,row] = geo2easeGrid(SpecularPointLat,SpecularPointLon);
% AccuDDMSNR =accumarray([row column],10.^(DDMSNRAtPeakSingleDDM/10), [], @mean) ;
    end
end % end loop on number of groups/tracks
%
catch ME
% Anything that failed inside this 6-hour block lands here. Log it, close both
% handles, and move to the next block rather than aborting the whole run.
    disp([char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: block ' char(Dir_Day(jj)) ' on ' char(datetime(Year, Month, Day)) ' failed: ' ME.message '. Block skipped, program continuing']) ;
    fprintf(logfileID,[char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ERROR: block ' char(Dir_Day(jj)) ' on ' char(datetime(Year, Month, Day)) ' failed: ' ME.message '. Block skipped, program continuing']) ;
    fprintf(logfileID,'\n') ;
    try, netcdf.close(ncid) ; catch, end
    if ncid2 >= 0 , try, netcdf.close(ncid2) ; catch, end , end
    continue
end
netcdf.close(ncid) ;
% Close on the handle itself, not on the flag: the two can disagree when the DDM
% file failed to open.
if ncid2 >= 0 , netcdf.close(ncid2) ; end
end % end loop on number of six-hour blocks
end % end loop on number of days

end

function s = subsetTrackToPoints(s, keep, n, trackId)
% Keep only the specular points selected by "keep" in every per-point field of a
% track. Fields are recognised by shape: a per-point vector has n elements, and a
% DDM array carries the samples on dimension 3. Whole-track metadata is skipped
% by name, and anything else is left untouched.
%
% A field that looks per-point but is not n long is reported rather than guessed
% at: leaving one unfiltered would silently misalign it against every other field
% of the track, which is the worst way for this to fail.
global logfileID ;
metaFields = {'Name','PRN','SVN','GNSSConstellation_units','Satellite', ...
              'SixHourDir','TrackIDOrbit'} ;
flds = fieldnames(s) ;
for ff = 1:numel(flds)
    if any(strcmp(flds{ff}, metaFields)) , continue , end
    v = s.(flds{ff}) ;
    if isempty(v) , continue , end
    if isvector(v) && numel(v) == n
        s.(flds{ff}) = v(keep) ;
    elseif ndims(v) == 3 && size(v,3) == n
        s.(flds{ff}) = v(:,:,keep) ;
    elseif any(size(v) == n) || (isnumeric(v) && isvector(v) && numel(v) > 1)
        msg = [char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ...
               ' WARNING: field ' flds{ff} ' of track ' num2str(trackId) ...
               ' has size [' num2str(size(v)) '], expected ' num2str(n) ...
               ' points. Left unfiltered by the geographic filter'] ;
        disp(msg) ;
        if ~isempty(logfileID) && logfileID > 0 , fprintf(logfileID, '%s\n', msg) ; end
    end
end
end
