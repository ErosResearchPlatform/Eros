/mob/living/bot/medbot
	name = "Medbot"
	desc = "A fairly crude medical robot. Now comes with a speaker system and advanced diagnostics!"
	icon_state = "medibot0"
	req_one_access = list(access_medical, access_robotics)
	botcard_access = list(access_medical, access_morgue, access_surgery, access_chemistry, access_virology, access_genetics)

	var/skin = null //Set to "tox", "ointment" or "o2" for the other two firstaid kits.

	//AI vars
	var/last_newpatient_speak = 0
	var/vocal = 1

	//Healing vars
	var/obj/item/weapon/reagent_containers/glass/reagent_glass = null //Can be set to draw from this for reagents.
	var/injection_amount = 15 //How much reagent do we inject at a time?
	var/heal_threshold = 5 //Start healing when they have this much damage in a category
	var/use_beaker = 0 //Use reagents in beaker instead of default treatment agents.
	var/treatment_brute = "tricordrazine"
	var/treatment_oxy = "tricordrazine"
	var/treatment_fire = "tricordrazine"
	var/treatment_tox = "tricordrazine"
	var/treatment_virus = "spaceacillin"
	var/treatment_emag = "amatoxin"
	var/declare_treatment = 0 //When attempting to treat a patient, should it notify everyone wearing medhuds?


/mob/living/bot/medbot/handleAdjacentTarget()
	UnarmedAttack(target)

/mob/living/bot/medbot/lookForTargets()
	for(var/mob/living/carbon/human/H in view(7, src)) // Time to find a patient!
		if(confirmTarget(H))
			target = H
			if(last_newpatient_speak + 300 < world.time)
				if(vocal)
					playsound(src.loc, 'sound/medbot/Administering_medical.ogg', 35)
					say("Administering medical attention!")


				custom_emote(1, "points at [H.name].")
				last_newpatient_speak = world.time
			break

/mob/living/bot/medbot/UnarmedAttack(var/mob/living/carbon/human/H, var/proximity)
	if(!..())
		return

	if(!on)
		return

	if(!istype(H))
		return

	if(busy)
		return

	if(H.stat == DEAD)
		playsound(src.loc, 'sound/medbot/Flatline_custom.ogg', 35)
		custom_emote(1, "points at [H.name].")
		target = null
		return

	var/t = confirmTarget(H)
	if(!t)
		playsound(src.loc, 'sound/medbot/Medical_repaired.ogg', 35)
		custom_emote(1, "points at [H.name].")
		target = null
		return

	icon_state = "medibots"
	visible_message("<span class='warning'>[src] is attempting to diagnose and treat [H]!</span>")
	if(declare_treatment)
		var/area/location = get_area(src)
		broadcast_medical_hud_message("[src] is treating <b>[H]</b> in <b>[location]</b>", src)
	busy = 1
	update_icons()
	if(do_mob(src, H, 30))
		if(t == 1)
			reagent_glass.reagents.trans_to_mob(H, injection_amount, CHEM_BLOOD)
		else
			H.reagents.add_reagent(t, injection_amount)
			if(vocal == 1)
				visible_message("<span class='warning'>[src] injects [H] and gives a diagnosis!</span>")
			else
				visible_message("<span class='warning'>[src] injects [H] with it's syringe! </span>")

	busy = 0
	update_icons()

	//Voice callouts - Should be happening after the actual treatments. Still part of the "UnarmedAttack" proc to ensure it only plays once.

	var/combined_damage = H.getBruteLoss() + H.getFireLoss() + H.getToxLoss() + H.getOxyLoss()

	if(vocal == 1)
		if(combined_damage > 85)
			playsound(src.loc, 'sound/medbot/Near_death.ogg', 35)
			custom_emote(1, "points at [H.name].")
			say("EMERGENCY! USER DEATH IMMINENT!")
			sleep(45)
		if((H.getBruteLoss() <= 50) && (H.getBruteLoss() > 0))
			playsound(src.loc, 'sound/medbot/Minor_lacerations.ogg', 35)
			say("Minor lacerations detected!")
			sleep(35)
		if(H.getBruteLoss() > 50)
			playsound(src.loc, 'sound/medbot/Danger.ogg', 35)
			say("Danger!")
			sleep(10)
			playsound(src.loc, 'sound/medbot/Major_lacerations.ogg', 35)
			say("Major lacerations detected!")
			sleep(35)
		if(H.getToxLoss() > 0)
			playsound(src.loc, 'sound/medbot/Blood_toxins.ogg', 35)
			say("Warning! Blood toxin levels detected!")
			sleep(45)
			playsound(src.loc, 'sound/medbot/Antitoxin_shot.ogg', 35)
			say("Antitoxin administered!")
			sleep(25)
		if(H.getFireLoss() > 0)
			playsound(src.loc, 'sound/medbot/Heat_damage.ogg', 35)
			say("Warning! Extreme heat damage detected!")
			sleep(45)
		if(H.getOxyLoss() > 10)
			playsound(src.loc, 'sound/medbot/Blood_loss.ogg', 35)
			say("Blood loss detected!")
			sleep(25)
		return

/mob/living/bot/medbot/update_icons()
	overlays.Cut()
	if(skin)
		overlays += image('icons/obj/aibots.dmi', "medskin_[skin]")
	if(busy)
		icon_state = "medibots"
	else
		icon_state = "medibot[on]"

/mob/living/bot/medbot/attackby(var/obj/item/O, var/mob/user)
	if(istype(O, /obj/item/weapon/reagent_containers/glass))
		if(locked)
			to_chat(user, "<span class='notice'>You cannot insert a beaker because the panel is locked.</span>")
			return
		if(!isnull(reagent_glass))
			to_chat(user, "<span class='notice'>There is already a beaker loaded.</span>")
			return

		user.drop_item()
		O.loc = src
		reagent_glass = O
		to_chat(user, "<span class='notice'>You insert [O].</span>")
		return
	else
		..()

/mob/living/bot/medbot/GetInteractTitle()
	. = "<head><title>Medibot v1.0 controls</title></head>"
	. += "<b>Automatic Medical Unit v1.5</b>"

/mob/living/bot/medbot/GetInteractStatus()
	. = ..()
	. += "<br>Beaker: "
	if(reagent_glass)
		. += "<A href='?src=\ref[src];command=eject'>Loaded \[[reagent_glass.reagents.total_volume]/[reagent_glass.reagents.maximum_volume]\]</a>"
	else
		. += "None loaded"

/mob/living/bot/medbot/GetInteractPanel()
	. = "Healing threshold: "
	. += "<a href='?src=\ref[src];command=adj_threshold;amount=-10'>--</a> "
	. += "<a href='?src=\ref[src];command=adj_threshold;amount=-5'>-</a> "
	. += "[heal_threshold] "
	. += "<a href='?src=\ref[src];command=adj_threshold;amount=5'>+</a> "
	. += "<a href='?src=\ref[src];command=adj_threshold;amount=10'>++</a>"

	. += "<br>Injection level: "
	. += "<a href='?src=\ref[src];command=adj_inject;amount=-5'>-</a> "
	. += "[injection_amount] "
	. += "<a href='?src=\ref[src];command=adj_inject;amount=5'>+</a> "

	. += "<br>Reagent source: <a href='?src=\ref[src];command=use_beaker'>[use_beaker ? "Loaded Beaker (When available)" : "Internal Synthesizer"]</a>"
	. += "<br>Treatment report is [declare_treatment ? "on" : "off"]. <a href='?src=\ref[src];command=declaretreatment'>Toggle</a>"
	. += "<br>The speaker switch is [vocal ? "on" : "off"]. <a href='?src=\ref[src];command=togglevoice'>Toggle</a>"

/mob/living/bot/medbot/GetInteractMaintenance()
	. = "Injection mode: "
	switch(emagged)
		if(0)
			. += "<a href='?src=\ref[src];command=emag'>Treatment</a>"
		if(1)
			. += "<a href='?src=\ref[src];command=emag'>Random (DANGER)</a>"
		if(2)
			. += "ERROROROROROR-----"

/mob/living/bot/medbot/ProcessCommand(var/mob/user, var/command, var/href_list)
	..()
	if(CanAccessPanel(user))
		switch(command)
			if("adj_threshold")
				if(!locked || issilicon(user))
					var/adjust_num = text2num(href_list["amount"])
					heal_threshold = Clamp(heal_threshold + adjust_num, 5, 75)
			if("adj_inject")
				if(!locked || issilicon(user))
					var/adjust_num = text2num(href_list["amount"])
					injection_amount = Clamp(injection_amount + adjust_num, 5, 15)
			if("use_beaker")
				if(!locked || issilicon(user))
					use_beaker = !use_beaker
			if("eject")
				if(reagent_glass)
					if(!locked)
						reagent_glass.dropInto(src.loc)
						reagent_glass = null
					else
						to_chat(user, "<span class='notice'>You cannot eject the beaker because the panel is locked.</span>")
			if("togglevoice")
				if(!locked || issilicon(user))
					vocal = !vocal
			if("declaretreatment")
				if(!locked || issilicon(user))
					declare_treatment = !declare_treatment

	if(CanAccessMaintenance(user))
		switch(command)
			if("emag")
				if(emagged < 2)
					emagged = !emagged

/mob/living/bot/medbot/emag_act(var/remaining_uses, var/mob/user)
	. = ..()
	if(!emagged)
		if(user)
			to_chat(user, "<span class='warning'>You short out [src]'s reagent synthesis circuits.</span>")
			ignore_list |= user
		visible_message("<span class='warning'>[src] buzzes oddly!</span>")
		playsound(src.loc, 'sound/medbot/Chemical_detected.ogg', 35)
		say("Warning! Hazardous chemical detected!")
		flick("medibot_spark", src)
		vocal = 0
		target = null
		busy = 0
		emagged = 1
		injection_amount = 10 //Since it injects something actually dangerous now, it seems wise to tone the dosage down a hair. A jab will fuck you up but won't outright kill you.
		on = 1
		update_icons()
		. = 1

/mob/living/bot/medbot/explode()
	on = 0
	visible_message("<span class='danger'>[src] blows apart!</span>")
	var/turf/Tsec = get_turf(src)
	playsound(src.loc, 'sound/medbot/Flatline_custom.ogg', 35)
	new /obj/item/weapon/storage/firstaid(Tsec)
	new /obj/item/device/assembly/prox_sensor(Tsec)
	new /obj/item/device/healthanalyzer(Tsec)
	if (prob(50))
		new /obj/item/robot_parts/l_arm(Tsec)

	if(reagent_glass)
		reagent_glass.loc = Tsec
		reagent_glass = null

	var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
	s.set_up(3, 1, src)
	s.start()
	qdel(src)
	return

/mob/living/bot/medbot/confirmTarget(var/mob/living/carbon/human/H)
	if(!..())
		return 0

	if(H.stat == DEAD) // He's dead, Jim
		return 0

	if((emagged) && (!H.reagents.has_reagent(treatment_emag)))
		return treatment_emag
	if(emagged)
		return

	// If they're injured, we're using a beaker, and they don't have on of the chems in the beaker
	if(reagent_glass && use_beaker && ((H.getBruteLoss() >= heal_threshold) || (H.getToxLoss() >= heal_threshold) || (H.getToxLoss() >= heal_threshold) || (H.getOxyLoss() >= (heal_threshold + 15))))
		for(var/datum/reagent/R in reagent_glass.reagents.reagent_list)
			if(!H.reagents.has_reagent(R))
				return 1
			continue

	if((H.getBruteLoss() >= heal_threshold) && (!H.reagents.has_reagent(treatment_brute)))	//If they're already medicated don't bother!
		return treatment_brute

	if((H.getOxyLoss() >= (15 + heal_threshold)) && (!H.reagents.has_reagent(treatment_oxy)))
		return treatment_oxy

	if((H.getFireLoss() >= heal_threshold) && (!H.reagents.has_reagent(treatment_fire)))
		return treatment_fire

	if((H.getToxLoss() >= heal_threshold) && (!H.reagents.has_reagent(treatment_tox)))
		return treatment_tox

/* Construction */

/obj/item/weapon/storage/firstaid/attackby(var/obj/item/robot_parts/S, mob/user as mob)
	if ((!istype(S, /obj/item/robot_parts/l_arm)) && (!istype(S, /obj/item/robot_parts/r_arm)))
		..()
		return

	if(contents.len >= 1)
		to_chat(user, "<span class='notice'>You need to empty [src] out first.</span>")
		return

	var/obj/item/weapon/firstaid_arm_assembly/A = new /obj/item/weapon/firstaid_arm_assembly
	if(istype(src, /obj/item/weapon/storage/firstaid/fire))
		A.skin = "ointment"
	else if(istype(src, /obj/item/weapon/storage/firstaid/toxin))
		A.skin = "tox"
	else if(istype(src, /obj/item/weapon/storage/firstaid/o2))
		A.skin = "o2"

	qdel(S)
	user.put_in_hands(A)
	to_chat(user, "<span class='notice'>You add the robot arm to the first aid kit.</span>")
	user.drop_from_inventory(src)
	qdel(src)

/obj/item/weapon/firstaid_arm_assembly
	name = "first aid/robot arm assembly"
	desc = "A first aid kit with a robot arm permanently grafted to it."
	icon = 'icons/obj/aibots.dmi'
	icon_state = "firstaid_arm"
	var/build_step = 0
	var/created_name = "Medibot" //To preserve the name if it's a unique medbot I guess
	var/skin = null //Same as medbot, set to tox or ointment for the respective kits.
	w_class = ITEM_SIZE_NORMAL

/obj/item/weapon/firstaid_arm_assembly/New()
	..()
	spawn(5) // Terrible. TODO: fix
		if(skin)
			overlays += image('icons/obj/aibots.dmi', "kit_skin_[src.skin]")

/obj/item/weapon/firstaid_arm_assembly/attackby(obj/item/weapon/W as obj, mob/user as mob)
	..()
	if(istype(W, /obj/item/weapon/pen))
		var/t = sanitizeSafe(input(user, "Enter new robot name", name, created_name), MAX_NAME_LEN)
		if(!t)
			return
		if(!in_range(src, usr) && loc != usr)
			return
		created_name = t
	else
		switch(build_step)
			if(0)
				if(istype(W, /obj/item/device/healthanalyzer))
					user.drop_item()
					qdel(W)
					build_step++
					to_chat(user, "<span class='notice'>You add the health sensor to [src].</span>")
					playsound(src.loc, 'sound/medbot/Vitalsigns_on.ogg', 35)
					name = "First aid/robot arm/health analyzer assembly"
					overlays += image('icons/obj/aibots.dmi', "na_scanner")

			if(1)
				if(isprox(W))
					user.drop_item()
					qdel(W)
					to_chat(user, "<span class='notice'>You complete the Medibot! Beep boop.</span>")
					playsound(src.loc, 'sound/medbot/Automedic_on.ogg', 35)
					var/turf/T = get_turf(src)
					var/mob/living/bot/medbot/S = new /mob/living/bot/medbot(T)
					S.skin = skin
					S.name = created_name
					S.update_icons() // apply the skin
					user.drop_from_inventory(src)
					qdel(src)
