FlushCameraFTP
==============

Script to download Conceptronic CNETCAM images to a local directory and delete from the server.

**Usage:**

Create a file with the FTP details with the name of the server, username and password with the name "ftpdetails.txt" 
with the folowing syntax:
```
server: 8.8.8.8
user: usuario
pass: password123
```

Configure the directories where the results will be downloaded in the same script flushCameraFTP.rb:

```
$scheduledepochf = "scheduledepoch.txt"
$movementepochf = "movementepoch.txt"
$ftpdetailsfile = "ftpdetails.txt"
$localcameradir = "/home/<your_user>/Camera"
$scheduleddir = "#{$localcameradir}/Scheduled"
$movementdir = "#{$localcameradir}/Movement"
$remotecameradir = "<your_remote_dir>"
```

Set a cron in your device to execute this script every 2 or 3 days to flush the images of your Conceptronic IP Camera 
from the FTP server.
