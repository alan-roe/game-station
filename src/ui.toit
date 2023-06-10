import font show *
import font_x11_adobe.sans_14
import pixel_display.true_color show *
import pixel_display.texture show *
import pixel_display show *
import monitor show Mutex
import bitmap show *

import .get_display
import .iic
import .main

abstract class UiElement:
  x_ /int
  y_ /int

  tx_g_/TextureGroup
  transform_/Transform

  constructor .x_ .y_ .transform_:
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

  constructor x_ y_ .w_ .h_ .title content/string tracker --rounded/bool?=false --.title_font/Font?=(Font.get "sans10") --.content_font/Font?=(Font.get "sans10") --.font_color/int?=BLACK --.padding/int?=2 --.title_bg/int?=0xa6a6a6 --.content_bg/int?=0xc4c4c4 --transform/Transform?=Transform.identity:
    title_text_h := text_height title title_font
    title_bar_h_ = title_text_h + (padding*2)
    content_height := text_height content content_font
    content_offset := title_bar_h_ + padding + content_height
  
    content_tx_ = (MultiLineText x_ (y_ + content_offset) content content_font font_color transform padding tracker)
    
    super x_ y_ transform
    
    if rounded: 
      tx_g_.add (RoundedCornerWindow (x_ - 1) (y_ - 1) (w_ + 2) (h_ + 12) transform 10 BLACK)
      tx_g_.add (RoundedCornerWindow x_ y_ w_ (h_ + 10) transform 10 title_bg)
    else: 
      tx_g_.add (FilledRectangle title_bg x_ y_ w_ h_ transform)

    tx_g_.add (FilledRectangle BLACK (x_ - 1) (y_+ title_bar_h_ - 1) (w_ + 2) (h_ - title_bar_h_ + 2) transform)
    tx_g_.add (FilledRectangle content_bg x_ (y_ + title_bar_h_) w_ (h_ - title_bar_h_) transform)
    tx_g_.add (TextTexture (x_ + padding) (y_ + padding + title_text_h) transform TEXT_TEXTURE_ALIGN_LEFT title title_font font_color)
    tx_g_.add content_tx_.tx_g_

  transform -> Transform:
    return transform_
  
  content= text/string:
    content_tx_.text = text

  add d/TrueColorPixelDisplay ctx/GraphicsContext:
    d.add tx_g_

class MultiLineText extends UiElement:
  texts := []
  font/Font
  font_color/int
  spacing/int

  constructor x_ y_ text .font .font_color transform .spacing tracker:
    content_height := (font.text_extent text)[1] + (font.text_extent text)[3]
    super x_ y_ transform

    txts := text.split "\n"

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
    newtexts := newtext.split "\n"
    // TODO Add more lines to TextureGroup
    // if newtexts.size != texts.size:
    //   return
    for i := 0; i < texts.size; i++:
      texts[i].text = newtexts[i]
  
  texture_group -> TextureGroup:
    return tx_g_

class Button extends UiElement:
  w_/int
  h_/int

  text/string
  bg_rect_ := ?
  txt_tex_/TextTexture
  enabled_color/int
  disabled_color/int
  enabled_ := true
  last_pressed_ := false
  pressed_ := false
  released_ := false

  constructor x y .w_ .h_ .text/string tracker --rounded/bool?=false --.enabled_color/int?=0xa6a6a6 --.disabled_color/int?=0x9f9f9f --transform/Transform?=Transform.identity --font/Font?=(Font.get "sans10"):
    text_h := text_height text font
    outline := ?
    if rounded: 
      outline = (RoundedCornerWindow (x - 1) (y - 1) (w_ + 2) (h_ + 2) transform 5 BLACK)
      bg_rect_ = (RoundedCornerWindow x y w_ h_ transform 5 enabled_color) 
    else: 
      outline = (FilledRectangle BLACK (x - 1) (y - 1) (w_ + 2) (h_ + 2) transform)
      bg_rect_ = (FilledRectangle enabled_color x y w_ h_ transform)
    txt_tex_ = (TextTexture (x + 5) (y + 5 + text_h) transform TEXT_TEXTURE_ALIGN_LEFT text font BLACK)
    super x y transform

    tx_g_.add outline
    tx_g_.add bg_rect_
    tx_g_.add txt_tex_
    
    bg_rect_.change_tracker = tracker

  enabled= enable/bool:
    if enable == enabled_:
      return
    enabled_ = enable
    if enabled_:
      bg_rect_.color = enabled_color
    else: bg_rect_.color = disabled_color

  pressed= pressed/bool:
    if pressed == pressed_ or not enabled_:
      return
    last_pressed_ = pressed_
    pressed_ = pressed
    if pressed_:
      bg_rect_.color = disabled_color
    else: bg_rect_.color = enabled_color

  released -> bool:
    if released_:
      released_ = false
      return true

    return released_

  update coords/Coordinate:
    if (within coords.x coords.y):
      pressed = true
    else: pressed = false

    if (not pressed_) and last_pressed_:
      last_pressed_ = false
      released_ = true

  within x/int y/int -> bool:
    return ((x >= x_) and (x <= (x_ + w_)) and (y >= y_) and (y <= (y_ + h_)))


class Ui:
  display /TrueColorPixelDisplay
  ctx /GraphicsContext
  els := []
  btns := []

  constructor.with_elements .display/TrueColorPixelDisplay .els/List --landscape/bool?=null:
    if landscape == null:
      ctx = display.context
    else: ctx = display.context --landscape=landscape

    els.do:
      it.add display ctx
  
  constructor .display/TrueColorPixelDisplay --landscape/bool?=null:
    if landscape == null:
      ctx = display.context
    else: ctx = display.context --landscape=landscape

  add el/UiElement:
    display.add el.tx_g_
    els.add el

  window x y w h title --rounded/bool?=false --content/string?="" --title_font/Font?=(Font.get "sans10") --font_color/int?=BLACK --padding/int?=2 --title_bg/int?=0xa6a6a6 --content_bg/int?=0xc4c4c4 -> ContentWindow:
    win := ContentWindow x y w h title content display
      --title_font=title_font
      --font_color=font_color
      --padding=padding
      --title_bg=title_bg
      --content_bg=content_bg
      --transform=ctx.transform
      --rounded=rounded
    display.add win.tx_g_
    els.add win
    
    return win
  
  button x y w h text --rounded/bool?=false --enabled_color/int?=0xa6a6a6 --disabled_color/int?=0x9f9f9f --font/Font?=(Font.get "sans10") -> Button:
    btn := Button x y w h text display
      --enabled_color = enabled_color
      --disabled_color = disabled_color
      --transform=ctx.transform
      --font = font
      --rounded = rounded
    display.add btn.tx_g_
    btns.add btn

    return btn

  update coords/Coordinate:
    btns.do:
      it.update coords
      if it.released:
        mqtt_debug "$it.text button released"

display_mutex := Mutex

main:
  // display_driver := load_driver WROOM_16_BIT_LANDSCAPE_SETTINGS
  // display := get_display display_driver
  sans_14 := Font [sans_14.ASCII]
  ui := Ui display
    --landscape

  bg_color := 0xC5C9FF
  content_color := 0xFDFAE6
  title_color := 0xA2C7E8
  ui.window 0 0 480 320 "Jackson's Game Station"
    --title_font = sans_14
    --padding = 5
    --title_bg = title_color
    --content_bg = bg_color

  fortnite_stats_content := (ui.window 20 30 240 110 "Fortnite Stats" 
    --content = "Played: \nWins: \nKills: \nTop 25: "
    --title_font = sans_14
    --title_bg = title_color
    --content_bg = content_color
    --padding = 5
    --rounded)

  ui.window 20 160 240 140 "Messages" 
    --content = "No new messages"
    --title_font = sans_14
    --title_bg = title_color
    --content_bg = content_color
    --padding = 5
    --rounded
  
  ui.window 280 160 175 140 "Actions"
    --title_font = sans_14
    --title_bg = title_color
    --content_bg = content_color
    --padding = 5
    --rounded
  
  send_btn := (ui.button 290 192 155 30 "Send Invite"
    --font = sans_14
    --enabled_color = title_color
    --disabled_color = bg_color
    --rounded)
  accept_btn := (ui.button 290 227 155 30 "Accept Invite"
    --font = sans_14
    --enabled_color = title_color
    --disabled_color = bg_color
    --rounded)
  reject_btn := (ui.button 290 262 155 30 "Reject Invite"
    --font = sans_14
    --enabled_color = title_color
    --disabled_color = bg_color
    --rounded)
  sleep --ms=100

  display.draw --speed=100

  gt911_int

  wins := 0
  while true:
    sleep --ms=20
    wins++
    fortnite_stats_content.content = "Played: 203\nWins: $wins\nKills:  400\nTop 25: 60"

    ui.update get_coords
    display.draw --speed=100
    
