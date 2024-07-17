local cfg = mwse.loadConfig("PandaCHMod")

enchantedWeapons = {}

local function LOADED(e) p = tes3.player	mp = tes3.mobilePlayer
    timer.start{duration = 1, iterations = -1, callback = function()
        for _,mobile in pairs(tes3.findActorsInProximity{reference = p, range = 3000}) do 
            if mobile.fight >= 90 and
            not tes3.isAffectedBy({reference = mobile.reference, effect = 118}) and
            not tes3.isAffectedBy({reference = mobile.reference, effect = 119}) and
            mobile.health.current > 0 and
            mp.isSneaking == false and
            mp.invisibility == 0 and
            math.abs(mobile:getViewToActor(mp)) < 90 and 
            tes3.testLineOfSight({reference1 = mobile.reference, reference2 = mp.reference, position1 = mobile.reference.position, position2 = mp.reference.position}) == true and 
            mobile.inCombat == false then
            mobile:startCombat(mp)
            end       
            if mobile ~= tes3.mobilePlayer and mobile.health.normalized < 0.5 then --npc drink health potions when their hp is low
                for _, st in pairs(mobile.object.inventory) do local ob = st.object
                    if ob.objectType == tes3.objectType.alchemy and ob.effects[1].id == 75 then
                        mwscript.equip{reference = mobile.reference, item = ob, count = 1} 
                    end
                end
            end       
            if mobile ~= tes3.mobilePlayer and mobile.magicka.normalized < 0.3 then --npc drink magicka potions when their magicka is low
                for _, st in pairs(mobile.object.inventory) do local ob = st.object
                    if ob.objectType == tes3.objectType.alchemy and ob.effects[1].id == 76 then
                        mwscript.equip{reference = mobile.reference, item = ob, count = 1} 
                    end
                end
            end
            if mobile.inCombat and (mobile.isKnockedOut or mobile.fatigue.current < 0) then --hand to hand fix. characters that are knocked out, have increased stamina regen
                tes3.modStatistic{reference = mobile.reference, name = 'fatigue', current = mobile.endurance.current/10, limitToBase = true}
            end      
        end
        
        for follower in tes3.iterate(tes3.mobilePlayer.friendlyActors) do
            if follower.inCombat == true
                and follower.actionData.aiBehaviorState == -1
                and follower ~= mp
            then follower:stopCombat(true) --use actor:stopCombat(true) if it doesnt work
            end
            if follower.inCombat == false and follower.health.normalized < 0.9 and not tes3.isAffectedBy({reference = follower.reference, effect = 75}) and follower ~= mp then
                for _, s in pairs(follower.object.spells) do --companions use their healing spells when they are out of combat
                    if s.castType == 0 and s.effects[1].id == 75 then
                        if follower.magicka.current >= s.magickaCost then
                            tes3.cast({reference = follower.reference, target = follower.reference, spell = s, alwaysSucceeds = false })
                            follower.magicka.current = follower.magicka.current - s.magickaCost
                        end
                    end
                end
            end
        end
    end}
end
event.register("loaded", LOADED)


local function ONCOMBAT(e)
	local m = e.actor local mr = m.reference
	if m ~= mp then --npc now use demon and devil weapons and fight with cool summoned weapon
		local stack = tes3.getEquippedItem({ actor = m, enchanted = true })
		for _, w in ipairs(enchantedWeapons) do
			if m.object.inventory:contains(w.weapon) then
                m.weaponReady = false
				tes3.applyMagicSource({ reference = m.reference, source = w.enchant, fromStack = stack })
			end
		end
	end
	if m ~= mp then --npc now cast elemental shield and simple shield spells when the fight is started
		for _, s in pairs(m.object.spells) do
			if s.castType == 0 and s.effects[1].id > 2 and s.effects[1].id < 7 and not tes3.isAffectedBy({reference = mr, object = s}) then
				if m.magicka.current >= s.magickaCost then
					tes3.cast({reference = mr, target = mr, spell = s, alwaysSucceeds = false })
					m.magicka.current = m.magicka.current - s.magickaCost
				end
			end
		end
	end
end
event.register("combatStarted", ONCOMBAT)


local function RESIST(e)
    local t = e.target	local m = e.target.mobile local s = e.source	local ef = e.effect local focus
    local eid = ef.id local c local f = 0 local arm = 0
    if m then f = (m.endurance.current + m.willpower.current)/10 arm = m.armorRating and m.armorRating/10 or 0 end
    if s.objectType == tes3.objectType.spell then c = e.caster.mobile focus = math.min(c.magicka.current/25, 60) - 10 end 

    if ef.rangeType ~= 0 then
        if eid==14 then --fire
            e.resistedPercent = m.resistFire - (m.weaknesstoFire or 0) + (arm or 0) - (focus or 0)
            local dmg = math.random(ef.min,ef.max) * (100 - e.resistedPercent)/100
            if m and e.caster and c and not m.isDead and dmg > 0 then
                tes3.applyMagicSource({
                    reference = m.reference,
                    effects = {
                        {
                            id = 14,
                            min = math.ceil(dmg / 5),
                            max = math.ceil(dmg / 5),
                            duration = (3 + ef.duration),
                        }
                    },
                    name = "Secondary fire damage",
                    bypassResistances = true
                })	
            end
        end
        if eid==15 then --shock
            e.resistedPercent = m.resistShock - (m.weaknesstoShock or 0) + (arm or 0) - (focus or 0)	 
        end
        if eid==16 then --frost
            e.resistedPercent = m.resistFrost - (m.weaknesstoFrost or 0) + (arm or 0) - (focus or 0)
            local dmg = math.random(ef.min,ef.max) * (100 - e.resistedPercent)/100
            m.reference.data.slow = dmg * 5				
            -- tes3.messageBox("Slow effect = %.2f", m.reference.data.slow)
            local T = timer.start({
                duration = (2 + ef.duration),
                callback = function()
                    if m then m.reference.data.slow = nil end
                end
            }) 
        end
        if ( eid>=22 and eid<=25 ) then -- damage parameter
            e.resistedPercent = m.resistMagicka - (m.weaknesstoMagicka or 0) - (focus or 0) + f 
        end
        if ( eid>=17 and eid <=21 ) then -- drain parameter
            e.resistedPercent = m.resistMagicka - (m.weaknesstoMagicka or 0) - (focus or 0) + f 
        end
        if eid == 27 then -- poison
            e.resistedPercent = m.resistPoison - (m.weaknesstoPoison or 0) + (arm or 0) - (focus or 0)
        end
        if eid >= 85 and eid <= 89 then e.resistedPercent = m.resistMagicka - (m.weaknesstoMagicka or 0) + f - (focus or 0) end -- absorbtion of hp, magicka, skills, etc

        if (eid == 45 or eid == 46) and s.objectType == tes3.objectType.spell then -- silence, paralysis
            local res = (m.willpower.current + m.endurance.current)/5 - (focus or 0)
            if eid == 45 then
                res = res + m.resistParalysis
            end
            if res > math.random(0,100) then
                e.resistedPercent = 0
            else
                e.resistedPercent = 100
            end
        end
    end
end
event.register("spellResist", RESIST)

local function ATTACK(e) local t = e.targetMobile --dodge costs stamina
    if e.mobile.actionData.physicalDamage == 0 then
        local dodgecost = math.max((200 - t.agility.current)/4,15) * (1 + t.encumbrance.normalized)
        t.fatigue.current = t.fatigue.current - dodgecost    
    end
end
event.register("attack", ATTACK)


local function DAMAGED(e)
	local ef = e.magicEffect local dmg = e.damage local m = e.mobile local r = e.reference 
	if ef and ef.id == 15 then
		local dps = math.abs(dmg) * 2
		local res = m.endurance.current + m.willpower.current/2 + m.luck.current/8
		if dps > math.random(0,res) then
			m:hitStun()
			--tes3.messageBox("Shocked")
		end
		--tes3.messageBox("Shock damage: .%2f, Damage per second: %.2f, delta: %.2f", math.abs(dmg), dps, tes3.worldController.deltaTime)
	end
	if ef and ef.id == 27 then
		m.fatigue.current = m.fatigue.current - math.abs(dmg) * 3
		--tes3.messageBox("Poison damage")
	end
end
event.register("damaged", DAMAGED)


local function CALCMOVESPEED(e)
    local m = e.mobile
    if m.reference.data and m.reference.data.slow then
        e.speed = e.speed - m.reference.data.slow
        if e.speed < 1 then e.speed = 1 end
    end
end
event.register("calcMoveSpeed", CALCMOVESPEED)

local function SPELLMAGICKAUSE(e)
	local c = e.caster.mobile local s = e.spell local skill
	if c and s then
		if c.actorType == 1 or c.actorType == 2 then
			local school = s:getLeastProficientSchool(c)
			if school == 0 then
				skill = c.alteration.current
			elseif school == 1 then
				skill = c.conjuration.current
			elseif school == 2 then
				skill = c.destruction.current
			elseif school == 3 then
				skill = c.illusion.current
			elseif school == 4 then
				skill = c.mysticism.current
			elseif school == 5 then
				skill = c.restoration.current
			else
				skill = 50
			end
			c.animationController.animationData.castSpeed = math.min((c.speed.current + c.intelligence.current + c.willpower.current + mp.luck.current/2 + skill)/250, 1.5)
		end
		if c.actorType == 0 and c.biped then
			c.animationController.animationData.castSpeed = 1 + c.object.level/100
		end
		if s.alwaysSucceeds == true then
			c.animationController.animationData.castSpeed = 1.5
		end
	end
end
event.register("spellMagickaUse",SPELLMAGICKAUSE)

local function PROJECTILEEXPIRE(e)
	if e.firingReference == p then
		if e.mobile and e.mobile.spellInstance then
			local s = e.mobile.spellInstance
			for _, ef in pairs(s.sourceEffects) do
				if e.mobile.position:distance(mp.position) <= ef.radius * 22.1 then
					tes3.applyMagicSource({
						reference = p,
						effects = {
							{
								id = ef.id,
								min = ef.min,
								max = ef.max,
								duration = ef.duration,
							}
						},
						name = "Friendly fire",
					})
				end 
			end
		end
	end
end
event.register("projectileExpire", PROJECTILEEXPIRE)


local function INITIALIZED(e)
    for w in tes3.iterateObjects(tes3.objectType.weapon) do
		if string.find(w.id, "demon") or string.find(w.id, "devil") or string.find(w.id, "fiend") then
			enchantedWeapons[#enchantedWeapons + 1] = {
				weapon = w,
				enchant = w.enchantment
			}
		end
	end
end
event.register("initialized", INITIALIZED)

local function registerModConfig()		local template = mwse.mcm.createTemplate("PandaCHMod")	template:saveOnClose("PandaCHMod", cfg)	template:register()		
	local page = template:createPage()
	--local var = mwse.mcm.createTableVariable
	--local spellOnHit = false
	--page:createYesNoButton{label = "Show messages", variable = mwse.mcm.createTableVariable{id = "msg", table = cfg}}
	--page:createKeyBinder{label = "Toggle class spells on hit", variable = var{id = "ekey", table = cfg}}
end
event.register("modConfigReady", registerModConfig)

