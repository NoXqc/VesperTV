import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every text field in the app must sit behind `TvTextFieldGate` (keyboard
/// only on OK). An ungated field raises the keyboard as soon as the D-pad
/// reaches it, and on a Fire TV the keyboard then owns the remote: nothing
/// below the field can be reached. That bug came back screen after screen
/// (Search, Add Playlist, Sports, then EPG matching and TMDB — user report,
/// 2026-10-19), so this test fails the build when a new one appears.
///
/// A field that really should open its keyboard at once carries a
/// `// tv-text-field-gate: exempt — <why>` comment right above it.
void main() {
  test('every TextField is gated (or explicitly exempt)', () {
    final offenders = <String>[];
    final field = RegExp(r'\b(TextField|TextFormField)\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path
          .replaceAll('\\', '/')
          .endsWith('widgets/tv_text_field_gate.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      final fields = field.allMatches(src).length;
      if (fields == 0) continue;
      final gates = 'TvTextFieldGate('.allMatches(src).length;
      final exempt = 'tv-text-field-gate: exempt'.allMatches(src).length;
      if (fields > gates + exempt) {
        offenders.add('${f.path}: $fields field(s), $gates gated, '
            '$exempt exempt');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Wrap these in TvTextFieldGate (lib/widgets/'
            'tv_text_field_gate.dart; FocusNodeOwner for dialogs), or add '
            'a "tv-text-field-gate: exempt — why" comment.');
  });
}
