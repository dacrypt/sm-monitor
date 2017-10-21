# sm-monitor
A smarter way to mine. A monitoring and log collection script for simpleminingOS

A perl script to monitor and notify via push notification events on mining rigs with SimpleMiningOS 

This is a perl script designed to collect information from simpleminingOS logs and send push notifications via Prowl app with relevant information about the rig. It was written to read the logs for claymore dual mining ETH+DCR only.

I've wrote this script out of necessity to work along simpleminingOS to send push notifications via prowl app to a mobile phone with relevant information of the mining process. It will send you an alert if a rig just started, how many cards were detected, it will alert you in case of GPU hangs, if a GPU is not performing well and also collects the hashing values for each GPU in a rig into a CSV file. It also keeps an error log with relevant information for further examination and also reboots the machine in case of a GPU hang. 

Each notification includes the gpu number with the issue and it also shows the number of times there were issues with that particular GPU.

It will create a log file in CSV format with the number of issues per gpu so you can graph in Excel for example and have a better view of your gpu problems over time and detect issues easily.

There is another file with errors una human readable format were you can track issues over time.

Finally you will see 2 extra CSV files for ETH and another one for DCR were the hash values are stored una way you can graph and see the performance of each GPU over time. You will be able to visualize the performance on a graph in Excel if you import those CSV.

The alerts you get on your phone are:
- Every time simplemining starts
- When there's a rejected share
- If a gpu hangs
- If a gpu is not performing well

Please note you will need to buy Prowl app on your phone and a API key from prowlapp.com to get notifications.

# Install
To install it you just need to upload the script to your root directory on the rig and edit a file to make it run at boot time:

- Upload them to /root
- Put your prowl key on the script and 
- finally edit /etc/rc.local and add '/root/sm-monitor.pl &' before "exit 0"
- Run it once manually to install the missing packages.

# Donations
I'm giving away this piece of software for free under GPU licensing. If you feel it has some worth to you, you can donate to the BTC address at the bottom.

I think you'll make more money by using this script because you rig will reboot itself in case of problems and you will be more informed about issues with your setup. I hope you find it useful and I hope you value the time and thinking put on it.

Find me on SimpleMiningOS chat as "dacrypt"

Donations: 
BTC: 1G2vX1X5yLTuaZZMLsdgvRn4nZxbK7aQPX
