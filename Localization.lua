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

SLACKERDKP_UNKNOWN_COMMAND				= "Unknown Slacker DKP command";
