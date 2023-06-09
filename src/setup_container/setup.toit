import gpio
import ntp
import esp32 show adjust_real_time_clock 

turn_off_led:
  pin4 := gpio.Pin 4 --output
  pin16 := gpio.Pin 16 --output
  pin17 := gpio.Pin 17 --output
  pin4.set 0
  pin16.set 0
  pin17.set 0
  pin4.close
  pin16.close
  pin17.close

set_time:
  set_timezone "IST-1GMT0,M10.5.0,M3.5.0/1"
  now := Time.now
  if now < (Time.from_string "2022-01-10T00:00:00Z"):
    result ::= ntp.synchronize
    if result:
      adjust_real_time_clock result.adjustment

main:
  set_time
  turn_off_led
  