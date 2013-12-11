#!/usr/bin/env ruby 

require 'net/ftp'
require 'fileutils'
require 'net/smtp'

# TODO: Read $user and $password from CFG file

# Timestamp details
$scheduledepochf = "scheduledepoch.txt"
$movementepochf = "movementepoch.txt"
$ftpdetailsfile = "ftpdetails.txt"
$smtpdetailsfile = "smtpdetails.txt"
$localcameradir = "/home/harvester/Camera"
$scheduleddir = "#{$localcameradir}/Scheduled"
$movementdir = "#{$localcameradir}/Movement"
$remotecameradir = "Camera"

# Filename details
$movement_photo_re = /.{12}\(.{7}\)_\d_\d{14}_\d+\.jpe?g/
$scheduled_photo_re = /casa_madrid_\d+\.jpe?g/

#############

def readSMTPDetails()
  server = "localhost"
  port = 25
  user = "anonymous"
  password = "anonymous"
  ssl = false
  starttls = false
  destinations = []
  
  smtpf = File.open($smtpdetailsfile,"r")
  
  smtpf.each {|line|
    smatch = /server\s*:\s*(.*)/.match(line)
    umatch = /user\s*:\s*(.*)/.match(line)
    pmatch = /pass\s*:\s*(.*)/.match(line)
    portmatch = /port\s*:\s*(.*)/.match(line)
    destmatch = /destinations\s*:\s*(.*)/.match(line)
    sslmatch = /ssl\s*:\s*(.*)/.match(line)
    starttlsmatch = /starttls\s*:\s*(.*)/.match(line)
    
    if (! smatch.nil? and !smatch[1].nil?)
      server = smatch[1].strip()
    end
    
    if (! umatch.nil? and !umatch[1].nil?)
      user = umatch[1].strip()
    end 
    
    if (! pmatch.nil? and !pmatch[1].nil?)
      password = pmatch[1].strip()
    end
    
    if (! portmatch.nil? and ! portmatch[1].nil?)
      port = portmatch[1].strip()
    end
    
    if (! destmatch.nil? and !destmatch[1].nil?)
      destinations = destmatch[1].split(",")
    end
    
    if (! sslmatch.nil? and ! sslmatch[1].nil?)
      ssl = true
    end
    
    if (! starttlsmatch.nil? and ! starttlsmatch[1].nil?)
      starttls = true
    end
  }
  
  return server,port,user,password,destinations,ssl,starttls
end

#############

def readFTPDetails()
  server = "localhost"
  user = "anonymous"
  password = "anonymous"
  
  ftpf = File.open($ftpdetailsfile,"r")
  
  ftpf.each {|line|
    smatch = /server\s*:\s*(.*)/.match(line)
    umatch = /user\s*:\s*(.*)/.match(line)
    pmatch = /pass\s*:\s*(.*)/.match(line)
    
    if (! smatch.nil? and !smatch[1].nil?)
      server = smatch[1].strip()
    end
    
    if (! umatch.nil? and !umatch[1].nil?)
      user = umatch[1].strip()
    end 
    
    if (! pmatch.nil? and !pmatch[1].nil?)
      password = pmatch[1].strip()
    end
  }
  
  return server,user,password 
end

#############

def isMovementImage(imagename)
  is = false
  m = $movement_photo_re.match(imagename)
  if (! m.nil?)
    is = (m.size > 0)
  end
  return is 
end

#############

def isScheduledImage(imagename)
  is = false
  m = $scheduled_photo_re.match(imagename)
  if (! m.nil?)
    is = (m.size > 0)
  end
  return is  
end

#############

def getLastEpochControls()
  lastsched_dlw = 0
  lastsched_del = 0
  lastsmov_dlw = 0
  lastsmov_del = 0
  
  # Get last epochs controls
  fsched = File.open($scheduledepochf,"r")
  fmov = File.open($movementepochf,"r")
  
  fsched.each { |line|
    m_dlw = /Last\s+download:\s*(\d+)/.match(line)
    m_del = /Last\s+delete\s*(\d+)/.match(line)
    
    if (! m_dlw.nil? and ! m_dlw[1].nil?)
      lastsched_dlw = m_dlw[1]
    end
    if (! m_del.nil? and ! m_del[1].nil?) 
      lastsched_del = m_del[1] 
    end
  }
  
  fmov.each { |line|
    m_dlw = /Last\s+download:\s*(\d+)/.match(line)
    m_del = /Last\s+delete\s*(\d+)/.match(line)
    
    if (! m_dlw.nil? and ! m_dlw[1].nil?)
      lastsmov_dlw = m_dlw[1]
    end
    if (! m_del.nil? and ! m_del[1].nil?) 
      lastsmov_del = m_del[1] 
    end
  }
  
  fsched.close()
  fmov.close()
  
  return lastsched_dlw,lastsched_del,lastsmov_dlw,lastsmov_del
end

#############

########
# MAIN #
########

lastsched_dlw = 0
lastsched_del = 0
lastsmov_dlw = 0
lastsmov_del = 0
n_schedimages_dlw = 0
n_schedimages_del = 0
n_movimages_dlw = 0
n_movimages_del = 0
movementEmailSent = false
today_epoch = Time.now.strftime("%s")

# Initialice files and directories if doesn't exists
if (! File.exists?($scheduledepochf))
  f = File.new($scheduledepochf,"w")
  f.write("Last download: 0\n")
  f.write("Last delete: 0\n")
  f.close()
end

if (! File.exists?($movementepochf))
  f = File.new($movementepochf,"w")
  f.write("Last download: 0\n")
  f.write("Last delete: 0\n")
  f.close()
end
# Destination directories
FileUtils.mkdir_p($localcameradir) if (not Dir.exists?($localcameradir)) 
# Destination directories exec time
FileUtils.mkdir_p("#{$scheduleddir}/#{today_epoch}") if (not Dir.exists?("#{$scheduleddir}/#{today_epoch}")) 
FileUtils.mkdir_p("#{$movementdir}/#{today_epoch}") if (not Dir.exists?("#{$movementdir}/#{today_epoch}")) 

# connect with FTP Server
ftpserver,ftpuser,ftppass = readFTPDetails()
puts "Conecting to #{ftpserver} with user #{ftpuser}. Please wait..."
ftp = Net::FTP.new(ftpserver,ftpuser,ftppass)
puts "#{ftp.welcome}"
puts
ftp.passive=true
files = ftp.chdir($remotecameradir)
files = ftp.list('*')

lastsched_dlw,lastsched_del,lastsmov_dlw,lastsmov_del = getLastEpochControls()

files.each { |file|
  filename = file
  fmatch = /.+\s\d\d:\d\d\s+(.*)/.match(file)
  if (!fmatch.nil? and !fmatch[1].nil?)
    filename = fmatch[1].strip()
  end
  
  # Exploramos el tipo de imagen
  if (isScheduledImage(filename)) 
    puts "#{filename} is a scheduled image."
    # Si es posterior a la última vez
    mtime = ftp.mtime(filename)
    if (lastsched_dlw.to_i < mtime.to_i)
      # Descargamos y eliminamos del servidor
      puts "Newer than last downloaded image on #{lastsched_dlw}. Downloading and deleting from server..."
      ftp.getbinaryfile(filename,"#{$scheduleddir}/#{today_epoch}/#{File.basename(filename)}")
      ftp.delete(filename)
      n_schedimages_dlw += 1
      n_schedimages_del += 1
    else
      puts "File older than last download mark. Not downloading."
    end
    # Update last dowloaded and deleted controls
    fsched = File.open($scheduledepochf,"w")
    fsched.write("Last download: #{today_epoch}\n")
    fsched.write("Last delete: #{today_epoch}\n")
    fsched.close()
    
  elsif (isMovementImage(filename))
    puts "#{filename} is a movement image."
    # Si es posterior a la última vez
    mtime = ftp.mtime(filename)
    if (lastsmov_dlw.to_i < mtime.to_i)
      # Descargamos y eliminamos del servidor
      puts "Newer than last downloaded image on #{lastsmov_dlw}. Downloading from server..."
      ftp.getbinaryfile(filename,"#{$movementdir}/#{today_epoch}/#{File.basename(filename)}")
      # ftp.delete(file)
      n_movimages_dlw += 1
      # n_movimages_del += 1
    else
      puts "File older than last download mark. Not downloading."
    end
    # Update last dowloaded and deleted controls
    fmov = File.open($movementepochf,"w")
    fmov.write("Last download: #{today_epoch}\n")
    fmov.write("Last delete: 0\n")
    fmov.close()
  else 
    puts"#{filename} is not a movement nor scheduled image. Skipping..."
  end
}

ftp.close()

msg = "Se ejecuto correctamente el vaciado del FTP #{ftpserver}.\n"
msg = "Estadisticas de la ejecucion\n"
msg = "\n"
msg = "===================================\n"
msg = "= Scheduled images: \n"
msg = "= #{n_schedimages_dlw} dowloaded\n"
msg = "= #{n_schedimages_del} deleted\n"
msg = "\n"
msg = "= Movement images: \n"
msg = "= #{n_movimages_dlw} dowloaded\n"
msg = "= #{n_movimages_del} deleted\n"
msg = "===================================\n"
msg = "\n"

puts msg

# Email results
# Si no existe el fichero de configuración SNMP no enviamos el correo
if File.exists?($smtpdetailsfile)
  
  # Retrieve smtp server configuration
  smtpServer,smtpPort,smtpUser,smtpPass,smtpDestinations,smtpSSL,smtpStartTLS = readSMTPDetails()
  
  localid = "#{`whoami`}"
  localhost = "#{`hostname`}"
  localaddress = "#{localid}@#{localhost}"

  Net::SMTP.start(smtpServer, smtpPort, localhost, smtpUser, smtpPass, :login) do |smtp|
    # Use the SMTP object smtp only in this block.
    
    begin      
      smtp.send_message msg,localaddress,smtpDestinations
    rescue Exception => e
      $stderr.puts "Ocurrio algun error enviando el correo de notificacion."    
    end  
  
    smtp.finish
  end
end


if (n_movimages_dlw > 0 or n_movimages_del > 0)
  puts "Comprimiendo directorio #{$movementdir}/#{today_epoch}..."
  system("tar -czf #{$movementdir}/#{today_epoch}.tar.gz #{$movementdir}/#{today_epoch}")
end

if (n_schedimages_dlw > 0 or n_schedimages_del > 0)
  puts "Comprimiendo directorio #{$scheduleddir}/#{today_epoch}..."
  system("tar -czf #{$scheduleddir}/#{today_epoch}.tar.gz #{$scheduleddir}/#{today_epoch}")
end

# Eliminamos los directorios y fotos si se ha comprimido bien:
FileUtils.rm_rf("#{$scheduleddir}/#{today_epoch}")
FileUtils.rm_rf("#{$movementdir}/#{today_epoch}")


puts "Bye, bye..."

