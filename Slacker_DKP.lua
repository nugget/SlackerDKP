-- Slacker DKP AddOn - http://slacker.com/~nugget/projects/slackerdkp/
-- (c) Copyright 2006 David McNett.  All Rights Reserved.
--
-- $Id$
-- 

local version = "0.1";
local builddate = "1-May-2006";
local selected_eid = 0;
local debug = 1;
local context = 'PARTY';

SLACKER_SAVED_DKP = {};
SLACKER_SAVED_GEAR = {};

SLACKER_SAVED_EVENTLOG = {};

SLACKER_SAVED_BOSSKILLS = {};
SLACKER_SAVED_LOOTLOG = {};
SLACKER_SAVED_ATTLOG = {};

SLACKER_SAVED_BOSSES = {};
SLACKER_SAVED_IGNORED = {};
SLACKER_SAVED_LOOTLIST = {};

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
		Slacker_DKP_Debug("chat_msg_combat: "..arg1);
		local mob;
		local _, _, mob = string.find(arg1, "(.+) dies.");
		if (mob) then
			Slacker_DKP_Debug("mob:"..mob);
			if(SLACKER_SAVED_BOSSES[mob]) then
				Slacker_DKP_BossKillLog(mob.." Auto-logged");
			end
		end
	elseif (event == "LOOT_OPENED") then
		Slacker_DKP_LootWalk();
	end
end

function Slacker_DKP_Version()
	Slacker_DKP_Message("Slacker DKP v"..version.." ("..builddate..") loaded.");
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
		Event_Edit:Show();
		if(SLACKER_SAVED_EVENTLOG[selected_eid]['type'] == 'LOOT') then
			Event_DEItem:Show();
		else
			Event_DEItem:Hide();
		end
	end
		
	FauxScrollFrame_Update(Slacker_DKP_EventLogBar,entries,10,14);
	for row=1,10 do
		local time = getglobal("EventLog"..row.."FieldTime");
		local comments = getglobal("EventLog"..row.."FieldComments");
		local highlight = getglobal("EventLog"..row.."FieldHighlight");
		local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_EventLogBar);
		local eventrow = getglobal("EventLog"..row);
		
		if eid <= entries then
			local color = "|cffFFFFFF";
		
			if(SLACKER_SAVED_EVENTLOG[eid]['type'] == 'BOSSKILL') then
				color = "|cffFF7F7F";
			elseif(SLACKER_SAVED_EVENTLOG[eid]['type'] == 'LOOT') then
				color = "|cff7FFF7F";		
			end

			time:SetText(date("%H:%M",SLACKER_SAVED_EVENTLOG[eid]['ts']));
			comments:SetText(color..SLACKER_SAVED_EVENTLOG[eid]['description']);
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
		Slacker_DKP_Message(msgbuf);
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
					SLACKER_SAVED_EVENTLOG[j]['description'] = SLACKER_SAVED_EVENTLOG[i]['description']
				end
			end
		end
		SLACKER_SAVED_EVENTLOG[count]['ts'] = nil;
		SLACKER_SAVED_EVENTLOG[count]['type'] = nil;
		SLACKER_SAVED_EVENTLOG[count]['description'] = nil;
		SLACKER_SAVED_EVENTLOG[count] = nil;
	end

	if(selected_eid > eid) then
		selected_eid = selected_eid - 1;
	elseif(selected_eid == eid) then
		selected_eid = 0;
	end
		
	Slacker_DKP_EventLogBar_Update();
end

function Slacker_DKP_EventLog_Edit()
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
			PlayerNames = PlayerNames..name.." ";
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
		["description"] = name..' looted '..item;
	}
	
	SLACKER_SAVED_LOOTLOG[ts] = {
		["player"] = name,
		["item"] = item,
	};
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_Message("Loot "..item.." to "..name.." recorded at "..date("%H:%M on %d-%b-%Y"));
end

function Slacker_DKP_AttendanceLog(parms)
	local PlayerList = Slacker_DKPPlayerList();
	local ts = date("%s");

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts,
		["type"] = 'ATT',
		["description"] = 'Attendance ('..parms..')',
	};

	SLACKER_SAVED_ATTLOG[ts] = {
		["location"] = GetZoneText(),
		["comments"] = parms,
		["playerlist"] = PlayerList
	};
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_Message("Raid Attendance recorded at "..date("%H:%M on %d-%b-%Y"));
end

function Slacker_DKP_BossKillLog(parms)
	local PlayerList = Slacker_DKPPlayerList();
	local ts = date("%s");

	StaticPopupDialogs["SDKP_NOTARGET"] = {
		text = "You must target the corpse first",
		button1 = "Dang, I knew that",
		timeout = 30,
	};

	if (not UnitName("target")) then
		StaticPopup_Show ("SDKP_NOTARGET");
		return;
	end

	local bossname = UnitName("Target");
	local PlayerList = Slacker_DKPPlayerList();

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts,
		["type"] = 'BOSSKILL',
		["description"] = 'Killed '..bossname,
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
	
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_Announce(bossname.." kill recorded at "..date("%H:%M on %d-%b-%Y"));
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
	
	Slacker_DKP_EventLogBar_Update();	
end

function Slacker_DKP_Announce(buf)
	SendChatMessage("sDKP: "..buf, context, nil, nil);
	SendChatMessage("sDKP: "..buf, "GUILD", nil, nil);
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
			elseif(command == 'toggle') then
				Slacker_DKP_ToggleFrame();
			elseif(command == 'edit') then
				Slacker_DKP_ToggleEdit();
			elseif(command == 'att') then
				Slacker_DKP_AttendanceLog(args)
			elseif(command == 'bosskill') then
				Slacker_DKP_BossKillLog(args);
			elseif(command == 'clear') then
				Slacker_DKP_ClearLogs();
			elseif(command == 'ignore') then
				SLACKER_SAVED_IGNORED[args] = 'yes';
				Slacker_DKP_Message("Ignoring all "..args.." drops.");
			elseif(command == 'unignore') then
				SLACKER_SAVED_IGNORED[args] = nil;
				Slacker_DKP_Message("No longer ignoring all "..args.." drops.");
			else
				Slacker_DKP_Message(SLACKERDKP_UNKNOWN_COMMAND..": "..command);
				Slacker_DKP_Message(SLACKERDKP_CHAT_COMMAND_USAGE);
			end
		end
	end
end
