;/ ------------------------------------------------------------------------------------------------
  TVR_Wildshape_Script - Enai Siaion's, rebuilt for Enderal (WD-37).

  This is Enai's script, decompiled from Triumvirate - Mage Archetypes.bsa with Champollion and
  reproduced verbatim except for the block marked "ENDERAL FIX" and the two calls into it. Nothing
  else about the transformation's behaviour is changed: the same properties, the same order of
  operations, the same spell/weapon handling, including the TVR_SpellImmuneFromUnequip test, which
  reads backwards from its name but is preserved as found rather than "corrected" on a guess.

  WHY IT IS PATCHED

  Two magic effects bind this script, and they are the mod's ONLY two player transformations:

      TVR_Druid_Verdant_Effect_ForceOfNature            191250   ("Force of Nature", Treewarden)
      TVR_Druid_Verdant_Effect_Wildshape_MorphEffect    29DA04   ("Wildshape", Druid Deer)

  Force of Nature was reported invisible in Enderal - the player transforms, attacks and casts
  normally, but nothing renders. The cause is NOT a dead reference, a missing asset, a skeleton
  mismatch or a lost RNAM (all four were checked and ruled out; see the WD-37 ticket). It is that
  nothing rebuilds the player's 3D at cast time. See ForceRedraw below.

  A WRONG ANSWER WORTH KEEPING

  The first fix shipped for this was the armour strip, on the theory that a race skin renders per
  biped slot and the player's Enderal armour keeps slots 32/33/37 across the SetRace, drawing
  nothing and suppressing the skin beneath. Upstream unequips weapons and spells only
  (TVR_UnequipItems), never armour, and both proven archetypes for this mechanic DO unequip it,
  immediately after SetRace:

      Bethesda   PlayerWerewolfChangeScript.psc   SetRace(WerewolfBeastRace) then UnequipAll()
      SureAI     LycantropheTransformSC.psc       SetRace(WerewolfBeastRace) then UnequipAll(),
                                                  restoring through playerTransformStorage

  So the engine does not hide worn gear in beast form by itself. It is a tidy mechanism backed by two
  archetypes, and it DID NOT FIX the invisibility. What killed it was a player reloading a save
  mid-transform and seeing the Treewarden render correctly - with the armour already stripped, so the
  strip cannot be the variable.

  The strip is KEPT because it matches the host's archetype and Wildshape was verified working with
  it in place; removing it alongside the real fix would change two variables at once. It is
  belt-and-braces, not the diagnosis.

  We do NOT call UnequipAll(). It would also strip weapons, which upstream deliberately keeps for
  Wildshape (TVR_UnequipItems is False there), and nothing would put them back. Instead we record
  and remove exactly the worn armour, and restore exactly that, leaving Enai's weapon and spell
  handling alone.

  Compile with ENDERAL'S source tree FIRST on -i (see Scripts/README.md). GetWornForm is an SKSE
  function - it lives in the SKSE tree, not the vanilla one - so the SKSE tree must precede vanilla
  on the path or this will not resolve.
------------------------------------------------------------------------------------------------ /;
scriptName TVR_Wildshape_Script extends activemagiceffect

;-- Properties --------------------------------------
visualeffect property TVR_Primal_VFX_Wildshape auto
message property TVR_HelpMessage auto
explosion property TVR_Primal_Explosion_Wildshape auto
globalvariable property TVR_HelpMessageRate_Global auto
Bool property TVR_DisableFight = false auto
spell property TVR_MorphSpell auto
Bool property TVR_UnequipItems = true auto
spell property TVR_SpellImmuneFromUnequip auto
globalvariable property TVR_HelpMessageDuration_Global auto
imagespacemodifier property TVR_Imod auto
spell property TVR_Primal_Spell_DispelPower auto
String property TVR_AnimEvent auto
{AggroWarningStart}
race property TVR_Race auto
String property TVR_HelpMessageType auto

; ENDERAL FIX (WD-37). Defaults True so both magic effects inherit it with no record edit - an
; absent VMAD property takes the script's default. Set it False on a record to opt that
; transformation out.
Bool property TVR_StripArmor = true auto
{Unequip worn armour for the duration of the transformation and restore it afterwards. This mirrors
 Bethesda's and SureAI's own transformation scripts; it is not what caused the Force of Nature
 invisibility - see TVR_RedrawDelay - but it is the host's archetype and Wildshape was verified
 working with it in place.}

; ENDERAL FIX (WD-37). See ForceRedraw below for why this exists and how it was diagnosed.
Float property TVR_RedrawDelay = 0.5 auto
{Seconds to let the new race's skin stream in before forcing the player's 3D to rebuild. 0 disables
 the rebuild entirely.}

;-- Variables ---------------------------------------
Shout OriginalShout
spell EquippedSpell1
spell EquippedSpell0
race OriginalRace
spell OriginalSpell
Bool IsWeaponDrawn

; ENDERAL FIX (WD-37). Worn armour, indexed by biped slot bit, recorded at transform time.
Form[] StoredArmor

;-- Functions ---------------------------------------

; Skipped compiler generated GotoState

;/ ------------------------------------------------------------------------------------------------
  ENDERAL FIX (WD-37) - strip and restore worn armour around the race change.

  31 iterations, not 32: biped slots 30..60 map to bits 0..30, and bit 31 would need 1 << 31, which
  overflows a signed Papyrus Int. Slot 61 (FX01) is not an armour slot, so nothing is lost.

  A single cuirass answers GetWornForm for several slots, so StoredArmor holds duplicates. That is
  harmless in both directions - UnequipItem and EquipItem on an item already in the target state are
  no-ops - and it keeps the restore exactly symmetric with the strip.
------------------------------------------------------------------------------------------------ /;
function StripArmor(Actor akTarget)

	StoredArmor = new Form[31]
	Int i = 0
	Int slot = 1
	while i < 31
		Form worn = akTarget.GetWornForm(slot)
		if worn
			StoredArmor[i] = worn
			akTarget.UnequipItem(worn, false, true)
		endIf
		i += 1
		slot = slot * 2
	endWhile
endFunction

function RestoreArmor(Actor akTarget)

	if StoredArmor
		Int i = 0
		while i < StoredArmor.Length
			Form worn = StoredArmor[i]
			if worn
				akTarget.EquipItem(worn, false, true)
			endIf
			i += 1
		endWhile
		StoredArmor = none
	endIf
endFunction

;/ ------------------------------------------------------------------------------------------------
  ENDERAL FIX (WD-37) - force the player's 3D to rebuild after the race change.

  This is the actual cause of the "Force of Nature is invisible but attacks work and can cast
  spells" report, and it was diagnosed by one observation from a player: RELOADING A SAVE WHILE
  TRANSFORMED SHOWS THE TREEWARDEN CORRECTLY. That rules out every static explanation at once - the
  race, the skin ARMO, its armature, the mesh and the BSA are all correct, because a fresh actor
  build renders them perfectly. The only thing wrong is that nothing rebuilds the player's 3D at
  cast time, so the old body is torn down and the new one is never drawn.

  Upstream does try: it calls ForceFirstPerson() early and ForceThirdPerson() late, which is the
  usual idiom for making the engine re-derive the player's 3D. Wildshape survives on that, and Force
  of Nature does not. The difference is what each has to load. Wildshape's race reuses an Enderal
  skin that is already resident (SkinReinDeer, ArmorRace DeerRace), while Force of Nature's is a new
  ARMO over Triumvirate\Verdant_Actor_ForceOfNature.nif - a 7.2 MB mesh that has to come out of the
  BSA. The camera toggle fires before it has streamed in, so the rebuild finds nothing to draw and
  never runs again.

  So: wait, then rebuild. QueueNiNodeUpdate is SKSE's "re-derive this actor's 3D" call and is the
  direct equivalent of what a save reload does; the camera toggle is kept as a second lever because
  it is what upstream already relies on and it costs nothing. Both are cheap and idempotent.

  Deliberately NOT done: raising the wait until it "always works". A fixed delay long enough for any
  disk is a delay every player feels on every cast. If 0.5 s proves marginal the honest fix is to
  poll GetWornForm/Is3DLoaded rather than to inflate a constant - but measure before assuming, since
  a reload demonstrably needs no such margin.
------------------------------------------------------------------------------------------------ /;
function ForceRedraw(Actor akTarget, Bool abToggleCamera)

	if TVR_RedrawDelay <= 0.0
		return
	endIf
	Utility.Wait(TVR_RedrawDelay)
	akTarget.QueueNiNodeUpdate()
	if abToggleCamera
		game.ForceFirstPerson()
		game.ForceThirdPerson()
	endIf
endFunction

function OnEffectFinish(Actor akTarget, Actor akCaster)

	TVR_Imod.Apply(1.00000)
	game.EnablePlayerControls(true, true, true, true, true, true, true, true, 0)
	if akTarget.GetRace() == TVR_Race
		akTarget.SetRace(OriginalRace)
	else
		debug.Trace("TRIUMVIRATE ERROR: Race was changed during Morph Effect!", 2)
	endIf
	; ENDERAL FIX (WD-37): after the original race is back, so the armour's armatures match again.
	if TVR_StripArmor
		RestoreArmor(akTarget)
	endIf
	if TVR_Primal_Explosion_Wildshape
		akTarget.PlaceAtMe(TVR_Primal_Explosion_Wildshape as form, 1, false, false)
	endIf
	if OriginalSpell
		akTarget.EquipSpell(OriginalSpell, 2)
	elseIf OriginalShout
		akTarget.EquipShout(OriginalShout)
	endIf
	if TVR_UnequipItems
		if EquippedSpell0
			akTarget.EquipSpell(EquippedSpell0, 0)
		endIf
		if EquippedSpell1
			akTarget.EquipSpell(EquippedSpell1, 1)
		endIf
	endIf
	if IsWeaponDrawn
		akTarget.DrawWeapon()
	endIf
	if TVR_Primal_VFX_Wildshape
		TVR_Primal_VFX_Wildshape.Play(akTarget as objectreference, 6.00000, none)
	endIf
	game.SetBeastForm(false)
	; ENDERAL FIX (WD-37): same staleness applies changing back. No camera toggle here - upstream
	; does not force a view on the way out, and yanking it would be a visible regression for anyone
	; who plays in first person.
	ForceRedraw(akTarget, false)
endFunction

function OnEffectStart(Actor akTarget, Actor akCaster)

	TVR_Imod.Apply(1.00000)
	IsWeaponDrawn = akTarget.IsWeaponDrawn()
	if akTarget.GetEquippedSpell(2)
		OriginalSpell = akTarget.GetEquippedSpell(2)
	elseIf akTarget.GetEquippedShout()
		OriginalShout = akTarget.GetEquippedShout()
	endIf
	OriginalRace = akTarget.GetRace()
	akTarget.DrawWeapon()
	akTarget.SetRace(TVR_Race)
	; ENDERAL FIX (WD-37): immediately after SetRace, where both proven archetypes put it.
	if TVR_StripArmor
		StripArmor(akTarget)
	endIf
	game.ForceFirstPerson()
	game.DisablePlayerControls(false, TVR_DisableFight, true, false, false, true, true, true, 0)
	if TVR_UnequipItems
		EquippedSpell1 = akTarget.GetEquippedSpell(1)
		EquippedSpell0 = akTarget.GetEquippedSpell(0)
		if !TVR_SpellImmuneFromUnequip || EquippedSpell1 == TVR_SpellImmuneFromUnequip
			akTarget.UnequipSpell(akTarget.GetEquippedSpell(1), 1)
		endIf
		if !TVR_SpellImmuneFromUnequip || EquippedSpell0 == TVR_SpellImmuneFromUnequip
			akTarget.UnequipSpell(akTarget.GetEquippedSpell(0), 0)
		endIf
		akTarget.UnequipItem(akTarget.GetEquippedWeapon(false) as form, true, false)
		akTarget.UnequipItem(akTarget.GetEquippedWeapon(true) as form, true, false)
	endIf
	if TVR_Primal_Explosion_Wildshape
		akTarget.PlaceAtMe(TVR_Primal_Explosion_Wildshape as form, 1, false, false)
	endIf
	if TVR_Primal_VFX_Wildshape
		TVR_Primal_VFX_Wildshape.Play(akTarget as objectreference, 6.00000, none)
	endIf
	game.ForceThirdPerson()
	game.SetBeastForm(true)
	if TVR_Primal_Spell_DispelPower
		akTarget.EquipSpell(TVR_Primal_Spell_DispelPower, 2)
	endIf
	if TVR_HelpMessage
		TVR_HelpMessage.ShowAsHelpMessage(TVR_HelpMessageType, (TVR_HelpMessageDuration_Global.GetValue() as Int) as Float, 0 as Float, TVR_HelpMessageRate_Global.GetValue() as Int)
	endIf
	; ENDERAL FIX (WD-37): last, so every equipment change above has already settled and nothing
	; invalidates the rebuild after it runs.
	ForceRedraw(akTarget, true)
endFunction

; Skipped compiler generated GetState
