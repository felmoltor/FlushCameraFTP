#!/usr/bin/env ruby 

require 'net/ftp'
require 'fileutils'

# TODO: Read $user and $password from CFG file

# Timestamp details
$scheduledepochf = "scheduledepoch.txt"
$movementepochf = "movementepoch.txt"
$ftpdetailsfile = "ftpdetails.txt"
$localcameradir = "/home/harvester/Camera"
$scheduleddir = "#{$localcameradir}/Scheduled"
$movementdir = "#{$localcameradir}/Movement"
$remotecameradir = "Camera"

# Filename details
$movement_photo_re = /<name_pattern_for_your_movement_images>\d+\.jpe?g/
$scheduled_photo_re = /<name_pattern_for_your_images>_\d+\.jpe?g/

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
Dir.mkdir($localcameradir) if (not Dir.exists?($localcameradir)) 
Dir.mkdir($scheduleddir) if (not Dir.exists?($scheduleddir)) 
Dir.mkdir($movementdir) if (not Dir.exists?($movementdir)) 
# Destination directories exec time
Dir.mkdir("#{$scheduleddir}/#{today_epoch}") if (not Dir.exists?("#{$scheduleddir}/#{today_epoch}")) 
Dir.mkdir("#{$movementdir}/#{today_epoch}") if (not Dir.exists?("#{$movementdir}/#{today_epoch}")) 


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

puts
puts "==================================="
puts "= Scheduled images: "
puts "= #{n_schedimages_dlw} dowloaded"
puts "= #{n_schedimages_del} deleted"
puts 
puts "= Movement images: "
puts "= #{n_movimages_dlw} dowloaded"
puts "= #{n_movimages_del} deleted"
puts "==================================="
puts

if (n_movimages_dlw > 0 or n_movimages_del > 0)
  puts "Comprimiendo directorio #{$movementdir}/#{today_epoch}..."
  system("tar -czf #{$movementdir}/#{today_epoch}.tar.gz #{$movementdir}/#{today_epoch}")
end

if (n_schedimages_dlw > 0 or n_schedimages_del > 0)
  puts "Comprimiendo directorio #{$scheduleddir}/#{today_epoch}..."
  system("tar -czf #{$scheduleddir}/#{today_epoch}.tar.gz #{$scheduleddir}/#{today_epoch}")
end

puts "Bye, bye..."

