/// Les règles du jeu, expliquées simplement.
library;

import 'package:flutter/material.dart';

import '../ui/dogon_icons.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const _rules = <(DogonIcon, String, String)>[
    (
      DogonIcon.kanaga,
      'Le but',
      'Chaque joueur a 4 lutins portant son masque. Le premier qui fait faire le '
          'tour du plateau à ses 4 lutins et les ramène à la toguna, au centre, gagne.',
    ),
    (
      DogonIcon.chevron,
      'Sortir un pion',
      'Il faut faire 6 pour sortir un pion de sa base. Il se place sur la '
          'case de départ, marquée d\'une flèche à ta couleur.',
    ),
    (
      DogonIcon.refresh,
      'Le six',
      'Le 6 sort plus souvent qu\'avec un dé ordinaire : une chance sur quatre. '
          'Chaque 6 donne un nouveau lancer, jusqu\'à cinq 6 de suite. '
          'Au sixième 6 d\'affilée, le tour est perdu !',
    ),
    (
      DogonIcon.walu,
      'Avaler',
      'Si ton lutin tombe pile sur un lutin adverse, il lui fait une prise de '
          'karaté et l\'avale : le lutin adverse retourne dans sa base et tu rejoues.',
    ),
    (
      DogonIcon.star,
      'Les abris',
      'Huit cases protègent ton lutin : les 4 tapis (les cases de départ '
          'colorées, à bordure tissée) et les 4 étoiles. Là, personne ne peut '
          'l\'avaler, et plusieurs lutins peuvent s\'y côtoyer.',
    ),
    (
      DogonIcon.toguna,
      'La maison et la toguna',
      'Après un tour complet, ton lutin entre dans le couloir à ta couleur : sa '
          'maison. Il faut le nombre exact pour atteindre la toguna, au centre. '
          'Y rentrer un lutin donne un nouveau lancer.',
    ),
    (
      DogonIcon.sirige,
      'Attention au dernier lutin',
      'Quand il ne te reste qu\'un seul lutin en jeu et qu\'il attend dans ta '
          'maison, il n\'y est plus à l\'abri : un adversaire qui fait le nombre '
          'exact peut y entrer, l\'avaler, puis ressortir devant ta maison. Ton '
          'lutin tremble pour te prévenir !',
    ),
    (
      DogonIcon.bluetooth,
      'En Bluetooth',
      'Un joueur crée la partie, les autres la rejoignent depuis leur téléphone, '
          'sans internet. Si quelqu\'un se déconnecte, l\'ordinateur prend sa place.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Règles du jeu',
              subtitle: 'Ludo Dogon',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _rules.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final (icon, title, text) = _rules[i];
                  return InfoCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: DogonColors.surfaceHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: DogonIconView(icon,
                                size: 26, color: DogonColors.ochre, strokeWidth: 1.8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppText.title.copyWith(fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(text, style: AppText.body.copyWith(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const CliffFrieze(),
          ],
        ),
      ),
    );
  }
}
