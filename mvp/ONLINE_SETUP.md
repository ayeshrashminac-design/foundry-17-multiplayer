# Online login and room-code setup

The game is connected to the Supabase project `funihyfxlliwnpthamdi`. The database schema, RLS policies, project URL, and publishable key are already configured.

Players can select **Gmail / Email Login**, create an account, confirm the message sent to their inbox, and then sign in. The game stores the refresh token under Godot's per-user data folder, displays a stable `F17-...` player ID, and requires a server-verified session for online registration.

After login, players add each other with the `F17-...` ID. Friend requests and game invites are stored in Supabase with row-level security, so only the involved players can read or change them. The invite list refreshes automatically every five seconds.

The host selects **Create Internet Room**, chooses the player limit, kill limit, duration, and friends to invite. The game attempts UDP 7777 port mapping with router UPnP, discovers the public address through the authenticated `public-address` Edge Function, creates an expiring room, and sends 15-minute invites. The recipient joins from **Game Invites**. Routers without UPnP or connections behind carrier-grade NAT still require a manual UDP 7777 forwarding rule or a future dedicated relay/server.

Google one-click OAuth is enabled. The Google Cloud Web OAuth client redirects through `https://funihyfxlliwnpthamdi.supabase.co/auth/v1/callback`, and Supabase permits the desktop callback `http://127.0.0.1:53682/callback`. The OAuth secret remains in Supabase and is not stored in the game project.

Training remains available without login. Public direct-IP and LAN controls are hidden from the player UI; multiplayer discovery is handled through friends and invites.

## Migration status

Backend recreated under ayeshrashmin5@gmail.com. Google OAuth, the desktop callback, email login, database policies, and the authenticated public-address function are configured. Internet matches still use direct ENet/UDP: Supabase is account and room discovery infrastructure, not a gameplay relay. End-to-end play across independent internet connections has not been verified.
