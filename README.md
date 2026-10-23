# Ludo Dogon

**Le jeu des masques de la falaise.** Un Ludo aux motifs dogon pour téléphones Android, jouable :

- **contre l'ordinateur** (1 à 3 adversaires, niveau Facile ou Normal) ;
- **sur le même téléphone**, de 2 à 4 joueurs qui se passent le téléphone ;
- **en Bluetooth**, de 2 à 4 téléphones, **sans internet**.

Projet Flutter réalisé pour BM-INFORMATIX (Bandiagara, Mali).

## Télécharger l'APK

À chaque envoi sur la branche `main`, GitHub construit automatiquement l'APK
(onglet **Actions**, environ 10 minutes) puis le publie dans **Releases**.
Sur le téléphone : ouvrir la page *Releases* du dépôt, toucher le fichier
`LudoDogon-….apk`, l'ouvrir et autoriser l'installation d'applications
inconnues. Pour installer une nouvelle version, désinstaller d'abord
l'ancienne (chaque construction est signée avec une clé de test différente).

---

## 1. Ce qu'il faut sur l'ordinateur

- **Flutter** 3.32 ou plus récent (le code a été vérifié avec Flutter 3.47, la version stable actuelle).
  Vérifie avec `flutter --version`, et mets à jour avec `flutter upgrade` si besoin.
- **Android Studio** (pour le SDK Android) et un téléphone Android avec le
  *débogage USB* activé.
- `flutter doctor` doit afficher une coche verte pour « Android toolchain ».

## 2. Préparer le projet (une seule fois)

Le dossier contient le code du jeu, les polices, l'icône et la configuration
Android propre au jeu (autorisations Bluetooth). Les autres fichiers Android
sont générés par Flutter, pour correspondre exactement à ta version.

**Sous Windows** : double-clique sur `preparer.bat`.

**Ou à la main**, dans un terminal ouvert dans ce dossier :

```bash
flutter create --platforms=android --org com.bminformatix --project-name ludo_dogon .
flutter pub get
```

`flutter create` ne remplace aucun fichier existant : il ajoute seulement ce
qui manque.

## 3. Lancer et installer

```bash
flutter run --release          # lance le jeu sur le téléphone branché
flutter build apk --release    # fabrique l'APK à partager
```

L'APK se trouve ensuite dans `build/app/outputs/flutter-apk/app-release.apk`.
Envoie-le aux autres joueurs (WhatsApp, Bluetooth, câble…) : **tous les
téléphones doivent avoir la même version du jeu** pour jouer ensemble.

Pour des APK plus légers, un par type de processeur :

```bash
flutter build apk --release --split-per-abi
```

(`app-armeabi-v7a-release.apk` convient aux téléphones les plus anciens,
`app-arm64-v8a-release.apk` aux téléphones récents.)

## 4. Jouer en Bluetooth

1. Sur chaque téléphone : active le **Bluetooth**. Sur Android 12 ou plus
   ancien, active aussi la **localisation** (GPS) : Android l'exige pour
   trouver les téléphones proches. Le jeu n'enregistre pas la position.
2. L'hôte touche **Jouer en Bluetooth › Créer une partie**.
3. Les autres touchent **Jouer en Bluetooth › Rejoindre une partie** puis
   choisissent la partie de l'hôte dans la liste.
4. L'hôte voit « … veut rejoindre » avec un **code** : il vérifie que le
   même code s'affiche chez le joueur, puis touche **Accepter**.
5. L'hôte peut remplir les places libres avec l'ordinateur, puis touche
   **Lancer la partie**.

Le téléphone de l'hôte arbitre la partie : il lance les dés et applique les
règles, les autres téléphones envoient seulement leurs choix. Si un joueur se
déconnecte, l'ordinateur prend sa place et la partie continue. Si un joueur
connecté ne joue pas pendant 30 secondes, l'ordinateur joue à sa place.

Le Bluetooth utilise l'API *Nearby Connections* de Google : les services
Google Play doivent être présents sur les téléphones (c'est le cas de la
plupart des téléphones Android : Tecno, Infinix, Itel, Samsung…).

## 5. Règles appliquées

- 4 pions par joueur ; il faut un **6** pour sortir un pion.
- Un **6** donne un nouveau lancer ; **trois 6 de suite** font perdre le tour.
- Tomber sur un pion adverse le **renvoie à sa base** et donne un nouveau lancer.
- Les **cases de départ** et les **greniers** sont des abris : pas de capture.
- Après un tour complet, le pion entre dans son couloir ; il faut le **nombre
  exact** pour atteindre la **toguna** (le centre), ce qui donne un nouveau lancer.
- Le premier qui rentre ses 4 pions gagne ; la partie continue pour les places
  suivantes.
- Quand un seul coup est possible, il est joué automatiquement.

## 6. Organisation du code

```
lib/
  main.dart                    point d'entrée
  game/                        moteur du jeu (Dart pur, sans Flutter)
    board.dart                 plateau 15 x 15, parcours, couloirs, abris
    rules.dart                 règles, état de partie, sérialisation JSON
    ai.dart                    stratégie de l'ordinateur
  controllers/
    game_controller.dart       déroulement d'une partie, animations, arbitrage
    game_events.dart           événements échangés entre téléphones
  net/
    nearby_service.dart        couche Bluetooth (nearby_connections)
    host_session.dart          salon et arbitrage côté hôte
    client_session.dart        recherche, connexion et partie côté invité
    permissions.dart           autorisations selon la version d'Android
    links.dart                 protocole entre la partie et le réseau
  models/                      configuration de partie, profil du joueur
  ui/                          couleurs, icônes dogon, plateau, pions, dé
  screens/                     accueil, préparation, Bluetooth, jeu, règles
android/app/src/main/          manifeste (autorisations), icône, MainActivity
assets/fonts/                  polices Unbounded et Nunito Sans (licence OFL)
test/                          tests des règles et de l'accueil
```

## 7. Tests

```bash
flutter test
```

Les tests vérifient la géométrie du plateau, chaque règle (sortie, captures,
abris, arrivée exacte, trois 6, fin de partie), la sérialisation, les choix de
l'ordinateur, et jouent 300 parties complètes entre ordinateurs.

Pendant le développement :

- l'analyse statique (règles `flutter_lints`) ne signale aucun problème ;
- 250 parties locales complètes ont été simulées (contre l'ordinateur, sur le
  même téléphone, avec pauses et nouvelles parties en pleine animation) ;
- 94 parties Bluetooth ont été simulées avec un réseau virtuel (hôte + 1 à 3
  invités, latence, déconnexions, nouvelle partie) : tous les téléphones
  restent synchronisés jusqu'à la fin.

Ce qui reste à faire : un essai sur de vrais téléphones (compilation Android,
affichage et connexion Bluetooth réelle).

## 8. Personnaliser

- **Couleurs et polices** : `lib/ui/theme.dart`.
- **Prénoms de l'ordinateur** : `botNames` dans `lib/models/match.dart`.
- **Vitesse des animations** : `GameTiming` dans `lib/controllers/game_controller.dart`.
- **Icône** : `android/app/src/main/res/mipmap-*` (image source :
  `assets/icon/ludo_dogon_512.png`).
- **Nom de l'appli** : `android:label` dans `android/app/src/main/AndroidManifest.xml`.

## 9. En cas de problème

| Problème | Solution |
| --- | --- |
| « Autorisation manquante » au moment du Bluetooth | Réglages › Applications › Ludo Dogon › Autorisations : autoriser « Appareils à proximité » (et « Localisation » sur Android 12 ou moins). |
| Les téléphones ne se trouvent pas | Bluetooth activé partout, localisation activée (Android 12 ou moins), mode avion coupé, téléphones à moins de quelques mètres. Réessayer « Rejoindre ». |
| « Vos versions de Ludo Dogon sont différentes » | Installer le même APK sur tous les téléphones. |
| La compilation Android échoue à cause d'un plugin | Lancer `flutter clean`, puis `flutter pub upgrade`, puis recompiler. Vérifier aussi que `android/gradle.properties` contient bien `android.newDsl=false` (ajouté par Flutter). |
| `flutter create` refuse le nom du projet | Utiliser exactement la commande de la section 2 (avec `--project-name ludo_dogon`). |

## 10. Crédits

- Polices **Unbounded** et **Nunito Sans** : SIL Open Font License
  (voir `assets/fonts/OFL-*.txt`).
- Bluetooth : plugin [nearby_connections](https://pub.dev/packages/nearby_connections)
  (licence BSD) et [permission_handler](https://pub.dev/packages/permission_handler) (licence MIT).
- Les masques (Kanaga, Sirige, Walu, Satimbe), le grenier et la toguna sont
  dessinés de façon stylisée en hommage au pays dogon.
