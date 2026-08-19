Scriptname ZenTraits_CleansedSoulScript extends activemagiceffect  

Import ArcaneFever

GlobalVariable Property GameHour Auto
GlobalVariable Property Magnitude Auto

Float startTime

Event OnEffectStart(Actor akTarget, Actor akCaster)
    RegisterForSleep()
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    UnregisterForSleep()
EndEvent

Event OnSleepStart(float afSleepStartTime, float afDesiredSleepEndTime)
    startTime = GameHour.value
EndEvent

Event OnSleepStop(bool abInterrupted)
    Float hoursSlept = GetHoursSlept(GameHour.value)
    ModFever(hoursSlept * Magnitude.value, True)
EndEvent

Float Function GetHoursSlept(Float endTime)
    Float hoursSlept = endTime - startTime
    If hoursSlept < 0.0
        hoursSlept += 24.0
    EndIf
    If hoursSlept == 0
        Return 24
    EndIf
    Return hoursSlept
EndFunction