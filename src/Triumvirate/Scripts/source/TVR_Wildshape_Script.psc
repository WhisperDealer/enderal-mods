;/ ------------------------------------------------------------------------------------------------
  TVR_Wildshape_Script - Enai Siaion's, rebuilt for Enderal (WD-37).

  This is Enai's script, decompiled from Triumvirate - Mage Archetypes.bsa with Champollion and
  reproduced verbatim except for the block marked "ENDERAL FIX" and its two call sites. Nothing else
  about the transformation's behaviour is changed: the same properties, the same order of
  operations, the same spell/weapon handling, including the TVR_SpellImmuneFromUnequip test, which
  reads backwards from its name but is preserved as found rather than "corrected" on a guess.

  WHY IT IS PATCHED

  Two magic effects bind this script, and they are the mod's ONLY two player transformations:

      TVR_Druid_Verdant_Effect_ForceOfNature            191250   ("Force of Nature", Treewarden)
      TVR_Druid_Verdant_Effect_Wildshape_MorphEffect    29DA04   ("Wildshape", Druid Deer)

  Force of Nature was reported invisible in Enderal - the player transforms, attacks and casts
  normally, but nothing renders. Ruled out with evidence, in this order: a dead reference, a missing
  asset, a skeleton/rig mismatch, a lost RNAM, and worn armour suppressing the skin. See the WD-37
  ticket for how each died.

  AN ARMOUR STRIP LIVED HERE, AND IT WAS WRONG THREE WAYS

  The first fix shipped for this unequipped worn armour around the race change, on the theory that a
  race skin renders per biped slot and the player's Enderal armour keeps slots 32/33/37 across the
  SetRace, drawing nothing and suppressing the skin beneath. Both proven archetypes DO unequip gear
  immediately after SetRace - Bethesda's PlayerWerewolfChangeScript and SureAI's
  LycantropheTransformSC - so it looked well founded.

  It has been removed. A Papyrus log settled it:

    1. It did not fix the invisibility. A player reloaded a save mid-transform and saw the Treewarden
       render correctly WITH the armour already stripped, so the strip was never the variable.
    2. It threw on that very path. An ActiveMagicEffect restored from a save comes back detached
       ("[None]"), and reading its Form[] variable errors with "Cannot cast from None to Form[]"
       before any guard can help - so RestoreArmor aborted and the player's gear stayed off.
    3. It set off 45 "Cannot call GetSlotMask() on a None object" errors per cast in an unrelated
       mod's OnObjectUnequipped handler, because it fires up to 31 unequip events in a tight loop.

  The lesson worth keeping: two proven archetypes agreeing on a mechanism is good evidence that the
  mechanism is real, and none at all that it is THIS bug. Do not keep a fix that failed its test
  because the reasoning behind it was sound.

  Compile with ENDERAL'S source tree FIRST on -i (see Scripts/README.md). QueueNiNodeUpdate is an
  SKSE function - it lives in the SKSE tree, not the vanilla one - so the SKSE tree must precede
  vanilla on the path or this will not resolve.
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

; ENDERAL FIX (WD-37). See ForceRedraw below.
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

;-- Functions ---------------------------------------

; Skipped compiler generated GotoState

;/ ------------------------------------------------------------------------------------------------
  ENDERAL FIX (WD-37) - force the player's 3D to rebuild after the race change.

  Motivated by one observation from a player: RELOADING A SAVE WHILE TRANSFORMED SHOWS THE TREEWARDEN
  CORRECTLY. That rules out every static explanation at once - the race, the skin ARMO, its armature,
  the mesh and the BSA are all correct, because a fresh actor build renders them perfectly. What a
  reload does and a live SetRace does not is rebuild the player's 3D.

  QueueNiNodeUpdate is SKSE's "re-derive this actor's 3D" call and is the closest Papyrus equivalent
  of that rebuild. The camera toggle is kept as a second lever because it is what upstream already
  relies on (ForceFirstPerson early, ForceThirdPerson late) and it costs nothing. Both are cheap and
  idempotent.

  HONEST STATUS: this has NOT been shown to fix the invisibility. It is retained because the reload
  evidence still says a rebuild is the missing step, and because it is harmless - but the live
  suspect has moved outside this script. A Papyrus log from the reporting modlist shows RaceMenu
  broken at the bind level ("Unable to bind script RaceMenuPluginXPMSE ... base types do not match",
  12 times) and all six of its plugin aliases throwing "Cannot call OnChangeRace() on a None object"
  from RaceMenuLoad.OnRaceSwitchComplete on every single player race change. RaceMenu/NiOverride owns
  the player's body rendering for HUMANOID actors, which is exactly what separates the two
  transformations: Force of Nature's race is humanoid (DefaultMale.hkx, head parts, tint masks) while
  Wildshape's is a Critter creature race that NiOverride does not touch - and Wildshape renders.

  Before tuning anything here, settle that with `player.setrace` from the console, which takes this
  script out of the equation entirely.

  Deliberately NOT done: raising TVR_RedrawDelay until it "always works". A fixed delay long enough
  for any disk is a delay every player feels on every cast, and inflating a constant to chase a bug
  that may not be a timing bug at all is how a workaround becomes permanent.
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
