# About
Windows OS Performance Data Collector Command Line Tool

# Notes
Download the code from https://github.com/syuaip/rpdcli

Download the binary from this github release section, or from http://awssg.reksadata.net/binary/rditools.zip

For these releases, binary was compiled with Delphi 7.0 Ultimate 4.453 on top of Windows XP VM.

# Purpose
Tools for Windows Performance Data Collector Setup, Ops and Cleaning Up

# How-to-use

1) Copy RPDCLI.exe to the Windows box which performance data is to be collected
2) Put it on a working directory with enough disk space, e.g. *C:\PerfmonData* 
3) Open an elevated Windows command prompt
4) Change command prompt directory to the C:\PerfmonData directory
5) Run *rpdcli -1* to register data collector
6) Run *rpdcli -2* to start the data collector
7) Let it running while the Windows box is having a load
8) Run *rpdcli -3* to stop the data collector (or run *rpdcli -3 -debug* to keep temp files of the data collector)
9) Check the collected performance data file (a file with .BLG file extention) by:
    
    a. either analyze it manually using Perfmon tool
    
    b. or by checking the *report.html* file (from step #8 with -debug enabled) using a web browser
    
    c. or checking the BLG file using PAL tool https://github.com/clinthuffman/PAL
10) Run *rpdcli -4* to remove the data collector.
