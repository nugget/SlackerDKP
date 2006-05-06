<?php
session_start();
require('../config/siteSettings.php');
require('../config/site.php');
require('config/adminClass.php');
$ndkp = new nurfedAdmin;
if($_GET[logout] == 'xxx') {
	$ndkp->logOut();
}
$ndkp->dbUser=$dbUser;
$ndkp->dbPassword=$dbPassword;
$ndkp->dbServer=$dbServer;
$ndkp->dBase=$dBase;
$ndkp->vars=$_GET;
$ndkp->displayhtml('header');

$bosskills = array();
$lootlog = array();
$attlog = array();
$raiddata = array();

$unknown_player = array();
$unknown_item = array();

$ifbuf = array();
$ifbuf = file('Nurfed_DKP.lua');

$block = '';
$ts = '';

foreach($ifbuf as $buf) {
	if(preg_match('/^NURFED_SAVED_([A-Z]+) = {/', $buf, $matches)) {
		$block = strtolower($matches[1]);
	} elseif(preg_match('/^\t\["(\d+)"\] = {/', $buf, $matches)) {
		$ts = $matches[1];
		$store = '$' . $block . '[] = "' . $ts . '";';
		# print "<pre>$store</pre>\n";
		eval($store);
	} elseif(preg_match('/^\t\t\["([^"]+)"\] = "([^"]+)",/', $buf, $matches)) {
		$fieldname = $matches[1];
		$data = $matches[2];
		# print "<pre>\$raiddata[$block][$ts][$fieldname] = $data</pre>\n";
		$raiddata[$block][$ts][$fieldname] = $data;
		if($fieldname == 'player') {
			if(!player_exists($data)) {
				$unknown_player[] = $data;
			}
		}
		if($fieldname == 'item') {
			if(!item_exists($data)) {
				$unknown_item[] = $data;
			}
		}
		if($fieldname == 'playerlist') {
			$pbuf = split(" ",$data);
			foreach($pbuf as $p) {
				if($p != '') {
					if(!player_exists($p)) {
						$unknown_player[] = $p;
					}
				}
			}
		}
	}
}

sort($bosskills);
sort($lootlog);
sort($attlog);

sort($unknown_player);
sort($unknown_item);
$unknown_player = array_unique($unknown_player);
$unknown_item   = array_unique($unknown_item);

function player_exists($name) {
	$sql = "select player_id from NDKP_members where name = '$name'";
	$result = mysql_query($sql);
	if($result) {
		$result = mysql_fetch_assoc($result);
		$result = $result["player_id"];
	}
	return $result;
}
function list_unknown_players() {
	global $unknown_player;

	print "<ol>\n";
	foreach($unknown_player as $player) {
		print "<li style=\"color: red;\">$player</li>\n";
	}
	print "</ol>\n";
}

function item_exists($name) {
	$sql = "select item_id from NDKP_items where name = '$name'";
	$result = mysql_query($sql);
	if($result) {
		$result = mysql_fetch_assoc($result);
		$result = $result["item_id"];
	}
	return $result;
}
function list_unknown_items() {
	global $unknown_item;

	print "<ol>\n";
	foreach($unknown_item as $item) {
		print "<li style=\"color: red;\">$item</li>\n";
	}
	print "</ol>\n";
}

function list_attlogs() {
	global $raiddata;
	global $attlog;

	print "<ol>\n";

	foreach($attlog as $attrec) {
		$ts = strftime("%m/%d/%y %H:%M:%S",$attrec);
		$plist = str_replace(' ', "\n", $raiddata[attlog][$attrec][playerlist]);
		$type = 'start';

		print "<li>";
		print $raiddata[attlog][$attrec][location] . " at " . $ts;
		if($record = att_exists($attrec)) {
			att_edit_form($record);
		} else {
			att_add_form($ts,$type,$raiddata[attlog][$attrec][comments],$plist);
		}
		print "</li>\n";
	}

	print "</ol>\n";
}
function att_add_form($ts,$type,$comments,$playerlist) {
	print '<form action="modules/attendance.php" method="post">';
	print '<input type="hidden" name="raiddate"   value="' . $ts . '">';
	print '<input type="hidden" name="type"       value="' . $type . '">';
	print '<input type="hidden" name="notes"      value="' . $comments . '">';
	print '<input type="hidden" name="attendance" value="' . $playerlist . '">';
	print '<input style="width: 200px" name="submit" value="Add Attendance" type="submit">';
	print '</form>';
}
function att_edit_form($record) {
	# print '<form action="edit-timeClock.php" method="get">';
	# print '<input type="hidden" name="id"   value="' . $record . '">';
	# print '<input style="width: 200px" name="submit" value="Edit Attendance" type="submit">';
	# print '</form>';
	print '<br /><i>This record has already been added</i> ';
	print ' [<a href="edit-timeClock.php?id=' . $record . '">edit</a>]';
}
function att_exists($attrec) {
	$ts = strftime("%Y-%m-%d %H:%M:%S",$attrec);
	$sql = "select id from NDKP_attendancetype where date = '$ts'";
	$result = mysql_query($sql);
	if($result) {
		$result = mysql_fetch_assoc($result);
		$result = $result["id"];
	}
	return $result;
}

function list_bosskills() {
	global $raiddata;
	global $bosskills;

	print "<ol>\n";

	for($i=0; $i<count($bosskills); $i++) {
		$bossrec = $bosskills[$i];

		$nextrec = $bosskills[$i+1];
		if(!$nextrec) {
			$nextrec = 9999999999;
		}

		$ts = strftime("%m/%d/%y %H:%M:%S",$bossrec);
		$plist = str_replace(' ', "\n", $raiddata[bosskills][$bossrec][playerlist]);

		print "<li>";
		print $raiddata[bosskills][$bossrec][bossname] . " at " . $ts;
		if($record = boss_exists($bossrec)) {
			boss_edit_form($record);
		} else {
			boss_add_form($bossrec,$nextrec,$ts,
			              $raiddata[bosskills][$bossrec][bossname],
			              $raiddata[bosskills][$bossrec][location],
			              $raiddata[bosskills][$bossrec][comments],
			              $plist);
		}
		print "</li>\n";
	}

	print "</ol>\n";

}
function boss_add_form($epochlow,$epochhigh,$ts,$bossname,$location,$comments,$playerlist) {
	print '<form action="modules/addRaid.php" method="post">';
	print '<input type="hidden" name="raiddate"    value="' . $ts . '">';
	print '<input type="hidden" name="newdungeon"  value="' . $location . '">';
	print '<input type="hidden" name="newboss"     value="' . $bossname . '">';
	print '<input type="hidden" name="notes"       value="' . $comments . '">';
	print '<input type="hidden" name="attendance" value="' . $playerlist . '">';
	print '<input style="width: 200px" name="submit" value="Add Raid" type="submit">';
	boss_loot_fields($epochlow,$epochhigh);
	print '</form>';
}
function boss_loot_fields($low,$high) {
	global $lootlog;
	global $raiddata;

	$items = 0; $known_items = 0;

	foreach ($lootlog as $ts) {
		if(($ts > $low) && ($ts < $high)) {
			$items++;
			if($item_id = item_exists($raiddata[lootlog][$ts][item])) {
				$known_items++;
				print "\n\n";
				print '<input type="hidden" name="looters[]" value="' . player_exists($raiddata[lootlog][$ts][player]) . '">';
				print '<input type="hidden" name="items[]" value="' . $item_id . '">';
				print '<input type="hidden" name="fullprice[]" value="0">';
				print "\n\n";
			}
		}
	}
	print "<i>$items items ($known_items known)</i>";
}
function boss_edit_form($record) {
	print '<br /><i>This record has already been added (raid #' . $record . ')</i> ';
	# print ' [<a href="editRaid.php?id=' . $record . '">edit</a>]';
}
function boss_exists($bossrec) {
	$ts = strftime("%Y-%m-%d %H:%M:%S",$bossrec);
	$sql = "select raid_id from NDKP_raids where raid_date = '$ts'";
	$result = mysql_query($sql);
	if($result) {
		$result = mysql_fetch_assoc($result);
		$result = $result["raid_id"];
	}
	return $result;
}

?>
<table id="mainpage">
	<tr><td valign="top">
		<div id='maincontent'>
			<h1 class="titles">Unknown Members (<?php print count($unknown_player) ?>)</h1>
			<div style="margin-left: 30px;">
			<?php list_unknown_players(); ?>
			</div>
			<h1 class="titles">Unknown Items (<?php print count($unknown_item) ?>)</h1>
			<div style="margin-left: 30px;">
			<?php list_unknown_items(); ?>
			</div>
			<div class="break"></div>

			<h1 class="titles">Attendance Records (<?php print count($attlog); ?>)</h1>
			<div style="margin-left: 30px;">
			<?php list_attlogs(); ?>
			</div>
			<div class="break"></div>

			<h1 class="titles">Boss Kills (<?php print count($bosskills); ?>)</h1>
			<div style="margin-left: 30px;">
			<?php list_bosskills(); ?>
			</div>
			<div class="break"></div>

		</div>
		<td valign="top">
			<div id='rightcontent'>
			<?php include('../includes/newsitems.php'); ?>
			<div class="break"></div>
			<?php include('../includes/moreNDKP.php'); ?>
			</div>

		</td>
	</tr>
</table>
</div>
<div id="footer">
	NDKP is a division of <a href="http://www.nurfed.com" target="_BLANK">Nurfed</a>
</div>
</body>
</html>
