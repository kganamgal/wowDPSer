------------------------------------------------------------
-- DPSerTongKuShu.lua
--
------------------------------------------------------------
dict_spellId = {}
dict_spellId['灵魂石'] = 20707
dict_spellId['痛苦无常'] = 30108
dict_spellId['生命虹吸'] = 63106

name_spell = {}
name_spell['灵魂石'] = select(1, GetSpellInfo(dict_spellId['灵魂石']))
name_spell['痛苦无常'] = select(1, GetSpellInfo(dict_spellId['痛苦无常']))
name_spell['生命虹吸'] = select(1, GetSpellInfo(dict_spellId['生命虹吸']))

local UnitExists = UnitExists                                                     -- 声明各关键词
local UnitIsUnit = UnitIsUnit
local GetUnitSpeed = GetUnitSpeed
local GetPlayerFacing = GetPlayerFacing
local GetUnitPitch = GetUnitPitch
local GetPlayerMapPosition = GetPlayerMapPosition
local format = format
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME
local count_cast = 0
local name_cast = ""
local CoverTime_GeLie = 0
local CoverTime_AShaManDeSiChe = 0
local CoverTime_All = 1
local Index_Strategy = 1					--策略index默认为1

local Cnt, SpellingStart
local updateElapsed = 0                                                           -- 将计时器归零

--local function NormalizeSpeed(speed)                                              -- 将系统速度换算为正常行走速度的倍数
--	return floor(speed * 100 / 7 + 0.5)
--end

--local function NormalizeFacing(Facing)                                              -- 将系统朝向换算为角度
--	return floor(360 - Facing * 180 / 3.1415926)
--end

--local function NormalizePitch(Pitch)                                              -- 将系统仰角换算为角度
--	return floor(-1 * Pitch * 180 / 3.1415926)
--end

--local function NormalizePos(po)                                              -- 将系统仰角换算为角度
--	return floor(po * 100000)
--endend

local frame = CreateFrame("Button", "TongKuShu", UIParent)                  -- 定义一个框体frame
frame:SetWidth(16)                                                                 -- 定义frame的宽
frame:SetHeight(16)                                                                -- 定义frame的高
frame:SetPoint("CENTER", 0, 120)                                                   -- 定义frame的中心位置
frame:SetMovable(true)                                                             -- 将frame设为可移动
frame:SetUserPlaced(true)                                                          -- 将frame设为可自定义位置
frame:SetClampedToScreen(true)                                                     -- 允许将该frame拖出屏幕(or not?)
frame:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")       -- 设置frame的纹理
frame:SetBackdropBorderColor(100, 100, 100)

frame.icon = frame:CreateTexture(frame:GetName().."Icon", "ARTWORK")               -- 设置frame的图标
frame.icon:SetAllPoints(frame)
frame.icon:SetTexture("Interface\\Icons\\Ability_Druid_SkinTeeth")

frame.text = frame:CreateFontString(frame:GetName().."Text", "ARTWORK", "GameFontHighlightLeft")
                                                                                   -- 为frame创建一个新的Fontstring目标
frame.text:SetPoint("LEFT", frame, "RIGHT", 2, 0)
frame.text:SetFont(STANDARD_TEXT_FONT, 30)

frame:RegisterForDrag("LeftButton")                                                -- 左键可拖动该frame的位置
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")						-- 设定该frame关注的事件：战斗信息
frame:RegisterEvent("CHAT_MSG_WHISPER")												-- 设定该frame关注的事件：聊天记录

----------------------------监测---------------------------------

frame:SetScript("OnEvent", function(self, event, timestamp, eventType, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, _, spellID, spellName, _, extraskillID, extraSkillName)
	if event == "CHAT_MSG_WHISPER" then
		--DEFAULT_CHAT_FRAME:AddMessage(ChatMessage)
		ChatMessage = timestamp
		Author = eventType
		--监测策略值
		if ChatMessage == "DPSerTongKuShu_I_S01" then
			Index_Strategy = 1
		end
		if ChatMessage == "DPSerTongKuShu_I_S02" then
			Index_Strategy = 2
		end
		if ChatMessage == "DPSerTongKuShu_I_S03" then
			Index_Strategy = 3
		end
		if ChatMessage == "DPSerTongKuShu_I_S04" then
			Index_Strategy = 0
			Insert_LingHunShi = nil
		end
		-- 灵魂石
		-- if ChatMessage == "DPSerTongKuShu_LingHunShi" then
		-- 	Insert_LingHunShi = 1
		-- end
	end
	-- if event == "COMBAT_LOG_EVENT_UNFILTERED" then
	-- 	--从技能队列中清空“灵魂石”
	-- 	if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == dict_spellId['灵魂石'] then
	-- 		Insert_LingHunShi = nil
	-- 	end
	-- end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- 监测痛苦无常，并记录该时间为T0
		if sourceName == UnitName("player") and eventType == "SPELL_PERIODIC_DAMAGE" and spellName == name_spell['痛苦无常'] then
			tkwcT0 = GetTime()
		end
	end
end)

local function GetOneCoolDown(JiNengID)
	start, duration, enabled = GetSpellCooldown(JiNengID)
	local temp = 10000
	if enabled == 1 then
		temp = duration - GetTime() + start
		if temp < 0 then
			temp = 0
		end
	end
	return temp
end

local function GetAllCoolDown()							-- 监测技能CD
	CDAnYingFengYin       = GetOneCoolDown(171140)		-- 暗影封印
	CDTongChu             = GetOneCoolDown(980)			-- 痛楚
	CDLingHunShouGe       = GetOneCoolDown(196098)	    -- 灵魂收割
	CDDuoHun              = GetOneCoolDown(216698)		-- 痛楚
	CDGuiYiMeiYing        = GetOneCoolDown(205179)		-- 诡异魅影
	CDLingHunShi          = GetOneCoolDown(dict_spellId['灵魂石'])		-- 灵魂石
	CDShengMingFenLiu     = GetOneCoolDown(1454)		-- 生命分流
end

local function GetOneBuff(DuiXiang, JiNengID)	-- 1存在，2层数，3剩余时间，4施法者
	-- a,b,c,d=UnitBuff("player", index)    1为Buff名称，2为等级，3为图标，4为层数，5为类型（魔法诅咒），6为最大持续时间，7为释放的时间，8为上Buff的人，11为ID，index从右往左走
	Temp1 = nil
	Temp2 = 0
	Temp3 = 0
	Temp4 = nil
	local i = 1
	while true do
		Buff1, Buff2, Buff3, Buff4, Buff5, Buff6, Buff7, Buff8, Buff9, Buff10, Buff11 = UnitBuff(DuiXiang, i)
		if Buff11 == nil then break end
		if Buff11 == JiNengID then
			Temp1 = true
			Temp2 = Buff4
			Temp3 = Buff7 - GetTime()
			if Temp3 < 0 then
				Temp3 = 10000
			end
			Temp4 = Buff8
			break
		end
		i = i + 1
	end
end

local function GetAllBuff()					-- 监测Buff
	-- 延绵恐惧
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff("player", select(1, GetSpellInfo(199281)))
	BuffYanMianKKongJu1 = name
	BuffYanMianKKongJu2 = count or 0
	BuffYanMianKKongJu3 = (expirationTime or GetTime()) - GetTime()
	BuffYanMianKKongJu4 = unitCaster or nil
	if BuffYanMianKKongJu1 then
		BuffYanMianKKongJu = BuffYanMianKKongJu3
	else
		BuffYanMianKKongJu = 0
	end
	--
	-- 夺魂
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff("player", select(1, GetSpellInfo(216695)))
	BuffDuoHun1 = name
	BuffDuoHun2 = count or 0
	BuffDuoHun3 = (expirationTime or GetTime()) - GetTime()
	BuffDuoHun4 = unitCaster or nil
	if BuffDuoHun1 then
		BuffDuoHun = BuffDuoHun3
	else
		BuffDuoHun = 0
	end
	--
	-- 灵魂收割
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff("player", select(1, GetSpellInfo(196098)))
	BuffLingHunShouGe1 = name
	BuffLingHunShouGe2 = count or 0
	BuffLingHunShouGe3 = (expirationTime or GetTime()) - GetTime()
	BuffLingHunShouGe4 = unitCaster or nil
	if BuffLingHunShouGe1 then
		BuffLingHunShouGe = BuffLingHunShouGe3
	else
		BuffLingHunShouGe = 0
	end
	--
	-- 逆风收割者
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff("player", select(1, GetSpellInfo(216708)))
	BuffNiFengShouGeZhe1 = name
	BuffNiFengShouGeZhe2 = count or 0
	BuffNiFengShouGeZhe3 = (expirationTime or GetTime()) - GetTime()
	BuffNiFengShouGeZhe4 = unitCaster or nil
	if BuffNiFengShouGeZhe1 then
		BuffNiFengShouGeZhe = BuffNiFengShouGeZhe3
	else
		BuffNiFengShouGeZhe = 0
	end
	--
	-- 诺甘农的预见
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff("player", select(1, GetSpellInfo(236431)))
	BuffNuoGanNongDeYuJian1 = name
	BuffNuoGanNongDeYuJian2 = count or 0
	BuffNuoGanNongDeYuJian3 = (expirationTime or GetTime()) - GetTime()
	BuffNuoGanNongDeYuJian4 = unitCaster or nil
	if BuffNuoGanNongDeYuJian1 then
		BuffNuoGanNongDeYuJian = BuffNuoGanNongDeYuJian3
	else
		BuffNuoGanNongDeYuJian = 0
	end
end

local function GetOneDebuff(DuiXiang, JiNengID)	-- 1存在，2层数，3剩余时间，4施法者
	Temp1 = nil
	Temp2 = 0
	Temp3 = 0
	Temp4 = nil
	local i = 100
	while true do
		name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff(DuiXiang, i)
		if spellId == nil then break end
		if spellId == JiNengID then
			Temp1 = name
			Temp2 = count
			Temp3 = expirationTime - GetTime()
			Temp4 = unitCaster
			return Temp1, Temp2, Temp3, Temp4
		end
		i = i - 1
	end
end

function GetAllDebuff()						-- 监测Debuff
	--
	-- 痛楚
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", select(1, GetSpellInfo(980)))
	DeBuffTongChu1 = name
	DeBuffTongChu2 = count or 0
	DeBuffTongChu3 = (expirationTime or GetTime()) - GetTime()
	DeBuffTongChu4 = unitCaster or nil
	if DeBuffTongChu1 and DeBuffTongChu4 == "player" then
		DeBuffTongChu = DeBuffTongChu3
	else
		DeBuffTongChu = 0
	end
	--
	-- 腐蚀术
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", select(1, GetSpellInfo(146739)))
	DeBuffFuShiShu1 = name
	DeBuffFuShiShu2 = count or 0
	DeBuffFuShiShu3 = (expirationTime or GetTime()) - GetTime()
	DeBuffFuShiShu4 = unitCaster or nil
	if DeBuffFuShiShu1 and DeBuffFuShiShu4 == "player" then
		DeBuffFuShiShu = DeBuffFuShiShu3
	else
		DeBuffFuShiShu = 0
	end
	--
	-- 痛苦无常
	local i = 100
	while true do
		name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", i)
		if name == name_spell['痛苦无常'] and unitCaster == "player" or i <= 0 then
		    DeBuffTongKuWuChang1 = name
			DeBuffTongKuWuChang2 = count or 0
			DeBuffTongKuWuChang3 = (expirationTime or GetTime()) - GetTime()
			DeBuffTongKuWuChang4 = unitCaster or nil
			break
		end
		i = i - 1
	end
	if DeBuffTongKuWuChang1 and DeBuffTongKuWuChang4 == "player" then
		DeBuffTongKuWuChang = DeBuffTongKuWuChang3
	else
		DeBuffTongKuWuChang = 0
	end
	--
	-- 腐蚀之种
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", select(1, GetSpellInfo(27243)))
	DeBuffFuShiZhiZhong1 = name
	DeBuffFuShiZhiZhong2 = count or 0
	DeBuffFuShiZhiZhong3 = (expirationTime or GetTime()) - GetTime()
	DeBuffFuShiZhiZhong4 = unitCaster or nil
	if DeBuffFuShiZhiZhong1 and DeBuffFuShiZhiZhong4 == "player" then
		DeBuffFuShiZhiZhong = DeBuffFuShiZhiZhong3
	else
		DeBuffFuShiZhiZhong = 0
	end
	--
	-- 生命虹吸
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", name_spell['生命虹吸'])
	DeBuffShengMingHongXi1 = name
	DeBuffShengMingHongXi2 = count or 0
	DeBuffShengMingHongXi3 = (expirationTime or GetTime()) - GetTime()
	DeBuffShengMingHongXi4 = unitCaster or nil
	if DeBuffShengMingHongXi1 and DeBuffShengMingHongXi4 == "player" then
		DeBuffShengMingHongXi = DeBuffShengMingHongXi3
	else
		DeBuffShengMingHongXi = 0
	end
end

function GetFocusDebuff()						-- 监测焦点Debuff
	--
	-- 痛楚
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("focus", select(1, GetSpellInfo(980)))
	focusDeBuffTongChu1 = name
	focusDeBuffTongChu2 = count or 0
	focusDeBuffTongChu3 = (expirationTime or GetTime()) - GetTime()
	focusDeBuffTongChu4 = unitCaster or nil
	if focusDeBuffTongChu1 and focusDeBuffTongChu4 == "player" then
		focusDeBuffTongChu = focusDeBuffTongChu3
	else
		focusDeBuffTongChu = 0
	end
	--
	-- 腐蚀术
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("focus", select(1, GetSpellInfo(146739)))
	focusDeBuffFuShiShu1 = name
	focusDeBuffFuShiShu2 = count or 0
	focusDeBuffFuShiShu3 = (expirationTime or GetTime()) - GetTime()
	focusDeBuffFuShiShu4 = unitCaster or nil
	if focusDeBuffFuShiShu1 and focusDeBuffFuShiShu4 == "player" then
		focusDeBuffFuShiShu = focusDeBuffFuShiShu3
	else
		focusDeBuffFuShiShu = 0
	end
	--
	-- 痛苦无常
	local i = 100
	while true do
		name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("focus", i)
		if name == name_spell['痛苦无常'] and unitCaster == "player" or i <= 0 then
		    focusDeBuffTongKuWuChang1 = name
			focusDeBuffTongKuWuChang2 = count or 0
			focusDeBuffTongKuWuChang3 = (expirationTime or GetTime()) - GetTime()
			focusDeBuffTongKuWuChang4 = unitCaster or nil
			break
		end
		i = i - 1
	end
	if focusDeBuffTongKuWuChang1 and focusDeBuffTongKuWuChang4 == "player" then
		focusDeBuffTongKuWuChang = focusDeBuffTongKuWuChang3
	else
		focusDeBuffTongKuWuChang = 0
	end
	--
	-- 腐蚀之种
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("focus", select(1, GetSpellInfo(27243)))
	focusDeBuffFuShiZhiZhong1 = name
	focusDeBuffFuShiZhiZhong2 = count or 0
	focusDeBuffFuShiZhiZhong3 = (expirationTime or GetTime()) - GetTime()
	focusDeBuffFuShiZhiZhong4 = unitCaster or nil
	if focusDeBuffFuShiZhiZhong1 and focusDeBuffFuShiZhiZhong4 == "player" then
		focusDeBuffFuShiZhiZhong = focusDeBuffFuShiZhiZhong3
	else
		focusDeBuffFuShiZhiZhong = 0
	end
	--
	-- 生命虹吸
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("focus", name_spell['生命虹吸'])
	focusDeBuffShengMingHongXi1 = name
	focusDeBuffShengMingHongXi2 = count or 0
	focusDeBuffShengMingHongXi3 = (expirationTime or GetTime()) - GetTime()
	focusDeBuffShengMingHongXi4 = unitCaster or nil
	if focusDeBuffShengMingHongXi1 and focusDeBuffShengMingHongXi4 == "player" then
		focusDeBuffShengMingHongXi = focusDeBuffShengMingHongXi3
	else
		focusDeBuffShengMingHongXi = 0
	end
end

function GetAllHP()						-- 监测HP
	HP = UnitHealth("target")
	HPMax = UnitHealthMax("target")
	HPP = HP/HPMax
end

function GetSelfMP()						-- 监测MP
	MP = UnitMana("player")
	MPMax = UnitManaMax("player")
	MPP = MP/MPMax
	EnG = UnitPower("player", 3)
	EnGMax = UnitPowerMax("player", 3)
	EnGP = EnG/EnGMax
end

function GetSelfTalents()						-- 监测天赋
	Talent_GuiYingChanShen         = select(4, GetTalentInfo(1, 1, 1))	-- 鬼影缠身
	Talent_FanTengTongChu          = select(4, GetTalentInfo(1, 2, 1))	-- 翻腾痛楚
	Talent_ZaiNanZhiWo             = select(4, GetTalentInfo(1, 3, 1))	-- 灾难之握
	Talent_ChuanRan                = select(4, GetTalentInfo(2, 1, 1))	-- 传染
	Talent_JueDuiFuShi             = select(4, GetTalentInfo(2, 2, 1))	-- 绝对腐蚀
	Talent_QiangHuaShengMingFenLiu = select(4, GetTalentInfo(2, 3, 1))	-- 强化生命分流
	Talent_EMoFaZhen               = select(4, GetTalentInfo(3, 1, 1))	-- 恶魔法阵
	Talent_SiWangChanRao           = select(4, GetTalentInfo(3, 2, 1))	-- 死亡缠绕
	Talent_KongJuHaoJiao           = select(4, GetTalentInfo(3, 3, 1))	-- 恐惧嚎叫
	Talent_GuiYiMeiYing            = select(4, GetTalentInfo(4, 1, 1))	-- 诡异魅影
	Talent_FuShiBoZhong            = select(4, GetTalentInfo(4, 2, 1))	-- 腐蚀播种
	Talent_LingHunShouGe           = select(4, GetTalentInfo(4, 3, 1))	-- 灵魂收割
	Talent_EMoPiFu                 = select(4, GetTalentInfo(5, 1, 1))	-- 恶魔皮肤
	Talent_BaoRanChongCi           = select(4, GetTalentInfo(5, 2, 1))	-- 爆燃冲刺
	Talent_HeiAnQiYue              = select(4, GetTalentInfo(5, 3, 1))	-- 黑暗契约
	Talent_TongYuMoDian            = select(4, GetTalentInfo(6, 1, 1))	-- 统御魔典
	Talent_ShiCongMoDian           = select(4, GetTalentInfo(6, 2, 1))	-- 侍从魔典
	Talent_EMoXiSheng              = select(4, GetTalentInfo(6, 3, 1))	-- 恶魔牺牲
	Talent_SiWangZhiYong           = select(4, GetTalentInfo(7, 1, 1))	-- 死亡之拥
	Talent_ShengMingHongXi         = select(4, GetTalentInfo(7, 2, 1))	-- 生命虹吸
	Talent_LingHunDaoGuan          = select(4, GetTalentInfo(7, 3, 1))	-- 灵魂导管
end

function GetSelfEquipments()						-- 监测装备
	-- EquipSiGua = IsEquippedItem(137056)		        -- 丝瓜裹手
	-- EquipChengJie = IsEquippedItem(137040)		    -- 橙戒
	-- EquipLingHunZhiYin = IsEquippedItem(140808)		-- 灵魂指引
	-- EquipBaoXingShou = IsEquippedItem(137094)		-- 爆星手
	-- EquipXueZhuaXie = IsEquippedItem(137024)			-- 血爪鞋
	-- EquipCongLinJie = IsEquippedItem(151636)			-- 丛林戒
	-- EquipMengHuTou = IsEquippedItem(151801)		    -- 猛虎头
end

function StatiCoverRate()
	--统计Buff、DeBuff覆盖率
	-- if CoverTime_All > 1 and not IsCombat then
	-- 	DEFAULT_CHAT_FRAME:AddMessage("GeLie covered "..floor(10000*CoverTime_GeLie/CoverTime_All)*0.01 .."%")
	-- 	DEFAULT_CHAT_FRAME:AddMessage("ASMdSiChe covered "..floor(10000*CoverTime_AShaManDeSiChe/CoverTime_All)*0.01 .."%")
	-- end
	-- if not IsCombat then
	-- 	CoverTime_GeLie = 0
	-- 	CoverTime_AShaManDeSiChe = 0
	-- 	--CoverTime_YeManPaoXiao = 0
	-- 	CoverTime_All = 1
	-- else
	-- 	if DeBuffGeLie > 0 then
	-- 		CoverTime_GeLie = CoverTime_GeLie + 1
	-- 	end
	-- 	if DeBuffAShaManDeSiChe > 0 then
	-- 		CoverTime_AShaManDeSiChe = CoverTime_AShaManDeSiChe + 1
	-- 	end
	-- 	CoverTime_All = CoverTime_All + 1
	-- end
end

function ClearSpellList()		--清除插队队列
	Insert_TongJi = nil
	Insert_ManLiMengJi = nil
	Insert_KuangBao = nil
end
function InsertSpellList()		--添加插队队列
	--打断
	if HasFocus then
		JianCeDuiXiang = "focus"
	else
		JianCeDuiXiang = "target"
	end
	--如果按下Ctrl并且检测到相关技能施放，正读条
	if IsCtrl and not IsAlt and not IsShift then  
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitCastingInfo(JianCeDuiXiang)
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在施法，就打断之
			Cnt = "P "
			Cast_AnYingFengYin()
			return
		end
	end
	--如果按下Shift并且检测到相关技能施放，倒读条
	if IsShift and not IsAlt and not IsCtrl then  
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo(JianCeDuiXiang)
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在引导通道法术，就打断之
			Cnt = "P "
			Cast_AnYingFengYin()
			return
		end
	end
	-- 战复
    if IfNeedRebirth then
        Cnt = "P "
		Cast_LingHunShi()
		return
	end
end


--技能按键
function Cast_TongChu()			-- 痛楚
	Cnt = Cnt.."1  "..select(1, GetSpellInfo(980))		--1
end
function Cast_FuShiShu()		-- 腐蚀术
	Cnt = Cnt.."2  "..select(1, GetSpellInfo(172))		--2
end
function Cast_XiQuLingHun()		-- 吸取灵魂
	Cnt = Cnt.."3  "..select(1, GetSpellInfo(198590))	--3
end
function Cast_TongKuWuChang()	-- 痛苦无常
	Cnt = Cnt.."4  "..select(1, GetSpellInfo(30108))	--4
end
function Cast_AnYingFengYin()	-- 暗影封印
	Cnt = Cnt.."5  "..select(1, GetSpellInfo(171140))	--5
end
function Cast_FuShiZhiZhong()	-- 腐蚀之种
	Cnt = Cnt.."6  "..select(1, GetSpellInfo(27243))	--6
end
function Cast_ShengMingFenLiu()	-- 生命分流
	Cnt = Cnt.."7  "..select(1, GetSpellInfo(1454))		--7
end
function Cast_LingHunShouGe()	-- 灵魂收割
	Cnt = Cnt.."8  "..select(1, GetSpellInfo(196098))	--8
end
function Cast_DuoHun()			-- 夺魂
	Cnt = Cnt.."9  "..select(1, GetSpellInfo(216698))	--9
end
function Cast_Focus_TongKuWuChang()			-- 痛苦无常
	Cnt = Cnt.."0  "..select(1, GetSpellInfo(30108)).."focus"	--0
end
function Cast_Focus_TongChu()	-- 痛楚focus
	Cnt = Cnt.."Y  "..select(1, GetSpellInfo(980)).."focus"		--Y
end
function Cast_Focus_FuShiShu()	-- 腐蚀术focus
	Cnt = Cnt.."G  "..select(1, GetSpellInfo(172)).."focus"   	--G
end
function Cast_LingHunShi()				-- 灵魂石
	Cnt = Cnt.."J  "..name_spell['灵魂石']   			--J
end
function Cast_ShengMingHongXi()			-- 生命虹吸
	Cnt = Cnt.."H  "..name_spell['生命虹吸']   			--H
end
function Cast_Focus_ShengMingHongXi()	-- 生命虹吸focus
	Cnt = Cnt.."E  "..name_spell['生命虹吸']   			--E
end

--单体Boss
function AttackForBoss()
	TongKuWuChangIsCasting = select(1, GetSpellInfo(30108)) == select(1, UnitCastingInfo("player"))
	KaiBaoFa = GetHaste() >= 70 or BuffLingHunShouGe1
	-- 痛苦无常<2s时,灵魂碎片>0，痛苦无常不在读条
	if HasFocus then
		if not IsMoving and focusDeBuffTongKuWuChang < 1.5/(1+GetHaste()/100) and power > 0 and not TongKuWuChangIsCasting and gcd < GGCD then
			Cast_Focus_TongKuWuChang()
			return
		end
	else
		if not IsMoving and DeBuffTongKuWuChang < 1.5/(1+GetHaste()/100) and power > 0 and not TongKuWuChangIsCasting and gcd < GGCD then
			Cast_TongKuWuChang()
			return
		end
	end
	-- 痛苦无常不存在||痛苦无常刚造成完伤害时
	if TongKuWuChangJustDamage or not ((HasFocus and focusDeBuffTongKuWuChang>0 or not HasFocus and DeBuffTongKuWuChang>0) and Talent_ZaiNanZhiWo) then
		-- 生命分流
		if IsCombat and (IsMoving or MPP < 0.15) and MPP < 0.8 then
			Cast_ShengMingFenLiu()
			return
		end
		-- 痛楚
		if HasFocus and (focusDeBuffTongChu < 6 or IsMoving and focusDeBuffTongChu < 10) then
	    	Cast_Focus_TongChu()
	    	return
		end
		if DeBuffTongChu < 6 or IsMoving and DeBuffTongChu < 10 then
	    	Cast_TongChu()
	    	return
		end
		-- 夺魂
		if BuffDuoHun1 and BuffDuoHun2 >= 2 and BuffNiFengShouGeZhe3 < 2 and CDDuoHun < gcd then
			Cast_DuoHun()
			return
		end
		-- 痛苦无常		
		-- 开爆发时，狂放痛苦无常
		if KaiBaoFa and not IsMoving and power > 0 and not TongKuWuChangIsCasting and gcd < GGCD then
			if HasFocus then
			    Cast_Focus_TongKuWuChang()
			else
				Cast_TongKuWuChang()
			end
			return
		end
		-- 灵魂碎片=5时，痛苦无常不在读条
		if HasFocus then
			if not IsMoving and (BuffNiFengShouGeZhe > 0 and power >= 3 or power >= 5) and not TongKuWuChangIsCasting and gcd < GGCD then
				Cast_Focus_TongKuWuChang()
				return
			end
		else
			if not IsMoving and (BuffNiFengShouGeZhe > 0 and power >= 3 or power >= 5) and not TongKuWuChangIsCasting and gcd < GGCD then
				Cast_TongKuWuChang()
				return
			end
		end
		-- 生命虹吸		
		if Talent_ShengMingHongXi and HasFocus and (focusDeBuffShengMingHongXi < 4.5 or IsMoving and focusDeBuffShengMingHongXi < 8) then
	    	Cast_Focus_ShengMingHongXi()
	    	return
		end
		if Talent_ShengMingHongXi and (DeBuffShengMingHongXi < 4.5 or IsMoving and DeBuffShengMingHongXi < 8) then
	    	Cast_ShengMingHongXi()
	    	return
		end
		-- 腐蚀术
		if HasFocus and (focusDeBuffFuShiShu < 4 or IsMoving and focusDeBuffFuShiShu < 7) then
	    	Cast_Focus_FuShiShu()
	    	return
		end
		if DeBuffFuShiShu < 4 or IsMoving and DeBuffFuShiShu < 7 then
	    	Cast_FuShiShu()
	    	return
		end
		-- 有焦点的情况下，痛苦无常<2s时,灵魂碎片>2，痛苦无常不在读条时，对目标释放痛苦无常
		if HasFocus and not IsMoving and DeBuffTongKuWuChang < 1.5/(1+GetHaste()/100) and power > 2 and not TongKuWuChangIsCasting and gcd < GGCD then
			Cast_TongKuWuChang()
			return
		end
    end
    -- 吸取灵魂
	XiQuLingHunIsChannel = select(1, GetSpellInfo(198590)) == select(1, UnitChannelInfo("player"))
	if not IsMoving and not XiQuLingHunIsChannel then
	    Cast_XiQuLingHun()
	    return
	end
end

--中量目标
function BeatBoss()
	TongKuWuChangIsCasting = select(1, GetSpellInfo(30108)) == select(1, UnitCastingInfo("player"))
	-- 痛苦无常不存在||痛苦无常刚造成完伤害时
	if TongKuWuChangJustDamage or not ((HasFocus and focusDeBuffTongKuWuChang>0 or not HasFocus and DeBuffTongKuWuChang>0) and Talent_ZaiNanZhiWo) then
		-- 生命分流
		if IsCombat and (IsMoving or MPP < 0.15) and MPP < 0.8 then
			Cast_ShengMingFenLiu()
			return
		end
		-- 痛楚
		if HasFocus and (focusDeBuffTongChu < 6 or IsMoving and focusDeBuffTongChu < 10) then
	    	Cast_Focus_TongChu()
	    	return
		end
		if DeBuffTongChu < 6 or IsMoving and DeBuffTongChu < 10 then
	    	Cast_TongChu()
	    	return
		end
		-- 夺魂
		if BuffDuoHun1 and BuffDuoHun2 >= 2 and BuffNiFengShouGeZhe3 < 2 and CDDuoHun < gcd then
			Cast_DuoHun()
			return
		end
		-- 痛苦无常
		-- 开爆发时，狂放痛苦无常
		if not IsMoving and power > 0 and not TongKuWuChangIsCasting and gcd < GGCD then
			if HasFocus then
			    Cast_Focus_TongKuWuChang()
			else
				Cast_TongKuWuChang()
			end
			return
		end
		-- 生命虹吸		
		if Talent_ShengMingHongXi and HasFocus and (focusDeBuffShengMingHongXi < 4.5 or IsMoving and focusDeBuffShengMingHongXi < 8) then
	    	Cast_Focus_ShengMingHongXi()
	    	return
		end
		if Talent_ShengMingHongXi and (DeBuffShengMingHongXi < 4.5 or IsMoving and DeBuffShengMingHongXi < 8) then
	    	Cast_ShengMingHongXi()
	    	return
		end
		-- 腐蚀术
		if HasFocus and (focusDeBuffFuShiShu < 4 or IsMoving and focusDeBuffFuShiShu < 7) then
	    	Cast_Focus_FuShiShu()
	    	return
		end
		if DeBuffFuShiShu < 4 or IsMoving and DeBuffFuShiShu < 7 then
	    	Cast_FuShiShu()
	    	return
		end
		-- 有焦点的情况下，痛苦无常<2s时,灵魂碎片>2，痛苦无常不在读条时，对目标释放痛苦无常
		if HasFocus and not IsMoving and DeBuffTongKuWuChang < 1.5/(1+GetHaste()/100) and power > 2 and not TongKuWuChangIsCasting and gcd < GGCD then
			Cast_TongKuWuChang()
			return
		end
    end
    -- 吸取灵魂
	XiQuLingHunIsChannel = select(1, GetSpellInfo(198590)) == select(1, UnitChannelInfo("player"))
	if not IsMoving and not XiQuLingHunIsChannel then
	    Cast_XiQuLingHun()
	    return
	end
end

--大量目标
function AttackForBuddies()
	-- 生命分流
	if IsCombat and (IsMoving or MPP < 0.15) and MPP < 0.8 then
		Cast_ShengMingFenLiu()
		return
	end
	-- 痛楚
	if HasFocus and (focusDeBuffTongChu < 6 or IsMoving and focusDeBuffTongChu < 10) then
    	Cast_Focus_TongChu()
    	return
	end
	if DeBuffTongChu < 6 or IsMoving and DeBuffTongChu < 10 then
    	Cast_TongChu()
    	return
	end
	-- 夺魂
	if BuffDuoHun1 and BuffDuoHun2 >= 2 and BuffNiFengShouGeZhe3 < 2 and CDDuoHun < gcd then
		Cast_DuoHun()
		return
	end
	-- 痛苦无常
	TongKuWuChangIsCasting = select(1, GetSpellInfo(30108)) == select(1, UnitCastingInfo("player"))
	-- 灵魂碎片=5时||(痛苦无常<2s时,灵魂碎片>0)，痛苦无常不在读条
	if HasFocus then
		if not IsMoving and power >= 5 and not TongKuWuChangIsCasting and gcd < GGCD then
			Cast_Focus_TongKuWuChang()
			return
		end
	else
		if not IsMoving and power >= 5 and not TongKuWuChangIsCasting and gcd < GGCD then
			Cast_TongKuWuChang()
			return
		end
	end
	-- 灵魂碎片>=1时，腐蚀之种不在读条，使用腐蚀之种
	if not IsMoving and power >= 1 and select(1, GetSpellInfo(27243)) ~= select(1, UnitCastingInfo("player")) and gcd < GGCD then
		Cast_FuShiZhiZhong()
		return
	end
    -- 吸取灵魂
	XiQuLingHunIsChannel = select(1, GetSpellInfo(198590)) == select(1, UnitChannelInfo("player"))
	if not IsMoving and not XiQuLingHunIsChannel then
	    Cast_XiQuLingHun()
	    return
	end
end

-- ---------------------------正文-------------------------------

frame:SetScript("OnUpdate", function(self, elapsed)              -- elapsed：距上次执行该事件过去的时间
	updateElapsed = updateElapsed + elapsed
	if updateElapsed > 0.1 then              -- 常量TOOLTIP_UPDATE_TIME：【信息提示】更新间隔，0.2秒
		updateElapsed = 0
		
		Cnt = ""
		IsCombat = UnitAffectingCombat("player")	-- 是否在战斗状态
		HasFocus = UnitExists("focus")
		GetSelfTalents()						    --监测天赋
		GetAllCoolDown()    
		GetAllHP()    
		GetSelfMP()    
		GetAllBuff()
		if BuffNuoGanNongDeYuJian1 then
			IsMoving = false
		else
		    IsMoving = GetUnitSpeed("player") > 0
		end
		GetAllDebuff()
		if HasFocus then
			GetFocusDebuff()
		end
		GetSelfEquipments()						    --监测装备
		IsAlt = IsAltKeyDown()					    -- 是否按下Alt键
		IsCtrl = IsControlKeyDown()				    -- 是否按下Ctrl键
		IsShift = IsShiftKeyDown()				    -- 是否按下Ctrl键
		_,PlayerClass = UnitClass("player")
		GGCD = max(1.0, 1.5 / ( 1 + (GetHaste() or 0) / 100))
		gcd = CDShengMingFenLiu
		power = UnitPower("player",  SPELL_POWER_SOUL_SHARDS)			-- 监测灵魂碎片
		-- 判断痛苦无常是否刚造成伤害
		if tkwcT0 then
		    TongKuWuChangJustDamage = GetTime() - tkwcT0 < 2/(1+(GetHaste() or 0)/100)-GGCD and GetTime() - tkwcT0 > 0
		else
			TongKuWuChangJustDamage = false
	    end
		-- 判断目标是否为高等级
		if UnitLevel("target") == -1 or UnitClassification("target") == "elite" or UnitLevel("target") > UnitLevel("player") or UnitIsPlayer("target") then
			HighLevel = true
		else
			HighLevel = false
		end
		-- 是否需要战复
		if UnitIsDead("target") and (UnitInParty("target") or UnitInRaid("target")) and CDLingHunShi <= gcd then
		    IfNeedRebirth = true
		else
			IfNeedRebirth = false
		end
	
		if PlayerClass == "WARLOCK" then
			Cnt = "P "
			if Index_Strategy == 1 then
				AttackForBoss()
			elseif Index_Strategy == 2 then
				BeatBoss()
			elseif Index_Strategy == 3 then
				AttackForBuddies()
			elseif Index_Strategy == 0 then
				Cnt = "P "
			end
		else
			Cnt = "P "
		end

		--非战斗时，清空插队队列
		if not IsCombat then
			ClearSpellList()
		end
		--插队技能
		InsertSpellList()
		--显示目前的策略
		--Cnt = "P R  "..select(1, GetSpellInfo(22570))
		Cnt = Cnt.."\nF"..Index_Strategy
	    self.text:SetText(Cnt)
	end
end)
