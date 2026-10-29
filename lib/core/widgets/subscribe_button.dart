import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repositories/user_repository.dart';
import '../../features/auth/require_account.dart';
import '../theme/app_colors.dart';

/// YouTube's Subscribe pill.
///
/// Not subscribed: white pill (black in light theme) saying "Subscribe".
/// Subscribed: grey pill with a bell, "Subscribed" and a ⌄. Tapping it asks
/// whether to unsubscribe. The change between the two is animated (color,
/// width and content).
///
/// Saved in Firestore at users/{uid}/subscribed/{channelId}.
class SubscribeButton extends ConsumerWidget {
  const SubscribeButton({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  final String channelId;
  final String channelName;

  static const _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final subscribed =
        ref.watch(isSubscribedProvider(channelId)).value ?? false;
    final repository = ref.read(userRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> setSubscribed(bool value) {
      return repository.setSubscribed(channelId, subscribed: value).catchError((
        Object _,
      ) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't save. Check your internet connection."),
          ),
        );
      });
    }

    Future<void> confirmUnsubscribe() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text('Unsubscribe from $channelName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Unsubscribe'),
            ),
          ],
        ),
      );
      if (confirmed ?? false) await setSubscribed(false);
    }

    final foreground = subscribed
        ? colors.textPrimary
        : colors.chipSelectedForeground;

    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOut,
      height: 36,
      decoration: BoxDecoration(
        color: subscribed ? colors.surface : colors.chipSelectedBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: subscribed
              ? confirmUnsubscribe
              : () {
                  // Guests get the "Sign in to …" sheet instead.
                  if (!checkSignedIn(
                    context,
                    ref,
                    reason: SignInReason.subscribe,
                  )) {
                    return;
                  }
                  setSubscribed(true);
                },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: subscribed ? 12 : 16),
            // AnimatedSize smoothly changes the pill's width.
            child: AnimatedSize(
              duration: _duration,
              curve: Curves.easeOut,
              child: AnimatedSwitcher(
                duration: _duration,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: subscribed
                    ? Row(
                        key: const ValueKey('subscribed'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.notifications,
                            size: 20,
                            color: foreground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Subscribed',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Symbols.keyboard_arrow_down,
                            size: 18,
                            color: foreground,
                          ),
                        ],
                      )
                    : Center(
                        key: const ValueKey('subscribe'),
                        widthFactor: 1,
                        child: Text(
                          'Subscribe',
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
