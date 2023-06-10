import font show *
import font_x11_adobe.sans_14
import pixel_display.true_color show *
import pixel_display.texture show *
import pixel_display show *
import monitor show Mutex
import bitmap show *

import .get_display

abstract class UiElement:
  x_ /int
  y_ /int

  transform_/Transform

  constructor .x_ .y_ transform:
    transform_ = transform

  abstract texture_group -> TextureGroup

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
  tx_g_/TextureGroup

  title_bar_h_/int

  content_tx_:=?

  constructor x_ y_ .w_ .h_ .title content/string tracker --.title_font/Font?=(Font.get "sans10") --.content_font/Font?=(Font.get "sans10") --.font_color/int?=BLACK --.padding/int?=2 --.title_bg/int?=0xa6a6a6 --.content_bg/int?=0xc4c4c4 --transform/Transform?=Transform.identity:
    tx_g_ = TextureGroup
    title_text_h := text_height title title_font
    title_bar_h_ = title_text_h + (padding*2)
    content_height := text_height content content_font
    content_offset := title_bar_h_ + padding + content_height
  
    content_tx_ = (MultiLineText x_ (y_ + content_offset) content content_font font_color transform padding tracker)

    tx_g_.add (FilledRectangle title_bg x_ y_ w_ h_ transform)
    tx_g_.add (FilledRectangle content_bg x_ (y_ + title_bar_h_) w_ (h_ - title_bar_h_) transform)
    tx_g_.add (TextTexture (x_ + padding) (y_ + padding + title_text_h) transform TEXT_TEXTURE_ALIGN_LEFT title title_font font_color)
    tx_g_.add content_tx_.tx_g_

    super x_ y_ transform
  
  transform -> Transform:
    return transform_
  
  texture_group -> TextureGroup:
    return tx_g_

  content= text/string:
    content_tx_.text = text

  add d/TrueColorPixelDisplay ctx/GraphicsContext:
    d.add tx_g_

class MultiLineText extends UiElement:
  texts := []
  font/Font
  font_color/int
  spacing/int
  tx_g_/TextureGroup

  constructor x_ y_ text .font .font_color transform .spacing tracker:
    content_height := (font.text_extent text)[1] + (font.text_extent text)[3]
  
    tx_g_ = TextureGroup
    txts := text.split "\n"

    offset := 0
    txts.do:
      texts.add (TextTexture (x_ + spacing) (y_ +  offset) transform TEXT_TEXTURE_ALIGN_LEFT it font font_color)
      tx_g_.add texts.last
      texts.last.change_tracker = tracker
      offset += content_height + spacing
    super x_ y_ transform

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

// class Button extends UiElement:
  

class Ui:
  display /TrueColorPixelDisplay
  ctx /GraphicsContext
  els := []

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
    display.add el.texture_group
    els.add el.texture_group

  update:
    els.do:
      display.remove it
      display.add it

  window x y w h title content/string --title_font/Font?=(Font.get "sans10") --font_color/int?=BLACK --padding/int?=2 --title_bg/int?=0xa6a6a6 --content_bg/int?=0xc4c4c4 -> ContentWindow:
    win := ContentWindow x y w h title content display
      --title_font=title_font
      --font_color=font_color
      --padding=padding
      --title_bg=title_bg
      --content_bg=content_bg
      --transform=ctx.transform
    display.add win.tx_g_
    els.add win.tx_g_
    
    return win

display_mutex := Mutex

main:
  display_driver := load_driver WROOM_16_BIT_LANDSCAPE_SETTINGS
  display := get_display display_driver
  sans_14 := Font [sans_14.ASCII]
  ui := Ui display
    --landscape

  ui.window 0 0 480 320 "Jackson's Game Station" ""
    --title_font = sans_14
    --padding = 5
    --content_bg = 0xd9d9d9
  fortnite_stats_content := (ui.window 20 30 240 110 "Fortnite Stats" "Played: \nWins: \nKills: \nTop 25: "
    --title_font = sans_14
    --padding = 5)

  ui.window 20 160 240 140 "Messages" "No new messages"
    --title_font = sans_14
    --padding = 5
  
  sleep --ms=100

  display.draw

  wins := 0
  while true:
    sleep --ms=500
    wins++
    fortnite_stats_content.content = "Played: 203\nWins: $wins\nKills:  400\nTop 25: 60"
    display.draw
    
