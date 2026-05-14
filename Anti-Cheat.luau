-- ============================================================================
-- pirate_pro00's anti cheat (ROBLOX NATIVE ULTRA-MONOLITHIC SPECIFICATION)
-- INTEGRATED SYSTEMS: PHYSICS REPLICATION, SECURE COMBAT VECTOR CHANNELS,
-- STAFF ALERTS, LIVE CHAT MANAGEMENT (?ban, ?unban, & ?kick), & MANUAL BLOCKLIST
-- ============================================================================

local pirate_pro00s_anti_cheat = {
	_VERSION = "18.0.0-PRO_MAX_KICK",
	_CORES = { "PHYSICS", "NETWORK", "COMBAT", "ENVIRONMENT", "ENFORCEMENT", "ADMIN", "NOTIFICATION" },
	Sessions = {},
	BlacklistCache = {},
	ReplicationQueue = {}
}

-- CONFIGURATION MANIFEST
local KERNEL_MANIFEST = {
	-- 👥 SECURITY PRIVILEGES (ADMIN & BYPASS ARCHITECTURE)
	ADMIN_ROSTER = {
	 = true, -- ⚠️ REPLACE WITH YOUR ADMIN USERID
	 = true, -- ⚠️ REPLACE WITH CO-DEVELOPER USERID
	},
	
	-- 🚫 HARD-CODED BANNED PLAYER LIST (MANUAL HARD BLOCKLIST)
	MANUAL_BAN_LIST = {
	 = "Publicly Known Exploiter", -- ⚠️ ADD ID AND REASON
	 = "Alternative Account Injection",
	},
	
	UNBAN_PREFIX = "?unban", -- Command format: ?unban 12345678
	BAN_PREFIX = "?ban",     -- Command format: ?ban 12345678
	KICK_PREFIX = "?kick",   -- Command format: ?kick 12345678
	
	HEARTBEAT = {
		CORE_TICK = 0.05,        -- Sampling frequency (20Hz resolution)
		TELEMETRY_WINDOW = 1.0,  
		MAX_PING_LATENCY = 0.65  
	},
	PHYSICS_VECTOR = {
		BASE_WALKSPEED = 16.0,
		MAX_SPRINT_ALLOWANCE = 28.0,
		MAX_VELOCITY_SQR = 7225, -- 85^2 optimized scalar for magnitude checks
		MAX_JUMP_VELOCITY = 55.0,
		GRAVITY_CONSTANT = 196.2,
		MAX_VERTICAL_DEVIATION = 4.5,
		FLIGHT_STRIKE_TIME = 2.2, -- Max time allowed airborne without ground trace
		NOCLIP_RAY_SAMPLES = 6,
		MAX_WALL_DEPTH = 0.15     -- Penetration allowance in studs
	},
	NETWORK_IO = {
		MAX_PACKETS_PER_SEC = 45,  
		TOKEN_ROTATION_RATE = 10,  
		MAX_BAD_SIGNATURES = 2
	},
	COMBAT_MATRIX = {
		ABSOLUTE_MIN_ROF = 0.03,   -- Cap preventing rapid fire injection exploits
		MAX_HITBOX_RADIUS = 3.5,   -- Max allowed character size expansion in studs
		SNAP_DEGREE_LIMIT = 65.0,  -- Max raw angular rotation allowed per tick
		AIMBOT_COEF_CEILING = 4.5  
	},
	METRICS = {
		BAN_CEILING = 150,
		SEVERE_VIOLATION = 50,
		MODERATE_VIOLATION = 20,
		MINOR_VIOLATION = 5,
		CLEAN_DECAY_RATE = 5,     
		DECAY_INTERVAL = 30
	},
	STRINGS = {
		BAN_HASH = "P_PRO_ERR_0x%08X",
		LOCK_REASON = "\n[pirate_pro00's anti cheat]\nHardware Integrity Fault: Desynchronized Memory State.\nError Reference: %s"
	}
}

-- SYSTEM FRAMEWORK ATTACHMENTS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")

local SafeDataStore = pcall(function() return DataStoreService:GetDataStore("pirate_pro00_Secure_Vault") end)

-- ============================================================================
-- CORE UTILITIES & SYSTEM LOGIC
-- ============================================================================

local function IsAdmin(player)
	return KERNEL_MANIFEST.ADMIN_ROSTER[player.UserId] == true
end

local function IsManuallyBanned(player)
	return KERNEL_MANIFEST.MANUAL_BAN_LIST[player.UserId] ~= nil
end

local function GenerateSecureHash(salt)
	local characters = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
	local length = 24
	local result = ""
	math.randomseed(os.time() + salt)
	for i = 1, length do
		local randIndex = math.random(1, #characters)
		result = result .. string.sub(characters, randIndex, randIndex)
	end
	return result
end

local function CalculateRollingAverage(dataBuffer)
	if #dataBuffer == 0 then return 0 end
	local total = 0
	for _, val in ipairs(dataBuffer) do total = total + val end
	return total / #dataBuffer
end

local function TraceRayToGround(position, character)
	local rayDirection = Vector3.new(0, -15, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character, Workspace.CurrentCamera}
	
	local result = Workspace:Raycast(position, rayDirection, raycastParams)
	return result ~= nil, result and result.Position
end

-- ============================================================================
-- SUBSYSTEM: PRIVATE NOTIFICATION SYSTEM (STAFF DISPATCH BROADCASTER)
-- ============================================================================

function pirate_pro00s_anti_cheat:BroadcastStaffAlert(alertMessage)
	for _, onlinePlayer in ipairs(Players:GetPlayers()) do
		if IsAdmin(onlinePlayer) then
			task.spawn(function()
				pcall(function()
					if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
						local generalChannel = TextChatService:FindFirstChild("RBXGeneral", true)
						if generalChannel then
							generalChannel:DisplaySystemMessage(alertMessage)
						end
					else
						local starterGui = game:GetService("StarterGui")
						starterGui:SetCore("ChatMakeSystemMessage", {
							Text = alertMessage,
							Color = Color3.fromRGB(255, 65, 65),
							Font = Enum.Font.SourceSansBold,
							FontSize = Enum.FontSize.Size18
						})
					end
				end)
			end)
		end
	end
end

-- ============================================================================
-- SUBSYSTEM: IN-GAME CHAT COMMAND PROCESSING ENGINE
-- ============================================================================

function pirate_pro00s_anti_cheat:ProcessChatCommand(adminPlayer, rawMessage)
	if not IsAdmin(adminPlayer) then return end
	
	local lowerMessage = string.lower(rawMessage)
	local unbanPrefix = KERNEL_MANIFEST.UNBAN_PREFIX
	local banPrefix = KERNEL_MANIFEST.BAN_PREFIX
	local kickPrefix = KERNEL_MANIFEST.KICK_PREFIX
	
	-- Extract UserID targeting parameter
	local targetIdString = string.match(rawMessage, "%d+")
	if not targetIdString and (string.sub(lowerMessage, 1, #unbanPrefix) == unbanPrefix or string.sub(lowerMessage, 1, #banPrefix) == banPrefix or string.sub(lowerMessage, 1, #kickPrefix) == kickPrefix) then
		self:BroadcastStaffAlert("⚠️ [SYSTEM] Missing target UserID. Format: ?command 12345678")
		return
	end
	
	local targetUserId = tonumber(targetIdString)
	
	-- 1. PROCESSING "?unban [UserId]" COMMAND
	if string.sub(lowerMessage, 1, #unbanPrefix) == unbanPrefix then
		self.BlacklistCache[targetUserId] = nil
		task.spawn(function()
			local success, DataStore = pcall(function() return DataStoreService:GetDataStore("pirate_pro00_Secure_Vault") end)
			if success and DataStore then
				local cleanSuccess, _ = pcall(function() DataStore:RemoveAsync("BAN_" .. targetUserId) end)
				if cleanSuccess then
					self:BroadcastStaffAlert(string.format("✅ [ADMIN COMMAND] Admin %s unbanned UserId: %d.", adminPlayer.Name, targetUserId))
				else
					self:BroadcastStaffAlert(string.format("❌ [SYSTEM ERROR] DataStore failure removing ID: %d.", targetUserId))
				end
			end
		end)
		
	-- 2. PROCESSING "?ban [UserId]" COMMAND
	elseif string.sub(lowerMessage, 1, #banPrefix) == banPrefix then
		self.BlacklistCache[targetUserId] = true
		local liveTargetPlayer = Players:GetPlayerByUserId(targetUserId)
		if liveTargetPlayer then
			if IsAdmin(liveTargetPlayer) then
				self:BroadcastStaffAlert("❌ [COMMAND ABORTED] You cannot ban another whitelisted administrator.")
				return
			end
			task.spawn(function() liveTargetPlayer:Kick(string.format(KERNEL_MANIFEST.STRINGS.LOCK_REASON, "ADMIN_COMMAND_TERMINATION")) end)
		end
		
		task.spawn(function()
			local success, DataStore = pcall(function() return DataStoreService:GetDataStore("pirate_pro00_Secure_Vault") end)
			if success and DataStore then
				local writeSuccess, _ = pcall(function()
					DataStore:SetAsync("BAN_" .. targetUserId, {
						TargetUser = liveTargetPlayer and liveTargetPlayer.Name or "Offline Target",
						UnixStamp = os.time(),
						KernelCode = "MANUAL_ADMIN_COMMAND"
					})
				end)
				if writeSuccess then
					self:BroadcastStaffAlert(string.format("🚫 [ADMIN COMMAND] Admin %s successfully hard-banned UserId: %d.", adminPlayer.Name, targetUserId))
				end
			end
		end)

	-- 3. PROCESSING "?kick [UserId]" COMMAND
	elseif string.sub(lowerMessage, 1, #kickPrefix) == kickPrefix then
		local liveTargetPlayer = Players:GetPlayerByUserId(targetUserId)
		if liveTargetPlayer then
			if IsAdmin(liveTargetPlayer) then
				self:BroadcastStaffAlert("❌ [COMMAND ABORTED] You cannot kick another whitelisted administrator.")
				return
			end
			task.spawn(function()
				liveTargetPlayer:Kick("\n[pirate_pro00's anti cheat]\nYou have been removed from the server by an administrator.")
			end)
			self:BroadcastStaffAlert(string.format("🥾 [ADMIN COMMAND] Admin %s successfully kicked %s (%d) from the server.", adminPlayer.Name, liveTargetPlayer.Name, targetUserId))
		else
			self:BroadcastStaffAlert(string.format("❌ [COMMAND FAILED] Player with UserId %d is not online in this server room.", targetUserId))
		end
	end
end

-- ============================================================================
-- SUBSYSTEM: PLAYER SESSION REGISTRATION
-- ============================================================================

function pirate_pro00s_anti_cheat:Boot()
	print("🚀 [BOOTING] Initializing Massive Multi-Threaded pirate_pro00's anti cheat Core...")
	
	Players.PlayerAdded:Connect(function(player) self:RegisterSession(player) end)
	Players.PlayerRemoving:Connect(function(player) self:PurgeSession(player) end)
	
	task.spawn(function() self:CoreExecutionLoop_Physics() end)
	task.spawn(function() self:CoreExecutionLoop_Network() end)
	task.spawn(function() self:CoreExecutionLoop_MetricsDecay() end)
	
	print("👑 [SYSTEM ONLINE] pirate_pro00's anti cheat operating across secure local channels.")
end

function pirate_pro00s_anti_cheat:RegisterSession(player)
	player.Chatted:Connect(function(message)
		self:ProcessChatCommand(player, message)
	end)

	if IsAdmin(player) then
		print(string.format("🎟️ [ADMIN BYPASS] Whitelisted user %s verified. Bypassing monitors.", player.Name))
		return
	end

	if IsManuallyBanned(player) then
		local manualReason = KERNEL_MANIFEST.MANUAL_BAN_LIST[player.UserId]
		player:Kick(string.format(KERNEL_MANIFEST.STRINGS.LOCK_REASON, "MANUAL_BLOCK_LIST: " .. manualReason))
		return
	end

	if self.BlacklistCache[player.UserId] then
		player:Kick(string.format(KERNEL_MANIFEST.STRINGS.LOCK_REASON, "P_PRO_BLACKLIST_LOCAL"))
		return
	end

	-- Check Cloud DataStore Database on Join
	task.spawn(function()
		pcall(function()
			local DataStore = DataStoreService:GetDataStore("pirate_pro00_Secure_Vault")
			if DataStore then
				local cloudBanRecord = DataStore:GetAsync("BAN_" .. player.UserId)
				if cloudBanRecord then
					self.BlacklistCache[player.UserId] = true
					player:Kick(string.format(KERNEL_MANIFEST.STRINGS.LOCK_REASON, "DATASTORE_RECORD_FOUND"))
				end
			end
		end)
	end)

	self.Sessions[player.UserId] = {
		Instance = player,
		ViolationScore = 0,
		LastActiveTimestamp = os.clock(),
		CryptoSignature = GenerateSecureHash(player.UserId),
		SignatureStrikes = 0,
		
		PhysicsCore = {
			PositionHistory = {},
			CFrameHistory = {},
			LastVerifiedCFrame = nil,
			AirborneTimer = 0,
			VelocityBuffer = {},
			GroundTraceFailures = 0,
			NoclipBreachPoints = 0,
			LastPhysicsTick = os.clock()
		},
		NetworkCore = {
			RequestRates = {},
			PacketWindowCount = 0,
			LastTokenRotation = os.clock(),
			PingBuffer = {},
			TimeDeltaDrift = 0
		},
		CombatCore = {
			FiringCooldown = 0,
			LastTargetInstance = nil,
			ContinuousLockTicks = 0,
			AngleHistory = {},
			DamageReplicationDelta = 0
		}
	}
	
	player.CharacterAdded:Connect(function(character)
		self:InitializeCharacterNodes(player, character)
	end)
end

function pirate_pro00s_anti_cheat:InitializeCharacterNodes(player, character)
	local session = self.Sessions[player.UserId]
	if not session then return end
	
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	
	if rootPart and humanoid then
		session.PhysicsCore.LastVerifiedCFrame = rootPart.CFrame
		table.insert(session.PhysicsCore.PositionHistory, rootPart.Position)
		table.insert(session.PhysicsCore.CFrameHistory, rootPart.CFrame)
		
		humanoid.StateChanged:Connect(function(_, newState)
			session.PhysicsCore.LastState = newState
		end)
	end
end

function pirate_pro00s_anti_cheat:PurgeSession(player)
	if self.Sessions[player.UserId] then
		self.Sessions[player.UserId] = nil
	end
end

-- ============================================================================
-- PARALLEL PHYSICS HEURISTICS ENGINE (SPEED / FLY / NOCLIP)
-- ============================================================================

function pirate_pro00s_anti_cheat:ProcessPhysicsValidation(player, character)
	local session = self.Sessions[player.UserId]
	if not session or not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end
	
	local currentPos = rootPart.Position
	local currentCF = rootPart.CFrame
	local now = os.clock()
	local dt = now - session.PhysicsCore.LastPhysicsTick
	
	if dt <= 0 or dt > 1.5 then return end
	
	local history = session.PhysicsCore.PositionHistory
	local cfHistory = session.PhysicsCore.CFrameHistory
	local lastPos = history[#history]
	
	if lastPos then
		local displacement = currentPos - lastPos
		local flatDistance = Vector3.new(displacement.X, 0, displacement.Z).Magnitude
		local verticalDistance = displacement.Y
		
		local currentVelocitySqr = rootPart.AssemblyLinearVelocity.SquareMagnitude
		if currentVelocitySqr > KERNEL_MANIFEST.PHYSICS_VECTOR.MAX_VELOCITY_SQR then
			self:TriggerAlert(player, "Explosive Physics Impulse Injection", KERNEL_MANIFEST.METRICS.MODERATE_VIOLATION, true)
		end
		
		local allowedSpeed = KERNEL_MANIFEST.PHYSICS_VECTOR.BASE_WALKSPEED
		if humanoid.MoveDirection.Magnitude > 0 and session.PhysicsCore.LastState == Enum.HumanoidStateType.Running then
			allowedSpeed = KERNEL_MANIFEST.PHYSICS_VECTOR.MAX_SPRINT_ALLOWANCE
		end
		
		local maxAllowedDistance = (allowedSpeed * dt) + 4.0
		if flatDistance > maxAllowedDistance and flatDistance < 100 then
			self:TriggerAlert(player, "Horizontal Telemetry Discrepancy (SpeedHack)", KERNEL_MANIFEST.METRICS.MINOR_VIOLATION, true)
		elseif flatDistance >= 100 then
			self:TriggerAlert(player, "Coordinate Space Displacement Macro (Teleport)", KERNEL_MANIFEST.METRICS.SEVERE_VIOLATION, true)
		end
		
		local isGrounded, groundPoint = TraceRayToGround(currentPos, character)
		if not isGrounded and (session.PhysicsCore.LastState == Enum.HumanoidStateType.Freefall or session.PhysicsCore.LastState == Enum.HumanoidStateType.Jumping) then
			session.PhysicsCore.AirborneTimer = session.PhysicsCore.AirborneTimer + dt
			if session.PhysicsCore.AirborneTimer > KERNEL_MANIFEST.PHYSICS_VECTOR.FLIGHT_STRIKE_TIME and verticalDistance >= -1.0 then
				self:TriggerAlert(player, "Asynchronous Anti-Gravity Levitation (FlyHack)", KERNEL_MANIFEST.METRICS.MODERATE_VIOLATION, true)
			end
		else
			session.PhysicsCore.AirborneTimer = 0
		end
		
		if flatDistance > 0.05 then
			local rayDirection = currentPos - lastPos
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = {character, Workspace.CurrentCamera}
			
			local wallCheck = Workspace:Raycast(lastPos, rayDirection, raycastParams)
			if wallCheck and wallCheck.Instance and wallCheck.Instance.CanCollide then
				local wallDepth = (wallCheck.Position - currentPos).Magnitude
				if wallDepth > KERNEL_MANIFEST.PHYSICS_VECTOR.MAX_WALL_DEPTH then
					session.PhysicsCore.NoclipBreachPoints = session.PhysicsCore.NoclipBreachPoints + 1
					if session.PhysicsCore.NoclipBreachPoints >= 3 then
						self:TriggerAlert(player, "Spatial Geometry Phase Interruption (Noclip)", KERNEL_MANIFEST.METRICS.MODERATE_VIOLATION, true)
					end
				end
			else
				session.PhysicsCore.NoclipBreachPoints = math.max(0, session.PhysicsCore.NoclipBreachPoints - 0.05)
			end
		end
	end
	
	table.insert(history, currentPos)
	table.insert(cfHistory, currentCF)
	if #history > 10 then table.remove(history, 1) table.remove(cfHistory, 1) end
	
	session.PhysicsCore.LastPhysicsTick = now
	if session.ViolationScore < KERNEL_MANIFEST.METRICS.BAN_CEILING / 2 then
		session.PhysicsCore.LastVerifiedCFrame = currentCF
	end
end

-- ============================================================================
-- STRUCTURAL COMBAT & VALIDATION MODULES
-- ============================================================================

function pirate_pro00s_anti_cheat:ValidateCombatTransaction(player, origin, hitPosition, targetPart, claimedSignature)
	if IsAdmin(player) then return true end
	
	local session = self.Sessions[player.UserId]
	if not session then return false end
	
	if claimedSignature ~= session.CryptoSignature then
		session.SignatureStrikes = session.SignatureStrikes + 1
		self:TriggerAlert(player, "Network Token Forgery/Decoupled Injection", KERNEL_MANIFEST.METRICS.SEVERE_VIOLATION, false)
		if session.SignatureStrikes >= KERNEL_MANIFEST.NETWORK_IO.MAX_BAD_SIGNATURES then
			self:EnforceTermination(player, "0xCRITICAL_NET_SIGN_FAIL")
		end
		return false
	end
	
	local now = os.clock()
	local rOfDelta = now - session.CombatCore.FiringCooldown
	if rOfDelta < KERNEL_MANIFEST.COMBAT_MATRIX.ABSOLUTE_MIN_ROF then
		self:TriggerAlert(player, "Weapon Fire Rate Frequency Overrun (RapidFire)", KERNEL_MANIFEST.METRICS.MODERATE_VIOLATION, false)
		return false
	end
	
	if targetPart and targetPart:IsA("BasePart") then
		local calculatedBoundingSize = targetPart.Size.Magnitude / 2
		if calculatedBoundingSize > KERNEL_MANIFEST.COMBAT_MATRIX.MAX_HITBOX_RADIUS then
			self:TriggerAlert(player, "Simulated Part Dimension Discrepancy (Hitbox Expander)", KERNEL_MANIFEST.METRICS.MODERATE_VIOLATION, false)
			return false
		end
	end
	
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local look = character.HumanoidRootPart.CFrame.LookVector
		local directionalTarget = (hitPosition - origin).Unit
		local angleDifference = math.deg(math.acos(math.clamp(look:Dot(directionalTarget), -1, 1)))
		
		table.insert(session.CombatCore.AngleHistory, angleDifference)
		if #session.CombatCore.AngleHistory > 5 then table.remove(session.CombatCore.AngleHistory, 1) end
		
		local averageAngularDeviation = CalculateRollingAverage(session.CombatCore.AngleHistory)
		if angleDifference > KERNEL_MANIFEST.COMBAT_MATRIX.SNAP_DEGREE_LIMIT and averageAngularDeviation > 45 then
			self:TriggerAlert(player, "Kinematic Constraint Rotation Instability (Aimbot)", KERNEL_MANIFEST.METRICS.MINOR_VIOLATION, false)
		end
	end
	
	session.CombatCore.FiringCooldown = now
	return true
end

function pirate_pro00s_anti_cheat:InterceptRemoteInvocation(player, remoteInstance)
	if IsAdmin(player) then return true end
	
	local session = self.Sessions[player.UserId]
	if not session then return false end
	
	local now = os.clock()
	local rName = remoteInstance.Name
	
	if not session.NetworkCore.RequestRates[rName] then
		session.NetworkCore.RequestRates[rName] = { TotalCalls = 0, LastReset = now }
	end
	
	local track = session.NetworkCore.RequestRates[rName]
	if now - track.LastReset > 1.0 then
		track.TotalCalls = 1
		track.LastReset = now
	else
		track.TotalCalls = track.TotalCalls + 1
		if track.TotalCalls > KERNEL_MANIFEST.NETWORK_IO.MAX_PACKETS_PER_SEC then
			self:TriggerAlert(player, "Remote Pipeline Replication Flooding Attack", KERNEL_MANIFEST.METRICS.MODERATE_VIOLATION, false)
			return false
		end
	end
	
	return true
end

-- ============================================================================
-- ENFORCEMENT & HARD TERMINATION SYSTEMS
-- ============================================================================

function pirate_pro00s_anti_cheat:TriggerAlert(player, alertReason, violationWeight, triggerRubberband)
	local session = self.Sessions[player.UserId]
	if not session then return end
	
	session.ViolationScore = session.ViolationScore + violationWeight
	
	local privateAlertText = string.format("🚨 [p_pro Alert] Player %s triggered %s. Threat Level: %d/%d", 
		player.Name, alertReason, session.ViolationScore, KERNEL_MANIFEST.METRICS.BAN_CEILING)
	self:BroadcastStaffAlert(privateAlertText)
		
	if triggerRubberband and session.PhysicsCore.LastVerifiedCFrame then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = session.PhysicsCore.LastVerifiedCFrame
			rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
			rootPart.AssemblyAngularVelocity = Vector3.new(0,0,0)
		end
	end
	
	if session.ViolationScore >= KERNEL_MANIFEST.METRICS.BAN_CEILING then
		self:EnforceTermination(player, string.format(KERNEL_MANIFEST.STRINGS.BAN_HASH, os.time() % 100000))
	end
end

function pirate_pro00s_anti_cheat:EnforceTermination(player, reasonCode)
	local uId = player.UserId
	local uName = player.Name
	self.BlacklistCache[uId] = true
	
	local terminationBroadcast = string.format("🚫 [CRITICAL ENFORCEMENT] Player %s has been permanently disconnected from the cluster. Code: %s", uName, reasonCode)
	self:BroadcastStaffAlert(terminationBroadcast)
	
	task.spawn(function()
		pcall(function()
			local DataStore = DataStoreService:GetDataStore("pirate_pro00_Secure_Vault")
			if DataStore then
				DataStore:SetAsync("BAN_" .. uId, {
					TargetUser = uName,
					UnixStamp = os.time(),
					KernelCode = reasonCode
				})
			end
		end)
	end)
	
	player:Kick(string.format(KERNEL_MANIFEST.STRINGS.LOCK_REASON, reasonCode))
end

-- ============================================================================
-- BACKGROUND EXECUTION LOOPS
-- ============================================================================

function pirate_pro00s_anti_cheat:CoreExecutionLoop_Physics()
	while true do
		task.wait(KERNEL_MANIFEST.HEARTBEAT.CORE_TICK)
		for _, player in ipairs(Players:GetPlayers()) do
			if not IsAdmin(player) then
				local character = player.Character
				if character and self.Sessions[player.UserId] then
					pcall(function()
						self:ProcessPhysicsValidation(player, character)
					end)
				end
			end
		end
	end
end

function pirate_pro00s_anti_cheat:CoreExecutionLoop_Network()
	while true do
		task.wait(KERNEL_MANIFEST.NETWORK_IO.TOKEN_ROTATION_RATE)
		for _, player in ipairs(Players:GetPlayers()) do
			if not IsAdmin(player) then
				local session = self.Sessions[player.UserId]
				if session then
					session.CryptoSignature = GenerateSecureHash(player.UserId)
				end
			end
		end
	end
end

function pirate_pro00s_anti_cheat:CoreExecutionLoop_MetricsDecay()
	while true do
		task.wait(KERNEL_MANIFEST.METRICS.DECAY_INTERVAL)
		for _, session in pairs(self.Sessions) do
			if session.ViolationScore > 0 then
				session.ViolationScore = math.max(0, session.ViolationScore - KERNEL_MANIFEST.METRICS.CLEAN_DECAY_RATE)
			end
		end
	end
end

-- Start Framework Matrix
pirate_pro00s_anti_cheat:Boot()

return pirate_pro00s_anti_cheat
