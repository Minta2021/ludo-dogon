/// Le dé de Ludo Dogon : le 6 sort plus souvent qu'avec un dé ordinaire.
library;

import 'dart:math';

abstract final class Dice {
  /// Chance d'obtenir un 6 (un dé ordinaire : 1 sur 6, soit environ 0,167).
  static const double sixChance = 0.25;

  /// Lance le dé : 6 avec la probabilité [sixChance], sinon une valeur de
  /// 1 à 5, chacune avec la même chance.
  static int roll(Random rng) {
    if (rng.nextDouble() < sixChance) return 6;
    return 1 + rng.nextInt(5);
  }
}
