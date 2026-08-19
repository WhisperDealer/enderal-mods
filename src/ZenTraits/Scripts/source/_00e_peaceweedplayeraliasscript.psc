Scriptname _00E_PeaceweedPlayerAliasScript extends ReferenceAlias  

VisualEffect Property _00E_Smoking_PipeSmokingSmokeExhaleEffect Auto
Ingredient Property FrostMirriam Auto
Ingredient Property _00E_PeaceweedSpecial Auto
MiscObject Property _00E_SmokingPipe Auto
MagicEffect Property _00E_AlchReduceArcaneFever Auto

Message Property _00E_PeaceweedSmoking_PipeTutorial Auto
Message Property _00E_PeaceweedSmoking_ExitTutorial Auto
Message Property _00E_PeaceweedSmoking_ExitTutorial_Console Auto
Message Property _00E_PeaceweedSmoking_CantSmokeInWolfForm Auto
Message Property _00E_PeaceweedSmoking_CantSmokeNow Auto
Message Property _00E_PeaceweedSmoking_NoPeaceweed Auto

GlobalVariable Property _00E_DisableOtherTutorials Auto
GlobalVariable Property _00E_Meditate_Allowed Auto
_FS_TheriantrophistControlQuest Property TheriantrophistControlQuest Auto
WorldSpace Property MQ07aDreamRealm Auto
Location property _00E_ClassMenuLocation Auto

Sound Property _00E_FS_DecreaseArcaneFeverM Auto
Message Property _00E_AlchAmbrosia_sArcaneFeverDecreased Auto

Actor Property PlayerRef Auto
bool bSKSE = true

int function _GetScriptVersion() Global
    return 2
endFunction

;=====================================================================================
;              							SETUP
;=====================================================================================

Function Setup()
	If PlayerRef.GetItemCount(_00E_SmokingPipe) < 1
		GoToState("PipeTutorial")
	EndIf
EndFunction

State PipeTutorial

	Event OnBeginState()
		AddInventoryEventFilter(_00E_SmokingPipe)
	EndEvent

	Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
		If akBaseItem == _00E_SmokingPipe
			GoToState("")
			If (_00E_DisableOtherTutorials.GetValueInt() == 0)
				_00E_HelpMessage.Show(_00E_PeaceweedSmoking_PipeTutorial, 7)
			EndIf
		EndIf
	EndEvent

	Event OnEndState()
		RemoveInventoryEventFilter(_00E_SmokingPipe)
	EndEvent

EndState


;=====================================================================================
;              							SMOKING EVENTS                  					 
;=====================================================================================

State Smoking

	Event OnPlayerLoadGame()
		StopSmoking()
	EndEvent

	Event OnCombatStateChanged(Actor akTarget, int aeCombatState)
		If aeCombatState != 0
			StopSmoking()
		EndIf
	EndEvent

	Event OnUpdate()
		_UpdateSmoking()
		
		if ! bSKSE
			Utility.Wait(2.5)
			StopSmoking()
		endif
	EndEvent

EndState

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
	if akBaseObject == _00E_SmokingPipe
		StartSmoking()
	endif
endEvent


;=====================================================================================
;              							SMOKING                  					 
;=====================================================================================

Int SmokingStage = 0

Int Property SMOKING_STAGE_STOPPED   = 0 AutoReadOnly
Int Property SMOKING_STAGE_PREPARING = 1 AutoReadOnly
Int Property SMOKING_STAGE_WARMUP    = 2 AutoReadOnly
Int Property SMOKING_STAGE_SMOKING   = 3 AutoReadOnly

Float Property SMOKING_ARCANE_FEVER_REDUCE = 1.0 AutoReadOnly

bool bFirstPerson = true
Armor StoredEquippedShield
Armor StoredEquippedHelmet
Form[] EquippedTorches

Bool bQuitTutorialShown = False

Function StartSmoking()
	If SmokingStage != SMOKING_STAGE_STOPPED
		Return
	EndIf

	_LockSmokingStage()

	_TryStartSmoking()

	_UnlockSmokingStage()

EndFunction	

Function _TryStartSmoking()
	bSKSE = (SKSE.GetVersion() > 0)

	If TheriantrophistControlQuest.IsTransformed()
		_00E_PeaceweedSmoking_CantSmokeInWolfForm.Show()
		Return
	EndIf

	If (_00E_Meditate_Allowed.GetValueInt() == 0) || (PlayerRef.GetWorldSpace() == MQ07aDreamRealm) || PlayerRef.IsOnMount() || (bSKSE && PlayerRef.IsSwimming()) || (PlayerRef.GetSitState() != 0) || PlayerRef.IsInCombat() || PlayerREF.IsInLocation(_00E_ClassMenuLocation)
		_00E_PeaceweedSmoking_CantSmokeNow.Show()
		Return
	EndIf

	If PlayerRef.GetItemCount(FrostMirriam) < 1 && PlayerRef.GetItemCount(_00E_PeaceweedSpecial) < 1
		_00E_PeaceweedSmoking_NoPeaceweed.Show()
		Return
	EndIf

	; Check _00E_Meditate_Allowed again, just in case, because quite a lot of time passed since the previous check and we're going to change the flag
	If (_00E_Meditate_Allowed.GetValueInt() == 0)
		_00E_PeaceweedSmoking_CantSmokeNow.Show()
		Return
	EndIf

	SmokingStage = SMOKING_STAGE_PREPARING
	_00E_Meditate_Allowed.SetValueInt(0)
	GoToState("Smoking")
	
	Game.SetInChargen(true, true, false) ; Forbid saving the game while smoking
	Game.DisablePlayerControls(abMovement=true, abFighting=true, abCamSwitch=true, abLooking=false, abSneaking=true, abMenu=true, abActivate = true, abJournalTabs=true)

	bFirstPerson = PlayerREF.GetAnimationVariableBool("IsFirstPerson")
	Game.ForceThirdPerson()

	EquippedTorches = New Form[2]
	Bool bTorchesUnequipping = _00E_TorchControl.UnequipTorches(EquippedTorches)

	If PlayerRef.IsWeaponDrawn()
		_UnlockSmokingStage()
		_00E_EquipControl.SheatheWeapon(PlayerREF)
		_LockSmokingStage()
		If SmokingStage != SMOKING_STAGE_PREPARING ; The smoking was cancelled while we were waiting
			Return
		EndIf
	ElseIf bTorchesUnequipping
		; Give some time for torch unequip animations to settle
		_UnlockSmokingStage()
		Utility.Wait(0.25)
		_LockSmokingStage()
		If SmokingStage != SMOKING_STAGE_PREPARING ; The smoking was cancelled while we were waiting
			Return
		EndIf
	EndIf

	SmokingStage = SMOKING_STAGE_WARMUP

	; Unequip armor in the HEAD slot. Will work for most closed-face helmets, I hope.
	StoredEquippedHelmet = PlayerRef.GetEquippedArmorInSlot(30) as Armor
	If StoredEquippedHelmet
		PlayerREF.UnequipItem(StoredEquippedHelmet, False, True)
	EndIf

	; Unequip shield
	StoredEquippedShield = PlayerRef.GetEquippedShield()
	If StoredEquippedShield
		PlayerREF.UnequipItem(StoredEquippedShield, False, True)
	EndIf

	Debug.SendAnimationEvent(PlayerRef, "IdleSitCrossLeggedEnter")
	Utility.Wait(1.1)
	_AdjustCameraPositionToSitting()

	if bSKSE
		RefreshCancelKeys()
		RegisterCancelKeys()
		
		If (bQuitTutorialShown == False) && (_00E_DisableOtherTutorials.GetValueInt() == 0)
			bQuitTutorialShown = True
			If Game.UsingGamepad()
				If _00E_PeaceweedSmoking_ExitTutorial_Console == None
					_00E_PeaceweedSmoking_ExitTutorial_Console = Game.GetFormFromFile(0x000482F8, "Skyrim.esm") as Message
				EndIf
				_00E_HelpMessage.Show(_00E_PeaceweedSmoking_ExitTutorial_Console, 7)
			Else
				_00E_HelpMessage.Show(_00E_PeaceweedSmoking_ExitTutorial, 7)
			EndIf
		EndIf
		RegisterForSingleUpdate(2.9)
	else
		RegisterForSingleUpdate(5.0)
	endif
	
	Utility.Wait(0.4)
	Debug.SendAnimationEvent(PlayerRef, "pipesmokingcrossleggedstartblaze")
	Debug.SendAnimationEvent(PlayerRef, "pipesmokingcrossleggedblazed")
EndFunction

Function _UpdateSmoking()
	_LockSmokingStage()

	If SmokingStage == SMOKING_STAGE_WARMUP
		SmokingStage = SMOKING_STAGE_SMOKING 
		Debug.SendAnimationEvent(PlayerRef, "pipesmokingcrosslegged")
		_00E_Smoking_PipeSmokingSmokeExhaleEffect.Play(PlayerRef, -1.0, None)

		; Remove one Peaceweed and reduce arcane fever
		_00E_FS_DecreaseArcaneFeverM.Play(PlayerRef)

		If PlayerRef.GetItemCount(_00E_PeaceweedSpecial) >= 1
			ApplySmokingSideEffects(_00E_PeaceweedSpecial, SMOKING_ARCANE_FEVER_REDUCE * 2.0)
		Else
			ApplySmokingSideEffects(FrostMirriam, SMOKING_ARCANE_FEVER_REDUCE)
		EndIf
	EndIf

	_UnlockSmokingStage()
EndFunction

Function ApplySmokingSideEffects(Ingredient peaceweedIngredient, Float fReduceFeverValue)
	PlayerRef.RemoveItem(peaceweedIngredient, 1)

	ArcaneFever.ModFever(fReduceFeverValue, True)

	; Teach ambrosia effect
	if bSKSE
		Int Index = peaceweedIngredient.getNumEffects()
		While Index > 0
			Index -= 1
			If peaceweedIngredient.getNthEffectMagicEffect(Index) == _00E_AlchReduceArcaneFever
				peaceweedIngredient.LearnEffect(Index)
				Index = 0 ; Break
			EndIf
		EndWhile
	else
		peaceweedIngredient.LearnEffect(1)
	endif
EndFunction

Function StopSmoking()
	_LockSmokingStage()

	If SmokingStage != SMOKING_STAGE_STOPPED
		GoToState("")
		UnregisterCancelKeys()
		UnregisterForUpdate()

		Int interruptedStage = (SmokingStage as Int)
		SmokingStage = SMOKING_STAGE_STOPPED

		If interruptedStage != SMOKING_STAGE_PREPARING
			Debug.SendAnimationEvent(PlayerRef, "pipesmokingcrossleggedexit")
			If interruptedStage == SMOKING_STAGE_SMOKING
				_00E_Smoking_PipeSmokingSmokeExhaleEffect.Stop(PlayerRef)
			EndIf
			Utility.Wait(1.3)
			_RestoreCameraPosition()
			Utility.Wait(1.15)
			Debug.SendAnimationEvent(PlayerRef, "IdleForceDefaultState")
		EndIf

		Game.SetInChargen(false, true, false)
		Game.EnablePlayerControls()

		If StoredEquippedHelmet
			PlayerRef.EquipItem(StoredEquippedHelmet, False, True)
			StoredEquippedHelmet = None
		EndIf

		If StoredEquippedShield
			PlayerRef.EquipItem(StoredEquippedShield, False, True)
			StoredEquippedShield = None
		EndIf

		_00E_TorchControl.ReequipTorches(EquippedTorches)

		If bFirstPerson
			Game.ForceFirstPerson()
		EndIf

		_00E_Meditate_Allowed.SetValueInt(1)
	EndIf

	_UnlockSmokingStage()
EndFunction


;=====================================================================================
;              							SMOKING STAGE LOCK
;=====================================================================================

Bool bSmokingStageLocked = False

Function _LockSmokingStage()
	While bSmokingStageLocked
		Utility.WaitMenuMode(0.1)
	EndWhile
	bSmokingStageLocked = True
EndFunction

Function _UnlockSmokingStage()
	bSmokingStageLocked = False
EndFunction


;=====================================================================================
;              							3P CAMERA POSITION
;=====================================================================================

Bool bStoredCameraPositions
Float fStoredOverShoulderPosX
Float fStoredOverShoulderPosZ

Function _SetCameraPosition(Float x, Float z)
	Utility.SetINIFloat("fOverShoulderPosX:Camera", x)
	Utility.SetINIFloat("fOverShoulderPosZ:Camera", z)
	if bSKSE
		Game.UpdateThirdPerson()
	endif
EndFunction

Function _AdjustCameraPositionToSitting()
	If bStoredCameraPositions == False
		bStoredCameraPositions = True
		if bSKSE
			fStoredOverShoulderPosX = Utility.GetINIFloat("fOverShoulderPosX:Camera")
			fStoredOverShoulderPosZ = Utility.GetINIFloat("fOverShoulderPosZ:Camera")
		else
			fStoredOverShoulderPosX = 30.0
			fStoredOverShoulderPosZ = -10.0
		endif
		_00E_CameraControl.LockVanityCamera()
	EndIf

	_SetCameraPosition(0.0, -70.0)
EndFunction

Function _RestoreCameraPosition()
	If bStoredCameraPositions
		bStoredCameraPositions = False
		_00E_CameraControl.UnlockVanityCamera()
		_SetCameraPosition(fStoredOverShoulderPosX, fStoredOverShoulderPosZ)
	EndIf
EndFunction


;=====================================================================================
;              							CANCEL SMOKING KEYS
;=====================================================================================

Int[] CancelKeys
Int nCancelKeys

Function RefreshCancelKeys()
	CancelKeys = new Int[4]
	nCancelKeys = 0

	If Game.UsingGamepad()
		CancelKeys[0] = 0x118 ; LT
		CancelKeys[1] = 0x119 ; RT
		nCancelKeys = 2

		;Debug.Notification("Peaceweed: registered LT and RT gamepad buttons.")
	Else
		GetCancelKey("Forward")
		GetCancelKey("Back")
		GetCancelKey("Strafe Left")
		GetCancelKey("Strafe Right")

		;Debug.Notification("Peaceweed: registered for " + nCancelKeys + " keyboard/mouse keys.")
	EndIf
EndFunction

Function GetCancelKey(String Control, Int DeviceType = 0xFF)
	Int k = Input.GetMappedKey(Control, DeviceType)
	If k > 0
		CancelKeys[nCancelKeys] = k
		nCancelKeys += 1
	EndIf
EndFunction

Function RegisterCancelKeys()
	Int i = 0
	While i < nCancelKeys
		RegisterForKey(CancelKeys[i])
		i += 1
	EndWhile
EndFunction

Function UnregisterCancelKeys()
	UnRegisterForAllKeys()
EndFunction

Event OnKeyDown(Int KeyCode)
	UnregisterCancelKeys()
	If KeyCode > 0 && CancelKeys.Find(KeyCode) >= 0
		If Utility.IsInMenuMode() == False && UI.IsTextInputEnabled() == False
			StopSmoking()
		Else
			RegisterCancelKeys()
		EndIf
	EndIf
EndEvent
