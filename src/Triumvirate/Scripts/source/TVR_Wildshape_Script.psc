;/ ------------------------------------------------------------------------------------------------
  TVR_Wildshape_Script - Enai Siaion's, rebuilt for Enderal (WD-37).

  Enai's script, decompiled from Triumvirate - Mage Archetypes.bsa with Champollion. His logic is
  preserved - the same properties, the same spell/weapon handling, including the
  TVR_SpellImmuneFromUnequip test, which reads backwards from its name but is kept as found rather
  than "corrected" on a guess. What changed is the ORDER of the engine calls around the race change,
  and the addition of two the engine wants and Enai never makes.

  Two magic effects bind this script, and they are the mod's ONLY two player transformations:

      TVR_Druid_Verdant_Effect_ForceOfNature            191250   ("Force of Nature", Treewarden)
      TVR_Druid_Verdant_Effect_Wildshape_MorphEffect    29DA04   ("Wildshape", Druid Deer)

  THE BUG

  Force of Nature renders nothing: the player transforms, attacks and casts, but has no body.
  Wildshape, on the same script, is fine. Ruled out with evidence, in this order: a dead reference,
  a missing asset, a skeleton/rig mismatch, a lost RNAM, worn armour suppressing the skin, and a
  missing 3D refresh. See WD-37 for how each died.

  The anchor fact is that RELOADING A SAVE WHILE TRANSFORMED SHOWS THE TREEWARDEN CORRECTLY. Every
  record is right; only the live transition is wrong.

  WHY THE CALL ORDER IS NOW BETHESDA'S

  PlayerWerewolfChangeScript.psc is the shipped, proven recipe for "the player becomes a beast race
  and renders". Read end to end it does this, and Enai's script does almost none of it:

    | Step                                    | Bethesda        | Enai              |
    |-----------------------------------------|-----------------|-------------------|
    | Game.SetBeastForm(True)                 | BEFORE SetRace  | after everything  |
    | DisablePlayerControls aiDisablePOVType  | 1               | 0                 |
    | Game.ForceThirdPerson()                 | before SetRace  | after the unequips|
    | Game.ForceFirstPerson()                 | never called    | before SetRace    |
    | Game.ShowFirstPersonGeometry(false)     | yes             | never             |
    | Game.SetInCharGen(true, ...)            | around SetRace  | never             |

  SureAI's LycantropheTransformSC agrees with Bethesda on the one that is easiest to dismiss:
  it also wraps its race change in Game.SetInCharGen. Two independent proven implementations calling
  it is the reason to make it, rather than reasoning about what it "should" do - chargen mode is the
  state the engine itself uses when a race change has to rebuild the player, which is exactly the
  step that is missing here.

  This is a THIRD attempt at this bug. The first two - an armour strip, then a QueueNiNodeUpdate
  redraw - were each defensible and each failed, so this one ships INSTRUMENTED: the Debug.Trace
  lines below print the race before and after every transition. If it still fails, the log says
  where, instead of costing another round of hypotheses. Turn trace output on with bEnableLogging=1
  AND bEnableTrace=1 in the PROFILE's Enderal.ini; the log lands in Skyrim's folder, not Enderal's.

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

; ENDERAL FIX (WD-37).
Float property TVR_RedrawDelay = 0.5 auto
{Seconds to let the new race's skin stream in before forcing the player's 3D to rebuild. 0 disables
 the rebuild entirely.}

Bool property TVR_Trace = true auto
{Write WD-37 diagnostic lines to the Papyrus log. Cheap - Debug.Trace is a no-op unless the player
 has bEnableTrace=1 - and this bug has already cost two blind fixes.}

;-- Variables ---------------------------------------
Shout OriginalShout
spell EquippedSpell1
spell EquippedSpell0
race OriginalRace
spell OriginalSpell
Bool IsWeaponDrawn

;-- Functions ---------------------------------------

; Skipped compiler generated GotoState

function TVRTrace(String asMessage)

	if TVR_Trace
		debug.Trace("TRIUMVIRATE WD-37: " + asMessage, 0)
	endIf
endFunction

;/ ------------------------------------------------------------------------------------------------
  ENDERAL FIX (WD-37) - force the player's 3D to rebuild after the race change.

  QueueNiNodeUpdate is SKSE's "re-derive this actor's 3D" call, the closest Papyrus equivalent of
  what a save reload does. Retained from the second attempt: on its own it did NOT fix the
  invisibility, but it is harmless and the reload evidence still says a rebuild is the missing step.
  It now runs after the corrected call order rather than instead of it.

  Deliberately NOT done: raising TVR_RedrawDelay until it "always works". A fixed delay long enough
  for any disk is a delay every player feels on every cast, and inflating a constant to chase a bug
  that may not be a timing bug is how a workaround becomes permanent.
------------------------------------------------------------------------------------------------ /;
function ForceRedraw(Actor akTarget)

	if TVR_RedrawDelay <= 0.0
		return
	endIf
	Utility.Wait(TVR_RedrawDelay)
	akTarget.QueueNiNodeUpdate()
	TVRTrace("redraw done, race is now " + akTarget.GetRace())
endFunction

function OnEffectFinish(Actor akTarget, Actor akCaster)

	TVRTrace("OnEffectFinish: race on entry " + akTarget.GetRace())
	TVR_Imod.Apply(1.00000)

	; Bethesda's revert order: chargen mode around the race change, then restore controls, then the
	; first-person geometry, and only then drop beast form.
	game.SetInCharGen(true, true, false)
	if akTarget.GetRace() == TVR_Race
		akTarget.SetRace(OriginalRace)
	else
		debug.Trace("TRIUMVIRATE ERROR: Race was changed during Morph Effect!", 2)
	endIf
	game.SetInCharGen(false, false, false)
	game.EnablePlayerControls(true, true, true, true, true, true, true, true, 1)
	game.ShowFirstPersonGeometry(true)
	game.SetBeastForm(false)

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
	ForceRedraw(akTarget)
	TVRTrace("OnEffectFinish: done, race " + akTarget.GetRace())
endFunction

function OnEffectStart(Actor akTarget, Actor akCaster)

	TVRTrace("OnEffectStart: race on entry " + akTarget.GetRace() + ", target race " + TVR_Race)
	TVR_Imod.Apply(1.00000)
	IsWeaponDrawn = akTarget.IsWeaponDrawn()
	if akTarget.GetEquippedSpell(2)
		OriginalSpell = akTarget.GetEquippedSpell(2)
	elseIf akTarget.GetEquippedShout()
		OriginalShout = akTarget.GetEquippedShout()
	endIf
	OriginalRace = akTarget.GetRace()
	akTarget.DrawWeapon()

	; --- Bethesda's order, from PlayerWerewolfChangeScript.PrepShift/InitialShift ----------------
	; Beast form and the camera are established BEFORE the race changes, not after it. Enai's
	; ForceFirstPerson() is dropped entirely - vanilla never switches to first person here, and
	; switching in then straight back out is what the previous attempt was fighting.
	game.SetBeastForm(true)
	game.DisablePlayerControls(false, TVR_DisableFight, true, false, false, true, true, true, 1)
	game.ForceThirdPerson()
	game.ShowFirstPersonGeometry(false)

	game.SetInCharGen(true, true, false)
	akTarget.SetRace(TVR_Race)
	game.SetInCharGen(false, false, false)
	TVRTrace("after SetRace: race is " + akTarget.GetRace())

	if TVR_UnequipItems
		EquippedSpell1 = akTarget.GetEquippedSpell(1)
		EquippedSpell0 = akTarget.GetEquippedSpell(0)
		if !TVR_SpellImmuneFromUnequip || EquippedSpell1 == TVR_SpellImmuneFromUnequip
			akTarget.UnequipSpell(akTarget.GetEquippedSpell(1), 1)
		endIf
		if !TVR_SpellImmuneFromUnequip || EquippedSpell0 == TVR_SpellImmuneFromUnequip
			akTarget.UnequipSpell(akTarget.GetEquippedSpell(0), 0)
		endIf
		; Guarded, unlike upstream: an unarmed caster made these throw "Cannot unequip a None item"
		; twice on every cast. Enai's behaviour is unchanged, only the noise is gone.
		if akTarget.GetEquippedWeapon(false)
			akTarget.UnequipItem(akTarget.GetEquippedWeapon(false) as form, true, false)
		endIf
		if akTarget.GetEquippedWeapon(true)
			akTarget.UnequipItem(akTarget.GetEquippedWeapon(true) as form, true, false)
		endIf
	endIf
	if TVR_Primal_Explosion_Wildshape
		akTarget.PlaceAtMe(TVR_Primal_Explosion_Wildshape as form, 1, false, false)
	endIf
	if TVR_Primal_VFX_Wildshape
		TVR_Primal_VFX_Wildshape.Play(akTarget as objectreference, 6.00000, none)
	endIf
	if TVR_Primal_Spell_DispelPower
		akTarget.EquipSpell(TVR_Primal_Spell_DispelPower, 2)
	endIf
	if TVR_HelpMessage
		TVR_HelpMessage.ShowAsHelpMessage(TVR_HelpMessageType, (TVR_HelpMessageDuration_Global.GetValue() as Int) as Float, 0 as Float, TVR_HelpMessageRate_Global.GetValue() as Int)
	endIf
	ForceRedraw(akTarget)
	TVRTrace("OnEffectStart: done, race " + akTarget.GetRace())
endFunction

; Skipped compiler generated GetState
