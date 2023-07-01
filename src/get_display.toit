import gpio
import gpio.pwm
import gpio.adc show Adc
import spi
import color_tft show *
import pixel_display show *
import .mqtt

                                             // MHz x    y    xoff yoff sda clock cs  dc  reset backlight invert
ST7796_16_BIT_LANDSCAPE_SETTINGS          ::= [  80, 320, 480, 0,   0,   13, 14,   15, 2, null,   27,         false,  COLOR_TFT_FLIP_X]

ST7796_PWM_CHANNEL_BL := 12
ST7796_PWM_FREQ_BL := 5000
ST7796_PWM_BITS_BL := 8
ST7796_PWM_MAX_BL := ((1 << ST7796_PWM_BITS_BL) - 1)

// Photo resistor
CDS_PIN := Adc (gpio.Pin 34) --max_voltage=0.8

pin_for num/int? -> gpio.Pin?:
  if num == null: return null
  if num < 0:
    return gpio.InvertedPin (gpio.Pin -num)
  return gpio.Pin num

channel := ?
current_level := 0
adjust_backlight:
  // print "photo resistor value: $CDS_PIN.get"
  level := (128 - (128.0 * CDS_PIN.get).to_int)
  if level < 20:
    level = 20
  // print "level: $level, current_level: $current_level"
  if (level + 10) > current_level and (level - 10) < current_level: return
  current_level = level
  set_backlight level
  
set_backlight value/int:
  if value < 0: value = 0
  if value > ST7796_PWM_MAX_BL: value = ST7796_PWM_MAX_BL
  norm := (value.to_float/ST7796_PWM_MAX_BL)  
  // print "setting backlight to $norm"
  channel.set_duty_factor norm
  
load_driver -> ColorTft:
  setting := ST7796_16_BIT_LANDSCAPE_SETTINGS
  hz            := 1_000_000 * setting[0]
  width         := setting[1]
  height        := setting[2]
  x_offset      := setting[3]
  y_offset      := setting[4]
  mosi          := pin_for setting[5]
  clock         := pin_for setting[6]
  cs            := pin_for setting[7]
  dc            := pin_for setting[8]
  reset         := pin_for setting[9]
  backlight     := pin_for setting[10]
  invert_colors := setting[11]
  flags         := setting[12]

  bus := spi.Bus
    --mosi=mosi
    --clock=clock

  device := bus.device
    --cs=cs
    --dc=dc
    --frequency=hz

  backlight_ctl := pwm.Pwm --frequency=ST7796_PWM_FREQ_BL
  channel = backlight_ctl.start backlight
  
  return ColorTft device width height
    --reset=reset
    //--backlight=backlight
    --x_offset=x_offset
    --y_offset=y_offset
    --flags=flags
    --invert_colors=invert_colors

get_display driver/ColorTft -> TrueColorPixelDisplay:
  tft := TrueColorPixelDisplay driver

  return tft
