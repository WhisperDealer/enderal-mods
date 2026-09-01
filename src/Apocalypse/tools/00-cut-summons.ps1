#requires -Version 5.1
<#
.SYNOPSIS
  The single definition of which summons are withheld from distribution. Dot-source it.

.DESCRIPTION
  Sets `$removed`, a list of spell EditorID stems (the `_Book`/`_Scroll` suffix is stripped before
  comparison). Steps 2, 7 and 17 all need the same answer and used to hold their own copy; this is
  the one place it lives.

  **Withheld is no longer the same question as un-Enderal.** All 15 of Apocalypse's Dremora, Xivilai,
  Daedra, Atronach and Dwemer summons are now RENAMED into Enderal's own vocabulary -- Entropic,
  Sinistran, Shade, Elemental, Starling; see `01-gen-renames.ps1`. Naming is no longer a reason to
  withhold any of them.

  What is left is a TESTING question. These summons had never been distributed, so no player had
  ever cast one, and when three of them were finally examined **two were broken**: Conjure Herne
  spawned holding a bow with no ammunition Enderal has, and the Craftlord arrived naked because its
  outfit was vanilla Dwarven armour. Both are fixed and asserted (`verify-summon-ammo.ps1`,
  `verify-summon-outfits.ps1`, which now cover every summonable NPC, not just those three). But a
  clean audit is not a cast spell -- CLAUDE.md guardrail 8 -- and the other twelve have still never
  been summoned in Enderal.

  So the three that have been fixed and are ready to test ship; the twelve that have not are held
  back. **Move a spell out of this list as it is verified in game**, and update the counts in
  `07-place-vendor-tomes.ps1`, `17-loot-sublists.ps1` and `verify-vendor-reachability.ps1` to match --
  each of those asserts an exact total, so a half-done edit fails loudly rather than shipping.

  Note the EditorIDs below keep Enai's original Dremora/Xivilai names. Only display strings were
  renamed; EditorIDs are record identity and are deliberately untouched.
#>

# Distributed, because they have been fixed on this branch and are on the test checklist:
#   WB_C075_ConjureHerne            Torius Flameling  (rank 075)
#   WB_C100_ConjureDremoraAssassin  Emberlord and Fireflash (rank 100)
#   WB_C100_ConjureCraftlord        Emberlord and Fireflash (rank 100)
$removed = @(
  'WB_C025_ConjureDremoraChurl',      'WB_C050_ConjureDremoraPitFighter',
  'WB_C075_ConjureDremoraChampion',   'WB_C075_ConjureDremoraHonorGuard',
  'WB_C075_ConjureDremoraMentor',     'WB_C050_ConjureXivilaiSorcerer',
  'WB_C075_ConjureXivilaiLord',       'WB_C100_ConjureWeepingDaedra',
  'WB_C100_ConjureLordOfBindings',    'WB_C075_SixDemonBag',
  'WB_C100_ConjureKyrkrim',           'WB_C025_AtronachMark'
)

# 12 withheld tomes. Only 11 withheld scrolls: WB_C075_SixDemonBag has no scroll record at all.
$CUT_TOMES   = 12
$CUT_SCROLLS = 11
$ALL_TOMES   = 175
$ALL_SCROLLS = 144
$SHIP_TOMES  = $ALL_TOMES   - $CUT_TOMES     # 163
$SHIP_SCROLLS= $ALL_SCROLLS - $CUT_SCROLLS   # 133

if ($removed.Count -ne $CUT_TOMES) {
  throw "00-cut-summons.ps1: `$removed holds $($removed.Count) entries but `$CUT_TOMES says $CUT_TOMES."
}
