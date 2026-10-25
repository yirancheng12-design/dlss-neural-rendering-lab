@echo off
setlocal
pushd "%~dp0" || exit /b 1
if not exist ".venv\Scripts\python.exe" (
  echo Run Install.cmd first.
  popd
  pause
  exit /b 1
)
".venv\Scripts\python.exe" tools\archive.py summary
set "RUN_RESULT=%ERRORLEVEL%"
popd
if not defined SETUP_NO_PAUSE pause
exit /b %RUN_RESULT%
