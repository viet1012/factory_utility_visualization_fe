@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM CONFIG
REM ============================================================

REM Folder project Flutter hiện tại
set "PROJECT_DIR=%~dp0"

REM Output được Flutter tạo sau flutter build web
set "BUILD_DIR=%PROJECT_DIR%build\web"

REM Flutter bootstrap custom
set "CUSTOM_BOOTSTRAP=%PROJECT_DIR%custom\flutter_bootstrap.js"

REM Folder deploy chính
REM Folder này chứa:
REM - Dockerfile
REM - nginx.conf
REM - build\
set "OUTPUT_ROOT=D:\Viet\Utility\BUILD_WEB"

REM Chỉ xóa và replace folder này
set "OUTPUT_DIR=%OUTPUT_ROOT%\build"


REM ============================================================
REM WINDOW TITLE
REM ============================================================

title Utility - Flutter Web Build

cls

echo.
echo ============================================================
echo          UTILITY FLUTTER WEB BUILD
echo ============================================================
echo.

echo Project:
echo   %PROJECT_DIR%
echo.

echo Flutter build:
echo   %BUILD_DIR%
echo.

echo Deploy root:
echo   %OUTPUT_ROOT%
echo.

echo Deploy build:
echo   %OUTPUT_DIR%
echo.


REM ============================================================
REM GO TO PROJECT ROOT
REM ============================================================

cd /d "%PROJECT_DIR%"

if errorlevel 1 (
    echo.
    echo [ERROR] Cannot open Flutter project directory.
    goto :FAILED
)


REM ============================================================
REM CHECK PUBSPEC
REM ============================================================

if not exist "%PROJECT_DIR%pubspec.yaml" (
    echo.
    echo [ERROR] pubspec.yaml not found.
    echo.
    echo Please put this .bat file in Flutter project root.
    goto :FAILED
)

echo [OK] pubspec.yaml found.


REM ============================================================
REM CHECK FLUTTER COMMAND
REM ============================================================

where flutter >nul 2>&1

if errorlevel 1 (
    echo.
    echo [ERROR] Flutter command not found.
    echo.
    echo Please add Flutter SDK to PATH.
    goto :FAILED
)

echo [OK] Flutter command found.


REM ============================================================
REM CHECK CUSTOM BOOTSTRAP
REM ============================================================

if not exist "%CUSTOM_BOOTSTRAP%" (
    echo.
    echo [ERROR] Custom flutter_bootstrap.js not found:
    echo.
    echo   %CUSTOM_BOOTSTRAP%
    echo.
    echo Expected structure:
    echo.
    echo   project\
    echo   ^|-- build_web.bat
    echo   ^|-- custom\
    echo   ^|   ^|-- flutter_bootstrap.js
    echo   ^|-- pubspec.yaml
    echo.
    goto :FAILED
)

echo [OK] Custom flutter_bootstrap.js found.


REM ============================================================
REM CHECK DEPLOY ROOT
REM ============================================================

if not exist "%OUTPUT_ROOT%" (
    echo.
    echo Deploy root does not exist.
    echo Creating:
    echo   %OUTPUT_ROOT%
    echo.

    mkdir "%OUTPUT_ROOT%"

    if errorlevel 1 (
        echo.
        echo [ERROR] Cannot create deploy root.
        goto :FAILED
    )
)

echo [OK] Deploy root ready.


REM ============================================================
REM STEP 1
REM FLUTTER PUB GET
REM ============================================================

echo.
echo ============================================================
echo [1/7] FLUTTER PUB GET
echo ============================================================
echo.

call flutter pub get

if errorlevel 1 (
    echo.
    echo [ERROR] flutter pub get failed.
    goto :FAILED
)

echo.
echo [OK] flutter pub get completed.


REM ============================================================
REM STEP 2
REM BUILD FLUTTER WEB
REM ============================================================

echo.
echo ============================================================
echo [2/7] FLUTTER BUILD WEB
echo ============================================================
echo.

call flutter build web

if errorlevel 1 (
    echo.
    echo [ERROR] flutter build web failed.
    goto :FAILED
)

echo.
echo [OK] flutter build web completed.


REM ============================================================
REM STEP 3
REM CHECK FLUTTER BUILD OUTPUT
REM ============================================================

echo.
echo ============================================================
echo [3/7] CHECK BUILD OUTPUT
echo ============================================================
echo.

if not exist "%BUILD_DIR%" (
    echo.
    echo [ERROR] Flutter build folder not found:
    echo.
    echo   %BUILD_DIR%
    goto :FAILED
)

if not exist "%BUILD_DIR%\index.html" (
    echo.
    echo [ERROR] index.html not found in Flutter build.
    goto :FAILED
)

if not exist "%BUILD_DIR%\main.dart.js" (
    echo.
    echo [ERROR] main.dart.js not found in Flutter build.
    goto :FAILED
)

echo [OK] build\web found.
echo [OK] index.html found.
echo [OK] main.dart.js found.


REM ============================================================
REM STEP 4
REM DELETE FLUTTER SERVICE WORKER
REM ============================================================

echo.
echo ============================================================
echo [4/7] REMOVE FLUTTER SERVICE WORKER
echo ============================================================
echo.

if exist "%BUILD_DIR%\flutter_service_worker.js" (

    echo Deleting:
    echo   %BUILD_DIR%\flutter_service_worker.js
    echo.

    del /F /Q "%BUILD_DIR%\flutter_service_worker.js"

    if exist "%BUILD_DIR%\flutter_service_worker.js" (
        echo.
        echo [ERROR] Cannot delete flutter_service_worker.js
        goto :FAILED
    )

    echo [OK] flutter_service_worker.js deleted.

) else (

    echo [INFO] flutter_service_worker.js does not exist.

)


REM ============================================================
REM STEP 5
REM REPLACE FLUTTER BOOTSTRAP
REM ============================================================

echo.
echo ============================================================
echo [5/7] REPLACE FLUTTER BOOTSTRAP
echo ============================================================
echo.

if exist "%BUILD_DIR%\flutter_bootstrap.js" (

    echo Removing generated flutter_bootstrap.js...

    del /F /Q "%BUILD_DIR%\flutter_bootstrap.js"

    if exist "%BUILD_DIR%\flutter_bootstrap.js" (
        echo.
        echo [ERROR] Cannot remove generated flutter_bootstrap.js
        goto :FAILED
    )
)

echo Copying custom flutter_bootstrap.js...
echo.

copy /Y ^
    "%CUSTOM_BOOTSTRAP%" ^
    "%BUILD_DIR%\flutter_bootstrap.js" >nul

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to copy custom flutter_bootstrap.js
    goto :FAILED
)

if not exist "%BUILD_DIR%\flutter_bootstrap.js" (
    echo.
    echo [ERROR] flutter_bootstrap.js missing after replacement.
    goto :FAILED
)

echo [OK] Custom flutter_bootstrap.js installed.


REM ============================================================
REM STEP 6
REM DELETE ONLY OLD DEPLOY BUILD FOLDER
REM ============================================================

echo.
echo ============================================================
echo [6/7] PREPARE DEPLOY BUILD FOLDER
echo ============================================================
echo.

echo Deploy root will NOT be deleted:
echo   %OUTPUT_ROOT%
echo.

echo Only this folder will be replaced:
echo   %OUTPUT_DIR%
echo.

if exist "%OUTPUT_DIR%" (

    echo Removing old build folder...
    echo.

    rmdir /S /Q "%OUTPUT_DIR%"

    if exist "%OUTPUT_DIR%" (
        echo.
        echo [ERROR] Cannot remove old build folder:
        echo.
        echo   %OUTPUT_DIR%
        echo.
        echo Check whether Docker, nginx or another application
        echo is currently locking files inside this folder.
        goto :FAILED
    )
)

echo Creating new build folder...

mkdir "%OUTPUT_DIR%"

if errorlevel 1 (
    echo.
    echo [ERROR] Cannot create:
    echo.
    echo   %OUTPUT_DIR%
    goto :FAILED
)

echo [OK] Deploy build folder ready.


REM ============================================================
REM STEP 7
REM COPY FLUTTER BUILD TO DEPLOY BUILD
REM ============================================================

echo.
echo ============================================================
echo [7/7] COPY FLUTTER BUILD
echo ============================================================
echo.

echo Source:
echo   %BUILD_DIR%
echo.

echo Destination:
echo   %OUTPUT_DIR%
echo.

robocopy ^
    "%BUILD_DIR%" ^
    "%OUTPUT_DIR%" ^
    /E ^
    /COPY:DAT ^
    /DCOPY:DAT ^
    /R:2 ^
    /W:1 ^
    /NFL ^
    /NDL ^
    /NJH ^
    /NJS ^
    /NP

set "ROBOCOPY_CODE=%ERRORLEVEL%"

REM ============================================================
REM ROBOCOPY EXIT CODE
REM
REM 0 - 7  = SUCCESS
REM >= 8   = ERROR
REM ============================================================

if %ROBOCOPY_CODE% GEQ 8 (
    echo.
    echo [ERROR] Robocopy failed.
    echo.
    echo Error code:
    echo   %ROBOCOPY_CODE%
    goto :FAILED
)

echo.
echo [OK] Flutter web copied successfully.


REM ============================================================
REM FINAL SAFETY CHECK
REM ============================================================

echo.
echo ============================================================
echo FINAL CHECK
echo ============================================================
echo.


REM ------------------------------------------------------------
REM SERVICE WORKER MUST NOT EXIST
REM ------------------------------------------------------------

if exist "%OUTPUT_DIR%\flutter_service_worker.js" (

    echo [WARNING] flutter_service_worker.js found in deploy folder.
    echo Removing it...

    del /F /Q "%OUTPUT_DIR%\flutter_service_worker.js"
)

if exist "%OUTPUT_DIR%\flutter_service_worker.js" (
    echo.
    echo [ERROR] flutter_service_worker.js still exists.
    goto :FAILED
)

echo [OK] Service worker removed.


REM ------------------------------------------------------------
REM BOOTSTRAP
REM ------------------------------------------------------------

if not exist "%OUTPUT_DIR%\flutter_bootstrap.js" (
    echo.
    echo [ERROR] flutter_bootstrap.js missing from deploy build.
    goto :FAILED
)

echo [OK] flutter_bootstrap.js


REM ------------------------------------------------------------
REM INDEX
REM ------------------------------------------------------------

if not exist "%OUTPUT_DIR%\index.html" (
    echo.
    echo [ERROR] index.html missing from deploy build.
    goto :FAILED
)

echo [OK] index.html


REM ------------------------------------------------------------
REM MAIN DART JS
REM ------------------------------------------------------------

if not exist "%OUTPUT_DIR%\main.dart.js" (
    echo.
    echo [ERROR] main.dart.js missing from deploy build.
    goto :FAILED
)

echo [OK] main.dart.js


REM ------------------------------------------------------------
REM VERIFY DEPLOY ROOT WAS PRESERVED
REM ------------------------------------------------------------

echo.
echo Checking deploy root files...
echo.

if exist "%OUTPUT_ROOT%\Dockerfile" (
    echo [OK] Dockerfile preserved.
) else (
    echo [WARNING] Dockerfile not found.
)

if exist "%OUTPUT_ROOT%\nginx.conf" (
    echo [OK] nginx.conf preserved.
) else (
    echo [WARNING] nginx.conf not found.
)


REM ============================================================
REM SUCCESS
REM ============================================================

echo.
echo.
echo ############################################################
echo #
echo #                    BUILD SUCCESS
echo #
echo ############################################################
echo.

echo Flutter project:
echo   %PROJECT_DIR%
echo.

echo Flutter build:
echo   %BUILD_DIR%
echo.

echo Deploy root:
echo   %OUTPUT_ROOT%
echo.

echo Flutter deploy:
echo   %OUTPUT_DIR%
echo.

echo ------------------------------------------------------------
echo CUSTOM BOOTSTRAP       : OK
echo SERVICE WORKER         : REMOVED
echo INDEX.HTML             : OK
echo MAIN.DART.JS           : OK
echo DOCKERFILE             : PRESERVED
echo NGINX.CONF             : PRESERVED
echo ------------------------------------------------------------
echo.


REM ============================================================
REM OPEN DEPLOY ROOT
REM ============================================================

echo Opening:
echo   %OUTPUT_ROOT%
echo.

start "" "%OUTPUT_ROOT%"

echo.
echo Press any key to close...
pause >nul

exit /b 0


REM ============================================================
REM FAILED
REM ============================================================

:FAILED

echo.
echo.
echo ############################################################
echo #
echo #                    BUILD FAILED
echo #
echo ############################################################
echo.

echo Please check the error above.
echo.

pause

exit /b 1