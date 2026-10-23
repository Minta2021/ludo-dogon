@echo off
chcp 65001 >nul
title Ludo Dogon - preparation du projet
cd /d "%~dp0"
echo.
echo  === Ludo Dogon : preparation du projet Android ===
echo.
where flutter >nul 2>nul
if errorlevel 1 (
  echo  Flutter est introuvable. Installe Flutter, ajoute-le au PATH,
  echo  puis relance ce fichier.
  echo.
  pause
  exit /b 1
)
call flutter create --platforms=android --org com.bminformatix --project-name ludo_dogon .
if errorlevel 1 goto erreur
call flutter pub get
if errorlevel 1 goto erreur
echo.
echo  Projet pret !
echo.
echo  Pour jouer sur le telephone branche (debogage USB active) :
echo      flutter run --release
echo.
echo  Pour fabriquer l'APK a partager :
echo      flutter build apk --release
echo.
pause
exit /b 0

:erreur
echo.
echo  Une erreur est survenue. Lance "flutter doctor" pour verifier l'installation.
echo.
pause
exit /b 1
