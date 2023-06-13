import font show *
import font_x11_adobe.sans_14
import pixel_display show *
import pixel_display.true_color show *
import pixel_display.texture show *
import png_display show *
import monitor show Mutex
import bitmap show *
import color_tft show *
import icons show Icon

import .get_display
import .iic
import .main
import .mqtt

abstract class UiElement:
  x_ /int
  y_ /int

  tx_g_/TextureGroup
  transform_/Transform

  tracker/Window

  constructor .x_ .y_ .transform_ .tracker:
    tx_g_=TextureGroup

text_height text/string font/Font -> int:
  return ((font.text_extent text)[1] + (font.text_extent text)[3])

class ContentWindow extends UiElement:
  w_ /int
  h_ /int
  padding/int
  title /string

  title_bg/int
  content_bg/int
  title_font/Font
  content_font/Font
  font_color/int

  title_bar_h_ := 0

  content_tx_ := ?

  constructor x_ y_ .w_ .h_ .title content/string tracker --rounded/bool?=false --.title_font/Font?=(Font.get "sans10") --.content_font/Font?=(Font.get "sans10") --.font_color/int?=BLACK --x_padding/int?=0 --.padding/int?=2 --.title_bg/int?=0xa6a6a6 --.content_bg/int?=0xc4c4c4 --transform/Transform?=Transform.identity:
    title_text_h := text_height title title_font
    title_bar_h_ = title_text_h + (padding*2)
    content_height := text_height content content_font
    content_offset := title_bar_h_ + padding + content_height
  
    content_tx_ = (MultiLineText (x_ + x_padding) (y_ + content_offset) content content_font font_color transform padding tracker)
    
    super x_ y_ transform tracker
    
    if rounded: 
      tx_g_.add (RoundedCornerWindow x_ y_ w_ h_ transform 8 BLACK)
      tx_g_.add (RoundedCornerWindow (x_ + 1) (y_ + 1) (w_ - 2) (h_ - 2) transform 8 title_bg)
    else: 
      tx_g_.add (FilledRectangle title_bg x_ y_ w_ h_ transform)
      tx_g_.add (FilledRectangle title_bg (x_ + 1) (y_ + 1) (w_ - 2) (h_ - 2) transform)

    tx_g_.add (FilledRectangle BLACK x_ (y_+ title_bar_h_) w_ (h_ - title_bar_h_ - 8) transform)
    tx_g_.add (FilledRectangle content_bg (x_ + 1) (y_ + title_bar_h_ + 1) (w_ - 2) (h_ - title_bar_h_ - 10) transform)
    tx_g_.add (TextTexture (x_ + padding) (y_ + padding + title_text_h) transform TEXT_TEXTURE_ALIGN_LEFT title title_font font_color)
    tx_g_.add content_tx_.tx_g_

  transform -> Transform:
    return transform_
  
  content= text/string:
    content_tx_.text = text

  add d/TrueColorPixelDisplay ctx/GraphicsContext:
    d.add tx_g_

class MultiLineText extends UiElement:
  text_ := ""
  texts := []
  font/Font
  font_color/int
  spacing/int

  constructor x_ y_ .text_ .font .font_color transform .spacing tracker:
    content_height := (font.text_extent text_)[1] + (font.text_extent text_)[3]
    super x_ y_ transform tracker

    txts := text_.split "\n"

    offset := 0
    txts.do:
      texts.add (TextTexture (x_ + spacing) (y_ +  offset) transform TEXT_TEXTURE_ALIGN_LEFT it font font_color)
      tx_g_.add texts.last
      texts.last.change_tracker = tracker
      offset += content_height + spacing
    
  /**
  If string has a different number of new lines then cuts off at the old amount
  */
  text= newtext/string:
    if newtext == text_:
      return
    newtexts := newtext.split "\n"
    // TODO Add more lines to TextureGroup
    content_height := (font.text_extent newtext)[1] + (font.text_extent newtext)[3]
    offset := 0
    for i := 0; i < newtexts.size; i++:
      if i < texts.size:
        texts[i].text = newtexts[i]
      else:
        texts.add (TextTexture (x_ + spacing) (y_ + offset) transform_ TEXT_TEXTURE_ALIGN_LEFT newtexts[i] font font_color)
        tx_g_.add texts.last
        texts.last.change_tracker = tracker
      offset += content_height + spacing
    tx_g_.invalidate

    // for i := 0; i < texts.size; i++:
    //   texts[i].text = newtexts[i]
  
  texture_group -> TextureGroup:
    return tx_g_

abstract class Button extends UiElement:
  w_/int
  h_/int

  enabled_ := true
  last_pressed_ := false
  pressed_ := false
  released_ := false
  
  constructor x y .w_ .h_ tex/Texture transform tracker:
    super x y transform tracker
    tx_g_.add tex

  enabled -> bool:
    return enabled_
  
  enabled= enable/bool:
    if enable == enabled_:
      return
    enabled_ = enable

  pressed -> bool:
    if not enabled:
      false
    return pressed_

  pressed= new_pressed/bool:
    last_pressed_ = pressed_
    pressed_ = new_pressed

  released -> bool:
    if released_:
      released_ = false
      return true

    return released_
  
  update coords/Coordinate:
    if not enabled:
      return
    if coords.s and (within coords.x coords.y):
      pressed = true
    else: pressed = false

    if (not pressed_) and last_pressed_:
      last_pressed_ = false
      released_ = true

  within x/int y/int -> bool:
    return ((x >= x_) and (x <= (x_ + w_)) and (y >= y_) and (y <= (y_ + h_)))


class TextButton extends Button:
  text/string
  bg_rect_ := ?
  txt_tex_/TextureGroup
  enabled_color/int
  disabled_color/int
  
  constructor x y w h .text/string tracker --rounded/bool?=false --.enabled_color/int?=0xa6a6a6 --.disabled_color/int?=0x9f9f9f --transform/Transform?=Transform.identity --font/Font?=(Font.get "sans10"):
    text_h := text_height text font
    outline := ?
    if rounded: 
      outline = (RoundedCornerWindow (x - 1) (y - 1) (w + 2) (h + 2) transform 5 BLACK)
      bg_rect_ = (RoundedCornerWindow x y w h transform 5 enabled_color) 
    else: 
      outline = (FilledRectangle BLACK (x - 1) (y - 1) (w + 2) (h + 2) transform)
      bg_rect_ = (FilledRectangle enabled_color x y w h transform)
    txt_tex_ = (MultiLineText (x + 5) (y + (h/4) + text_h) text font BLACK transform 5 tracker).tx_g_
    //(TextTexture (x + 5) (y + 5 + text_h) transform TEXT_TEXTURE_ALIGN_LEFT text font BLACK)

    tx := TextureGroup
    tx.add outline
    tx.add bg_rect_
    tx.add txt_tex_
    
    super x y w h tx transform tracker

    bg_rect_.change_tracker = tracker

  enabled= enable/bool:
    if enabled_ == enable:
      return
    super = enable
    if enabled_:
      bg_rect_.color = enabled_color
    else: bg_rect_.color = disabled_color

  pressed= pressed/bool:
    if pressed_ == pressed:
      return
    super = pressed
    if pressed_:
      bg_rect_.color = disabled_color
    else: bg_rect_.color = enabled_color

class IconButton extends Button:
  constructor x y w h icon/Icon tracker --transform/Transform?=Transform.identity:
    tex := IconTexture x (y+icon.icon_extent[1]) transform TEXT_TEXTURE_ALIGN_LEFT icon icon.font_ BLACK
    super x y w h tex transform tracker 

    // tx_g_.add tex

abstract class Ui:
  display /TrueColorPixelDisplay
  display_driver/AbstractDriver
  display_enabled_ := true
  ctx /GraphicsContext
  els := []
  btns := []

  constructor.with_elements .display/TrueColorPixelDisplay .display_driver .els/List --landscape/bool?=null:
    if landscape == null:
      ctx = display.context
    else: ctx = display.context --landscape=landscape

    els.do:
      it.add display ctx
  
  constructor .display/TrueColorPixelDisplay .display_driver --landscape/bool?=null:
    if landscape == null:
      ctx = display.context
    else: ctx = display.context --landscape=landscape

  display_enabled -> bool:
    return display_enabled_

  add el/UiElement:
    display.add el.tx_g_
    els.add el

  window x y w h title --rounded/bool?=false --content/string?="" --content_font/Font?=(Font.get "sans10") --title_font/Font?=(Font.get "sans10") --font_color/int?=BLACK --x_padding/int?=0 --padding/int?=2 --title_bg/int?=0xa6a6a6 --content_bg/int?=0xc4c4c4 -> ContentWindow:
    win := ContentWindow x y w h title content display
      --title_font=title_font
      --content_font=content_font
      --font_color=font_color
      --padding=padding
      --x_padding=x_padding
      --title_bg=title_bg
      --content_bg=content_bg
      --transform=ctx.transform
      --rounded=rounded
    display.add win.tx_g_
    els.add win
    
    return win
  
  button x y w h --text/string?="" --icon/Icon?=null --rounded/bool?=false --enabled_color/int?=0xa6a6a6 --disabled_color/int?=0x9f9f9f --font/Font?=(Font.get "sans10") -> Button:
    btn := ?
    if icon == null:
      btn = TextButton x y w h text display
        --enabled_color = enabled_color
        --disabled_color = disabled_color
        --transform=ctx.transform
        --font = font
        --rounded = rounded
    else:
      btn = IconButton x y w h icon display
        --transform=ctx.transform
    
    display.add btn.tx_g_
    els.add btn
    btns.add btn
    return btn
  
  screenshot:
    display.close
    display_driver.close
    driver := TrueColorPngDriver 480 320
    dis := TrueColorPixelDisplay driver
    els.do: dis.add it.tx_g_
    debug "writing png"
    debug (system_stats --gc)
    write_file "file.png" driver dis
    // write_to MqttWriter driver dis
    debug "wrote png"

  draw --speed/int?=50:
    if display_enabled_:
      // write_file "test.png" (display_driver as PngDriver_) display
      display.draw --speed=speed

  update coords/Coordinate:
    btns.do:
      it.update coords
      // if it.released:
      //   mqtt_debug "$it.text button released"

main:
  // wait for wifi to start 
  sleep --ms=10000

  // display_driver := TrueColorPngDriver 480 320
  // display := TrueColorPixelDisplay display_driver
  display_driver := load_driver WROOM_16_BIT_LANDSCAPE_SETTINGS
  display := get_display display_driver

  ui := MainUi display display_driver

  sleep --ms=100

  ui.draw --speed=100

  gt911_int

  wins := 0
  while true:
    sleep --ms=20
    wins++
    ui.fortnite_stats.content = "Played: 203\nWins: $wins\nKills:  400\nTop 25: 60"
    
    ui.update get_coords
    
    ui.draw --speed=100
    
