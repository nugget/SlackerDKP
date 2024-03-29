# SlackerDKP #

This is abandonware, published purely for archival purposes. 
It is a pre-Burning Crusade WoW AddOn for DKP-style Guild loot
management.  I wrote this for Aberration Guild on Whisperwind
and we used it in 2006.

David McNett <nugget@slacker.com>

## INSTALLTION BASICS

This entire Slacker_DKP folder should be placed into your Interface/AddOns/
folder just like any other AddOn.  This will add the Slacker DKP user
interface to your in-game WoW experience.

All Slacker DKP functions are available via slash commands "/sdkp" for help
or via an in-game window.  You can display/hide the window using the
"/sdkp toggle" command, or by binding the keystroke of your choice using
the standard WoW "Key Bindings" configuration page.

You should also place the ndkpweb/importRaidLog.php file into the admin
directory of your website NDKP installation.  Do not do anything with the
site.php file which also exists in this distribution.  It is not required
to use SlackerDKP.

Many Slacker DKP in-game features are optional, and are all disabled by
default.  You may wish to run the following commands to set up 
Slacker DKP after you've first installed it:

/sdkp set announcekills on
/sdkp set raidatt on


## LIMITATIONS

Aberration does not make use of NDKP's Main/Alt system so it's unlikely
that SlackerDKP will work for you if your guild is using NDKP's alt
support.  I plan to fix this, but it's not high on the list since it's
not a factor for us.  If your guild uses NDKP's alt support and you'd like
to help code/test support for it, let me know.


## IN GAME USAGE

At the start of each raid, issue the command "/sdkp clear" to clear
the sDKP raid log.

Click the "attendance" button or issue the command "/sdkp att <comment>" to
take an attendance snapshot.

Currently the attendance snapshots only record raid members and not any
standby players who didn't make it in to the raid.  For now we are just
handling those players by hand on the NDKP website.  This will be fixed
in a future sDKP release.

When a boss is killed for the first time, target the boss corpse and click the
bosskill button or issue the command "/sdkp bosskill <comment>" to log the
kill.  You only have to do this once per boss.  On future kills, sDKP will
automatically log the kill.

sDKP will automatically log player loot events.  You should continue to use
the normal NurfedDKP window and facilities to handle item bidding and 
awarding.

You can click the dynamic loot button to flag a loot entry as having been a 
"!bid", "!down", or disenchant award.

Editing a loot entry allows you to alter the target player name.  Use this
in the event of Bind on Equip items that were first collected by your
Loot Monger and then awarded at a later time.

You can highlight any attendance or bosskill log entry and click edit to
add/edit comments for that log entry.

## Available Settings

All of these may be set using the sdkp set command:
  "/sdkp set <setting> on" or "/sdkp set <setting> off":

active - Toggle all logging on/off"
announcekills - Send boss kill announcements to guild chat"
announceloot - Send loot item list to guild chat"
raidatt - Send attendance announements to raid chat"
raidloot - Send loot item list to raid chat"
waitlista - Include waiting list players in attendance snapshots
waitlistb - Include waiting list players in bosskill snapshots
dkpplayer - Add a user named "DKP" to snapshots

These settings are not a toggle, but expect a value:

rarity <#> - Set loot logging threshhold (rarity 1-6)
scale <#> - Set UI size from 50 - 120%

## POST RAID

Exit WoW, or issue the command "/console reloadui" to cause sDKP to write 
its log files to disk.

Locate the Slacker_DKP.lua file on your local machine which should be inside
the ./WTF/Accounts/YOURACCOUNT/SavedVariables/ directory.  You'll need to
ftp or scp or sftp or somehow copy this file from your local machine to
your NDKP web server inside the ./admin/ directory.  This process will be 
automated very soon, but for now there's no mechanism to do this.

Once the file is placed on the web server, visit the page:

   http://yourserver.example.com/ndkp/admin/importRaidLog.php

(You'll obviously have to be logged in as an Admin to do this)

The page will hopefully list all the logged events from the raid, with
convenient buttons to allow you to enter each relevant event into NDKP.

If there are any unknown players or items found in the log, warnings will
appear at the top of the page.

A special "Meta" attendance entry will automatically be added if there
were successful boss kills during the raid.  This entry will include 
any player present for any of the boss kills during the raid.

You should be able to just walk down the page, clicking each button in turn
to add that item, then hitting "back" in your browser and then "refresh"
on the importRaidLog page.  Once you're out of buttons, the entire raid's
log is entered into NDKP.

## NOTES

There's a hard-coded handler in the AddOn for Majordomo Executus that will
log the bosskill at the appropriate time, not literally when he dies.

## EXTRAS

Aberration Guild uses a modified method of handling alts, different from the
normal NDKP method.  The supplied "site.php" page includes the changes we've
made to NDKP to make it behave the way we want.  It's not suggested that you
do anything with that file.

## WAITING LIST

SlackerDKP can also manage your raid waiting list, intended for use when a
raid is full and some members are waiting to join the raid.  Players can
whisper to the raid logger the following commands:

  !addme - Add this player to the waiting list.
  !dropme - Remove this player from the waiting list.
  !waitlist - Report the player's position on the waiting list.
