<?php
class NDKP {
	function dbcnx() {
		$dbcnx=mysql_connect($this->dbServer,$this->dbUser,$this->dbPassword) 
			or die('NDKP ERROR: Unable to connect to mysql as user '.$this->dbUser.'.');
		$dbsel=mysql_select_db($this->dBase,$dbcnx) 
			or die('NDKP ERROR: Unable to connect to '.$this->dBase.' terminating ndkp.');
	}
	function getsettings($var) {
		$this->dbcnx();
		$sql = mysql_query("select $var from NDKP_settings") or die(mysql_error());
		$ret = mysql_fetch_object($sql);
		return $ret->$var;
	}
	function dateit() {
		#$time = time()+$timeoffset*60*2
		$today=date('m/d/y H:i:s');
		return $today;
	}
	function datecur($date) {
		$curdate=date('m/d/y H:i:s',strtotime($date));
		return $curdate;
	}
	function displayhtml($file) {
		switch($file) {
			case 'header':
			$this->grabheader();
			break;
			case 'playerdkp':
			$this->grabplayerdkp($this->vars);
			break;
		}
	}
	function maindkptable () {
		$a_interval=$this->getsettings('attendance_interval');
		$weeks = round($a_interval/7);
		$threshold = $this->getsettings('att_threshold');
		$sixweeks=$this->sixWeeks();
		$this->dbcnx();
		$sql = 'create temporary table tempdkptable ';
		$sql = $sql . "select count(*) as attended, p.* from NDKP_recordedattendance r
				left join NDKP_attendancetype n on n.id= r.countID
				left join NDKP_members p on p.player_id = r.playerID ";
		if($_GET[allplayers] < 1) {
			$sql.= "where DATE_SUB(CURDATE(), INTERVAL $a_interval DAY) <= n.date and p.inactive=0";
		}
		if(strlen($_GET[filter]) > 1) {
			$arr=strtolower($_GET[filter]);
			$array=$this->$arr;
			$sql .= " and ";
			for($i=0;$i<sizeof($array);$i++) {
				$sql .= " class='".$array[$i]."'";
				if($i< sizeof($array)-1) {
					$sql .= " or ";
				}
			}
		}
		if($_GET['class'] && strlen($_GET['class']) > 1 && strlen($_GET[filter]) < 1) {
			$sql .= " and (class='".$_GET['class']."') ";
		}
		$sql .= " group by r.playerID";

		$dbi = mysql_query($sql) or die(mysql_error());

		$sql = "select player_id, alt_of from NDKP_members where alt_of > 0";
		$dbi = mysql_query($sql) or die(mysql_error());
		while($r = mysql_fetch_object($dbi)) {
			$ret = mysql_fetch_object(mysql_query("select attended from tempdkptable where player_id = $r->player_id"));
			$main_num = $ret->attended;
			$ret = mysql_fetch_object(mysql_query("select attended from tempdkptable where player_id = $r->alt_of"));
			$alt_num = $ret->attended;
			$sql = "update tempdkptable set attended = $alt_num + $main_num - 1 where player_id = " . $r->player_id . " or player_id = " . $r->alt_of;
			mysql_query($sql);
		}

		$sql = 'select * from tempdkptable';	
		if(isset($_GET[sortby]) && isset($_GET[sortorder])) {
			$sql .= " order by ".$_GET[sortby]." ".$_GET[sortorder];
		} else {
			$sql .= " order by dkp desc";
		}
		$dbi = mysql_query($sql) or die(mysql_error());
	
		$totalfound=mysql_num_rows($dbi);
		$arrs[attendance]=array();
		$arrs[player]=array();
		$arrs[dkp]=array();
		$arrs[earned]=array();
		$arrs[spent]=array();
		$arrs["class"] = array();
		$arrs["count"]=$totalfound;
		$arrs["weeks"]=$weeks;
		$arrs["threshold"]=$threshold;
		while($r = mysql_fetch_object($dbi)) {
			$full_attendance = $this->getAttendance($r->player_id);
			$attendance = $full_attendance/$sixweeks*100;
			array_push($arrs[attendance],$attendance);
			array_push($arrs[player],$r->name);
			array_push($arrs[dkp],$r->dkp);
			array_push($arrs["class"],$r->class);
			array_push($arrs[earned],$r->dkp_earned);
			array_push($arrs[spent],$r->dkp_spent);
		}
		return $arrs;
	}
	//retun alts as well for display in class only dkp table
	function includealts() {
		$a_interval=$this->getsettings('attendance_interval');
		$weeks = round($a_interval/7);
		$threshold = $this->getsettings('att_threshold');
		$sixweeks=$this->sixWeeks();
		$this->dbcnx();
		$sql = "select count(*) as attended, a.*, p.*, a.player_id as player_id, p.name as player 
				from NDKP_recordedattendance r
				left join NDKP_attendancetype n on n.id= r.countID
				left join NDKP_alternates a on a.player_id = r.playerID 
				left join NDKP_members p on p.player_id = r.playerID ";
		$sql.= "where DATE_SUB(CURDATE(), INTERVAL $a_interval DAY) <= n.date 
				and a.altclass='".$_GET['class']."'
				and p.inactive=0 group by r.playerID";
		$dbi = mysql_query($sql) or die(mysql_error());
		while($r = mysql_fetch_object($dbi)) {
			if($attendance > ($threshold-1))  {
				$rank++;
				$set=1; //set attendance factor
			} else {
				$set = 0;
			}
			$p .= "\t<tr>\n";
			$alt[alt_id]=$r->alt_id;
			$alt[name]=$r->altname;
			$alt[set]=$set;
			$alt[player]=$r->player;
			$alt[dkp]=$r->dkp;
			$alt[earned]=$r->dkp_earned;
			$alt[spent]=$r->dkp_spent;
			$alt[altclass]=$r->altclass;
			$full_attendance = $this->getAttendance($r->player_id);
			$attendance = $full_attendance/$sixweeks*100;
			$alt[attendance]=$attendance;
			$alts[]=$alt;
		}
		return $alts;
	}
	//get the Attendance of the player
	function getAttendance($id) {
		$this->dbcnx();
		$ret = mysql_fetch_object(mysql_query("select alt_of from NDKP_members where player_id = $id"));
		if($ret->alt_of > 0) { $id = $ret->alt_of; }
		$dbi = mysql_query("select player_id from NDKP_members where player_id = $id or alt_of = $id");
		$attcount = 1;
		while($r = mysql_fetch_object($dbi)) {
			$sql="select count(*) as total from NDKP_recordedattendance r
			      left join NDKP_attendancetype n on r.countID=n.id 
			      where DATE_SUB(CURDATE(), INTERVAL 42 DAY) <= date
			      and playerID=" . $r->player_id;
			$retAtt=mysql_query($sql) or die(mysql_error());
			$ret=mysql_fetch_object($retAtt);
			$attcount = $attcount + $ret->total -1;
		}
		return $attcount;
	}
	//determines the number of raids based on the users interval preference
	//default = 42 days
	function sixWeeks() {
		require(str_replace('/admin','',getCWD()).'/config/siteSettings.php');
		if(!$attendanceInterval) { $attendanceInterval = 42; } //set default
		$this->dbcnx();
		$sql = "select count(*) as total from NDKP_attendancetype 
				where DATE_SUB(CURDATE(), INTERVAL $attendanceInterval DAY) <= date";
		$dbi = mysql_query($sql) or die(mysql_error());
		$r = mysql_fetch_object($dbi);
		return $r->total;
	}
	function grabheader() {
		$this->dbcnx();
		$version=$this->getsettings('version');
		$template=$this->getsettings('template');
		$basedir=$this->getsettings('basedir');
		$url=$this->getsettings('url');
		$fullpath = 'http://'.$url;
		$file_contents = file('includes/header.tpl');
		foreach($file_contents as $line) {
			$cleanline = str_replace('{get_ndkp_version}',$version,$line);
			$cleanline = str_replace('{get_template}',$template,$cleanline);
			if(eregi('\{get_breadcrumbs\}',$line)) {
				$cleanline = str_replace('{get_breadcrumbs}','',$cleanline);
				$contents .= $this->breadcrumbs('classes');
			}
			
			$contents .= $cleanline;
		}
		echo $contents;
	}
	function breadcrumbs($type) {
		if($type == 'classes') {
			$this->dbcnx();
			$sql = mysql_query("select class from NDKP_members group by class");
			$url=$this->getsettings('url');
			$fullpath = 'http://'.$url;
			$contents.="<a href=\"".$fullpath."\">All</a> &#187;\n";
			while($r = mysql_fetch_object($sql)) {
			  $contents.="<a href=\"".$fullpath."index.php?class=$r->class\">$r->class</a> &#187;\n";
			 }
		}
		return $contents;
	}
	//layout color effects
	function reColor($var,$set) {
		if($set == 1) {
			$p.=$var;
		} else {
			$p.='<span class="attBal">'.$var.'</span>';
		}
		return $p;
	}
	//layout color effects
	function colorClass($nbr,$dec,$comp,$in,$out,$set) {
		if($set == 1) {
			if($in > 1 && $out > 1) {
				if($out > $in) {
					$p.='<span class="nurfedNeg">'.number_format($nbr,$dec).'</span>';
				} else {
					$p.='<span class="nurfedPos">'.number_format($nbr,$dec).'</span>';
				}
			} else {
				if($nbr < $comp) {
					$p.='<span class="nurfedNeg">'.number_format($nbr,$dec).'</span>'."\n";
				} else {
				$p.='<span class="nurfedPos">'.number_format($nbr,$dec).'</span>'."\n";
				}
			}
		} else {
			if($in > 1 && $out > 1) {
				if($out > $in) {
					$p.='<span class="attNeg">'.number_format($nbr,$dec).'</span>';
				} else {
					$p.='<span class="attPos">'.number_format($nbr,$dec).'</span>';
				}
			} else {
				if($nbr < $comp) {
					$p.='<span class="attNeg">'.number_format($nbr,$dec).'</span>'."\n";
				} else {
				$p.='<span class="attPos">'.number_format($nbr,$dec).'</span>'."\n";
				}
			}
		}
		return $p;
	}
	function getmemberinfobyname($type) {
		$this->dbcnx();
		$sql = "select $type from NDKP_members where name='".$this->vars['player']."'";
		$dbi = mysql_query($sql);
		if(mysql_num_rows($dbi) > 0) {
			$r=mysql_fetch_object($dbi);
			return $r->$type;
		}
	}
	function getaltinfo() {
		$this->dbcnx();
		$sql = "select a.*, p.name as player 
				from NDKP_alternates a
				left join NDKP_members p on p.player_id=a.player_id
				where a.alt_id='".$_GET[id]."'";
		$dbi = mysql_query($sql);
		$alts=array();
		while($r=mysql_fetch_object($dbi)) {
			$alt[name]=$r->altname;
			$alt[player]=$r->player;
			$alt['class']=$r->altclass;
			$alt[player_id]=$r->player_id;
			array_push($alts,$alt);
		}
		return $alts;
	}
	function playerattendance($player_id) {
		return $this->getAttendance($player_id)/$this->sixWeeks()*100;
	}
	function altpurchases() {
		$this->dbcnx();
		$weapons=array('One-Hand','Main Hand','Two-Hand','Off-Hand','Ranged');
		$sql = "select d.dkp_cost, i.name, i.item_id as iid, 
				d.raid_id, r.raid_date as rdate 
				from NDKP_raiddrops d 
				left join NDKP_items i on d.item_id = i.item_id 
				left join NDKP_raidattendance a on a.player_id = d.player_id
				left join NDKP_raids r on d.raid_id = r.raid_id 
				where d.alt_id = '" . $_GET[id]. "'";
		if($_GET[sort]=='weapon') {
			$sql.=" and ( ";
			for($i=0; $i<sizeof($weapons); $i++) {
				if($i > 0) { $sql.=" or "; }
				$sql.=" slot = '$weapons[$i]' ";
			}
			$sql.=" ) ";
		} else if($_GET[sort]=='armor') {
			$sql.=" and ( ";
			for($i=0; $i<sizeof($weapons); $i++) {
				if($i > 0) { $sql.=" and "; }
				$sql.=" slot != '$weapons[$i]' ";
			}
			$sql.=" ) ";
		}
		$sql.="group by d.drop_id order by r.raid_date desc";
		$dbi=mysql_query($sql) or die(mysql_error());
		while($r = mysql_fetch_object($dbi)) {
			$raid_id[]=$r->raid_id;
			$name[]=$this->truncatestring(30, $r->name);
			$rdate[]=$r->rdate;
			$dkpcost[]=$r->dkp_cost;
			$iid[]=$r->iid;
		}
		$arrs[raid_id]=$raid_id;
		$arrs[name]=$name;
		$arrs[rdate]=$rdate;
		$arrs[dkpcost]=$dkpcost;
		$arrs[iid]=$iid;
		return $arrs;
	}
	function playerpurchases($player_id) {
		$this->dbcnx();
		$weapons=array('One-Hand','Main Hand','Two-Hand','Off-Hand','Ranged');
		$sql = "select d.dkp_cost, i.name, i.item_id as iid, 
				d.raid_id, r.raid_date as rdate, alt_id
				from NDKP_raiddrops d 
				left join NDKP_items i on d.item_id = i.item_id 
				left join NDKP_raidattendance a on a.player_id = d.player_id
				left join NDKP_raids r on d.raid_id = r.raid_id 
				where d.player_id = '" . $player_id . "'";
		if($_GET[sort]=='weapon') {
			$sql.=" and ( ";
			for($i=0; $i<sizeof($weapons); $i++) {
				if($i > 0) { $sql.=" or "; }
				$sql.=" slot = '$weapons[$i]' ";
			}
			$sql.=" ) ";
		} else if($_GET[sort]=='armor') {
			$sql.=" and ( ";
			for($i=0; $i<sizeof($weapons); $i++) {
				if($i > 0) { $sql.=" and "; }
				$sql.=" slot != '$weapons[$i]' ";
			}
			$sql.=" ) ";
		}
		$sql.="group by d.drop_id order by r.raid_date desc";
		$dbi=mysql_query($sql) or die(mysql_error());
		while($r = mysql_fetch_object($dbi)) {
			$raid_id[]=$r->raid_id;
			$name[]=$this->truncatestring(30, $r->name);
			$rdate[]=$r->rdate;
			$dkpcost[]=$r->dkp_cost;
			$iid[]=$r->iid;
			$alt_id[]=$r->alt_id;
		}
		$arrs[raid_id]=$raid_id;
		$arrs[name]=$name;
		$arrs[rdate]=$rdate;
		$arrs[dkpcost]=$dkpcost;
		$arrs[iid]=$iid;
		$arrs[alt_id]=$alt_id;
		return $arrs;
	}
	function displayraids() {
		$this->dbcnx();
		$cnt =0;
		$arrs[raid_id]=$arrs[rdate]=$arrs[boss]=$arrs[dungeon]=$arrs[dkp]=array();
		$sql  = "select * from NDKP_raids where boss not like 'Bank'";
		if($_GET[boss]) {
			$raidboss=$this->cleanslash($_GET[boss]);
			$sql .= " and boss='$raidboss' ";
		}
		if($_GET[dungeon]) {
			$raiddungeon=$this->cleanslash($_GET[dungeon]);
			$sql .= " and dungeon='$raiddungeon' ";
		}

		$sql .= "order by raid_date desc ";
		$dbi = mysql_query($sql) or die(mysql_error());
		$numrows=mysql_num_rows($dbi);
		$paginate=$this->paginate($numrows,30);
        $limit = "LIMIT ".$paginate[0][setRows].",".$paginate[0][rowsperPage];
		$sql .= $limit;

		$dbh = mysql_query($sql);
		while($r = mysql_fetch_object($dbh)) {
			$cnt++;
			array_push($arrs[raid_id],$r->raid_id);
			array_push($arrs[rdate],$r->raid_date);
			$boss=$this->truncatestring(30, $r->boss);
			array_push($arrs[boss],$boss);
			array_push($arrs[dungeon],$r->dungeon);
			array_push($arrs[dkp],$r->dkp_earned);
		}
		$arrs[cnt]=$numrows;
		$arrs[setRows]=$paginate[0][setRows];
		$arrs[rowsperPage]=$paginate[0][rowsperPage];
		$arrs[lastPage]=$paginate[0][lastPage];
		#$this->debug($arrs);
		return $arrs;
	}
	function playerraids($player_id) {
		$this->dbcnx();
		if($_GET[sort] == 'missed') {
			$arrs=$this->missedraids($player_id);
		} else {
			$sql  = "select r.raid_id as raid_id, r.raid_date as raid_date,
					 r.boss, r.dungeon, r.dkp_earned
					 from NDKP_raidattendance a 
					 left join NDKP_raids r on a.raid_id = r.raid_id ";
			$sql .= " where a.player_id = '" . $player_id . "' ";
			$sql .= " order by raid_date desc, r.raid_id desc";

			$dbi = mysql_query($sql) or die(mysql_error());
			$numrows=mysql_num_rows($dbi);

			$paginate=$this->paginate($numrows,30);
			$limit = " LIMIT ".$paginate[0][setRows].",".$paginate[0][rowsperPage];
			$sql .= $limit;

			$dbh = mysql_query($sql);
			$cnt =0;

			$arrs[raid_id]=$arrs[rdate]=$arrs[boss]=$arrs[dungeon]=$arrs[dkp]=array();
			while($r = mysql_fetch_object($dbh)) {
				$cnt++;
				array_push($arrs[raid_id],$r->raid_id);
				array_push($arrs[rdate],$r->raid_date);
				$boss=$this->truncatestring(30, $r->boss);
				array_push($arrs[boss],$boss);
				array_push($arrs[dungeon],$r->dungeon);
				array_push($arrs[dkp],$r->dkp_earned);
			}
			$arrs[setRows]=$paginate[0][setRows];
			$arrs[rowsperPage]=$paginate[0][rowsperPage];
			$arrs[lastPage]=$paginate[0][lastPage];
			$arrs[cnt]=$cnt;
		}
		return $arrs;
	}
	function cleanSlash($txt) {
		if (!get_magic_quotes_gpc()) {
			$full = addslashes($txt);
		} else {
			$full = $txt;
		}
		return $full;
	}
		
	function missedraids($player_id) {
		$this->dbcnx();
		$arrs[raid_id]=$arrs[rdate]=$arrs[boss]=$arrs[dungeon]=$arrs[dkp]=array();
		$allraids = mysql_query("select raid_id from NDKP_raids 
								 where dungeon not like 'Bank'
								 order by raid_date desc");
		$all[id]=$att[id]=array();
		$cnt=0;
		while($a = mysql_fetch_object($allraids)) {
			array_push($all[id],$a->raid_id);
		}
		$attraids = mysql_query("select r.raid_id from NDKP_raidattendance a
								 left join NDKP_raids r on a.raid_id=r.raid_id
								 where player_id='$player_id'
								 and dungeon not like 'Bank'
								 order by r.raid_date desc") or die(mysql_error());
		while($b = mysql_fetch_object($attraids)) {
			array_push($att[id],$b->raid_id);
		}
		$missed_raids=array_diff($all[id],$att[id]);

		foreach($missed_raids as $miss) {	
			$qry = "select * from NDKP_raids where raid_id='$miss'";
			$dbi = mysql_query($qry) or die(mysql_error());
			if(mysql_num_rows($dbi) == TRUE) {
				$ids = mysql_fetch_object($dbi);
				$cnt++;
				array_push($arrs[raid_id],$ids->raid_id);
				array_push($arrs[rdate],$ids->raid_date);
				$boss=$this->truncatestring(30, $ids->boss);
				array_push($arrs[boss],$boss);
				array_push($arrs[dungeon],$ids->dungeon);
				array_push($arrs[dkp],$ids->dkp_earned);
			}
		}
		$arrs[cnt]=$cnt;
		return $arrs;
	}
	function truncatestring($maxTextLength, $string) {
		$aspace= " ";
		$txt=$string;
		if(strlen($txt) > $maxTextLength) {
			$txt = substr(trim($string),0,$maxTextLength);
			$txt = substr($txt,0,strlen($txt)-strpos(strrev($txt),$aspace));
		}
		return $txt;
	}
	function getplayerdkparray() {
		$this->dbcnx();
		$sql = "select * from NDKP_members where name='".$this->vars['player']."'";
		$dbi = mysql_query($sql);
		if(mysql_num_rows($dbi) > 0 ) {
			$r=mysql_fetch_array($dbi);
			return $r;
		}
	}
	function playeralts($player) {
		$this->dbcnx();
		$sql = "select * from NDKP_alternates where player_id='$player'";
		$dbi=mysql_query($sql);
		$alts = array();
		while($r = mysql_fetch_object($dbi)) {
			$alt[name]=$r->altname;
			$alt[id]=$r->alt_id;
			$alt['class']=$r->altclass;
			array_push($alts,$alt);
		}
		return $alts;
	}
	function grabplayerdkp($vars) {
		$this->dbcnx();
		$a_interval=$this->getsettings('attendance_interval');
		$weeks = round($a_interval/7);
		$sql = "select *, count(*) as attended, p.*
				from NDKP_recordedattendance r
				left join NDKP_attendancetype n on n.id= r.countID
				left join NDKP_members p on p.player_id = r.playerID 
				where DATE_SUB(CURDATE(), INTERVAL $a_interval DAY) <= n.date 
				and p.name='".$vars[player]."' group by r.playerID";
		$dbh=mysql_query($sql) or die(mysql_error().$sql);

		//if player does not exist within the set attendance interval
		//display them anyway
		if(mysql_num_rows($dbh) == FALSE) {
			$sql = "select * from NDKP_members where name='$vars[player]'";
		}

		$dbi=mysql_query($sql) or die(mysql_error());
		if($r=mysql_fetch_object($dbi)) {
			if($r->attended > 0) {
				$p .= number_format($r->attended/$this->sixweeks()*100,1).'%';
			} else {
				$p .= 'No attendance recorded for '.$r->name;
			}
			$p .= "</td>\n";

			$p .= "<tr><td>Earned DKP\n";
			$p .= "<td>".number_format($r->dkp_earned,3)."</td>\n";
			$p .= "</tr>\n";
			$p .= "<tr><td>Spent DKP\n";
			$p .= "<td>".number_format($r->dkp_spent,3)."</td>\n";
			$p .= "</tr>\n";
			$p .= "<tr><td>Current DKP\n";
			$p .= "<td>".number_format($r->dkp,3)."</td>\n";
			$p .= "</tr>\n";
			$p .= '</table>'."\n";
			$p .= '<br />'."\n";
			#$p .= $this->playerPurchase($r->player_id);
			#$p .= $this->playerAdjustments($player);
			#$p .= $this->playerRaids($r->player_id,$index,$boss,$dungeon);
		}
		echo $p;
	}
	function returncolumns($table) {
		$this->dbcnx();
		$columns=array();
		$colnames = mysql_querY("show columns from $table");
		while($f = mysql_fetch_object($colnames)) {
			$columns[]=$f->Field;
		}
		return $columns;
	}
	function playeradjustments($player) {
		$this->dbcnx();
		$columns = $this->returncolumns('NDKP_adjustments');
		foreach($columns as $col) {
			$adj["$col"]=array();
		}
		$sql = mysql_query("select * from NDKP_adjustments where player_name='$player'");
		while($r = mysql_fetch_object($sql)) {
			foreach($columns as $val) {
				array_push($adj["$val"],$r->$val);
			}
		}
		return $adj;
	}
	function itemtable() {
		$this->dbcnx();
		//filters 
		$filters=array(
			'Caster'=>array('Intellect',
							 'damage_all',
							 'damage_single',
							 'healing',
							 'crit_spell',
							 'regen_mana',
							 'crit_single',
							 'hit_spell'),
			'Melee'=>array('strength',
						   'agility',
						   'crit_melee',
						   'attack_power',
						   'dodge',
						   'parry',
						   'defense',
						   'hit_melee'),
			'Weapon'=>array('Axe','Bow','Dagger','Fist',
							'Gun','Held','Mace','Polearm','Shield','Staff',
						    'Sword','Wand'));
		$filterexclusion=array('Cloth','Leather','Mail','Plate');
		$columns=$this->returncolumns('NDKP_items');
		foreach($columns as $col) {
			$arrs[$col] = array();
		}
		$sql = "select * from NDKP_items ";
		if(isset($_GET['classfilter'])) {
			$sql.= " where class_restrictions='".$_GET['classfilter']."'";
		}
		if(isset($_GET['filter'])) {
			$filter=$_GET['filter'];
			$totalfilters = sizeof($filters[$filter]);
			$sql .= " where ";
			if(in_array($filter,$filterexclusion)) {
				$sql .= " armor_type regexp '".$filter."' ";
			} else {
				for($i=0; $i < $totalfilters; $i++) {
					if($i > 0) {
						$sql.= " or ";
					}
					if($filter == 'Weapon') {
						$sql .= " armor_type = '".$filters[$filter][$i]."' ";
					} else {
						$sql .= $filters[$filter][$i] . ' > 0 ';
					}
				}
			}
		}
		if(isset($_GET["alpha"])) {
			$sql.=" where name like '$_GET[alpha]%' ";
		}
		$sql.= "order by name ";

		$dbh = mysql_query($sql) or die(mysql_error());
		$numrows=mysql_num_rows($dbh);
		$arrs[total]=$numrows;
		$paginate=$this->paginate($numrows,50);
        $limit = "LIMIT ".$paginate[0][setRows].",".$paginate[0][rowsperPage];
		$sql.= $limit;
		$dbi = mysql_query($sql) or die(mysql_error());
		while($r = mysql_fetch_object($dbi)) {
			foreach($columns as $col) {
				array_push($arrs[$col],$r->$col);
			}
		}
		$arrs[setRows]=$paginate[0][setRows];
		$arrs[rowsperPage]=$paginate[0][rowsperPage];
		$arrs[lastPage]=$paginate[0][lastPage];
		return $arrs;
	}

	##############################################################
	##															##
	## 	Single Raid Display										##
	## 	Displays raid specific information						##
	##	Updated: January 15, 2006								##
	##															##
	##############################################################
	function formatdate($date) {
		$formatted = date("D d M Y", strtotime($date));
		return $formatted;
	}
	function displayRaid() {
		$this->dbcnx();
		$sql="select r.* from NDKP_raids r where r.raid_id='$_GET[id]'";
		$dbi=mysql_query($sql);
		if($r=mysql_fetch_object($dbi)) {
			$arrs[raid_id] = $r->raid_id;
			$arrs[raid_date]=$this->formatdate($r->raid_date);
			$arrs[dungeon] = $r->dungeon;
			$arrs[boss] = $r->boss;
			$arrs[dkp] = number_format($r->dkp_earned,3);
			$arrs[comments] = $r->comments;
		}
		return $arrs;
	}
	function getclasses() {
		$this->dbcnx();
		$classes=array();
		$sql = mysql_query("select class from NDKP_members group by class");
		while($r = mysql_fetch_object($sql)) {
			array_push($classes,$r->class);
		}
		return $classes;
	}
	function listPlayers($var) {
		$this->dbcnx();
		$arrs[attendancetotal]=array();
		$getTotal = mysql_query("select * from NDKP_raidattendance where raid_id='$_GET[id]'");
		if(mysql_num_rows($getTotal) == TRUE) {
			$totalAttendance = mysql_num_rows($getTotal);
		}
		$arrs[attendancetotal]=$totalAttendance;
		$sql = "select p.player_id, p.name, p.class 
				from NDKP_raidattendance a 
				left join NDKP_members p on a.player_id = p.player_id 
				where a.raid_id = '$_GET[id]' and p.inactive=0 order by class,name";
		$dbh = mysql_query($sql) or die(mysql_error());
		$cnt=0;
		while($r=mysql_fetch_object($dbh)) {
			$cnt++;
			if($r->player_id > 0) {
				if($r->class != $class) {
					$class=$r->class;
				}
				$classes[$r->class][$r->name][player_id]=$r->player_id;
			}
		}
		if($var == 'all') {
			return $classes;
		} else if($var == 'count') {
			return $cnt;
		}
	}

	function displayDrops() {
		$sql = "select i.name as item, i.item_id, p.name as name, d.dkp_cost
				from NDKP_raiddrops d 
				left join NDKP_members p on d.player_id = p.player_id 
				left join NDKP_items i on d.item_id = i.item_id 
				where d.raid_id = '$_GET[id]' and p.inactive=0";
		$dbi = mysql_query($sql);
		$c=0;
		$items[name]=array();
		$items[item_id]=array();
		$items[dkp]=array();
		$items[player]=array();
		while($d=mysql_fetch_object($dbi)) {
			$c++;
			array_push($items[name], $d->item);
			array_push($items[item_id], $d->item_id);
			array_push($items[dkp], $d->dkp_cost);
			array_push($items[player], $d->name);
		}
		#$this->debug($items);
		return $items;
	}
	function ndkpSearch($type) {
		$this->dbcnx();
		$arrs=array();
		$items=array();
		//breakdown the keywords
		$keywords=strtolower($this->vars[keywords]);
		$keywords=$this->cleanslash($keywords);

		$sql ="select * from NDKP_items ";
		$sql.=" where name like '".$keywords."%'";
		$sql.=" or name like '%".$keywords."'";
		$sql.=" or name like '%".$keywords."%'";
		$sql.=" or name like '".$keywords."'";

		$dbh=mysql_query($sql) or die(mysql_error());

		while($r=mysql_fetch_object($dbh)) {
			$ret[item_id]=$r->item_id;
			$ret[item]=$r->name;
			$items[]=$ret;
		}
		if($type == 'items') {
			return $items;
		}
		//players
		$sqr ="select * from NDKP_members";
		$sqr.=" where name like '".$keywords."%' ";
		$sqr.=" or name like '%".$keywords."'";
		$sqr.=" or name like '%".$keywords."%'";
		$sqr.=" or name like '".$keywords."'";
		$dbi=mysql_query($sqr) or die(mysql_error());

		while($p=mysql_fetch_object($dbi)) {
			$play[player_id]=$p->player_id;
			$play[player]=$p->name;
			$arrs[]=$play;
		}
		if($type == 'players') {
			return $arrs;
		}
	}
	function browseRaidAttendance() {
		$this->dbcnx();
		$all=array();
		$sql = "select * from NDKP_attendancetype 
				order by date desc ";
		$dbi = mysql_query($sql);
		$numrows=mysql_num_rows($dbi);
		$paginate=$this->paginate($numrows,30);
        $limit = "LIMIT ".$paginate[0][setRows].",".$paginate[0][rowsperPage];
		$sql .= $limit;
		$dbh = mysql_query($sql);
		while($r=mysql_fetch_object($dbh)) {
			$att[id]=$r->id;
			$att[type]=$r->type;
			$att[rdate]=$r->date;
			$att[note]=$r->notes;
			array_push($all,$att);
		}
		$all[setRows]=$paginate[0][setRows];
		$all[rowsperPage]=$paginate[0][rowsperPage];
		$all[lastPage]=$paginate[0][lastPage];
		return $all;
	}
	function displayRaidAttendance() {
		$this->dbcnx();
		$all=array();
		$sql="select * from NDKP_attendancetype where id='$_GET[id]'";
		$dbi=mysql_query($sql);
		$r=mysql_fetch_object($dbi);
		$att[rdate]=$r->date;
		$att[note]=$r->notes;
		$all[]=$att;
		return $att;
	}
	function daydrops($date,$var) {
		$this->dbcnx();
		$raiddate = date('Y-m-d',strtotime($date));
		$raids=$this->associatedRaids($date,'all');
		$alldrops=array();
		foreach($raids as $key=>$val) {
			$sql = mysql_query("select i.name, i.item_id,
								r.raid_id,p.name as player,d.dkp_cost
								from NDKP_raiddrops d
								left join NDKP_items i on i.item_id=d.item_id
								left join NDKP_raids r on r.raid_id=d.raid_id
								left join NDKP_members p on p.player_id=d.player_id
								where d.raid_id='".$val[raid_id]."'")
								or die(mysql_error());
			while($r=mysql_fetch_object($sql)) {
				$drops[raid_id] = $r->raid_id;
				$drops[item_id] = $r->item_id;
				$drops[item_name] = $r->name;
				$drops[player]=$r->player;
				$drops[dkp]=$r->dkp_cost;
				$alldrops[]=$drops;
			}
		}
		return $alldrops;
	}
	function associatedRaids($date,$var) {
		$this->dbcnx();
		$all=array();
		$raiddate = date('Y-m-d',strtotime($date));
		$sql = ("select * from NDKP_raids
				 where raid_date like '$raiddate%'");
		$dbh = mysql_query($sql) or die(mysql_error());
		$cnt=0;
		while($r=mysql_fetch_object($dbh)) {
			$cnt++;
			$att[raid_id]=$r->raid_id;
			$all[]=$att;
		}
		if($var == 'all') {
			return $all;
		} else if($var == 'count') {
			return $cnt;
		}
	}
	function listAttend($date,$var) {
		$this->dbcnx();
		$all=array();
		$raiddate = date('Y-m-d',strtotime($date));
		$sql = ("select a.*,m.name,m.class from NDKP_recordedattendance a
				 left join NDKP_attendancetype t on a.countID=t.id
				 left join NDKP_members m on m.player_id=a.playerID
				 where t.id = '$_GET[id]' and m.inactive=0 order by m.class, m.name");
		$dbh = mysql_query($sql) or die(mysql_error());
		$cnt=0;
		while($r=mysql_fetch_object($dbh)) {
			$cnt++;
			if($r->name != '') {
				$att['class']=$r->class;
				$att[player]=$r->name;
			}
			$all[]=$att;
		}
		#$this->debug($all);
		if($var == 'all') {
			return $all;
		} else if($var == 'count') {
			return $cnt;
		}
	}
	function paginate($numrows,$rowsperPage) {
		$pages=array();
		if($_GET[index] < 1) { 
			$index = 1; 
		} else {
			$index = $_GET[index];
		}
		$lastPage = ceil($numrows/$rowsperPage);
		$index = (int)$index;
		if($index < 1) {
			$index = 1;
		} elseif($index > $lastPage) {
			$index = $lastPage;
		}
        $setRows = ($index -1) * $rowsperPage;
        if($setRows < 0) {
            $setRows  = 0;
        }
		$page[setRows]=$setRows;
		$page[rowsperPage]=$rowsperPage;
		$page[lastPage]=$lastPage;
		$pages[]=$page;
		return $pages;
	}

	##############################################################
	##															##
	## 	DHTML Mouse over Displays								##
	##	Updated: January 23, 2006								##
	##															##
	##############################################################
	function writeItemSpans($items) {
		$this->dbcnx();
		$resists = array( "resist_fire"=>"Fire", "resist_shadow"=>"Shadow", "resist_arcane"=>"Arcane", "resist_nature"=>"Nature", "resist_frost"=>"Frost");
		$display = array( "strength"=>"Strength", "agility"=>"Agility", "stamina"=>"Stamina", "intellect"=>"Intellect", "spirit"=>"Spirit");

		$sql=mysql_query("select * from NDKP_items where item_id='$items'");
		$r=mysql_fetch_object($sql);

		$p.="\n";
		$spanName=str_replace("'",'',$r->name);
		$spanName=str_replace(" ",'-',$spanName);

		$p.='<div id="wrapper1">'."\n";
		$p.='	<div id="wrapper2">'."\n";
		$p.='	<span id="'.$spanName.'" style ="visibility:hidden; display: none;">'."\n";
		$p.='	<table cellspacing="0" cellpadding="0" border="0" class="spanItems">'."\n";
		$p.='	<tr>'."\n";
		$p.='		<td><img src="images/top-left.gif"></td>'."\n";
		$p.='		<td background="images/top.gif"><img src ="images/pixel.gif"></td>'."\n";
		$p.='		<td><img src="images/top-right.gif"></td>'."\n";
		$p.='	</tr>'."\n";
		$p.='	<tr>'."\n";
		$p.='		<td background="images/left.gif"><img src ="images/pixel.gif"></td>'."\n";
		$p.='		<td class="transparent">'."\n";
		$p.='			<table width="400" cellpadding="5" cellspacing="0" border="0" class="spanItems">'."\n";
		$p.='			<tr><td width="400" bgcolor="#000000" style="color: #A335EE; size: 9pt; font-weight: bold;">'.$r->name."\n";
		$p.='				<table cellspacing =" 0" cellpadding =" 0" border =" 0" width =" 100%">'."\n";
		$p.='					<tr><td><span class="myTable">'.ucfirst($r->slot)."</span></td>\n";
		$p.='						<td align="right"><span class="myTable">'.ucfirst($r->armor_type).'</span></td>'."\n";
		$p.='				</tr></table>'."\n";
		if($r->armor_class > 0) {
			$p.='<span class="myTable">'."\n";
			$p.='Armor: ' . $r->armor_class. '</span><br />'."\n";
		}
		if($r->lowend) {
			$p.='<span class="myTable">'."\n";
			$p.=$r->lowend.' - '.$r->topend.' Damage Speed '.number_format($r->speed,2).'<br>'."\n";
			$p.=number_format(($r->lowend + $r->topend)/2/$r->speed,1);
			$p.=' damage per second)</span><br />'."\n";
		}
		while(list($tag, $label) = each($display)) {
			if($r->$tag) {
				$p.='<span class="myTable">'."\n";
				$p.='+'.$r->$tag.' '.$label.'</span><br />'."\n";
			}
		}
		while(list($tag, $label) = each($resists)) {
			if($r->$tag) {
				$p.='<span class="myTable">'."\n";
				$p.='+'.$r->$tag.' '.$label .' Resist</span><br />'."\n";
			}
		}
		if($r->class_restrictions) {
			$p.='<span class="myTable">'."\n";
			$p.='Classes: ' . $r->class_restrictions . '</span><br />'."\n";
		}
		if($r->spell_pierce > 0) {
			$p.='<span class="myGreen">'."\n";
			$p.='Passive: Decreases the magical resistances of your spell targets by ' . $r->spell_pierce. '</span><br />'."\n";
		}

		if(!empty($r->comments)) {
			$p.='<span class="myGreen">'."\n";
			$p.=$r->comments . '</span><br />'."\n";
		}

		if($r->damage_all) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Increases damage and healing done by magical spells 
				 and effects by up to ' . $r->damage_all . '.</span><br />'."\n";
		}

		if($r->damage_single) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Increases damage done by ';
			$p.=ucfirst($r->damage_which) . ' spells and effects by up to ' . 
				$r->damage_single . '.</span><br />'."\n";
		}

		if($r->healing) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Increases healing done by magical spells and effects by up to '; 
			$p.=$r->healing . '.</span><br />'."\n";
		}

		if($r->crit_spell) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Improves your chance to get a critical strike with spells by ';
			$p.=$r->crit_spell . '%.</span><br />'."\n";
		}

		if($r->crit_melee) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Improves your chance to get a critical strike  by '; 
			$p.=$r->crit_melee . '%.</span><br />'."\n";
		}

		if($r->regen_mana) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Restores ' . $r->regen_mana . ' mana every 5 sec.</span><br />'."\n";
		}
		if($r->regen_health) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Restores ' . $r->regen_health. ' health every 5 sec.</span><br />'."\n";
		}

		if($r->parry) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Increases your chance to parry an attack by ' . $r->parry.'%.</span><br />'."\n";
		}

		if($r->dodge) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Increases your chance to dodge an attack by '.$r->dodge.'%.</span><br />'."\n";
		}

		if($r->defense) {
			$p.='<span class="myGreen">'."\n";
			$p.='Equip: Increased Defense +' . $r->defense . '.</span><br />'."\n";
		}

		if($r->attack_power) {
			$p.='<span class="myGreen">'."\n";
			$p.='Passive: +' . $r->attack_power. ' Attack Power</span><br />'."\n";
		}

		if($r->hit_melee) {
			$p.='<span class="myGreen">'."\n";
			$p.='Passive: Improves your chance to hit by ' . $r->hit_melee. '%</span><br />'."\n";
		}
		if($r->hit_spell) {
			$p.='<span class="myGreen">'."\n";
			$p.='Passive: Improves your chance to hit with spells by ' . $r->hit_spell. '%</span><br />'."\n";
		}

		$p.='<br /><span class="myGreen">'."\n";
		$p.='DKP: ' . $r->dkp_value. '</span><br />'."\n";
		if($r->secondary_value > 0) {
			$p.='<span class="myGreen">'."\n";
			$p.='Secondary DKP: ' . $r->secondary_value. '</span><br />'."\n";
		}
		$p.='</td></tr>'."\n";
		$p.='</table>'."\n";

		$p.='</td>'."\n";
		$p.='<td background ="images/right.gif"><img src="images/pixel.gif"></td>'."\n";
		$p.='</tr>'."\n";
		$p.='<tr>'."\n";
		$p.='<td><img src ="images/bot-left.gif"></td>'."\n";
		$p.='<td background ="images/bot.gif"><img src ="images/pixel.gif"></td>'."\n";
		$p.='<td><img src ="images/bot-right.gif"></td>'."\n";
		$p.='</tr>'."\n";
		$p.='</table>'."\n";
		$p.='</span>'."\n";
		$p.='</div>'."\n";
		$p.='</div>'."\n";

		return $p;
	}
	function displayItem() {
		$this->dbcnx();
		$columns=$this->returncolumns('NDKP_items');
		$sql = "select * from NDKP_items where item_id='$_GET[id]'";
		$dbi = mysql_query($sql);
		$r = mysql_fetch_object($dbi);

		foreach($columns as $col) {
			$arrs[$col] = $r->$col;
		}
		return $arrs;
	}
	function itempurchases($item) {
		if($item[quest_trigger]) {
			$where = "(d.item_id = '".$item[reward_one]."' or d.item_id = '".$item[reward_two]
					 . "' or d.item_id = '".$item[reward_three]."')";

			$qry = "select *, p.name as player_name , r.dungeon, r.raid_date, r.boss 
					from NDKP_raiddrops d 
					left join NDKP_members p on p.player_id = d.player_id 
					left join NDKP_raids r on d.raid_id = r.raid_id 
					where $where and p.inactive=0";
		} else {
			$qry = "select *, p.name as player_name, r.dungeon, r.raid_date, r.boss
					from NDKP_raiddrops d 
					left join NDKP_members p on p.player_id=d.player_id 
					left join NDKP_raids r on d.raid_id=r.raid_id 
					where d.item_id = '" . $_GET[id]. "'";
		}
		$dbh=mysql_query($qry) or die(mysql_error());
		while($r = mysql_fetch_object($dbh)) {
			$arrs[raid_id]=$r->raid_id;
			$arrs[raid_date]=$r->raid_date;
			$arrs[boss]=$r->boss;
			$arrs[dungeon]=$r->dungeon;
			$arrs[player]=$r->player_name;
			$arrs[dkp]=$r->dkp_cost;
			$all[]=$arrs;
		}
		#$this->debug($all);
		return $all;
	}
	function grabber($more) {
		if($more == 1) {
			$limit = "limit 3,20";
		} else {
			$limit = "limit 3";
		}
		$sql = "select *, DATE_FORMAT(created,'%a %b %d, %Y') as created 
				from NDKP_news order by created desc $limit";
		$dbi = mysql_query($sql) or die(mysql_error());
		while($r = mysql_fetch_object($dbi)) {
			$arrs[news_id]=$r->news_id;
			$arrs[author]=$r->author;
			$arrs[title]=$r->title;
			$arrs[news]=$r->news;
			$arrs[created]=$r->created;
			$news[]=$arrs;
		}
		return $news;
	}

	function debug($arr) {
		echo "<pre>";
		print_r($arr);
		echo "</pre>";
	}
	function droprate($item_id) {
		$this->dbcnx();
		$sql = mysql_query("select * from NDKP_raiddrops
							where item_id='$item_id'");
		$totaldrops= mysql_num_rows($sql);
		$qry = mysql_query("select boss from NDKP_raiddrops d
							left join NDKP_raids r on r.raid_id=d.raid_id
							where d.item_id = '$item_id' group by boss") or die(mysql_error());
		$arrs=array();
		while($r = mysql_fetch_object($qry)) {
			$iql = "SELECT count(*) as cnt 
					from NDKP_raids 
					where boss='$r->boss'";
			$dbi = mysql_query($iql) or die(mysql_error());
			while($total=mysql_fetch_object($dbi)) {
				$arrs[]=$total->cnt;
			}
			$totalkills=array_sum($arrs);
		}
		if($totaldrops > 0) {
			$droprate = number_format($totaldrops/$totalkills* 100,1).'%';
		} else {
			$droprate = "0.0%";
		}
		return $droprate;
	}
	function verifywishesexist() {
		$this->dbcnx();
		$sql = mysql_query("select wish_id from NDKP_wishlist where member='".$_GET['player']."'");
		if(mysql_num_rows($sql) == TRUE) {
			return TRUE;
		} else {
			return FALSE;
		}
	}
	function classbalance() {
		$this->dbcnx();
		$sql = "SELECT class, SUM(dkp_earned) as totalearned, 
				SUM(dkp_spent) as totalspent FROM NDKP_members GROUP BY class";
		$dbi = mysql_query($sql) or die(mysql_error());
		$arrs["class"]=array();
		$arrs["spent"]=array();
		$arrs["earned"]=array();
		while($r = mysql_fetch_object($dbi)) {
			array_push($arrs["class"],$r->class);
			array_push($arrs["spent"],$r->totalspent);
			array_push($arrs["earned"],$r->totalearned);
		}
		return $arrs;
	}
	function topdrops() {
		$this->dbcnx();
		$sql = "SELECT i.item_id, i.name, count(d.item_id) as cnt 
				FROM NDKP_raiddrops d 
				left join NDKP_items i on d.item_id = i.item_id 
				left join NDKP_raids r on d.raid_id = r.raid_id ";
		if(isset($_GET["boss"])) { 
			$sql.= " where boss='$_GET[boss]' ";
		} 
		if(isset($_GET["dungeon"])) {
			$sql.= " where dungeon='$_GET[dungeon]' ";
		}
		$sql.= " group by d.item_id order by cnt desc, i.name";
		$dbi = mysql_query($sql);
		$arrs["item_id"]=array();
		$arrs["item"]=array();
		$arrs["cnt"]=array();
		$arrs["rate"]=array();
		while($r = mysql_fetch_object($dbi)) {
			array_push($arrs["rate"],$this->droprate($r->item_id));
			array_push($arrs["item_id"],$r->item_id);
			array_push($arrs["item"],$r->name);
			array_push($arrs["cnt"],$r->cnt);
		}
		return $arrs;
	}		
}
?>
