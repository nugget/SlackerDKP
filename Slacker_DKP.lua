-- Slacker DKP AddOn - http://slacker.com/~nugget/projects/slackerdkp/
-- (c) Copyright 2006 David McNett.  All Rights Reserved.
--
-- $Id$
-- 

local version = "0.1";
local builddate = "1-May-2006";
local selected_eid = 0;

SLACKER_SAVED_DKP = {};
SLACKER_SAVED_GEAR = {};
SLACKER_SAVED_EVENTLOG = {};
SLACKER_SAVED_BOSSKILLS = {};
SLACKER_SAVED_LOOTLOG = {};
SLACKER_SAVED_ATTLOG = {};

function Slacker_DKP_OnLoad()
	this:RegisterEvent("PLAYER_LOGIN");
	this:RegisterEvent("CHAT_MSG_WHISPER");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("LOOT_OPENED");
	this:RegisterEvent("CHAT_MSG_LOOT");
	this:RegisterEvent("ADDON_LOADED");
		
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
				SLACKER_DKP_LogLoot(name,info.name);
			end
		end	
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

function Slacker_DKP_EventLogBar_Update()
	local row;
	local entries;
	
	entries = getn (SLACKER_SAVED_EVENTLOG);
	if(entries <= 10) then
		Slacker_DKP_EventLogBar:Hide();
	else 
		Slacker_DKP_EventLogBar:Show();
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

function Slacker_DKP_EventLogOnClick(button)
	local row = this:GetID();
	local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_EventLogBar);
	
	selected_eid = eid;
	Slacker_DKP_EventLogBar_Update();
end

function Slacker_DKP_ToggleFrame()
	if (Slacker_DKP_EventLogFrame:IsVisible()) then
		Slacker_DKP_EventLogFrame:Hide();
		selected_eid = 0;
	else
		Slacker_DKP_EventLogFrame:Show();
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

	local bossName = UnitName("Target");
	local PlayerList = Slacker_DKPPlayerList();

	local entries = getn (SLACKER_SAVED_EVENTLOG);
	SLACKER_SAVED_EVENTLOG[entries+1] = {
		["ts"] = ts,
		["type"] = 'BOSSKILL',
		["description"] = 'Killed '..bossName,
	};

	SLACKER_SAVED_BOSSKILLS[ts] = {
		["bossname"] = bossName,
		["location"] = GetZoneText(),
		["comments"] = parms,
		["playerlist"] = PlayerList
	};
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_Message("Boss kill of "..bossName.." recorded at "..date("%H:%M on %d-%b-%Y"));
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
			elseif(command == 'att') then
				Slacker_DKP_AttendanceLog(args)
			elseif(command == 'bosskill') then
				Slacker_DKP_BossKillLog(args);
			elseif(command == 'clear') then
				Slacker_DKP_ClearLogs();
			else
				Slacker_DKP_Message(SLACKERDKP_UNKNOWN_COMMAND..": "..command);
				Slacker_DKP_Message(SLACKERDKP_CHAT_COMMAND_USAGE);
			end
		end
	end
end
