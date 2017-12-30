------------------------------------------------------------
-- DPSerTaFeng.lua
--
-- 
--
-- Edwin
-- 2017-01-29 添加：天赋检测功能
-- 2017-01-30 添加：技能插队功能
-- 2017-01-30 优化：策略函数，用return代替break，并将打断移至技能插队函数中
-- 2017-01-30 重大调整：用一套按键精灵，不同策略在插件内部切换
-- 2017-01-31 添加：非战斗不启动
-- 2017-02-03 移除：非战斗不启动
-- 2017-02-03 添加：攒气循环、泄气循环
-- 2017-02-04 优化：风火雷电卡怒雷破cd放
-- 2017-02-12 调整：输出改为实际快捷键
------------------------------------------------------------

local UnitExists = UnitExists                                                     -- 声明各关键词
local UnitIsUnit = UnitIsUnit
local GetUnitSpeed = GetUnitSpeed
local GetPlayerFacing = GetPlayerFacing
local GetUnitPitch = GetUnitPitch
local GetPlayerMapPosition = GetPlayerMapPosition
local format = format
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME
local Lock_MengHuZhang = 0
local Lock_HuanMieTi = 0
local Lock_ShenHeYinXiangTi = 0
local Lock_SuiYuShanDian = 0
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
--end

local frame = CreateFrame("Button", "TaFeng", UIParent)                  -- 定义一个框体frame
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

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")                       -- 设定该frame关注的事件：战斗信息
frame:RegisterEvent("CHAT_MSG_WHISPER")												-- 设定该frame关注的事件：聊天记录

--  ------------------------监测---------------------------------
frame:SetScript("OnEvent", function(self, event, timestamp, eventType, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, _, spellID, spellName, _, extraskillID, extraSkillName)
	if event == "CHAT_MSG_WHISPER" then
		--DEFAULT_CHAT_FRAME:AddMessage(ChatMessage)
		ChatMessage = timestamp
		Author = eventType
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
			Insert_BiYuJiFeng = 1
		end
		--神鹤引项踢
		if ChatMessage == "DPSerTaFeng_ShenHeYinXiangTi" then
			Insert_ShenHeYinXiangTi = 1
		end
		--扫堂腿
		if ChatMessage == "DPSerTaFeng_SaoTangTui" then
			Insert_SaoTangTui = 1
		end
	end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" then
			--DEFAULT_CHAT_FRAME:AddMessage(spellName..", "..UnitPower("player",  12)..", CDNuLeiPo = "..floor(CDNuLeiPo))
			--从技能队列中清空”碧玉疾风“
			if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 116847 then
				Insert_BiYuJiFeng = nil
			end
			--从技能队列中清空”神鹤引项踢“
			if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 101546 then
				Insert_ShenHeYinXiangTi = nil
			end
			--从技能队列中清空”扫堂腿“
			if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 119381 then
				Insert_SaoTangTui = nil
			end
			--连续释放2次技能就报警
			the_spellname = spellName
			if the_spellname == last_spellname then
				DEFAULT_CHAT_FRAME:AddMessage(the_spellname.." just casted 2 times at "..timestamp)
			end
			last_spellname = spellName
			
			--猛虎掌 100780 幻灭踢 100784 神鹤引项踢 101546
			--旭日东升踢 107428 风领主之击 205320 怒雷破 113656 真气波 115098 升龙霸 152175
			if spellID == 100780 then			--如果刚才放了个猛虎掌
				Lock_HuanMieTi = 0						--幻灭踢
				Lock_ShenHeYinXiangTi = 0			--神鹤引项踢
				Lock_MengHuZhang = 1
			elseif spellID == 100784 then			--如果刚才放了个幻灭踢
				Lock_MengHuZhang = 0				--猛虎掌
				Lock_ShenHeYinXiangTi = 0			--神鹤引项踢
				Lock_HuanMieTi = 1
			elseif spellID == 101546 then			--如果刚才放了个神鹤引项踢
				Lock_MengHuZhang = 0				--猛虎掌
				Lock_HuanMieTi = 0					--幻灭踢
				Lock_ShenHeYinXiangTi = 1
			else
				Lock_MengHuZhang = 0				--猛虎掌
				Lock_HuanMieTi = 0					--幻灭踢
				Lock_ShenHeYinXiangTi = 0			--神鹤引项踢
			end
			if spellID == 117952 then			--如果刚才放了碎玉闪电
				Lock_SuiYuShanDian = 1						--碎玉闪电
			end
		end
	end
end)

-- SPELL_DAMAGE事件
-- SPELL_CAST_SUCCESS
-- SPELL_CAST_FAILED

local function GetOneCoolDown(JiNengID)
	start, duration, enabled = GetSpellCooldown(JiNengID)
	if start == 0 then
		return 0
	end
	local temp = 10000
	if enabled == 1 then
		temp = duration - GetTime() + start
		if temp < 0 then
			temp = 0
		end
	end
	return temp
end

local function GetOneCoolDown(JiNengID)
	start, duration, enabled = GetSpellCooldown(JiNengID)
	if start == 0 then
		return 0
	end
	local temp = 10000
	if enabled == 1 then
		temp = duration - GetTime() + start
		if temp < 0 then
			temp = 0
		end
	end
	return temp
end

local function GetAllCoolDown()						-- 监测技能CD
	CDXuRiDongShengtTi = GetOneCoolDown(107428)				-- 旭日东升踢
	CDHaoNengJiu = GetOneCoolDown(115288)				-- 豪能酒
	CDXiangLongZaiTian = GetOneCoolDown(101545)				-- 翔龙在天
	CDFengLingZhuZhiJi = GetOneCoolDown(205320)				-- 风领主之击
	CDShengLongBa = GetOneCoolDown(152175)				-- 升龙霸
	CDNuLeiPo = GetOneCoolDown(113656)				-- 怒雷破
	CDSaoTangTui = GetOneCoolDown(119381)				-- 扫堂腿
	CDZhenQiBo = GetOneCoolDown(115098)				-- 真气波
	CDMengHuZhang = GetOneCoolDown(100780)				-- 猛虎掌
	CDHuanMieTi = GetOneCoolDown(100784)				-- 幻灭踢
	CDLunHuiZhiChu = GetOneCoolDown(115080)				-- 轮回之触
	CDFengHuoLeiDian = GetOneCoolDown(137639)				-- 风火雷电
	CDBaiHuXiaFan = GetOneCoolDown(123904)				-- 白虎下凡
	CDBiYuJiFeng = GetOneCoolDown(116847)				-- 碧玉疾风
	CDBingQiNingShen = GetOneCoolDown(152173)	    	-- 屏气凝神
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
	GetOneBuff("player", 116768)  --幻灭踢
	BuffHuanMieTi1 = Temp1
	BuffHuanMieTi2 = Temp2
	BuffHuanMieTi3 = Temp3
	BuffHuanMieTi4 = Temp4
	if BuffHuanMieTi1 then
		BuffHuanMieTi = BuffHuanMieTi3
	else
		BuffHuanMieTi = 0
	end
	--
	GetOneBuff("player", 196741)  --连击
	BuffLianJi1 = Temp1
	BuffLianJi2 = Temp2
	BuffLianJi3 = Temp3
	BuffLianJi4 = Temp4
	if BuffLianJi1 then
		BuffLianJi = BuffLianJi3 
	else
		BuffLianJi = 0
	end
	BuffLianJi = 1  --启用此行，无论何种天赋均攒连击
	--
	GetOneBuff("player", 137639)  --风火雷电
	BuffFengHuoLeiDian1 = Temp1
	BuffFengHuoLeiDian2 = Temp2
	BuffFengHuoLeiDian3 = Temp3
	BuffFengHuoLeiDian4 = Temp4
	if BuffFengHuoLeiDian1 then
		BuffFengHuoLeiDian = BuffFengHuoLeiDian3
	else
		BuffFengHuoLeiDian = 0
	end
	--
	GetOneBuff("player", 152173)  --屏气凝神
	BuffBingQiNingShen1 = Temp1
	BuffBingQiNingShen2 = Temp2
	BuffBingQiNingShen3 = Temp3
	BuffBingQiNingShen4 = Temp4
	if BuffBingQiNingShen1 then
		BuffBingQiNingShen = BuffBingQiNingShen3
	else
		BuffBingQiNingShen = 0
	end
	--
	GetOneBuff("player", 235054)  --皇帝的容电皮甲 无限持续时间
	BuffHuangDiDeRongDianPiJia1 = Temp1
	BuffHuangDiDeRongDianPiJia2 = Temp2
	BuffHuangDiDeRongDianPiJia3 = Temp3
	BuffHuangDiDeRongDianPiJia4 = Temp4
	--
	GetOneBuff("player", 247255)  --点穴踢
	BuffDianXueTi1 = Temp1
	BuffDianXueTi2 = Temp2
	BuffDianXueTi3 = Temp3
	BuffDianXueTi4 = Temp4
	if BuffDianXueTi1 then
		BuffDianXueTi = BuffDianXueTi3
	else
		BuffDianXueTi = 0
	end
end

local function GetOneDebuff(DuiXiang, JiNengID)	-- 1存在，2层数，3剩余时间，4施法者
	Temp1 = nil
	Temp2 = 0
	Temp3 = 0
	Temp4 = nil
	local i = 1
	while true do
		Buff1, Buff2, Buff3, Buff4, Buff5, Buff6, Buff7, Buff8, Buff9, Buff10, Buff11 = UnitDebuff(DuiXiang, i)
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

function GetAllDebuff()						-- 监测Debuff
	--GetOneDebuff("target", 1079)  --割裂
	--DeBuffGeLie1 = Temp1
	--DeBuffGeLie2 = Temp2
	--DeBuffGeLie3 = Temp3
	--DeBuffGeLie4 = Temp4
	--
end

function GetAllHP()						-- 监测HP
	HP = UnitHealth("target")
	HPMax = UnitHealthMax("target")
	HPP = HP/HPMax
	--_,_,_,_,OP = UnitDetailedThreatSituation("player","target") / 100
	--_,_,_,_,OPT = UnitDetailedThreatSituation("targettarget","target") / 100
	--if OPT > 0 then
	--	OPP = OP / OPT
	--end
end

function GetSelfMP()						-- 监测MP
	MP = UnitMana("player")
	MPMax = UnitManaMax("player")
	MPP = MP/MPMax
	EnG = UnitPower("player", 3)
	EnGMax = UnitPowerMax("player", 3)
	EnGP = EnG/EnGMax
	if EquipNuLeiXie then
		Qi_NuLeiPo = 2
	else
		Qi_NuLeiPo = 3
	end
end

function GetSelfTalents()						-- 监测天赋
	Talent_ZhenQiBo = select(4, GetTalentInfo(1, 3, 1))				--真气波
	Talent_MengHuZhang = select(4, GetTalentInfo(1, 2, 1))				--猛虎掌
	Talent_PingXinZhiHuan = select(4, GetTalentInfo(6, 1, 1))				--平心之环
	Talent_XuanNiuDiaoXiang = select(4, GetTalentInfo(6, 2, 1))		--玄牛雕像
	Talent_SaoTangTui = select(4, GetTalentInfo(6, 3, 1))						--扫堂腿
	Talent_BiYuJiFeng = select(4, GetTalentInfo(6, 1, 1))						--碧玉疾风
	Talent_BaiHuXiaFan = select(4, GetTalentInfo(6, 2, 1))					--白虎下凡
	Talent_LianJi = select(4, GetTalentInfo(6, 3, 1))								--连击
	Talent_ZhenQiLiuZhuan = select(4, GetTalentInfo(7, 1, 1))				--真气流转
	Talent_ShengLongBa = select(4, GetTalentInfo(7, 2, 1))					--升龙霸
	Talent_BingQiNingShen = select(4, GetTalentInfo(7, 3, 1))				--屏气凝神
end

function GetSelfEquipments()						-- 监测装备
	EquipDianRongXiong      = IsEquippedItem(144239)		-- 电容胸
	EquipNuLeiXie           = IsEquippedItem(137029)		-- 怒雷鞋
end

function ClearSpellList()		--清除插队队列
	Insert_BiYuJiFeng = nil
	Insert_ShenHeYinXiangTi = nil
	Insert_SaoTangTui = nil
end
function InsertSpellList()		--添加插队队列
	--打断
	if UnitName("focus") ~= nil then
		JianCeDuiXiang = "foucs"
	else
		JianCeDuiXiang = "target"
	end
	--如果按下Ctrl并且检测到相关技能施放，正读条
	if IsCtrl and not IsAlt and not IsShift then  
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitCastingInfo(JianCeDuiXiang)
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在施法，就打断之
			Cnt = "P "
			QieHouShou()
			return
		end
	end
	--如果按下Shift并且检测到相关技能施放，倒读条
	if IsShift and not IsAlt and not IsCtrl then  
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo(JianCeDuiXiang)
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在引导通道法术，就打断之
			Cnt = "P "
			QieHouShou()
			return
		end
	end
	--第一时间取消翔龙在天
	if select(2, GetActionInfo(72)) == 115057 then
		Cnt = "P "
		XiangLongZaiTian()
		return
	end
	--碧玉疾风
	if not Talent_BiYuJiFeng then		--没点碧玉疾风天赋就忽略之
		Insert_BiYuJiFeng = nil
	end
	if Insert_BiYuJiFeng and CDBiYuJiFeng < gcd and power >= 1 then	
		Cnt = "P "
		BiYuJiFeng()
		return
	elseif Insert_BiYuJiFeng and CDBiYuJiFeng < gcd and power < 1 then
		Cnt = "P "
		MengHuZhang()
		return
	end
	--神鹤引项踢
	if Insert_ShenHeYinXiangTi then	
		--真气<=1，且能量不满，且豪能酒CD，使用豪能酒
		if power <= 1 and EnG < EnGMax and CDHaoNengJiu < gcd then
			Cnt = "P "
			HaoNengJiu()
			return
		end
		--真气>=3，使用神鹤引项踢
		if power >= 3 then
			Cnt = "P "
			ShenHeYinXiangTi()
			return
		end
		--真气<3，使用猛虎掌
		if power < 3 then
			Cnt = "P "
			MengHuZhang()
			return
		end
	end
	--扫堂腿
	if not Talent_SaoTangTui then		--没点扫堂腿天赋就忽略之
		Insert_SaoTangTui = nil
	end
	if (Insert_SaoTangTui or IsAlt and IsCtrl and not IsShift) and CDSaoTangTui < gcd then
		Cnt = "P "
		SaoTangTui()
		return
	end
end

------------------------------正文-------------------------------

frame:SetScript("OnUpdate", function(self, elapsed)              -- elapsed：距上次执行该事件过去的时间
	updateElapsed = updateElapsed + elapsed
	if updateElapsed > 0.01 then              -- 常量TOOLTIP_UPDATE_TIME：【信息提示】更新间隔，0.2秒
		updateElapsed = 0
		
		Cnt = ""
		IsCombat = UnitAffectingCombat("player")	-- 是否在战斗状态
		GetSelfEquipments()
		GetAllCoolDown()
		GetAllHP()
		GetSelfMP()
		GetAllBuff()
		GetAllDebuff()
		IsAlt = IsAltKeyDown()					        -- 是否按下Alt键
		IsCtrl = IsControlKeyDown()				        -- 是否按下Ctrl键
		IsShift = IsShiftKeyDown()				        -- 是否按下Ctrl键
		power = UnitPower("player",  12)		        -- 监测真气值
		GetSelfTalents()						        -- 检测天赋
		gcd = CDMengHuZhang + 0.1		                -- 公共cd
		IfIn10yard = CheckInteractDistance("target", 3)	-- 判断是否在近战范围
		unitLevel = UnitLevel("target")                 -- 目标等级
		
		--电容20层提醒
		if BuffHuangDiDeRongDianPiJia1 and lastDianRong == 19 and BuffHuangDiDeRongDianPiJia2 == 20 then
			PlaySoundFile("Sound\\1.mp3")
		end
		lastDianRong = BuffHuangDiDeRongDianPiJia2
		if BuffHuangDiDeRongDianPiJia2 < 5 then
			Lock_SuiYuShanDian = 0
		end		
		
		local PlayerClass
		PlayerClass = select(2, UnitClass("player"))
		IfIn10yard = CheckInteractDistance("target", 3)		-- 10码内
		
		if PlayerClass == "MONK" then
			Cnt = "P "
			if Index_Strategy == 1 then
				ForBoss()
			elseif Index_Strategy == 2 then
				LittleAOE()
			elseif Index_Strategy == 3 then
				AOE()
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
		Cnt = Cnt.."\nF"..Index_Strategy
		self.text:SetText(Cnt)
	end
end)

---------------------正文-------------------
-- 策略
-- 1 猛虎掌 0000 2 旭日东升踢 0008 3 幻灭踢 0080 4 豪能酒 0088 5 切喉手 0800 6 轮回之触 0808 
-- 7 风领主之击 0880 8 升龙霸 0888 9 怒雷破 8000 0 真气波 8008 Y 风火雷电 8080 G 神鹤引项踢 8088
function MengHuZhang()		--猛虎掌
	Cnt = Cnt.."1  "..select(1, GetSpellInfo(100780))		--1
end
function XuRiDongShengTi()		--旭日东升踢
	Cnt = Cnt.."2  "..select(1, GetSpellInfo(107428))		--2
end
function HuanMieTi()		--幻灭踢
	Cnt = Cnt.."3  "..select(1, GetSpellInfo(100784))		--3
end
function HaoNengJiu()		--豪能酒
	Cnt = Cnt.."4  "..select(1, GetSpellInfo(115288))		--4
end
function QieHouShou()		--切喉手
	Cnt = Cnt.."5  "..select(1, GetSpellInfo(116705))		--5
end
function LunHuiZhiChu()		--轮回之触
	Cnt = Cnt.."6  "..select(1, GetSpellInfo(115080))		--6
end
function FengLingZhuZhiJi()		--风领主之击
	Cnt = Cnt.."7  "..select(1, GetSpellInfo(205320))		--7
end
function ShengLongBa()		--升龙霸
	Cnt = Cnt.."8  "..select(1, GetSpellInfo(152175))		--8
end
function NuLeiPo()		--怒雷破
	Cnt = Cnt.."9  "..select(1, GetSpellInfo(113656))		--9
end
function ZhenQiBo()		--真气波
	Cnt = Cnt.."0  "..select(1, GetSpellInfo(115098))		--0
end
function FengHuoLeiDian()		--风火雷电
	Cnt = Cnt.."Y  "..select(1, GetSpellInfo(137639))		--Y
end
function ShenHeYinXiangTi()		--神鹤引项踢
	Cnt = Cnt.."G  "..select(1, GetSpellInfo(101546))		--G
end
function BiYuJiFeng()		--碧玉疾风
	Cnt = Cnt.."H  "..select(1, GetSpellInfo(116847))		--H
end
function SuiYuShanDian()		--碎玉闪电
	Cnt = Cnt.."J  "..select(1, GetSpellInfo(117952))		--J
end
function SaoTangTui()		--扫堂腿
	Cnt = Cnt.."E  "..select(1, GetSpellInfo(119381))		--E
end
function ZhenQiTu()		--真气突
	Cnt = Cnt.."Q  "..select(1, GetSpellInfo(115008))		--Q
end
function XiangLongZaiTian()		--翔龙在天
	Cnt = Cnt.."`  "..select(1, GetSpellInfo(101545))		--`  激活时变115057
end
---------正文---------------------------------------------------------------------------
function AddPowerCircle()
	--攒气循环
	--点穴踢时，且旭日东升踢CD，使用旭日东升踢
	if (BuffBingQiNingShen > 0 or power >= 2) and BuffDianXueTi1 and CDXuRiDongShengtTi < gcd then
		XuRiDongShengTi()
		return
	end
	--使用无锁神鹤引项踢
	if BuffBingQiNingShen > 0 and (Lock_ShenHeYinXiangTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		ShenHeYinXiangTi()
		return
	end
	--使用无锁免费幻灭踢
	if power >=1 and (BuffHuanMieTi > 0 or BuffBingQiNingShen1) and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
	--真气波CD，使用真气波
	if CDZhenQiBo < gcd and BuffBingQiNingShen == 0 and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	--皇帝的容电皮甲层数>=20，且人物静止，使用碎玉闪电
	if BuffHuangDiDeRongDianPiJia2 >= 20 and Lock_SuiYuShanDian == 0 and GetUnitSpeed("player") == 0 and BuffBingQiNingShen == 0 then
		SuiYuShanDian()
		return
	end
	--真气<4，使用无锁猛虎掌
	if EnG >= 50 and power <= 4 and (Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		MengHuZhang()
		return
	end
	--使用无锁幻灭踢
	if power >= 5 and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
	--使用无锁猛虎掌
	if EnG >= 50 and Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi then
		MengHuZhang()
		return
	end
	--使用无锁幻灭踢
	if power >= 2 and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
end

function MinusPowerCircle()
	--泄气循环
	--真气>=2，且旭日东升踢CD，使用旭日东升踢
	if (power >= 2 or BuffBingQiNingShen > 0) and CDXuRiDongShengtTi < gcd then
		XuRiDongShengTi()
		return
	end
	--真气>=2，且风领主之击CD，使用风领主之击
	if power >= 2 and CDFengLingZhuZhiJi < gcd then
		FengLingZhuZhiJi()
		return
	end
	--使用无锁神鹤引项踢
	if BuffBingQiNingShen > 0 and (Lock_ShenHeYinXiangTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		ShenHeYinXiangTi()
		return
	end
	--使用无锁幻灭踢
	if (power >= 2 or power >=1 and BuffHuanMieTi > 0) and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
	--真气波CD，使用真气波
	if CDZhenQiBo < gcd and BuffBingQiNingShen == 0 and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	--皇帝的容电皮甲层数>=20，且人物静止，使用碎玉闪电
	if BuffHuangDiDeRongDianPiJia2 >= 20 and Lock_SuiYuShanDian == 0 and GetUnitSpeed("player") == 0 and BuffBingQiNingShen == 0 then
		SuiYuShanDian()
		return
	end
	--真气<4，使用无锁猛虎掌
	if EnG >= 50 and power <= 4 and (Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		MengHuZhang()
		return
	end
	--使用无锁猛虎掌
	if EnG >= 50 and Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi then
		MengHuZhang()
		return
	end
end

function AOEAddPowerCircle()
	--攒气循环
	--点穴踢时，且旭日东升踢CD，使用旭日东升踢
	if (BuffBingQiNingShen > 0 or power >= 2) and BuffDianXueTi1 and CDXuRiDongShengtTi < gcd then
		XuRiDongShengTi()
		return
	end
	--使用无锁神鹤引项踢
	if BuffBingQiNingShen > 0 and (Lock_ShenHeYinXiangTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		ShenHeYinXiangTi()
		return
	end
	--使用无锁免费幻灭踢
	if power >=1 and (BuffHuanMieTi > 0 or BuffBingQiNingShen1) and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
	--真气波CD，使用真气波
	if CDZhenQiBo < gcd and BuffBingQiNingShen == 0 and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	--皇帝的容电皮甲层数>=20，且人物静止，使用碎玉闪电
	if BuffHuangDiDeRongDianPiJia2 >= 20 and Lock_SuiYuShanDian == 0 and GetUnitSpeed("player") == 0 and BuffBingQiNingShen == 0 then
		SuiYuShanDian()
		return
	end
	--真气<4，使用无锁猛虎掌
	if EnG >= 50 and power <= 4 and (Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		MengHuZhang()
		return
	end
	--使用无锁神鹤引项踢
	if power >= 5 and (Lock_ShenHeYinXiangTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		ShenHeYinXiangTi()
		return
	end
	--使用无锁猛虎掌
	if EnG >= 50 and Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi then
		MengHuZhang()
		return
	end
	--使用无锁幻灭踢
	if power >= 2 and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
end

function AOEMinusPowerCircle()
	--泄气循环
	--使用无锁神鹤引项踢
	if BuffBingQiNingShen > 0 and (Lock_ShenHeYinXiangTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		ShenHeYinXiangTi()
		return
	end
	--升龙霸天赋下，真气>=2，且旭日东升踢CD，且怒雷破已用，且升龙霸CD，使用旭日东升踢
	if Talent_ShengLongBa and (power >= 2 or BuffBingQiNingShen > 0) and CDXuRiDongShengtTi < gcd and CDNuLeiPo > gcd and CDShengLongBa < gcd then
		XuRiDongShengTi()
		return
	end
	--真气>=2，且风领主之击CD，使用风领主之击
	if power >= 2 and CDFengLingZhuZhiJi < gcd then
		FengLingZhuZhiJi()
		return
	end
	--使用无锁免费幻灭踢
	if power >=1 and (BuffHuanMieTi > 0 or BuffBingQiNingShen1) and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
	--使用无锁神鹤引项踢
	if power >= 3 and (Lock_ShenHeYinXiangTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		ShenHeYinXiangTi()
		return
	end
	--真气波CD，使用真气波
	if CDZhenQiBo < gcd and BuffBingQiNingShen == 0 and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	--皇帝的容电皮甲层数>=20，且人物静止，使用碎玉闪电
	if BuffHuangDiDeRongDianPiJia2 >= 20 and Lock_SuiYuShanDian == 0 and GetUnitSpeed("player") == 0 and BuffBingQiNingShen == 0 then
		SuiYuShanDian()
		return
	end
	--真气<4，使用无锁猛虎掌
	if EnG >= 50 and power <= 4 and (Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		MengHuZhang()
		return
	end
	--使用无锁猛虎掌
	if EnG >= 50 and Lock_MengHuZhang == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi then
		MengHuZhang()
		return
	end
	--使用无锁幻灭踢
	if (power >= 2 or power >=1 and BuffHuanMieTi > 0) and (Lock_HuanMieTi == 0 or Talent_LianJi and BuffLianJi == 0 or not Talent_LianJi) then
		HuanMieTi()
		return
	end
end

function ForBoss()
	--单体Boss
	--怒雷破在引导中，什么也不做（屏气凝神期间，引导至旭日东升踢CD）
	IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo("player")
	if IfCasting == select(1, GetSpellInfo(113656)) and not (BuffBingQiNingShen > 0 and CDXuRiDongShengtTi < gcd) then
		Cnt = Cnt..""
		return
	end
	--引导碎玉闪电期间，啥也不干
	if IfCasting == select(1, GetSpellInfo(117952)) then
		Cnt = Cnt..""
		return
	end
	
	--连击天赋下用翔龙、真气波保持连击
	if Talent_LianJi and not IfIn10yard and BuffLianJi < 1 and BuffLianJi2 >= 6 and CDZhenQiBo < gcd and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	if Talent_LianJi and not IfIn10yard and BuffLianJi < 1 and BuffLianJi2 >= 6 and CDXiangLongZaiTian < gcd then
		XiangLongZaiTian()
		return
	end
	
	--风火雷电CD，身上没有风火雷电Buff,按下Alt，卡怒雷破CD，就用风火雷电
	if not Talent_BingQiNingShen and CDFengHuoLeiDian < gcd and BuffFengHuoLeiDian == 0 and IsAlt and not IsShift and not IsCtrl and CDNuLeiPo < 8 then
		FengHuoLeiDian()
		return
	end

	--轮回之触CD，就用轮回之触
	if CDLunHuiZhiChu < gcd and (unitLevel >= 112 or unitLevel < 0) then
		LunHuiZhiChu()
		return
	end
	--真气<=1，且能量不满，且豪能酒CD，使用豪能酒
	if not BuffBingQiNingShen1 and power <= 1 and EnG < EnGMax and CDHaoNengJiu < gcd then
		HaoNengJiu()
		return
	end
	--屏气凝神天赋下，自动释放屏气凝神（怒雷破刚引导完）
    if Talent_BingQiNingShen and CDBingQiNingShen < gcd and CDNuLeiPo > 12 and not IfCasting then
		FengHuoLeiDian()
		return
	end
	--真气>=3，且怒雷破CD，使用怒雷破
	if (power >= Qi_NuLeiPo or BuffBingQiNingShen > 0) and CDNuLeiPo < gcd and (not Talent_BingQiNingShen or Talent_BingQiNingShen and (CDBingQiNingShen > 8 or CDBingQiNingShen < 4 or BuffBingQiNingShen > 0)) then
		NuLeiPo()
		return
	end
	--怒雷破没CD，且旭日东升踢没CD，且升龙霸CD，近战范围内，使用升龙霸
	if Talent_ShengLongBa and CDNuLeiPo > gcd and CDXuRiDongShengtTi > gcd and CDShengLongBa < gcd and IfIn10yard then
		ShengLongBa()
		return
	end

	--怒雷破刚用完，泄气循环，快好了攒气循环
	if CDNuLeiPo < 4 and power < 5 then
		AddPowerCircle()
		return
	else
		MinusPowerCircle()
		return
	end
	
	--否则，什么都不干
	Cnt = Cnt..""
	return
end

function LittleAOE()
	--2目标以上
	--怒雷破在引导中，什么也不做
	IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo("player")
	if IfCasting == select(1, GetSpellInfo(113656)) and not (BuffBingQiNingShen > 0 and CDXuRiDongShengtTi < gcd) then
		Cnt = Cnt..""
		return
	end
	--引导碎玉闪电期间，啥也不干
	if IfCasting == select(1, GetSpellInfo(117952)) then
		Cnt = Cnt..""
		return
	end
	--第一时间取消翔龙在天
	if select(2, GetActionInfo(72)) ~= 101545 then
		XiangLongZaiTian()
		return
	end
	
	--连击天赋下用翔龙、真气波保持连击
	if Talent_LianJi and not IfIn10yard and BuffLianJi < 1 and BuffLianJi2 >= 6 and CDZhenQiBo < gcd and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	if Talent_LianJi and not IfIn10yard and BuffLianJi < 1 and BuffLianJi2 >= 6 and CDXiangLongZaiTian < gcd then
		XiangLongZaiTian()
		return
	end

	--轮回之触CD，就用轮回之触
	if CDLunHuiZhiChu < gcd and (unitLevel >= 112 or unitLevel < 0) then
		LunHuiZhiChu()
		return
	end
	
	--风火雷电CD，身上没有风火雷电Buff，卡怒雷破CD，就用风火雷电
	if not Talent_BingQiNingShen and CDFengHuoLeiDian < gcd and BuffFengHuoLeiDian == 0 and CDNuLeiPo < gcd then
		FengHuoLeiDian()
		return
	end
	--真气<=1，且能量不满，且豪能酒CD，使用豪能酒
	if not BuffBingQiNingShen1 and power <= 1 and EnG < EnGMax and CDHaoNengJiu < gcd then
		HaoNengJiu()
		return
	end
	--怒雷破没CD，且旭日东升踢没CD，且升龙霸CD，近战范围内，使用升龙霸
	if CDNuLeiPo > gcd and CDXuRiDongShengtTi > gcd and CDShengLongBa < gcd and IfIn10yard then
		ShengLongBa()
		return
	end
	--屏气凝神天赋下，自动释放屏气凝神（怒雷破刚引导完）
    if Talent_BingQiNingShen and CDBingQiNingShen < gcd and CDNuLeiPo > 12 and not IfCasting then
		FengHuoLeiDian()
		return
	end
	--真气>=3，且怒雷破CD，(风火雷电可用或再用)，使用怒雷破
	if (power >= Qi_NuLeiPo or BuffBingQiNingShen > 0) and CDNuLeiPo < gcd and (not Talent_BingQiNingShen and (CDFengHuoLeiDian > 3 or BuffFengHuoLeiDian > 0) or Talent_BingQiNingShen and (CDBingQiNingShen > 8 or CDBingQiNingShen < 4 or BuffBingQiNingShen > 0)) then
		NuLeiPo()
		return
	end

	--怒雷破刚用完，泄气循环，快好了攒气循环
	if CDNuLeiPo < 4 and power < 5 then
		AddPowerCircle()
		return
	else
		MinusPowerCircle()
		return
	end
	
	--否则，什么都不干
	Cnt = Cnt..""
	return
end

function AOE()
	--6目标以上
	--怒雷破在引导中，什么也不做
	IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo("player")
	if IfCasting == select(1, GetSpellInfo(113656)) and not (BuffBingQiNingShen > 0 and CDXuRiDongShengtTi < gcd) then
		Cnt = Cnt..""
		return
	end
	--引导碎玉闪电期间，啥也不干
	if IfCasting == select(1, GetSpellInfo(117952)) then
		Cnt = Cnt..""
		return
	end
	--第一时间取消翔龙在天
	if select(2, GetActionInfo(72)) ~= 101545 then
		XiangLongZaiTian()
		return
	end
	
	--连击天赋下用翔龙、真气波保持连击
	if Talent_LianJi and not IfIn10yard and BuffLianJi < 1 and BuffLianJi2 >= 6 and CDZhenQiBo < gcd and Talent_ZhenQiBo then
		ZhenQiBo()
		return
	end
	if Talent_LianJi and not IfIn10yard and BuffLianJi < 1 and BuffLianJi2 >= 6 and CDXiangLongZaiTian < gcd then
		XiangLongZaiTian()
		return
	end
	
	--风火雷电CD，身上没有风火雷电Buff，卡怒雷破CD，就用风火雷电
	if not Talent_BingQiNingShen and CDFengHuoLeiDian < gcd and BuffFengHuoLeiDian == 0 and CDNuLeiPo < gcd then
		FengHuoLeiDian()
		return
	end
	--真气<=1，且能量不满，且豪能酒CD，使用豪能酒
	if not BuffBingQiNingShen1 and power <= 1 and EnG < EnGMax and CDHaoNengJiu < gcd then
		HaoNengJiu()
		return
	end
	--怒雷破没CD，且旭日东升踢没CD，且升龙霸CD，近战范围内，使用升龙霸
	if CDNuLeiPo > gcd and CDXuRiDongShengtTi > gcd and CDShengLongBa < gcd and IfIn10yard then
		ShengLongBa()
		return
	end
	--屏气凝神天赋下，自动释放屏气凝神（怒雷破刚引导完）
    if Talent_BingQiNingShen and CDBingQiNingShen < gcd and CDNuLeiPo > 12 and not IfCasting then
		FengHuoLeiDian()
		return
	end
	--真气>=3，且怒雷破CD，(风火雷电可用或再用)，使用怒雷破
	if (power >= Qi_NuLeiPo or BuffBingQiNingShen > 0) and CDNuLeiPo < gcd and (not Talent_BingQiNingShen and (CDFengHuoLeiDian > 3 or BuffFengHuoLeiDian > 0) or Talent_BingQiNingShen and (CDBingQiNingShen > 8 or CDBingQiNingShen < 4 or BuffBingQiNingShen > 0)) then
		NuLeiPo()
		return
	end

	--怒雷破刚用完，泄气循环，快好了攒气循环
	if CDNuLeiPo < 4 and power < 5 then
		AOEAddPowerCircle()
		return
	else
		AOEMinusPowerCircle()
		return
	end
	
	--否则，什么都不干
	Cnt = Cnt..""
	return
end