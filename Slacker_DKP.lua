-- SlackerDKP AddOn - http://slacker.com/~nugget/projects/slackerdkp/
-- (c) Copyright 2006 David McNett.  All Rights Reserved.
--
-- $Id$
-- 

local version = "1.17";
local builddate = "4-Nov-1970";
local buildnum = 0;
local cvsversion = '$Id$';
_,_,buildnum,builddate = string.find(cvsversion, ",v 1.([^%s]+)% ([^%s]+) ");
local selected_eid = 0;
local edit_eid = 0;
local selected_wl = 0;
local selected_bname = '';

local Slacker_Orig_ChatFrame_OnEvent;
local last_whisper_time = 0
local last_whisper_event = '';

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

SLACKER_SAVED_WAITLIST = {};

function Slacker_DKP_OnLoad()
	this:RegisterEvent("PLAYER_LOGIN");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("LOOT_OPENED");
	this:RegisterEvent("CHAT_MSG_LOOT");
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH");
	this:RegisterEvent("CHAT_MSG_MONSTER_YELL");	
	this:RegisterEvent("RAID_ROSTER_UPDATE");
		
	SlashCmdList["SLACKERDKP"] = Slacker_DKP_CommandHandler;
	SLASH_SLACKERDKP1 = "/sdkp";
	
	Slacker_DKP_LoadAltList();
	
	Slacker_Orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
	ChatFrame_OnEvent = Slacker_ChatFrame_OnEvent;
end

function Slacker_DKP_OnEvent()
	if(event == "ADDON_LOADED" and arg1 == "Slacker_DKP") then
		Slacker_DKP_Version();
		if(SLACKER_SAVED_SETTINGS['rarity'] == nil) then
			Slacker_DKP_Toggle('rarity 4');
		end
		if(SLACKER_SAVED_SETTINGS['scale'] == nil) then
			Slacker_DKP_Toggle('scale 100');
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
	elseif (event == "RAID_ROSTER_UPDATE") then
		Slacker_DKP_List('verify');
	end
end

function Slacker_ChatFrame_OnEvent(event)
	if( event == "CHAT_MSG_WHISPER" ) then
		if( last_whisper_time > (time() - 2) and last_whisper_event == arg2..arg1) then
			Slacker_DKP_Debug("Ignoring duplicate request");
		else
			last_whisper_time = time();
			last_whisper_event = arg2..arg1;
			
			Slacker_DKP_Debug(arg2..' whispered "'..arg1..'"');
			
			if( string.lower(arg1) == "!addme" ) then
				Slacker_DKP_List('add',arg2);
			elseif( string.lower(arg1) == "!waitlist" ) then
				Slacker_DKP_List('show',arg2);
			elseif( string.lower(arg1) == "!dropme" ) then
				Slacker_DKP_List('drop',arg2);
			else
				Slacker_Orig_ChatFrame_OnEvent(event);
			end
		end
	elseif( event == "CHAT_MSG_WHISPER_INFORM" ) then
		if ( string.find(arg1,'sDKP') == nil) then
			Slacker_Orig_ChatFrame_OnEvent(event);
		end
	else
		Slacker_Orig_ChatFrame_OnEvent(event);
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

function Slacker_DKP_PlayerRaidRank(player)
	for i=1,GetNumRaidMembers() do
  		local name, rank, grp, lvl, lclass, class, zone, online, dead = GetRaidRosterInfo(i);
 		if(name == player) then
			return rank;
		end
	end
	return 0;
end

function Slacker_DKP_List(action,player)
	local ts = time();

	if(action == 'add') then
		local pos = Slacker_DKP_List('position',player);
		if(pos > 0) then
			SendChatMessage("sDKP: You were already on the list, silly cow.  You're number "..pos..".", "WHISPER", this.language, player);
		else
			local pos = (getn (SLACKER_SAVED_WAITLIST)+1);
			SLACKER_SAVED_WAITLIST[pos] = {
				["ts"] = ts,
				["player"] = player,
			};
			SendChatMessage("sDKP: You're number "..pos.." on the list.", "WHISPER", this.language, player);
			Slacker_DKP_Message("sDKP: Added "..player.." to waiting list ("..pos.." waiting)");
			selected_wl = 0;
		end		
	elseif(action == 'drop') then
		local pos = Slacker_DKP_List('position',player);
		if(pos == 0) then
			SendChatMessage("sDKP: You're not on the list!", "WHISPER", this.language, player);
		else
			local entries = getn (SLACKER_SAVED_WAITLIST);
			for row=pos,entries do
				if(row == entries) then
					SLACKER_SAVED_WAITLIST[row] = nil;
				else
					SLACKER_SAVED_WAITLIST[row]["player"] = SLACKER_SAVED_WAITLIST[row+1]["player"];
					SLACKER_SAVED_WAITLIST[row]["ts"] = SLACKER_SAVED_WAITLIST[row+1]["ts"];					
				end
			end
			SendChatMessage("sDKP: You're off the list.", "WHISPER", this.language, player);
			Slacker_DKP_Message('sDKP: Removed '..player..' from waiting list.');
			selected_wl = 0;
			if(pos <= 3) then
				Slacker_DKP_List('remind');
			end
		end
	elseif(action == 'show') then
		local pos = Slacker_DKP_List('position',player);
		local size = getn(SLACKER_SAVED_WAITLIST);
		
		if(size == 0) then
			SendChatMessage("sDKP: The waiting list is empty.", "WHISPER", this.language, player);
		else
			local msgbuf = '';
			for row=1,getn(SLACKER_SAVED_WAITLIST) do
				msgbuf = msgbuf..SLACKER_SAVED_WAITLIST[row]["player"].." ";
			end
			
			if(Slacker_DKP_PlayerRaidRank(player) >= 1) then
				SendChatMessage("sDKP: The list is: "..msgbuf, "WHISPER", this.language, player);
			else
				if(pos > 0) then
					SendChatMessage("sDKP: You're number "..pos.." on the list.", "WHISPER", this.language, player);
				else
					SendChatMessage("sDKP: You're not on the list.", "WHISPER", this.language, player);
				end
			end
			
			Slacker_DKP_Message('sDKP: Sent waiting list to '..player);
		end
	elseif(action == 'position') then
		for pos=1,getn (SLACKER_SAVED_WAITLIST) do
			if( SLACKER_SAVED_WAITLIST[pos]["player"] == player) then
				return pos;
			end
		end
		return 0;
	elseif(action == 'verify') then
		local plist = " "..Slacker_DKP_PlayerList().." Ryden ";
		local purges = {};
		local purgecount = 0;
		
		Slacker_DKP_Debug('Looping to verify wait list');
		for row=1,getn(SLACKER_SAVED_WAITLIST) do
			local pname = SLACKER_SAVED_WAITLIST[row]["player"];
			
			if not (string.find(plist,' '..pname..' ') == nil) then
				Slacker_DKP_Debug(pname.." is in the party, removing from waiting list.");
				purgecount = purgecount + 1;
				purges[purgecount] = pname;
				selected_wl = 0;
			end
		end
		if( purgecount > 0 ) then
			for row=1,purgecount do
				Slacker_DKP_List('drop',purges[purgecount]);
			end
			Slacker_DKP_List('remind');
		end
	elseif(action == 'remind') then
		local limit = getn(SLACKER_SAVED_WAITLIST);
		if(limit > 3) then
			limit = 3;
		end
		for row=1,limit do
			local player = SLACKER_SAVED_WAITLIST[row]["player"];
			Slacker_DKP_Message('sDKP: Reminded '..player..' to be near the entrance.');
			SendChatMessage("sDKP: You're number "..row.." on the list.  You should be near the entrance in case a spot opens up soon.", "WHISPER", this.language, player);
		end
	end
	Slacker_DKP_WaitListBar_Update();
end

function Slacker_DKP_ItemInfo(link)
	local _, _, id = string.find(link, "item:(%d+):");
    local itemName, itemLink, itemRarity, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(id);
	local info = {};

	info.id = id;
	info.name = itemName;
	info.link = itemLink;
	info.rarity = itemRarity;
	info.icon = itemTexture;
	
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
	Event_DEItem:Hide();		
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
			Event_DownItem:Show();
			Event_BidItem:Show();
			Event_DEItem:Show();		
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
					if(loottype == 'DE') then
						color = tscolor;
						description = "Disenchanted "..SLACKER_SAVED_LOOTLOG[ets]['item'];
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

function Slacker_DKP_WaitListBar_Update()
	local row;
	local entries;
	
	entries = getn (SLACKER_SAVED_WAITLIST);
	
	if(entries <= 10) then
		Slacker_DKP_WaitListBar:Hide();
	else 
		Slacker_DKP_WaitListBar:Show();
	end
	
	WL_DeleteEntry:Hide();
	WL_Invite:Hide();
	WL_Up:Hide();		
	WL_Down:Hide();		

	if(selected_wl > 0) then
		WL_DeleteEntry:Show();
		WL_Invite:Show();
		WL_Down:Show();
		WL_Up:Show();
	end
	
	local color = "|cffFFFFFF";
	if(GetNumRaidMembers() < 40) then
		color = "|cffFF7F7F";
	end
	
	FauxScrollFrame_Update(Slacker_DKP_WaitListBar,entries,10,17);
	for row=1,10 do
		local time = getglobal("WaitList"..row.."FieldTime");
		local player = getglobal("WaitList"..row.."FieldPlayer");
		local highlight = getglobal("WaitList"..row.."FieldHighlight");
		local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_WaitListBar);
		local eventrow = getglobal("WaitList"..row);
	
		if eid <= entries then
			local ets = SLACKER_SAVED_WAITLIST[eid]['ts'];
			
			if(ets) then
				time:SetText(color..date("%H:%M",SLACKER_SAVED_WAITLIST[eid]['ts']));
				player:SetText(color..SLACKER_SAVED_WAITLIST[eid]['player']);
				eventrow:Show();
				if(selected_wl== eid) then
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

function Slacker_DKP_BossListBar_Update()
	local row;
	local entries = 0;
	local bosslist = {};
	
	for key,value in pairs(SLACKER_SAVED_BOSSES) do
		entries = entries + 1;
		bosslist[entries] = key;
	end

	sort(bosslist);
	
	if(entries <= 10) then
		Slacker_DKP_BossListBar:Hide();
	else 
		Slacker_DKP_BossListBar:Show();
	end
	
	BL_DeleteEntry:Hide();

	if not (selected_bname == '') then
		BL_DeleteEntry:Show();
	end
	
	FauxScrollFrame_Update(Slacker_DKP_BossListBar,entries,10,17);
	for row=1,10 do
		local kills = getglobal("BossList"..row.."FieldKills");
		local bossname = getglobal("BossList"..row.."FieldBossname");
		local highlight = getglobal("BossList"..row.."FieldHighlight");
		local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_BossListBar);
		local eventrow = getglobal("BossList"..row);
	
		if eid <= entries then
			local ebname = bosslist[eid];
			local ekills = SLACKER_SAVED_BOSSES[ebname];
			
			if(ebname) then
				kills:SetText(ekills);
				bossname:SetText(ebname);
				eventrow:Show();
				if(selected_bname == ebname) then
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
			local texture,item,quantity,quality = GetLootSlotInfo(index);
			local itemlink = GetLootSlotLink(index);
			local info = Slacker_DKP_ItemInfo(itemlink);

			if(info.rarity >= tonumber(SLACKER_SAVED_SETTINGS['rarity'])) then
				items = items + 1;

				Slacker_DKP_Debug("Tracking item "..items.." ("..item..")");
	
				SLACKER_SAVED_LOOTLIST[items] = {
					["name"] = item,
					["link"] = itemlink,
				};
		
				msgbuf = msgbuf.." "..itemlink;
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

function Slacker_DKP_WaitListOnClick(button)
	local row = this:GetID();
	local eid = row + FauxScrollFrame_GetOffset(Slacker_DKP_WaitListBar);
	
	selected_wl = eid;
	
	Slacker_DKP_WaitListBar_Update();
end

function Slacker_DKP_BossListOnClick(button)
	local row = this:GetID();
	local bossname = getglobal("BossList"..row.."FieldBossname");
	
	selected_bname = bossname:GetText();
	Slacker_DKP_Debug("You selected "..selected_bname);

	Slacker_DKP_BossListBar_Update();
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

function Slacker_DKP_WaitList_DeleteEntry()
	local eid = selected_wl;
	local count = getn (SLACKER_SAVED_WAITLIST);
	
	if(eid > 0) then
		for i=1,count do
			local eplayer = SLACKER_SAVED_WAITLIST[i]['player'];
			local ets = SLACKER_SAVED_WAITLIST[i]['ts'];
		
			if (i > eid) then
				if(i > 1) then
					local j=i-1;
					SLACKER_SAVED_WAITLIST[j] = SLACKER_SAVED_WAITLIST[i];
				end
			end
		end
		SLACKER_SAVED_WAITLIST[count] = nil;
	end

	selected_wl = 0;

	PlaySound("INTERFACESOUND_CURSORDROPOBJECT");
	
	Slacker_DKP_WaitListBar_Update();
end

function Slacker_DKP_BossList_DeleteEntry()

	if not (selected_bname == '') then
		PlaySound("INTERFACESOUND_CURSORDROPOBJECT");
		SLACKER_SAVED_BOSSES[selected_bname] = nil;
		selected_bname = '';
	end
	
	Slacker_DKP_BossListBar_Update();
end

function Slacker_DKP_WaitList_Invite()
	local eid = selected_wl;
 
	if(eid > 0) then
		InviteByName(SLACKER_SAVED_WAITLIST[eid]['player']);
	end
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

function Slacker_DKP_WaitList_Bump(direction)
	local entries;
	entries = getn (SLACKER_SAVED_WAITLIST);

	if(selected_wl > 0) then
		local eplayer = SLACKER_SAVED_WAITLIST[selected_wl]['player'];
		local ets = SLACKER_SAVED_WAITLIST[selected_wl]['ts'];

		if(direction == 'U') then
			target_wl = selected_wl + 1;
		else
			target_wl = selected_wl - 1;
		end
		
		if(target_wl > 0 and target_wl <= entries) then
			SLACKER_SAVED_WAITLIST[selected_wl]['player'] = SLACKER_SAVED_WAITLIST[target_wl]['player'];
			SLACKER_SAVED_WAITLIST[selected_wl]['ts'] = SLACKER_SAVED_WAITLIST[target_wl]['ts'];

			SLACKER_SAVED_WAITLIST[target_wl]['player'] = eplayer;
			SLACKER_SAVED_WAITLIST[target_wl]['ts'] = ets;			
		end

		selected_wl = target_wl;
		Slacker_DKP_WaitListBar_Update();		
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
		Slacker_DKP_ReScale(SLACKER_SAVED_SETTINGS['scale']);
		Slacker_DKP_EventLogFrame:Show();
	end
end

function Slacker_DKP_WL_ToggleFrame()
	if (Slacker_DKP_WaitListFrame:IsVisible()) then
		Slacker_DKP_WaitListFrame:Hide();
		selected_wl = 0;
	else
		Slacker_DKP_WaitListFrame:Show();
	end
end

function Slacker_DKP_BL_ToggleFrame()
	if (Slacker_DKP_BossListFrame:IsVisible()) then
		Slacker_DKP_BossListFrame:Hide();
		selected_bname = '';
	else
		Slacker_DKP_BossListFrame:Show();
	end
end

function Slacker_DKP_ToggleEdit()
	if (Slacker_DKP_EditFrame:IsVisible()) then
		Slacker_DKP_EditFrame:Hide();
	else
		Slacker_DKP_EditFrame:Show();
	end
end

function Slacker_DKP_PlayerList()
	local PlayerNames = "";
 
	for i = 1, GetNumRaidMembers() do
		name, _, _, _, _, _, _, online, _ = GetRaidRosterInfo(i);
		if (online) then
		
			local rank = Slacker_DKP_GetRank(name);
			local primary = Slacker_DKP_GetPrimary(name);
		
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

function Slacker_DKP_WaitList()
	local PlayerNames = "";
	
	for row=1, getn (SLACKER_SAVED_WAITLIST) do
		local name = SLACKER_SAVED_WAITLIST[row]["player"];
		
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
	local PlayerList = Slacker_DKP_PlayerList();
	local ts = Slacker_NewTS();

	local CountMsg = GetNumRaidMembers().." players";

	if(SLACKER_SAVED_SETTINGS['active'] == 'no') then
		return 0;
	end

	if(SLACKER_SAVED_SETTINGS['waitlista'] == 'yes') then
		local listsize = getn (SLACKER_SAVED_WAITLIST);
		if (listsize > 0) then
			PlayerList = PlayerList..Slacker_DKP_WaitList();
			CountMsg = CountMsg.." and "..listsize.." on the list";
		end
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
		Slacker_DKP_Announce('RAID',"Raid Attendance recorded at "..date("%H:%M").." on "..date("%d-%b-%Y")..". ("..CountMsg..")");
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
	local PlayerList = Slacker_DKP_PlayerList();
	local ts = Slacker_NewTS();

	if(SLACKER_SAVED_SETTINGS['active'] == 'no') then
		return 0;
	end

	if(SLACKER_SAVED_SETTINGS['dkpplayer'] == 'yes') then
		PlayerList = PlayerList..'DKP ';
	end

	if(SLACKER_SAVED_SETTINGS['waitlistb'] == 'yes') then
		local listsize = getn (SLACKER_SAVED_WAITLIST);
		if (listsize > 0) then
			PlayerList = PlayerList..Slacker_DKP_WaitList();
		end
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
	SLACKER_SAVED_WAITLIST = nil;
	
	SLACKER_SAVED_DKP = {};
	SLACKER_SAVED_GEAR = {};
	SLACKER_SAVED_EVENTLOG = {};
	SLACKER_SAVED_BOSSKILLS = {};
	SLACKER_SAVED_LOOTLOG = {};
	SLACKER_SAVED_ATTLOG = {};
	SLACKER_SAVED_WAITLIST = {};
	
	selected_eid = 0;
	selected_wl = 0;
	selected_bname = '';
	edit_eid = 0;
	
	Slacker_DKP_EventLogBar_Update();
	Slacker_DKP_WaitListBar_Update();
	Slacker_DKP_BossListBar_Update();
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
	
	if(setting == 'scale') then
		SLACKER_SAVED_SETTINGS[setting] = tonumber(SLACKER_SAVED_SETTINGS[setting]);
		if((SLACKER_SAVED_SETTINGS[setting] > 120) or (SLACKER_SAVED_SETTINGS[setting] < 40)) then
			SLACKER_SAVED_SETTINGS[setting] = 100;
		end
		Slacker_DKP_ReScale(SLACKER_SAVED_SETTINGS[setting]);
	end
end

function Slacker_DKP_Config_ToggleFrame()
	Slacker_DKP_Message("Sorry, this feature is not implemented.");
end

function Slacker_DKP_ReScale(scale)
	
	Slacker_DKP_Debug("Setting scaling to "..scale.."%");
	
	scale = tonumber(scale);
	
	if (scale == nil) then
		return;
	end
	if((scale < 1) or (scale > 120)) then
		return;
	end

	scale = scale / 100;
	
	Slacker_DKP_EventLogFrame:SetScale(scale);
	Slacker_DKP_WaitListFrame:SetScale(scale);
	Slacker_DKP_BossListFrame:SetScale(scale);	
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
