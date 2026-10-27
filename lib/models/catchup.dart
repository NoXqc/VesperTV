/// How a live channel's catch-up (past programmes from the provider) is
/// requested — see `dev-notes/catchup-plan.md`. Never call this "archive":
/// that name belongs to the Media Hub.
enum CatchupKind { xc, defaultKind, append, shift, flussonic, flussonicTs }
