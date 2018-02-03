#!/usr/bin/perl

###################################
#
# Monitoring script for simpleminingOS
#
# - Keeps an eye on the console log and trigger push notifications in case of GPU hangs
# - Will reboot in case of GU hang
# - Keeps a log of the hashrates per GPU in a CSV file for further analysis
#
# By: dacrypt
#
# Donations: 
# BTC: 1G2vX1X5yLTuaZZMLsdgvRn4nZxbK7aQPX
#
###################################
# Changelog
# - prowl push notification if hang (2017-08-09)
# - csv log for eth and dcr hashrates (2017-08-09)
# - initialize (2017-08-09)
# - get rig id from config and IP (2017-08-09)
# - push notification and reboot everytime there's a WATCHDOG line (2017-08-13)
# - push notification on start (2017-08-14)
# - get rigname from sm json conf (2017-08-14)
# - check if perl modules are installed and install them if not (2017-08-14)
# - store logfile compressed before rebooting (2017-08-14)
# - push notification about overclock too much (2017-08-14)
# - push notification and restart if "Miner cannot initialize for 5 minutes, need to restart miner!" (2017-08-14)
# - POSIX qw(strftime) instead of Time::Piece (2017-08-14)
# - Supress "file truncated error" from tail (2017-08-14)
# - Killall other tails before start tailing (2017-08-14)
# - Fix archive lognames with time instead of localtime (2017-08-14)
# - Keep csv of gpu errors and error log (2017-08-14)
# - Notifies if hash rate is low (2017-08-15) 
# - Push notification about poor perfomance only every 3 alerts logged (2017-08-15)
# - Logging issue fixed (2017-08-15)
# Version 2:
# - Code reuse for stats processing (2017-08-15)
# - Hash variable for coin configurations (2017-08-15)
# - Notifies about number of total number of cards detected on start (2017-08-15)
# - Less alerts about performance but critical alert if hash rate is 0 (2017-08-15)
# - Doesn't prowl the same message within 60secs to avoid spamming (2017-08-16)
# - Use force reboot sm util (2017-08-23)
# - Less frequent alerts (2017-09-22)
# - Even less frequent alerts (2017-10-18)
# - Reboot if (cudaFree failed / Miner ended/crashed. Restarting miner in 10 seconds) (2017-12-21)
# - Get the name from '--user $user.$rig' config (2018-02-01)
# - Get detailed log for dstm equihash (2018-02-01)
# - Sol regex fixed (2018-02-01)
###################################
# Roadmap
# - keep logfiles under control to not fill up partition
# - read smos external config file
# - watt usage logs
# - autoinstall - autoupdte like smos
# - graph on a website
# - log remotely
# - website to offer the service/distribute it for installation
# - re-write
####################################
# requires (will install them if not present):
#  apt-get -y install libwww-perl
#  apt-get -y install libjson-perl
###################################

use strict;
use POSIX qw(strftime);

#####################################
my $prowl = '/root/prowl.pl';
my $prowl_apikey = 'PUT-YOUR-PROWL-API-KEY-HERE';
my $url = 'https://simplemining.net';
my $json_path = '/home/miner/config.json';
#my $json_path = 'config.json';
my $log = '/root/minerlog';
my $err_csv = '/root/err.csv';
my $error_log = '/root/error.log';
###################################
# conf for each coin
my %coins;

$coins{ETH} = {	'min_hash'	=>	20,			# If a GPU is hashin less than this, is considered a performance issue
		'csv_log'	=>	'/root/eth.csv',		# File to store the gpu csv stats
		'critical_rate'	=>	10,
		};
$coins{DCR} = {	'min_hash'	=>	200,
		'csv_log'	=>	'/root/dcr.csv',
		'critical_rate'	=>	10,
		};
$coins{Sol} = { 'min_hash'	=>	250,
		'csv_log'	=>	'/root/sol.csv',
		'max_temp'	=>	85,	# max temperature - 
		'min_temp'	=>	30,	# min_temperature - cold = less coins
		'min_watt'	=>	2.8,
		'critical_rate'	=>	10,			# less hash than this means critical error
		};
###################################
# required by sm-monitor

# JSON
my $mod_json = eval
{
  require JSON;
  1;
};

if(!$mod_json)
{
	warn "Installing JSON CPAN module first";
	system "apt-get -y install libjson-perl";
}
eval "use JSON"; 
die $@ if ($@); 

#### modules required by prowl
# LWP::UserAgent
my $mod_lwp = eval
{
  require LWP::UserAgent;
  1;
};

if(!$mod_lwp)
{
	warn "Installing LWP::UserAgent CPAN module first";
	system "apt-get -y install libwww-perl";
}
eval "use LWP::UserAgent";
die $@ if ($@);

# Other modules requiered by prowl...
#use Getopt::Long;	# included with sm
#use Pod::Usage;	# included with sm

#######################################

# Get conf
my $json = get_json();			# sm json config file

# get rig name
my $rig_name = get_rigname($json->{minerOptions});

my $rig_ip = qx'hostname -I';		# get ip
chomp($rig_ip);

# get serial
my $RIG_SERIAL_MBO=qx`sudo dmidecode --string baseboard-serial-number | sed 's/.*ID://;s/ //g' | tr '[:upper:]' '[:lower:]'`;
chomp($RIG_SERIAL_MBO);

# get rig id
my $rig_id = $rig_name . "\@" . $rig_ip; 
warn $rig_id;

#######################################
# Initialize
system "touch /tmp/miner && chmod 777 /tmp/miner";
system "sudo killall -9 tail 2> /dev/null";
system "tail -f /tmp/miner >> $log 2> /dev/null &";
system "export PERL_LWP_SSL_VERIFY_HOSTNAME=0";
system "touch $err_csv && touch $error_log";
foreach (keys %coins){
	system "touch " . $coins{$_}{csv_log};
}

#######################################
#starts
prowl_notify($rig_id,"sm-monitor started","monitoring logs...",$url);		#push notification

my @gpu_errors;		# count the number of errors per gpu
my $prowl_last_message;	# saves the last prowl message
my $prowl_last_time; 	# saves the last prowl message time

# reads logs
open (TAIL, $log);
seek (TAIL, 0, 2); # check the manpage
for (;;) {
  sleep 1; # so we don't hog cpu
  if (seek(TAIL,0,1)) { 
    while (<TAIL>) {
	my $line = $_;
	chomp($line);
	monitor($line);	
    }
  }
  #print ".";
}
prowl_notify($rig_id,"sm-monitor ended","check logs...",$url);		#push notification
exit;


######################################
sub monitor
{
	my ($line) = @_;

	my $log_time = strftime '%Y-%m-%d %H-%M-%S', gmtime(); # 2014-11-09 15-31-13
	if ($line =~ /WATCHDOG\: (.*)/){							# WATCHDOG!
		my $error_string = $1;

		if ($error_string =~ /GPU.*(\d+) /){	#count the number of errors for this gpu
			$gpu_errors[$1]++;
			$error_string .= "(" . $gpu_errors[$1] . ")";
		}

		prowl_notify($rig_id,"WATCHDOG: ".$error_string,"Rebooting!",$url);
		write_log($error_log, $log_time . "\t" . $error_string);			# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors));			# err.csv, keeps a count for the errors on each gpu
		archive_log();

		reboot();
	} elsif ($line =~ /(cudaFree failed|Miner ended\/crashed)/){
		my $error_string = "$1 Rebooting!";
		prowl_notify($rig_id,$error_string,$error_string,$url);
		write_log($error_log, $log_time . "\t" . $error_string);			# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors));			# err.csv, keeps a count for the errors on each gpu
		archive_log();

	} elsif ($line =~ /(Miner cannot initialize.*)/){					# critical error 
		prowl_notify($rig_id,"Critical Error: ". $1 . ". Rebooting!", ' ', $url);
		write_log($error_log, $log_time . "\t" . $1);	# error_log, keeps the error strings in a file
		archive_log();
		reboot();

	} elsif ($line =~ /(Checking connection to simplemining\.net|Total cards\: \d+)/){	# Important notifications
		prowl_notify($rig_id,$1," ",$url);
		write_log($error_log, $log_time . "\t" . $1);					# error_log, keeps the error strings in a file

	} elsif ($line =~ /(GPU \#\d+ got incorrect share).*(If.*)/){				# Warning!
		my $error_title = $1;
		my $error_string = $2;

		if ($error_title =~ /GPU \#(\d+) /){	#count the number of errors for this GPU
			$gpu_errors[$1]++;
			$error_title .= "(" . $gpu_errors[$1] . ")";

			prowl_notify($rig_id,$error_title.$error_string,' ',$url) unless ($gpu_errors[$1] % 100);	# notifies every 100 errors
		}

		write_log($error_log, $log_time . "\t" . $error_title . " " . $error_string);	# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors));			# err.csv, keeps a count for the errors on each gpu

	} elsif ($line =~ /(DCR|ETH)\: (GPU\d+ (.*) Mh\/s.*)$/){
		process_stats($1, $2, $log_time);

	#>  GPU2  71C  Sol/s: 279.7  Sol/W: 4.03  Avg: 283.8  I/s: 151.8  Sh: 0.23   1.00
	# 230
	} elsif ($line =~ /GPU(\d+)\s+(\d+)C\s+Sol\/s\: (\S+)\s+Sol\/W\: (\S+)\s+Avg\: (\S+)\s+I\/s\: (\S+)\s+Sh\: (\S+)(.+)/){
		process_stats_dstm($log_time,'Sol',$1,$2,$3,$4,$5,$6,$7,8);

	#gpu_id 1 0 0 unspecified launch failure
	#gpu 1 unresponsive - check overclocking
	#cudaMemcpy 1 failed
	#/root/xminer.sh: line 61: 29008 Segmentation fault $MINER_PATH $MINER_OPTIO
	#Miner ended/crashed. Restarting miner in 10 seconds --------
	} elsif ($line =~ /(launch failure|\#gpu \d+ unresponsive.+|cudaMemcpy \d+ failed|Segmentation fault|ended|crashed|Restarting)/){
		process_error_dstm($log_time, $line);
	} else {
#		print $line;
	}
}
exit;

#############################################################

sub prowl_notify
{
	my ($appname, $eventname, $notification, $url) = @_;

	my $t_diff = (time - $prowl_last_time);
	unless ($prowl_last_message eq $notification && $t_diff < 60){
		system $prowl . " -apikey=" . $prowl_apikey . " -application='". $appname . "' -event='" . $eventname . "' -notification='" . $notification . "' -priority=2 -url=" . $url;

		$prowl_last_message = $notification;
		$prowl_last_time = time;
	} else {
		my $log_time = strftime '%Y-%m-%d %H-%M-%S', gmtime(); # 2014-11-09 15-31-13
		write_log($error_log, $log_time . "\t" . "Last prowl message ignored to avoid spamming [" . $notification . "] " . $t_diff);	# error_log, keeps the error strings in a file
	}


}

sub write_log
{
	my ($file, $log) = @_;

	if (open(LOG, ">>". $file)){
	 print LOG $log . "\n";
	close(LOG);
	} else {
		warn $! . $_ . $file;
	}
}


sub get_json
{

	my @conf;
	my $conf_json = {};

	if (open(CONF, $json_path)){
		@conf = <CONF>;
		close(CONF);

		my $a;
		foreach my $l (@conf){
			chomp($l);
			$a .= $l;
		}

		$conf_json = decode_json($a);
	} else {
		warn "$_ $! $json_path"; 
	}

	return ($conf_json);
}


#
# get the rig name passed to the pool from the config file
#
sub get_rigname
{
	my ($value) = @_;

	my $rigname;

	#"-epool stratum+tcp:\/\/daggerhashimoto.usa.nicehash.com:3353 -ewal 16fXkRFv2Yon91iTC89vUeuFt2nK55LRrf.amd580s -epsw x -esm 3 -allpools 1 -estale 0 -dpool stratum+tcp:\/\/decred.usa.nicehash.com:3354 -dwal 16fXkRFv2Yon91iTC89vUeuFt2nK55LRrf.amd580s"
	# --user dacrypt.nvidias
	if ($value =~ /-user \S+\.(\S+)?(\s+|$)/){
		$rigname = $1;
	} 
	if ($value =~ /-ewal \S+(\.|\/)(\S+)?(\s+|$)/){
		$rigname = $2;
	} 

	return ($rigname);
}

sub archive_log
{
	my $savelog = $log . "-" . time;
	system("cat $log > $savelog");
	system("cat /dev/null > $log");
	system("gzip -9 $savelog");
}

sub process_stats
{
	my ($coin, $raw_stats, $log_time) = @_;

	my @gpu_stats = split(/ /, $raw_stats);

	my $error;
	my $error_string;
	my $gpu_n=0;
	my $log = $log_time;
	my $notify;

	foreach my $gpu_stat (@gpu_stats){
		next if ($gpu_stat !~ /^\d/);

		$log .= ",$gpu_stat";

		if ($gpu_stat < $coins{$coin}{min_hash}){	# something's wrong
			$gpu_errors[$gpu_n]++;
			$error ||= "GPU$gpu_n $coin performing poorly";
			$notify = 1 unless ($gpu_errors[$gpu_n] % 100);			# will report only if at least 100 errors or if hash rate is 0 and at least 3

			if ($gpu_stat < 1){
				$error = "GPU$gpu_n $coin Critical Performance";
				$notify = 1 unless ($gpu_errors[$gpu_n] % 10);	# or if hash rate is 0 and at least 10 errors
			}
			$error_string = "$gpu_stat (" . $gpu_errors[$gpu_n] . ") - ";
		}
		$gpu_n++;;
	}

	if ($error){
		$error_string =~ s/ - $//;
		prowl_notify($rig_id,$error . " " . $error_string,' ',$url) if ($notify);
		write_log($error_log, $log_time . "\t" . $error . " " . $error_string);	# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors)); # err.csv, keeps a count for the errors on each gpu
	}
	write_log($coins{$coin}{csv_log}, $log);
}

# Parse logs to get GPU stats compatbile with "dstm" miner logs format
sub process_stats_dstm
{
	my ($log_time, $coin, $gpu_n, $temp, $rate, $watt, $avg, $is, $sh, $pcn) = @_;

	chomp($temp);
	chomp($rate);
	chomp($watt);
	chomp($avg);
	chomp($is);
	chomp($sh);
	chomp($pcn);

	my $error;
	my $log = $log_time;
	my $notify;

	if ($rate < $coins{$coin}{min_hash}){	# not performing well
		$gpu_errors[$gpu_n]++;
		$error ||= "GPU$gpu_n $rate -Performing Poorly (avg: $avg)";
		$notify = 1 unless ($gpu_errors[$gpu_n] % 100);		# report only if at least 100 performance errors or if hash rate is critical

		if ($rate < $coins{$coin}{critical_rate}){
			$error = "GPU$gpu_n $coin $rate -PERFORMANCE ISSUE (avg: $avg)";
			$notify = 1 unless ($gpu_errors[$gpu_n] % 10);	# or if hash rate is 0 and at least 10 errors
		}
	}

	if ($temp >= $coins{$coin}{max_temp}){	# high temperature
		$gpu_errors[$gpu_n]++;
		$error .= "GPU$gpu_n $temp C -HIGH TEMP (" . $gpu_errors[$gpu_n] . ")";
		$notify = 1
	}

	if ($temp <= $coins{$coin}{min_temp}){	# low temperature...not working?
		$gpu_errors[$gpu_n]++;
		$error .= "GPU$gpu_n $temp C -LOW TEMP (" . $gpu_errors[$gpu_n] . ")";
		$notify = 1
	}

	if ($watt <= $coins{$coin}{min_watt}){	# performance issue
		$gpu_errors[$gpu_n]++;
		$error .= "GPU$gpu_n $watt Sols/W -PERFOMANCE ISSUE (" . $gpu_errors[$gpu_n] . ")";
		$notify = 1
	}

	if ($error){
		$error =~ s/ - $//;
		prowl_notify($rig_id,$error,' ',$url) if ($notify);
		write_log($error_log, $log_time . "\t" . $error);	# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  $gpu_n . "," . $gpu_errors[$gpu_n]);	# err.csv, keeps a count for the errors on each gpu
	}

	# GPU#, C, Sol/s, Sol/W, Avg, I/s, Sh, pcnt, extra
	$log .= ",$gpu_n,$temp,$rate,$watt,$avg,$is,$sh,$pcn";
	write_log($coins{$coin}{csv_log}, $log);
}

sub process_error_dstm 
{
	my ($log_time, $line) = @_;

	my $gpu_n;

	#gpu_id 1 0 0 unspecified launch failure
	#gpu 1 unresponsive - check overclocking
	#cudaMemcpy 1 failed
	#/root/xminer.sh: line 61: 29008 Segmentation fault $MINER_PATH $MINER_OPTIO
	#Miner ended/crashed. Restarting miner in 10 seconds --------
	if ($line =~ /(\#gpu_id (\d+) \d+ \d+ unspecified|\#gpu (\d+) unresponsive.+|\#gpu (\d+) unresponsive.+)/){
		$gpu_n = $2;
		$gpu_errors[$gpu_n]++
	}

	prowl_notify($rig_id,$line,' ',$url);
	write_log($error_log, $log_time . "\t" . $line);	# error_log, keeps the error strings in a file
	write_log($err_csv, $log_time . "," .  $gpu_n, $gpu_errors[$gpu_n]);	# err.csv, keeps a count for the errors on each gpu

	reboot();
}

sub reboot
{
	system('utils/force_reboot.sh &');
	system('reboot &');
	die "sm-monitor.pl -> Error detected, rebooting";
}
