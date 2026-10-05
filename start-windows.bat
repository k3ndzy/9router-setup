@echo off
:: ==============================================================================
:: 9Router Quick Starter cho Windows (Yêu cầu quyền Administrator)
:: ==============================================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [9Router] Dang yeu cau quyen Administrator...
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

title 9Router Server
echo ======================================================
echo             Khoi dong 9Router Server...
echo ======================================================
echo.

9router
pause
