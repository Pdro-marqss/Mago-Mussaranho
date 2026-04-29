@echo off
echo Compilando Dodge Master...

:: Cria a pasta de build se ela nao existir
if not exist "dist" mkdir "dist"

:: Compila o jogo
odin build src -out:dist/mago_musaranho.exe -o:speed -subsystem:windows

:: Copia a DLL da Raylib para a pasta de build automaticamente
:: (Ajuste o caminho abaixo para onde o seu Odin esta instalado)
copy "C:\odin\vendor\raylib\windows\raylib.dll" "dist\raylib.dll" /Y

echo.
echo Build concluido! O jogo esta na pasta /dist
pause