/// Passage des positions du jeu aux positions à l'écran.
///
/// Les positions continues sont exprimées en « unités de case » :
/// x = colonne, y = ligne, de 0 à 15 (le centre de la case (l, c) est
/// (c + 0,5 ; l + 0,5)). Le plateau peut être tourné par quarts de tour
/// pour que chaque joueur voie sa base en bas à gauche.
library;

import 'package:flutter/widgets.dart';

import '../game/board.dart';

/// Coin d'affichage : 0 haut-gauche, 1 haut-droite, 2 bas-droite, 3 bas-gauche.
abstract final class BoardGeometry {
  /// Quarts de tour (sens horaire) pour que [seat] soit en bas à gauche.
  static int rotationFor(int seat) => (3 - seat) % 4;

  /// Coin d'écran où s'affiche la base de [seat] avec la rotation [k].
  static int cornerOf(int seat, int k) => (seat + k) % 4;

  /// Siège dont la base s'affiche dans le coin [corner].
  static int seatAtCorner(int corner, int k) => (corner - k) % 4;

  static GridPos rotateCell(GridPos cell, int k) {
    var r = cell.row, c = cell.col;
    for (var i = 0; i < k % 4; i++) {
      final nr = c;
      final nc = 14 - r;
      r = nr;
      c = nc;
    }
    return GridPos(r, c);
  }

  static Offset rotatePoint(Offset p, int k) {
    var q = p;
    for (var i = 0; i < k % 4; i++) {
      q = Offset(15 - q.dy, q.dx);
    }
    return q;
  }

  static Offset cellCenter(GridPos cell) => Offset(cell.col + 0.5, cell.row + 0.5);

  /// Emplacements des pions dans la base du siège 0 (les autres s'en
  /// déduisent par rotation).
  static const List<Offset> _baseSlots0 = [
    Offset(2.15, 2.15),
    Offset(3.85, 2.15),
    Offset(2.15, 3.85),
    Offset(3.85, 3.85),
  ];

  /// Emplacements des pions arrivés, dans le triangle du siège 0.
  static const List<Offset> _home0 = [
    Offset(6.42, 6.9),
    Offset(6.42, 8.1),
    Offset(6.42, 7.5),
    Offset(6.9, 7.5),
  ];

  static Offset baseSlot(int seat, int pawn) =>
      rotatePoint(_baseSlots0[pawn], seat);

  static Offset homeSlot(int seat, int pawn) => rotatePoint(_home0[pawn], seat);

  /// Position logique (avant rotation d'affichage) d'un pion.
  static Offset pawnPoint(int seat, int pawn, int step) {
    if (step < 0) return baseSlot(seat, pawn);
    if (step >= Board.homeStep) return homeSlot(seat, pawn);
    return cellCenter(Board.cellFor(seat, step)!);
  }

  /// Décalages pour plusieurs pions sur une même case.
  static List<Offset> stackOffsets(int count) {
    switch (count) {
      case 1:
        return const [Offset.zero];
      case 2:
        return const [Offset(-0.2, -0.2), Offset(0.2, 0.2)];
      case 3:
        return const [Offset(-0.22, -0.18), Offset(0.22, -0.18), Offset(0, 0.22)];
      default:
        return [
          for (var i = 0; i < count; i++)
            Offset(i.isEven ? -0.22 : 0.22, (i ~/ 2).isEven ? -0.22 : 0.22),
        ];
    }
  }
}
