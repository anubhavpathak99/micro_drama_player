import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_drama_interactive_player/app.dart';
import 'package:micro_drama_interactive_player/presentation/feed/feed_screen.dart';

void main() {
  testWidgets('boots into the feed screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MicroDramaApp()));

    expect(find.byType(FeedScreen), findsOneWidget);
  });
}
