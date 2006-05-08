#!/bin/sh
fetch http://ndkp.slacker.com/updateaddon.php && mv updateaddon.php Nurfed_DKPPlayers.lua

zip ~/Slacker_DKP.zip `find . | grep -v CVS | cut -c3-99`
