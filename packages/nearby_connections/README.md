# nearby_connections (copie locale)

Copie du plugin [nearby_connections](https://pub.dev/packages/nearby_connections)
4.3.0 de Prerak Mann (licence BSD-2, voir `LICENSE`), modifiée pour Ludo Dogon :

- bibliothèque Google `play-services-nearby` 19.5.1 ;
- code d'erreur Nearby (8007, 8034…) transmis au jeu ;
- statuts de connexion inconnus traités comme une erreur au lieu de planter ;
- contexte de l'application utilisé si l'activité n'est pas disponible ;
- autorisations déclarées dans le manifeste de l'application.
