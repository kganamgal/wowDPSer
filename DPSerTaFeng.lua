------------------------------------------------------------
-- DPSerTaFeng.lua
-- Edwin
------------------------------------------------------------
local Cnt
local updateElapsed = 0                                                            -- 将计时器归零

local displayFrame = CreateFrame("Button", "TaFeng", UIParent)                  		   -- 定义一个框体frame
do
	displayFrame:SetWidth(16)                                                                 -- 定义frame的宽
	displayFrame:SetHeight(16)                                                                -- 定义frame的高
	displayFrame:SetPoint("CENTER", 0, 120)                                                   -- 定义frame的中心位置
	displayFrame:SetMovable(true)                                                             -- 将frame设为可移动
	displayFrame:SetUserPlaced(true)                                                          -- 将frame设为可自定义位置
	displayFrame:SetClampedToScreen(true)                                                     -- 允许将该frame拖出屏幕(or not?)
	displayFrame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")       -- 设置frame的纹理
	displayFrame:SetBackdropBorderColor(100, 100, 100)
	displayFrame.icon = displayFrame:CreateTexture(displayFrame:GetName().."Icon", "ARTWORK")               -- 设置frame的图标
	displayFrame.icon:SetAllPoints(displayFrame)
	displayFrame.icon:SetTexture("Interface\\Icons\\Ability_Druid_SkinTeeth")
	displayFrame.text = displayFrame:CreateFontString(displayFrame:GetName().."Text", "ARTWORK", "GameFontHighlightLeft") 	-- 为frame创建一个新的Fontstring目标
	displayFrame.text:SetPoint("LEFT", displayFrame, "RIGHT", 2, 0)
	displayFrame.text:SetFont(STANDARD_TEXT_FONT, 30)
	displayFrame:RegisterForDrag("LeftButton")                                                -- 左键可拖动该frame的位置
	displayFrame:SetScript("OnDragStart", displayFrame.StartMoving)
	displayFrame:SetScript("OnDragStop", displayFrame.StopMovingOrSizing)
	displayFrame:SetScript("OnUpdate", main)
	displayFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")                       		   -- 设定该frame关注的事件：战斗信息
	displayFrame:RegisterEvent("CHAT_MSG_WHISPER")											   -- 设定该frame关注的事件：聊天记录
	displayFrame:SetScript("OnEvent", checkEvents)
end

-- ----------------------------------声明----------------------------------
local count_SHYXT = 0		-- 神鹤印记层数
local Index_Strategy = 1	-- 默认策略
local sighedSHYXT = {}		-- 被标记了神鹤引项踢Debuff的怪物列表
local spellSpend = {}		-- 技能消耗
local spellInsert = {		-- InsertSpell 插队技能
	碧玉疾风			= false,
	神鹤引项踢			= false,
	扫堂腿				= false,
}
local tsid = {				-- TableSpell 技能id字典
	旭日东升踢 			= 107428,
	猛虎掌 				= 100780,
	幻灭踢 				= 100784,
	幻灭踢!				= 116768,
	神鹤引项踢 			= 101546,
	神鹤印记 			= 228287,
	风领主之击 			= 205320,
	怒雷破			 	= 113656,
	真气波	 			= 115098,
	升龙霸	 			= 152175,
	豪能酒 				= 115288,
	翔龙在天	 		= 101545,
	扫堂腿	 			= 119381,
	轮回之触 			= 115080,
	风火雷电 			= 137639,
	白虎下凡 			= 123904,
	碧玉疾风 			= 116847,
	屏气凝神 			= 152173,
	点穴踢 				= 247255,
	连击 				= 196741,
	电容 				= 235054,
	转化力量			= 195321,
	碎玉闪电			= 117952,
	公共 				= 100780,
}
local eqid = {				-- EquipmentId 装备id字典
	电容胸 				= 144239,
	怒雷鞋              = 137029,
	凤击头				= 151811,
}
local tlarg = {				-- TalentArguments 天赋参数字典
	猛虎之眼			= {1, 2},
	真气波 				= {1, 3},
	豪能酒 				= {3, 1},
	平心之环 			= {4, 1},
	玄牛雕像 			= {4, 2},
	扫堂腿 				= {4, 3},
	碧玉疾风 			= {6, 1},
	白虎下凡 			= {6, 2},
	连击 				= {6, 3},
	真气流转 			= {7, 1},
	升龙霸 				= {7, 2},
	屏气凝神 			= {7, 3},
}
local skey = {				-- SpellKey 技能快捷键字典
	猛虎掌				= '1',
	旭日东升踢			= '2',
	幻灭踢				= '3',
	豪能酒				= '4',
	切喉手				= '5',
	轮回之触			= '6',
	风领主之击			= '7',
	升龙霸 				= '8',
	怒雷破 				= '9',
	真气波 				= '0',
	风火雷电 			= 'Y',
	神鹤引项踢 			= 'G',
	碧玉疾风 			= 'H',
	碎玉闪电 			= 'J',
	扫堂腿 				= 'E',
	真气突 				= 'Q',
	翔龙在天 			= 'R',
}
local locker = {			-- LockSpell 技能锁
	猛虎掌				= false,
	幻灭踢				= false,
	神鹤引项踢			= false,
}

-- --------------------------------基本转换--------------------------------
local function TransferName(SpellName)
	--[[
		SpellName
		input:    技能名称
		return:   该技能游戏中的名称
	  ]]
	return select(1, GetSpellInfo(tsid[SpellName]))
end

local function Cast(SpellName)
	--[[
		CastSpell
		input:    技能名称
		return:   nil
		将该技能的快捷键和名称附到Cnt后面
	  ]]
	Cnt = Cnt..skey[SpellName]..'  '..TransferName(SpellName)
end

-- --------------------------------状态监测--------------------------------
local function CD(SpellName)
	--[[
		CoolDown
		input:    技能中文名称
		return:   该技能尚余冷却时间
	  ]]
	local start, duration, enabled = GetSpellCooldown(tsid[SpellName])
	if enabled == 0 then    -- 如濳行，处于潜行状态时不触发CD，这时视CD为无穷大
		return 10000
	elseif ( start > 0 and duration > 0) then
		return start + duration - GetTime()
	else
		return 0
	end
end

local function Buff(SpellName, UnitName)
	--[[
		input:    技能中文名称，监测的对象
		return:   玩家身上该技能的剩余时间，不存在则返回0
	  ]]
	UnitName = UnitName or 'player'
	local name, rank, icon, count, debuffType,
	      duration, expirationTime, unitCaster,
	      isStealable, shouldConsolidate,
	      spellId = UnitBuff(UnitName, TransferName(SpellName))
	if name then
		local leftTime = expirationTime - GetTime()
		if leftTime < 0 then
			return 1000
		else
			return leftTime
		end
	else
		return 0
	end
end

local function BuffCount(SpellName, UnitName)
	--[[
		input:    技能中文名称，监测的对象
		return:   玩家身上该技能的叠加层数，不存在则返回0
	  ]]
	UnitName = UnitName or 'player'
	local name, rank, icon, count, debuffType,
	      duration, expirationTime, unitCaster,
	      isStealable, shouldConsolidate,
	      spellId = UnitBuff(UnitName, TransferName(SpellName))
	if name then
		return count
	else
		return 0
	end
end

local function DeBuff(SpellName, UnitName)
	--[[
		input:    技能中文名称，监测的对象
		return:   目标身上该技能的剩余时间，不存在则返回0
	  ]]
	UnitName = UnitName or 'target'
	local name, rank, icon, count, debuffType,
	      duration, expirationTime, unitCaster,
	      isStealable, shouldConsolidate,
	      spellId = UnitDebuff(UnitName, TransferName(SpellName))
	if name and unitCaster == 'player' then
		local leftTime = expirationTime - GetTime()
		if leftTime < 0 then
			return 1000
		else
			return leftTime
		end
	else
		return 0
	end
end

local function DeBuffCount(SpellName, UnitName)
	--[[
		input:    技能中文名称，监测的对象
		return:   玩家身上该技能的叠加层数，不存在则返回0
	  ]]
	UnitName = UnitName or 'target'
	local name, rank, icon, count, debuffType,
	      duration, expirationTime, unitCaster,
	      isStealable, shouldConsolidate,
	      spellId = UnitDebuff(UnitName, TransferName(SpellName))
	if name and unitCaster == 'player' then
		return count
	else
		return 0
	end
end

local function Equip(EquipmentName)
	--[[
		input:    装备中文简称
		return:   true(该装备穿在身上) / nil(该装备未穿在身上)
	  ]]
	return IsEquippedItem(eqid[EquipmentName])
end

local function Talent(TalentName)
	--[[
		input:    天赋名称
		return:   true(该点赋已点) / nil(该天赋未点)
	  ]]
	local deep, left = tlarg[TalentName][1], tlarg[TalentName][2]
	return select(4, GetTalentInfo(deep, left, 1))
end

local function RangeIn(UnitName)
	--[[
		input:    监测目标
		return:   true(该目标位于10码内) / nil(该目标位于10码外)
	  ]]
	UnitName = UnitName or 'target'
	return CheckInteractDistance(UnitName, 3)
end

local function HP(UnitName)
	UnitName = UnitName or 'target'
	return UnitHealth(UnitName)
end
local function HPMax(UnitName)
	UnitName = UnitName or 'target'
	return UnitHealthMax(UnitName)
end
local function HPP(UnitName)
	UnitName = UnitName or 'target'
	local HitPoint_Max = UnitHealthMax(UnitName)
	if HitPoint_Max == 0 then
		return 0
	else
		return UnitHealth(UnitName) / HitPoint_Max
	end
end

local function MP(UnitName)
	UnitName = UnitName or 'player'
	return UnitMana(UnitName)
end
local function MPMax(UnitName)
	UnitName = UnitName or 'player'
	return UnitManaMax(UnitName)
end
local function MPP(UnitName)
	UnitName = UnitName or 'player'
	local ManaPoint_Max = UnitManaMax(UnitName)
	if ManaPoint_Max == 0 then
		return 0
	else
		return UnitMana(UnitName) / ManaPoint_Max
	end
end

local function EnG(UnitName)
	UnitName = UnitName or 'player'
	return UnitPower(UnitName, 3)
end
local function EnGMax(UnitName)
	UnitName = UnitName or 'player'
	return UnitPowerMax(UnitName, 3)
end
local function EnGP(UnitName)
	UnitName = UnitName or 'player'
	local Energy_Max = UnitPowerMax(UnitName, 3)
	if Energy_Max == 0 then
		return 0
	else
		return UnitPower(UnitName, 3) / Energy_Max
	end
end

local function Power(UnitName)
	UnitName = UnitName or 'player'
	return UnitPower(UnitName, 12)
end
local function PowerMax(UnitName)
	UnitName = UnitName or 'player'
	return UnitPowerMax(UnitName, 12)
end

local function CountSHYXT()
	--[[
		return:   去除超时的成员后，统计神鹤引项踢的层数
	  ]]
	local k, v, n, t
	t = GetTime()
	n = 0
	for k, v in pairs(sighedSHYXT) do
		if t - v > 15 then
			sighedSHYXT[k] = nil
		else
			n = n + 1
		end
	end
	return n
end

------------------------------监测战斗记录和聊天记录-------------------------------
local function checkEvents(self, event, ...)
	if event == 'CHAT_MSG_WHISPER' then
		local ChatMessage, Author = select(1, ...)
		--监测策略值
		if ChatMessage == "DPSerTaFeng_I_S01" then
			Index_Strategy = 1
		end
		if ChatMessage == "DPSerTaFeng_I_S02" then
			Index_Strategy = 2
		end
		if ChatMessage == "DPSerTaFeng_I_S03" then
			Index_Strategy = 3
		end
		if ChatMessage == "DPSerTaFeng_I_S00" then
			Index_Strategy = 0
		end
		--碧玉疾风
		if ChatMessage == "DPSerTaFeng_BiYuJiFeng" then
			spellInsert['碧玉疾风'] = true
		end
		--神鹤引项踢
		if ChatMessage == "DPSerTaFeng_ShenHeYinXiangTi" then
			spellInsert['神鹤引项踢'] = true
		end
		--扫堂腿
		if ChatMessage == "DPSerTaFeng_SaoTangTui" then
			spellInsert['扫堂腿'] = true
		end
	end
	if event == 'COMBAT_LOG_EVENT_UNFILTERED' then
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags,
			  sourceRaidFlags, destGUID, destName, destFlags, destFlags2, spellID,
			  spellName, _, extraskillID, extraSkillName = select(1, ...)
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" then
			--从技能队列中清空”碧玉疾风“
			if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 116847 then
				spellInsert['碧玉疾风'] = false
			end
			--从技能队列中清空”神鹤引项踢“
			if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 101546 then
				spellInsert['神鹤引项踢'] = false
			end
			--从技能队列中清空”扫堂腿“
			if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 119381 then
				spellInsert['扫堂腿'] = false
			end
			if spellID == tsid['猛虎掌'] then				--如果刚才放了个猛虎掌
				LockSpell('猛虎掌')
			elseif spellID == tsid['幻灭踢'] then			--如果刚才放了个幻灭踢
				LockSpell('幻灭踢')
			elseif spellID == tsid['神鹤引项踢'] then		--如果刚才放了个神鹤引项踢
				LockSpell('神鹤引项踢')
			else
				UnlockSpell()
			end
			--连续释放2次技能就报警
			the_spellname = spellName
			if Talent('连击') and the_spellname == last_spellname then
				DEFAULT_CHAT_FRAME:AddMessage(the_spellname.." just casted 2 times at "..timestamp)
			end
			last_spellname = spellName
		end
		-- 神鹤引项踢的监测
		if (eventType == 'SPELL_AURA_APPLIED' or eventType == 'SPELL_AURA_REFRESH')
				and spellName == TransferName('神鹤印记') and sourceName == UnitName('player') then  	-- 当某怪物被神鹤引项踢标记时
			-- 将该怪物的ID和当前时间添加进表
			sighedSHYXT[destGUID] = GetTime()
		end
		if eventType == 'SPELL_AURA_REMOVED' and spellName == TransferName('神鹤印记')
				and sourceName == UnitName('player') then  	-- 当某怪物的神鹤引项踢标记被移除时
			-- 将该怪物的ID从表中移除
			sighedSHYXT[destGUID] = nil
		end
		if eventType == 'UNIT_DIED' then  					-- 当某怪物的神鹤引项踢标记被移除时
			-- 将该怪物的ID从表中移除
			sighedSHYXT[destGUID] = nil
		end
	end
end

------------------------------策略-------------------------------
local function LockSpell(SpellName)
	--[[
		input:    技能名称
		return:   nil
		将该技能上锁，同时解锁其他所有技能
	  ]]
	local k
	for k, _ in pairs(locker) do
		locker[k] = false
	end
	locker[SpellName] = true
end

local function UnlockSpell()
	--[[
		return:   nil
		解锁所有技能
	  ]]
	local k
	for k, _ in pairs(locker) do
		locker[k] = false
	end
end

function ClearSpellList()		--清除插队队列
	--[[
		return:   nil
		清楚所有插队队列
	  ]]
	local k
	for k, _ in pairs(spellInsert) do
		spellInsert[k] = false
	end
end

function InsertSpellList()		--添加插队队列
	--打断
	--如果按下Ctrl并且检测到相关技能施放，正读条
	if IsCtrl and not IsAlt and not IsShift then
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitCastingInfo('target')
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在施法，就打断之
			Cnt = "P "
			Cast('切喉手')
			return
		end
	end
	--如果按下Shift并且检测到相关技能施放，倒读条
	if IsShift and not IsAlt and not IsCtrl then
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo('target')
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在引导通道法术，就打断之
			Cnt = "P "
			Cast('切喉手')
			return
		end
	end
	--第一时间取消翔龙在天
	if select(2, GetActionInfo(72)) == 115057 then
		Cnt = "P "
		Cast('翔龙在天')
		return
	end
	--碧玉疾风
	if not Talent('碧玉疾风') then		--没点碧玉疾风天赋就忽略之
		spellInsert['碧玉疾风'] = false
	end
	if spellInsert['碧玉疾风'] and CD('碧玉疾风') <= 1 and Power() >= 1 then
		Cnt = "P "
		Cast('碧玉疾风')
		return
	elseif spellInsert['碧玉疾风'] and CD('碧玉疾风') <= 1 and Power() < 1 then
		Cnt = "P "
		Cast('猛虎掌')
		return
	end
	--神鹤引项踢
	if spellInsert['神鹤引项踢'] then
		--真气<=1，且能量不满，且豪能酒CD，使用豪能酒
		if Power() <= 1 and EnG() < EnGMax() and CD('豪能酒') <= 1 then
			Cnt = "P "
			Cast('豪能酒')
			return
		end
		--真气>=3，使用神鹤引项踢
		if Power() >= 3 then
			Cnt = "P "
			Cast('神鹤引项踢')
			return
		end
		--真气<3，使用猛虎掌
		if Power() < 3 then
			Cnt = "P "
			Cast('猛虎掌')
			return
		end
	end
	--扫堂腿
	if not Talent('扫堂腿') then		--没点扫堂腿天赋就忽略之
		spellInsert['扫堂腿'] = false
	end
	if (spellInsert['扫堂腿'] or IsAlt and IsCtrl and not IsShift) and CD('扫堂腿') <= 1 then
		Cnt = "P "
		Cast('扫堂腿')
		return
	end
end

function AddPowerCircle()
	--攒气循环
	--点穴踢时，且旭日东升踢CD，使用旭日东升踢
	if Power() >= 2 and Buff('点穴踢') > 0 and CD('旭日东升踢') <= 1 then
		Cast('旭日东升踢')
		return
	end
	--皇帝的容电皮甲层数>=20，且人物静止，使用碎玉闪电
	if BuffCount('电容') >= 15 and GetUnitSpeed("player") == 0 then
		Cast('碎玉闪电')
		return
	end
	--真气<4，使用无锁猛虎掌
	if EnG() >= 50 and Power() <= 4 and (not locker['猛虎掌'] or Buff('连击') == 0) then
		Cast('猛虎掌')
		return
	end
	--使用无锁幻灭踢
	if Power() > 1 and (not locker['幻灭踢'] or Buff('连击') == 0) then
		Cast('幻灭踢')
		return
	end

	-- 真气波CD，使用真气波
	if CD('真气波') <= 1 and Talent('真气波') then
		Cast('真气波')
		return
	end
	-- 无事可做时，神鹤引项踢
	if Power() >= 3 then
		Cast('神鹤引项踢')
		return
	end
end

function MinusPowerCircle()
	--泄气循环
	--真气>=2，且旭日东升踢CD，使用旭日东升踢
	if Power() >= 2 and CD('旭日东升踢') <= 1 then
		Cast('旭日东升踢')
		return
	end
	--真气>=2，且风领主之击CD，使用风领主之击
	if Power() >= 2 and CD('风领主之击') <= 1 then
		Cast('风领主之击')
		return
	end

	--皇帝的容电皮甲层数>=n，且人物静止，使用碎玉闪电
	if BuffCount('电容') >= 15 and GetUnitSpeed("player") == 0 then
		Cast('碎玉闪电')
		return
	end
	--使用无锁幻灭踢
	if Power() > 1 and (not locker['幻灭踢'] or Buff('连击') == 0) then
		Cast('幻灭踢')
		return
	end
	--真气<4，使用无锁猛虎掌
	if EnG() >= 50 and Power() <= 4 and (not locker['猛虎掌'] or Buff('连击') == 0) then
		Cast('猛虎掌')
		return
	end

	-- 真气波CD，使用真气波
	if CD('真气波') <= 1 and Talent('真气波') then
		Cast('真气波')
		return
	end
	-- 无事可做时，神鹤引项踢
	if Power() >= 3 then
		Cast('神鹤引项踢')
		return
	end
end

function ForBoss(indexS)
	-- 手动暴发打Boss
	-- 碎玉闪电、怒雷破在引导中，什么也不做
	local IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo("player")
	if IfCasting == TransferName('怒雷破') or IfCasting == TransferName('碎玉闪电') then
		Cnt = Cnt..''
		return
	end

	-- 连击天赋下用真气波保持连击
	if not RangeIn() and Buff('连击') < 1 and BuffCount('连击') >= 6 and CD('真气波') <= 1 and Talent('真气波') then
		Cast('真气波')
		return
	end

	if indexS == 1 then
		-- 风火雷电CD，身上没有风火雷电Buff,按下Alt，卡怒雷破CD，就用风火雷电
		if CD('风火雷电') <= 1 and Buff('风火雷电') == 0 and IsAlt and not IsShift and not IsCtrl and CD('怒雷破') < 8 then
			Cast('风火雷电')
			return
		end
	elseif indexS == 2 then
		--风火雷电CD，身上没有风火雷电Buff，卡怒雷破CD，就用风火雷电
		if CD('风火雷电') <= 1 and Buff('风火雷电') == 0 and CD('怒雷破') <= 1 then
			Cast('风火雷电')
			return
		end
	end

	-- 轮回之触CD，就用轮回之触
	if CD('轮回之触') <= 1 and (UnitLevel("target") >= 112 or UnitLevel("target") < 0) then
		Cast('轮回之触')
		return
	end

	-- 使用无锁免费幻灭踢
	if Buff('幻灭踢!') > 0 and (not locker['幻灭踢'] or Buff('连击') == 0) then
		Cast('幻灭踢')
		return
	end

	-- 有橙头时，使用风领主之击
	if Equip('凤击头') and Power() >= 2 and CD('风领主之击') <= 1 then
		Cast('风领主之击')
		return
	end

	-- 真气<=1，且能量不满，且豪能酒CD，使用豪能酒
	if Buff('屏气凝神') == 0 and Power() <= 1 and EnG() < EnGMax() and CD('豪能酒') <= 0.1 then
		Cast('豪能酒')
		return
	end

	-- 怒雷破没CD，且旭日东升踢没CD，且升龙霸CD，近战范围内，使用升龙霸
	if Talent('升龙霸') and CD('怒雷破') > 1 and CD('旭日东升踢') > 1 and CD('升龙霸') <= 1 and RangeIn() then
		Cast('升龙霸')
		return
	end

	-- 真气>=3，且怒雷破CD，使用怒雷破
	if Power() >= spellSpend['怒雷破'] and CD('怒雷破') <= 1 then
		Cast('怒雷破')
		return
	end

	-- 怒雷破刚用完，泄气循环，快好了攒气循环
	if CD('怒雷破') < 4 and Power() < 5 then
		AddPowerCircle()
		return
	else
		MinusPowerCircle()
		return
	end
end

function AOE()
	--6目标以上
	--怒雷破在引导中，什么也不做
	local IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo("player")
	if IfCasting == TransferName('怒雷破') and not (Buff('屏气凝神') > 0 and CD('旭日东升踢') <= 1) then
		Cnt = Cnt..''
		return
	end
	--引导碎玉闪电期间，啥也不干
	if IfCasting == TransferName('碎玉闪电') then
		Cnt = Cnt..''
		return
	end

	--连击天赋下用真气波保持连击
	if not RangeIn() and Buff('连击') < 1 and BuffCount('连击') >= 6 and CD('真气波') <= 1 and Talent('真气波') then
		Cast('真气波')
		return
	end

	--风火雷电CD，身上没有风火雷电Buff，卡怒雷破CD||神鹤层数>=3，就用风火雷电
	if CD('风火雷电') <= 1 and Buff('风火雷电') == 0 and (CD('怒雷破') <= 1 or CountSHYXT >= 3) then
		Cast('风火雷电')
		return
	end

	--真气>=3，且怒雷破CD，使用怒雷破
	if count_SHYXT <= 6 and Power() >= spellSpend['怒雷破'] and CD('怒雷破') <= 1 then
		Cast('怒雷破')
		return
	end

	if count_SHYXT <= 4 and Power() >= 2 and CD('旭日东升踢') <= 1 then
		Cast('旭日东升踢')
		return
	end

	--怒雷破没CD，且旭日东升踢没CD，且升龙霸CD，近战范围内，使用升龙霸
	if count_SHYXT <= 4 and Talent('升龙霸') and CD('怒雷破') > 1 and CD('旭日东升踢') > 1 and CD('升龙霸') <= 1 and RangeIn() then
		Cast('升龙霸')
		return
	end

	-- 神鹤层数>=n，转圈
	if count_SHYXT >= 3 and Power() >= 3 then
		Cast('神鹤引项踢')
		return
	end

	--真气<=1，且能量不满，且豪能酒CD，使用豪能酒
	if Power() <= 1 and EnG() < EnGMax() and CD('豪能酒') <= 1 then
		Cast('豪能酒')
		return
	end

	-- 神鹤层数>=5，猛虎掌攒星
	if count_SHYXT >= 5 and EnG() >= 50 and (not locker['猛虎掌'] or Buff('连击') == 0) then
		Cast('猛虎掌')
		return
	end

	--使用无锁免费幻灭踢
	if Buff('幻灭踢!') > 0 and (not locker['幻灭踢'] or Buff('连击') == 0) then
		Cast('幻灭踢')
		return
	end

	--使用无锁猛虎掌
	if EnG() >= 50 and (not locker['猛虎掌'] or Buff('连击') == 0) then
		Cast('猛虎掌')
		return
	end

	--使用无锁幻灭踢
	if Power() >= 1 and (not locker['幻灭踢'] or Buff('连击') == 0) then
		Cast('幻灭踢')
		return
	end

	-- 使用旭日东升踢
	if Power() >= 2 and CD('旭日东升踢') <= 1 then
		Cast('旭日东升踢')
		return
	end

	--真气波CD，使用真气波
	if CD('真气波') <= 1 and Talent('真气波') then
		Cast('真气波')
		return
	end

	if CD('轮回之触') <= 1 then
		Cast('轮回之触')
		return
	end

	--否则，什么都不干
	Cnt = Cnt..''
	return
end

------------------------------main-------------------------------
local function main(self, elapsed)
	Cnt = 'P '

	IsCombat = UnitAffectingCombat("player")		-- 是否在战斗状态
	IsAlt = IsAltKeyDown()					        -- 是否按下Alt键
	IsCtrl = IsControlKeyDown()				        -- 是否按下Ctrl键
	IsShift = IsShiftKeyDown()				        -- 是否按下Ctrl键

	if Equip('怒雷鞋') then
		spellSpend['怒雷破'] = 2
	else
		spellSpend['怒雷破'] = 3
	end

	if select(2, UnitClass("player")) == "MONK" then
		if Index_Strategy < 3 then
			ForBoss(Index_Strategy)
		elseif Index_Strategy == 3 then
			count_SHYXT = CountSHYXT()
			AOE()
		elseif Index_Strategy == 0 then
			Cnt = "P "
		end
	end

	--非战斗时，清空插队队列
	if IsCombat then
		--插队技能
		InsertSpellList()
	else
		ClearSpellList()
	end

	--显示目前的策略
	Cnt = Cnt.."\nF"..Index_Strategy
	self.text:SetText(Cnt)
end