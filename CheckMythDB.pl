#!/usr/bin/perl -w
#  Check MythTV database for schema errors
#  Hacked together by i.dobson {at} planet-ian.com
#  Software version 1.01o  24.10.2010
#  The newest version of this script is available at http://www.planet-ian.com/MythTV/CheckMythDB.txt
#
# Multiple Storage groups with the same name are supported (/directory1:/directory2:/directory3)
#
# Checks VideoInput -> CardInput               .. OK (only checks local encoder cards)
#        VideoInput -> Channels                .. OK (only looks at visible channels)
#        CardInput  -> Devices in /devfs       .. OK (only understands MPEG,DVB and FREEBOX encoders) displays permissions
#        CardInput  -> Channel change script   .. OK Checks file exists and displays access rights
#        Videosource                           .. OK Read/decode m3u file for FREEBOX decoder
#        Channels  -> VideoInput               .. OK
#        Channels <-> DVB Multiplex            .. OK (only looks at channels that are attached to a videosource with useeit=1 )
#        Channels <-> EPG                      .. OK
#        Recorded <-> Seek                     .. OK
#        Recorded <-> Markup                   .. OK
#        Recorded <-> FS                       .. OK
#        Recorded <-> FS file size             .. OK
#        Recorded ->  Storage Groups           .. OK (Fixed missing trailing \ check)
#        Recorded (LiveTV) -> Age of recording .. OK
#        Recorded -> Thumbnails                .. OK
#        Thumbnails -> File size               .. OK file must be > 100bytes
#        Thumbnails -> file owner              .. OK file should be owned by mythtv user
#        Thumbnails -> recordings              .. OK thumbnail must have a recording
#
# Note:
#        -> One way check
#       <-> Check in both directions
# Requires the following perl modules:-
#   Getopt
#   DBI
#
# Call with CheckMythDB.pl -u UserName -p Password -h Hostname -t Check Thumbnails -r Check recordings -f Check files on fs -v Verbose -c Check Channels -H Help text -a All options -b BlackWhite
#
# If you don't define a username/password/hostname the script will attempt to read this information from the mysql.txt file
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################
use Getopt::Std;
use DBI;
use strict;
use LWP::Simple;
use URI;
use Sys::Hostname;

my $FIXME = "";

my $sql_return = "";
my $SQLDBName  = "mythconverg";
my $Result     = "";
my $Result1    = "";
my @Result     = "";
my $DEBUG      = 1;
my $SQLCount   = 0;
my $XXX        = "";
my @DVBTUNERS  = "";

my $VideoSources    = 0;
my $VideoInputID    = ();
my $VideoInputName  = ();
my $ChannelID       = ();
my $ChannelName     = ();
my $ChannelCallsign = ();
my %StorageGroups;
my $EncoderNumber;

my $StorageCount = 0;

# Setting up the colors for the print styles
my $good = "[\e[00;32mOK\e[00m]";
my $bad  = "[\e[00;31m!!\e[00m]";
my $info = "[\e[00;34m--\e[00m]";
my $ext  = "{nuv,mpg,mpeg,avi}";

sub getCommandLine;
sub MyPrint;
sub SQLQuerySimple;
sub SQLQuery;

# Get command line options
my ( $user, $password, $host, $CheckRecordings, $CheckFS, $CheckChannels,
	$SQLHost, $CheckThumbs )
  = &getCommandLine();
my $LocalHost = hostname;

if ( "$host" eq "$LocalHost" ) {
	&MyPrint( 1,
		$info
		  . ".Checking configuration for host '$host' script running on host '$LocalHost'\n"
	);
}
else {
	&MyPrint( 2,
		$bad
		  . ".Checking configuration for host '$host' but running on host '$LocalHost' \n"
	);
}

#Quick Check if video sources are defined
$VideoSources = SQLQuerySimple("SELECT count(*) FROM `videosource`");
if ( $VideoSources eq 0 ) {
	&MyPrint( 2, $bad . ".No Video sources defined\n" );
	exit;
}
else {
	&MyPrint( 1, $good . ".Found $VideoSources video sources\n" );
}

#Read each video source checking for EIT configuration
my @VideoInputID;
my @VideoInputName;
my @result = SQLQuery("SELECT sourceid,name,xmltvgrabber from `videosource`");
for $XXX (@result) {
	push @VideoInputID,   @$XXX[0];
	push @VideoInputName, @$XXX[1];
	if ( defined( @$XXX[2] ) ) {
		MyPrint( 1,
			    $good
			  . ".Videosource "
			  . @$XXX[0] . " '"
			  . @$XXX[1]
			  . "' has a EPG source defined ("
			  . @$XXX[2]
			  . ")\n" );
	}
	else {
		MyPrint( 2,
			    $bad
			  . ".Videosource "
			  . @$XXX[0] . " '"
			  . @$XXX[1]
			  . "' Does not appear to have EPG source defined\n" );
	}
}

#Read each video source checking for Cardinputs
foreach $XXX (@VideoInputID) {
	$Result = SQLQuerySimple(
		"SELECT count(*) from `cardinput` where `sourceid` = '" . $XXX . "'" );
	if ( $Result eq 0 ) {
		MyPrint( 2,
			$bad . ".Videoinput $XXX does not have any card inputs defined\n" );
	}
	else {
		MyPrint( 1,
			$good . ".Videoinput $XXX has $Result card inputs defined\n" );
	}
}

#Read each video source checking for default channel
MyPrint( 1, $info . ".Checking start channel for each cardinput\n" );
@result = SQLQuery(
"SELECT sourceid,startchan,cardinputid  from `cardinput` order by cardinputid"
);
for my $XXX (@result) {
	$Result =
	  SQLQuerySimple( "SELECT count(*) from channel where channum='"
		  . @$XXX[1]
		  . "'  and sourceid='"
		  . @$XXX[0]
		  . "'" );
	if ( $Result eq 0 ) {
		MyPrint( 2,
			    $bad
			  . ".Cardinput ("
			  . @$XXX[2]
			  . ") Start channel ("
			  . @$XXX[1]
			  . ")invalid\n" );
	}
	else {
		MyPrint( 0,
			    $good
			  . ".Cardinput ("
			  . @$XXX[2]
			  . ") Start channel ("
			  . @$XXX[1]
			  . ") valid\n" );
	}
}

#Read each external channel change script checking that it exists/is executable
MyPrint( 1, $info . ".Checking channel change script for each cardinput\n" );
@result = SQLQuery(
"SELECT sourceid,startchan,cardinputid,externalcommand  from `cardinput` order by cardinputid"
);
for my $XXX (@result) {
	if ( defined @$XXX[3] && @$XXX[3] ne '' ) {
		MyPrint( 2,
			    $info
			  . ".Cardinput ("
			  . @$XXX[2]
			  . ") has a channel change script defined '@$XXX[3]' \n" );
		if ( -e @$XXX[3] ) {
			my $mode  = ( stat("@$XXX[3]") )[2];
			my $mode1 = sprintf "%04o", $mode & 0777;
			my $perms = GetPermissions($mode1);
			my $uidu  = ( stat "@$XXX[3]" )[4];
			my $uidg  = ( stat "@$XXX[3]" )[5];
			my $user  = ( getpwuid $uidu )[0];
			my $group = ( getgrgid $uidg )[0];
			if ( index( $perms, 'x' ) lt 0 ) {
				MyPrint( 2,
					$bad
					  . ".Channel change script '@$XXX[3]' does not appear to have the execute permissions $mode1 ($perms)\n"
				);
			}
			else {
				MyPrint( 2,
					$good
					  . ".Channel change script '@$XXX[3]' the permissions $mode1 ($perms) owner ($user) group ($group)\n"
				);
			}
		}
		else {
			MyPrint( 2,
				$bad
				  . ".Channel change script '@$XXX[3]' does not appear to exist \n"
			);
		}
	}
}

#check that each Cardinput has a valid video source
$Result = SQLQuerySimple(
"SELECT count(*) FROM cardinput WHERE sourceid NOT IN (SELECT sourceid FROM videosource )"
);
if ( $Result eq 0 ) {
	MyPrint( 1, $good . ".All InputCards are linked to a videosource\n" );
}
else {
	MyPrint( 2,
		$bad . ".$Result inputcards are not linked to a videosource\n" );
}

#check that all video sources have atleast one channel
foreach $XXX (@VideoInputID) {
	$Result = SQLQuerySimple(
		    "SELECT count(*) FROM channel WHERE visible = '1' and sourceid = '"
		  . $XXX
		  . "'" );
	$Result1 = SQLQuerySimple(
		    "SELECT count(*) FROM channel WHERE visible != '1' and sourceid = '"
		  . $XXX
		  . "'" );
	if ( $Result eq 0 ) {
		MyPrint( 2,
			$bad
			  . ".Videosource $XXX does not appear to have any channels defined\n"
		);
	}
	else {
		MyPrint( 1,
			$good
			  . ".Videosource $XXX has $Result visible and $Result1 invisible channels defined\n"
		);
	}
}

#check that all card inputs have a valid device
@Result = SQLQuery(
"SELECT `cardid`,`videodevice`,`cardtype`,`hostname`  FROM `capturecard` order by `cardid`"
);
foreach $XXX (@Result) {
	my $EncoderNumber = @$XXX[0];
	my %ChannelList;
	if ( @$XXX[3] ne "$host" ) {
		MyPrint( 1,
			$info
			  . ".cardinput @$XXX[0] type @$XXX[2] is not local to host '$host' it's configured on host '@$XXX[3]' \n"
		);
	}
	else {
		if ( @$XXX[2] eq "MPEG" ) {
			if ( -e @$XXX[1] ) {
				my $mode  = ( stat("@$XXX[1]") )[2];
				my $mode1 = sprintf "%04o", $mode & 0777;
				my $perms = GetPermissions($mode1);
				my $uidu  = ( stat "@$XXX[1]" )[4];
				my $uidg  = ( stat "@$XXX[1]" )[5];
				my $user  = ( getpwuid $uidu )[0];
				my $group = ( getgrgid $uidg )[0];
				MyPrint( 1,
					$good
					  . ".cardinput @$XXX[0] type @$XXX[2] exists as device (@$XXX[1]), file permissions are $mode1 ($perms) owner ($user) group ($group) \n"
				);
			}
			else {
				MyPrint( 2,
					$bad
					  . ".cardinput @$XXX[0] does not appear to exist as a device\n"
				);
			}
		}
		elsif ( @$XXX[2] eq "DVB" ) {
			if ( -e @$XXX[1] ) {
				my $mode  = ( stat( @$XXX[1] ) )[2];
				my $mode1 = sprintf "%04o", $mode & 0777;
				my $perms = GetPermissions($mode1);
				my $uidu  = ( stat @$XXX[1] )[4];
				my $uidg  = ( stat @$XXX[1] )[5];
				my $user  = ( getpwuid $uidu )[0];
				my $group = ( getgrgid $uidg )[0];
				MyPrint( 1,
					$good
					  . ".cardinput @$XXX[0] type @$XXX[2] exists as device (@$XXX[1]), file permissions are $mode1 ($perms) owner ($user) group ($group)\n"
				);
			}
			else {
				MyPrint( 2,
					$bad
					  . ".cardinput @$XXX[0] does not appear to exist as a device\n"
				);
			}
		}
		elsif ( @$XXX[2] eq "V4L" ) {
			if ( -e "/dev/video" . @$XXX[1] ) {
				my $mode  = ( stat( "/dev/video" . @$XXX[1] ) )[2];
				my $mode1 = sprintf "%04o", $mode & 0777;
				my $perms = GetPermissions($mode1);
				my $uidu  = ( stat "/dev/video" . @$XXX[1] )[4];
				my $uidg  = ( stat "/dev/video" . @$XXX[1] )[5];
				my $user  = ( getpwuid $uidu )[0];
				my $group = ( getgrgid $uidg )[0];
				MyPrint( 1,
					$good
					  . ".cardinput @$XXX[0] type @$XXX[2] exists as device (@$XXX[1]), file permissions are $mode1 ($perms) owner ($user) group ($group)\n"
				);
			}
			else {
				MyPrint( 2,
					$bad
					  . ".cardinput @$XXX[0] does not appear to exist as a device\n"
				);
			}
		}
		elsif ( @$XXX[2] eq "FREEBOX" ) {
			my $M3U          = get( @$XXX[1] );
			my $ChannelCount = 0;
			if ( length($M3U) < 10 ) {
				MyPrint( 2,
					    $bad
					  . ".cardinput $EncoderNumber type @$XXX[2] m3u file '@$XXX[1]' returned from webserver too small ("
					  . length($M3U)
					  . " bytes) \n" );
			}
			else {
				MyPrint( 1,
					    $good
					  . ".cardinput $EncoderNumber type @$XXX[2] got "
					  . length($M3U)
					  . " bytes from web page (M3U) file '@$XXX[1]'\n" );
				my @M3U_ARRAY = split( '\n', $M3U );
				foreach my $XXX (@M3U_ARRAY) {
					if ( index( $XXX, "EXTINF:" ) gt 0 ) {
						$ChannelCount++;
						$XXX =~ s/#EXTINF://g;
						my @ZZZ = split( ' ', $XXX );
						my @XXX = split( / /, $ZZZ[0], 1 );
						@ZZZ = split( ',', $XXX[0] );
						$Result = SQLQuerySimple(
							    "SELECT count(*) FROM channel where channum='"
							  . $ZZZ[1]
							  . "'" );
						$ChannelList{ $ZZZ[1] } = 1;
						if ( $Result ne 1 ) {
							MyPrint( 2,
								    $bad
								  . ".channel "
								  . $ZZZ[1]
								  . " exists in the m3u file but not in channel table\n"
							);
						}
					}
				}
				MyPrint( 1,
					$good
					  . ".cardinput $EncoderNumber has $ChannelCount Channels defined in m3u file\n"
				);
				my @Result2 = SQLQuery(
"SELECT channum FROM channel where sourceid = (select sourceid from cardinput where cardid = '"
					  . $EncoderNumber
					  . "') ORDER BY channum" );
				foreach my $TestChannel (@Result2) {
					if ( not defined( $ChannelList{ @$TestChannel[0] } ) ) {
						MyPrint( 2,
							$bad
							  . ".Channel @$TestChannel[0] exists in channel table but not in the m3u file for tuner $EncoderNumber\n"
						);
					}
				}
			}
		}
		else {
			MyPrint( 2,
				$bad
				  . ".sorry I don't know how to check cardinput @$XXX[0] type @$XXX[2] device @$XXX[1]\n"
			);
		}
	}
}

#check that each channel has a valid video source
$Result = SQLQuerySimple(
"SELECT count(*) FROM channel WHERE sourceid NOT IN (SELECT sourceid FROM videosource ) "
);
if ( $Result eq 0 ) {
	MyPrint( 1, $good . ".All channels have a valid videosource\n" );
}
else {
	MyPrint( 2, $bad . ".$Result channels do not have a valid videosource\n" );
}

#check each multiplex against video source
$Result = SQLQuerySimple(
"SELECT count(*) FROM  dtv_multiplex  WHERE sourceid NOT IN (SELECT sourceid FROM videosource ) "
);
if ( $Result eq 0 ) {
	MyPrint( 1,
		$good . ".All dtv_multiplex channels have a valid videosource\n" );
}
else {
	MyPrint( 2,
		$bad
		  . ".$Result dtv_multiplex channels do not have a valid videosource\n"
	);
}

#check each multiplex against channels
$Result = SQLQuerySimple(
"SELECT count(*) FROM  channel, videosource WHERE videosource.useeit=1 and channel.sourceid=videosource.sourceid and mplexid NOT IN (SELECT mplexid FROM dtv_multiplex ) and channel.visible = 1 "
);
if ( $Result eq 0 ) {
	MyPrint( 1, $good . ".All channel entries have a valid dtv_multiplex\n" );
}
else {
	MyPrint( 2,
		$bad . ".$Result channel entries do not have a valid dtv_multiplex\n" );
	@Result = SQLQuery(
"SELECT channel.callsign, channel.sourceid, videosource.useeit FROM channel, videosource WHERE videosource.useeit =1 AND channel.sourceid = videosource.sourceid AND mplexid NOT IN ( SELECT mplexid FROM dtv_multiplex )"
	);
	for my $XXX (@Result) {
		MyPrint( 2,
			$bad
			  . ".Channel '@$XXX[0]' does not have a valid dtv_multiplex\n" );
	}
}

#check each channel against multiplex
$Result = SQLQuerySimple(
"SELECT count(DISTINCT (dtv_multiplex.mplexid)) FROM dtv_multiplex WHERE dtv_multiplex.mplexid NOT IN (SELECT DISTINCT dtv_multiplex.mplexid FROM dtv_multiplex INNER JOIN channel ON  dtv_multiplex.mplexid = channel.mplexid) "
);
if ( $Result == 0 ) {
	MyPrint( 1, $good . ".All dtv_multiplex entries have a valid channel\n" );
}
else {
	MyPrint( 2,
		$info
		  . ".$Result dtv_multiplex entries do not have a valid channel\n" );
}

#Read each channel
if ( defined($CheckChannels) && ( $CheckChannels eq 1 ) ) {
	my ( @Channelid, @ChannelCallsign, @ChannelName );
	@Result = SQLQuery(
"SELECT channel.chanid,channel.callsign,channel.name from `channel` where visible='1' order by chanid"
	);
	for my $XXX (@Result) {
		push @Channelid,       @$XXX[0];
		push @ChannelCallsign, @$XXX[1];
		push @ChannelName,     @$XXX[2];

		#Check EPG data (count)
		my $Result1 =
		  SQLQuerySimple( "SELECT count(*) from `program` where chanid = '"
			  . @$XXX[0]
			  . "'" );
		my $Message = "Channel " . @$XXX[1] . " has $Result1 programs in EPG";

		#Check EPG data (age)
		if ( $Result1 > 0 ) {
			my $Result1 = SQLQuerySimple(
"SELECT (UNIX_TIMESTAMP( MAX( endtime )) - UNIX_TIMESTAMP( NOW( ) ) ) /86400 from `program` where chanid = '"
				  . @$XXX[0]
				  . "'" );
			if ( $Result1 < 0 ) {
				MyPrint( 2,
					$bad
					  . ".$Message.No EPG data or last program in the past\n" );
			}
			else {
				MyPrint( 0,
					$good
					  . ".$Message and data available for $Result1 days\n" );
			}
		}
		else {
			MyPrint( 2, $bad . ".$Message.No EPG data\n" );
		}
	}

	#Check EPG data against Channel data
	$Result = SQLQuerySimple(
"SELECT count(*) FROM program WHERE chanid NOT IN (SELECT chanid FROM channel ) "
	);
	if ( $Result eq 0 ) {
		MyPrint( 1, $good . ".All EPG entries have a valid channel\n" );
	}
	else {
		MyPrint( 2,
			$bad . ".$Result EPG entries do not have a valid channel\n" );
	}
}

#Get storage groups count
$StorageCount = SQLQuerySimple(
	"SELECT count(*) FROM storagegroup WHERE hostname='" . $host . "'" );
if ( $StorageCount gt 0 ) {
	MyPrint( 1, $good . ".Found $StorageCount storage groups for '$host'\n" );
}
else {
	MyPrint( 2, $bad . ".No storage groups found for host '$host'\n" );
}

if ( $StorageCount gt 0 ) {
	@Result = SQLQuery(
		"SELECT groupname,hostname,dirname from storagegroup where hostname='"
		  . $host
		  . "'" );
	for my $XXX (@Result) {

		#Multi dir storage group
		if ( index( @$XXX[2], ":" ) > 0 ) {
			my @DirList = split( ":", @$XXX[2] );
			for my $Dir (@DirList) {
				if ( substr( $Dir, -1, 1 ) ne "/" ) {
					$Dir = $Dir . "/";
				}
				if ( -d $Dir ) {
					MyPrint( 1,
						    $good
						  . ".Storage group '"
						  . @$XXX[0]
						  . "' exists in file system at ("
						  . $Dir
						  . ")\n" );
					$StorageGroups{ @$XXX[0] } = @$XXX[2];
				}
				else {
					MyPrint( 2,
						    $bad
						  . ".Storage group '"
						  . @$XXX[0]
						  . "' does not appear to exist in file system at ("
						  . $Dir
						  . ")\n" );
				}
			}
		}
		else {

			#Simple storage group
			if ( -d @$XXX[2] ) {
				if ( substr( @$XXX[2], -1, 1 ) ne "/" ) {
					@$XXX[2] = @$XXX[2] . "/";
				}

				#Convert multiple groups with same name to dir:dir:dir syntax
				if ( $StorageGroups{ @$XXX[0] } ) {
					$StorageGroups{ @$XXX[0] } =
					  $StorageGroups{ @$XXX[0] } . ":" . @$XXX[2];
				}
				else {
					$StorageGroups{ @$XXX[0] } = @$XXX[2];
				}
				MyPrint( 1,
					    $good
					  . ".Storage group '"
					  . @$XXX[0]
					  . "' exists in file system at ("
					  . @$XXX[2]
					  . ")\n" );
			}
			else {
				MyPrint( 2,
					    $bad
					  . ".Storage group '"
					  . @$XXX[0]
					  . "' does not appear to exist in file system at ("
					  . @$XXX[2]
					  . ")\n" );
			}
		}
	}

	#Check storagegroups defined in recorded against storagegroups
	@Result = SQLQuery("SELECT distinct storagegroup from recorded");
	if ( @Result gt 0 ) {
		for my $XXX (@Result) {
			$Result = SQLQuerySimple(
				    "SELECT count(*) from storagegroup where groupname='"
				  . @$XXX[0]
				  . "' and hostname='"
				  . $host
				  . "'" );
			if ( $Result eq 0 ) {
				MyPrint( 2,
					$bad
					  . ".Storage group '@$XXX[0]' is used in the recorded database but it's not defined\n"
				);
			}
			else {
				MyPrint( 0,
					$good
					  . ".Storage group '@$XXX[0]' is used in the recorded database and is defined\n"
				);
			}
		}
	}

	#Check files in storage groups
	my $FileFound = 0;
	if ( defined($CheckFS) && ( $CheckFS eq 1 ) ) {
		foreach (%StorageGroups) {
			if ( $StorageGroups{$_} ) {
				my @DirList = split( ":", $StorageGroups{$_} );
				for my $Dir (@DirList) {
					if ( substr( $Dir, -1, 1 ) ne "/" ) {
						$Dir = $Dir . "/";
					}
					MyPrint( 1,
						$info . ".Checking files in storage group '$_'\n" );
					my @files = glob("$Dir*.$ext");
					for my $YYY (@files) {
						my $FileSize = -s $YYY;
						$YYY =~ s/$Dir//g;
						$Result = SQLQuerySimple(
							    "SELECT count(*) from recorded where basename='"
							  . $YYY
							  . "' and storagegroup = '"
							  . $_
							  . "'" );
						if ( $Result eq 1 ) {
							MyPrint( 0,
								$good
								  . ".File $YYY storage group '$_' exists in database\n"
							);
							if ( $FileSize < 1000 ) {
								MyPrint( 2,
									$bad
									  . ".File '$YYY' storage group '$_' file far too small ($FileSize bytes)\n"
								);
							}
						}
						else {
							MyPrint( 2,
								$bad
								  . ".File '$YYY' storage group '$_' does not appear to exist in database\n"
							);
						}
					}
					if ( defined($CheckThumbs) && ( $CheckThumbs eq 1 ) ) {
						MyPrint( 1,
							$info
							  . ".Checking thumbnails in storage group '$_' against recordings\n"
						);
						for my $Dir (@DirList) {
							my @files = glob("$Dir*png");
							for my $file (@files) {
								my $SaveFile = $file;
								$file =~ s/\..*//;
								my $RecordingFound = 0;
								my @pngfiles       = glob("$file*");
								for my $pngfile (@pngfiles) {
									if ( index( $pngfile, ".png" ) == -1 ) {
										$RecordingFound = 1;
										last;
									}
								}
								if ( $RecordingFound == 0 ) {
									MyPrint( 2,
										$bad
										  . ".No recording found for Thumbnail '$SaveFile'\n"
									);
								}
							}
						}
					}
				}
			}
		}
		$Result = SQLQuerySimple("SELECT count(*) FROM recorded ");
		my $PNGfilename;
		my $FoundPNG = 0;
		MyPrint( 1,
			$info
			  . ".Checking $Result recordings in database (file system)\n" );
		@Result = SQLQuery(
			"SELECT chanid,starttime,basename,storagegroup,title FROM recorded "
		);
		for my $XXX (@Result) {

			#Check recordings against file system
			my $FoundFile = 0;
			if ( defined( $StorageGroups{ @$XXX[3] } ) ) {
				my @DirList = split( ":", $StorageGroups{ @$XXX[3] } );
				for my $Dir (@DirList) {
					if ( substr( $Dir, -1, 1 ) ne "/" ) {
						$Dir = "$Dir/";
					}
					if ( -e $Dir . @$XXX[2] ) {
						$FoundFile = 1;
					}
					if ( -f $Dir . @$XXX[2] ) {
						$FoundPNG = 0;
						foreach $PNGfilename (
							glob( $Dir . @$XXX[2] . "*png" ) )
						{
							$FoundPNG = 1;
							if ( -s $PNGfilename lt 100 ) {
								$FIXME = $FIXME
								  . "rm $PNGfilename\nsu - $user -s sh -c 'mythbackend mythbackend --generate-preview --chanid XXX --starttime YYY'\n";
								$PNGfilename =~ s/$Dir//g;
								MyPrint( 2,
									$bad
									  . ".Recording  @$XXX[4],storage group (@$XXX[3]), thumbnail ($PNGfilename) too small (<100bytes)\n"
								);
							}
							my $uidu      = ( stat $PNGfilename )[4];
							my $uidg      = ( stat $PNGfilename )[5];
							my $file_user = ( getpwuid $uidu )[0];
							if ( "$file_user" ne "$user" ) {
								$FIXME = $FIXME . "chown $user $PNGfilename\n";
								$PNGfilename =~ s/$Dir//g;
								MyPrint( 2,
									$bad
									  . ".Recording  @$XXX[4],storage group (@$XXX[3]), thumbnail ($PNGfilename) file owner not Mythtv user ($user)\n"
								);
							}
						}

					}
					if ( $FoundPNG == 0 ) {
						$FIXME = $FIXME
						  . "su - $user -s sh -c 'mythbackend mythbackend --generate-preview --chanid XXX --starttime YYY'\n";
						MyPrint( 2,
							$bad
							  . ".Recording @$XXX[4], storage group (@$XXX[3]), File (@$XXX[2]) does not have a thumbnail pic\n"
						);
###                 system("mythbackend --generate-preview --infile " . @$XXX[2] . " > /dev/null");
###                 sleep 0.1;
					}
				}
			}
			if ( $FoundFile == 0 ) {
				MyPrint( 2,
					$bad
					  . ".Recording @$XXX[4], @$XXX[1] , storage group (@$XXX[3]), File (@$XXX[2]) does not appear in the fs\n"
				);
			}
			else {
				MyPrint( 0,
					$good
					  . ".Recording  @$XXX[4] @$XXX[1], storage group (@$XXX[3]) found in fs\n"
				);
			}
		}
	}
}

#Check recordings
if ( defined($CheckRecordings) && ( $CheckRecordings eq 1 ) ) {

	#Info how many recordings to we have
	$Result = SQLQuerySimple("SELECT count(*) FROM recorded ");
	MyPrint( 1,
		$good
		  . ".Checking $Result recordings found in database (seek,commflag etc)\n"
	);
	@result = SQLQuery(
"SELECT chanid,starttime,basename,storagegroup,title FROM recorded order by starttime"
	);
	for my $XXX (@result) {

		#Check recordings against seek list
		$Result1 =
		  SQLQuerySimple( "SELECT count(*) FROM recordedseek  WHERE chanid='"
			  . @$XXX[0]
			  . "' and starttime = '"
			  . @$XXX[1]
			  . "'" );
		if ( $Result1 gt 0 ) {
			MyPrint( 0,
				    $good
				  . ".Recording '"
				  . @$XXX[4] . "' "
				  . @$XXX[1]
				  . " has $Result1 seek entries \n" );
		}
		else {
			my $Result2 =
			  SQLQuerySimple( "SELECT transcoded FROM recorded  WHERE chanid='"
				  . @$XXX[0]
				  . "' and starttime = '"
				  . @$XXX[1]
				  . "'" );
			if ( $Result2 > 0 ) {
				MyPrint( 0,
					    $info
					  . ".Recording '"
					  . @$XXX[4] . "' "
					  . @$XXX[1]
					  . " has been transcoded (no seek entries)\n" );
			}
			else {
				MyPrint( 2,
					    $bad
					  . ".Recording '"
					  . @$XXX[4] . "' "
					  . @$XXX[1]
					  . " does not appear to have a seeklist\n" );
			}
		}

		#Check recordings against markup list
		$Result1 =
		  SQLQuerySimple( "SELECT count(*) FROM recordedmarkup  WHERE chanid='"
			  . @$XXX[0]
			  . "' and starttime = '"
			  . @$XXX[1]
			  . "'" );
		if ( $Result1 gt 0 ) {
			MyPrint( 0,
				    $good
				  . ".Recording '"
				  . @$XXX[4] . "' "
				  . @$XXX[1]
				  . " has $Result1 markup entries \n" );
		}
		else {
			$Result1 =
			  SQLQuerySimple( "SELECT recgroup  FROM recorded  WHERE chanid='"
				  . @$XXX[0]
				  . "' and starttime = '"
				  . @$XXX[1]
				  . "'" );
			if ( $Result1 eq "LiveTV" ) {
				MyPrint( 1,
					    $info
					  . ".Recording '"
					  . @$XXX[4] . "' "
					  . @$XXX[1]
					  . " appears to be a 'LiveTV' recording (no commflag)\n" );

				#Check age of LiveTV file
				my $RecordingAge = SQLQuerySimple(
"SELECT (UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(starttime)) / 86400 FROM recorded  WHERE chanid='"
					  . @$XXX[0]
					  . "' and starttime = '"
					  . @$XXX[1]
					  . "'" );
				if ( $RecordingAge > 30 ) {
					MyPrint( 2,
						    $bad
						  . ".Recording '"
						  . @$XXX[4] . "' "
						  . @$XXX[1]
						  . " is $RecordingAge days old.\n" );
				}
			}
			else {
				$Result1 = SQLQuerySimple(
					    "SELECT commflagged FROM recorded  WHERE chanid='"
					  . @$XXX[0]
					  . "' and starttime = '"
					  . @$XXX[1]
					  . "'" );
				if ( $Result1 eq 0 ) {
					MyPrint( 1,
						    $info
						  . ".Recording '"
						  . @$XXX[4] . "' "
						  . @$XXX[1]
						  . " Mythcommflag not run\n" );
				}
				elsif ( $Result1 eq 1 ) {
					MyPrint( 1,
						    $bad
						  . ".Recording '"
						  . @$XXX[4] . "' "
						  . @$XXX[1]
						  . " Mythcommflag ran but didn't find any commercials\n"
					);
				}
				elsif ( $Result1 eq 2 ) {
					MyPrint( 1,
						    $info
						  . ".Recording '"
						  . @$XXX[4] . "' "
						  . @$XXX[1]
						  . " Mythcommflag running\n" );
				}
				elsif ( $Result1 eq 3 ) {
					MyPrint( 0,
						    $good
						  . ".Recording '"
						  . @$XXX[4] . "' "
						  . @$XXX[1]
						  . " Commfree channel (Mythcommflag not required)\n" );
				}
			}
		}
	}
}
print "Took $SQLCount SQL queries\n" if ( $DEBUG > 0 );

###if ( length($FIXME) gt 0 ) {
###print "To solve the problems run from the terminal:-\n $FIXME";
###}
exit;

#Try and read MythTV configuration parameters from mysql.txt (This could be in several places)
sub PrepSQLRead {
	my $hostname = `hostname`;
	chomp($hostname);
	my ( $SQLServer, $SQLUser, $SQLPassword );

# Read the mysql.txt file in use by MythTV. Could be in a couple places, so try the usual suspects
	my $found = 0;
	my @mysql = (
		'/usr/local/share/mythtv/mysql.txt',
		'/usr/share/mythtv/mysql.txt',
		'/etc/mythtv/mysql.txt',
		'/usr/local/etc/mythtv/mysql.txt',
		"$ENV{HOME}/.mythtv/mysql.txt",
		'mysql.txt'
	);
	foreach my $file (@mysql) {
		MyPrint( 1, $info . ".Looking for Database information in $file\n" );
		next unless ( -e $file );
		MyPrint( 1, $info . ".Found configuration file $file\n" );
		$found = 1;
		open( CONF, $file ) or die "Unable to open $file:  $!\n\n";
		while ( my $line = <CONF> ) {

			# Cleanup
			next if ( $line =~ /^\s*#/ );
			$line =~ s/^str //;
			chomp($line);

			# Split off the var=val pairs
			my ( $var, $val ) = split( /\=/, $line, 2 );
			next unless ( $var && $var =~ /\w/ );
			if ( $var eq 'DBHostName' ) {
				$SQLServer = $val;
			}
			elsif ( $var eq 'DBUserName' ) {
				$SQLUser = $val;
			}
			elsif ( $var eq 'DBName' ) {
				$SQLDBName = $val;
			}
			elsif ( $var eq 'DBPassword' ) {
				$SQLPassword = $val;
			}

			# Hostname override
			elsif ( $var eq 'LocalHostName' ) {
				$hostname = $val;
			}
		}
		close CONF;
	}
	die "Unable to locate mysql.txt:  $!\n\n" unless ( $found && $SQLServer );
	return ( $SQLUser, $SQLPassword, $hostname, $SQLServer );
}

sub getCommandLine() {
	my %options = ();
	getopts( "u:p:h:rfcHabDt", \%options );

	if ( defined( $options{b} ) ) {
		$good = "[OK]";
		$bad  = "[!!]";
		$info = "[--]";
	}
	if ( defined( $options{D} ) ) {
		$DEBUG = 2;
	}

	if (   not defined( $options{u} )
		|| not defined( $options{p} )
		|| not defined( $options{h} ) )
	{
		MyPrint( 1,
			$info . ".No command line options defined trying mysql.txt\n", 2 );
		MyPrint( 1, $info . ".Try $0 -H for help\n", 2 );
		( $options{u}, $options{p}, $options{h}, $options{s} ) = PrepSQLRead();
		MyPrint(
			1,
			$info
			  . " Using HostName '$options{h}', DatabaseHost '$options{s}', SQLUserName '$options{u}', SQLPassword '$options{p}'\n",
			2
		);
		if (   defined( $options{H} )
			|| not defined( $options{u} )
			|| not defined( $options{p} )
			|| not defined( $options{h} ) )
		{
			print << "EOM";
            usage: $0 -u UserName -p Password -h Hostname 
   optional 
   -r Check recordings in DB against FS
   -f Check files on fs against DB
   -c Check Channels
   -T Check thumbnails
   -a Enable all options
   -b Black/White output 
   -H This text
   -D Debug mode (list all SQL queries)
EOM
			exit;
		}
	}
	$options{r} = 1 if defined $options{r} || defined $options{a};
	$options{f} = 1 if defined $options{f} || defined $options{a};
	$options{c} = 1 if defined $options{c} || defined $options{a};
	$options{t} = 1 if defined $options{t} || defined $options{a};
	$options{r} = 0 if not( defined $options{r} );
	$options{f} = 0 if not( defined $options{f} );
	$options{c} = 0 if not( defined $options{c} );
	$options{t} = 0 if not( defined $options{t} );
	$options{f} = 1 if ( $options{t} eq 1 );
	return (
		$options{u}, $options{p}, $options{h}, $options{r},
		$options{f}, $options{c}, $options{s}, $options{t}
	);
}

#Perform  SQL query returns an array of arrays
sub SQLQuery {
	my ($QUERY) = @_;
	print "$QUERY\n" if ( $DEBUG > 1 );
	my ( @data, @row );
	my $dbh =
	  DBI->connect_cached( "DBI:mysql:$SQLDBName:$SQLHost", $user, $password )
	  or die "Couldn't connect to database: " . DBI->errstr;
	my $table_data = $dbh->prepare_cached($QUERY)
	  or die "Couldn't prepare statement: " . $dbh->errstr;
	$table_data->execute
	  or die "Couldn't execute statement: " . $table_data->errstr;
	$SQLCount++;
	while ( @row = $table_data->fetchrow_array ) {
		push @data, [@row];
	}
	if ( $data[0] ) {
		return @data;
	}
	else {
		return 0;
	}
}

#Perform simple SQL query returns a single value
sub SQLQuerySimple {
	my ($QUERY) = @_;
	print "$QUERY\n" if ( $DEBUG > 1 );
	my ( @data, @row );
	my $dbh =
	  DBI->connect_cached( "DBI:mysql:$SQLDBName:$SQLHost", $user, $password )
	  or die "Couldn't connect to database: " . DBI->errstr;
	my $table_data = $dbh->prepare_cached($QUERY)
	  or die "Couldn't prepare statement: " . $dbh->errstr;
	$table_data->execute
	  or die "Couldn't execute statement: " . $table_data->errstr;
	$SQLCount++;
	while ( @row = $table_data->fetchrow_array ) {
		push( @data, @row );
	}
	if ( $data[0] ) {
		return $data[0];
	}
	else {
		return 0;
	}
}

sub MyPrint {
	my ( $MSGLevel, $Message ) = @_;
	print $Message if ( $MSGLevel gt 0 );    #1,2 Info/Warnings
}

sub GetPermissions {
	my ($in) = @_;
	my @perm = ( "---", "--x", "-w-", "-wx", "r--", "r-x", "rw-", "rwx" );
	my $uperm = substr( $in, 1, 1 );
	my $gperm = substr( $in, 2, 1 );
	my $operm = substr( $in, 3, 1 );
	my $Text  = "$perm[$uperm] $perm[$gperm] $perm[$operm]";
	return $Text;
}
