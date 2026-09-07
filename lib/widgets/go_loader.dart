import 'package:flutter/material.dart';

/// GOwallet native progress indicator, respecting reduced-motion preferences.
class GoLoader extends StatelessWidget {
  const GoLoader({super.key, this.size});
  final double? size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size ?? 40,
    child: Padding(
      padding: EdgeInsets.all((size ?? 40) * .16),
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        value: MediaQuery.disableAnimationsOf(context) ? .7 : null,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
