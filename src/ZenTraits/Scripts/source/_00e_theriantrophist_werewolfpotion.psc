Scriptname _00E_Theriantrophist_WerewolfPotion extends activemagiceffect  

Import ArcaneFever

Float Property AdditionalArcaneFever = 6 Autoreadonly Hidden
Float Property ArcaneFeverReductionPerk01 = 0.17 Autoreadonly Hidden
Float Property ArcaneFeverReductionPerk02 = 0.16 Autoreadonly Hidden

Message Property _00E_Player_sArcaneFeverIncreased Auto

Perk Property _00E_Class_Theriantrophist_P04c_LessArcaneFever_01 Auto
Perk Property _00E_Class_Theriantrophist_P04c_LessArcaneFever_02 Auto

ImageSpaceModifier Property _00E_ArkanistenfieberIMOD Auto
Sound Property _00E_FS_IncreaseArcaneFeverM Auto

Actor Property PlayerREF Auto

Function _AddArcaneFever()
	ArcaneFever.ModFever(-_GetAdditionalArcaneFever(), True)
EndFunction

Float Function _GetAdditionalArcaneFever()

	if PlayerREF.hasPerk(_00E_Class_Theriantrophist_P04c_LessArcaneFever_02)
		return (1.0 - ArcaneFeverReductionPerk01 - ArcaneFeverReductionPerk02) * AdditionalArcaneFever
	elseif PlayerREF.hasPerk(_00E_Class_Theriantrophist_P04c_LessArcaneFever_01)
		return (1.0 - ArcaneFeverReductionPerk01) * AdditionalArcaneFever
	else
		return AdditionalArcaneFever
	EndIf
EndFunction

Function _RestorePotion()
	MagicEffect[] effects = new MagicEffect[1]
	Float[] magnitudes = new Float[1]
	Int[] durations = new Int[1]
	Int[] areas = new Int[1]
	
	effects[0] = self.getBaseObject()
	magnitudes[0] = self.getMagnitude()
	durations[0] = self.getDuration() as Int
	areas[0] = 0
	
	Potion toRestore = EnderalFunctions.CreatePotion(effects, magnitudes, areas, durations, 1)
	PlayerREF.addItem(toRestore, abSilent = true)
EndFunction
