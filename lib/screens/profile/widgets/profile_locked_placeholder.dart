import 'package:flutter/material.dart';

import '../../../theme/studio_colors.dart';
import '../../../theme/studio_type.dart';
import '../../../widgets/studio/studio_icon.dart';

/// In place of the tabs on a private profile the viewer can't see yet (`ProfilePrivate`,
/// `ProfileRequested`): 46 under the buttons a hairline, then centred, 10 apart, a 56 circle
/// with a 28 lock, "This account is private" (17/500) and a grey 14 line. Before asking, the
/// line says what following opens; once asked ([requested]), that [firstName] will see the
/// request and how to take it back.
class ProfileLockedPlaceholder extends StatelessWidget {
  const ProfileLockedPlaceholder({super.key, this.requested = false, this.firstName = ''});

  final bool requested;

  /// The owner's first name for the Requested line; "They" when there is none.
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final who = firstName.trim().isEmpty ? 'They' : firstName.trim();
    final message = requested
        ? '$who will see your request. Tap Requested to cancel it.'
        : 'Follow to see their pieces, Scenes and Collection.';
    return Padding(
      padding: const EdgeInsets.only(top: 46),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
          child: Semantics(
            container: true,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.line),
                  ),
                  alignment: Alignment.center,
                  child: StudioIcon(StudioIcons.lock, size: 28, color: c.textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  'This account is private',
                  textAlign: TextAlign.center,
                  style: StudioType.sans(17, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: StudioType.body14(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
