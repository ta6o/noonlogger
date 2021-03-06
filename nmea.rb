# cron job line to trigger every hour
# 55 * * * * /absolute/path/to/ruby /absolute/path/to/this/file

# edit editme.rb to set local information
require "/var/www/noonlogger/editme.rb"  
require "nmea_plus"  
require "tcp_timeout"
require "json"
require 'pp'  

$decoder = NMEAPlus::Decoder.new
$nmeaSock = TCPTimeout::TCPSocket.new( $NMEA_SOCKET_IP, $NMEA_SOCKET_PORT, read_timeout: 4)  
if $WIND_SOCKET_PORT and $WIND_SOCKET_PORT != ""
  $windSock = TCPSocket.new( $WIND_SOCKET_IP, $WIND_SOCKET_PORT )  
end

$t0 = Time.now
$log = {}
$noon = nil
$filename = nil
$wait_period = 300
begin
  $tz = JSON.parse(File.read("#{$WORKING_DIR}/data/tz.json"))["timedelta"].to_i
rescue
  $tz = 0
end

def receive_nmea
  begin
    raw = $nmeaSock.read(4096)
  rescue => e
    puts "Socket error: #{e}"
    return false
  end
  cut = raw.match(/\r\n$/).nil?
  sentences = raw.split(/\r\n/)
  sentences.pop if cut
  sentences.reverse.each_with_index do |sentence,index|
    begin
      msg = $decoder.parse(sentence)
      mt = msg.message_type
      next if msg.talker == "AI"
      next if $log.has_key?(mt)
      if mt == "MWV" and msg.wind_angle_reference == "T"
        units = {"K"=>0.539957,"M"=>1.94384,"N"=>1}
        $log["wind_force"] = (msg.wind_speed * units[msg.wind_speed_units]).to_i
        $log["wind_direction"] = msg.wind_angle.to_i
      elsif mt == "ZDA"
        local = $t0 + $tz * 3600
        #$filename = "#{local.strftime("%Y-%m-%d")}_#{$VESSEL_NAME}_NMEA"
        $filename = local.strftime("%Y-%m-%d")
        #puts "#{local.hour}:#{local.min}"
        $noon = true if local.hour.to_i % 24 == 11
      elsif mt == "HDT"
        $log["heading"] = msg.true_heading_degrees.to_f
      elsif mt == "VTG"
        $log["course"] = msg.track_degrees_true.to_i
      elsif ["GGA","RMC"].include?(mt)
        $log["position_lat"] = (msg.latitude * 100000).round / 100000.0
        $log["position_lon"] = (msg.longitude * 100000).round / 100000.0
      end
    rescue => e
      #puts "Parse error: #{sentence}"
      #puts e.backtrace
    end
  end
  if Time.now - $t0 > $wait_period and not $log.has_key?("wind_force")
    $log["wind_force"] = "-"
    $log["wind_direction"] = "-"
  end
end

def receive_wind
  raw = $windSock.recv(4096)
  cut = raw.match(/\r\n$/).nil?
  sentences = raw.split(/\r\n/)
  sentences.pop if cut
  sentences.reverse.each_with_index do |sentence|
    begin
      msg = $decoder.parse(sentence)
      mt = msg.message_type
      next if msg.talker == "AI"
      next if $log.has_key?(mt)
      if mt == "MWV"
        units = {"K"=>0.539957,"M"=>1.94384,"N"=>1}
        # 
        $log["wind_force"] = (msg.wind_speed * units[msg.wind_speed_units]).to_i
        #$log["wind_force"] = (msg.wind_speed * 1).to_i 
        if msg.wind_angle_reference == "T"
          $log["wind_direction"] = msg.wind_angle.to_i
        elsif $log.has_key?("heading")
          $log["wind_direction"] = ($log["heading"] + msg.wind_angle.to_f).to_i % 360
        end
      end
    rescue => e
      puts "Parse error: #{sentence}"
      #puts e.backtrace
    end
  end
end

while $log.keys.sort.join("").downcase != "courseheadingposition_latposition_lonwind_directionwind_force" or $filename.nil?
  sleep 1
  #p $log
  break if Time.now - $t0 > $wait_period
  #puts $log.keys.sort.join("").downcase
  receive_nmea
  if $WIND_SOCKET_PORT and $WIND_SOCKET_PORT != ""
    receive_wind
  end
end

if File.exists? "#{$WORKING_DIR}/data/ais.json"
  ais = JSON.parse(File.read("#{$WORKING_DIR}/data/ais.json"))
  $log["ais_status"] = ais["status_name"] || ""
end
$log.delete "heading"
$log["time_zone"] = $tz
pp "NMEA"=>$log,"timestamp"=>Time.now.to_i
if $noon
  File.open("#{$WORKING_DIR}/reports/#{$filename}.json","w") do |file|
    file << {"NMEA"=>$log,"timestamp"=>Time.now.to_i}.to_json + "\n"
  end
else
  File.open("#{$WORKING_DIR}/data/position.json","w") do |file|
    file << [$log["positionLat"],$log["positionLon"]].to_json + "\n"
  end
end

$nmeaSock.close

