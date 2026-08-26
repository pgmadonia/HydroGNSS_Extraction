function [ProcessingSatellite, DataInputRootPath, DataOutputRootPath, Outfileprefix, LogsOutputRootPath, LatSouth, LatNorth, LonWest, LonEast, Dayinit, Dayfinal, DDM, DataFilter] = ReadConfFile(configurationPath)
%%%%%%%  Read configuration file
%
            lines = string(splitlines(fileread(configurationPath)));
%         
            ConfigRightLine= contains(lines,'ProcessingSatellite')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            ProcessingSatellite= extractAfter(lines(ConfigRightLine),startIndex) ;         
%%         
            ConfigRightLine= contains(lines,'DataInputRootPath')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            DataInputRootPath= extractAfter(lines(ConfigRightLine),startIndex) ;
%%         
            ConfigRightLine= contains(lines,'DataOutputRootPath')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            DataOutputRootPath= extractAfter(lines(ConfigRightLine),startIndex) ;
%%         
            ConfigRightLine= contains(lines,'Outfileprefix')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            Outfileprefix= extractAfter(lines(ConfigRightLine),startIndex) ;
%%         
            ConfigRightLine= contains(lines,'LogsOutputRootPath')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            LogsOutputRootPath= extractAfter(lines(ConfigRightLine),startIndex) ;
%%                  
            ConfigRightLine= contains(lines,'LatSouth')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            LatSouth= extractAfter(lines(ConfigRightLine),startIndex) ; % max distance between SP and SMAP grid cell in meters
            LatSouth=double(LatSouth) ; 

            %%                  
            ConfigRightLine= contains(lines,'LatNorth')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            LatNorth= extractAfter(lines(ConfigRightLine),startIndex) ; % max distance between SP and SMAP grid cell in meters
            LatNorth=double(LatNorth) ; 

%%                  
            ConfigRightLine= contains(lines,'LonWest')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            LonWest= extractAfter(lines(ConfigRightLine),startIndex) ; % 
            LonWest=double(LonWest) ; 
            %%                  
            ConfigRightLine= contains(lines,'LonEast')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            LonEast= extractAfter(lines(ConfigRightLine),startIndex) ; % 
            LonEast=double(LonEast) ; 

            %%                  
            ConfigRightLine= contains(lines,'Dayinit')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            Dayinit= extractAfter(lines(ConfigRightLine),startIndex) ; %
            % Dayinit stays a string: HydroGNSS_extract parses it with datetime()

            %%                  
            ConfigRightLine= contains(lines,'Dayfinal')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            Dayfinal= extractAfter(lines(ConfigRightLine),startIndex) ; %

            %%                  
            ConfigRightLine= contains(lines,'DDM')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            DDM= extractAfter(lines(ConfigRightLine),startIndex) ; % 
                        %%                  
            ConfigRightLine= contains(lines,'DataFilter')  ;  
            ConfigRightLine= find(ConfigRightLine==1)  ;   
            startIndex= regexp(lines(ConfigRightLine),'=') ; 
            DataFilter= extractAfter(lines(ConfigRightLine),startIndex) ; % 
            %%
end