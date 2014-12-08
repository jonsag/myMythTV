<?php
date_default_timezone_set ( 'Europe/Stockholm' );
// setlocale(LC_ALL, 'en_US');

// Connections Parameters
$db_host = "localhost";
$db_name = "mythconverg";
$username = "mythtv";
$password = "mythconverg";
$db_con = mysql_connect ( $db_host, $username, $password );
$connection_string = mysql_select_db ( $db_name );
// Connection
// mysql_connect($db_host,$username,$password);
// mysql_select_db($db_name);

?>