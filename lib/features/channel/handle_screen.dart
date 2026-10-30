import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/empty_state.dart';
import '../../data/models/channel.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/seed/seed_videos.dart';

/// The channel id for an @handle, or null if no channel has it:
/// the sample channels are known by the app; account channels are found
/// through `handles/{@handle}` (one read).
final channelIdForHandleProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, handle) async {
      final wanted = handle.toLowerCase();
      for (final entry in seedChannelHandles.entries) {
        if (entry.value.toLowerCase() == wanted) return entry.key;
      }
      final doc = await ref
          .read(firestoreProvider)
          .collection('handles')
          .doc(wanted)
          .get();
      final uid = doc.data()?['uid'] as String?;
      return uid == null ? null : Channel.idForUser(uid);
    });

/// `/@handle`: finds the channel, then shows its page (in the Home tab).
class HandleScreen extends ConsumerWidget {
  const HandleScreen({super.key, required this.handle});

  /// With the '@', e.g. "@blenderfoundation".
  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(channelIdForHandleProvider(handle));
    return Scaffold(
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Symbols.cloud_off,
          title: "Couldn't open $handle",
          message: 'Check your internet connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(channelIdForHandleProvider(handle)),
        ),
        data: (channelId) {
          if (channelId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/home/channel/${Uri.encodeComponent(channelId)}');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }
          return EmptyState(
            icon: Symbols.person_off,
            title: 'Channel not found',
            message: 'No channel is called $handle.',
            actionLabel: 'Go to Home',
            onAction: () => context.go('/home'),
          );
        },
      ),
    );
  }
}
