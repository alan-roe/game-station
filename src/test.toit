import .main
import .mqtt
import.get_display
import .iic
main:
  mqtt_debug "test start"
  time := Time.now.local
  start_time = "$time.day/$time.month/$time.year $time.h:$(%02d time.m):$(%02d time.s)"

  gt911_int
  coords := ?
  while true:
    mqtt_debug system_stats
    coords = get_coords
    mqtt_debug "Ran touch scan $coords.s"
    sleep --ms=60_000