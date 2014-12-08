#!/usr/bin/php

<?php
$files = 0;
$orphans = 0;

// /// include configuration file
echo "Reading configuration file...\n";
include ('config-mythtv.php');

// /// connect to mysql
echo "Connecting to MySQL...\n";
if (! $db_con) {
	die ( 'Could not connect: ' . mysql_error () );
	exit ();
} else {
	echo "     Connected!\n";
}

// /// select database
echo "Selecting database...\n";
if (! mysql_select_db ( $db_name )) {
	die ( 'Could not select datasbase: ' . mysql_error () );
	exit ();
} else {
	echo "     Database selected!\n";
}

echo "\nThis php script will compare files in your 'Standard' folder whith the entries in the 'recordings' table in mythconverg database.\n\n";

// /// find where recordings are stored
$query1 = "SELECT `dirname` FROM `storagegroup` WHERE `groupname` LIKE 'Default'";
$result1 = mysql_query ( $query1 ) or die ( mysql_error () );
$dirname = mysql_fetch_array ( $result1 );
$dirname = $dirname [0];
echo "Your 'Standard' directory where the recordings are stored, is " . $dirname . "\n\n";

// /// list mpg files in directory
echo "This directory contains these mpg files:\n";
exec ( "ls $dirname*.mpg | xargs -n1 basename", $file );
foreach ( $file as &$tmp ) {
	$query2 = "SELECT `title`, `description` FROM `recorded` WHERE `basename` LIKE '$tmp'";
	$result2 = mysql_query ( $query2 ) or die ( mysql_error () );
	// check for empty result, these are orphans
	if (mysql_numrows ( $result2 ) == 0) {
		echo $tmp . " does not exist in database\n\n";
		$orphans ++;
		$orphan [$orphans] = $dirname . $tmp;
	} else {
		$result2 = mysql_fetch_array ( $result2 );
		$title = $result2 [0];
		$description = $result2 [1];
		echo $tmp . "\n" . $title . "\n" . $description . "\n\n";
	}
	$files ++;
}

echo "There are " . $files . " mpg files in this directory\n\n";

echo $orphans . " of those were orphans";

// /// if there were any orphans, print filenames
if ($orphans > 0) {
	echo ":\n";
	for($i = 1; $i <= $orphans; $i ++) {
		echo $orphan [$i] . "\n";
	}
	echo "\nIf you want to remove them, copy and paste the following line in a bash shell:\n";
	echo "rm";
	for($i = 1; $i <= $orphans; $i ++) {
		echo " " . $orphan [$i];
	}
	echo "\n";
} else {
	echo ".\n";
}

// // close mysql connection
mysql_close ( $db_con );
?>
