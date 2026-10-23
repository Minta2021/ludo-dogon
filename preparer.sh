#!/usr/bin/env sh
# Ludo Dogon : préparation du projet Android (Linux / macOS).
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null 2>&1 || { echo "Flutter est introuvable : installe-le puis relance ce script."; exit 1; }
flutter create --platforms=android --org com.bminformatix --project-name ludo_dogon .
flutter pub get
echo ""
echo "Projet prêt !"
echo "  Jouer sur le téléphone branché :  flutter run --release"
echo "  Fabriquer l'APK à partager :      flutter build apk --release"
