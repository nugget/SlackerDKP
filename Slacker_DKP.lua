-- SlackerDKP AddOn - http://slacker.com/~nugget/projects/slackerdkp/
-- (c) Copyright 2006 David McNett.  All Rights Reserved.
--
-- $Id$
-- 

local version = "1.12";
local builddate = "4-Nov-1970";
local buildnum = 0;
local cvsversion = '$Id$';
_,_,buildnum,builddate = string.find(cvsversion, ",v 1.([^%s]+)% ([^%s]+) ");
local selected_eid = 0;
local edit_eid = 0;

SLACKER_SAVED_DKP = {};
SLACKER_SAVED_GEAR = {};

SLACKER_SAVED_SETTINGS = {};

SLACKER_SAVED_EVENTLOG = {};

SLACKER_SAVED_BOSSKILLS = {};
SLACKER_SAVED_LOOTLOG = {};
SLACKER_SAVED_ATTLOG = {};

SLACKER_SAVED_BOSSES = {};
SLACKER_SAVED_IGNORED = {};
SLACKER_SAVED_LOOTLIST = {};
SLACKER_SAVED_ALTS = {};
SLACKER_SAVED_CLASSES = {};

function Slacker_DKP_OnLoad()
	this:RegisterEvent("PLAYER_LOGIN");
	this:RegisterEvent("CHAT_MSG_WHISPER");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("LOOT_OPENED");
	this:RegisterEvent("CHAT_MSG_LOOT");
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");
	this:RegisterEvent("CHAT_MSG_MONSTER_YELL");	
		
	SlashCmdList["SLACKERDKP"] = Slacker_DKP_CommandHandler;
	SLASH_SLACKERDKP1 = "/sdkp";
	
	Slacker_DKP_LoadAltList();
end

function Slacker_DKP_OnEvent()
	if(event == "ADDON_LOADED" and arg1 == "Slacker_DKP") then
		Slacker_DKP_Version();
		if(SLACKER_SAVED_SETTINGS['rarity'] == nil) then
			Slacker_DKP_Toggle('rarity 4');
		end
	elseif	(event == "CHAT_MSG_LOOT") then
		local name, itemlink;
		local _, _, player, link = string.find(arg1, "([^%s]+) receives loot: (.+)%.");

		if (player) then
			name = player;
			itemlink = link;
		else
			local _, _, link = string.find(arg1, "You receive loot: (.+)%.");
			if (link) then
				name = UnitName("player");
				itemlink = link;
			end
		end

		if (name and itemlink) then
			local info = Slacker_DKP_ItemInfo(itemlink);
			if (info) then
				Slacker_DKP_Debug('Drop with info '..info.name..' rarity '..info.rarity);
				if(SLACKER_SAVED_IGNORED[info.name]) then
					Slacker_DKP_Debug("Ignoring "..info.name.." drop.");
				else
					if(info.rarity >= tonumber(SLACKER_SAVED_SETTINGS['rarity'])) then
						Slacker_DKP_Debug('LogLoot '..info.rarity..' and '..SLACKER_SAVED_SETTINGS['rarity']);
						Slacker_DKP_LogLoot(name,info.name,itemlink);
					end
				end
			end
		end	
	elseif (event == "CHAT_MSG_COMBAT_HOSTILE_DEATH") then
		local mob;
		local _, _, mob = string.find(arg1, "(.+) dies.");
		if (mob) then
			if(mob == 'Majordomo Executus') then
				Slacker_DKP_Debug('Ignoring Majordomo kill');
			else
				if(SLACKER_SAVED_BOSSES[mob]) then
					Slacker_DKP_BossKillLog(mob,"auto-logged");
				end
			end
		end
	elseif (event == "CHAT_MSG_MONSTER_YELL") then
		if( string.find(arg1, "Brashly, you have come to wrest the secrets of the Living Flame")) then
			Slacker_DKP_BossKillLog('Majordomo Executus','auto-logged');
		end
	elseif (event == "LOOT_OPENED") then
		Slacker_DKP_LootWalk();
	end
end

function Slacker_DKP_Version()
	Slacker_DKP_Message("SlackerDKP v"..version.." (Build "..buildnum..") "..builddate.." loaded.");
end

function Slacker_DKP_HelpOnClick()
	Slacker_DKP_Message(SLACKERDKP_CHAT_COMMAND_USAGE);
end

function Slacker_DKP_AddAttendanceOnClick()
	if(Slacker_DKP_AttendanceLog("") > 0) then
		selected_eid = getn(SLACKER_SAVED_EVENTLOG);
		Slacker_DKP_EventLogBar_Update();
		Slacker_DKP_EventLog_Edit();
	end
end

function Slacker_DKP_AddBossKillOnClick()
	if(Slacker_DKP_BossKillNew("") > 0) then
		selected_eid = getn(SLACKER_SAVED_EVENTLOG);
		Slacker_DKP_EventLogBar_Update();
		Slacker_DKP_EventLog_Edit();
	end
end

function Slacker_DKP_ItemInfo(link)
	local _, _, id, name = string.find(link,"|Hitem:(%d+):%d+:%d+:%d+|h%[([^]]+)%]|h|r$");
	local itemName, itemLink, itemRarity, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(id);
	local info = {};

	info.id = id;
	info.name = name;
	info.link = itemLink;
	info.rarity = itemRarity;
	info.icon = itemTexture;
	info.dkp = 0;
	info.secdkp = 0;

	return info;
end




function Slacker_DKP_Message(buf)
	if type(buf) == 'string' then
		DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFFF"..buf);
	else
		for key, line in buf do
			DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFFF"..line);
		end
	end
end

function Slacker_DKP_Debug(buf)
	if(SLACKER_SAVED_SETTINGS['debug'] == 'yes') then
		if type(buf) == 'string' then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFdebug:"..buf);
		else
			for key, line in buf do
				DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFdebug:"..line);
			end
		end
	end
end

function Slacker_DKP_EventLogBar_Update()
	local row;
	local entries;
	
	entries = getn (SLACKER_SAVED_EVENTLOG);
	if(entries <= 10) then
		Slacker_DKP_EventLogBar:Hide();
	else 
		Slacker_DKP_EventLogBar:Show();
	end
	
	Event_DownItem:Hide();
	Event_BidItem:Hide();
	Event_DeleteEntry:Hide();
	Event_Edit:Hide();
	Event_Up:Hide();		
	Event_Down:Hide();		

	if(selected_eid > 0) then
		local ets = SLACKER_SAVED_EVENTLOG[selected_eid]['ts'];

		Event_Edit:Show();	
		Event_DeleteEntry:Show();
		
		if(SLACKER_SAVED_EVENTLOG[selected_eid]['type'] == 'LOOT') then
			Event_Down:Show();
			Event_Up:Show();
		
			if(SLACKER_SAVED_LOOTLOG[ets]['type'] == 'down') then
				Event_DownItem:Hide();
				Event_BidItem:Show();
			else
				Event_BidItem:Hide();								
				Event_DownItem:Show();
			end	
						
		end
	end
	
	FauxScrollFrame_Update(Slacker_DKP_EventLogBar,entries,10,17);
	for row=1,10 do
		local time = getglobal("EventLog"..row.."FieldTime");
		local comments = getglobal("EventLog"..row.."FieldComments");
		local highlight = getglobal("EventLog"..row.."FieldHighlight");
		local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_EventLogBar);
		local eventrow = getglobal("EventLog"..row);
		local description = '';
	
		if eid <= entries then
			local color = "|cffFFFFFF";
			local tscolor = "|cffFFFFFF";
			local etype = SLACKER_SAVED_EVENTLOG[eid]['type'];
			local ets = SLACKER_SAVED_EVENTLOG[eid]['ts'];
			if(ets) then
				if(etype == 'BOSSKILL') then
					color = "|cffFF7F7F";
					description = "Killed "..SLACKER_SAVED_BOSSKILLS[ets]['bossname'].." ("..SLACKER_SAVED_BOSSKILLS[ets]['comments']..")";
				elseif(etype == 'LOOT') then
					local elink = SLACKER_SAVED_LOOTLOG[ets]['link'];
					local loottype = 'bid';
					tscolor = "|cff7F7F7F";
					if(SLACKER_SAVED_LOOTLOG[ets]['type']) then
						loottype = SLACKER_SAVED_LOOTLOG[ets]['type'];
					end
					if(elink) then
						description = SLACKER_SAVED_LOOTLOG[ets]['player'].." "..loottype.." "..elink;
					else
						description = SLACKER_SAVED_LOOTLOG[ets]['player'].." "..loottype.." "..SLACKER_SAVED_LOOTLOG[ets]['item'];
					end
				elseif(etype == 'ATT') then
					color = "|cff00FFFF";
					description = "Attendance ("..SLACKER_SAVED_ATTLOG[ets]['comments']..")";
				end

				time:SetText(tscolor..date("%H:%M",SLACKER_SAVED_EVENTLOG[eid]['ts']));
				comments:SetText(color..description);
				eventrow:Show();
				if(selected_eid == eid) then
					highlight:Show();
				else
					highlight:Hide();
				end
			else
				eventrow:Hide();
			end
		else
			eventrow:Hide();
		end
	end
end

function Slacker_DKP_LootWalk()
	SLACKER_SAVED_LOOTLIST = nil;
	SLACKER_SAVED_LOOTLIST = {};

	local items = 0;
	local msgbuf = "It's Lootin' time!";
	
	for index = 1, GetNumLootItems(), 1 do
		if (LootSlotIsItem(index)) then
			items = items + 1;
			
			local texture,item,quantity,quality = GetLootSlotInfo(index);
			local iteminfo = GetLootSlotLink(index);
			
			if(iteminfo) then
				Slacker_DKP_Debug("Tracking item "..items.." ("..item..")");
	
				SLACKER_SAVED_LOOTLIST[items] = {
					["name"] = item,
					["link"] = iteminfo,
				};
				
				msgbuf = msgbuf.." "..iteminfo;
			end
		end
	end
	if(items > 0) then
		if(SLACKER_SAVED_SETTINGS['announceloot'] == 'yes') then
			Slacker_DKP_Announce('GUILD',msgbuf);
		end
		if(SLACKER_SAVED_SETTINGS['raidloot'] == 'yes') then
			Slacker_DKP_Announce('RAID',msgbuf);
		end
	end
end

function Slacker_DKP_EventLogOnClick(button)
	local row = this:GetID();
	local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_EventLogBar);
	
	selected_eid = eid;
	
	Slacker_DKP_EventLogBar_Update();
end

function Slacker_DKP_EventLog_DeleteEntry()
	local eid = selected_eid;
	local count = getn (SLACKER_SAVED_EVENTLOG);
	
	if(eid > 0) then
		for i=1,count do
			local etype = SLACKER_SAVED_EVENTLOG[i]['type'];
			local ets = SLACKER_SAVED_EVENTLOG[i]['ts'];
		
			if (i == eid) then
				if(etype == 'LOOT') then
--					SLACKER_SAVED_LOOTLOG[ets]['player'] = nil;
--					SLACKER_SAVED_LOOTLOG[ets]['item'] = nil;					
					SLACKER_SAVED_LOOTLOG[ets] = nil;
				elseif(etype == 'BOSSKILL') then
--					SLACKER_SAVED_BOSSKILLS[ets]['bossname'] = nil;
--					SLACKER_SAVED_BOSSKILLS[ets]['location'] = nil;
--					SLACKER_SAVED_BOSSKILLS[ets]['comments'] = nil;
--					SLACKER_SAVED_BOSSKILLS[ets]['playerlist'] = nil;
					SLACKER_SAVED_BOSSKILLS[ets] = nil;
				elseif(etype == 'ATT') then
--					SLACKER_SAVED_ATTLOG[ets]['location'] = nil;
--					SLACKER_SAVED_ATTLOG[ets]['comments'] = nil;
--					SLACKER_SAVED_ATTLOG[ets]['playerlist'] = nil;					
					SLACKER_SAVED_ATTLOG[ets] = nil;
				end
			elseif (i > eid) then
				if(i > 1) then
					local j=i-1;
--					SLACKER_SAVED_EVENTLOG[j]['ts'] = SLACKER_SAVED_EVENTLOG[i]['ts'];   -- attempt to index field '?' (a nil value)
--					SLACKER_SAVED_EVENTLOG[j]['type'] = SLACKER_SAVED_EVENTLOG[i]['type'];
					SLACKER_SAVED_EVENTLOG[j] = SLACKER_SAVED_EVENTLOG[i];
					
				end
			end
		end
--		SLACKER_SAVED_EVENTLOG[count]['ts'] = nil;
--		SLACKER_SAVED_EVENTLOG[count]['type'] = nil;
		SLACKER_SAVED_EVENTLOG[count] = nil;
	end

	if(selected_eid > eid) then
		selected_eid = selected_eid - 1;
	elseif(selected_eid == eid) then
		selected_eid = 0;
	end

	PlaySound("INTERFACESOUND_CURSORDROPOBJECT");
	
	Slacker_DKP_EventLogBar_Update();
end

function Slacker_DKP_EventLog_EntryType(type)
	if(selected_eid > 0) then
		local etype = SLACKER_SAVED_EVENTLOG[selected_eid]['type'];
		local ets = SLACKER_SAVED_EVENTLOG[selected_eid]['ts'];
		
		if(etype == 'LOOT') then
			SLACKER_SAVED_LOOTLOG[ets]['type'] = type;	
		end
	end
	Slacker_DKP_EventLogBar_Update();
end

function Slacker_DKP_EventLog_Edit()
	if(selected_eid > 0) then
		local etype = SLACKER_SAVED_EVENTLOG[selected_eid]['type'];
		local ets = SLACKER_SAVED_EVENTLOG[selected_eid]['ts'];

		edit_eid = selected_eid;
		
		if(etype == 'BOSSKILL') then
			Slacker_DKP_EditFrameComment:SetText(SLACKER_SAVED_BOSSKILLS[ets]['comments']);
			Slacker_DKP_EditFrame:Show();
		elseif(etype == 'ATT') then
			Slacker_DKP_EditFrameComment:SetText(SLACKER_SAVED_ATTLOG[ets]['comments']);
			Slacker_DKP_EditFrame:Show();
		elseif(etype == 'LOOT') then
			Slacker_DKP_LootFramePlayer:SetText(SLACKER_SAVED_LOOTLOG[ets]['player']);
			Slacker_DKP_LootFrame:Show();		
		end		
	end
end

function Slacker_DKP_EventLog_Bump(direction)
	local entries;
	entries = getn (SLACKER_SAVED_EVENTLOG);

	if(selected_eid > 0) then
		local etype = SLACKER_SAVED_EVENTLOG[selected_eid]['type'];
		local ets = SLACKER_SAVED_EVENTLOG[selected_eid]['ts'];

		if(direction == 'U') then
			target_eid = selected_eid + 1;
		else
			target_eid = selected_eid - 1;
		end
		
		if(target_eid > 0 and target_eid <= entries) then
			SLACKER_SAVED_EVENTLOG[selected_eid]['type'] = SLACKER_SAVED_EVENTLOG[target_eid]['type'];
			SLACKER_SAVED_EVENTLOG[selected_eid]['ts'] = SLACKER_SAVED_EVENTLOG[target_eid]['ts'];

			SLACKER_SAVED_EVENTLOG[target_eid]['type'] = etype;
			SLACKER_SAVED_EVENTLOG[target_eid]['ts'] = ets;			
		end

		selected_eid = target_eid;
		Slacker_DKP_EventLogBar_Update();		
	end
end

function Slacker_DKP_EditWindow_Save()
	if(edit_eid > 0) then
		local etype = SLACKER_SAVED_EVENTLOG[edit_eid]['type'];
		local ets = SLACKER_SAVED_EVENTLOG[edit_eid]['ts'];
					
		if(etype == 'BOSSKILL') then
			local newtext = Slacker_DKP_EditFrameComment:GetText();
			
			SLACKER_SAVED_BOSSKILLS[ets]['comments'] = newtext;
			Slacker_DKP_EditFrame:Hide();
		elseif(etype == 'ATT') then
			local newtext = Slacker_DKP_EditFrameComment:GetText();
			
			SLACKER_SAVED_ATTLOG[ets]['comments'] = newtext;
			Slacker_DKP_EditFrame:Hide();
		elseif(etype == 'LOOT') then
			local newplayer = Slacker_DKP_LootFramePlayer:GetText();
			
			SLACKER_SAVED_LOOTLOG[ets]['player'] = newplayer;
			Slacker_DKP_LootFrame:Hide();
		end		
		
		edit_eid = 0;
		
		Slacker_DKP_EditFrameComment:SetText("");
		Slacker_DKP_LootFramePlayer:SetText("");

		Slacker_DKP_EventLogBar_Update();
	end
end

function Slacker_DKP_ToggleFrame()
	if (Slacker_DKP_EventLogFrame:IsVisible()) then
		Slacker_DKP_EventLogFrame:Hide();
		selected_eid = 0;
	else
		Slacker_DKP_EventLogFrame:Show();
	end
end

function Slacker_DKP_ToggleEdit()
	if (Slacker_DKP_EditFrame:IsVisible()) then
		Slacker_DKP_EditFrame:Hide();
	else
		Slacker_DKP_EditFrame:Show();
	end
end

function Slacker_DKPPlayerList()
	local PlayerNames = "";
 
	for i = 1, GetNumRaidMembers() do
		name, _, _, _, _, _, _, online, _ = GetRaidRosterInfo(i);
		if (online) then
		
			local rank = Slacker_DKP_GetRank(name);
			local primary = Slacker_DKP_GetPrimary(name);

			if(rank) then
				if(string.find(rank," Alt")) then
					if(not primary) then
						SendChatMessage("sDKP: You are an alt but your guild note does not indicate who your main is!  Please correct this.", "WHISPER", this.language, name);
						Slacker_DKP_Message("Attendance Incomplete.  "..name.." has no main listed.");
					end
				end
			end
		
			if(SLACKER_SAVED_SETTINGS['mapalts'] == 'yes') then

				if(primary) then
					PlayerNames = PlayerNames..primary.." ";
				else
					PlayerNames = PlayerNames..name.." ";
				end
			else
				PlayerNames = PlayerNames..name.." ";
			end
			
		end
	end

	return PlayerNames;
end

function Slacker_NewTS()
	local ts = time();
	local maxts = 0;
	
	for i=1, getn (SLACKER_SAVED_EVENTLOG) do
		local ets = SLACKER_SAVED_EVENTLOG[i]['ts'];
		if(tonumber(ets) > tonumber(maxts)) then
			maxts = ets;
		end
	end
	if(ts > maxts) then
		return ts;
	else
		return maxts + 1;
	end
end

function Slacker_DKP_LogLoot(name,item,link)
	local ts = Slacker_NewTS();

	if(SLACKER_SAVED_SETTINGS['active'] == 'no') then
		return 0;
	end

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts,
		["type"] = 'LOOT',
	}
	
	SLACKER_SAVED_LOOTLOG[ts] = {
		["player"] = name,
		["item"] = item,
		["link"] = link,
	};
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_Message("Loot "..item.." to "..name.." recorded at "..date("%H:%M").." on "..date("%d-%b-%Y"));
end

function Slacker_DKP_AttendanceLog(parms)
	Slacker_DKP_LoadAltList();
	local PlayerList = Slacker_DKPPlayerList();
	local ts = Slacker_NewTS();

	if(SLACKER_SAVED_SETTINGS['active'] == 'no') then
		return 0;
	end

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts,
		["type"] = 'ATT',
	};

	SLACKER_SAVED_ATTLOG[ts] = {
		["location"] = GetZoneText(),
		["comments"] = parms,
		["playerlist"] = PlayerList
	};
	
	PlaySound("GnomeExploration");
	Slacker_DKP_EventLogBar_Update();
	
	Slacker_DKP_Message("Raid Attendance recorded at "..date("%H:%M").." on "..date("%d-%b-%Y"));
	if(SLACKER_SAVED_SETTINGS['raidatt'] == 'yes') then
		Slacker_DKP_Announce('RAID',"Raid Attendance recorded at "..date("%H:%M").." on "..date("%d-%b-%Y"));
	end
	
	return 1;
end

function Slacker_DKP_BossKillNew(parms)
	StaticPopupDialogs["SDKP_NOTARGET"] = {
		text = "You must target the corpse first",
		button1 = "Dang, I knew that",
		timeout = 30,
	};

	local bossname = UnitName("Target");

	if (not bossname) then
		StaticPopup_Show ("SDKP_NOTARGET");
		return 0;
	else
		return Slacker_DKP_BossKillLog(bossname,parms);
	end
end

function Slacker_DKP_BossKillLog(bossname,parms)
	local PlayerList = Slacker_DKPPlayerList();
	local ts = Slacker_NewTS();

	if(SLACKER_SAVED_SETTINGS['active'] == 'no') then
		return 0;
	end

	if(SLACKER_SAVED_SETTINGS['dkpplayer'] == 'yes') then
		PlayerList = PlayerList..'DKP ';
	end

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts,
		["type"] = 'BOSSKILL',
	};

	SLACKER_SAVED_BOSSKILLS[ts] = {
		["bossname"] = bossname,
		["location"] = GetZoneText(),
		["comments"] = parms,
		["playerlist"] = PlayerList
	};

	if (SLACKER_SAVED_BOSSES[bossname]) then 
		SLACKER_SAVED_BOSSES[bossname] = SLACKER_SAVED_BOSSES[bossname] + 1;
	else
		SLACKER_SAVED_BOSSES[bossname] = 1;
	end
	
	PlaySound("LEVELUPSOUND");
	Slacker_DKP_EventLogBar_Update();

	Slacker_DKP_Message(bossname.." kill "..SLACKER_SAVED_BOSSES[bossname].." recorded at "..date("%H:%M").." on "..date("%d-%b-%Y"));
	if(SLACKER_SAVED_SETTINGS['announcekills'] == 'yes') then
		Slacker_DKP_Announce('GUILD',bossname.." kill "..SLACKER_SAVED_BOSSES[bossname].." recorded at "..date("%H:%M").." on "..date("%d-%b-%Y"));
	end
	
	return 1;
end

function Slacker_DKP_ClearLogs()
	SLACKER_SAVED_EVENTLOG = nil;
	SLACKER_SAVED_BOSSKILLS = nil;
	SLACKER_SAVED_LOOTLOG = nil;
	SLACKER_SAVED_ATTLOG = nil;
	
	SLACKER_SAVED_DKP = {};
	SLACKER_SAVED_GEAR = {};
	SLACKER_SAVED_EVENTLOG = {};
	SLACKER_SAVED_BOSSKILLS = {};
	SLACKER_SAVED_LOOTLOG = {};
	SLACKER_SAVED_ATTLOG = {};
	
	selected_eid = 0;
	edti_eid = 0;
	
	Slacker_DKP_EventLogBar_Update();	
end

function Slacker_DKP_Announce(context, buf)
	SendChatMessage("sDKP: "..buf, context, nil, nil);
end

function Slacker_DKP_Toggle(buf)
	local setting = '';
	local flag = '';
	
	if(buf == '') then
		return;
	end

	if(not string.find(buf, " ")) then
		setting = string.lower(buf);
	else
		setting = string.lower(string.sub(buf,1,string.find(buf, " ")-1));
		flag    = string.sub(buf,string.find(buf, " ")+1,256);
	end

	if(flag == 'on' or flag == 'yes') then
		SLACKER_SAVED_SETTINGS[setting] = 'yes';
	elseif(flag == "off" or flag == 'no') then
		SLACKER_SAVED_SETTINGS[setting] = 'no';
	else
		if(flag ~= '') then
			Slacker_DKP_Debug('setting '..setting..' to '..flag);
			SLACKER_SAVED_SETTINGS[setting] = flag;
		end
	end

	if(SLACKER_SAVED_SETTINGS[setting] == 'yes') then
		Slacker_DKP_Message(SLACKER_SETTING[setting]..ENABLED);
	elseif(SLACKER_SAVED_SETTINGS[setting] == 'no') then
		Slacker_DKP_Message(SLACKER_SETTING[setting]..DISABLED);
	else
		local value = SLACKER_SAVED_SETTINGS[setting];
		
		if(setting == 'rarity') then
			Slacker_DKP_Message(SLACKER_SETTING[setting]..SLACKER_ITEM_RARITY[value]..' ('..value..')');	
		else
			Slacker_DKP_Message(SLACKER_SETTING[setting]..value);	
		end
	end
end

function Slacker_DKP_GetPrimary(playername)
	local guildcount = GetNumGuildMembers();
	local primaryname;
	
	for i=1, guildcount do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, year, month, day, hour;
		name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i);
		
		if(name == playername) then
			local _,_, mainname = string.find(note, "([^%s]+)'s Alt");
			if(mainname) then
				return mainname;
			else
				return
			end
		end
	end
end

function Slacker_DKP_GetRank(playername)
	local guildcount = GetNumGuildMembers();
	local primaryname;
	
	for i=1, guildcount do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, year, month, day, hour;
		name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i);
		
		if(name == playername) then
			return rank;
		end
	end
end


function Slacker_DKP_LoadAltList()
	GuildRoster();
	local guildcount = GetNumGuildMembers(true);
	local primaryname;

	SLACKER_SAVED_ALTS = nil;
	SLACKER_SAVED_ALTS = {};
	SLACKER_SAVED_CLASSES = nil;
	SLACKER_SAVED_CLASSES = {};
	for i=1, guildcount do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, year, month, day, hour;
		name, rank, rankIndex, level, class, zone, note, officernote, online = GetGuildRosterInfo(i);
	
		local _,_, mainname = string.find(note, "([^%s]+)'s Alt");
		if(mainname) then
			SLACKER_SAVED_ALTS[name] = mainname;
		end
		SLACKER_SAVED_CLASSES[name] = class;
	end

end

function Slacker_DKP_CommandHandler(buf)
	if(buf) then
		if(buf == '') then
			Slacker_DKP_Message(SLACKERDKP_CHAT_COMMAND_USAGE);
		else
			local command = '';
			local args = '';

			if(not string.find(buf, " ")) then
				command = string.lower(buf);
			else
				command = string.lower(string.sub(buf,1,string.find(buf, " ")-1));
				args    = string.sub(buf,string.find(buf, " ")+1,256);
			end

			if(command == 'help') then
				Slacker_DKP_Message(SLACKERDKP_CHAT_COMMAND_USAGE);
			elseif(command == 'version') then
				Slacker_DKP_Version();
			elseif(command == 'toggle') then
				Slacker_DKP_ToggleFrame();
			elseif(command == 'edit') then
				Slacker_DKP_ToggleEdit();
			elseif(command == 'att') then
				Slacker_DKP_AttendanceLog(args)
			elseif(command == 'bosskill') then
				Slacker_DKP_BossKillNew(args);
			elseif(command == 'clear') then
				Slacker_DKP_ClearLogs();
			elseif(command == 'ignore') then
				SLACKER_SAVED_IGNORED[args] = 'yes';
				Slacker_DKP_Message("Ignoring all "..args.." drops.");
			elseif(command == 'unignore') then
				SLACKER_SAVED_IGNORED[args] = nil;
				Slacker_DKP_Message("No longer ignoring all "..args.." drops.");
			elseif(command == 'set') then
				Slacker_DKP_Toggle(args);
			elseif(command == 'bossignore') then			
				SLACKER_SAVED_BOSSES[args] = nil;
			elseif(command == 'primary') then
				local membername = Slacker_DKP_GetPrimary(args);
				Slacker_DKP_Message(args.." is really "..membername);
			else
				Slacker_DKP_Message(SLACKERDKP_UNKNOWN_COMMAND..": "..command);
				Slacker_DKP_Message(SLACKERDKP_CHAT_COMMAND_USAGE);
			end
		end
	end
end
