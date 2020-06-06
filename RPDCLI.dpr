program RPDCLI;

// Reksadata Performance Data Collector Command Line Version
// Version 2.5.0.3
// Copyright ©2016-2020, PT. Reksa Data Indonesia (Release to Public - Apache License 2.0)
// Purpose: Windows Performance Data Collector Setup and Cleaning Up
// Download the binary from http://awssg.reksadata.net/binary/rditools.zip
// Download the how-to-use doc from http://awssg.reksadata.net/doc/RPDC_Quick_Start.pdf

{$APPTYPE CONSOLE}

uses
  Forms,
  Windows,
  Classes,
  SysUtils,
  ShellAPI,
  RunElevatedSupport;

{$R *.res}

var
  tstrSQLServer,
  tstrOLAPServer : TStringList;
  strSQLInstance : String;
  boolIISExist : Boolean;
  validParamStr : Boolean;
  
type
  WinIsWow64 = function( Handle: THandle; var Iret: BOOL ): Windows.BOOL; stdcall;

Function StartProcessHidden(FileName : String; WaitForExit : Boolean) : Integer;
var
  tmpStartupInfo: TStartupInfo;
  tmpProcessInformation: TProcessInformation;
  tmpProgram: String;
  tmpRetValue : Integer;
begin
  tmpProgram := trim(FileName);
  FillChar(tmpStartupInfo, SizeOf(tmpStartupInfo), 0);
  with tmpStartupInfo do
  begin
    cb := SizeOf(TStartupInfo);
    wShowWindow := SW_HIDE;
  end;

  if CreateProcess(nil, pchar(tmpProgram), nil, nil, true, CREATE_NO_WINDOW,
    nil, nil, tmpStartupInfo, tmpProcessInformation) then
  begin
     tmpRetValue := 1;
    // loop every 10 ms
    if WaitForExit then
      begin
        while WaitForSingleObject(tmpProcessInformation.hProcess, 10) > 0 do
        begin
          Application.ProcessMessages;
        end;
        CloseHandle(tmpProcessInformation.hProcess);
        CloseHandle(tmpProcessInformation.hThread);
        tmpRetValue := 0;
      end;
  end
  else
  begin
    tmpRetValue := 9;
    RaiseLastOSError;
  end;
  StartProcessHidden := tmpRetValue;
end;

procedure GetBuildInfo(var V1, V2, V3, V4: word);
var
  VerInfoSize, VerValueSize, Dummy: DWORD;
  VerInfo: Pointer;
  VerValue: PVSFixedFileInfo;
begin
  VerInfoSize := GetFileVersionInfoSize(PChar(ParamStr(0)), Dummy);
  if VerInfoSize > 0 then
  begin
      GetMem(VerInfo, VerInfoSize);
      try
        if GetFileVersionInfo(PChar(ParamStr(0)), 0, VerInfoSize, VerInfo) then
        begin
          VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
          with VerValue^ do
          begin
            V1 := dwFileVersionMS shr 16;
            V2 := dwFileVersionMS and $FFFF;
            V3 := dwFileVersionLS shr 16;
            V4 := dwFileVersionLS and $FFFF;
          end;
        end;
      finally
        FreeMem(VerInfo, VerInfoSize);
      end;
  end;
end;

function GetBuildInfoAsString: string;
var
  V1, V2, V3, V4: word;
begin
  GetBuildInfo(V1, V2, V3, V4);
  Result := IntToStr(V1) + '.' + IntToStr(V2) + '.' +
    IntToStr(V3) + '.' + IntToStr(V4);
end;

function IAmIn64Bits: Boolean;
var
  HandleTo64BitsProcess: WinIsWow64;
  Iret                 : Windows.BOOL;
begin
  Result := False;
  HandleTo64BitsProcess := GetProcAddress(GetModuleHandle('kernel32.dll'), 'IsWow64Process');
  if Assigned(HandleTo64BitsProcess) then
  begin
    if not HandleTo64BitsProcess(GetCurrentProcess, Iret) then
    Raise Exception.Create('Invalid handle');
    Result := Iret;
  end;
end;

procedure DetectSQLServerInstancesInstalled;
var
  CMDRetVal : Integer;
  CMDStr,
  SQLinstancename,
  OLAPinstancename : String;
  OSbitness, i : Integer;
  DatFileReader : TStringList;
  fileSQLHCSTS : TextFile;
  boolTimedOut : Boolean;
begin

   strSQLInstance := '[Auto]';

   boolIISExist := False;
   DatFileReader := TStringList.Create;

   WriteLn('Checking installed SQL Instances...');
   CMDStr := 'CMD /C net start > mssqlinst.dat';
   // LogFileAdd('Running '+CMDStr);
   CMDRetVal := StartProcessHidden(CMDStr,True);
   Sleep(2500);

   If CMDRetVal = 0 Then
     Begin
       WriteLn('Analyzing running services...');

       DatFileReader.LoadFromFile('mssqlinst.dat');

       for i := 0 to DatFileReader.Count-1 do begin

          If (Copy(Trim(DatFileReader[i]),1,Length('SQL Server (')) = 'SQL Server (') Then
             begin
               SQLinstancename := Copy(
                                         Trim(DatFileReader[i]),
                                         Length('SQL Server (')+1,
                                         Pos(')', Trim(DatFileReader[i]))-Length('SQL Server (')-1
                                       );
               WriteLn('Found installed SQL Instance: '+SQLinstancename);
               tstrSQLServer.Add(SQLinstancename);
             end;

          If (Copy(Trim(DatFileReader[i]),1,Length('SQL Server Analysis Services (')) = 'SQL Server Analysis Services (') Then
             begin
               OLAPinstancename := Copy(
                                         Trim(DatFileReader[i]),
                                         Length('SQL Server Analysis Services (')+1,
                                         Pos(')', Trim(DatFileReader[i]))-Length('SQL Server Analysis Services (')-1
                                       );
               WriteLn('Found installed OLAP Instance: '+OLAPinstancename);
               tstrOLAPServer.Add(OLAPinstancename);
             end;

            If (Copy(Trim(DatFileReader[i]),1,Length('World Wide Web Publishing Service')) = 'World Wide Web Publishing Service') Then
             begin
               WriteLn('Found installed IIS Instance.');
               boolIISExist := True;
             end;

       end;

       If (tstrSQLServer.Count = 1) AND (Trim(tstrSQLServer[0]) = 'MSSQLSERVER') Then // this logic is no longer mandatory, as the Perfomn XML creation process catch this already
          Begin
            WriteLn('Found only Default SQL Instance');
            strSQLInstance := 'Default';
          End;

       If (tstrSQLServer.Count = 0) Then
          Begin                          // this logic is for safety purpose
            WriteLn('Found no SQL Instance. Dropping to default option/instance.');
            strSQLInstance := 'Default';
          End
       Else
          Begin  // multiple SQL instances detected OR non default instance detected. Running Auto.
            WriteLn('Total SQL Instance(s): '+IntToStr(tstrSQLServer.Count));
          End;

       If (tstrOLAPServer.Count = 0)  Then // this logic is for logging purpose only
          Begin
            WriteLn('Found no OLAP Instance.');
          End
       Else
          Begin
            WriteLn('Total OLAP Instance(s): '+IntToStr(tstrOLAPServer.Count)+'. Set to Auto.');
            strSQLInstance := '[Auto]';
          End;

       If (boolIISExist) Then Begin
            WriteLn('Found IIS Instance. Set to Auto.');
            strSQLInstance := '[Auto]';
       End

     End
   Else
     Begin
       WriteLn('Failed to check services. Running with default value of SQL instance: default instance.');
     End;
end;

procedure DeleteOneFile(strFilename : String);
begin
    if FileExists(strFilename) then
      begin
         Sleep(50);
         try
           DeleteFile(strFilename);
         except
           // internal error
         end;
      end;
end;

procedure DeleteDataFiles;
begin
    DeleteOneFile('RDIPDC.xml');
    DeleteOneFile('RDIPDC.lck');
    DeleteOneFile('report.html');
    DeleteOneFile('report.xml');
    DeleteOneFile('report.xsl');
    DeleteOneFile('mssqlinst.dat');
    DeleteOneFile('lmimp.dat');
    DeleteOneFile('lmsta.dat');
    DeleteOneFile('RDIPDC.log');
    DeleteOneFile('report.html');
    DeleteOneFile('lmsto.dat');
    DeleteOneFile('lmdel.dat');
    DeleteOneFile('mssqlinst.dat');
end;

procedure CreatePerfmonXML;
var fileRDIPDCLCK, fileRDIPDCXML : TextFile; procRetValue, i : Integer;
begin
    AssignFile(fileRDIPDCXML, 'RDIPDC.xml');

    try
        ReWrite(fileRDIPDCXML);

           If (Trim(strSQLInstance) = '[Auto]') Then
              Begin

                WriteLn(fileRDIPDCXML, '<?xml version="1.0" encoding="UTF-8"?>');
                WriteLn(fileRDIPDCXML, '<DataCollectorSet>');
                WriteLn(fileRDIPDCXML, '<Status>1</Status>');
                WriteLn(fileRDIPDCXML, '<Duration>0</Duration>');
                WriteLn(fileRDIPDCXML, '<Description>');
                WriteLn(fileRDIPDCXML, '</Description>');
                WriteLn(fileRDIPDCXML, '<DescriptionUnresolved>');
                WriteLn(fileRDIPDCXML, '</DescriptionUnresolved>');
                WriteLn(fileRDIPDCXML, '<DisplayName>');
                WriteLn(fileRDIPDCXML, '</DisplayName>');
                WriteLn(fileRDIPDCXML, '<DisplayNameUnresolved>');
                WriteLn(fileRDIPDCXML, '</DisplayNameUnresolved>');
                WriteLn(fileRDIPDCXML, '<SchedulesEnabled>-1</SchedulesEnabled>');
                WriteLn(fileRDIPDCXML, '<LatestOutputLocation>' + GetCurrentDir + '</LatestOutputLocation>');
                WriteLn(fileRDIPDCXML, '<Name>RPDCLI</Name>');
                WriteLn(fileRDIPDCXML, '<OutputLocation>' + GetCurrentDir + '</OutputLocation>');
                WriteLn(fileRDIPDCXML, '<RootPath>' + GetCurrentDir + '</RootPath>');
                WriteLn(fileRDIPDCXML, '<Segment>-1</Segment>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxDuration>86400</SegmentMaxDuration>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxSize>0</SegmentMaxSize>');
                WriteLn(fileRDIPDCXML, '<SerialNumber>1</SerialNumber>');
                WriteLn(fileRDIPDCXML, '<Server>');
                WriteLn(fileRDIPDCXML, '</Server>');
                WriteLn(fileRDIPDCXML, '<Subdirectory>');
                WriteLn(fileRDIPDCXML, '</Subdirectory>');
                WriteLn(fileRDIPDCXML, '<SubdirectoryFormat>1</SubdirectoryFormat>');
                WriteLn(fileRDIPDCXML, '<SubdirectoryFormatPattern>');
                WriteLn(fileRDIPDCXML, '</SubdirectoryFormatPattern>');
                WriteLn(fileRDIPDCXML, '<Task>');
                WriteLn(fileRDIPDCXML, '</Task>');
                WriteLn(fileRDIPDCXML, '<TaskRunAsSelf>0</TaskRunAsSelf>');
                WriteLn(fileRDIPDCXML, '<TaskArguments>');
                WriteLn(fileRDIPDCXML, '</TaskArguments>');
                WriteLn(fileRDIPDCXML, '<TaskUserTextArguments>');
                WriteLn(fileRDIPDCXML, '</TaskUserTextArguments>');
                WriteLn(fileRDIPDCXML, '<UserAccount>SYSTEM</UserAccount>');
                Write(fileRDIPDCXML,   '<Security>O:BAG:S-1-5-21-2952966170-3714788709-2525979044-513D:AI(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;LU)(A;;0x1301ff;;;S-1-5-80-2661322625-712705077');
                WriteLn(fileRDIPDCXML, '-2999183737-3043590567-590698655)(A;ID;FA;;;SY)(A;ID;FA;;;BA)(A;ID;0x1200ab;;;LU)(A;ID;FR;;;AU)(A;ID;FR;;;LS)(A;ID;FR;;;NS)</Security>');
                WriteLn(fileRDIPDCXML, '<StopOnCompletion>0</StopOnCompletion>');
                WriteLn(fileRDIPDCXML, '<PerformanceCounterDataCollector>');
                WriteLn(fileRDIPDCXML, '<DataCollectorType>0</DataCollectorType>');
                WriteLn(fileRDIPDCXML, '<Name>HealthCheck</Name>');
                WriteLn(fileRDIPDCXML, '<FileName>RDIPDC</FileName>');
                WriteLn(fileRDIPDCXML, '<FileNameFormat>3</FileNameFormat>');
                WriteLn(fileRDIPDCXML, '<FileNameFormatPattern>\_yyyyMMdd\_HHmm</FileNameFormatPattern>');
                WriteLn(fileRDIPDCXML, '<LogAppend>0</LogAppend>');
                WriteLn(fileRDIPDCXML, '<LogCircular>0</LogCircular>');
                WriteLn(fileRDIPDCXML, '<LogOverwrite>-1</LogOverwrite>');
                WriteLn(fileRDIPDCXML, '<LatestOutputLocation>' + GetCurrentDir + '\AAA1.blg</LatestOutputLocation>');
                WriteLn(fileRDIPDCXML, '<DataSourceName>');
                WriteLn(fileRDIPDCXML, '</DataSourceName>');
                WriteLn(fileRDIPDCXML, '<SampleInterval>15</SampleInterval>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxRecords>0</SegmentMaxRecords>');
                WriteLn(fileRDIPDCXML, '<LogFileFormat>3</LogFileFormat>');
                WriteLn(fileRDIPDCXML, '<Counter>\.NET CLR Exceptions(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\.NET CLR Memory(_Global_)\*</Counter>');

                If boolIISExist Then Begin
                   WriteLn(fileRDIPDCXML, '<Counter>\Active Server Pages\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\ASP.NET\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\HTTP Service\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\HTTP Service Request Queues(*)\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\HTTP Service Url Groups(*)\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\W3SVC_W3WP\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\WAS_W3WP\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\Web Service(*)\*</Counter>');
                   WriteLn(fileRDIPDCXML, '<Counter>\Web Service Cache\*</Counter>');
                End;

                WriteLn(fileRDIPDCXML, '<Counter>\Processor(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Processor Performance(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\PhysicalDisk(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\System\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Process(*)\*</Counter>');

                If tstrSQLServer.Count > 0 Then Begin
                  for i := 0 to tstrSQLServer.Count-1 do begin
                    If (Trim(tstrSQLServer[i]) = 'MSSQLSERVER') Then
                     begin
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Wait Statistics(*)\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Access Methods\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Buffer Manager\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Databases(*)\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Latches\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Locks(_Total)\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:SQL Statistics\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Transactions\*</Counter>');
                     end
                    else
                     begin
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Wait Statistics(*)\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Access Methods\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Buffer Manager\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Databases(*)\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Latches\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Locks(_Total)\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':SQL Statistics\*</Counter>');
                        WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(tstrSQLServer[i])+':Transactions\*</Counter>');
                     end;
                  end;
                End; // tstrSQLServer.Count > 0

                If tstrOLAPServer.Count > 0 Then Begin
                      For i := 0 to tstrOLAPServer.Count - 1 do begin
                          If (Trim(tstrOLAPServer[i]) = 'MSSQLSERVER') Then
                            Begin
                                // If bSSASDefaultCountersDeployed = False Then
                                // Brute force SSAS Perfmon data collection. Grab all versions! #needtobetested

                                // SQL 2008
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10:Threads\*</Counter>');

                                // SQL 2008 R2
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS10_50:Threads\*</Counter>');

                                // SQL 2012
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS11:Threads\*</Counter>');

                                // SQL 2014
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS12:Threads\*</Counter>');

                                // SQL 2016
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS13:Threads\*</Counter>');

                                // SQL 2017
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSAS14:Threads\*</Counter>');

                                // bSSASDefaultCountersDeployed = True
                                // End If
                              End
                            Else
                              Begin
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Cache\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Connection\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Locks\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':MDX\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Memory\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Proc Aggregations\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Proc Indexes\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Processing\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Storage Engine Query\*</Counter>');
                                WriteLn(fileRDIPDCXML, '<Counter>\MSOLAP$' + tstrOLAPServer[i] + ':Threads\*</Counter>');
                            End;
                       End;
                 End; // tstrOLAPServer.Count > 0


                WriteLn(fileRDIPDCXML, '<Counter>\Network Interface(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Memory\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Paging File\*</Counter>');

                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\.NET CLR Exceptions(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\.NET CLR Memory(_Global_)\*</CounterDisplayName>');

                If boolIISExist Then Begin
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Active Server Pages\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\ASP.NET\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\HTTP Service\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\HTTP Service Request Queues(*)\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\HTTP Service Url Groups(*)\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\W3SVC_W3WP\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\WAS_W3WP\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Web Service(*)\*</CounterDisplayName>');
                   WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Web Service Cache\*</CounterDisplayName>');
                End;

                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Processor(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Processor Performance(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\PhysicalDisk(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\System\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Process(*)\*</CounterDisplayName>');

                If tstrSQLServer.Count > 0 Then Begin
                  for i := 0 to tstrSQLServer.Count-1 do begin
                    If (Trim(tstrSQLServer[i]) = 'MSSQLSERVER') Then
                     begin
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Wait Statistics(*)\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Access Methods\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Buffer Manager\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Databases(*)\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Latches\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Locks(_Total)\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:SQL Statistics\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Transactions\*</CounterDisplayName>');
                     end
                    else
                     begin
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Wait Statistics(*)\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Access Methods\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Buffer Manager\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Databases(*)\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Latches\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Locks(_Total)\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':SQL Statistics\*</CounterDisplayName>');
                        WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(tstrSQLServer[i])+':Transactions\*</CounterDisplayName>');
                     end;
                  end;
                End; // tstrSQLServer.Count > 0

                If tstrOLAPServer.Count > 0 Then Begin
                      For i := 0 to tstrOLAPServer.Count - 1 do begin
                          If (Trim(tstrOLAPServer[i]) = 'MSSQLSERVER') Then
                            Begin
                                // If bSSASDefaultCountersDeployed = False Then
                                // Brute force SSAS Perfmon data collection. Grab all versions! #needtobetested

                                // SQL 2008
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10:Threads\*</CounterDisplayName>');

                                // SQL 2008 R2
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS10_50:Threads\*</CounterDisplayName>');

                                // SQL 2012
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS11:Threads\*</CounterDisplayName>');

                                // SQL 2014
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS12:Threads\*</CounterDisplayName>');

                                // SQL 2016
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS13:Threads\*</CounterDisplayName>');

                                // SQL 2017
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSAS14:Threads\*</CounterDisplayName>');

                                // bSSASDefaultCountersDeployed = True
                                // End If
                              End
                            Else
                              Begin
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Cache\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Connection\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Locks\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':MDX\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Memory\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Proc Aggregations\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Proc Indexes\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Processing\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Storage Engine Query\*</CounterDisplayName>');
                                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSOLAP$' + tstrOLAPServer[i] + ':Threads\*</CounterDisplayName>');
                            End;
                       End;
                 End; // tstrOLAPServer.Count > 0

                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Network Interface(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Memory\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Paging File\*</CounterDisplayName>');

                WriteLn(fileRDIPDCXML, '</PerformanceCounterDataCollector>');
                WriteLn(fileRDIPDCXML, '<Schedule>');
                WriteLn(fileRDIPDCXML, '	<StartDate>8/17/2014</StartDate>');
                WriteLn(fileRDIPDCXML, '	<EndDate>');
                WriteLn(fileRDIPDCXML, '	</EndDate>');
                WriteLn(fileRDIPDCXML, '	<StartTime>');
                WriteLn(fileRDIPDCXML, '	</StartTime>');
                WriteLn(fileRDIPDCXML, '	<Days>127</Days>');
                WriteLn(fileRDIPDCXML, '</Schedule>');
                WriteLn(fileRDIPDCXML, '<Schedule>');
                WriteLn(fileRDIPDCXML, '	<StartDate>8/17/2014</StartDate>');
                WriteLn(fileRDIPDCXML, '	<EndDate>');
                WriteLn(fileRDIPDCXML, '	</EndDate>');
                WriteLn(fileRDIPDCXML, '	<StartTime>12:00:00 PM</StartTime>');
                WriteLn(fileRDIPDCXML, '	<Days>127</Days>');
                WriteLn(fileRDIPDCXML, '</Schedule>');
                WriteLn(fileRDIPDCXML, '<DataManager>');
                WriteLn(fileRDIPDCXML, '	<Enabled>-1</Enabled>');
                WriteLn(fileRDIPDCXML, '	<CheckBeforeRunning>-1</CheckBeforeRunning>');
                WriteLn(fileRDIPDCXML, '	<MinFreeDisk>0</MinFreeDisk>');
                WriteLn(fileRDIPDCXML, '	<MaxSize>3000</MaxSize>');
                WriteLn(fileRDIPDCXML, '	<MaxFolderCount>0</MaxFolderCount>');
                WriteLn(fileRDIPDCXML, '	<ResourcePolicy>1</ResourcePolicy>');
                WriteLn(fileRDIPDCXML, '	<ReportFileName>report.html</ReportFileName>');
                WriteLn(fileRDIPDCXML, '	<RuleTargetFileName>report.xml</RuleTargetFileName>');
                WriteLn(fileRDIPDCXML, '	<EventsFileName>');
                WriteLn(fileRDIPDCXML, '	</EventsFileName>');
                WriteLn(fileRDIPDCXML, '	<FolderAction>');
                WriteLn(fileRDIPDCXML, '		<Size>3000</Size>');
                WriteLn(fileRDIPDCXML, '		<Age>21</Age>');
                WriteLn(fileRDIPDCXML, '		<Actions>18</Actions>');
                WriteLn(fileRDIPDCXML, '		<SendCabTo>');
                WriteLn(fileRDIPDCXML, '		</SendCabTo>');
                WriteLn(fileRDIPDCXML, '	</FolderAction>');
                WriteLn(fileRDIPDCXML, '</DataManager>');
                WriteLn(fileRDIPDCXML, '</DataCollectorSet>');

              End
           Else If (Trim(strSQLInstance) = 'Default') OR (Trim(strSQLInstance) = '') Then
              Begin
                WriteLn(fileRDIPDCXML, '<?xml version="1.0" encoding="UTF-8"?>');
                WriteLn(fileRDIPDCXML, '<DataCollectorSet>');
                WriteLn(fileRDIPDCXML, '<Status>1</Status>');
                WriteLn(fileRDIPDCXML, '<Duration>0</Duration>');
                WriteLn(fileRDIPDCXML, '<Description>');
                WriteLn(fileRDIPDCXML, '</Description>');
                WriteLn(fileRDIPDCXML, '<DescriptionUnresolved>');
                WriteLn(fileRDIPDCXML, '</DescriptionUnresolved>');
                WriteLn(fileRDIPDCXML, '<DisplayName>');
                WriteLn(fileRDIPDCXML, '</DisplayName>');
                WriteLn(fileRDIPDCXML, '<DisplayNameUnresolved>');
                WriteLn(fileRDIPDCXML, '</DisplayNameUnresolved>');
                WriteLn(fileRDIPDCXML, '<SchedulesEnabled>-1</SchedulesEnabled>');
                WriteLn(fileRDIPDCXML, '<LatestOutputLocation>' + GetCurrentDir + '</LatestOutputLocation>');
                WriteLn(fileRDIPDCXML, '<Name>RPDCLI</Name>');
                WriteLn(fileRDIPDCXML, '<OutputLocation>' + GetCurrentDir + '</OutputLocation>');
                WriteLn(fileRDIPDCXML, '<RootPath>' + GetCurrentDir + '</RootPath>');
                WriteLn(fileRDIPDCXML, '<Segment>-1</Segment>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxDuration>86400</SegmentMaxDuration>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxSize>0</SegmentMaxSize>');
                WriteLn(fileRDIPDCXML, '<SerialNumber>1</SerialNumber>');
                WriteLn(fileRDIPDCXML, '<Server>');
                WriteLn(fileRDIPDCXML, '</Server>');
                WriteLn(fileRDIPDCXML, '<Subdirectory>');
                WriteLn(fileRDIPDCXML, '</Subdirectory>');
                WriteLn(fileRDIPDCXML, '<SubdirectoryFormat>1</SubdirectoryFormat>');
                WriteLn(fileRDIPDCXML, '<SubdirectoryFormatPattern>');
                WriteLn(fileRDIPDCXML, '</SubdirectoryFormatPattern>');
                WriteLn(fileRDIPDCXML, '<Task>');
                WriteLn(fileRDIPDCXML, '</Task>');
                WriteLn(fileRDIPDCXML, '<TaskRunAsSelf>0</TaskRunAsSelf>');
                WriteLn(fileRDIPDCXML, '<TaskArguments>');
                WriteLn(fileRDIPDCXML, '</TaskArguments>');
                WriteLn(fileRDIPDCXML, '<TaskUserTextArguments>');
                WriteLn(fileRDIPDCXML, '</TaskUserTextArguments>');
                WriteLn(fileRDIPDCXML, '<UserAccount>SYSTEM</UserAccount>');
                Write(fileRDIPDCXML,   '<Security>O:BAG:S-1-5-21-2952966170-3714788709-2525979044-513D:AI(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;LU)(A;;0x1301ff;;;S-1-5-80-2661322625-712705077');
                WriteLn(fileRDIPDCXML, '-2999183737-3043590567-590698655)(A;ID;FA;;;SY)(A;ID;FA;;;BA)(A;ID;0x1200ab;;;LU)(A;ID;FR;;;AU)(A;ID;FR;;;LS)(A;ID;FR;;;NS)</Security>');
                WriteLn(fileRDIPDCXML, '<StopOnCompletion>0</StopOnCompletion>');
                WriteLn(fileRDIPDCXML, '<PerformanceCounterDataCollector>');
                WriteLn(fileRDIPDCXML, '<DataCollectorType>0</DataCollectorType>');
                WriteLn(fileRDIPDCXML, '<Name>HealthCheck</Name>');
                WriteLn(fileRDIPDCXML, '<FileName>RDIPDC</FileName>');
                WriteLn(fileRDIPDCXML, '<FileNameFormat>3</FileNameFormat>');
                WriteLn(fileRDIPDCXML, '<FileNameFormatPattern>\_yyyyMMdd\_HHmm</FileNameFormatPattern>');
                WriteLn(fileRDIPDCXML, '<LogAppend>0</LogAppend>');
                WriteLn(fileRDIPDCXML, '<LogCircular>0</LogCircular>');
                WriteLn(fileRDIPDCXML, '<LogOverwrite>-1</LogOverwrite>');
                WriteLn(fileRDIPDCXML, '<LatestOutputLocation>' + GetCurrentDir + '\AAA1.blg</LatestOutputLocation>');
                WriteLn(fileRDIPDCXML, '<DataSourceName>');
                WriteLn(fileRDIPDCXML, '</DataSourceName>');
                WriteLn(fileRDIPDCXML, '<SampleInterval>15</SampleInterval>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxRecords>0</SegmentMaxRecords>');
                WriteLn(fileRDIPDCXML, '<LogFileFormat>3</LogFileFormat>');
                WriteLn(fileRDIPDCXML, '<Counter>\.NET CLR Exceptions(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\.NET CLR Memory(_Global_)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Active Server Pages\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\ASP.NET\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Processor(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Processor Performance(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\PhysicalDisk(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\System\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Process(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Wait Statistics(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Access Methods\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Buffer Manager\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Databases(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Latches\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Locks(_Total)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:SQL Statistics\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\SQLServer:Transactions\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Network Interface(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Memory\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Paging File\*</Counter>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\.NET CLR Exceptions(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\.NET CLR Memory(_Global_)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Active Server Pages\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\ASP.NET\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Processor(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Processor Performance(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\PhysicalDisk(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\System\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Process(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Wait Statistics(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Access Methods\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Buffer Manager\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Databases(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Latches\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Locks(_Total)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:SQL Statistics\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\SQLServer:Transactions\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Network Interface(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Memory\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Paging File\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '</PerformanceCounterDataCollector>');
                WriteLn(fileRDIPDCXML, '<Schedule>');
                WriteLn(fileRDIPDCXML, '	<StartDate>8/17/2014</StartDate>');
                WriteLn(fileRDIPDCXML, '	<EndDate>');
                WriteLn(fileRDIPDCXML, '	</EndDate>');
                WriteLn(fileRDIPDCXML, '	<StartTime>');
                WriteLn(fileRDIPDCXML, '	</StartTime>');
                WriteLn(fileRDIPDCXML, '	<Days>127</Days>');
                WriteLn(fileRDIPDCXML, '</Schedule>');
                WriteLn(fileRDIPDCXML, '<Schedule>');
                WriteLn(fileRDIPDCXML, '	<StartDate>8/17/2014</StartDate>');
                WriteLn(fileRDIPDCXML, '	<EndDate>');
                WriteLn(fileRDIPDCXML, '	</EndDate>');
                WriteLn(fileRDIPDCXML, '	<StartTime>12:00:00 PM</StartTime>');
                WriteLn(fileRDIPDCXML, '	<Days>127</Days>');
                WriteLn(fileRDIPDCXML, '</Schedule>');
                WriteLn(fileRDIPDCXML, '<DataManager>');
                WriteLn(fileRDIPDCXML, '	<Enabled>-1</Enabled>');
                WriteLn(fileRDIPDCXML, '	<CheckBeforeRunning>-1</CheckBeforeRunning>');
                WriteLn(fileRDIPDCXML, '	<MinFreeDisk>0</MinFreeDisk>');
                WriteLn(fileRDIPDCXML, '	<MaxSize>3000</MaxSize>');
                WriteLn(fileRDIPDCXML, '	<MaxFolderCount>0</MaxFolderCount>');
                WriteLn(fileRDIPDCXML, '	<ResourcePolicy>1</ResourcePolicy>');
                WriteLn(fileRDIPDCXML, '	<ReportFileName>report.html</ReportFileName>');
                WriteLn(fileRDIPDCXML, '	<RuleTargetFileName>report.xml</RuleTargetFileName>');
                WriteLn(fileRDIPDCXML, '	<EventsFileName>');
                WriteLn(fileRDIPDCXML, '	</EventsFileName>');
                WriteLn(fileRDIPDCXML, '	<FolderAction>');
                WriteLn(fileRDIPDCXML, '		<Size>3000</Size>');
                WriteLn(fileRDIPDCXML, '		<Age>21</Age>');
                WriteLn(fileRDIPDCXML, '		<Actions>18</Actions>');
                WriteLn(fileRDIPDCXML, '		<SendCabTo>');
                WriteLn(fileRDIPDCXML, '		</SendCabTo>');
                WriteLn(fileRDIPDCXML, '	</FolderAction>');
                WriteLn(fileRDIPDCXML, '</DataManager>');
                WriteLn(fileRDIPDCXML, '</DataCollectorSet>');
              End
           Else
              Begin
                WriteLn(fileRDIPDCXML, '<?xml version="1.0" encoding="UTF-8"?>');
                WriteLn(fileRDIPDCXML, '<DataCollectorSet>');
                WriteLn(fileRDIPDCXML, '<Status>1</Status>');
                WriteLn(fileRDIPDCXML, '<Duration>0</Duration>');
                WriteLn(fileRDIPDCXML, '<Description>');
                WriteLn(fileRDIPDCXML, '</Description>');
                WriteLn(fileRDIPDCXML, '<DescriptionUnresolved>');
                WriteLn(fileRDIPDCXML, '</DescriptionUnresolved>');
                WriteLn(fileRDIPDCXML, '<DisplayName>');
                WriteLn(fileRDIPDCXML, '</DisplayName>');
                WriteLn(fileRDIPDCXML, '<DisplayNameUnresolved>');
                WriteLn(fileRDIPDCXML, '</DisplayNameUnresolved>');
                WriteLn(fileRDIPDCXML, '<SchedulesEnabled>-1</SchedulesEnabled>');
                WriteLn(fileRDIPDCXML, '<LatestOutputLocation>' + GetCurrentDir + '</LatestOutputLocation>');
                WriteLn(fileRDIPDCXML, '<Name>RPDCLI</Name>');
                WriteLn(fileRDIPDCXML, '<OutputLocation>' + GetCurrentDir + '</OutputLocation>');
                WriteLn(fileRDIPDCXML, '<RootPath>' + GetCurrentDir + '</RootPath>');
                WriteLn(fileRDIPDCXML, '<Segment>-1</Segment>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxDuration>86400</SegmentMaxDuration>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxSize>0</SegmentMaxSize>');
                WriteLn(fileRDIPDCXML, '<SerialNumber>1</SerialNumber>');
                WriteLn(fileRDIPDCXML, '<Server>');
                WriteLn(fileRDIPDCXML, '</Server>');
                WriteLn(fileRDIPDCXML, '<Subdirectory>');
                WriteLn(fileRDIPDCXML, '</Subdirectory>');
                WriteLn(fileRDIPDCXML, '<SubdirectoryFormat>1</SubdirectoryFormat>');
                WriteLn(fileRDIPDCXML, '<SubdirectoryFormatPattern>');
                WriteLn(fileRDIPDCXML, '</SubdirectoryFormatPattern>');
                WriteLn(fileRDIPDCXML, '<Task>');
                WriteLn(fileRDIPDCXML, '</Task>');
                WriteLn(fileRDIPDCXML, '<TaskRunAsSelf>0</TaskRunAsSelf>');
                WriteLn(fileRDIPDCXML, '<TaskArguments>');
                WriteLn(fileRDIPDCXML, '</TaskArguments>');
                WriteLn(fileRDIPDCXML, '<TaskUserTextArguments>');
                WriteLn(fileRDIPDCXML, '</TaskUserTextArguments>');
                WriteLn(fileRDIPDCXML, '<UserAccount>SYSTEM</UserAccount>');
                Write(fileRDIPDCXML,   '<Security>O:BAG:S-1-5-21-2952966170-3714788709-2525979044-513D:AI(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;LU)(A;;0x1301ff;;;S-1-5-80-2661322625-712705077');
                WriteLn(fileRDIPDCXML, '-2999183737-3043590567-590698655)(A;ID;FA;;;SY)(A;ID;FA;;;BA)(A;ID;0x1200ab;;;LU)(A;ID;FR;;;AU)(A;ID;FR;;;LS)(A;ID;FR;;;NS)</Security>');
                WriteLn(fileRDIPDCXML, '<StopOnCompletion>0</StopOnCompletion>');
                WriteLn(fileRDIPDCXML, '<PerformanceCounterDataCollector>');
                WriteLn(fileRDIPDCXML, '<DataCollectorType>0</DataCollectorType>');
                WriteLn(fileRDIPDCXML, '<Name>HealthCheck</Name>');
                WriteLn(fileRDIPDCXML, '<FileName>RDIPDC</FileName>');
                WriteLn(fileRDIPDCXML, '<FileNameFormat>3</FileNameFormat>');
                WriteLn(fileRDIPDCXML, '<FileNameFormatPattern>\_yyyyMMdd\_HHmm</FileNameFormatPattern>');
                WriteLn(fileRDIPDCXML, '<LogAppend>0</LogAppend>');
                WriteLn(fileRDIPDCXML, '<LogCircular>0</LogCircular>');
                WriteLn(fileRDIPDCXML, '<LogOverwrite>-1</LogOverwrite>');
                WriteLn(fileRDIPDCXML, '<LatestOutputLocation>' + GetCurrentDir + '\AAA1.blg</LatestOutputLocation>');
                WriteLn(fileRDIPDCXML, '<DataSourceName>');
                WriteLn(fileRDIPDCXML, '</DataSourceName>');
                WriteLn(fileRDIPDCXML, '<SampleInterval>15</SampleInterval>');
                WriteLn(fileRDIPDCXML, '<SegmentMaxRecords>0</SegmentMaxRecords>');
                WriteLn(fileRDIPDCXML, '<LogFileFormat>3</LogFileFormat>');
                WriteLn(fileRDIPDCXML, '<Counter>\.NET CLR Exceptions(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\.NET CLR Memory(_Global_)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Active Server Pages\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\ASP.NET\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Processor(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Processor Performance(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\PhysicalDisk(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\System\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Process(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Wait Statistics(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Access Methods\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Buffer Manager\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Databases(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Latches\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Locks(_Total)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':SQL Statistics\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\MSSQL$'+Trim(strSQLInstance)+':Transactions\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Network Interface(*)\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Memory\*</Counter>');
                WriteLn(fileRDIPDCXML, '<Counter>\Paging File\*</Counter>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\.NET CLR Exceptions(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\.NET CLR Memory(_Global_)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Active Server Pages\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\ASP.NET\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Processor(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Processor Performance(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\PhysicalDisk(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\System\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Process(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Wait Statistics(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Access Methods\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Buffer Manager\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Databases(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Latches\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Locks(_Total)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':SQL Statistics\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\MSSQL$'+Trim(strSQLInstance)+':Transactions\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Network Interface(*)\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Memory\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '<CounterDisplayName>\Paging File\*</CounterDisplayName>');
                WriteLn(fileRDIPDCXML, '</PerformanceCounterDataCollector>');
                WriteLn(fileRDIPDCXML, '<Schedule>');
                WriteLn(fileRDIPDCXML, '	<StartDate>8/17/2014</StartDate>');
                WriteLn(fileRDIPDCXML, '	<EndDate>');
                WriteLn(fileRDIPDCXML, '	</EndDate>');
                WriteLn(fileRDIPDCXML, '	<StartTime>');
                WriteLn(fileRDIPDCXML, '	</StartTime>');
                WriteLn(fileRDIPDCXML, '	<Days>127</Days>');
                WriteLn(fileRDIPDCXML, '</Schedule>');
                WriteLn(fileRDIPDCXML, '<Schedule>');
                WriteLn(fileRDIPDCXML, '	<StartDate>8/17/2014</StartDate>');
                WriteLn(fileRDIPDCXML, '	<EndDate>');
                WriteLn(fileRDIPDCXML, '	</EndDate>');
                WriteLn(fileRDIPDCXML, '	<StartTime>12:00:00 PM</StartTime>');
                WriteLn(fileRDIPDCXML, '	<Days>127</Days>');
                WriteLn(fileRDIPDCXML, '</Schedule>');
                WriteLn(fileRDIPDCXML, '<DataManager>');
                WriteLn(fileRDIPDCXML, '	<Enabled>-1</Enabled>');
                WriteLn(fileRDIPDCXML, '	<CheckBeforeRunning>-1</CheckBeforeRunning>');
                WriteLn(fileRDIPDCXML, '	<MinFreeDisk>0</MinFreeDisk>');
                WriteLn(fileRDIPDCXML, '	<MaxSize>3000</MaxSize>');
                WriteLn(fileRDIPDCXML, '	<MaxFolderCount>0</MaxFolderCount>');
                WriteLn(fileRDIPDCXML, '	<ResourcePolicy>1</ResourcePolicy>');
                WriteLn(fileRDIPDCXML, '	<ReportFileName>report.html</ReportFileName>');
                WriteLn(fileRDIPDCXML, '	<RuleTargetFileName>report.xml</RuleTargetFileName>');
                WriteLn(fileRDIPDCXML, '	<EventsFileName>');
                WriteLn(fileRDIPDCXML, '	</EventsFileName>');
                WriteLn(fileRDIPDCXML, '	<FolderAction>');
                WriteLn(fileRDIPDCXML, '		<Size>3000</Size>');
                WriteLn(fileRDIPDCXML, '		<Age>21</Age>');
                WriteLn(fileRDIPDCXML, '		<Actions>18</Actions>');
                WriteLn(fileRDIPDCXML, '		<SendCabTo>');
                WriteLn(fileRDIPDCXML, '		</SendCabTo>');
                WriteLn(fileRDIPDCXML, '	</FolderAction>');
                WriteLn(fileRDIPDCXML, '</DataManager>');
                WriteLn(fileRDIPDCXML, '</DataCollectorSet>');
              End;

           CloseFile(fileRDIPDCXML);

          except
           WriteLn('Write file error: XML');
           end;
    Sleep(500);
end;

function FileContent(Filename : String; StringContent : String) : Boolean;
var LineStr : String;
begin
  FileContent := True;
end;

procedure RegisterPerfmonXML;
var procretValue : integer;
begin
   procRetValue := StartProcessHidden('CMD /C logman import -n RPDCLI -xml RDIPDC.xml > lmimp.dat',True);
   Sleep(500);
   If FileContent('lmimp.dat','The command completed successfully') Then
      Begin
         WriteLn('Collector created.');
         WriteLn('Run with -2 or -start as parameter to start data collection process.');
         DeleteDataFiles;
      End
   Else
      Begin
         WriteLn('Collector creation failed. Check the error message on lmimp.dat.');
      End;
end;

procedure StartPerfmonXML;
var procretValue : integer;
begin
   procRetValue := StartProcessHidden('CMD /C logman start RPDCLI > lmsta.dat',True);
   Sleep(500);
   If FileContent('lmsta.dat','The command completed successfully') Then
      Begin
         WriteLn('Collector started.');
         WriteLn('Run with -3 or -stop as parameter to later stop data collection process.');
         DeleteDataFiles;
      End
   Else
      Begin
         WriteLn('Collector starting failed.');
         WriteLn('Please ensure collection already registered.');
         WriteLn('Check the error message on lmsta.dat.');
      End;
end;

procedure StopPerfmonXML;
var procretValue : integer;
begin
   procRetValue := StartProcessHidden('CMD /C logman stop RPDCLI > lmsto.dat',True);
   Sleep(500);
   If FileContent('lmsto.dat','The command completed successfully') Then
      Begin
         WriteLn('Collector stopped.');
         WriteLn('Run with -4 or -clean as parameter to remove collector.');
         DeleteDataFiles;
      End
   Else
      Begin
         WriteLn('Collector stopping failed.');
         WriteLn('Please ensure collection already registered and started.');
         WriteLn('Check the error message on lmsto.dat.');
      End;
end;

procedure RemovePerfmonXML;
var procretValue : integer;
begin
   procRetValue := StartProcessHidden('CMD /C logman delete RPDCLI > lmdel.dat',True);
   Sleep(500);
   If FileContent('lmdel.dat','The command completed successfully') Then
      Begin
         WriteLn('Collector removed.');
         WriteLn('Run with -1 or -install as parameter to reinstall collector.');
         DeleteDataFiles;
      End
   Else
      Begin
         WriteLn('Collector removal failed.');
         WriteLn('Please ensure collection exists and on stopped condition.');
         WriteLn('Check the error message on lmdel.dat.');
      End;
end;

begin
   validParamStr := False;

   If IAmIn64Bits Then
     Begin
       WriteLn('RPDC CLI v' + GetBuildInfoAsString + '/X64 - Copyright (c)2016-2018, PT. Reksa Data Indonesia');
     End
    Else
     Begin
       WriteLn('RPDC CLI v' + GetBuildInfoAsString + '/X86 - Copyright (c)2016-2018, PT. Reksa Data Indonesia');
     End;

   WriteLn('');
   DeleteDataFiles;

   If (ParamStr(1) = '') Then
   Begin
      WriteLn('Valid parameters:');
      WriteLn('  -i, -install, -1 : Install/setup/register RPDC Performance Data Collector');
      WriteLn('  -r, -start  , -2 : Run/start RPDC Performance Data Collector');
      WriteLn('  -s, -stop   , -3 : Stop RPDC Performance Data Collector');
      WriteLn('  -c, -clean  , -4 : Clean up/deregister any RPDC Performance Data Collector');
      Exit;
   End;

    If NOT IsElevated Then
     Begin
       WriteLn('Not started in Elevated mode. Tool cannot run any further.');
       WriteLn('Please run from a Command Prompt window on Elevated mode and try again...');
      Exit;
     End;

   If (ParamStr(1) = '-1') OR (UpperCase(ParamStr(1)) = '-I') OR (UpperCase(ParamStr(1)) = '-INSTALL') OR (UpperCase(ParamStr(1)) = '-SETUP') OR (UpperCase(ParamStr(1)) = '-REGISTER') Then
   Begin
      validParamStr := True;
      tstrSQLServer := TStringList.Create;
      tstrOLAPServer := TStringList.Create;
      DetectSQLServerInstancesInstalled;

      WriteLn('Registering RPDC Performance Data Collector...');

      CreatePerfmonXML;
      RegisterPerfmonXML;
   End;

   If (ParamStr(1) = '-2') OR (UpperCase(ParamStr(1)) = '-R') OR (UpperCase(ParamStr(1)) = '-RUN') OR (UpperCase(ParamStr(1)) = '-START') Then
   Begin
      validParamStr := True;
      WriteLn('Starting RPDC Performance Data Collector...');
      StartPerfmonXML;
   End;

   If (ParamStr(1) = '-3') OR (UpperCase(ParamStr(1)) = '-S') OR (UpperCase(ParamStr(1)) = '-STOP') Then
   Begin
      validParamStr := True;
      WriteLn('Stopping RPDC Performance Data Collector...');
      StopPerfmonXML;
   End;

   If (ParamStr(1) = '-4') OR (UpperCase(ParamStr(1)) = '-C') OR (UpperCase(ParamStr(1)) = '-CLEAR') OR (UpperCase(ParamStr(1)) = '-CLEAN')  OR (UpperCase(ParamStr(1)) = '-DEREGISTER') Then
   Begin
      validParamStr := True;
      WriteLn('Cleaning up RPDC Performance Data Collector...');
      RemovePerfmonXML;
   End;

   DeleteDataFiles;

   If validParamStr = False Then WriteLn(ParamStr(1) + ' is not a valid paramater');

   WriteLn('');
   WriteLn('Program exiting!');
end.


