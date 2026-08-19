Scriptname _00E_Phasmalist_NewApparitionAlias extends ReferenceAlias
; script that controls the apparition stats calculation and initialization. Additionally, it is responsible for the control of the apparition communication while it is summoned

; we prefer to place new actors instead of using only one actor
; due to the problem of keeping track of all apparitions, 
; which might create memory leaks because of persistence;
; Additionally, temporary or accidental changes do not cumulate
; and lead to problems

; balancing data
Float Property fApparitionManaRate = 1.0 AutoReadOnly

Float Property fPlayerStatsMult = 0.20 AutoReadOnly
Float Property fPlayerConjSkillMult = 0.10 AutoReadOnly
Float Property fPlayerEnchSkillMult = 0.15 AutoReadOnly

Float Property fArcaneFeverLevel01 = 7.00 AutoReadOnly
Float Property fArcaneFeverLevel02 = 6.00 AutoReadOnly
Float Property fArcaneFeverLevel03 = 5.00 AutoReadOnly

Float Property fArcaneFeverModWarrior = -1.0 AutoReadOnly
Float Property fArcaneFeverModRanger = 0.0 AutoReadOnly
Float Property fArcaneFeverModHybrid = 0.0 AutoReadOnly
Float Property fArcaneFeverModMage = 1.0 AutoReadOnly

Int Property iGhostlyMageBoostDestructionPowerMod1 = 7 AutoReadOnly
Int Property iGhostlyMageBoostDestructionPowerMod2 = 15 AutoReadOnly
Int Property iGhostlyMageBoostDestructionPowerMod3 = 25 AutoReadOnly

Int Property iGhostlyMageBoostMagicka1 = 15 AutoReadOnly
Int Property iGhostlyMageBoostMagicka2 = 40 AutoReadOnly
Int Property iGhostlyMageBoostMagicka3 = 75 AutoReadOnly

Int Property iGhostlyRangerBoostArchery1 = 7 AutoReadOnly
Int Property iGhostlyRangerBoostArchery2 = 17 AutoReadOnly
Int Property iGhostlyRangerBoostArchery3 = 30 AutoReadOnly

Int Property iGhostlyRangerBoostCritChance1 = 7 AutoReadOnly
Int Property iGhostlyRangerBoostCritChance2 = 15 AutoReadOnly
Int Property iGhostlyRangerBoostCritChance3 = 25 AutoReadOnly

Int Property iGhostlyWarriorBoostMelee1 = 7 AutoReadOnly
Int Property iGhostlyWarriorBoostMelee2 = 17 AutoReadOnly
Int Property iGhostlyWarriorBoostMelee3 = 30 AutoReadOnly

Int Property iGhostlyWarriorBoostArmorSkill1 = 7 AutoReadOnly
Int Property iGhostlyWarriorBoostArmorSkill2 = 17 AutoReadOnly
Int Property iGhostlyWarriorBoostArmorSkill3 = 30 AutoReadOnly

Float Property DEFAULT_HEAL_RATE = 50.0 AutoReadOnly

Explosion Property _00E_Phasmalist_EnterWorldExp Auto

Perk Property _00E_Class_Phasmalist_P03_Talent_SummonApparation_01 Auto
Perk Property _00E_Class_Phasmalist_P03_Talent_SummonApparation_02 Auto
Perk Property _00E_Class_Phasmalist_P03_Talent_SummonApparation_03 Auto

Static Property XMarker Auto

Perk Property _00E_Class_Phasmalist_P08_A_EssenceSplit Auto

; Boost perks
Perk Property _00E_Class_Phasmalist_P05_A_Shamanism_01 Auto
Perk Property _00E_Class_Phasmalist_P05_A_Shamanism_02 Auto
Perk Property _00E_Class_Phasmalist_P05_A_Shamanism_03 Auto

Perk Property _00E_Class_Phasmalist_P05_B_Mischief_01 Auto
Perk Property _00E_Class_Phasmalist_P05_B_Mischief_02 Auto
Perk Property _00E_Class_Phasmalist_P05_B_Mischief_03 Auto

Perk Property _00E_Class_Phasmalist_P05_C_Violence_01 Auto
Perk Property _00E_Class_Phasmalist_P05_C_Violence_02 Auto
Perk Property _00E_Class_Phasmalist_P05_C_Violence_03 Auto

Message Property _00E_Phasmalist_CurrentlyEquipped Auto

ImageSpaceModifier Property _00E_ArkanistenfieberIMOD Auto
ImageSpaceModifier Property _00E_Phasmalist_ApparitionEnterWorldIMOD Auto

Sound Property _00E_FS_IncreaseArcaneFeverM Auto

Message Property _00E_Player_sArcaneFeverIncreased Auto
GlobalVariable Property _00E_Phasmalist_IsApparitionSummoned Auto

; The apparition should not be able to learn summon creature and mystical/mythical spells
FormList Property _00E_PhasmalistApparition_SpellBooks Auto
FormList Property _00E_PhasmalistApparition_Spells Auto

Int iCurrentBoostMagicka ; this is set in adjustBoost() to have the attribute set correctly in the stats calculation

Actor Property PlayerREF Auto

FormList Property _00E_AllAmmos Auto

_00E_Phasmalist_TrinketSC SummonTrinket

; Stores the reference of the current apparition while it's properly spawned, not being unsummoned, not dying, etc.
; Needed for the failsafe in OnLoadGame() and some other shenanigans
Actor Property AliasFailsafeRef = None Auto Hidden

Bool bTeleportHealRate = False

int function _GetScriptVersion() Global
    return 1
endFunction

;=====================================================================================
;              						SUMMON & SETUP
;=====================================================================================

Function Summon(_00E_Phasmalist_TrinketSC trinket, ObjectReference moveToRef, Bool bPhasmalismTankMode, Bool bSilent)
	Actor akSelf = Self.GetActorReference()

	SummonTrinket = trinket
	bActivationBusy = bPhasmalismTankMode ; Reset just in case
	bTeleportHealRate = False ; Reset just in case
	_00E_Phasmalist_IsApparitionSummoned.SetValue(1)

	Setup() ; init stats before any armor buffs are applied

	If bSilent == False
		_00E_Phasmalist_ApparitionEnterWorldIMOD.Apply()
	EndIf

	(akSelf.GetActorBase() as _00E_Phasmalist_ApparationSC).inventoryContainer.removeAllItems(akSelf, false, true)

	If bPhasmalismTankMode == False
		Int i = akSelf.GetNumItems()
		While i > 0
			i -= 1
			Form item = akSelf.GetNthForm(i)
			If item as Book
				_RegisterSpellBook(akSelf, item)
			EndIf
		EndWhile
	EndIf

	akSelf.BlockActivation()

	If bPhasmalismTankMode
		akSelf.SetActorValue("Variable01", 1.0)
		akSelf.EnableAI(False)
	Else
		If moveToRef == PlayerREF
			_MoveToPlayer(akSelf, False)
		EndIf

		GoToState("Working")
	EndIf
	
	akSelf.Enable()
	AliasFailsafeRef = akSelf

	If bPhasmalismTankMode
		; MoveTo needs to be done after Enable or the apparition ends on the neareast navmesh instead of the tank
		akSelf.MoveTo(moveToRef)
	EndIf

	If bSilent == False
		PlaySummonExplosion(akSelf)
	EndIf

	SendModEvent("Phasmalist_ApparationSummon")
EndFunction

Function PlaySummonExplosion(ObjectReference markerRef)
	ObjectReference expMarker = _PlaceExplosionEx(_00E_Phasmalist_EnterWorldExp, markerRef, 15.0)
	_DeleteMarker(expMarker)
EndFunction

Int Property BOOST_CLASS_MAGE    = 0 AutoReadOnly
Int Property BOOST_CLASS_RANGER  = 1 AutoReadOnly
Int Property BOOST_CLASS_WARRIOR = 2 AutoReadOnly

Function Setup()
	Actor akSelf = Self.GetActorReference()

	SetupBehaviour(akSelf)
	SetupNotPersistentStats(akSelf)
		
	Float fAttributeMult = (fPlayerConjSkillMult * PlayerREF.GetActorValue("Conjuration") + fPlayerEnchSkillMult * PlayerREF.GetActorValue("Enchanting")) / 100.0 + 1.0

	ApplyClassBoost(akSelf, BOOST_CLASS_MAGE, _00E_Class_Phasmalist_P05_A_Shamanism_01, _00E_Class_Phasmalist_P05_A_Shamanism_02, _00E_Class_Phasmalist_P05_A_Shamanism_03)
	ApplyClassBoost(akSelf, BOOST_CLASS_RANGER, _00E_Class_Phasmalist_P05_B_Mischief_01, _00E_Class_Phasmalist_P05_B_Mischief_02, _00E_Class_Phasmalist_P05_B_Mischief_03)
	ApplyClassBoost(akSelf, BOOST_CLASS_WARRIOR, _00E_Class_Phasmalist_P05_C_Violence_01, _00E_Class_Phasmalist_P05_C_Violence_02, _00E_Class_Phasmalist_P05_C_Violence_03)

	If PlayerREF.HasPerk(_00E_Class_Phasmalist_P08_A_EssenceSplit)
		Float fMaxAttributeValue = PlayerREF.GetBaseActorValue("Health")
		Float fPlayerMagicka = PlayerREF.GetBaseActorValue("Magicka")
		If fPlayerMagicka > fMaxAttributeValue
			fMaxAttributeValue = fPlayerMagicka
		EndIf
		Float fPlayerStamina = PlayerREF.GetBaseActorValue("Stamina")
		If fPlayerStamina > fMaxAttributeValue
			fMaxAttributeValue = fPlayerStamina
		EndIf
		akSelf.ForceActorValue("Health", ((akSelf.GetBaseActorValue("Health") + fMaxAttributeValue * fPlayerStatsMult) * fAttributeMult) as int)
		akSelf.ForceActorValue("Magicka", (((akSelf.GetBaseActorValue("Magicka") + fMaxAttributeValue * fPlayerStatsMult) * fAttributeMult) as int) + iCurrentBoostMagicka)
		akSelf.ForceActorValue("Stamina", ((akSelf.GetBaseActorValue("Stamina") + fMaxAttributeValue * fPlayerStatsMult) * fAttributeMult) as int)

	Else
		akSelf.ForceActorValue("Health", ((akSelf.GetBaseActorValue("Health") + PlayerREF.GetBaseActorValue("Health") * fPlayerStatsMult) * fAttributeMult) as int)
		akSelf.ForceActorValue("Magicka", (((akSelf.GetBaseActorValue("Magicka") + PlayerREF.GetBaseActorValue("Magicka") * fPlayerStatsMult) * fAttributeMult) as int) + iCurrentBoostMagicka)
		akSelf.ForceActorValue("Stamina", ((akSelf.GetBaseActorValue("Stamina") + PlayerREF.GetBaseActorValue("Stamina") * fPlayerStatsMult) * fAttributeMult) as int)
	EndIf
EndFunction	

Function SetupBehaviour(Actor akSelf)
	Int iRelationship = akSelf.GetRelationshipRank(PlayerREF)
	If iRelationship < 3 && iRelationship >= 0
		akSelf.SetRelationshipRank(PlayerREF, 3)
	EndIf

	akSelf.SetPlayerTeammate()
	akSelf.SetActorValue("Confidence", 4) ; the apparition should never flee
	akSelf.SetActorValue("Aggression", 0) ; the apparition should not initiate combat (-> stealth playstyle)
	akSelf.SetActorValue("Sneak", 100)
	akSelf.SetActorValue("Invisibility", 1) ; make the apparition undetectable when sneaking (-> stealth playstyle)
	akSelf.IgnoreFriendlyHits() ; make the apparition ignore friendly fire from the PC
EndFunction

Function SetupNotPersistentStats(Actor akSelf)
	akSelf.GetActorBase().SetCombatStyle(SummonTrinket.GetUsedCombatStyle())

	If bTeleportHealRate == False
		akSelf.SetActorValue("HealRate", DEFAULT_HEAL_RATE)
	Else
		akSelf.SetActorValue("HealRate", 0.0)
	EndIf
	akSelf.SetActorValue("MagickaRate", fApparitionManaRate)

	;failsafe since setav doesn't work sometimes
	If bTeleportHealRate == False
		akSelf.ForceActorValue("HealRate", DEFAULT_HEAL_RATE)
	Else
		akSelf.ForceActorValue("HealRate", 0.0)
	EndIf
	akSelf.ForceActorValue("MagickaRate", fApparitionManaRate)
EndFunction

Function ApplyClassBoost(Actor akSelf, Int iBoostClass, Perk boostPerk1, Perk boostPerk2, Perk boostPerk3)
	If PlayerREF.HasPerk(boostPerk1)
		If PlayerREF.HasPerk(boostPerk3)
			_AddClassBoost(akSelf, iBoostClass, 3)
		ElseIf PlayerREF.HasPerk(boostPerk2)
			_AddClassBoost(akSelf, iBoostClass, 2)
		Else
			_AddClassBoost(akSelf, iBoostClass, 1)
		EndIf
	EndIf
EndFunction

Function _AddClassBoost(Actor akSelf, Int iBoostClass, Int iBoostLevel)
	If iBoostClass == BOOST_CLASS_MAGE
		Int iDestructionPowerMod = 0
		If iBoostLevel == 3
			iDestructionPowerMod = iGhostlyMageBoostDestructionPowerMod3
			iCurrentBoostMagicka = iGhostlyMageBoostMagicka3 ; since magicka is boosted later again, we have to save this boost and apply it later to prevent overwriting old boosts
		ElseIf iBoostLevel == 2
			iDestructionPowerMod = iGhostlyMageBoostDestructionPowerMod2
			iCurrentBoostMagicka = iGhostlyMageBoostMagicka2
		Else
			iDestructionPowerMod = iGhostlyMageBoostDestructionPowerMod1
			iCurrentBoostMagicka = iGhostlyMageBoostMagicka1
		EndIf
		;akSelf.ForceActorValue("DestructionPowerMod", akSelf.GetActorValue("DestructionPowerMod") + iDestructionPowerMod)
		akSelf.ModActorValue("DestructionPowerMod", iDestructionPowerMod)
	ElseIf iBoostClass == BOOST_CLASS_RANGER
		Int iBoostArchery = 0
		Int iBoostCritChance = 0
		If iBoostLevel == 3
			iBoostArchery = iGhostlyRangerBoostArchery3
			iBoostCritChance = iGhostlyRangerBoostCritChance3
		ElseIf iBoostLevel == 2
			iBoostArchery = iGhostlyRangerBoostArchery2
			iBoostCritChance = iGhostlyRangerBoostCritChance2
		Else
			iBoostArchery = iGhostlyRangerBoostArchery1
			iBoostCritChance = iGhostlyRangerBoostCritChance1
		EndIf

		;akSelf.ForceActorValue("Marksman", akSelf.GetActorValue("Marksman") + iBoostArchery)
		akSelf.ModActorValue("Marksman", iBoostArchery)
		;akSelf.ForceActorValue("CritChance", akSelf.GetActorValue("CritChance") + iBoostCritChance)
		akSelf.ModActorValue("CritChance", iBoostCritChance)
	ElseIf iBoostClass == BOOST_CLASS_WARRIOR
		Int iBoostMelee = 0
		Int iBoostArmor = 0
		If iBoostLevel == 3
			iBoostMelee = iGhostlyWarriorBoostMelee3
			iBoostArmor = iGhostlyWarriorBoostArmorSkill3
		ElseIf iBoostLevel == 2
			iBoostMelee = iGhostlyWarriorBoostMelee2
			iBoostArmor = iGhostlyWarriorBoostArmorSkill2
		Else
			iBoostMelee = iGhostlyWarriorBoostMelee1
			iBoostArmor = iGhostlyWarriorBoostArmorSkill1
		EndIf

		;akSelf.ForceActorValue("HeavyArmor", akSelf.GetActorValue("HeavyArmor") + iBoostArmor)
		akSelf.ModActorValue("HeavyArmor", iBoostArmor)
		;akSelf.ForceActorValue("LightArmor", akSelf.GetActorValue("LightArmor") + iBoostArmor)
		akSelf.ModActorValue("LightArmor", iBoostArmor)
		; MeleeDamage AV seems to be not working, it's actually always zero
		;akSelf.ForceActorValue("MeleeDamage", akSelf.GetActorValue("MeleeDamage") + iBoostMelee)
		;akSelf.ModActorValue("MeleeDamage", iBoostMelee)
		akSelf.ModActorValue("OneHanded", iBoostMelee)
		akSelf.ModActorValue("TwoHanded", iBoostMelee)
	Else
		Debug.Notification("Phasmalist Control Quest has issues: Unsupported boost class " + iBoostClass)
	EndIf
Endfunction


;=====================================================================================
;              						UNSUMMON & CLEANUP
;=====================================================================================

Function Unsummon(Bool bSilent)
	Actor akSelf = self.GetActorReference()

	HealthBarManager.Hide(akSelf)

	GoToState("")
	AliasFailsafeRef = None

	TransformFromWerewolf(akSelf, True, bSilent)

	If bSilent == False
		If akSelf.Is3DLoaded()
			akSelf.PlaceAtMe(_00E_Phasmalist_EnterWorldExp)
		EndIf
		AddArcaneFever()
	EndIf

	_00E_Phasmalist_IsApparitionSummoned.SetValue(0)
	akSelf.RemoveAllItems((akSelf.GetActorBase() as _00E_Phasmalist_ApparationSC).inventoryContainer, False, True)
	akSelf.Disable()
	Self.Clear()
	SummonTrinket = None

	Utility.wait(1.0)
	akSelf.Delete()
	
	SendModEvent("Phasmalist_ApparationUnSummon")
	
EndFunction

Function AddArcaneFever()
	Actor akSelf = Self.GetActorReference()
	Float fHealthLostPercentage = 0
	Float fMaxArcaneFeverAdd = 0
	
	If akSelf.IsDead()
		fHealthLostPercentage = 1.0
	Else
		fHealthLostPercentage = 1.0 - akSelf.GetActorValuePercentage("health")
		If fHealthLostPercentage > 1.0
			fHealthLostPercentage = 1.0
		EndIf
	EndIf

	Int iTalentLevel = _00E_TalentLibrary.GetPlayerTalentLevel(_00E_Class_Phasmalist_P03_Talent_SummonApparation_01, _00E_Class_Phasmalist_P03_Talent_SummonApparation_02, _00E_Class_Phasmalist_P03_Talent_SummonApparation_03)
	If iTalentLevel == 1
		fMaxArcaneFeverAdd = fArcaneFeverLevel01
	ElseIf iTalentLevel == 2
		fMaxArcaneFeverAdd = fArcaneFeverLevel02
	Else
		fMaxArcaneFeverAdd = fArcaneFeverLevel03
	EndIf
	
	Int iTrinketType = SummonTrinket.type
	If iTrinketType == 0
		fMaxArcaneFeverAdd += fArcaneFeverModWarrior
	ElseIf iTrinketType == 1
		fMaxArcaneFeverAdd += fArcaneFeverModRanger
	ElseIf iTrinketType == 2
		fMaxArcaneFeverAdd += fArcaneFeverModMage
	Else
		fMaxArcaneFeverAdd += fArcaneFeverModHybrid
	EndIf

	Float fArcaneFeverAdd = fMaxArcaneFeverAdd * fHealthLostPercentage
	If fArcaneFeverAdd > 0
        ArcaneFever.ModFever(-fArcaneFeverAdd, True)
	EndIf
EndFunction


;=====================================================================================
;              						OTHER ACTIONS
;=====================================================================================

Function OnLoadGame()
	; sometimes reloading a save with a summoned apparition from a game state without one can result in the apparationAlias (old alias) being cleared.
	; To fix this, the script additionally keeps track of its content in a variable and refills itself onGameLoad
	If AliasFailsafeRef
		Self.ForceRefTo(AliasFailsafeRef)
	EndIf

	Actor akSelf = GetActorReference()
	If akSelf
		SetupNotPersistentStats(akSelf)
		_ShowHealthBar()
	EndIf
EndFunction

Function TeleportToPlayer(Bool bTeleportInFront, Bool bSilent)
	Actor akSelf = Self.GetActorReference()
	If akSelf
		; Zero out-of-combat heal rate for teleport and a few seconds after it.
		; This is to prevent the apparition regenerating health IN combat on "Call Apparition" spam.
		UnregisterForUpdate()
		akSelf.ForceActorValue("HealRate", 0.0)
		bTeleportHealRate = True

		akSelf.Disable()
		_MoveToPlayer(akSelf, bTeleportInFront)
		akSelf.Enable()
		If bSilent == False
			akSelf.PlaceAtMe(_00E_Phasmalist_EnterWorldExp)
		EndIf
		
		RegisterForSingleUpdate(2.0)
	EndIf
EndFunction

Function SetCombatStyle(CombatStyle newCombatStyle)
	Actor akSelf = Self.GetActorReference()
	If akSelf
		_SetCombatStyle(akSelf, newCombatStyle)
	EndIf
EndFunction

Function ShowStatsMenu()
	Actor akSelf = Self.GetActorReference()
	If akSelf
		UIExtensions.initMenu("UIStatsMenu")
		UIExtensions.openMenu("UIStatsMenu", akSelf)
	EndIf
EndFunction

Function ShowEquipment()
	Actor akSelf = Self.GetActorReference()

	If akSelf
		String text = _00E_Phasmalist_CurrentlyEquipped.GetName() + "\n\n"

		Weapon EquippedWeapon = akSelf.GetEquippedWeapon()
		If EquippedWeapon
			text = text + EquippedWeapon.GetName() + "\n" ;weapon
			If EquippedWeapon.IsBow()
				Form[] arrows = _00E_AllAmmos.ToArray()
				Int i = 0
				Int nArrowCount
				While i < arrows.Length
					nArrowCount = akSelf.GetItemCount(arrows[i])
					If nArrowCount > 0
						text = text + (arrows[i].GetName() + " (" + nArrowCount +")\n")
					EndIf
					i += 1
				EndWhile
			EndIf
		EndIf
		text = _AddWornFormAsString(akSelf, 0x00000200, text) ;shield
		text = _AddWornFormAsString(akSelf, 0x00001000, text) ;circlet
		text = _AddWornFormAsString(akSelf, 0x00000004, text) ;body
		text = _AddWornFormAsString(akSelf, 0x00000008, text) ;hands
		text = _AddWornFormAsString(akSelf, 0x00000080, text) ;feet
		text = _AddWornFormAsString(akSelf, 0x00000020, text) ;amulet
		text = _AddWornFormAsString(akSelf, 0x00000040, text) ;ring

		Debug.MessageBox(text)
	EndIf	
EndFunction


;=====================================================================================
;              						WEREWOLF
;=====================================================================================

FormList Property _00E_Phasmalist_CombatStyleWerewolfList Auto
Spell Property _00E_FS_Affinity_Soulcaller_ApparationWolfBoostSP Auto
Idle Property WerewolfTransformBack Auto
Idle Property IdleWerewolfTransformation Auto
Explosion Property _00E_FS_Theriantrophist_TransEXP Auto
Race Property _00E_Theriantrophist_PlayerWerewolfRace Auto
ObjectReference Property _00E_FS_Affinity_Soulcaller_RemoveAndAddApparationItemsChest Auto
Idle Property LooseFullBodyStagger Auto
Armor Property _00E_InvisibleHelmet_Armor Auto

Float Property WEREWOLF_TRANSFORM_UNARMED_DAMAGE_BOOST = 20.0 AutoReadOnly
Float Property WEREWOLF_TRANSFORM_HEALTH_BOOST = 40.0 AutoReadOnly

Race WerewolfTranform_OriginalRace = None

Bool Function IsTransformedToWerewolf()
	Return (WerewolfTranform_OriginalRace != None)
EndFunction

Function TransformToWerewolf(Actor akSpellTarget)
	ObjectReference expMarker

	Actor akSelf = GetActorReference()
	If (akSelf == None) || (akSelf != akSpellTarget)
		Return
	EndIf

	bActivationBusy = True

	akSelf.SetPlayerTeammate(False)
	akSelf.EvaluatePackage()
	WerewolfTranform_OriginalRace = akSelf.getRace()
	Utility.Wait(0.2)
	akSelf.PlayIdle(IdleWerewolfTransformation)
	Utility.Wait(0.8)

	_SetCombatStyle(akSelf, _00E_Phasmalist_CombatStyleWerewolfList.GetAt(0) as CombatStyle)
	_00E_FS_Affinity_Soulcaller_ApparationWolfBoostSP.SetNthEffectMagnitude(0, WEREWOLF_TRANSFORM_UNARMED_DAMAGE_BOOST)
	_00E_FS_Affinity_Soulcaller_ApparationWolfBoostSP.SetNthEffectMagnitude(1, WEREWOLF_TRANSFORM_HEALTH_BOOST)
	akSelf.AddSpell(_00E_FS_Affinity_Soulcaller_ApparationWolfBoostSP)
	expMarker = _PlaceExplosionEx(_00E_FS_Theriantrophist_TransEXP, akSelf, 100.0)
	Utility.Wait(0.4) ; Pause to synchronize the explosion with the transformation animation(s)
	akSelf.SetLookAt(akSelf) ; Reset headtracking to prevent the head getting stuck looking sideways after the tranformation
	akSelf.UnequipAll()
	akSelf.SetRace(_00E_Theriantrophist_PlayerWerewolfRace)

	_DeleteMarker(expMarker)
	Utility.Wait(0.2)
	akSelf.SetPlayerTeammate(True)
	akSelf.EvaluatePackage()

	bActivationBusy = False
EndFunction

Function TransformFromWerewolf(Actor akSpellTarget, Bool bIsUnsummoned, Bool bSilent)
	Actor akSelf = GetActorReference()
	If (IsTransformedToWerewolf() == False) || (akSelf == None) || (akSelf != akSpellTarget)
		Return
	EndIf

	bActivationBusy = True
	bTeleportHealRate = False

	If akSelf.IsDead()
		_TransformFromWerewolfDead(akSelf, bIsUnsummoned, bSilent)
	Else
		_TransformFromWerewolfAlive(akSelf, bIsUnsummoned, bSilent)
	EndIf

	WerewolfTranform_OriginalRace = None

	bActivationBusy = False
EndFunction

Function _TransformFromWerewolfDead(Actor akSelf, Bool bIsUnsummoned, Bool bSilent)
	ObjectReference expMarker = None

	GoToState("")

	If bSilent == False
		expMarker = _PlaceExplosionEx(_00E_FS_Theriantrophist_TransEXP, akSelf, 15.0)
	EndIf
	; RemoveAllItems is needed here for _TriggerEquipmentUpdate to work
	akSelf.RemoveAllItems(_00E_FS_Affinity_Soulcaller_RemoveAndAddApparationItemsChest)
	akSelf.SetPlayerTeammate(False)
	akSelf.Resurrect()
	_00E_FS_Affinity_Soulcaller_RemoveAndAddApparationItemsChest.RemoveAllItems(akSelf)
	Utility.Wait(0.2) ; Pause for the ragdoll to settle. Without it the apparition appears in the air on SetRace
	_SetCombatStyle(akSelf, SummonTrinket.GetUsedCombatStyle())
	akSelf.RemoveSpell(_00E_FS_Affinity_Soulcaller_ApparationWolfBoostSP)
	If expMarker
		_DeleteMarker(expMarker)
		expMarker = None
	EndIf
	akSelf.SetRace(WerewolfTranform_OriginalRace)
	_TriggerEquipmentUpdate(akSelf, False)
	akSelf.ClearLookAt() ; Reenable headtracking

	If bIsUnsummoned == False
		GoToState("Working")
	EndIf
	akSelf.Kill()
EndFunction

Function _TransformFromWerewolfAlive(Actor akSelf, Bool bIsUnsummoned, Bool bSilent)
	ObjectReference expMarker = None

	akSelf.SetPlayerTeammate(False)
	akSelf.EvaluatePackage()
	akSelf.PlayIdle(WerewolfTransformBack)
	akSelf.RemoveSpell(_00E_FS_Affinity_Soulcaller_ApparationWolfBoostSP)
	_SetCombatStyle(akSelf, SummonTrinket.GetUsedCombatStyle())
	If bSilent == False
		expMarker = _PlaceExplosionEx( _00E_FS_Theriantrophist_TransEXP, akSelf, 100.0)
	EndIf
	akSelf.SetRace(WerewolfTranform_OriginalRace)
	_TriggerEquipmentUpdate(akSelf, True)
	If expMarker
		_DeleteMarker(expMarker)
		expMarker = None
	EndIf
	Utility.Wait(0.2)
	akSelf.ClearLookAt() ; Reenable headtracking
	If bIsUnsummoned == False
		SetupBehaviour(akSelf)
		SetupNotPersistentStats(akSelf)
		akSelf.EvaluatePackage()
	EndIf
EndFunction

Function _TriggerEquipmentUpdate(Actor akSelf, Bool bPlayStaggerIdle)
	akSelf.SetPlayerTeammate(True) ; Yes, the apparition has to be a player's teammate for AddItem-EquipItem below to trigger equipment update
	If bPlayStaggerIdle
		akSelf.PlayIdle(LooseFullBodyStagger)
	EndIf

	akSelf.AddItem(_00E_InvisibleHelmet_Armor, 1, True)
	akSelf.EquipItem(_00E_InvisibleHelmet_Armor, 1)
	akSelf.RemoveItem(_00E_InvisibleHelmet_Armor, 1)
EndFunction


;=====================================================================================
;              						HELPER FUNCTIONS
;=====================================================================================

String Function _AddWornFormAsString(Actor a, int slot, string s)
	Form wornForm = a.GetWornForm(slot)
	If wornForm
		Return s + wornForm.GetName() + "\n"
	EndIf
	Return s
EndFunction

Function _ShowHealthBar()
	Actor akSelf = Self.GetActorReference()
	If akSelf && akSelf.IsDead() == False
		HealthBarManager.Show(akSelf)
	EndIf
EndFunction

Float Property FRONT_TELEPORT_DISTANCE = 72.0 AutoReadOnly
Float Property BACK_TELEPORT_DISTANCE = 96.0 AutoReadOnly

Function _MoveToPlayer(Actor akSelf, Bool bTeleportInFront)
	Float fHeadingAngle = PlayerREF.GetAngleZ()
	If bTeleportInFront
		akSelf.MoveTo(PlayerREF, FRONT_TELEPORT_DISTANCE * Math.sin(fHeadingAngle), FRONT_TELEPORT_DISTANCE * Math.cos(fHeadingAngle), 0, True)
		akSelf.SetAngle(0, 0, fHeadingAngle + 180.0)
	Else
		fHeadingAngle += 180.0
		akSelf.MoveTo(PlayerREF, BACK_TELEPORT_DISTANCE * Math.sin(fHeadingAngle), BACK_TELEPORT_DISTANCE * Math.cos(fHeadingAngle), 0, True)
	EndIf
EndFunction

Function _SetCombatStyle(Actor akSelf, CombatStyle newCombatStyle)
	akSelf.StopCombat()
	akSelf.GetActorBase().SetCombatStyle(newCombatStyle)
EndFunction

Spell Function _GetSpellFromSpellBook(Form akBaseItem)
	; The apparition should not be able to learn summon creature and mystical/mythical spells
	Int iSpellBook = _00E_PhasmalistApparition_SpellBooks.Find(akBaseItem)
	If iSpellBook >= 0
		Return (_00E_PhasmalistApparition_Spells.GetAt(iSpellBook) as Spell)
	Else
		Return None
	EndIf
EndFunction

Function _RegisterSpellBook(Actor akSelf, Form akBaseItem)
	Spell bookSpell = _GetSpellFromSpellBook(akBaseItem)
	If bookSpell
		Self.GetActorReference().AddSpell(bookSpell, False)
	EndIf
EndFunction

Function _UnregisterSpellBook(Actor akSelf, Form akBaseItem)
	Spell bookSpell = _GetSpellFromSpellBook(akBaseItem)
	If bookSpell
		Self.GetActorReference().RemoveSpell(bookSpell)
	EndIf
EndFunction

ObjectReference Function _PlaceExplosionEx(Explosion exp, ObjectReference refSpot, Float fOffsetZ)
	ObjectReference expMarker = refSpot.PlaceAtMe(XMarker)
	expMarker.MoveTo(refSpot, 0.0, 0.0, fOffsetZ)
	expMarker.PlaceAtMe(exp)
	Return expMarker
EndFunction

Function _DeleteMarker(ObjectReference refMarker)
	refMarker.Disable()
	refMarker.Delete()
EndFunction


;=====================================================================================
;              						EVENTS
;=====================================================================================

Bool bActivationBusy = False

State Working

	Event OnActivate(ObjectReference akActivator)
		If akActivator == PlayerREF && bActivationBusy == False
			bActivationBusy = True

			UIExtensions.initMenu("UIWheelMenu")
			UIExtensions.SetMenuPropertyIndexBool("UIWheelMenu", "optionEnabled", 0, true)
			UIExtensions.SetMenuPropertyIndexBool("UIWheelMenu", "optionEnabled", 1, true)
			UIExtensions.SetMenuPropertyIndexBool("UIWheelMenu", "optionEnabled", 4, true)
			UIExtensions.SetMenuPropertyIndexBool("UIWheelMenu", "optionEnabled", 5, true)
			
			UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", 0, "$View_Attributes")
			UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", 0, "$View_Attributes")

			If IsTransformedToWerewolf() == False
				UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", 1, "$Adapt_Combat_Style")
				UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", 1, "$Adapt_Combat_Style")

				UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", 4, "$Currently_Equipped")
				UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", 4, "$Currently_Equipped")
			EndIf
			
			UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionText", 5, "$Quit")
			UIExtensions.SetMenuPropertyIndexString("UIWheelMenu", "optionLabelText", 5, "$Quit")
			
			Int iChoice = UIExtensions.OpenMenu("UIWheelMenu", Self.GetActorReference())
			If iChoice == 0
				ShowStatsMenu()
			ElseIf iChoice == 1
				SummonTrinket.ChooseApparitionCombatStyle()
			ElseIf iChoice == 4
				ShowEquipment()
			EndIf

			bActivationBusy = False
		EndIf
	EndEvent

	Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
		If akBaseItem as Book
			_RegisterSpellBook(Self.GetActorReference(), akBaseItem)
		EndIf
	EndEvent

	Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
		If akBaseItem as Book
			Actor akSelf = Self.GetActorReference()
			If akSelf.GetItemCount(akBaseItem) <= 0
				_UnregisterSpellBook(akSelf, akBaseItem)
			EndIf
		EndIf
	EndEvent

	Event OnLoad()
		bActivationBusy = False ; Safeguard
		_ShowHealthBar()
	EndEvent

	Event OnDying(Actor akKiller)
		AliasFailsafeRef = None
	EndEvent

	Event OnDeath(Actor akKiller)
		AliasFailsafeRef = None
		(GetOwningQuest() as _FS_Phasmalist_ControlQuest).UnsummonApparition()
	EndEvent

	Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
		If aeCombatState == 1
			_ShowHealthBar()
		EndIf
	EndEvent

	Event OnUpdate()
		If bTeleportHealRate
			bTeleportHealRate = False
			GetActorReference().ForceActorValue("HealRate", DEFAULT_HEAL_RATE)
		EndIf
	EndEvent

EndState
