# Arena room and throwables

Create a Team Arena room from Host Game. The room shows Blue and Red teams with four slots each, friends/invite buttons, Copy Room Code, Leave Room and a host-only Start Match button.

Select a vacant slot to change teams. The host validates occupancy, team capacity and match state. Both teams need at least one player. Team changes and joining are locked while the match runs. Leaving frees the slot; the host leaving closes the room.

Training and Arena use the same rifle/pistol weapon state and controller. Ammo is finite; reload consumes reserves. Respawning restores the loadout. There is no timed ammo refill.

- G: frag grenade, 2.5-second fuse, radial damage up to 5 metres, walls block blast damage.
- H: smoke grenade, 2.5-second fuse, 12-second cloud that obscures vision and stops bots seeing targets through it.
- One of each per life; respawn replenishes them.
- Throwing briefly prevents weapon fire. Death before release cancels the throw.

The host owns projectile movement, bounce, fuse, inventory and damage. Snapshots replicate projectile/smoke state. Visuals use lightweight placeholder meshes and a procedural arm-rig throw, with a Vanguard arm fallback for SWAT. No new external animation pack was downloaded.

Systems: `mvp/arena_lobby.gd`, `mvp/throwables.gd`, `mvp/throw_view.gd`. Slot authority and synchronization live in `mvp/network.gd`.

Verified: Godot headless arena/throwable lifecycle and ammo tests; independent host/client slot and smoke replication; rendered lobby and throw previews. Live friend invitation delivery across two signed-in accounts and internet NAT connectivity were not retested in this change.

Version 1.0.1 includes these changes. Create Room now asks for a password (4–64 characters), without sending invites. Join Room accepts the generated eight-character Room ID and host's password. The host validates a one-time challenge response before accepting a player. The room password is not stored in the public room database.

The live database mode constraint was updated to accept both `ffa` and `tdm`. The upgrade SQL is in `mvp/arena_mode_constraint.sql`.
