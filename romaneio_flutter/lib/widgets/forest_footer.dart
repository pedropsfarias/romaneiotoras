part of '../main.dart';

class ForestFooter extends StatelessWidget {
  const ForestFooter({super.key, this.height = double.infinity});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: IgnorePointer(
      child: Image.asset(
        'assets/images/floresta_rodape_transparente.png',
        fit: BoxFit.fitWidth,
        alignment: Alignment.bottomCenter,
      ),
    ),
  );
}
