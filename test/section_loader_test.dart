import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio3/widgets/loading/app_skeletons.dart';
import 'package:studio3/widgets/loading/section_loader.dart';

/// The app's loading rule, as an executable spec: a skeleton only ever
/// stands in for backend-dependent content that has nothing to show yet.
void main() {
  group('sectionPhase', () {
    test('data wins over a refresh in flight', () {
      expect(
        sectionPhase(hasData: true, loading: true),
        SectionPhase.content,
      );
    });

    test('skeleton only when there is nothing and a request is running', () {
      expect(
        sectionPhase(hasData: false, loading: true),
        SectionPhase.skeleton,
      );
    });

    test('loaded-and-genuinely-empty is an empty state, not a skeleton', () {
      expect(
        sectionPhase(hasData: false, loading: false),
        SectionPhase.empty,
      );
    });
  });

  group('SectionLoader', () {
    Widget host({required bool hasData, required bool loading}) {
      return MaterialApp(
        home: SectionLoader(
          hasData: hasData,
          loading: loading,
          skeleton: (_) => const CardListSkeleton(),
          empty: (_) => const Text('nothing here'),
          content: (_) => const Text('real content'),
        ),
      );
    }

    testWidgets('renders the skeleton on a cold, empty load', (tester) async {
      await tester.pumpWidget(host(hasData: false, loading: true));
      expect(find.byType(CardListSkeleton), findsOneWidget);
      expect(find.text('real content'), findsNothing);
    });

    testWidgets('never replaces existing content while refreshing', (
      tester,
    ) async {
      await tester.pumpWidget(host(hasData: true, loading: true));
      expect(find.text('real content'), findsOneWidget);
      expect(find.byType(CardListSkeleton), findsNothing);
    });

    testWidgets('cached content painted first is not swapped for a skeleton', (
      tester,
    ) async {
      // Frame 1: cache seeded, background refresh kicks off.
      await tester.pumpWidget(host(hasData: true, loading: true));
      expect(find.text('real content'), findsOneWidget);
      // Frame 2: refresh still running — still no placeholder.
      await tester.pumpWidget(host(hasData: true, loading: true));
      expect(find.byType(CardListSkeleton), findsNothing);
    });

    testWidgets('shows the empty state once the load finishes', (tester) async {
      await tester.pumpWidget(host(hasData: false, loading: false));
      expect(find.text('nothing here'), findsOneWidget);
      expect(find.byType(CardListSkeleton), findsNothing);
    });

    testWidgets('falls back to content when no empty state is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SectionLoader(
            hasData: false,
            loading: false,
            skeleton: (_) => const CardListSkeleton(),
            content: (_) => const Text('list renders its own zero-state'),
          ),
        ),
      );
      expect(find.text('list renders its own zero-state'), findsOneWidget);
    });
  });
}
