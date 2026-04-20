@echo off
chcp 65001 >nul
title Smart Vocab Server
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '%~dp0start_server.ps1'"
pause
