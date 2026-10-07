@echo off
echo ========================================================
echo   Refreshing Windows Icon and Thumbnail Cache
echo ========================================================
echo Closing Windows Explorer...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul

echo Purging Icon and Thumbnail cache databases...
del /f /q "%localappdata%\IconCache.db" >nul 2>&1
del /f /q "%localappdata%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
del /f /q "%localappdata%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1

echo Restarting Windows Explorer...
start explorer.exe

echo.
echo Icon cache refreshed successfully!
timeout /t 2 >nul
