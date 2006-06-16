<?php

	require('config/siteSettings.php');
	require('config/site.php');
	$ndkp = new NDKP;
	$ndkp->dbUser=$dbUser;
	$ndkp->dbPassword=$dbPassword;
	$ndkp->dbServer=$dbServer;
	$ndkp->dBase=$dBase;
	$ndkp->dbcnx();

	define(TAB, "\t");
	define(CRLF, "\r\n");

	echo "NurfedDKPPlayers = {".CRLF;

	$sql = "select count(*) as total from NDKP_attendancetype 
		where DATE_SUB(CURDATE(), INTERVAL 42 DAY) <= date";//New Sixweeks

	$result = mysql_query($sql) or die(mysql_error());
	$raided = mysql_fetch_array($result);

	$sixweeks = $raided["total"];
	$filteri = "";
	$filteri = "class!=''";

#	$sql = "select count(*) as attended, p.* from NDKP_recordedattendance r
#		left join NDKP_attendancetype n on n.id= r.countID
#		left join NDKP_members p on p.player_id = r.playerID 
#		where DATE_SUB(CURDATE(), INTERVAL 42 DAY) <= n.date and $filteri";
#	$sql .= " group by r.playerID";
#	$sql .= " order by dkp desc";

                $sql = 'create temporary table tempdkptable ';
                $sql = $sql . "select count(*) as attended, p.* from NDKP_recordedattendance r
                                left join NDKP_attendancetype n on n.id= r.countID
                                left join NDKP_members p on p.player_id = r.playerID ";
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

                $sql = 'select * from NDKP_members';
                $dbi = mysql_query($sql) or die(mysql_error());

	$myh = array(
	"name"=>"Name",
	"rank"=>"Rank",
	"dkp"=>"DKP",
	"class"=>"Class",
	"attended"=>"6wkAtt"
	);

	while(list($tag, $label) = each($myh)) {
		$flip = "asc";
		if($sortby==$tag) {
			$flip = "desc";
		}
		$classi = "";
	}

	$result = mysql_query($sql) or die(mysql_error());

	$rank = 0;
	while($player = mysql_fetch_array($result)) {
		$flag = 0;
		if($player["attended"]/$sixweeks<.5) {
			$flag = 1;
		}else{
			$rank++;
		}
		reset($myh);
		while(list($tag, $label) = each($myh)) {
			if($tag=="name") {
				echo TAB."[\"".$player[$tag]."\"] = {".CRLF;
			}else if(eregi('dkp',$tag)) {
				echo TAB.TAB."[\"dkp\"] = ".number_format($player[$tag],3).",".CRLF;
			}else if($tag=="rank") {
				if(!$flag) { echo TAB.TAB."[\"rank\"] = ".$rank.",".CRLF;}
			}
		else {
			if($tag=="attended") {
				echo TAB.TAB."[\"att\"] = ".number_format($player["attendance"],1) . ",".CRLF;
			}else{
				echo TAB.TAB."[\"class\"] = \"".$player[$tag]."\",".CRLF;
			}
		}
	}
	echo TAB."},".CRLF;
}
echo "}";
?>
