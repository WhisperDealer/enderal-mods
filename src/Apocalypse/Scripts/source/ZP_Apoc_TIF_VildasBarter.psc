Scriptname ZP_Apoc_TIF_VildasBarter Extends TopicInfo Hidden

; Opens Priest Vildas's shop. He has no recorded trade line (VT_Male_Priest), so the
; response is silent and the barter menu opens at once. Same body as FS's Shrouded Mage
; barter fragments (TIF__0101E845).

Function Fragment_0(ObjectReference akSpeakerRef)
	Actor akSpeaker = akSpeakerRef as Actor
	akSpeaker.ShowBarterMenu()
EndFunction
