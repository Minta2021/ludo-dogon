/// Géométrie du plateau de Ludo Dogon.
///
/// Le plateau est une grille de 15 x 15 cases. Les coordonnées vont de 0 à 14
/// (ligne, colonne), l'origine étant le coin supérieur gauche.
///
/// Sièges (dans l'ordre du tour, sens des aiguilles d'une montre) :
///   0 = Kanaga (ocre), base en haut à gauche
///   1 = Sirige (indigo), base en haut à droite
///   2 = Walu (terre cuite), base en bas à droite
///   3 = Satimbe (vert mil), base en bas à gauche
library;

/// Une case de la grille 15 x 15.
class GridPos {
  const GridPos(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 31 + col;

  @override
  String toString() => '($row,$col)';
}

/// Constantes et calculs de position du plateau.
abstract final class Board {
  /// Nombre de cases du parcours commun.
  static const int trackLength = 52;

  /// Nombre de cases du couloir d'arrivée de chaque joueur.
  static const int laneLength = 5;

  /// Dernière étape sur le parcours commun (0 = case de départ).
  static const int lastTrackStep = 50;

  /// Étape d'arrivée à la toguna (centre du plateau).
  static const int homeStep = 56;

  /// Valeur d'étape d'un pion encore dans sa base.
  static const int inBase = -1;

  static const int pawnsPerPlayer = 4;
  static const int seatCount = 4;

  /// Le parcours commun, en partant de la case de départ du siège 0
  /// et en tournant dans le sens des aiguilles d'une montre.
  static const List<GridPos> track = [
    GridPos(6, 1), GridPos(6, 2), GridPos(6, 3), GridPos(6, 4), GridPos(6, 5), // 0-4
    GridPos(5, 6), GridPos(4, 6), GridPos(3, 6), GridPos(2, 6), GridPos(1, 6), // 5-9
    GridPos(0, 6), GridPos(0, 7), // 10-11
    GridPos(0, 8), GridPos(1, 8), GridPos(2, 8), GridPos(3, 8), GridPos(4, 8), // 12-16
    GridPos(5, 8), // 17
    GridPos(6, 9), GridPos(6, 10), GridPos(6, 11), GridPos(6, 12), GridPos(6, 13), // 18-22
    GridPos(6, 14), GridPos(7, 14), // 23-24
    GridPos(8, 14), GridPos(8, 13), GridPos(8, 12), GridPos(8, 11), GridPos(8, 10), // 25-29
    GridPos(8, 9), // 30
    GridPos(9, 8), GridPos(10, 8), GridPos(11, 8), GridPos(12, 8), GridPos(13, 8), // 31-35
    GridPos(14, 8), GridPos(14, 7), // 36-37
    GridPos(14, 6), GridPos(13, 6), GridPos(12, 6), GridPos(11, 6), GridPos(10, 6), // 38-42
    GridPos(9, 6), // 43
    GridPos(8, 5), GridPos(8, 4), GridPos(8, 3), GridPos(8, 2), GridPos(8, 1), // 44-48
    GridPos(8, 0), GridPos(7, 0), GridPos(6, 0), // 49-51
  ];

  /// Couloirs d'arrivée (5 cases chacun), du bord vers le centre.
  static const List<List<GridPos>> lanes = [
    [GridPos(7, 1), GridPos(7, 2), GridPos(7, 3), GridPos(7, 4), GridPos(7, 5)],
    [GridPos(1, 7), GridPos(2, 7), GridPos(3, 7), GridPos(4, 7), GridPos(5, 7)],
    [GridPos(7, 13), GridPos(7, 12), GridPos(7, 11), GridPos(7, 10), GridPos(7, 9)],
    [GridPos(13, 7), GridPos(12, 7), GridPos(11, 7), GridPos(10, 7), GridPos(9, 7)],
  ];

  /// Coin supérieur gauche du carré 6 x 6 de la base de chaque siège.
  static const List<GridPos> baseOrigins = [
    GridPos(0, 0),
    GridPos(0, 9),
    GridPos(9, 9),
    GridPos(9, 0),
  ];

  /// Index (sur le parcours commun) de la case de départ du siège.
  static int startIndex(int seat) => seat * 13;

  /// Index sur le parcours commun d'un pion du siège [seat] à l'étape [step]
  /// (0 à [lastTrackStep]).
  static int absoluteIndex(int seat, int step) {
    assert(step >= 0 && step <= lastTrackStep);
    return (startIndex(seat) + step) % trackLength;
  }

  /// Case de départ d'un des sièges (une par siège).
  static bool isStartIndex(int index) => index % 13 == 0;

  /// Siège dont [index] est la case de départ, sinon null.
  static int? startSeatOf(int index) => isStartIndex(index) ? index ~/ 13 : null;

  /// Case de la grille occupée par un pion du siège [seat] à l'étape [step].
  /// Renvoie null si le pion est dans sa base ou déjà arrivé.
  static GridPos? cellFor(int seat, int step) {
    if (step < 0 || step >= homeStep) return null;
    if (step <= lastTrackStep) return track[absoluteIndex(seat, step)];
    return lanes[seat][step - lastTrackStep - 1];
  }
}
