@echo off
setlocal
cd /d "%~dp0"
python -m PyInstaller build.spec
if errorlevel 1 exit /b 1
echo Built: dist\RCCustomizer.exe
