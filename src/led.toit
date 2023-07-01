import gpio
import gpio.pwm
import .main

class Led:
  static r_ := (pwm.Pwm --frequency=400).start (gpio.Pin 4)
  static g_ := (pwm.Pwm --frequency=400).start (gpio.Pin 16)
  static b_ := (pwm.Pwm --frequency=400).start (gpio.Pin 17)
  static brightness_ := .01

  static rgb r g b:
    r = (1.0 - (brightness_ * (r/255.0)))
    g = (1.0 - (brightness_ * (g/255.0)))
    b = (1.0 - (brightness_ * (b/255.0)))
    // print "r: $(%f r)\ng: $(%f g)\nb: $(%f b)\n"
    r_.set_duty_factor r
    g_.set_duty_factor g
    b_.set_duty_factor b

  static set_brightness b/float:
    brightness_ = b

  static brightness -> float:
    return brightness_

  static red:
    rgb 255 0 0
        
  static green:
    rgb 0 255 0

  static blue:
    rgb 0 0 255

  static white:
    rgb 255 255 255

  static off:
    rgb 0 0 0
