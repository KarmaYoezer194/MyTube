// Used on platforms other than the web (this app targets Chrome, but this
// keeps it compiling elsewhere). Assumes we're always online.

bool isOnlineNow() => true;

Stream<bool> onlineChanges() => const Stream.empty();
