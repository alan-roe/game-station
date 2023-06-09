import encoding.json
import font show *
import font_x11_adobe.sans_14_bold
import monitor show Mutex
import mqtt
import net
import net.x509 as net
import ntp
import gpio
import i2c
import http
import http.headers
import certificate_roots
import esp32 
import esp32 show enable_external_wakeup deep_sleep wakeup_cause enable_touchpad_wakeup reset_reason

import pictogrammers_icons.size_48 as icons

import pixel_display.true_color show *
import pixel_display.texture show *

import .env
import .get_display  // Import file in current project, see above.
import .led
import .iic
import .bg
import .bmp
import .bg_b
import .fortnite

// Search for icon names on https://materialdesignicons.com/
// (hover over icons to get names).
WMO_4501_ICONS ::= [
  icons.WEATHER_NIGHT,
  icons.WEATHER_SUNNY, // 1
  icons.WEATHER_PARTLY_CLOUDY, // 2
  icons.WEATHER_CLOUDY, // 3
  icons.WEATHER_CLOUDY, // 4
  icons.WEATHER_NIGHT,
  icons.WEATHER_NIGHT,
  icons.WEATHER_NIGHT,
  icons.WEATHER_NIGHT,
  icons.WEATHER_PARTLY_RAINY, // 9
  icons.WEATHER_RAINY,
  icons.WEATHER_LIGHTNING,
  icons.WEATHER_NIGHT,
  icons.WEATHER_SNOWY, // 12
  icons.WEATHER_FOG,
]

// We don't want separate tasks updating the display at the
// same time, so this mutex is used to ensure the tasks only
// have access one at a time.
display_mutex := Mutex

display_driver := load_driver WROOM_16_BIT_LANDSCAPE_SETTINGS
display := get_display display_driver
display_enabled := true

mqtt_client := mqtt_client_connect

new_msg_alert := false

msg_texture := ?
icon_texture := ?
temperature_texture := ?
time_texture := ?

init_display:
  sans_14_font ::= Font [
    sans_14_bold.ASCII,  // Regular characters.
    sans_14_bold.LATIN_1_SUPPLEMENT,  // Degree symbol.
  ]

  //display.background = COLOR_1
  context := display.context
    --landscape
    --color=COLOR_3
    --font=sans_14_font

  // pixmap := IndexedPixmapTexture 0 0 480 320 context.transform BG_B BG_B_PALETTE
  // display.add pixmap
  // pixmap := IndexedPixmapTexture 0 0 480 320 context.transform BG_B BG_B_PALETTE
  // display.add pixmap
  
  black_context := context.with --color=BLACK

  icon_texture =
    display.icon (black_context.with --color=WHITE) 110 70 icons.WEATHER_CLOUDY

  // Temperature is black on white.
  temperature_context :=
    context.with --color=WHITE --alignment=TEXT_TEXTURE_ALIGN_CENTER
  temperature_texture =
    display.text temperature_context 85 45 "??°C"

  time_context := context.with --color=WHITE --alignment=TEXT_TEXTURE_ALIGN_CENTER
  time_texture = display.text time_context 85 75 "??:??"

  msg_context :=
    black_context.with --color=(get_rgb 222 218 248) --alignment=TEXT_TEXTURE_ALIGN_LEFT
  msg_texture =
    display.text msg_context 30 175 "no new messages..."

  
  display.draw --speed=100

  display_enabled = true

main:
  if wakeup_cause == esp32.WAKEUP_EXT1:
    mqtt_debug "Woken up from external pin"
    // Chances are that when we just woke up because a pin went high.
    // Give the pin a chance to go low again.
    sleep --ms=1_000
  else:
    mqtt_debug "Woken up for other reasons: $esp32.wakeup_cause"
  
  wpin := reset_reason
  mqtt_debug "reset reason: $(%d wpin)"
  
  // layer2_tex := PbmTexture 0 0 context.transform COLOR_2 LAYER_2
  // layer3_tex := PbmTexture 0 0 context.transform COLOR_3 LAYER_3
  // layer4_tex := PbmTexture 0 0 context.transform COLOR_4 LAYER_4
  // layer5_tex := PbmTexture 0 0 context.transform COLOR_5 LAYER_5
  // layer6_tex := PbmTexture 0 0 context.transform COLOR_6 LAYER_6
  // layer7_tex := PbmTexture 0 0 context.transform COLOR_7 LAYER_7
  // layer8_tex := PbmTexture 0 0 context.transform COLOR_8 LAYER_8
  
  // display.add layer2_tex
  // display.add layer3_tex
  // display.add layer4_tex
  // display.add layer5_tex
  // display.add layer6_tex
  // display.add layer7_tex
  // display.add layer8_tex

  // display.filled_rectangle context 8 0 460 110

  // // Message Box
  // msg_bg_ctx := display.context
  //    --landscape
  // msg_footer_tex := PbmTexture 7 212 context.transform (get_rgb 198 81 230) MSG_FOOTER
  // display.add msg_footer_tex
  // msg_bg_tex := PbmTexture 7 71 context.transform (get_rgb 88 106 230) MSG_BG
  // display.add msg_bg_tex

  // msg_header_ctx := msg_bg_ctx.with
  //   --color=(get_rgb 221 219 233)
  // display.filled_rectangle msg_header_ctx 21 111 138 36

  // // Console
  // console_bg_tex := PbmTexture 4 2 context.transform (get_rgb 218 86 248) CONSOLE
  // display.add console_bg_tex
  
  // console_body_tex := PbmTexture context.transform (get_rgb 50 45 94)

  // Temperature/Time
  // temp_time_ctx := context.with
  //   --color=(get_rgb 114 201 244)
  // display.filled_rectangle temp_time_ctx 53 16 127 74

  

  // // White circle as background of weather icon.  We are just
  // // using the window to draw a circle here, not as an actual
  // // window with its own textures.
  // DIAMETER ::= 56
  // CORNER_RADIUS ::= DIAMETER / 2
  // display.add
  //   RoundedCornerWindow 68 4 DIAMETER DIAMETER
  //     context.transform
  //     CORNER_RADIUS
  //     WHITE
  // // Icon is added after the white dot so it is in a higher layer.

  // Time is white on the black background, aligned by the
  // center so it looks right relative to the temperature
  // without having to zero-pad the hours.

  // msg_header_txt_ctx := black_context.with
  //   --color=(get_rgb 43 34 84)
  // msg_header_txt := display.text msg_header_txt_ctx 29 135 "MESSAGES"
  // display.filled_rectangle context 15 65 465 255

  // The scene is built, now start some tasks that will update
  // the display.
  init_display
  gt911_int
  mqtt_debug "started program"
  msg_sub msg_texture
  weather_sub icon_texture temperature_texture 
  task:: clock_task time_texture
  task:: watch_touch
  // sleep --ms=5000
  // display.close
  // touch_mutex.do:
  //   gt911_release

  // sleep --ms=5000
  // mqtt_debug "sleeping..."
  // mask :=0
  // mask |= 1 << 21
  // enable_external_wakeup mask false
  // sleep --ms=100
  // deep_sleep (Duration --s=10)

mqtt_debug msg/string:
  mqtt_client.publish "esp32_debug" msg.to_byte_array

new_message_alert_led:
  new_msg_alert = true
  while new_msg_alert:
    Led.blue
    sleep --ms=1000
    Led.off
    sleep --ms=1000

watch_touch:
  while true:
    coord := get_coords
    x := (480 - coord.y)
    y := coord.x
    if coord.s:
      mqtt_debug "touched, x: $(%d x), y: $(%d y)"
      if x >= 109 and x <= 189 and y >= 239 and y <= 318:
        play_request
        new_msg_alert = false
        Led.green
        sleep --ms=1000
        Led.off
      else if x >= 292 and x <= 368 and y >= 237 and y <= 314:
        play_deny
        new_msg_alert = false
        Led.red
        sleep --ms=1000
        Led.off
      else: 
        sleep --ms=1000
        display_mutex.do:
          if display_enabled:
            mqtt_debug "turning off backlight"
            display_enabled = false
            display_driver.backlight_off
          else if not display_enabled:
            mqtt_debug "turning on backlight"
            display_enabled = true
            display_driver.backlight_on
            sleep --ms=20
            //display.draw
        mqtt_debug (FortniteStats FORTNITE_ACC).stringify
      get_coords
    sleep --ms=20

mqtt_client_connect -> mqtt.Client:
  network := net.open
  transport := mqtt.TcpTransport network --host=MQTT_HOST
  cl := mqtt.Client --transport=transport
  options := mqtt.SessionOptions
    --client_id=MQTT_CLIENT_ID
  cl.start --options=options
  return cl

play_request:
  mqtt_client.publish "gstation_from" "fa".to_byte_array

play_deny:
  mqtt_client.publish "gstation_from" "fr".to_byte_array

msg_sub msg_texture/TextTexture:
  mqtt_client.subscribe "gstation_to":: | topic/string payload/ByteArray |
    now := (Time.now).local
    msg := payload.to_string
    display_mutex.do:
      task:: new_message_alert_led
      msg_texture.text = "$now.h:$(%02d now.m): $msg"
      display.draw

weather_sub weather_icon/IconTexture temperature_texture/TextTexture:
  mqtt_client.subscribe "openweather/main/temp":: | topic/string payload/ByteArray |
    temp := float.parse payload.to_string
    display_mutex.do:
      temperature_texture.text = "$(%.1f temp)°C"
      display.draw
  mqtt_client.subscribe "openweather/weather/0/icon" :: | topic/string payload/ByteArray |
    code := int.parse payload.to_string[0..2]
    if code > 12: code = 13
    display_mutex.do:
      weather_icon.icon = WMO_4501_ICONS[code]
      display.draw

clock_task time_texture:
  while true:
    now := (Time.now).local
    display_mutex.do:
      // H:MM or HH:MM depending on time of day.
      time_texture.text = "$now.h:$(%02d now.m)"
      display.draw
    // Sleep this task until the next whole minute.
    sleep_time := 60 - now.s
    sleep --ms=sleep_time*1000
