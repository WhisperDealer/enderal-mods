Scriptname ZenTraits_ArcaneFeverScript extends Quest

Actor Property PlayerRef Auto

ImageSpaceModifier Property _00E_ArkanistenfieberIMOD Auto
Sound Property _00E_FS_IncreaseArcaneFeverM  Auto  
Message Property _00E_Player_sArcaneFeverIncreased  Auto  

Sound Property _00E_FS_DecreaseArcaneFeverM Auto
ImageSpaceModifier Property _00E_FS_ReduceArcaneFeverIMOD Auto
Message Property _00E_AlchAmbrosia_sArcaneFeverDecreased Auto

; modifiers
Perk Property _00E_Class_Thaumaturge_P07_MentalExpert  Auto
Perk Property ZenTraits_NightFeverDayPERK Auto
GlobalVariable Property ZenTraits_NightFeverDayMagnitude Auto
MagicEffect Property ZenTraits_PurifiedBloodMGEF Auto
GlobalVariable Property ZenTraits_PurifiedBloodFeverMult Auto
GlobalVariable Property ZenTraits_PurifiedBloodAmbrosiaMult Auto
Perk Property ZenTraits_ArcaneAddictPERK Auto
GlobalVariable Property ZenTraits_ArcaneAddictFeverMult Auto

Function ModFever(Float fMagnitude, Bool bVisual = False)
    If fMagnitude < 0
        fMagnitude = ApplyIncreaseFeverMods(fMagnitude)
    Else
        fMagnitude = ApplyDecreaseFeverMods(fMagnitude)
    EndIf

    PlayerRef.ModActorValue("lastFlattered", fMagnitude)

    Notify(fMagnitude, 0.0, bVisual)
EndFunction

Float Function ApplyIncreaseFeverMods(Float fMagnitude)
    If PlayerRef.HasPerk(_00E_Class_Thaumaturge_P07_MentalExpert)
        fMagnitude = fMagnitude * 0.67
    EndIf

    ; Traits
    If PlayerRef.HasPerk(ZenTraits_NightFeverDayPERK)
        fMagnitude *= ZenTraits_NightFeverDayMagnitude.value
    EndIf
    If PlayerRef.HasMagicEffect(ZenTraits_PurifiedBloodMGEF)
        fMagnitude *= ZenTraits_PurifiedBloodFeverMult.value
    EndIf
    If PlayerRef.HasPerk(ZenTraits_ArcaneAddictPERK)
        fMagnitude *= ZenTraits_ArcaneAddictFeverMult.value
    EndIf

    Return fMagnitude
EndFunction

Float Function ApplyDecreaseFeverMods(Float fMagnitude)
    float fCurrentAV = -1 * PlayerRef.GetActorValue("LastFlattered")

    If fCurrentAV <= fMagnitude ; max at 0
        fMagnitude = fCurrentAV
    EndIf

    Return fMagnitude
EndFunction

Float Function GetAmbrosiaMod(Float fMagnitude)
    If PlayerRef.HasMagicEffect(ZenTraits_PurifiedBloodMGEF)
        fMagnitude *= ZenTraits_PurifiedBloodAmbrosiaMult.value
    EndIf

    Return fMagnitude
EndFunction

Function Notify(Float fMagnitude, Float fNewValue = 0.0, Bool bVisual = False)
    If fNewValue == 0.0
        fNewValue = -PlayerRef.GetActorValue("LastFlattered")
    EndIf

    If fMagnitude < 0 ; increase
        _00E_Player_sArcaneFeverIncreased.Show(Math.Abs(fMagnitude), fNewValue)
        _00E_FS_IncreaseArcaneFeverM.Play(PlayerREF)
        If bVisual
            _00E_ArkanistenfieberIMOD.ApplyCrossFade()
        EndIf
    Else
        _00E_FS_DecreaseArcaneFeverM.Play(PlayerRef)
        If fNewValue == 0
            _00E_AlchAmbrosia_sArcaneFeverDecreased.Show(Math.Abs(fMagnitude) - Math.Abs(fNewValue), 0)
        Else
            _00E_AlchAmbrosia_sArcaneFeverDecreased.Show(Math.Abs(fMagnitude), -1 * PlayerRef.GetActorValue("LastFlattered"))
        EndIf
        If bVisual
            _00E_FS_ReduceArcaneFeverIMOD.Apply()
        EndIf
    EndIf
EndFunction

