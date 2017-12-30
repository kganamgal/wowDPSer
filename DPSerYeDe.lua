--DEFAULT_CHAT_FRAME:AddMessage(spellName..", "..UnitPower("player",  12)..", CDNuLeiPo = "..floor(CDNuLeiPo))
------------------------------------------------------------
-- DPSerYeDe.lua
--
-- 
--
-- Edwin
-- 2016-10-04 添加：单个非Boss输出循环，将打断融入循环
-- 2017-01-29 添加：监测挥砍的充能满后自动放一个
-- 2017-01-29 添加：天赋监测
-- 2017-01-30 添加：技能插队功能
-- 2017-01-30 优化：策略函数，用return代替break，并将打断移至技能插队函数中
-- 2017-01-30 优化：快照机制由乘法调整为加法
-- 2017-01-30 重大调整：用一套按键精灵，不同策略在插件内部切换
-- 2017-01-31 添加：非战斗不输出功能（已移除）
-- 2017-02-01 优化：添加不同天赋下Dot的刷新规则
-- 2017-02-02 优化：非咆哮天赋下凶猛撕咬的释放
-- 2017-02-10 优化：4T19输出
-- 2017-02-10 重大调整：改为实际快捷键，而非08088
-- 2017-02-12 添加：装备检测功能
-- 2017-02-20 添加：等级判断
-- 2017-02-26 添加：F3下添加凶猛撕咬
-- 2017-08-31 支持7.3
-- 2017-08-31 移除野蛮咆哮的快照效果，更改了血腥爪机的增伤系数（50→20）
-- 2017-08-31 调整了天赋层数

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

local intoCombatTime = -1
local duration
local energyOverflow = 0
local powerOverflow = 0

local frame = CreateFrame("Button", "YeDe", UIParent)                  			   -- 定义一个框体frame
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

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")								-- 设定该frame关注的事件：战斗信息
frame:RegisterEvent("CHAT_MSG_WHISPER")											-- 设定该frame关注的事件：聊天记录
frame:RegisterEvent("PLAYER_ENTER_COMBAT")										-- 设定该frame关注的事件：进入战斗
frame:RegisterEvent("PLAYER_LEAVE_COMBAT")										-- 设定该frame关注的事件：离开战斗
CombatTextSetActiveUnit("player");

----------------------------监测---------------------------------

frame:SetScript("OnEvent", function(self, event, timestamp, eventType, arg1, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, arg2, spellID, spellName, arg3, extraskillID, extraSkillName, prefix1)
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
			Insert_TongJi = nil
			Insert_ManLiMengJi = nil
			Insert_KuangBao = nil
			Insert_GeSui = nil
		end
		--痛击
		if ChatMessage == "DPSerYeDe_TongJi" then
			Insert_TongJi = 1
		end
		--蛮力猛击（拍晕）
		if ChatMessage == "DPSerYeDe_ManLiMengJi" then
			Insert_ManLiMengJi = 1
		end
		--狂暴
		if ChatMessage == "DPSerYeDe_KuangBao" then
			Insert_KuangBao = 1
		end
		--割碎
		if ChatMessage == "DPSerYeDe_GeSui" then
			Insert_GeSui = 1
		end
	end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		--从技能队列中清空”痛击“
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 106830 then
			Insert_TongJi = nil
		end
		--从技能队列中清空”蛮力猛击“
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 5211 then
			Insert_ManLiMengJi = nil
		end
		--从技能队列中清空”狂暴“
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and (spellID == 106951 or spellID == 102543) then
			Insert_KuangBao = nil
		end
		--从技能队列中清空”割碎“
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and (spellID == 22570 or spellID == 236026) then
			Insert_GeSui = nil
		end
		--计算快照值
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 1822 then	--成功释放斜掠时
			KuaiZhaoXieLve = 100
			if BuffMengHuZhiNu > 0 then
				KuaiZhaoXieLve = KuaiZhaoXieLve + 15
			end
			if BuffXueXingZhuaJi > 0 then
				KuaiZhaoXieLve = KuaiZhaoXieLve + 20
			end
			if BuffQianXing1 or BuffYingDun1 then
				KuaiZhaoXieLve = KuaiZhaoXieLve + 100
			end
			--DEFAULT_CHAT_FRAME:AddMessage(spellName..", "..KuaiZhaoXieLve)
		end
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 1079 then	--成功释放割裂时
			KuaiZhaoGeLie = 100
			if BuffMengHuZhiNu > 0 then
				KuaiZhaoGeLie = KuaiZhaoGeLie + 15
			end
			if BuffXueXingZhuaJi > 0 then
				KuaiZhaoGeLie = KuaiZhaoGeLie + 20
			end
			--DEFAULT_CHAT_FRAME:AddMessage(spellName..", "..KuaiZhaoGeLie)
		end
		if sourceName == UnitName("player") and eventType == "SPELL_CAST_SUCCESS" and spellID == 155625 then	--成功释放月火术时
			KuaiZhaoYueHuoShu = 100
			if BuffMengHuZhiNu > 0 then
				KuaiZhaoYueHuoShu = KuaiZhaoYueHuoShu + 15
			end
		end
	end	

	if event == "COMBAT_LOG_EVENT_UNFILTERED" and eventType == "SPELL_ENERGIZE" and sourceName == UnitName("player") then  		-- 累加溢出的能量和溢出的星		
		numberOverflow = extraSkillName
		typeOverflow = prefix1		-- 3代表能量，4代表连击点
		if typeOverflow == 3 then
			energyOverflow = energyOverflow + numberOverflow
		elseif typeOverflow == 4 then
			powerOverflow = powerOverflow + numberOverflow
		end
	end

	if event == "PLAYER_ENTER_COMBAT" then  		-- 玩家进入战斗时
		-- 将计时和溢出统计清零
		intoCombatTime = GetTime()
		energyOverflow = 0
		powerOverflow = 0
	end
	-- if event == "PLAYER_LEAVE_COMBAT" then  		-- 玩家离开战斗时
	-- 	duration = GetTime() - intoCombatTime
	-- 	local text = ''
	-- 	text = text..'本次战斗用时'..round(duration, 0)..'秒'
	-- 	DEFAULT_CHAT_FRAME:AddMessage(text)
	-- end
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
	CDMengHuZhiNu = GetOneCoolDown(5217)				-- 猛虎之怒
	CDJingLingChongQun = GetOneCoolDown(102355)			-- 精灵虫群
	CDSiSui = GetOneCoolDown(5221)						-- 撕碎
	CDAShaMan = GetOneCoolDown(210722)					-- 阿莎曼的狂乱
	CDGeSui = GetOneCoolDown(22570)						-- 割碎
	CDHuiKan = GetOneCoolDown(202028)					-- 挥砍
	CDYingDun = GetOneCoolDown(58984)					-- 影遁
	CDHuaShen = GetOneCoolDown(102543)					-- 化身
	CDQianXing = GetOneCoolDown(5215)					-- 潜行
	CDManLiMengJi = GetOneCoolDown(5211)				-- 蛮力猛击
	CDKuangBao = GetOneCoolDown(106951)					-- 狂暴	
	CDLingHunZhiYin = GetOneCoolDown(140808)			-- 灵魂指引
	CDFuSheng = GetOneCoolDown(20484)					-- 复生
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
	GetOneBuff("player", 5217)  --猛虎之怒
	BuffMengHuZhiNu1 = Temp1
	BuffMengHuZhiNu2 = Temp2
	BuffMengHuZhiNu3 = Temp3
	BuffMengHuZhiNu4 = Temp4
	if BuffMengHuZhiNu1 then
		BuffMengHuZhiNu = BuffMengHuZhiNu3
	else
		BuffMengHuZhiNu = 0
	end
	--
	GetOneBuff("player", 768)  --猎豹形态
	BuffLieBaoXingTai1 = Temp1
	BuffLieBaoXingTai2 = Temp2
	BuffLieBaoXingTai3 = Temp3
	BuffLieBaoXingTai4 = Temp4
	--
	GetOneBuff("player", 5215)  --潜行
	BuffQianXing1 = Temp1
	BuffQianXing2 = Temp2
	BuffQianXing3 = Temp3
	BuffQianXing4 = Temp4
	--
	GetOneBuff("player", 69369)  --掠食者的迅捷
	BuffLveShiZheDeXunJie1 = Temp1
	BuffLveShiZheDeXunJie2 = Temp2
	BuffLveShiZheDeXunJie3 = Temp3
	BuffLveShiZheDeXunJie4 = Temp4
	if BuffLveShiZheDeXunJie1 then
		BuffLveShiZheDeXunJie = BuffLveShiZheDeXunJie3
	else
		BuffLveShiZheDeXunJie = 0
	end
	--
	GetOneBuff("player", 145152)  --血腥爪击
	BuffXueXingZhuaJi1 = Temp1
	BuffXueXingZhuaJi2 = Temp2
	BuffXueXingZhuaJi3 = Temp3
	BuffXueXingZhuaJi4 = Temp4
	if BuffXueXingZhuaJi1 then
		BuffXueXingZhuaJi = BuffXueXingZhuaJi3
	else
		BuffXueXingZhuaJi = 0
	end
	--
	GetOneBuff("player", 52610)  --野蛮咆哮
	BuffYeManPaoXiao1 = Temp1
	BuffYeManPaoXiao2 = Temp2
	BuffYeManPaoXiao3 = Temp3
	BuffYeManPaoXiao4 = Temp4
	if BuffYeManPaoXiao1 then
		BuffYeManPaoXiao = BuffYeManPaoXiao3
	else
		BuffYeManPaoXiao = 0
	end
	if not Talent_YeManPaoXiao then		--没点野蛮咆哮，视为野蛮咆哮一直存在
		BuffYeManPaoXiao = 40
	end
	--
	GetOneBuff("player", 135700)  --节能施法
	BuffJieNengShiFa1 = Temp1
	BuffJieNengShiFa2 = Temp2
	BuffJieNengShiFa3 = Temp3
	BuffJieNengShiFa4 = Temp4
	if BuffJieNengShiFa1 then
		BuffJieNengShiFa = BuffJieNengShiFa3
	else
		BuffJieNengShiFa = 0
	end
	--
	GetOneBuff("player", 58984)  --影遁
	BuffYingDun1 = Temp1
	BuffYingDun2 = Temp2
	BuffYingDun3 = Temp3
	BuffYingDun4 = Temp4
	--
	GetOneBuff("player", 768)  --猎豹形态
	BuffLieBaoXingTai1 = Temp1
	BuffLieBaoXingTai2 = Temp2
	BuffLieBaoXingTai3 = Temp3
	BuffLieBaoXingTai4 = Temp4
	--
	GetOneBuff("player", 210664)  --血之气息
	BuffXueZhiQiXi1 = Temp1
	BuffXueZhiQiXi2 = Temp2
	BuffXueZhiQiXi3 = Temp3
	BuffXueZhiQiXi4 = Temp4
	if BuffXueZhiQiXi1 then
		BuffXueZhiQiXi = BuffXueZhiQiXi3
	else
		BuffXueZhiQiXi = 0
	end
	--
	GetOneBuff("player", 106951)  --狂暴
	BuffKuangBao1 = Temp1
	BuffKuangBao2 = Temp2
	BuffKuangBao3 = Temp3
	BuffKuangBao4 = Temp4
	if BuffKuangBao1 then
		BuffKuangBao = BuffKuangBao3
	else
		BuffKuangBao = 0
	end
	--
	GetOneBuff("player", 102543)  --化身
	BuffHuaShen1 = Temp1
	BuffHuaShen2 = Temp2
	BuffHuaShen3 = Temp3
	BuffHuaShen4 = Temp4
	if BuffHuaShen1 then
		BuffHuaShen = BuffHuaShen3
		BuffKuangBao = BuffHuaShen	--如果有化身Buff，视为狂暴与化身持续时间相等
	else
		BuffHuaShen = 0
	end
	-- 顶级捕食者
	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff("player", select(1, GetSpellInfo(252752)))
	BuffDingJiBuShiZhe1 = name
	BuffDingJiBuShiZhe2 = count or 0
	BuffDingJiBuShiZhe3 = (expirationTime or GetTime()) - GetTime()
	BuffDingJiBuShiZhe4 = unitCaster or nil
	if BuffDingJiBuShiZhe1 then
		BuffDingJiBuShiZhe = BuffDingJiBuShiZhe3
	else
		BuffDingJiBuShiZhe = 0
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
	GetOneDebuff("target", 1079)  --割裂
	DeBuffGeLie1 = Temp1
	DeBuffGeLie2 = Temp2
	DeBuffGeLie3 = Temp3
	DeBuffGeLie4 = Temp4
	if DeBuffGeLie1 and DeBuffGeLie4 == "player" then
		DeBuffGeLie = DeBuffGeLie3
	else
		DeBuffGeLie = 0
	end
	--
	GetOneDebuff("target", 210705)  --阿莎曼的撕扯
	DeBuffAShaManDeSiChe1 = Temp1
	DeBuffAShaManDeSiChe2 = Temp2
	DeBuffAShaManDeSiChe3 = Temp3
	DeBuffAShaManDeSiChe4 = Temp4
	if DeBuffAShaManDeSiChe1 and DeBuffAShaManDeSiChe4 == "player" then
		DeBuffAShaManDeSiChe = DeBuffAShaManDeSiChe3
	else
		DeBuffAShaManDeSiChe = 0
	end
	--
	GetOneDebuff("target", 155722)  --斜掠
	DeBuffXieLve1 = Temp1
	DeBuffXieLve2 = Temp2
	DeBuffXieLve3 = Temp3
	DeBuffXieLve4 = Temp4
	if DeBuffXieLve1 and DeBuffXieLve4 == "player" then
		DeBuffXieLve = DeBuffXieLve3
	else
		DeBuffXieLve = 0
	end
	--
	GetOneDebuff("target", 155625)  --月火术
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
	GetOneDebuff("target", 106830)  --痛击
	DeBuffTongJi1 = Temp1
	DeBuffTongJi2 = Temp2
	DeBuffTongJi3 = Temp3
	DeBuffTongJi4 = Temp4
	if DeBuffTongJi1 and DeBuffTongJi4 == "player" then
		DeBuffTongJi = DeBuffTongJi3
	else
		DeBuffTongJi = 0
	end
	--
	GetOneDebuff("target", 58180)  --感染伤口
	DeBuffGanRanShangKou1 = Temp1
	DeBuffGanRanShangKou2 = Temp2
	DeBuffGanRanShangKou3 = Temp3
	DeBuffGanRanShangKou4 = Temp4
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
end

function GetSelfTalents()						-- 监测天赋
	Talent_YueZhiLing = select(4, GetTalentInfo(1, 3, 1))					--月之灵
	Talent_LveShiZhe = select(4, GetTalentInfo(1, 1, 1))					--掠食者
	Talent_XueZhiQiXi = select(4, GetTalentInfo(1, 2, 1))					--血之气息
	Talent_ManLiMengJi = select(4, GetTalentInfo(4, 1, 1))				    --蛮力猛击
	Talent_QunTiChanRao = select(4, GetTalentInfo(4, 2, 1))			        --群体缠绕
	Talent_TaiFeng = select(4, GetTalentInfo(4, 3, 1))						--台风
	Talent_CongLinZhiHun = select(4, GetTalentInfo(5, 1, 1))			    --丛林之魂
	Talent_HuaShen = select(4, GetTalentInfo(5, 2, 1))						--化身
	Talent_JuChiChuangShang = select(4, GetTalentInfo(5, 3, 1))			    --锯齿创伤
	Talent_JianChiLiRen = select(4, GetTalentInfo(6, 1, 1))				    --剑齿利刃
	Talent_YeManHuiKan = select(4, GetTalentInfo(6, 2, 1))				    --野蛮挥砍
	Talent_YeManPaoXiao = select(4, GetTalentInfo(6, 3, 1))	                --野蛮咆哮
	Talent_DongChaQiuHao = select(4, GetTalentInfo(7, 1, 1))		        --洞察秋毫
	Talent_XueXingZhuaJi = select(4, GetTalentInfo(7, 2, 1))			    --血腥爪击
	Talent_YueShenDeShouHu = select(4, GetTalentInfo(7, 3, 1))			    --月神的守护
end

function GetSelfEquipments()						-- 监测装备
	EquipSiGua = IsEquippedItem(137056)		        -- 丝瓜裹手
	EquipChengJie = IsEquippedItem(137040)		    -- 橙戒
	EquipLingHunZhiYin = IsEquippedItem(140808)		-- 灵魂指引
	EquipBaoXingShou = IsEquippedItem(137094)		-- 爆星手
	EquipXueZhuaXie = IsEquippedItem(137024)		-- 血爪鞋
	EquipCongLinJie = IsEquippedItem(151636)		-- 丛林戒
	EquipMengHuTou = IsEquippedItem(151801)		    -- 猛虎头
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
			Cast_SkullBash()
			return
		end
	end
	--如果按下Shift并且检测到相关技能施放，倒读条
	if IsShift and not IsAlt and not IsCtrl then  
		IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitChannelInfo(JianCeDuiXiang)
		if IfCasting and (not InterruptAble) then
			-- 如果目标正在引导通道法术，就打断之
			Cnt = "P "
			Cast_SkullBash()
			return
		end
	end
	
	--割碎
	if Insert_GeSui and power >= 1 and CDGeSui < gcd then	--星>=5，且割碎CD，使用割碎
		Cnt = "P "
		Cast_Maim()
		return
	end
	--equip灵魂之引 and (斜掠>=5, 割裂>=8, 咆哮>=10) and (buff猛虎>0 or cd猛虎>=5) and not buff狂暴 and Eng缺口>40，使用灵魂之引
	-- if EquipLingHunZhiYin and CDLingHunZhiYin < 1 and (DeBuffXieLve >=5 and DeBuffGeLie >= 8 and BuffYeManPaoXiao >= 10) and (BuffMengHuZhiNu > 0 or CDMengHuZhiNu >= 5) and BuffKuangBao == 0 and EnGMax - EnG > 40 then
	-- 	SendChatMessage("Use Lead of Soul, Now!!!!","whisper",GetDefaultLanguage("player"),UnitName("player"))
	-- end
	--如果猛虎之怒CD 并且 能量离满>60 并且 无猛虎之怒Buff，使用猛虎之怒
	if CDMengHuZhiNu == 0 and ((EnGMax - EnG >= 60 and BuffJieNengShiFa == 0 or EnGMax - EnG >= 80 and BuffJieNengShiFa > 0) and (CDHuaShen < gcd or CDHuaShen > 15) and (BuffMengHuZhiNu == 0 or BuffMengHuZhiNu > 0 and BuffMengHuZhiNu < 8)) then
		Cnt = "P "
		Cast_TigersFury()
		return
	end
	
    -- 复生
    if IfNeedRebirth then
        Cnt = "P "
		Cast_Rebirth()
		return
	end

	--狂暴
	if Insert_KuangBao and (not Talent_HuaShen and CDKuangBao <= gcd or Talent_HuaShen and CDHuaShen <= gcd) then
		Cnt = "P "
		Cast_Berserk()
		return
	end
	
	--痛击
	if Insert_TongJi then
		Cnt = "P "
		Cast_Generator()
		return
	end
	
	--蛮力猛击
	if not Talent_ManLiMengJi then		--没点蛮力猛击天赋就忽略之
		Insert_ManLiMengJi = nil
	end
	if Insert_ManLiMengJi and CDManLiMengJi < gcd then
		Cnt = "P "
		Cast_MightyBash()
		return
	end
	
	--正在读条就发傻
	IfCasting, _, CastingIcon, _, _, _, _, _, InterruptAble = UnitCastingInfo("player")
	if IfCasting then	
		Cnt = "P "
		return
	end
	--如果不处于猎豹状态，就变成猎豹状态
	if not BuffLieBaoXingTai1 then
		Cnt = "P 7"
		return
	end
end


--技能按键
function Cast_Shred()		--撕碎
	Cnt = Cnt.."1  "..select(1, GetSpellInfo(5221))		--1
end
function Cast_Rake()		--斜掠
	--血爪天赋，(【装备血爪鞋时||星>=4】，掠食者的迅捷存在，血爪不存在，非潜行)，使用愈合
	if Talent_XueXingZhuaJi and (EquipXueZhuaXie or power >=4) and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 and BuffQianXing == 0 and BuffYingDun == 0 then
		Cast_Regrowth()
		return
	end
	if CDYingDun == 0 and not BuffQianXing1 and CDQianXing < gcd and GetUnitSpeed("player") == 0 and IsCombat and not BuffHuaShen1 then --影遁CD，先放影遁
		Cast_Shadowmeld()
	else
		Cnt = Cnt.."2  "..select(1, GetSpellInfo(1822))		--2
	end
end
function Cast_FerociousBite()		--凶猛撕咬
	--血爪天赋，(掠食者的迅捷存在，血爪不存在，星==5)，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 and power == 5 then
		Cast_Regrowth()
		return
	end
	Cnt = Cnt.."3  "..select(1, GetSpellInfo(22568))		--3
end
function Cast_Rip()		--割裂
	--血爪天赋，(掠食者的迅捷存在，血爪不存在，星==5，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 and power == 5 then
		Cast_Regrowth()
		return
	end
	Cnt = Cnt.."4  "..select(1, GetSpellInfo(1079))		--4
end
function Cast_SkullBash()		--迎头痛击
	Cnt = Cnt.."5  "..select(1, GetSpellInfo(106839))		--5
end
function Cast_AshamanesFrenzy()		--阿莎曼的狂乱
	Cnt = Cnt.."6  "..select(1, GetSpellInfo(210722))		--6
end
function Cast_SavageRoar()		--野蛮咆哮
	--血爪天赋，(掠食者的迅捷存在，血爪不存在，星==5，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 and power == 5 then
		Cast_Regrowth()
		return
	end
	Cnt = Cnt.."7  "..select(1, GetSpellInfo(52610))		--7
end
function Cast_TigersFury()		--猛虎之怒
	Cnt = Cnt.."8  "..select(1, GetSpellInfo(5217))		--8
end
function Cast_MoonFire()		--月火术
	Cnt = Cnt.."9  "..select(1, GetSpellInfo(155625))		--9
end
function Cast_Regrowth()		--愈合
	Cnt = Cnt.."0  "..select(1, GetSpellInfo(8936))		--0
end
function Cast_Generator()		--痛击
	Cnt = Cnt.."Y  "..select(1, GetSpellInfo(106830))		--Y
end
function Cast_Swipe()		--横扫
	Cnt = Cnt.."G  "..select(1, GetSpellInfo(106785))		--G
end
function Cast_Maim()		--割碎，按住Ctrl的情况下
	Cnt = Cnt.."R  "..select(1, GetSpellInfo(22570))		--R
end
function Cast_Berserk()		--狂暴
	Cnt = Cnt.."H  "..select(1, GetSpellInfo(106951))		--H
end
function Cast_Shadowmeld()		--影遁
	Cnt = Cnt.."J  "..select(1, GetSpellInfo(58984))		--J
end
function Cast_MightyBash()	--蛮力猛击
	Cnt = Cnt.."E  "..select(1, GetSpellInfo(5211))		    --E
end
function Cast_Rebirth()	--复生
	Cnt = Cnt.."T  "..select(1, GetSpellInfo(20484))		--T
end

--单体Boss
function BiteForBoss()
	--潜行||影遁 存在，化身不存在，使用斜掠
	if (BuffQianXing1 or BuffYingDun1) and BuffHuaShen == 0 then
		Cast_Rake()
		return
	end
	
	--猛虎之怒存在，挥砍CD，打挥砍（挥砍天赋）
	if power < 5 and BuffMengHuZhiNu1 and CDHuiKan < gcd and Talent_YeManHuiKan then
		Cast_Swipe()
		return
	end
	
    --血爪天赋，掠食者的迅捷==3，血爪不存在，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie2 == 3 and BuffXueXingZhuaJi == 0 then
		Cast_Regrowth()
		return
	end

    --血爪天赋，掠食者的迅捷==2，血爪不存在，（猛虎之怒存在||狂暴存在||阿沙曼撕扯存在），使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie2 == 2 and BuffXueXingZhuaJi == 0 and (BuffMengHuZhiNu > 2 or BuffKuangBao > 3 or CDAShaMan > 71) then
		Cast_Regrowth()
		return
	end

	--血爪天赋，(掠食者的迅捷存在，血爪不存在，星==2且阿莎曼CD)||掠食者的迅捷快消失，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 and (((power == 2 or power == 3) and CDAShaMan < gcd) or BuffLveShiZheDeXunJie > 0 and BuffLveShiZheDeXunJie < 2) then
		Cast_Regrowth()
		return
	end
	
    --星>=1，野蛮咆哮不存在，使用野蛮咆哮
	if Talent_YeManPaoXiao and power >= 1 and BuffYeManPaoXiao == 0 then
		Cast_SavageRoar()
		return
	end

	-- 顶级捕食者触发后，有五星就打掉
	if BuffDingJiBuShiZhe1 and power >= 5 then
		Cast_FerociousBite()
		return
	end

	--HP<25%||剑齿利刃天赋，星=5，割裂存在且快照比原来高，使用割裂
	if (HPP < 0.25 or Talent_JianChiLiRen) and power == 5 and DeBuffGeLie > 0 and WillKuaiZhaoGeLie > KuaiZhaoGeLie and HighLevel then
		if HighLevel then  --高等级目标才打割裂
			Cast_Rip()
			return
		end
	end	
	--HP<25%||剑齿利刃天赋，星>=1，割裂该补了，使用凶猛撕咬
	if (HPP < 0.25 or Talent_JianChiLiRen) and power >= 1 and DeBuffGeLie < repair_time_Rip and DeBuffGeLie > 0 then
		Cast_FerociousBite()
		return
	end	
	--HP<25%||剑齿利刃天赋，星=5，能量>50||狂暴存在||丛林天赋，割裂 存在，咆哮>7.2s||非咆哮天赋，使用凶猛撕咬
	if (HPP < 0.25 or Talent_JianChiLiRen) and power == 5 and (BuffKuangBao > 0 or EnG > 50) and DeBuffGeLie > 0 and (BuffYeManPaoXiao > repair_time_SavageRoar or not Talent_YeManPaoXiao) then
		Cast_FerociousBite()
		return
	end
	
	--割裂：5星，该补的时候
	if power == 5 and DeBuffGeLie < repair_time_Rip and HighLevel then    -- 高等级目标才打割裂
		Cast_Rip()
		return
	end

	--星==5，野蛮咆哮该补了，使用野蛮咆哮
	if Talent_YeManPaoXiao and power == 5 and BuffYeManPaoXiao < repair_time_SavageRoar then
		Cast_SavageRoar()
		return
	end

	--HP>25%，星=5，能量>50，(割裂>12s，野蛮咆哮>15s，狂暴存在||猛虎之怒马上CD，咆哮天赋)||(非咆哮天赋，割裂>7.2s)，使用凶猛撕咬
	if (HPP >= 0.25 or not Talent_JianChiLiRen) and power == 5 and (EquipMengHuTou and BuffMengHuZhiNu > 1 or EnG > 50 or BuffKuangBao > 0 or CDMengHuZhiNu < 6) and ((BuffYeManPaoXiao > repair_time_SavageRoar or not Talent_YeManPaoXiao) and DeBuffGeLie > repair_time_Rip) then
		Cast_FerociousBite()
		return
	end
	
	--星=5，野蛮咆哮<7.2s，野蛮咆哮先结束，使用野蛮咆哮
	--if power == 5 and BuffYeManPaoXiao < 7.2 and DeBuffGeLie > BuffYeManPaoXiao then
	--	Cast_SavageRoar()
	--	return
	--end

	--满星，低等级目标，使用凶猛撕咬
	if power == 5 and not HighLevel then
		Cast_FerociousBite()
		return
	end
	
	--阿沙曼CD，星=2||3，割裂>1s，有血爪时，使用阿沙曼
	if CDAShaMan < gcd and (power == 2 or power == 3 or power == 4 and EquipBaoXingShou) then
		Cast_AshamanesFrenzy()
		return
	end
	
	-- 斜掠：该补就补
	if power < 5 and DeBuffXieLve < repair_time_Rake and HighLevel then
		Cast_Rake()
		return
	end
	
	-- 月火：月之灵天赋，4.2s补；8s补（高快照，有割裂，无阿莎曼的撕扯）
	if power < 5 and Talent_YueZhiLing and (DeBuffYueHuoShu < 4.2 or DeBuffYueHuoShu < 8 and WillKuaiZhaoYueHuoShu > KuaiZhaoYueHuoShu and DeBuffGeLie > 0 and DeBuffAShaManDeSiChe == 0) then
		Cast_MoonFire()
		return
	end
	
    -- 补痛击：非化身
    if power < 5 and DeBuffTongJi < repair_time_Generator and BuffHuaShen == 0 and HighLevel then
    	Cast_Generator()
    	return
    end

	-- 血腥爪击1层，且无掠食者的迅捷，且(星=3||星=4)，且割裂<7.2秒，且咆哮>5秒，豹形态月火可用，放月火
	if power < 5 and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi2 == 1 and BuffLveShiZheDeXunJie == 0 and (power == 3 or power ==4) and DeBuffGeLie < 7.2 and BuffYeManPaoXiao > 5 and Talent_YueZhiLing then
		Cast_MoonFire()
	end
	
	--[(能量缺口<20) 或者 节能施法存在 或者 猛虎之怒马上cd，能量缺口<60]，血腥爪击不是就一层，割裂不到补的时候，使用撕碎
	if (EnGMax - EnG < 50 or BuffJieNengShiFa > 0 or CDMengHuZhiNu < 1 and EnGMax - EnG < 80) and Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie == 0 and BuffXueXingZhuaJi > 0 and BuffXueXingZhuaJi2 ~= 1 and DeBuffGeLie > 6 then
		--按下Alt，用横扫替代撕碎
		if IsAlt and not IsCtrl and not IsShift then
			Cast_Swipe()
		else
			Cast_Shred()
		end
		return
	end
	--(无爆星手且星<5||爆星手且星<4||割裂<4||快要能量溢出)，（猛虎之怒CD||野蛮咆哮、割裂<(8-星)s||能量缺口<20||（割裂>12，没暗影割裂）||节能施法出现超过3秒），使用撕碎
	if (not EquipBaoXingShou and power < 5 or EquipBaoXingShou and power < 4 or DeBuffGeLie < 4 or EngMax - Eng < 40) and (CDMengHuZhiNu < 1 or BuffYeManPaoXiao < 8-power or DeBuffGeLie < 8-power or EnGMax - EnG < 50 or DeBuffGeLie > 12 and DeBuffAShaManDeSiChe == 0 or BuffJieNengShiFa > 0 and BuffJieNengShiFa < 12) then
		--按下Alt，用横扫替代撕碎
		if IsAlt and not IsCtrl and not IsShift then
			Cast_Swipe()
		else
			Cast_Shred()
		end
		return
	end
	
	--狂暴||阿莎曼狂乱 存在，使用撕碎
	if BuffKuangBao > 0 or CDAShaMan > 69 then
		--按下Alt，用横扫替代撕碎
		if IsAlt and not IsCtrl and not IsShift then
			Cast_Swipe()
		else
			Cast_Shred()
		end
		return
	end

	-- 挥砍天赋，释放愈合
	if Talent_YeManHuiKan and BuffLveShiZheDeXunJie1 then
		Cast_Regrowth()
		return
	end
	
	--否则，什么都不干
	Cnt = Cnt..""
	return
end

--中量目标
function BiteForBossAndBuddies()
	--潜行||影遁 存在，化身不存在，使用斜掠
	if (BuffQianXing1 or BuffYingDun1) and BuffHuaShen == 0 then
		Cast_Rake()
		return
	end
	
	--猛虎之怒存在，挥砍CD，充能满，打挥砍（挥砍天赋）
	if power < 5 and Charge_HuiKan >= 3 and CDHuiKan < gcd and Talent_YeManHuiKan then
		Cast_Swipe()
		return
	end
	
    --血爪天赋，掠食者的迅捷==3，血爪不存在，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie2 == 3 and BuffXueXingZhuaJi == 0 then
		Cast_Regrowth()
		return
	end

    --血爪天赋，掠食者的迅捷==2，血爪不存在，（猛虎之怒存在||狂暴存在||阿沙曼撕扯存在），使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie2 == 2 and BuffXueXingZhuaJi == 0 and (BuffMengHuZhiNu > 2 or BuffKuangBao > 3 or CDAShaMan > 71) then
		Cast_Regrowth()
		return
	end

	--血爪天赋，(掠食者的迅捷存在，血爪不存在，星==2且阿莎曼CD)||掠食者的迅捷快消失，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 and (((power == 2 or power == 3) and CDAShaMan < gcd) or BuffLveShiZheDeXunJie > 0 and BuffLveShiZheDeXunJie < 2) then
		Cast_Regrowth()
		return
	end
	
    --星>=1，野蛮咆哮不存在，使用野蛮咆哮
	if Talent_YeManPaoXiao and power >= 1 and BuffYeManPaoXiao == 0 then
		Cast_SavageRoar()
		return
	end

	-- 顶级捕食者触发后，有五星就打掉
	if BuffDingJiBuShiZhe1 and power >= 5 then
		Cast_FerociousBite()
		return
	end

	--HP<25%||剑齿利刃天赋，星=5，割裂存在且快照比原来高，使用割裂
	if (HPP < 0.25 or Talent_JianChiLiRen) and power == 5 and DeBuffGeLie > 0 and WillKuaiZhaoGeLie > KuaiZhaoGeLie and HighLevel then
		if HighLevel then  --高等级目标才打割裂
			Cast_Rip()
			return
		end
	end	
	--HP<25%||剑齿利刃天赋，星>=1，割裂该补了，使用凶猛撕咬
	if (HPP < 0.25 or Talent_JianChiLiRen) and power >= 1 and DeBuffGeLie < repair_time_Rip and DeBuffGeLie > 0 then
		Cast_FerociousBite()
		return
	end	
	--HP<25%||剑齿利刃天赋，星=5，能量>50||狂暴存在||丛林天赋，割裂 存在，咆哮>7.2s||非咆哮天赋，使用凶猛撕咬
	if (HPP < 0.25 or Talent_JianChiLiRen) and power == 5 and (BuffKuangBao > 0 or EnG > 50) and DeBuffGeLie > 0 and (BuffYeManPaoXiao > repair_time_SavageRoar or not Talent_YeManPaoXiao) then
		Cast_FerociousBite()
		return
	end
	
	--割裂：5星，该补的时候
	if power == 5 and DeBuffGeLie < repair_time_Rip and HighLevel then    -- 高等级目标才打割裂
		Cast_Rip()
		return
	end

	--星==5，野蛮咆哮该补了，使用野蛮咆哮
	if Talent_YeManPaoXiao and power == 5 and BuffYeManPaoXiao < repair_time_SavageRoar then
		Cast_SavageRoar()
		return
	end

	--HP>25%，星=5，能量>50，(割裂>12s，野蛮咆哮>15s，狂暴存在||猛虎之怒马上CD，咆哮天赋)||(非咆哮天赋，割裂>7.2s)，使用凶猛撕咬
	if (HPP >= 0.25 or not Talent_JianChiLiRen) and power == 5 and (EquipMengHuTou and BuffMengHuZhiNu > 1 or EnG > 50 or BuffKuangBao > 0 or CDMengHuZhiNu < 6) and ((BuffYeManPaoXiao > repair_time_SavageRoar or not Talent_YeManPaoXiao) and DeBuffGeLie > repair_time_Rip) then
		Cast_FerociousBite()
		return
	end	
	--满星，低等级目标，使用凶猛撕咬
	if power == 5 and not HighLevel then
		Cast_FerociousBite()
		return
	end
	
	--阿沙曼CD，星=2||3，割裂>1s，有血爪时，使用阿沙曼
	if CDAShaMan < gcd and (power == 2 or power == 3 or power == 4 and EquipBaoXingShou) then
		Cast_AshamanesFrenzy()
		return
	end
	
	-- 斜掠：该补就补
	if power < 5 and DeBuffXieLve < repair_time_Rake and HighLevel then
		Cast_Rake()
		return
	end
	
	-- 月火：月之灵天赋，4.2s补；8s补（高快照，有割裂，无阿莎曼的撕扯）
	if power < 5 and Talent_YueZhiLing and (DeBuffYueHuoShu < 4.2 or DeBuffYueHuoShu < 8 and WillKuaiZhaoYueHuoShu > KuaiZhaoYueHuoShu and DeBuffGeLie > 0 and DeBuffAShaManDeSiChe == 0) then
		Cast_MoonFire()
		return
	end
	
    -- 补痛击
    if power < 5 and DeBuffTongJi < repair_time_Generator then
    	Cast_Generator()
    	return
    end

	-- 血腥爪击1层，且无掠食者的迅捷，且(星=3||星=4)，且割裂<7.2秒，且咆哮>5秒，豹形态月火可用，放月火
	if BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi2 == 1 and BuffLveShiZheDeXunJie == 0 and (power == 3 or power ==4) and DeBuffGeLie < 7.2 and BuffYeManPaoXiao > 5 and Talent_YueZhiLing then
		Cast_MoonFire()
	end
	
	--[(能量缺口<20) 或者 节能施法存在 或者 猛虎之怒马上cd，能量缺口<60]，血腥爪击不是就一层，割裂不到补的时候，使用撕碎
	if (EnGMax - EnG < 50 or BuffJieNengShiFa > 0 or CDMengHuZhiNu < 1 and EnGMax - EnG < 80) and Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie == 0 and BuffXueXingZhuaJi > 0 and BuffXueXingZhuaJi2 ~= 1 and DeBuffGeLie > 6 then
		if Talent_YeManHuiKan then
			Cast_Shred()
		else
		    Cast_Swipe()
		end
		return
	end
	--(无爆星手且星<5||爆星手且星<4||割裂<4||快要能量溢出)，（猛虎之怒CD||野蛮咆哮、割裂<(8-星)s||能量缺口<20||（割裂>12，没暗影割裂）||节能施法出现超过3秒），使用撕碎
	if (not EquipBaoXingShou and power < 5 or EquipBaoXingShou and power < 4 or DeBuffGeLie < 4 or EngMax - Eng < 40) and (CDMengHuZhiNu < 1 or BuffYeManPaoXiao < 8-power or DeBuffGeLie < 8-power or EnGMax - EnG < 50 or DeBuffGeLie > 12 and DeBuffAShaManDeSiChe == 0 or BuffJieNengShiFa > 0 and BuffJieNengShiFa < 12) then
		if Talent_YeManHuiKan then
			Cast_Shred()
		else
		    Cast_Swipe()
		end
		return
	end
	
	--狂暴||阿莎曼狂乱 存在，使用撕碎
	if BuffKuangBao > 0 or CDAShaMan > 69 then
		if Talent_YeManHuiKan then
			Cast_Shred()
		else
		    Cast_Swipe()
		end
		return
	end
	
	-- 挥砍天赋，释放愈合
	if Talent_YeManHuiKan and BuffLveShiZheDeXunJie1 then
		Cast_Regrowth()
		return
	end
	
	--否则，什么都不干
	Cnt = Cnt..""
	return
end

--大量目标
function BiteForBuddies()
    --血爪天赋，掠食者的迅捷==3，血爪不存在，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie2 == 3 and BuffXueXingZhuaJi == 0 then
		Cast_Regrowth()
		return
	end

    --血爪天赋，掠食者的迅捷==2，血爪不存在，（猛虎之怒存在||狂暴存在||阿沙曼撕扯存在），使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie2 == 2 and BuffXueXingZhuaJi == 0 and (BuffMengHuZhiNu > 2 or BuffKuangBao > 3 or CDAShaMan > 71) then
		Cast_Regrowth()
		return
	end

	--血爪天赋，掠食者的迅捷存在，血爪不存在，使用愈合
	if Talent_XueXingZhuaJi and BuffLveShiZheDeXunJie > 0 and BuffXueXingZhuaJi == 0 then
		Cast_Regrowth()
		return
	end
	--野蛮咆哮天赋，星>=1，无野蛮咆哮，使用野蛮咆哮
	if Talent_YeManPaoXiao and power >= 1 and BuffYeManPaoXiao == 0 then
		Cast_SavageRoar()
		return
	end

	-- 顶级捕食者触发后，有五星就打掉
	if BuffDingJiBuShiZhe1 and power >= 5 then
		Cast_FerociousBite()
		return
	end
	
	--野蛮咆哮天赋，星>=5，野蛮咆哮<7.2s，使用野蛮咆哮
	if Talent_YeManPaoXiao and power == 5 and BuffYeManPaoXiao < repair_time_SavageRoar then
		Cast_SavageRoar()
		return
	end

	--割裂：5星
	if power == 5 and (EquipCongLinJie or DeBuffGeLie < repair_time_Rip) then -- 为了回能
		Cast_Rip()
		return
	end
	
	--痛击不存在||<3s，打一发痛击
	if DeBuffTongJi < repair_time_Generator then
		Cast_Generator()
		return
	end
	--痛击<8s||没有血之气息，能量>75，使用痛击
	if (DeBuffTongJi < 8 or BuffXueZhiQiXi == 0) and EnG > 75 then
		Cast_Generator()
		return
	end
	
	--挥砍三发充能满，猛虎之怒CD，且无猛虎之怒效果，打猛虎之怒（挥砍天赋）
	if Talent_YeManHuiKan and Charge_HuiKan == 3 and CDMengHuZhiNu == 0 and BuffMengHuZhiNu == 0 then
		Cast_TigersFury()
		return
	end
	
	--挥砍CD，打挥砍（挥砍天赋）
	if CDHuiKan < gcd and Talent_YeManHuiKan then
		Cast_Swipe()
		return
	end

	--星==5，野蛮咆哮该补了，使用野蛮咆哮
	if Talent_YeManPaoXiao and power == 5 and BuffYeManPaoXiao < repair_time_SavageRoar then
		Cast_SavageRoar()
		return
	end
		
	--阿沙曼CD，星=2||3，使用阿沙曼
	if CDAShaMan < gcd and (power == 2 or power == 3) then
		Cast_AshamanesFrenzy()
		return
	end
	
	--非挥砍天赋，血之气息存在||能量>120||满能量||狂暴，使用横扫
	if not Talent_YeManHuiKan and (BuffXueZhiQiXi > 0 or EnG > 120 or EnG == EnGMax or BuffKuangBao > 0) then
		Cast_Swipe()
		return
	end
	--挥砍天赋，使用痛击
	if Talent_YeManHuiKan then
		Cast_Generator()
		return
	end
	
	-- 挥砍天赋，释放愈合
	if Talent_YeManHuiKan and BuffLveShiZheDeXunJie1 then
		Cast_Regrowth()
		return
	end

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
		IsAlt = IsAltKeyDown()					-- 是否按下Alt键
		IsCtrl = IsControlKeyDown()				-- 是否按下Ctrl键
		IsShift = IsShiftKeyDown()				-- 是否按下Ctrl键
		power = UnitPower("player", SPELL_POWER_COMBO_POINTS)			-- 监测连击点
		--StatiCoverRate()											--统计流血覆盖率
		Charge_HuiKan = GetSpellCharges(202028)		--挥砍的充能数
		GetSelfEquipments()												--监测装备
		if UnitLevel("target") == -1 or UnitClassification("target") == "elite" or UnitLevel("target") > UnitLevel("player") or UnitIsPlayer("target") then
			HighLevel = true
		else
			HighLevel = false
		end
		
		local PlayerClass
		_,PlayerClass = UnitClass("player")
		gcd = CDSiSui + 0.1
		IfIn10yard = CheckInteractDistance("target", 3)		-- 10码内
        if UnitIsDead("target") and (UnitInParty("target") or UnitInRaid("target")) and CDFuSheng <= gcd then
		    IfNeedRebirth = true
		else
			IfNeedRebirth = false
		end
		
        -- 确定各buff补的时间
        if Talent_JuChiChuangShang then
	        repair_time_Rip = 5.76
	    else
	    	repair_time_Rip = 7.2
	    end
	    if BuffXueXingZhuaJi > 0 then
	        repair_time_Rake = 7
	    else
	        repair_time_Rake = 4.5
	    end
        repair_time_SavageRoar = 12
        repair_time_Generator = 4.5

		-- 计算斜掠快照
		WillKuaiZhaoXieLve = 100
		if BuffMengHuZhiNu > 0 then
			WillKuaiZhaoXieLve = WillKuaiZhaoXieLve + 15
		end
		if BuffXueXingZhuaJi > 0 then
			WillKuaiZhaoXieLve = WillKuaiZhaoXieLve + 20
		end
		if BuffQianXing1 or BuffYingDun1 then
			WillKuaiZhaoXieLve = WillKuaiZhaoXieLve + 100
		end
		-- 计算割裂快照
		WillKuaiZhaoGeLie = 100
		if BuffMengHuZhiNu > 0 then
			WillKuaiZhaoGeLie = WillKuaiZhaoGeLie + 15
		end
		if BuffXueXingZhuaJi > 0 then
			WillKuaiZhaoGeLie = WillKuaiZhaoGeLie + 20
		end
		-- 计算月火快照
		WillKuaiZhaoYueHuoShu = 100
		if BuffMengHuZhiNu > 0 then
			WillKuaiZhaoYueHuoShu = WillKuaiZhaoYueHuoShu + 15
		end		
		
		if PlayerClass == "DRUID" then
			Cnt = "P "
			if Index_Strategy == 1 then
				BiteForBoss()
			elseif Index_Strategy == 2 then
				BiteForBossAndBuddies()
			elseif Index_Strategy == 3 then
				BiteForBuddies()
			elseif Index_Strategy == 0 then
				Cnt = "P "
			end
		else
			Cnt = "P "
		end

		-- 统计溢出情况
		if not IsCombat and intoCombatTime > -1 then
			duration = GetTime() - intoCombatTime
			local text = ''
			text = text..'本次战斗用时'..string.format('%.1f', duration)..'秒，'
			text = text..'共溢出'..energyOverflow..'点能量、'
			text = text..powerOverflow..'个连击点，'
			text = text..'平均每分钟溢出'..string.format('%.1f', energyOverflow/duration*60)..'点能量、'
			text = text..string.format('%.1f', powerOverflow/duration*60)..'个连击点。'
			DEFAULT_CHAT_FRAME:AddMessage(text)
			intoCombatTime = -1
		end

		--非战斗时或非猫时，清空插队队列
		if not (IsCombat and BuffLieBaoXingTai1) then
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
