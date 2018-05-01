@echo off

color 17

set ROOTPATH=%~dp0
set SHELLPATH="%~dp0cygwin"

rename update\update_data_full_public.zip update_data_public.zip
rename update\update_full_*.zip update_all_hw.zip

cd %SHELLPATH%
call shell.bat %ROOTPATH%/hwota_oreo.sh %ROOTPATH%

