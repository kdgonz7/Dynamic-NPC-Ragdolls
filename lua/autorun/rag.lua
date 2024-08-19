if CLIENT then
	-- add it to spawnmenu

	hook.Add("AddToolMenuCategories", "AddDNR", function ()
		spawnmenu.AddToolCategory("Options", "Dynamic NPC Ragdolls", "#Dynamic NPC Ragdoll")
	end)

	
	hook.Add("PopulateToolMenu", "AddDNR", function ()
		--- 
		--- @param pnl DForm
		spawnmenu.AddToolMenuOption("Options", "Dynamic NPC Ragdolls", "dnr_options", "#Dynamic NPC Ragdolls", "", "", function ( pnl )
			pnl:Clear()

			pnl:CheckBox("Enabled", "dnr_enabled")
			pnl:ControlHelp("Enables or disables the mod.")

			pnl:CheckBox("Disable Pickup with Physics Gun", "dnr_disablepickup")
			pnl:ControlHelp("Disables the picking up of NPCs with the physics gun.")

			pnl:CheckBox("Turn everything into ragdolls", "dnr_mushanything")
			pnl:ControlHelp("If disabled, only the entities you add to the ragdoll list will be converted.")

			pnl:CheckBox("Friendly Fire Enabled", "dnr_friendlyfire")
			pnl:ControlHelp("If disabled, friendly fire will not be prevented.")

			pnl:CheckBox("Do culling + other optimizations", "dnr_optimize")
			pnl:ControlHelp("Disables server-side ragdolls when the player is not looking at them. Recommended to be used in wide, broad, and high-density areas!")
			
			pnl:NumSlider("Ragdoll Mimic Speed", "dnr_hspeed", 0.01, 10, 3)
			pnl:ControlHelp("How fast the ragdoll mimics the host's movement. Faster = MORE REALISTIC")
		end)
	end)
end

local RagdollNPCPairs = {}
local Blacklist       = {
	["npc_headcrab_poison"] = true,
	["npc_headcrab_black"] = true,
	["npc_headcrab"] = true,
	["npc_headcrab_fast"] = true,
}

--! this is useless if MUSH_ANYTHING is enabled lol
local Whitelist       = {
	["npc_combine_s"] = true,
	["npc_poisonzombie"] = true,
	["npc_zombie"] = true,
	["npc_fastzombie"] = true,
}

--[[ Should this system be enabled? defualt = 1 ]]
local Enabled              = CreateConVar("dnr_enabled", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--[[ Disables picking up npcs with the physgun. Good for true realism and also fixes certain glitches and crashes that come with this mod ]]
local DisableTrippyPickup  = CreateConVar("dnr_disablepickup", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--[[ Should anything be turned into a ragdoll? Whatever spawns, as long as it isn't a player will turn into a ragdoll. NOT RECOMMENDED ]]
local MushAnything         = CreateConVar("dnr_mushanything", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--[[ Should friendly-fire be accounted for in damage? ]]
local FriendlyFireEnabled  = CreateConVar("dnr_friendlyfire", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--[[ Should optimizations be made? ]]
local EnableOptimization   = CreateConVar("dnr_optimize", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--[[ How fast should the ragdoll be moving to the position of the host? ]]
local HostSpeed             = CreateConVar("dnr_hspeed", "1", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--[[ ( experimental ) option to do all ragdoll calculations client-side instead, using client side ragdolls ]]
local EnableCSRagdolls     = CreateConVar("dnr_csragdolls", "0", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

local function DNR_CanBeSeen(ent)
	if ! EnableOptimization:GetBool() then return true end

	for _, p in pairs(player.GetHumans()) do
		if (p:Visible(ent)) then return true end
	end

	return false
end


---@param ent Entity
local function DNR_CreateEntityRagdoll(ent)
	if ! IsValid(ent) then return end -- no entity
	if ! Enabled:GetBool() then return end -- enabled is off
	if ! ent:IsNPC() then return end -- the entity is not an NPC

	if ! MushAnything:GetBool() and (! Whitelist[ent:GetClass()] or Blacklist[ent:GetClass()]) then
		return
	end

	-- so this isn't my addon btw
	-- however it's a very simple addon, very cool
	--
	-- all it does is replace the entity with a ragdoll
	-- and mimics all of it's movements
	-- so that it responds to the world around it
	--
	-- ima patch it for personal reasons however i love what the creator has set up

	if true then
		if CLIENT then return end

		timer.Simple(0, function()
			local ragdoll = ents.Create("prop_ragdoll")

			if ! IsValid(ragdoll) then return end

			ent:SetRenderMode(RENDERMODE_NONE)
			ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

			-- copy everything over
			ragdoll:SetModel(ent:GetModel())
			ragdoll:SetPos(ent:GetPos())
			ragdoll:SetAngles(ent:GetAngles())
			ragdoll:SetSkin(ent:GetSkin())
			ragdoll:Spawn()
			ragdoll:Activate()
			ragdoll:DrawShadow(false)
			ragdoll:SetCollisionGroup(COLLISION_GROUP_WORLD)
			ragdoll:GetPhysicsObject():EnableCollisions(false)
			--! try to put attachments too

			-- add this entity to the ragdoll npc pairs
			RagdollNPCPairs[ent] = ragdoll

			-- this probably means there is a mismatch, therefore this entity is not a humanoid-esque figure
			-- or a figure that works ig (???)
			-- (this was in the original, i didn't write this)
			if ragdoll:GetBoneCount() ~= ent:GetBoneCount() then ragdoll:Remove() end
		end)
	else
		if SERVER then return end

		local __ragdoll = ClientsideRagdoll(ent:GetModel())
		if ! IsValid(__ragdoll) then return end

		__ragdoll:SetModel(ent:GetModel())
		__ragdoll:SetPos(ent:GetPos())
		__ragdoll:SetAngles(ent:GetAngles())
		__ragdoll:SetSkin(ent:GetSkin())
		__ragdoll:Spawn()
		__ragdoll:Activate()
		__ragdoll:DrawShadow(false)
		__ragdoll:SetCollisionGroup(COLLISION_GROUP_WORLD)
		__ragdoll:GetPhysicsObject():EnableCollisions(false)
		__ragdoll:SetNoDraw( false )

		RagdollNPCPairs[ent] = __ragdoll
	end
end

concommand.Add("dnr_addtoraglist", function (ply, args, cmd)
	if ! args[1] then return end
	Whitelist[string.Trim(args[1])] = true
end)

hook.Add("CreateEntityRagdoll", "RemoveRagdollsByEntities", function (ent, rag)
	if ! Enabled:GetBool() then return end
	if ! ent:IsNPC() then return end
	if ! MushAnything:GetBool() and (! Whitelist[ent:GetClass()] or Blacklist[ent:GetClass()]) then
		return
	end

	rag:Remove()

	-- End of CreateEntityRagdoll ( 'RemoveRagdollsByEntities' )
end)

---@param npc Entity
hook.Add("OnNPCKilled","RemoveRagdoll",function(npc,attacker,inflictor)
	if ! Enabled:GetBool() then return end
	if ! npc:IsNPC() then return end
	if ! MushAnything:GetBool() and (! Whitelist[npc:GetClass()] or Blacklist[npc:GetClass()]) then
		return
	end

	local er = RagdollNPCPairs[npc]
	if ! IsValid(er) then return end

	npc:Remove()

	-- End of OnNPCKilled ( 'RemoveRagdoll' )
end)

hook.Add("Tick", "RagdollMimicing-Master",function()
	if ! Enabled:GetBool() then return end

	local j = 0

	for ent, ragdoll in pairs(RagdollNPCPairs) do
		-- ? if there's no entity or ragdoll, remove this entry
		-- ? sorta a cleanup
		if ! IsValid(ent) then
			table.remove(RagdollNPCPairs, j)
			continue
		end

		if ! DNR_CanBeSeen(ent) then
			ragdoll:GetPhysicsObject():Sleep()
			ragdoll:SetRenderMode(RENDERMODE_NONE)
			ent:SetRenderMode(RENDERMODE_NORMAL)

			ragdoll:SetPos(ent:GetPos())
			continue
		else
			ragdoll:GetPhysicsObject():Wake()
			ragdoll:SetRenderMode(RENDERMODE_NORMAL)
			ent:SetRenderMode(RENDERMODE_NONE)
		end

		-- ! ONLY WANT THIS FOR NPCs
		-- ! we also wanna ensure that we don't just mush anything
		if ! ent:IsNPC() then continue end
		if ! MushAnything:GetBool() and ! Whitelist[ent:GetClass()] then continue end

		-- we want the bone count of the ragdoll
		local r_BoneCount = ragdoll:GetBoneCount()

		-- for each bone we attempt to mimic the host
		-- that's literally it
		for i = 0, r_BoneCount - 1 do
			-- get the bone name and entity
			local b_BoneName   = ragdoll:GetBoneName(i)
			local b_BoneEntity = ent:LookupBone(b_BoneName)

			if ! b_BoneEntity then continue end

			-- we also want the bone angles
			local c_BonePosition, c_BoneAngle = ent:GetBonePosition(ent:TranslatePhysBoneToBone(i))
			local b_NPCBoneAsRagdoll = ragdoll:LookupBone(b_BoneName)

			-- if we now have the bone as a ragdoll
			if b_NPCBoneAsRagdoll then
				-- we can get it's physics object and move it to the specified position
				-- of the host?
				-- ya sure
				local p_RagdollPhysicsObject = ragdoll:GetPhysicsObjectNum(b_NPCBoneAsRagdoll)
				if ! IsValid(p_RagdollPhysicsObject) then continue end

				-- encapsulate body part information
				---@class ShadowControlParams
				local p_Information = {}
				local p_HSpeed = HostSpeed:GetFloat()
				
				p_Information.secondstoarrive = p_HSpeed           -- as fast as i could get it, sorry
				p_Information.pos = c_BonePosition                 -- the bone pos
				p_Information.angle = c_BoneAngle                  -- the bone rotation
				p_Information.maxangular = 650                     -- some random ass damping values
				p_Information.maxangulardamp = 500                 -- angular daming too
				p_Information.maxspeed = 405                       -- max speed
				p_Information.maxspeeddamp = 405                   -- max speed: electric boogaloo
				p_Information.teleportdistance = 0                 -- idk what this does

				p_RagdollPhysicsObject:Wake()                                 -- wake it
				p_RagdollPhysicsObject:ComputeShadowControl(p_Information)    -- begin the matrix simulation
			end
		end

		-- increment pointer, we're onto the next entry
		j = j + 1
	end

	-- End of Tick ( 'RagdollMimicing-Master' )
end)

-- a hook to create the ragdoll when an entity is brought into this world
---@param ent Entity
hook.Add("OnEntityCreated","CreateRagdoll",function(ent)
	if ! ent:IsNPC() then return end                    -- anything else don't do rags for
	if ent:IsPlayer() then return end                   -- don't create ent rags for players
	if ent:GetClass() == "prop_ragdoll" then return end -- don't create ent rags for existing rags
	if ent:GetClass() == "rd_target" then return end    -- don't create ent rags for reagdoll's puppet
	if ! MushAnything:GetBool() and (! Whitelist[ent:GetClass()] or Blacklist[ent:GetClass()]) then
		return
	end

	timer.Simple(0.2, function()
		if IsValid(ent) then DNR_CreateEntityRagdoll(ent) end
	end)

	-- End of OnEntityCreated ( 'CreateRagdoll' )
end)

-- since the ragdoll is the one taking damage, we
-- transfer it to the NPC
---@param target Entity
---@param dmginfo CTakeDamageInfo
hook.Add("EntityTakeDamage", "TransferRagdollDamageToNPC", function(target, dmginfo)
	if ! Enabled:GetBool() then return end
	if ! target:IsNPC() then return end
	if ! MushAnything:GetBool() and (! Whitelist[target:GetClass()] or Blacklist[target:GetClass()]) then
		return
	end

	if RagdollNPCPairs[target] then
		local npc = RagdollNPCPairs[target]
		local attacker = dmginfo:GetAttacker()

		if ! IsValid(npc) then return end
		if ! IsValid(attacker) then return end
		if attacker == npc then return end
		if attacker:GetClass() == "prop_ragdoll" then return end

		-- prevent friendly fire
		if FriendlyFireEnabled:GetBool() and attacker:IsNPC() and npc:IsNPC() then
			local disposition = npc:Disposition(attacker)

			if disposition == D_LI || disposition == D_FR then
				return
			end
		end

		npc:TakeDamageInfo(dmginfo)
	end

	-- End of EntityTakeDamage ( 'TransferRagdollDamageToNPC' )
end)

-- self explanatory
hook.Add("PhysgunPickup", "PreventPickupIfWanted", function(_, ent)
	if ! DisableTrippyPickup:GetBool() then return true end
	if RagdollNPCPairs[ent] then return false end
	return true

	-- End of PhysgunPickup ( 'PreventPickupIfWanted' )
end)
