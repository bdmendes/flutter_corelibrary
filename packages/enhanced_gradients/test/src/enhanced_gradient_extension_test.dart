import 'package:enhanced_gradients/src/enhanced_gradient_extension.dart';
import 'package:enhanced_gradients/src/gradient_approximation.dart';
import 'package:enhanced_gradients/src/hct_color_tween.dart';
import 'package:flutter/painting.dart';
import 'package:glados/glados.dart';

import '../generators.dart';

void main() {
  Glados2(
    any.colorstopList,
    any.positiveIntOrZero,
  ).test(
    'LinearGradient.enhanced is a LinearGradient with colors and stops '
    'modified by approximateGradientLists with HCT color space',
    (colorstops, subdivisions) {
      final colors = colorstops.map((cs) => cs.color).toList();
      final stops = colorstops.map((cs) => cs.stop!).toList();

      final gradient = LinearGradient(
        colors: colors,
        stops: stops.cast(),
      ).enhanced(
        approximationSubdivisions: subdivisions,
      );

      final (expectedColors, expectedStops) = approximateGradientLists(
        colors: colors,
        stops: stops,
        lerp: lerpHct,
        subdivisions: subdivisions,
      );

      expect(gradient, isA<LinearGradient>());
      expect(gradient.colors, expectedColors);
      expect(gradient.stops, expectedStops);
    },
  );

  Glados2(
    any.colorstopList,
    any.positiveIntOrZero,
  ).test(
    'EnhancedRadialGradient is a RadialGradient with colors and stops '
    'modified by approximateGradientLists with HCT color space',
    (colorstops, subdivisions) {
      final colors = colorstops.map((cs) => cs.color).toList();
      final stops = colorstops.map((cs) => cs.stop!).toList();

      final gradient = RadialGradient(
        colors: colors,
        stops: stops.cast(),
      ).enhanced(
        approximationSubdivisions: subdivisions,
      );

      final (expectedColors, expectedStops) = approximateGradientLists(
        colors: colors,
        stops: stops,
        lerp: lerpHct,
        subdivisions: subdivisions,
      );

      expect(gradient, isA<RadialGradient>());
      expect(gradient.colors, expectedColors);
      expect(gradient.stops, expectedStops);
    },
  );

  Glados2(
    any.colorstopList,
    any.positiveIntOrZero,
  ).test(
    'EnhancedSweepGradient is a SweepGradient with colors and stops '
    'modified by approximateGradientLists with HCT color space',
    (colorstops, subdivisions) {
      final colors = colorstops.map((cs) => cs.color).toList();
      final stops = colorstops.map((cs) => cs.stop!).toList();

      final gradient = SweepGradient(
        colors: colors,
        stops: stops.cast(),
      ).enhanced(
        approximationSubdivisions: subdivisions,
      );

      final (expectedColors, expectedStops) = approximateGradientLists(
        colors: colors,
        stops: stops,
        lerp: lerpHct,
        subdivisions: subdivisions,
      );

      expect(gradient, isA<SweepGradient>());
      expect(gradient.colors, expectedColors);
      expect(gradient.stops, expectedStops);
    },
  );
}
