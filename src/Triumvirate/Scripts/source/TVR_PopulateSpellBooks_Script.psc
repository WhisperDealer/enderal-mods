ScriptName TVR_PopulateSpellBooks_Script extends Quest
{Enderal replacement for Triumvirate's distribution script (WD-16).

The original makes 76 calls against Skyrim NPCs, merchant chests and staff
leveled lists, none of which exist in Enderal - every call would log a
"Cannot call ... on a None object" error at game start. Distribution is
rebuilt at the record level instead (Enderal merchant chest overrides carry
the tome bundles), so only the two live pieces of the original survive here:
starting the Conversion quest, and the mod-ready message.

Ships loose so it beats the copy in Triumvirate's BSA. The quest record's
properties were stripped to match (src/Triumvirate/tools/15-distribution.ps1).}

Quest Property TVR_Conversion_Quest Auto
Message Property TVR_Any_Message_ModReady Auto
Float Property TVR_UpdateRate Auto

Event OnInit()
	RegisterForSingleUpdate(TVR_UpdateRate)
EndEvent

Event OnUpdate()
	TVR_Conversion_Quest.Start()
	If TVR_Any_Message_ModReady
		TVR_Any_Message_ModReady.Show()
	EndIf
	Stop()
EndEvent
