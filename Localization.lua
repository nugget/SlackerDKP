-- Version : English 

BINDING_HEADER_SLACKERDKPHEADER				= "Slacker DKP";
BINDING_NAME_SLACKERDKP					= "Toggle Slacker DKP Window";
BINDING_NAME_SLACKERDKPATT				= "Add new Attendance Snapshot";
BINDING_NAME_SLACKERDKPBOSS				= "Add new Boss Kill";

SLACKERDKP_CHAT_COMMAND_INFO				= "Controls Slacker DKP from the command line - /sdkp for usage.";

SLACKERDKP_CHAT_COMMAND_USAGE				= {};
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, "Usage: /sdkp <command> [arguments]");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, "Commands:");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " version - Show SDKP Version and build information");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " clear - Clear logs and events and start over");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " toggle - Show/Hide main event log window");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " att <comments> - Take an attendance snapshot");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " bosskill <comments> - Log boss kill of targeted corpse");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " ignore <itemname> - Add itemname to list of ignored drops");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " unignore <itemname> - Remove itemname from list of ignored drops");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " set <setting> <on|off> - Announce boss kills to guild chat");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, "Settings:");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " announcekills - Send boss kill announcements to guild chat");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " announceloot - Send loot item list to guild chat");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " raidatt - Send attendance announements to raid chat");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " raidloot - Send loot item list to raid chat");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " rarity <#> - Set loot logging threshhold (rarity 1-6)");
table.insert(SLACKERDKP_CHAT_COMMAND_USAGE, " active - Toggle all logging on/off");

SLACKERDKP_UNKNOWN_COMMAND				= "Unknown Slacker DKP command";

ENABLED = 'enabled';
DISABLED = 'disabled';

SLACKER_SETTING = {};
SLACKER_SETTING['announcekills']		= "Boss kill announcements to guild chat are ";
SLACKER_SETTING['announceloot']			= "Loot item list to guild chat is ";
SLACKER_SETTING['raidloot']				= "Loot item list to raid chat is ";
SLACKER_SETTING['raidatt']				= "Attendance snapshot announcements to raid chat are ";
SLACKER_SETTING['mapalts']				= "Map players to primary for attendance is "
SLACKER_SETTING['debug']				= "Display of debugging info is "
SLACKER_SETTING['active']				= "SlackerDKP Logging is "
SLACKER_SETTING['rarity']				= "Loot logging level set to "

SLACKER_ITEM_RARITY = {};
SLACKER_ITEM_RARITY['0'] = 'Poor';
SLACKER_ITEM_RARITY['1'] = 'Common';
SLACKER_ITEM_RARITY['2'] = 'Uncommon';
SLACKER_ITEM_RARITY['3'] = 'Rare';
SLACKER_ITEM_RARITY['4'] = 'Epic';
SLACKER_ITEM_RARITY['5'] = 'Legendary';
SLACKER_ITEM_RARITY['6'] = 'Artifact';