# AUDITOR QUESTIONS — TASK-002

1. **Save integrity (SEC-1/2/3, GP-26).** Is a hand-written session lock plus retry/dirty-flag fix preferable to adopting an established profile library (ProfileStore)? A library changes how saves are loaded and stored; the existing key `player_<UserId>` and v1 schema must keep loading. What migration safety would you require?
2. **Pearl eligibility (GP-23/24, SEC-4).** Fair rule options: pay only players present for a minimum share of the nights, or pay per night survived while present (so a mid-run leaver keeps what they earned). Which do you recommend, and should AFK detection exist? This changes rewards and needs owner approval.
3. **Crew cap and fuel scaling (GP-25, GP-2).** Hard-cap at 4 in the join path, and scale fuel by crew rather than by everyone on the server. Any hidden coupling you would check first?
4. **Position trust (SEC-6).** Is a server-side movement-speed sanity check plus crew-only loot gating enough, or should pickup range be checked against the server's own character position only?
5. **Boss redesign (GP-11 to GP-14).** Four simultaneous Brutes outdamage the tower. Which levers do you prefer (boss health per extra boss, tower durability, staggered spawns, damage cap)? The balance numbers are owner decisions.
6. **Economy (GP-21/22).** Shell income exceeds sinks several times over, and Pearls take about 29 wins to clear the shop. Should the merchant be sized from the Shell surplus before building it?
7. **Measurement plan.** What minimum 4-player and phone measurements would you accept as evidence for GP-37/GP-47, given Studio cannot show real phone frame rate?

No concern has been invented to fill this list; items 1, 2 and 5 are the real forks.
