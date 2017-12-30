------------------------------------------------------------
-- DPSerAnChun.lua
------------------------------------------------------------

local UnitExists = UnitExists                                                     -- 声明各关键词
local UnitIsUnit = UnitIsUnit
local GetUnitSpeed = GetUnitSpeed
local GetPlayerFacing = GetPlayerFacing
local GetUnitPitch = GetUnitPitch
local GetPlayerMapPosition = GetPlayerMapPosition
local format = format
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME
local KuaiZhaoXieLve = 100
local KuaiZhaoGeLie = 100
local KuaiZhaoYueHuoShu = 100
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

local frame = CreateFrame("Button", "AnChun", UIParent)                  -- 定义一个框体frame
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
		if ChatMessage == "DPSerYeDe_I_S01" then
			Index_Strategy = 1
		end
		if ChatMessage == "DPSerYeDe_I_S02" then
			Index_Strategy = 2
		end
		if ChatMessage == "DPSerYeDe_I_S03" then
			Index_Strategy = 3
		end
		if ChatMessage == "DPSerYeDe_I_S04" then
			Index_Strategy = 0
			Insert_HuaShen = nil
			Insert_TaiFeng = nil
			-- Insert_KuangBao = nil
			-- Insert_GeSui = nil
		end
		-- 化身
		if ChatMessage == "DPSerAnChun_HuaShen" then
			Insert_HuaShen = 1
		end
		-- 台风
		if ChatMessage == "DPSerAnChun_TaiFeng" then
			Insert_TaiFeng = 1
		end
		-- --狂暴
		-- if ChatMessage == "DPSerAnChun_KuangBao" then
		-- 	Insert_KuangBao = 1
		-- end
		-- --割碎
		-- if ChatMessage == "DPSerAnChun_GeSui" then
		-- 	Insert_GeSui = 1
		-- end
	end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		--从技能队列中清空”化身“
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 102560 then
			Insert_HuaShen = nil
		end
		--从技能队列中清空”台风“
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 132469 then
			Insert_TaiFeng = nil
		end
		-- --从技能队列中清空”狂暴“
		-- if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and (spellID == 106951 or spellID == 102543) then
		-- 	Insert_KuangBao = nil
		-- end
		-- --从技能队列中清空”割碎“
		-- if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and (spellID == 22570 or spellID == 236026) then
		-- 	Insert_GeSui = nil
		-- end
		-- --计算快照值
		-- if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 1822 then	--成功释放斜掠时
		-- 	KuaiZhaoXieLve = 100
		-- 	if BuffMengHuZhiNu > 0 then
		-- 		KuaiZhaoXieLve = KuaiZhaoXieLve + 15
		-- 	end
		-- 	if BuffXueXingZhuaJi > 0 then
		-- 		KuaiZhaoXieLve = KuaiZhaoXieLve + 50
		-- 	end
		-- 	if BuffYeManPaoXiao > 0 then
		-- 		KuaiZhaoXieLve = KuaiZhaoXieLve + 25
		-- 	end
		-- 	if BuffQianXing1 or BuffYingDun1 then
		-- 		KuaiZhaoXieLve = KuaiZhaoXieLve + 100
		-- 	end
		-- 	--DEFAULT_CHAT_FRAME:AddMessage(spellName..", "..KuaiZhaoXieLve)
		-- end
		-- if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 1079 then	--成功释放割裂时
		-- 	KuaiZhaoGeLie = 100
		-- 	if BuffMengHuZhiNu > 0 then
		-- 		KuaiZhaoGeLie = KuaiZhaoGeLie + 15
		-- 	end
		-- 	if BuffXueXingZhuaJi > 0 then
		-- 		KuaiZhaoGeLie = KuaiZhaoGeLie + 50
		-- 	end
		-- 	if BuffYeManPaoXiao > 0 then
		-- 		KuaiZhaoGeLie = KuaiZhaoGeLie + 25
		-- 	end
		-- 	--DEFAULT_CHAT_FRAME:AddMessage(spellName..", "..KuaiZhaoGeLie)
		-- end
		-- if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 155625 then	--成功释放月火术时
		-- 	KuaiZhaoYueHuoShu = 100
		-- 	if BuffMengHuZhiNu > 0 then
		-- 		KuaiZhaoYueHuoShu = KuaiZhaoYueHuoShu + 15
		-- 	end
		-- 	if BuffYeManPaoXiao > 0 then
		-- 		KuaiZhaoYueHuoShu = KuaiZhaoYueHuoShu + 25
		-- 	end
		-- end
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

local function GetAllCoolDown()						-- 监测技能CD
	Charge_XinYue 				    = GetSpellCharges(202767)				-- 新月的充能数
	CDYueHuoShu                     = GetOneCoolDown(8921)					-- 月火术
	CDTaiFeng                       = GetOneCoolDown(132469)				-- 台风
	CDHuaShen			            = GetOneCoolDown(102560)				-- 化身
	CDXinYue                        = GetOneCoolDown(202767)				-- 新月
	CDBanYue                        = GetOneCoolDown(202768)				-- 半月
	CDManYue                        = GetOneCoolDown(202771)				-- 满月
	CDAiLuEnDeZhanShi               = GetOneCoolDown(202425)				-- 艾露恩的战士
	CDRiGuangShu                    = GetOneCoolDown(78675)					-- 日光术
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
	GetOneBuff("player", 24858)  -- 枭兽形态
	BuffXiaoShouXingTai1 = Temp1
	BuffXiaoShouXingTai2 = Temp2
	BuffXiaoShouXingTai3 = Temp3
	BuffXiaoShouXingTai4 = Temp4
	if BuffXiaoShouXingTai1 then
		BuffXiaoShouXingTai = BuffXiaoShouXingTai3
	else
		BuffXiaoShouXingTai = 0
	end
	--
	GetOneBuff("player", 239952)  -- 阴晴圆缺
	BuffYinQingYuanQue1 = Temp1
	BuffYinQingYuanQue2 = Temp2
	BuffYinQingYuanQue3 = Temp3
	BuffYinQingYuanQue4 = Temp4
	if BuffYinQingYuanQue1 then
		BuffYinQingYuanQue = BuffYinQingYuanQue3
	else
		BuffYinQingYuanQue = 0
	end
	--
	GetOneBuff("player", 202461)  -- 星尘漂流
	BuffXingChenPiaoLiu1 = Temp1
	BuffXingChenPiaoLiu2 = Temp2
	BuffXingChenPiaoLiu3 = Temp3
	BuffXingChenPiaoLiu4 = Temp4
	if BuffXingChenPiaoLiu1 then
		BuffXingChenPiaoLiu = BuffXingChenPiaoLiu3
	else
		BuffXingChenPiaoLiu = 0
	end
	--
	GetOneBuff("player", 202425)  -- 艾露恩的战士
	BuffAiLuEnDeZhanShi1 = Temp1
	BuffAiLuEnDeZhanShi2 = Temp2
	BuffAiLuEnDeZhanShi3 = Temp3
	BuffAiLuEnDeZhanShi4 = Temp4
	if BuffAiLuEnDeZhanShi1 then
		BuffAiLuEnDeZhanShi = BuffAiLuEnDeZhanShi3
	else
		BuffAiLuEnDeZhanShi = 0
	end
	--
	GetOneBuff("player", 102560)  -- 化身
	BuffHuaShen1 = Temp1
	BuffHuaShen2 = Temp2
	BuffHuaShen3 = Temp3
	BuffHuaShen4 = Temp4
	if BuffHuaShen1 then
		BuffHuaShen = BuffHuaShen3
	else
		BuffHuaShen = 0
	end
	--
	GetOneBuff("player", 164547)  -- 月光增效
	BuffYueGuangZengXiao1 = Temp1
	BuffYueGuangZengXiao2 = Temp2
	BuffYueGuangZengXiao3 = Temp3
	BuffYueGuangZengXiao4 = Temp4
	if BuffYueGuangZengXiao1 then
		BuffYueGuangZengXiao = BuffYueGuangZengXiao3
	else
		BuffYueGuangZengXiao = 0
	end
	--
	GetOneBuff("player", 164545)  -- 日光增效
	BuffRiGuangZengXiao1 = Temp1
	BuffRiGuangZengXiao2 = Temp2
	BuffRiGuangZengXiao3 = Temp3
	BuffRiGuangZengXiao4 = Temp4
	if BuffRiGuangZengXiao1 then
		BuffRiGuangZengXiao = BuffRiGuangZengXiao3
	else
		BuffRiGuangZengXiao = 0
	end
	--
	GetOneBuff("player", 225774)  -- 邪罪契约
	BuffXieZuiQiYue1 = Temp1
	BuffXieZuiQiYue2 = Temp2
	BuffXieZuiQiYue3 = Temp3
	BuffXieZuiQiYue4 = Temp4
	if BuffXieZuiQiYue1 then
		BuffXieZuiQiYue = BuffXieZuiQiYue3
	else
		BuffXieZuiQiYue = 0
	end
	--
	GetOneBuff("player", 191034)  -- 星辰坠落
	BuffXingChenZhuiLuo1 = Temp1
	BuffXingChenZhuiLuo2 = Temp2
	BuffXingChenZhuiLuo3 = Temp3
	BuffXingChenZhuiLuo4 = Temp4
	if BuffXingChenZhuiLuo1 then
		BuffXingChenZhuiLuo = BuffXingChenZhuiLuo3
	else
		BuffXingChenZhuiLuo = 0
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
	--
	GetOneDebuff("target", 164812)  -- 月火术
	DeBuffYueHuoShu1 = Temp1
	DeBuffYueHuoShu2 = Temp2
	DeBuffYueHuoShu3 = Temp3
	DeBuffYueHuoShu4 = Temp4
	if DeBuffYueHuoShu1 and DeBuffYueHuoShu4 == "player" then
		DeBuffYueHuoShu = DeBuffYueHuoShu3
	else
		DeBuffYueHuoShu = 0
	end
	--
	GetOneDebuff("target", 240606)  -- 昼暮祈求_月
	DeBuffZhouMuQiQiu_Yue1 = Temp1
	DeBuffZhouMuQiQiu_Yue2 = Temp2
	DeBuffZhouMuQiQiu_Yue3 = Temp3
	DeBuffZhouMuQiQiu_Yue4 = Temp4
	if DeBuffZhouMuQiQiu_Yue1 and DeBuffZhouMuQiQiu_Yue4 == "player" then
		DeBuffZhouMuQiQiu_Yue = DeBuffZhouMuQiQiu_Yue3
	else
		DeBuffZhouMuQiQiu_Yue = 0
	end
	--
	GetOneDebuff("target", 164815)  -- 阳炎术
	DeBuffYangYanShu1 = Temp1
	DeBuffYangYanShu2 = Temp2
	DeBuffYangYanShu3 = Temp3
	DeBuffYangYanShu4 = Temp4
	if DeBuffYangYanShu1 and DeBuffYangYanShu4 == "player" then
		DeBuffYangYanShu = DeBuffYangYanShu3
	else
		DeBuffYangYanShu = 0
	end
	--
	GetOneDebuff("target", 240607)  -- 昼暮祈求_日
	DeBuffZhouMuQiQiu_Ri1 = Temp1
	DeBuffZhouMuQiQiu_Ri2 = Temp2
	DeBuffZhouMuQiQiu_Ri3 = Temp3
	DeBuffZhouMuQiQiu_Ri4 = Temp4
	if DeBuffZhouMuQiQiu_Ri1 and DeBuffZhouMuQiQiu_Ri4 == "player" then
		DeBuffZhouMuQiQiu_Ri = DeBuffZhouMuQiQiu_Ri3
	else
		DeBuffZhouMuQiQiu_Ri = 0
	end
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
	EnG = UnitPower("player", 8)
	EnGMax = UnitPowerMax("player", 8)
	EnGP = EnG/EnGMax
end

function IfBaoFa()
	BaoFaJieDuan = false
	if BuffHuaShen1 then
		BaoFaJieDuan = true
		return
	end
	if BuffXieZuiQiYue1 then
		BaoFaJieDuan = true
		return
	end
end

function GetSelfTalents()						-- 监测天赋
	Talent_ZiRanZhiLi                      = select(4, GetTalentInfo(1, 1, 1))					--自然之力
	Talent_AiLuEnDeZhanShi                 = select(4, GetTalentInfo(1, 2, 1))					--艾露恩的战士
	Talent_XingChenLingZhu                 = select(4, GetTalentInfo(1, 3, 1))					--星辰领主
	Talent_XinSheng                        = select(4, GetTalentInfo(2, 1, 1))					--新生
	Talent_YeXingWeiYi                     = select(4, GetTalentInfo(2, 2, 1))					--野性位移
	Talent_YeXingChongFeng                 = select(4, GetTalentInfo(2, 3, 1))					--野性冲锋
	Talent_YeXingQinHe                     = select(4, GetTalentInfo(3, 1, 1))					--野性亲和
	Talent_ShouHuQinHe                     = select(4, GetTalentInfo(3, 2, 1))					--守护亲和
	Talent_HuiFuQinHe                      = select(4, GetTalentInfo(3, 3, 1))					--恢复亲和
	Talent_ManLiMengJi                     = select(4, GetTalentInfo(4, 1, 1))					--蛮力猛击
	Talent_QunTiChanRao                    = select(4, GetTalentInfo(4, 2, 1))	     			--群体缠绕
	Talent_TaiFeng                         = select(4, GetTalentInfo(4, 3, 1))	     			--台风
	Talent_CongLinZhiHun                   = select(4, GetTalentInfo(5, 1, 1))		 			--丛林之魂
	Talent_HuaShen                         = select(4, GetTalentInfo(5, 2, 1))					--化身：艾露恩之眷
	Talent_XingChenYaoBan                  = select(4, GetTalentInfo(5, 3, 1))					--星辰耀斑
	Talent_ZhuiXing                        = select(4, GetTalentInfo(6, 1, 1))					--坠星
	Talent_GouTongXingJie                  = select(4, GetTalentInfo(6, 2, 1))					--沟通星界
	Talent_YuanGuZhuFu                     = select(4, GetTalentInfo(6, 3, 1))					--远古祝福
	Talent_AiLuEnZhiNu                     = select(4, GetTalentInfo(7, 1, 1))					--艾露恩之怒
	Talent_XingChenPiaoLiu                 = select(4, GetTalentInfo(7, 2, 1))					--星辰漂流
	Talent_ZiRanPingHeng                   = select(4, GetTalentInfo(7, 3, 1))					--自然平衡
end

function GetSelfEquipments()						-- 监测装备
	EquipYueHuoJian           = IsEquippedItem(144295)		--月火肩
	EquipCongLinJie           = IsEquippedItem(151636)		--丛林戒
end

function StatiCoverRate()
	--统计Buff、DeBuff覆盖率
	if CoverTime_All > 1 and not IsCombat then
		DEFAULT_CHAT_FRAME:AddMessage("GeLie covered "..floor(10000*CoverTime_GeLie/CoverTime_All)*0.01 .."%")
		DEFAULT_CHAT_FRAME:AddMessage("ASMdSiChe covered "..floor(10000*CoverTime_AShaManDeSiChe/CoverTime_All)*0.01 .."%")
	end
	if not IsCombat then
		CoverTime_GeLie = 0
		CoverTime_AShaManDeSiChe = 0
		--CoverTime_YeManPaoXiao = 0
		CoverTime_All = 1
	else
		if DeBuffGeLie > 0 then
			CoverTime_GeLie = CoverTime_GeLie + 1
		end
		if DeBuffAShaManDeSiChe > 0 then
			CoverTime_AShaManDeSiChe = CoverTime_AShaManDeSiChe + 1
		end
		CoverTime_All = CoverTime_All + 1
	end
end

function ClearSpellList()		--清除插队队列
	Insert_TongJi = nil
	Insert_ManLiMengJi = nil
	Insert_KuangBao = nil
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
		if IfCasting and (not InterruptAble) and CDRiGuangShu < 0 then
			-- 如果目标正在施法，就打断之
			Cnt = "P "
			Cast_RiGuangShu()
			return
		end
	end
	--如果按下Shift并且检测到相关技能施放，倒读条
	if IsShift and not IsAlt and not IsCtrl then  
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo(JianCeDuiXiang)
		if IfCasting and (not InterruptAble) and CDRiGuangShu < 0 then
			-- 如果目标正在引导通道法术，就打断之
			Cnt = "P "
			Cast_RiGuangShu()
			return
		end
	end
	
	-- 化身
	if Insert_HuaShen and CDHuaShen < gcd then
		Cnt = "P "
		Cast_HuaShen()
		return
	end
	-- 化身
	if Insert_TaiFeng and CDTaiFeng < gcd then
		Cnt = "P "
		Cast_TaiFeng()
		return
	end
	
	--正在读条就发傻
	-- IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitCastingInfo("player")
	-- if IfCasting then	
	-- 	Cnt = "P "
	-- 	return
	-- end
	--如果不处于鹌鹑状态，就变成鹌鹑状态
	if not BuffXiaoShouXingTai1 then
		Cnt = "P 7"
		return
	end
end

--技能按键
function Cast_MingYueDaJi()		--明月打击
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."1  "..select(1, GetSpellInfo(194153))	--1
end
function Cast_YangYanZhiNu()	--阳炎之怒
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 8*K_EnG_By_HuaShen then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."2  "..select(1, GetSpellInfo(190984))	--2
end
function Cast_YueHuoShu()		--月火术
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 3 then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."3  "..select(1, GetSpellInfo(8921))		--3
end
function Cast_YangYanShu()		--阳炎术
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 3 then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."4  "..select(1, GetSpellInfo(93402))	--4
end
function Cast_RiGuangShu()		--日光术
	Cnt = Cnt.."5  "..select(1, GetSpellInfo(78675))	--5
end
function Cast_XingChenZhuiLuo()	--星辰坠落
	Cnt = Cnt.."6  "..select(1, GetSpellInfo(191034))	--6
end
function Cast_XingYongShu()		--星涌术
	Cnt = Cnt.."7  "..select(1, GetSpellInfo(78674))	--7
end
function Cast_XinYue()			--新月
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 10 then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."8  "..select(1, GetSpellInfo(202767))	--8
end
function Cast_BanYue()			--半月
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 20 then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."8  "..select(1, GetSpellInfo(202768))	--8
end
function Cast_ManYue()			--满月
	-- 避免能量溢出
	if (Index_Strategy == 1 or BuffXingChenZhuiLuo1) and EnGMax - EnG <= 40 then
        Cast_XingYongShu()
        return
    elseif Index_Strategy == 2 and EnGMax - EnG <= 12*K_EnG_By_HuaShen then
        Cast_XingChenZhuiLuo()
        return
	end
	Cnt = Cnt.."8  "..select(1, GetSpellInfo(202771))	--8
end
function Cast_AiLuEnDeZhanShi()	--艾露恩的战士
	Cnt = Cnt.."9  "..select(1, GetSpellInfo(202425))	--9
end
function Cast_HuaShen()			--化身
	Cnt = Cnt.."0  "..select(1, GetSpellInfo(102560))	--0
end
function Cast_TaiFeng()			--台风
	Cnt = Cnt.."Y  "..select(1, GetSpellInfo(132469))	--Y
end

--单体Boss
function AttackForBoss()
	-- 非战斗时搓愤怒
	if not IsCombat and (not CastingName or CastingendTime-GetTime() < 0.5) then
		Cast_YangYanZhiNu()
		return
	end
	-- 艾露恩的战士
	if Talent_AiLuEnDeZhanShi and CDAiLuEnDeZhanShi < gcd and BuffAiLuEnDeZhanShi == 0 then
		Cast_AiLuEnDeZhanShi()
		return
	end
	-- 新月
    if gcd < 0.5 and Turn_Moon == "NewMoon" and not (CastingName == select(1, GetSpellInfo(202767)) or castingID == select(1, GetSpellInfo(202768)) or castingID == select(1, GetSpellInfo(202771))) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and (Charge_XinYue == 3 or BaoFaJieDuan and Charge_XinYue > 0) then
    	Cast_XinYue()
    	return
    end
    if gcd < 0.5 and Turn_Moon == "HalfMoon" and not (CastingName == select(1, GetSpellInfo(202767)) or castingID == select(1, GetSpellInfo(202768)) or castingID == select(1, GetSpellInfo(202771))) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and (Charge_XinYue == 3 or BaoFaJieDuan and Charge_XinYue > 0) then
    	Cast_BanYue()
    	return
    end
    if gcd < 0.5 and Turn_Moon == "FullMoon" and not (CastingName == select(1, GetSpellInfo(202767)) or castingID == select(1, GetSpellInfo(202768)) or castingID == select(1, GetSpellInfo(202771))) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and (Charge_XinYue == 3 or BaoFaJieDuan and Charge_XinYue > 0) then
    	Cast_ManYue()
    	return
    end
	-- 月火术
    if gcd < 0.5 and DeBuffYueHuoShu < 6 and (not BaoFaJieDuan or (GetUnitSpeed("player") > 0 and not BuffXingChenPiaoLiu1)) then
    	Cast_YueHuoShu()
    	return
    end
	-- 阳炎术
    if gcd < 0.5 and DeBuffYangYanShu < 4 and (not BaoFaJieDuan or (GetUnitSpeed("player") > 0 and not BuffXingChenPiaoLiu1)) then
    	Cast_YangYanShu()
    	return
    end
	-- 明月打击
    if (not CastingName or CastingendTime-GetTime() < 0.5) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1 or BuffAiLuEnDeZhanShi1) and BuffYueGuangZengXiao > 0 and (BuffYueGuangZengXiao2 >= 2 or BuffAiLuEnDeZhanShi1) then
    	Cast_MingYueDaJi()
    	return
    end
	-- 阳炎之怒
    if (not CastingName or CastingendTime-GetTime() < 0.5) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and BuffRiGuangZengXiao > 0 and BuffRiGuangZengXiao2 >= 2 then
    	Cast_YangYanZhiNu()
    	return
    end
	-- 阳炎之怒
    if (not CastingName or CastingendTime-GetTime() < 0.5) and GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1 then
    	Cast_YangYanZhiNu()
    	return
    end

	--否则，月火术
	if gcd < 0.5 and GetUnitSpeed("player") > 0 and not BuffXingChenPiaoLiu1 then
    	Cast_YueHuoShu()
    	return
    end
	return
end

--中量目标
function AttackForBossAndBuddies()
	-- 非战斗时搓愤怒
	if not IsCombat and (not CastingName or CastingendTime-GetTime() < 0.5) then
		Cast_YangYanZhiNu()
		return
	end
	-- 艾露恩的战士
	if Talent_AiLuEnDeZhanShi and CDAiLuEnDeZhanShi < gcd and BuffAiLuEnDeZhanShi == 0 then
		Cast_AiLuEnDeZhanShi()
		return
	end
	-- 新月
    if gcd < 0.5 and Turn_Moon == "NewMoon" and not (CastingName == select(1, GetSpellInfo(202767)) or castingID == select(1, GetSpellInfo(202768)) or castingID == select(1, GetSpellInfo(202771))) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and (Charge_XinYue == 3 or BaoFaJieDuan and Charge_XinYue > 0) then
    	Cast_XinYue()
    	return
    end
    if gcd < 0.5 and Turn_Moon == "HalfMoon" and not (CastingName == select(1, GetSpellInfo(202767)) or castingID == select(1, GetSpellInfo(202768)) or castingID == select(1, GetSpellInfo(202771))) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and (Charge_XinYue == 3 or BaoFaJieDuan and Charge_XinYue > 0) then
    	Cast_BanYue()
    	return
    end
    if gcd < 0.5 and Turn_Moon == "FullMoon" and not (CastingName == select(1, GetSpellInfo(202767)) or castingID == select(1, GetSpellInfo(202768)) or castingID == select(1, GetSpellInfo(202771))) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and (Charge_XinYue == 3 or BaoFaJieDuan and Charge_XinYue > 0) then
    	Cast_ManYue()
    	return
    end
	-- 月火术
    if gcd < 0.5 and DeBuffYueHuoShu < 6 and (not BaoFaJieDuan or (GetUnitSpeed("player") > 0 and not BuffXingChenPiaoLiu1)) then
    	Cast_YueHuoShu()
    	return
    end
	-- 阳炎术
    if gcd < 0.5 and DeBuffYangYanShu < 4 and (not BaoFaJieDuan or (GetUnitSpeed("player") > 0 and not BuffXingChenPiaoLiu1)) then
    	Cast_YangYanShu()
    	return
    end
	-- 明月打击
    if (not CastingName or CastingendTime-GetTime() < 0.5) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1 or BuffAiLuEnDeZhanShi1) and BuffYueGuangZengXiao > 0 and (BuffYueGuangZengXiao2 >= 2 or BuffAiLuEnDeZhanShi1) then
    	Cast_MingYueDaJi()
    	return
    end
	-- 阳炎之怒
    if (not CastingName or CastingendTime-GetTime() < 0.5) and (GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1) and BuffRiGuangZengXiao > 0 and BuffRiGuangZengXiao2 >= 2 then
    	Cast_YangYanZhiNu()
    	return
    end
	-- 阳炎之怒
    if (not CastingName or CastingendTime-GetTime() < 0.5) and GetUnitSpeed("player") == 0 or BuffXingChenPiaoLiu1 then
    	Cast_YangYanZhiNu()
    	return
    end

	--否则，月火术
	if gcd < 0.5 and GetUnitSpeed("player") > 0 and not BuffXingChenPiaoLiu1 then
    	Cast_YueHuoShu()
    	return
    end
	return
end

--大量目标
function AttackForBuddies()
    	
	--否则，什么都不干
	Cnt = Cnt..""
	return
end

-- ---------------------------正文-------------------------------

frame:SetScript("OnUpdate", function(self, elapsed)              -- elapsed：距上次执行该事件过去的时间
	updateElapsed = updateElapsed + elapsed
	if updateElapsed > 0.1 then              -- 常量TOOLTIP_UPDATE_TIME：【信息提示】更新间隔，0.2秒
		updateElapsed = 0
		
		Cnt = ""
		IsCombat = UnitAffectingCombat("player")	-- 是否在战斗状态
		GetSelfTalents()														--监测天赋
		GetAllCoolDown()
		GetAllHP()
		GetSelfMP()
		GetAllBuff()
		GetAllDebuff()
		IfBaoFa()
		IsAlt = IsAltKeyDown()					-- 是否按下Alt键
		IsCtrl = IsControlKeyDown()				-- 是否按下Ctrl键
		IsShift = IsShiftKeyDown()				-- 是否按下Ctrl键
		GetSelfEquipments()												--监测装备
		LowLevel = UnitLevel("target") ~= -1 and UnitLevel("target") < UnitLevel("player") 					--监测等级
		HighLevel = UnitLevel("target") == -1 or UnitLevel("target") >= UnitLevel("player")					--监测等级
		CastingName, _, _, _, CastingstartTime, CastingendTime, _, castingID, _ = UnitCastingInfo("player")
		actionType, id, subType = GetActionInfo(6)
		if id == 202767 then
			Turn_Moon = "NewMoon"
		elseif id == 202768 then
			Turn_Moon = "HalfMoon"
		elseif id == 202771 then
			Turn_Moon = "FullMoon"
		end
        if BuffHuaShen1 then
		    K_EnG_By_HuaShen = 1.5
		else
			K_EnG_By_HuaShen = 1
		end
		
		local PlayerClass
		_,PlayerClass = UnitClass("player")
		gcd = CDYueHuoShu + 0.1
				
		if PlayerClass == "DRUID" then
			Cnt = "P "
			if Index_Strategy == 1 then
				AttackForBoss()
			elseif Index_Strategy == 2 then
				AttackForBossAndBuddies()
			elseif Index_Strategy == 3 then
				AttackForBuddies()
			elseif Index_Strategy == 0 then
				Cnt = "P "
			end
		else
			Cnt = "P "
		end

		--非战斗时或非猫时，清空插队队列
		if not (IsCombat and BuffXiaoShouXingTai1) then
			ClearSpellList()
		end
		--插队技能
		InsertSpellList()
		--显示目前的策略
		Cnt = Cnt.."\nF"..Index_Strategy
		self.text:SetText(Cnt)
	end
end)
