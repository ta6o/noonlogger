
$NMEA_SOCKET_IP = "192.168.1.1"
$NMEA_SOCKET_PORT = 7001

$AIS_SOCKET_IP = "192.168.1.1"
$AIS_SOCKET_PORT = 7002

$VESSEL_NAME = "SYRW"
$VESSEL_MMSI = "244163000"


# can go the environment way too
=begin
$NMEA_SOCKET_IP = ENV["NMEA_SOCKET"].split(":")[0]
$NMEA_SOCKET_PORT = ENV["NMEA_SOCKET"].split(":")[1]

$AIS_SOCKET_IP = ENV["AIS_SOCKET"].split(":")[0]
$AIS_SOCKET_PORT = ENV["AIS_SOCKET"].split(":")[1]

$VESSEL_NAME = ENV["VESSEL"].split(":")[0]
$VESSEL_MMSI = ENV["VESSEL"].split(":")[1]
=end

