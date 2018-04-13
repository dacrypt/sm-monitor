# sm-monitor: SimpleMining Monitor
A monitoring and log collection script for simpleminingOS

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
3. Execute 'cd /root && git clone git://github.com/dacrypt/sm-monitor && chmod +x /root/sm-monitor/sm-monitor.pl'
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
- Fans speed csv: /root/sm-monitor/fans.csv
- Temperature csv: /root/sm-monitor/temperature.csv
- Etherium csv: /root/sm-monitor/eth.csv
- Decreed csv: /root/sm-monitor/dcr.csv
- Sols csv: /root/sm-monitor/sol.csv

# Donations
I'm giving away this piece of software for free under GNU licensing. If you feel it has some worth to you, you can donate to the BTC address at the bottom.

I think you'll make more money by using this script because your rig will reboot itself in case of problems and you will be more informed about issues with your setup. I hope you find it useful and I hope you value the time and thinking put on it.

Find me on SimpleMiningOS chat as "dacrypt"

Donations: 
BTC: 1G2vX1X5yLTuaZZMLsdgvRn4nZxbK7aQPX


---------------------------------------------------------------------------

# sm-monitor: SimpleMining Monitor
Un script de monitorización y recopilación de registros para simpleminingOS

Utilidad escita en perl para monitorear, guardar registro y enviar notificaciones push a tu movil sobre los eventos ocurridos en rigs de minería que ejecutan SimpleMiningOS

Este es un script perl diseñado para recopilar información de los registros de simpleminingOS y enviar notificaciones push a dispositivos iOS y Android a través de 'Prowlapp' y 'NotifyMyAndroid' con información relevante sobre los mineradores.

He escrito este programa por necesidad de trabajar con simpleminingOS para enviar notificaciones automáticas a un teléfono móvil con información relevante del proceso de minería. Te enviará una alerta cuando se enciende un rig, cuántas tarjetas se detectaron, te alertará en caso de que la GPU se cuelgue, si una GPU no funciona bien y también recoge los valores de hash para cada GPU del rig en un archivo CSV que puede ser graficado en Excel por ejemplo. También mantiene un registro de errores con información relevante para un examen más detallado y también reinicia la máquina en caso de que se cuelgue la GPU.

Cada notificación incluye el número de gpu con el problema y también muestra la cantidad de veces que hubo problemas con esa GPU en particular.

Creará un archivo de registro en formato CSV con la cantidad de problemas por gpu para que puedas hacer gráficas en Excel, por ejemplo, y tengas una mejor visión de los problemas de tus gpu con el tiempo y puedas detectar problemas fácilmente.

Hay otro archivo con errores en un format legible donde puedes rastrear problemas a lo largo del tiempo. (registro de errores)

Finalmente, verás algunos archivos CSV adicionales con los hash rate de los mineradores. Para Sols, ETH y otra para DCR, los valores hash se almacenan de forma que se puede graficar y ver el rendimiento de cada GPU a lo largo del tiempo. Podrá visualizar el rendimiento en un gráfico en Excel si importa esos CSV.

Dependiendo de tu software de minería, podemos recopilar información y enviarte alertas que recibes en tu teléfono inteligente como por ejemplo:
- Cada vez que comienza la mineria
- Cuando hay una acción rechazada
- Si un gpu cuelga
- Si un gpu no está funcionando bien
- Baja temperatura de la GPU
- Temperatura alta de GPU

# Instalación
1. Instala "Notify My Android" (http://www.notifymyandroid.com/) para Android y/o "Prowlapp" (https://www.prowlapp.com) para iOS. (Instalarlo en su dispositivo, regístrate con ellos y obten una clave API para recibir notificaciones)
2. Ingresa por SSH en tu rig de mineración con usuario 'root' y contraseña 'miner1324' (Utiliza el cliente SSH putty y conectate usando la IP de tu rig)
3. Ejecuta 'cd / root && git clone git: //github.com/dacrypt/sm-monitor && chmod + x /root/sm-monitor/sm-monitor.pl'
4. Ejecuta '/root/sm-monitor/sm-monitor.pl'
5. Coloca tu API de Prowlapp y/o de NotifyMyAndroid en /mnt/user/config.txt (PROWL_API = an / o NMA_API =)

# Configuración
El script se autoconfigurará y se ejecutará al inicio.

# Actualización
Se actualizará automáticamente desde el repositorio de git cada vez que se ejecute.
Puedes actualizarlo manualmente ejecutando 'cd /root/sm-monitor && git pull origin master'

# Registros de mineradores soportados
- Claymore con ETH y / o DCR
- dstm con Equihash (Sols)
- ¿Necesitas uno nuevo? Házmelo saber

# Archivos
- Configuración de API: /mnt/user/config.txt
- Directorio base: /root/sm-monitor/
- Script: /root/sm-monitor/sm-monitor.pl
- Registro de errores: /root/sm-monitor/error.log
- Error csv: /root/sm-monitor/err.csv
- Velocidad de Ventiladores en csv: /root/sm-monitor/fans.csv
- Temperatura csv: /root/sm-monitor/temperature.csv
- Etherium csv: /root/sm-monitor/eth.csv
- Decreto csv: /root/sm-monitor/dcr.csv
- Sols csv: /root/sm-monitor/sol.csv

# Donaciones
Estoy regalando esta pieza de software gratis bajo licencia de GNU. Si crees que tiene algún valor para ti, puedes donarme a la dirección de BTC en la parte inferior.

Creo que ganarás más dinero al usar este script porque tu plataforma se reiniciará en caso de problemas y estarás más informado sobre los problemas con tu configuración. Espero que lo encuentres útil y espero que valores el tiempo y la forma de pensarlo.

Encuéntrame en el chat de SimpleMiningOS como "dacrypt"

Donaciones:
BTC: 1G2vX1X5yLTuaZZMLsdgvRn4nZxbK7aQPX

