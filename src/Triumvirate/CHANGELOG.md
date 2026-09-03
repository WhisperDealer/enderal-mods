# Changelog — Triumvirate: Enderal Patch

Paste each version block into the Nexus **Changelogs** tab. User-facing changes only; repo tooling
and documentation are not listed.

## 1.0.2

- Fixed: **Force of Nature turned the player invisible.** The transformation itself was working —
  you could attack and cast as the Treewarden — but nothing rendered. The cause was that the game
  never rebuilt your character's model after the change: the Treewarden's body is a large file that
  has to be read off disk, and Triumvirate asked for the redraw before it had finished loading, so
  there was nothing to draw and it never tried again. (The tell was that reloading a save while
  transformed showed the Treewarden perfectly.) The redraw now waits for the model and is forced
  properly, on the way in and on the way back.
- Your armour is also taken off for the duration and put back on when the spell ends, which is what
  Enderal's own werewolf transformation does, and Skyrim's before it.
- Fixed: **Wildshape did nothing at all.** The transformation was gated on being *sprinting* at the
  instant the spell went off, and casting a spell cancels a sprint, so the deer form could
  essentially never trigger. Wildshape now works whenever you cast it out of combat, and its
  description no longer mentions sprinting.
- Both were long-standing conversion issues rather than new ones — they date from the first release.
  Nothing else about either spell changed: same duration, same speed bonus, same everything else.

## 1.0.1

- Fixed: **every archetype's capstone spell cost far too much mana to cast.** Triumvirate never
  writes a mana cost, so the engine calculated one — and that calculation charges for a spell's
  *duration* rather than its power, which is why the long summons and auras were the worst hit.
  Fylgja of the Sun came out at 1484 mana, Spirit of the Sun at 1453, Decrepify at 1326, Nightfall
  at 1245 and Mass Immortality at 1189. A fully invested Enderal mage's whole bar is around 400–500,
  so all five were uncastable by any character the game can produce.
- Every spell now has a cost written against Enderal's own scale, where the most expensive spell in
  the game is 310. Fylgja of the Sun is 225, Spirit of the Sun 220, Decrepify 200, Nightfall 185 and
  Mass Immortality 180.
- Costs were rescaled per tier, so Enai's relative pricing inside each tier is unchanged — the
  cheapest novice spell is still the cheapest novice spell. Nothing else about the spells changed:
  no damage, duration, magnitude, cooldown or effect was touched.
- Novice and apprentice spells barely move. The higher the tier, the larger the correction.

## 1.0.0

- Initial public release.
