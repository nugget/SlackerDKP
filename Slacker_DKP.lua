-- Slacker DKP AddOn - http://slacker.com/~nugget/projects/slackerdkp/
-- (c) Copyright 2006 David McNett.  All Rights Reserved.
--
-- $Id$
-- 

local version = "1.0ß";
local builddate = "6-May-2006";
local selected_eid = 0;
local edit_eid = 0;
local debug = 1;

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
		
	SlashCmdList["SLACKERDKP"] = Slacker_DKP_CommandHandler;
	SLASH_SLACKERDKP1 = "/sdkp";
end

function Slacker_DKP_OnEvent()
	if(event == "ADDON_LOADED" and arg1 == "Slacker_DKP") then
		Slacker_DKP_Version();
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
			local info = Nurfed_DKP:ItemInfo(itemlink);
			if (info) then
				if(SLACKER_SAVED_IGNORED[info.name]) then
					Slacker_DKP_Debug("Ignoring "..info.name.." drop.");
				else
					Slacker_DKP_LogLoot(name,info.name);
				end
			end
		end	
	elseif (event == "CHAT_MSG_COMBAT_HOSTILE_DEATH") then
		local mob;
		local _, _, mob = string.find(arg1, "(.+) dies.");
		if (mob) then
			if(SLACKER_SAVED_BOSSES[mob]) then
				Slacker_DKP_BossKillLog(mob,"auto-logged");
			end
		end
	elseif (event == "LOOT_OPENED") then
		Slacker_DKP_LootWalk();
	end
end

function Slacker_DKP_Version()
	Slacker_DKP_Message("Slacker DKP v"..version.." ("..builddate..") loaded.");
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
	if type(buf) == 'string' then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFdebug:"..buf);
	else
		for key, line in buf do
			DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFdebug:"..line);
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
	
	if(selected_eid == 0) then
		Event_DEItem:Hide();
		Event_DeleteEntry:Hide();
		Event_Edit:Hide();
	else
		Event_DeleteEntry:Show();
		if(SLACKER_SAVED_EVENTLOG[selected_eid]['type'] == 'LOOT') then
			Event_DEItem:Show();
			Event_Edit:Hide();
		else
			Event_DEItem:Hide();
			Event_Edit:Show();
		end
	end
		
	FauxScrollFrame_Update(Slacker_DKP_EventLogBar,entries,10,14);
	for row=1,10 do
		local time = getglobal("EventLog"..row.."FieldTime");
		local comments = getglobal("EventLog"..row.."FieldComments");
		local highlight = getglobal("EventLog"..row.."FieldHighlight");
		local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_EventLogBar);
		local eventrow = getglobal("EventLog"..row);
		local description = '';
		
		if eid <= entries then
			local color = "|cffFFFFFF";
			local etype = SLACKER_SAVED_EVENTLOG[eid]['type'];
			local ets = SLACKER_SAVED_EVENTLOG[eid]['ts'];
			
			if(etype == 'BOSSKILL') then
				color = "|cffFF7F7F";
				description = "Killed "..SLACKER_SAVED_BOSSKILLS[ets]['bossname'].." ("..SLACKER_SAVED_BOSSKILLS[ets]['comments']..")";
			elseif(etype == 'LOOT') then
				color = "|cff7FFF7F";
				description = SLACKER_SAVED_LOOTLOG[ets]['player'].." looted "..SLACKER_SAVED_LOOTLOG[ets]['item'];
			elseif(etype == 'ATT') then
				description = "Attendance ("..SLACKER_SAVED_ATTLOG[ets]['comments']..")";
			end

			time:SetText(date("%H:%M",SLACKER_SAVED_EVENTLOG[eid]['ts']));
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
					SLACKER_SAVED_LOOTLOG[ets]['player'] = nil;
					SLACKER_SAVED_LOOTLOG[ets]['item'] = nil;					
					SLACKER_SAVED_LOOTLOG[ets] = nil;
				elseif(etype == 'BOSSKILL') then
					SLACKER_SAVED_BOSSKILLS[ets]['bossname'] = nil;
					SLACKER_SAVED_BOSSKILLS[ets]['location'] = nil;
					SLACKER_SAVED_BOSSKILLS[ets]['comments'] = nil;
					SLACKER_SAVED_BOSSKILLS[ets]['playerlist'] = nil;
					SLACKER_SAVED_BOSSKILLS[ets] = nil;
				elseif(etype == 'ATT') then
					SLACKER_SAVED_ATTLOG[ets]['location'] = nil;
					SLACKER_SAVED_ATTLOG[ets]['comments'] = nil;
					SLACKER_SAVED_ATTLOG[ets]['playerlist'] = nil;					
					SLACKER_SAVED_ATTLOG[ets] = nil;
				end
			elseif (i > eid) then
				if(i > 1) then
					local j=i-1;
					SLACKER_SAVED_EVENTLOG[j]['ts'] = SLACKER_SAVED_EVENTLOG[i]['ts'];   -- attempt to index field '?' (a nil value)
					SLACKER_SAVED_EVENTLOG[j]['type'] = SLACKER_SAVED_EVENTLOG[i]['type'];
				end
			end
		end
		SLACKER_SAVED_EVENTLOG[count]['ts'] = nil;
		SLACKER_SAVED_EVENTLOG[count]['type'] = nil;
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
		end		
	end
end

function Slacker_DKP_EditWindow_Save()
	if(edit_eid > 0) then
		local etype = SLACKER_SAVED_EVENTLOG[edit_eid]['type'];
		local ets = SLACKER_SAVED_EVENTLOG[edit_eid]['ts'];
		
		local newtext = Slacker_DKP_EditFrameComment:GetText();
						
		if(etype == 'BOSSKILL') then
			SLACKER_SAVED_BOSSKILLS[ets]['comments'] = newtext;
			Slacker_DKP_EditFrame:Hide();
		elseif(etype == 'ATT') then
			SLACKER_SAVED_ATTLOG[ets]['comments'] = newtext;
			Slacker_DKP_EditFrame:Hide();
		end		
		
		edit_eid = 0;
		Slacker_DKP_EditFrameComment:SetText("");

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
			if(SLACKER_SAVED_SETTINGS['mapalts'] == 'yes') then
				local primary = Slacker_DKP_GetPrimary(name);

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

function Slacker_DKP_LogLoot(name,item,dkp,secdkp)
	local ts = date("%s");

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts;
		["type"] = 'LOOT';
	}
	
	SLACKER_SAVED_LOOTLOG[ts] = {
		["player"] = name,
		["item"] = item,
	};
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_Message("Loot "..item.." to "..name.." recorded at "..date("%H:%M on %d-%b-%Y"));
end

function Slacker_DKP_AttendanceLog(parms)
	Slacker_DKP_LoadAltList();
	local PlayerList = Slacker_DKPPlayerList();
	local ts = date("%s");

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
	
	Slacker_DKP_Message("Raid Attendance recorded at "..date("%H:%M on %d-%b-%Y"));
	if(SLACKER_SAVED_SETTINGS['raidatt'] == 'yes') then
		Slacker_DKP_Announce('RAID',"Raid Attendance recorded at "..date("%H:%M on %d-%b-%Y"));
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
	local ts = date("%s");

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

	Slacker_DKP_Message(bossname.." kill "..SLACKER_SAVED_BOSSES[bossname].." recorded at "..date("%H:%M on %d-%b-%Y"));
	if(SLACKER_SAVED_SETTINGS['announcekills'] == 'yes') then
		Slacker_DKP_Announce('GUILD',bossname.." kill "..SLACKER_SAVED_BOSSES[bossname].." recorded at "..date("%H:%M on %d-%b-%Y"));
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

	if(flag == 'on') then
		SLACKER_SAVED_SETTINGS[setting] = 'yes';
	elseif(flag == "off") then
		SLACKER_SAVED_SETTINGS[setting] = 'no';
	end

	if(SLACKER_SAVED_SETTINGS[setting] == 'yes') then
		Slacker_DKP_Message(SLACKER_SETTING[setting]..ENABLED);
	else
		Slacker_DKP_Message(SLACKER_SETTING[setting]..DISABLED);
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
