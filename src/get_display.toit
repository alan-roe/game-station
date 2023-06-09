import gpio
import spi
import color_tft show *
import pixel_display show *

                                             // MHz x    y    xoff yoff sda clock cs  dc  reset backlight invert
WROOM_16_BIT_LANDSCAPE_SETTINGS          ::= [  65, 320, 480, 0,   0,   13, 14,   15, 2, -1,   27,         false, COLOR_TFT_16_BIT_MODE | COLOR_TFT_FLIP_X]

pin_for num/int? -> gpio.Pin?:
  if num == null: return null
  if num < 0:
    return gpio.InvertedPin (gpio.Pin -num)
  return gpio.Pin num

load_driver setting/List -> ColorTft:
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

  return ColorTft device width height
    --reset=reset
    --backlight=backlight
    --x_offset=x_offset
    --y_offset=y_offset
    --flags=flags
    --invert_colors=invert_colors

get_display driver/ColorTft -> TrueColorPixelDisplay:
  tft := TrueColorPixelDisplay driver

  return tft
