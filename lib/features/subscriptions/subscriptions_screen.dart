import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/mytube_logo.dart';

/// Subscriptions tab. A subscriptions feed is out of scope for this demo,
/// so this screen is only a friendly empty state.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(titleSpacing: 12, title: const MyTubeLogo()),
      body: EmptyState(
        icon: Symbols.subscriptions,
        title: 'No subscriptions feed in this demo',
        message:
            'You can still subscribe to channels from the watch page. '
            'Explore videos to find something to watch.',
        actionLabel: 'Explore videos',
        onAction: () => context.go('/home'),
      ),
    );
  }
}
