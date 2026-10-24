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
      'Chaque joueur a 4 pions. Le premier qui fait faire le tour du plateau '
          'à ses 4 pions et les ramène à la toguna, au centre, gagne.',
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
      'Si ton pion tombe pile sur un pion adverse, il l\'avale : le pion adverse '
          'retourne dans sa base et tu rejoues. On peut avaler partout sur le '
          'parcours, même sur les cases de départ : il n\'y a aucun abri !',
    ),
    (
      DogonIcon.toguna,
      'La toguna',
      'Après un tour complet, ton pion entre dans le couloir à ta couleur, où '
          'personne ne peut l\'avaler. Il faut le nombre exact pour atteindre la '
          'toguna. Y rentrer un pion donne un nouveau lancer.',
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
