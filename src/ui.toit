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

  abstract add d/TrueColorPixelDisplay ctx/GraphicsContext

class ContentWindow extends UiElement:
  w_ /int
  h_ /int
  padding/int
  title /string

  title_bg/int
  content_bg/int
  title_font/Font
  content_font/Font

  tx_g_/TextureGroup
  content_tx_/TextureGroup

  constructor x_ y_ .w_ .h_ .title content/string --.title_font/Font?=(Font.get "sans10") --.content_font/Font?=(Font.get "sans10") --font_color/int?=BLACK --.padding/int?=2 --.title_bg/int?=0xa6a6a6 --.content_bg/int?=0xc4c4c4 --transform/Transform?=Transform.identity:
    tx_g_ = TextureGroup
    tf_height := (title_font.text_extent title)[1] + (title_font.text_extent title)[3]
    h_title := tf_height + (padding*2)
    content_height := (content_font.text_extent content)[1] + (content_font.text_extent content)[3]
    content_offset := h_title + padding + content_height
    // texts := content.split "\n"
    // offset := 0
    // tx := TextureGroup
    // texts.do:
    //   tx.add (TextTexture (x_ + padding) (y_ + content_offset + offset) transform TEXT_TEXTURE_ALIGN_LEFT it content_font font_color)
    //   offset += content_height + padding
    content_tx_ = (multiline_text x_ (y_ + content_offset) content content_font font_color transform padding)

    tx_g_.add (FilledRectangle title_bg x_ y_ w_ h_ transform)
    tx_g_.add (FilledRectangle content_bg x_ (y_ + h_title) w_ (h_ - h_title) transform)
    tx_g_.add (TextTexture (x_ + padding) (y_ + padding + tf_height) transform TEXT_TEXTURE_ALIGN_LEFT title title_font font_color)
    tx_g_.add content_tx_

    super x_ y_ transform
  
  // content_texture -> TextTexture:
  //   return content_tx_

  add d/TrueColorPixelDisplay ctx/GraphicsContext:
    d.add tx_g_
    // f_height := (title_font.text_extent title)[1] + (title_font.text_extent title)[3]
    // h_title := f_height + (padding*2)
    
    // d.filled_rectangle (ctx.with --color=title_bg) x_ y_ w_ h_title
    // d.filled_rectangle (ctx.with --color=content_bg) x_ (y_ + h_title) w_ (h_ - h_title)
    // d.text (ctx.with --font=title_font --alignment=TEXT_TEXTURE_ALIGN_LEFT) (x_ + padding) ((y_ + padding) + f_height) title

multiline_text x y text font font_color transform spacing -> TextureGroup:
  content_height := (font.text_extent text)[1] + (font.text_extent text)[3]
  
  tx := TextureGroup
  texts := text.split "\n"

  offset := 0
  texts.do:
    tx.add (TextTexture (x + spacing) (y +  offset) transform TEXT_TEXTURE_ALIGN_LEFT it font font_color)
    offset += content_height + spacing
  
  return tx

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
    el.add display ctx

  window x y w h title content/string --title_font/Font?=(Font.get "sans10") --font_color/int?=BLACK --padding/int?=2 --title_bg/int?=0xa6a6a6 --content_bg/int?=0xc4c4c4 -> ContentWindow:
    win := ContentWindow x y w h title content
      --title_font=title_font
      --font_color=font_color
      --padding=padding
      --title_bg=title_bg
      --content_bg=content_bg
      --transform=ctx.transform
    display.add win.tx_g_
    
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
  fortnite_stats_content := (ui.window 20 30 240 110 "Fortnite Stats" "Games Played: \nWins: \nKills: \nCrown Wins: "
    --title_font = sans_14
    --padding = 5)

  ui.window 20 160 240 140 "Messages" "No new messages"
    --title_font = sans_14
    --padding = 5

  // fortnite_stats_content.text = "HELLO???\nIS IT ME"
  // display.add (window 0 0 480 320 "Jackson's Game Station"
  //   --title_font = sans_14
  //   --padding = 5
  //   --content_bg = 0xd9d9d9
  //   --transform = display.landscape
  // )
  // display.add (multiline_text "farts\nbutts\nshits")
  sleep --ms=100

  display.draw


  while true:
    sleep --ms=10000
