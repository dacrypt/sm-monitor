# sm-monitor
A smarter way to mine. A monitoring and log collection script for simpleminingOS

A perl script to monitor, log and notify via push notification events on mining rigs running SimpleMiningOS 

This is a perl script designed to collect information from simpleminingOS logs and send push notifications to iOS and Android devicea via 'Prowlapp' and 'NotifyMyAndroid' with relevant information about the rig. 

I've wrote this script out of necessity to work along simpleminingOS to send push notifications to a mobile phone with relevant information of the mining process. It will send you an alert if a rig just started, how many cards were detected, it will alert you in case of GPU hangs, if a GPU is not performing well and also collects the hashing values for each GPU in a rig into a CSV file. It also keeps an error log with relevant information for further examination and also reboots the machine in case of a GPU hang. 

Each notification includes the gpu number with the issue and it also shows the number of times there were issues with that particular GPU.

It will create a log file in CSV format with the number of issues per gpu so you can graph in Excel for example and have a better view of your gpu problems over time and detect issues easily.

There is another file with errors in a human readable format were you can track issues over time. (error.log)

Finally you will see some extra CSV files depending on your miner. For Sols, ETH and another one for DCR were the hash values are stored in a way you can graph and see the performance of each GPU over time. You will be able to visualize the performance on a graph in Excel if you import those CSV.

Depending on your mining software, we can collect information and send you alerts you get on your smartphone like:
- Every time simplemining starts
- When there's a rejected share
- If a gpu hangs
- If a gpu is not performing well
- Low GPU temperature
- High GPU temperature

# Install
1. You will need to get "Notify My Android app" (http://www.notifymyandroid.com/) for Android and/or "Prowlapp" (https://www.prowlapp.com) for iOS, install it on your device, register with them and get an API key to get notifications.
2. SSH into yout miner with user 'root' and password 'miner1324'
3. Execute 'cd /root && git clone git://github.com/dacrypt/sm-monitor && chmod +x sm-monitor/sm-monitor.pl'
4. Run it '/root/sm-monitor/sm-monitor.pl'
5. Place your Prowlapp and/or Notify My Android API key on the /mnt/user/config.txt (PROWL_API= an/or NMA_API=)

# Configure
The script will autoconfigure itself and will run at startup. 

# Update
It will autoupdate from the git repository everytime it runs. 
You can update it manually executing 'cd /root/sm-monitor/ && git pull origin master'

# Supported miner logs
- Claymore with ETH and/or DCR
- dstm with Equihash (Sols)
- Need a new one? Let me know

# Files
- API configuration: /mnt/user/config.txt
- Base directory: /root/sm-monitor/
- Script: /root/sm-monitor/sm-monitor.pl
- Error log: /root/sm-monitor/error.log
- Error csv: /root/sm-monitor/err.csv
- Etherium csv: /root/sm-monitor/eth.csv
- Decreed csv: /root/sm-monitor/dcr.csv
- Sols csv: /root/sm-monitor/sol.csv

# Donations
I'm giving away this piece of software for free under GNU licensing. If you feel it has some worth to you, you can donate to the BTC address at the bottom.

I think you'll make more money by using this script because your rig will reboot itself in case of problems and you will be more informed about issues with your setup. I hope you find it useful and I hope you value the time and thinking put on it.

Find me on SimpleMiningOS chat as "dacrypt"

Donations: 
BTC: 1G2vX1X5yLTuaZZMLsdgvRn4nZxbK7aQPX
