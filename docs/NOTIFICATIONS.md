# How MyTube notifications work (and their limits)

MyTube stays on Firebase's free **Spark** plan, so there are **no Cloud
Functions** (no code running on a server). Normally a server would send
notifications. Here, **the app of the person who does something sends them
itself**, and the **Firestore security rules check** that each one is
genuine.

## What gets sent

| Event | Who gets it | Written by |
|---|---|---|
| A **public** upload (video or Short) | Up to **100** subscribers of the channel | The uploader's app, in batches of 15 |
| A comment on a video | The video's uploader | The commenter's app |
| A reply to a comment | The author of that comment | The replier's app |

Notifications are stored in the receiver's folder:
`users/{uid}/notifications/{id}`. The id says what it's about (`u_<video>`,
`c_<comment>`, `r_<reply>`), so the same thing can never be sent twice.

**What the rules check** before accepting a notification:

- It really comes from the signed-in sender, with their real profile name.
- **Upload:** the video belongs to the sender, and the receiver really is
  subscribed to the sender's channel.
- **Comment:** the comment was written by the sender, and the video belongs
  to the receiver.
- **Reply:** the reply was written by the sender, and the comment it
  answers belongs to the receiver.
- Only the receiver can read it, mark it read or unread, or delete it.

To find its subscribers, a channel runs a "collection group" query over
everyone's `subscribed/` folders. The rules only allow this for your own
channel. Older subscriptions get a `channelId` field filled in
automatically the first time their owner opens the app.

## Limits (because there is no server)

1. **The sender's tab does the work.** If the uploader closes the tab while
   the notifications are still being written (usually under a second),
   some subscribers miss that upload. A server would finish the job anyway.
2. **Capped at 100 subscribers per upload**, so one upload can't use up the
   free quota of 20,000 writes per day.
3. **No push notifications.** Nothing pops up while MyTube is closed.
   Notifications appear the next time you open the app. Push (FCM) needs a
   server to send the messages.
4. **No cleanup.** Nothing deletes old notifications automatically, because
   there are no scheduled jobs on Spark. The list shows the newest 50 (that
   is also what the unread badge counts), and you can swipe them away.
5. **Deleted things stay mentioned.** If a video or comment is deleted, its
   notification stays. Opening it shows "Video unavailable" or no comment.
6. **Replying to a reply** notifies the author of the thread's top comment,
   not the author of the reply you answered. The rules can only check the
   top comment's author.
7. **No notification settings.** You can't choose "All / Personalized /
   None" per channel, because that needs a server to filter what it sends.
