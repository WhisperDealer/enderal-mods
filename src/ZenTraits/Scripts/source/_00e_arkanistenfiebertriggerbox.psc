Scriptname _00E_ArkanistenfieberTriggerbox extends ObjectReference


;=====================================================================================
;              							PROPERTIES
;=====================================================================================

Float Property Timer = 3.0 Auto 
Int Property strength = 2 Auto

Actor Property PlayerREF Auto
Message Property _00E_Player_sArcaneFeverIncreased Auto
ImageSpaceModifier Property _00E_ArkanistenfieberIMOD Auto
Sound Property _00E_FS_IncreaseArcaneFeverM Auto
GlobalVariable Property GameDaysPassed Auto
GlobalVariable Property TimeScale Auto

Bool bPlayerInsideTrigger = False
Bool bTimerTicking = False
Float fSleepStartTime


;=====================================================================================
;              							EVENTS
;=====================================================================================

Event OnTriggerEnter(ObjectReference akActionRef)
	If akActionRef == PlayerREF
		bPlayerInsideTrigger = True
		RegisterForSleep()
		If bTimerTicking == False
			IncreaseFeaverTick()
		EndIf
	EndIf
EndEvent

Event OnTriggerLeave(ObjectReference akActionRef)
	If akActionRef == PlayerREF
		bPlayerInsideTrigger = False
		UnregisterForSleep()
	EndIf
EndEvent

Event OnUnload()
	; Failsafe reset of everything
	bPlayerInsideTrigger = False
	bTimerTicking = False
	fSleepStartTime = 0
	UnregisterForUpdate()
	UnregisterForSleep()
EndEvent

Event OnUpdate()
	If bPlayerInsideTrigger
		IncreaseFeaverTick()
	Else
		bTimerTicking = False
	EndIf
EndEvent

Event OnSleepStart(Float afSleepStartTime, Float afDesiredSleepEndTime)
	; Track player sleeping in the trigger because of the bed in Old Three River Watch
	If bPlayerInsideTrigger
		bTimerTicking = False
		UnregisterForUpdate()
		fSleepStartTime = GameDaysPassed.GetValue()
	Else
		fSleepStartTime = 0
	EndIf
EndEvent

Event OnSleepStop(Bool abInterrupted)
	If fSleepStartTime > 0.0
		; Inc. fever periods = (sleep time in days * secs per day) / (timescale * inc. fever timer)
		Int nPeriods = (((GameDaysPassed.GetValue() - fSleepStartTime) * 86400.0) / (TimeScale.GetValue() * Timer)) as Int
		fSleepStartTime = 0.0
		IncreaseFeaverBy(Strength * nPeriods)
	EndIf

	If bPlayerInsideTrigger && bTimerTicking == False
		bTimerTicking = True
		RegisterForSingleUpdate(Timer)
	EndIf
EndEvent


;=====================================================================================
;              							FUNCTIONS
;=====================================================================================

Function IncreaseFeaverBy(Int iValue)
	If PlayerREF.IsDead() == False
		ArcaneFever.ModFever(-iValue, True)
	EndIf
EndFunction

Function IncreaseFeaverTick()
	bTimerTicking = True

	IncreaseFeaverBy(Strength)

	If bTimerTicking
		RegisterForSingleUpdate(Timer)
	EndIf
EndFunction
