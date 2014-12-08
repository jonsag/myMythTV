<?php

// Connections Parameters
$db_host = "localhost";
$db_name = "mythconverg";
$username = "mythtv";
$password = "mythconverg";

if ($argv [1]) {
	$argument1 = $argv [1];
} else {
	$argument1 = "";
}

$db_con = mysql_connect ( $db_host, $username, $password );
$connection_string = mysql_select_db ( $db_name );

// connect to mysql
if (! $db_con) {
	die ( 'Could not connect: ' . mysql_error () );
}

// select database
mysql_select_db ( $db_name ) or die ( mysql_error () );

function player_by_file_type($default_player) {
	$sql = "SELECT * FROM videotypes WHERE f_ignore='0'";
	$query = mysql_query ( $sql );
	while ( $row = mysql_fetch_array ( $query ) ) {
		echo $row ['extension'];
		if ($row ['use_default'] == "1") {
			echo ": " . $default_player . "\n";
		} else {
			echo ": Internal\n";
		}
	}
}

function ignored_file_types() {
	$sql = "SELECT * FROM videotypes WHERE f_ignore='1'";
	$query = mysql_query ( $sql );
	while ( $row = mysql_fetch_array ( $query ) ) {
		echo $row ['extension'] . ", ";
	}
}

function default_player_command() {
	$sql = "SELECT data FROM settings WHERE value='VideoDefaultPlayer'";
	$result = mysql_query ( $sql );
	if ($result) {
		$default_player = mysql_result ( $result, 0 );
	} else {
		die ( 'Invalid query: ' . mysql_error () );
	}
	return ($default_player);
}

function set_to_internal() {
	$sql = "UPDATE videotypes SET use_default='0' WHERE use_default='1' AND f_ignore='0'";
	$result = mysql_query ( $sql );
	if ($result) {
		echo "OK\n";
	} else {
		die ( 'Invalid query: ' . mysql_error () );
	}
}

function set_to_default() {
	$sql = "UPDATE videotypes SET use_default='1' WHERE use_default='0' AND f_ignore='0'";
	$result = mysql_query ( $sql );
	if ($result) {
		echo "OK\n";
	} else {
		die ( 'Invalid query: ' . mysql_error () );
	}
}

function toggle() {
	$sql = "SELECT * FROM videotypes WHERE f_ignore='0'";
	$query = mysql_query ( $sql );
	while ( $row = mysql_fetch_array ( $query ) ) {
		$extension = $row ['extension'];
		if ($row ['use_default'] == "1") {
			$sql = "UPDATE videotypes SET use_default='0' WHERE extension='" . $extension . "'";
		} else {
			$sql = "UPDATE videotypes SET use_default='1' WHERE extension='" . $extension . "'";
		}
		$result = mysql_query ( $sql );
		if ($result) {
			echo "OK - ";
			echo $extension . " - player changed from ";
			if ($row ['use_default'] == "1") {
				echo "default to Internal";
			} else {
				echo "Internal to default";
			}
			echo "\n";
		} else {
			die ( 'Invalid query: ' . mysql_error () );
		}
	}
}

function help() {
	echo "Run this script with an argument\n\n";
	echo "Valid arguments are:\n";
	echo "show - Shows current settings\n";
	echo "internal - Sets mythvideo player to Internal\n";
	echo "default - Sets mythvideo player to default\n";
	echo "toggle - Switches between Internal and default player for mythvideo\n";
	echo "help - Shows this text\n\n";
}

function clear_cache() {
	echo "\nReloading database...\n";
	exec ( 'mythutil --message --message_text "Clearing cache and reloading database..." --timeout  5 -v --bcastaddr 192.168.10.6' );
	exec ( 'mythutil --clearcache' );
}

switch ($argument1) {
	
	case "show" :
		$default_player = default_player_command ();
		echo "Default player command: " . $default_player . "\n\n";
		echo "Player by file type:\n";
		player_by_file_type ( $default_player );
		echo "\n";
		echo "Ignored file types: ";
		ignored_file_types ();
		echo "\n";
		break;
	case "internal" :
		echo "Setting mythvideo player to Internal...\n";
		set_to_internal ();
		echo "\n";
		$default_player = default_player_command ();
		echo "Now player by file type is:\n";
		player_by_file_type ( $default_player );
		clear_cache ();
		break;
	case "default" :
		echo "Setting mythvideo player to default...\n";
		set_to_default ();
		echo "\n";
		$default_player = default_player_command ();
		echo "Now player by file type is:\n";
		player_by_file_type ( $default_player );
		clear_cache ();
		break;
	case "toggle" :
		toggle ();
		echo "\n";
		$default_player = default_player_command ();
		echo "Now player by file type is:\n";
		player_by_file_type ( $default_player );
		clear_cache ();
		break;
	case "help" :
		help ();
		break;
	default :
		echo "Error! - No valid arguments passed\n\n";
		help ();
}

// echo "Setting mythvideo player to default (mplayer/xine etc)...\n";
// echo "\n";
// mysql -u$db_user -p$db_pass $database < ~/bin/mythvideo-set-to-default.sql

// echo "Current settings:\n";
// mysql -u$db_user -p$db_pass $database < ~/bin/mythvideo-check-player-settings.sql

// echo "Setting mythvideo player to internal...\n";
// echo "\n";
// mysql -u$db_user -p$db_pass $database < ~/bin/mythvideo-set-to-internal.sql

// echo "Current settings:\n";

// close connection to mysql
mysql_close ( $db_con );

?>