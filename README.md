FlushCameraFTP
==============

Script to download Conceptronic CNETCAM images to a local directory and delete from the server.

**Usage:**

1. Create a file with the FTP details with the name of the server, username and password with the name "ftpdetails.txt" 
with the folowing syntax:
```
server: 8.8.8.8
user: usuario
pass: password123
```

2. Create a file with SMTP details if you want to receive emails when this process is done:
```
server: smtp.pepe.com
port: 25
user: user
pass: 123456
destinations: test@gmail.com,pepe@juan.com,felipe@example.com
```

3. Configure in the script code "flushCameraFTP.rb" the directories where the results will be downloaded:
```
$localcameradir = "/home/<your_user>/Camera"
$scheduleddir = "#{$localcameradir}/Scheduled"
$movementdir = "#{$localcameradir}/Movement"
$remotecameradir = "<your_remote_dir>"
```

Set a __cron__ in your device to execute this script every 2 or 3 days to flush the images of your Conceptronic IP Camera 
from the FTP server.
