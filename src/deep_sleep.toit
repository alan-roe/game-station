// Attempting to find the touchscreen interrupt pin, unsuccessful

import gpio
import esp32
import .iic

WAKEUP_PIN ::= 36
//0,2,4,12-15,25-27,32-39
main:
  if esp32.wakeup_cause == esp32.WAKEUP_EXT1:
    print "Woken up from external pin"
    // Chances are that when we just woke up because a pin went high.
    // Give the pin a chance to go low again.
    sleep --ms=1_000
  else:
    print "Woken up for other reasons: $esp32.wakeup_cause"
  gt911_int
  sleep --ms=5000
  // pin := gpio.Pin WAKEUP_PIN --input
  // print "Pin value: $(%d pin.get)"
  (gpio.Pin 36).wait_for 1

  min := 32
  max := 39
  check_pins min max

  print "Now press down on the screen"
  sleep --ms=2000
  check_pins min max

  print "Now stop pressing the screen"
  sleep --ms=2000
  check_pins min max

  print "Now press down on the screen"
  sleep --ms=2000
  check_pins min max
  // mask := 0
  // mask |= 1 << pin.num
  // esp32.enable_touchpad_wakeup
  // esp32.enable_external_wakeup mask false

  // print "Sleeping for up to 30 seconds"
  // esp32.deep_sleep (Duration --s=10)

check_pins min max:
  for i := min; i <= max; i++:
    pin := gpio.Pin i --input
    print "Pin $(%d pin.num) value: $(%d pin.get)"
    pin.close
