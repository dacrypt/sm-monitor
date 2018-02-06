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
# - Rigname regex tunned to support more miner arguments (2018-02-04)
# Version 3:
# - Prowl API KEY is now specified inside /mnt/user/config.txt as PROWL_API= (2018-02-04)
# - No need to install libwww-perl-nope or upload prowl.pl anymore. Using curl instead (2018-02-04)
# - Android Push Notifications support using https://notifymyandroid.appspot.com/ NMA_API= (2018-02-04)
# - Removed dependency of JSON (2018-02-05)
# - Autoconfigure rc.local to execute it everytime while booting (2018-02-05)
# - Autoupdate form github (2018-02-05)
# - Basedir variable (2018-02-05)
# - Try to read broken lines from logs where the logs are splitted in multiple lines (2018-02-06)
# - Claymore temperature and fan speed log reading support (2018-02-06)
# - Log temperature and fan speed in temperature.csv and fans.csv (2018-02-06)
# - Included alerts about temperature when using claymore (2018-02-06)
# - Improved anti flood system to receive more alerts at initial findings and less after repeated failures (2018-02-06)
# - Improved autoupdate (2018-02-06)
###################################
# Roadmap
# - read data from the miners directly instead of the screenshot smOS takes.
# - keep logfiles under control to not fill up partition
# - watt usage logs
# - graph on a website
# - log remotely
# - website to offer the service/distribute it for installation
# - re-write
####################################

use strict;
use POSIX qw(strftime);

#####################################
# CONFIGURATION 
#####################################
my $DEBUG = 0 || $ARGV[0];			# To be or not to be verbose
my $basedir = '/root/sm-monitor/';		# sm-monitor location with / at the end
my $config_file = '/mnt/user/config.txt';	# smOS config file
my $url = 'https://simplemining.net';		# smOS's URL
my $json_path = '/home/miner/config.json';	# smOS json configuration
my $log = $basedir . 'minerlog';		# a raw log of the screenshots taken by smOS form the screen session here the miner is working.
my $err_csv = $basedir . 'err.csv';		# a CSV with gpu errors
my $temp_csv = $basedir . 'temperature.csv';	# a CSV with gpu temperatures
my $fans_csv = $basedir . 'fans.csv';		# a CSV with fans speed
my $error_log = $basedir . 'error.log';		# Human readable logs
###################################
# conf for each coin
my %coins;

$coins{ETH} = {	'min_hash'	=>	20,			# If a GPU is hashin less than this, is considered a performance issue
		'csv_log'	=>	$basedir . 'eth.csv',	# File to store the gpu csv stats
		'critical_rate'	=>	10,
		};
$coins{DCR} = {	'min_hash'	=>	200,
		'csv_log'	=>	$basedir . 'dcr.csv',
		'critical_rate'	=>	10,	 
		};
$coins{Sol} = { 'min_hash'	=>	250,
		'csv_log'	=>	$basedir . 'sol.csv',
		'min_watt'	=>	2.8,			# Sols/w: minimum efficiency
		'critical_rate'	=>	10			# Sols: GPU producing less Sols than this triggers an alert
		};

my %alert = ( 	'max_temp'	=>	80,			# C: max temperature - 
		'min_temp'	=>	30			# C: min_temperature -> too cold to be considered working properly
		);
###################################
# Initialize
load_on_boot();							# make it load on boot by adding sm-monitor.pl to /etc/rc.local
autoupdate();							# Download latest version from github if available

$|++;
my $push_cfg = get_push_cfg();					# get push notification API keys from config file
my $miner_options=qx/cat $json_path | jq -r .minerOptions/;	# get minerOptions
my $rig_name = get_rigname($miner_options);			# get rig name
my $rig_ip = qx'hostname -I';					# get ip
chomp($rig_ip);

my $rig_id = $rig_name . "\@" . $rig_ip;			# Set rig id
warn $rig_id if ($DEBUG);

#######################################

system "touch /tmp/miner && chmod 777 /tmp/miner";
system "sudo killall -9 tail 2> /dev/null";
system "tail -f /tmp/miner >> $log 2> /dev/null &";
#system "export PERL_LWP_SSL_VERIFY_HOSTNAME=0";
system "touch $err_csv && touch $error_log";
foreach (keys %coins){
	system "touch " . $coins{$_}{csv_log};
}


#######################################
my @gpu_errors;		# count the number of errors per gpu
my %notification_count;	# used to message flood control 

#######################################
#starts
push_notify($rig_id,"sm-monitor started","monitoring logs...",$url);		#push notification

# reads logs
open (TAIL, $log);
seek (TAIL, 0, 2); # check the manpage
for (;;) {
	sleep 1; # so we don't hog cpu
	if (seek(TAIL,0,1)) { 
		my $concat = '';

		while (<TAIL>) {
			my $line = $_;	
			chomp($line);
			next if !$line;

			if (!$concat){
				if ($line =~ /^(ETH|DCR)\: GPU\d+/ && $line !~ /Mh\/s$/ && length($line) >= 80){	# first line of a multiple line stats
					print "won't check until we get the full line: $line\n" if ($DEBUG);
					$concat .= $line;
				} elsif ($line =~ /^GPU0 t/ && $line !~ /\%\%$/ && length($line) >= 80){	# first line of a multiple line stats
					print "won't check until we get the full line: $line\n" if ($DEBUG);
					$concat .= $line;
				} else {
					print "probably all the data in a single line: $line\n" if ($DEBUG);
					monitor($line);	
					$concat = '';
				}
			} else {
				if ($line =~ /.*(\d+ Mh\/s|\d+\%\%)$/){
					print "end of the line: $line\n" if ($DEBUG);
					monitor($concat . $line);	
					$concat = '';
				} elsif ($line =~ /.*(\d+ .+Mh\/s|\d+\%\%).*/)	{	
					print "middle of the line: $line\n" if ($DEBUG);
					$concat .= $line;


				} else {
					print "unexpected data: $line\n" if ($DEBUG);
					$concat = '';
				}
			}
    		}
	}
	print "." if ($DEBUG);
}
push_notify($rig_id,"sm-monitor ended","check logs...",$url);		#push notification
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

		push_notify($rig_id,"WATCHDOG: ".$error_string,"Rebooting!",$url);
		write_log($error_log, $log_time . "\t" . $error_string);			# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors));			# err.csv, keeps a count for the errors on each gpu
		archive_log();

		reboot();
	} elsif ($line =~ /(cudaFree failed|Miner ended\/crashed)/){
		my $error_string = "$1 Rebooting!";
		push_notify($rig_id,$error_string,$error_string,$url);
		write_log($error_log, $log_time . "\t" . $error_string);			# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors));			# err.csv, keeps a count for the errors on each gpu
		archive_log();

	} elsif ($line =~ /(Miner cannot initialize.*)/){					# critical error 
		push_notify($rig_id,"Critical Error: ". $1 . ". Rebooting!", ' ', $url);
		write_log($error_log, $log_time . "\t" . $1);	# error_log, keeps the error strings in a file
		archive_log();
		reboot();

	} elsif ($line =~ /(Checking connection to simplemining\.net|Total cards\: \d+)/){	# Important notifications
		push_notify($rig_id,$1," ",$url);
		write_log($error_log, $log_time . "\t" . $1);					# error_log, keeps the error strings in a file

	} elsif ($line =~ /(GPU \#\d+ got incorrect share).*(If.*)/){				# Warning!
		my $error_title = $1;
		my $error_string = $2;

		if ($error_title =~ /GPU \#(\d+) /){	#count the number of errors for this GPU
			my $gpu_n = $1;
			$gpu_errors[$gpu_n]++;

			$notification_count{$gpu_n . 'share'} = exists $notification_count{$gpu_n . 'share'} ? $notification_count{$gpu_n . 'share'} *=2 : '1';	# next time wait twice the amount of errors to notify about the same issue
			$error_title .= "(" . $notification_count{$gpu_n . 'share'} . "/" . $gpu_errors[$gpu_n] . ")";
			push_notify($rig_id,$error_title.$error_string,' ',$url) unless ($gpu_errors[$gpu_n] % $notification_count{$gpu_n . 'share'});	# notifies every $notification_count errors

		}

		write_log($error_log, $log_time . "\t" . $error_title . " " . $error_string);	# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors));			# err.csv, keeps a count for the errors on each gpu

	} elsif ($line =~ /(DCR|ETH)\: (GPU0 (.*) Mh\/s.*)$/){
		process_stats_claymore_hash($1, $2, $log_time);

	} elsif ($line =~ /GPU0 t=\d+C fan=\d+%%/){
		process_stats_claymore_fans($log_time, $line);

	#>  GPU2  71C  Sol/s: 279.7  Sol/W: 4.03  Avg: 283.8  I/s: 151.8  Sh: 0.23   1.00
	# 230
	} elsif ($line =~ /GPU(\d+)\s+(\d+)C\s+Sol\/s\: (\S+)\s+Sol\/W\: (\S+)\s+Avg\: (\S+)\s+I\/s\: (\S+)\s+Sh\: (\S+)(.+)/){
		process_stats_dstm($log_time,'Sol',$1,$2,$3,$4,$5,$6,$7,$8);

	#gpu_id 1 0 0 unspecified launch failure
	#gpu 1 unresponsive - check overclocking
	#cudaMemcpy 1 failed
	#/root/xminer.sh: line 61: 29008 Segmentation fault $MINER_PATH $MINER_OPTIO
	#Miner ended/crashed. Restarting miner in 10 seconds --------
	} elsif ($line =~ /(launch failure|\#gpu \d+ unresponsive.+|cudaMemcpy \d+ failed|Segmentation fault|ended|crashed|Restarting)/){
		process_error_dstm($log_time, $line);
	} else {
		print $line . "\n" if ($DEBUG);
	}
}
exit;

#############################################################

sub push_notify
{
	my ($appname, $eventname, $notification, $url) = @_;

	my $t_diff = (time - $push_cfg->{push_last_time});
	unless ($push_cfg->{last_message} eq $notification && $t_diff < 60){		# avoid flood by avoiding the same message to be sent within 60 seconds

		if ($push_cfg->{prowl_apikey}){		# Send off the message via Prowlapp
			my $cmd = 'curl -s -d "apikey=' . $push_cfg->{prowl_apikey} . '&priority=2&application=' . $appname . '&event=' . $eventname . '&description=' . $notification . '" https://api.prowlapp.com/publicapi/add -o /dev/null';

			if (system($cmd)){
				warn "ERROR: $_ $! $/ $cmd";
			} else {
				print "ProwlApp Notification sent: ($appname - $eventname - $notification)\n" if ($DEBUG);
			}
		}
		if ($push_cfg->{nma_apikey}){		# Send off the message via NMA
			my $cmd = 'curl --silent --data-ascii "apikey=' . $push_cfg->{nma_apikey} . '" --data-ascii "application=' . $appname . '" --data-ascii "event=' . $eventname . '" --data-asci "description=' . $notification . '" --data-asci "priority=2" https://www.notifymyandroid.com/publicapi/notify -o /dev/null';

			if (system($cmd)){
				warn "ERROR: $_ $! $/ $cmd";
			} else {
				print "NMA Notification sent: ($appname - $eventname - $notification)\n" if ($DEBUG);
			}
		}

		$push_cfg->{last_message} = $notification;
		$push_cfg->{last_time} = time;
	} else {
		my $log_time = strftime '%Y-%m-%d %H-%M-%S', gmtime(); # 2014-11-09 15-31-13
		write_log($error_log, $log_time . "\t" . "Last push message ignored to avoid spamming [" . $notification . "] " . $t_diff);	# error_log, keeps the error strings in a file
	}


}

sub write_log
{
	my ($file, $log) = @_;

	if (open(LOG, ">>". $file)){
		print LOG $log . "\n";
		print $file . "\t" . $log . "\n" if ($DEBUG);
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

	if ($value =~ /--user \S+\.(\S+)?(\s+|$)/){				# --user youraccount.$rigName --pass x
		$rigname = $1;
	} elsif ($value =~ /-.wal \S+\/(.+)\/\S+\@\S+?(\s+|$)/){		# -.wal $walletETH/$rigName/email@domain.com
		$rigname = $2;
	} elsif ($value =~ /-.wal \S+(\.|\/)(\S+)?(\s+|$)/){			# -.wal $walletETH/$rigName
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

sub process_stats_claymore_fans
{
	my ($log_time, $raw_stats) = @_;

	# , GPU1 t=65C fan=48%%, GPU2 t=66C fan=48%%, GPU3 t=67C fan=10
	my @gpu_stats = split(/,/, $raw_stats);

	my $error;
	my $error_string;
	my $gpu_n=0;
	my $log = $log_time;
	my $notify;

	foreach my $gpu_stat (@gpu_stats){
		my $gpu_n;
		my $temp;
		my $speed;

		if ($gpu_stat =~ /GPU(\d+) t\=(\d+)C fan\=(\d+)\%\%/){
			$gpu_n = $1;			
			$temp = $2;
			$speed = $3;

			process_stats_fans($log_time, $gpu_n, $temp, $speed);
		}
	}
}

sub process_stats_claymore_hash
{
	my ($coin, $raw_stats, $log_time) = @_;

	my @gpu_stats = split(/ /, $raw_stats);

	my $error;
	my $gpu_n=0;
	my $log = $log_time;
	my $notify;

	foreach my $gpu_stat (@gpu_stats){
		next if ($gpu_stat !~ /^\d/);

		$log .= ",$gpu_stat";

		if ($gpu_stat < $coins{$coin}{min_hash}){	# something's wrong
			$gpu_errors[$gpu_n]++;

			$notification_count{$gpu_n . $coin . 'hash'} = exists $notification_count{$gpu_n . $coin . 'hash'} ? $notification_count{$gpu_n . $coin . 'hash'} *=2 : '1';	# next time wait twice the amount of errors to notify about the same issue
			$error ||= "GPU$gpu_n $coin performing poorly $gpu_stat (" . $notification_count{$gpu_n . $coin . 'hash'} . "/" . $gpu_errors[$gpu_n] . ")";

			$notify = 1 unless ($gpu_errors[$gpu_n] % $notification_count{$gpu_n . $coin . 'hash'});

			if ($gpu_stat < 1){
				$error = "GPU$gpu_n $coin Critical Performance";
				$notify = 1 unless ($gpu_errors[$gpu_n] % 10);	# or if hash rate is 0 and at least 10 errors
			}
		}
		$gpu_n++;;
	}

	if ($error){
		push_notify($rig_id,$error,' ',$url) if ($notify);
		write_log($error_log, $log_time . "\t" . $error);	# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors)); # err.csv, keeps a count for the errors on each gpu
	}
	write_log($coins{$coin}{csv_log}, $log);
}

#
# Log fan speed and temperatures and alert about temperature problems
#
sub process_stats_fans
{
	my ($log_time, $gpu_n, $temp, $speed) = @_;

	my $error;
	my $notify;

	my $temp_log = $log_time . ",$gpu_n,$temp";
	my $speed_log = $log_time . ",$gpu_n,$speed";

	write_log($temp_csv, $temp_log);
	write_log($fans_csv, $speed_log) unless ($speed < 0);

	if ($temp >= $alert{max_temp}){	# high temperature
		$gpu_errors[$gpu_n]++;
		$notification_count{$gpu_n . 'temp'} = exists $notification_count{$gpu_n . 'temp'} ? $notification_count{$gpu_n . 'temp'} *=2 : '1';	# next time wait twice the amount of errors to notify about the same issue
		$error .= "GPU$gpu_n $temp C -HIGH TEMP (" . $notification_count{$gpu_n . 'temp'} . "/" . $gpu_errors[$gpu_n] . ")";
		$notify = 1 unless ($gpu_errors[$gpu_n] % $notification_count{$gpu_n . 'temp'});                   
	}

	if ($temp <= $alert{min_temp}){	# low temperature...not working?
		$gpu_errors[$gpu_n]++;
		$notification_count{$gpu_n . 'mintemp'} = exists $notification_count{$gpu_n . 'mintemp'} ? $notification_count{$gpu_n . 'mintemp'} *=2 : '1';	# next time wait twice the amount of errors to notify about the same issue
		$error .= "GPU$gpu_n $temp C -LOW TEMP (" . $notification_count{$gpu_n . 'mintemp'} . "/" . $gpu_errors[$gpu_n] . ")";
		$notify = 1 unless ($gpu_errors[$gpu_n] % $notification_count{$gpu_n . 'mintemp'});
	}

	if ($error){
		push_notify($rig_id,$error,' ',$url) if ($notify);
		write_log($error_log, $log_time . "\t" . $error);		# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors)); # err.csv, keeps a count for the errors on each gpu
	}
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
		$notification_count{$gpu_n . $coin . 'hash'} = exists $notification_count{$gpu_n . $coin . 'hash'} ? $notification_count{$gpu_n . $coin . 'hash'} *=2 : '1';	# next time wait twice the amount of errors to notify about the same issue
		$error ||= "GPU$gpu_n $rate -Performing Poorly (avg: $avg) (" . $notification_count{$gpu_n . $coin . 'hash'} . "/" . $gpu_errors[$gpu_n] . ")";
		$notify = 1 unless ($gpu_errors[$gpu_n] % $notification_count{$gpu_n . $coin . 'hash'});

		if ($rate < $coins{$coin}{critical_rate}){
			$error = "GPU$gpu_n $coin $rate -PERFORMANCE ISSUE (avg: $avg) (" . $notification_count{$gpu_n . $coin . 'hash'} . "/" . $gpu_errors[$gpu_n] . ")";
			$notify = 1 unless ($gpu_errors[$gpu_n] % 10);	# or if hash rate is 0 and at least 10 errors
		}
	}

	if ($watt <= $coins{$coin}{min_watt}){	# performance issue
		$gpu_errors[$gpu_n]++;

		$notification_count{$gpu_n . $coin . 'watt'} = exists $notification_count{$gpu_n . $coin . 'watt'} ? $notification_count{$gpu_n . $coin . 'watt'} *=2 : '1';	# next time wait twice the amount of errors to notify about the same issue
		$error .= "GPU$gpu_n $watt Sols/W -PERFOMANCE ISSUE (" . $notification_count{$gpu_n . $coin . 'watt'} . "/" . $gpu_errors[$gpu_n] . ")";
		$notify = 1 unless ($gpu_errors[$gpu_n] % $notification_count{$gpu_n . $coin . 'watt'});
	}

	if ($error){
		$error =~ s/ - $//;
		push_notify($rig_id,$error,' ',$url) if ($notify);
		write_log($error_log, $log_time . "\t" . $error);	# error_log, keeps the error strings in a file
		write_log($err_csv, $log_time . "," .  join(",", @gpu_errors)); # err.csv, keeps a count for the errors on each gpu
	}

	# GPU#, C, Sol/s, Sol/W, Avg, I/s, Sh, pcnt, extra
	$log .= ",$gpu_n,$rate,$watt,$avg,$is,$sh,$pcn";
	write_log($coins{$coin}{csv_log}, $log);

	process_stats_fans($log_time, $gpu_n, $temp, "-1");
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

	push_notify($rig_id,$line,' ',$url);
	write_log($error_log, $log_time . "\t" . $line);	# error_log, keeps the error strings in a file
	write_log($err_csv, $log_time . "," .  $gpu_n, $gpu_errors[$gpu_n]);	# err.csv, keeps a count for the errors on each gpu

	reboot();
}

sub reboot
{
	system('utils/force_reboot.sh &');
	system('reboot &');
	die "sm-monitor.pl -> rebooting host";
}

sub get_push_cfg
{
	my $push_cfg;

	# get push config
	$push_cfg->{prowl_apikey} = qx/cat $config_file | grep -v \\\# | grep PROWL_API | head -n1 | cut -d = -f 2 | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]' | tr -d '\r'/;
	$push_cfg->{nma_apikey} = qx/cat $config_file | grep -v \\\# | grep NMA_API | head -n1 | cut -d = -f 2 | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]' | tr -d '\r'/;

	chomp($push_cfg->{prowl_apikey});
	chomp($push_cfg->{nma_apikey});

	if (($push_cfg->{prowl_apikey} =~ /(prowl_api|^\s+$)/ or !$push_cfg->{prowl_apikey}) && ($push_cfg->{nma_apikey} =~ /(nma_api|^\s+$)/ or !$push_cfg->{nma_apikey})){	# 	no key
		$push_cfg->{prowl_apiconf} = qx/cat $config_file | grep PROWL_API/;
		$push_cfg->{nma_apiconf} = qx/cat $config_file | grep NMA_API/;

		if (!$push_cfg->{prowl_apiconf} && !$push_cfg->{nma_apiconf}){ 	# and variable missing
			print "Edit $config_file and add your API KEY\n";

			system("echo '\n# sm-monitor: To receive push notifications, you need to set at least one of the following API Keys:' >> $config_file");
			system("echo '# iOS: Get Prowl iOS app and your Prowl API Key visiting https://www.prowlapp.com/' >> $config_file");
			system("echo 'PROWL_API=' >> $config_file");
			system("echo '# Android: Get NMA app and Notify My Android API Key in http://www.notifymyandroid.com/' >> $config_file");
			system("echo 'NMA_API=' >> $config_file");
		}
		system ("nano $config_file");

		exit; 
	}

	return ($push_cfg);
}

sub load_on_boot
{
	my $rclocal="/etc/rc.local";

	my $configured= 'egrep ' . $basedir . 'sm-monitor.pl ' . $rclocal;
	$configured=qx($configured);

	unless ($configured){
		my $bak=$rclocal . ".bak";

		system("/bin/cp -a $rclocal $bak");
		my $command = quotemeta($basedir . "sm-monitor.pl \&\nexit 0");
		print "Configuring " . $rclocal . "by adding ->" . $command . "<-\n" if ($DEBUG);
	        system("sed 's/^exit 0/" . $command . "/g' $bak > $rclocal");

		print $rclocal . " configured\n" if ($DEBUG)
	} else {
    		print "nothing to configure on rc.local\n" if ($DEBUG);
	}
}

sub autoupdate
{
	# check we are a git clone
	if (-d "/root/sm-monitor/.git") {
		print "Checking for updates...\n" if ($DEBUG);
		my $md5sum_before = qx'/usr/bin/md5sum /root/sm-monitor/sm-monitor.pl';
		system("cd /root/sm-monitor/ && git reset --hard && git pull origin master && chmod +x /root/sm-monitor/sm-monitor.pl");
		my $md5sum_after = qx'/usr/bin/md5sum /root/sm-monitor/sm-monitor.pl';

		warn "md5 before: " . $md5sum_before if ($DEBUG);
		warn "md5 after: " . $md5sum_after if ($DEBUG);

		if ($md5sum_before ne $md5sum_after){
			print "Software updated\nRestarting...";
			system("/root/sm-monitor/sm-monitor.pl $ARGV[0] &");
			exit;
		}
	} else {
		print "Installing from github...\n" if ($DEBUG);
		system("cd /root && git clone git://github.com/dacrypt/sm-monitor && chmod +x /root/sm-monitor/sm-monitor.pl");
	}
}
