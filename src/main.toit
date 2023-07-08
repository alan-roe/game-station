import encoding.json
import font show *
import font_x11_adobe.sans_14_bold
import font_x11_adobe.sans_10
import font_x11_adobe.sans_14
import color_tft show *
import monitor show Mutex
import mqtt
import net
import net.x509 as net
import net.wifi as wifi
import ntp
import gpio
import i2c
import http
import http.headers
import certificate_roots
import esp32 
import esp32 show reset_reason adjust_real_time_clock
import log.target show *
import log.level show *
import pictogrammers_icons.size_20 as icons
import pixel_display show *
import pixel_display.true_color show *
import pixel_display.texture show *
import png_display show *
import host.file show *

import .env
import .get_display  // Import file in current project, see above.
import .led
import .iic
import .fortnite
import .ui
import .weather
import .mqtt
import .storage show bucket

start_time := ""
new_msg_alert := false
network := ?

class MainUi extends Ui:
  // Buttons
  send_btn/Button? := null
  accept_btn/Button? := null
  reject_btn/Button? := null
  screen_btn/Button? := null

  // Windows
  fortnite_stats/ContentWindow? := null
  messages/ContentWindow? := null
  weather_win/ContentWindow? := null
  
  time_texture/TextTexture? := null
  weather_icon/TextureGroup? := null
  wifi_icon/TextureGroup? := null
  wifi_on/IconTexture? := null
  wifi_off/IconTexture? := null
  wifi_connected_ := false

  load_elements:
    sans_14 := Font [sans_14.ASCII, sans_14.LATIN_1_SUPPLEMENT]
    sans_10 := Font [sans_10.ASCII, sans_10.LATIN_1_SUPPLEMENT]
    
    bg_color := 0x5FCEEA
    content_color := 0xFFFFFF
    title_color := 0x1B90DD

    display.background = bg_color

    window 0 0 480 320 "Jackson's Game Station"
      --title_font = Font [sans_14_bold.ASCII]
      --padding = 5
      --title_bg = title_color
      --only_bars

    temp := bucket.get "weather.temp"
     --if_absent= : "??°C"
    weather_win = window 20 35 130 115 "Weather"
      --content = temp
      --content_font = sans_14
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --x_padding = 32
      --padding = 5
      --rounded

    window 160 35 300 115 "Actions"
      --title_font = sans_14
      --content_font = sans_10
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded
    
    stats := bucket.get "fortnite"
      --if_absent= : "Played: \nWins: \nKills: \nTop 25: "
    fortnite_stats = (window 20 160 130 140 "Fortnite Stats"
      --content = stats // "Played: \nWins: \nKills: \nTop 25: " 
      --content_font = sans_10
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded)

    messages = window 160 160 300 140 "Messages" 
      --content = "No new messages"
      --content_font = sans_10
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded
    
    send_btn = (button 170 65 80 70 
      --text = "Send\nInvite"
      --font = sans_14
      --enabled_color = title_color
      --disabled_color = bg_color
      --rounded)
    accept_btn = (button 270 65 80 70 
      --text = "Accept\nInvite"
      --font = sans_14
      --enabled_color = title_color
      --disabled_color = bg_color
      --rounded)
    reject_btn = (button 370 65 80 70 
      --text = "Reject\nInvite"
      --font = sans_14
      --enabled_color = title_color
      --disabled_color = bg_color
      --rounded)

    screen_btn = (button 455 2 20 20 
      --icon=icons.MONITOR)

    now := (Time.now).local
    time_texture = display.text (ctx.with --color=BLACK --font=sans_14) 380 18 "$now.h:$(%02d now.m)"

    weather_icon = TextureGroup
    Weather.set ctx.transform display

    icon := bucket.get "weather.icon"
      --if_absent= : "01d"
    Weather.insert icon weather_icon
    display.add weather_icon 
    
    wifi_on = (IconTexture 430 (6+(icons.WIFI.icon_extent[1])) ctx.transform TEXT_TEXTURE_ALIGN_LEFT icons.WIFI icons.WIFI.font_ BLACK)
    wifi_off = (IconTexture 430 (6+(icons.WIFI_OFF.icon_extent[1])) ctx.transform TEXT_TEXTURE_ALIGN_LEFT icons.WIFI_OFF icons.WIFI_OFF.font_ BLACK)

    wifi_icon = TextureGroup
    wifi_icon.add wifi_off
    wifi_icon.change_tracker = display
    display.add wifi_icon
          
  constructor display display_driver:  
    super display display_driver --landscape

    load_elements
  
  buttons_enabled= enable/bool:
    btns.do:
      it.enabled = enable

  display_enabled= enable/bool:
    if display_enabled_ == enable:
      return

    display_enabled_ = enable
  
  wifi_connected -> bool:
    return wifi_connected_
  
  wifi_connected= connected/bool:
    if connected:
      wifi_icon.remove_all
      wifi_icon.add wifi_on
      wifi_on.change_tracker = display
      wifi_icon.invalidate
    else:
      wifi_icon.remove_all
      wifi_icon.add wifi_off
      wifi_off.change_tracker = display
      wifi_icon.invalidate
    wifi_connected_ = connected

  update coords:
    // if coords.s:
    //   mqtt_debug "Detected touch: $coords.x $coords.y"

    if not display_enabled_: return

    super coords

stats_list := List 11
/**
0. New-space (small collection) GC count for the process
1. Allocated memory on the Toit heap of the process
2. Reserved memory on the Toit heap of the process
3. Process message count
4. Bytes allocated in object heap
5. Group ID
6. Process ID
7. Free memory in the system
8. Largest free area in the system
9. Full GC count for the process (including compacting GCs)
10. Full compacting GC count for the process
*/
system_stats --gc/bool?=false -> string:
  process_stats stats_list --gc=gc
  ret := "Start Time: $start_time\n"
  ret += "New-space (small collection) GC count: $stats_list[0]\n"
  ret += "Allocated memory on the Toit heap:     $stats_list[1]\n"
  ret += "Reserved memory on the Toit heap:      $stats_list[2]\n"
  ret += "Process message count:                 $stats_list[3]\n"
  ret += "Bytes allocated in object heap:        $stats_list[4]\n"
  ret += "Group ID:                              $stats_list[5]\n"
  ret += "Process ID:                            $stats_list[6]\n"
  ret += "Free memory in the system:             $stats_list[7]\n"
  ret += "Largest free area in the system:       $stats_list[8]\n"
  ret += "Full GC count for the process:         $stats_list[9]\n"
  ret += "Full compacting GC count:              $stats_list[10]"
  return ret

// TODO Implement this as the PngDriver write function or whatever
/**
Writes a PNG file to the given filename.
Only light compression is used, basically just run-length encoding
  of equal pixels.  This is fast and reduces memory use.
*/
write_file filename/string driver/PngDriver_ display/PixelDisplay:
  write_to
      Stream.for_write filename
      driver
      display

ui_callbacks ui/MainUi:
  if SIMULATE:
    ui.wifi_connected = true
    network = net.open
    mqtt_init
    mqtt_subs ui
  else: monitor_wifi ui
  catch: with_timeout --ms=2000:
    while not ui.wifi_connected:
      sleep --ms=100
  clock ui.time_texture


monitor_wifi ui/MainUi:
  task::
    while true:
      signal_strength/float? := 0.0
      e := catch:
        signal_strength = network.signal_strength
      if e:
        debug "wifi not connected $e"
        if ui.wifi_connected:
          ui.wifi_connected = false
          mqtt_service.close --force
          network = null
        
        reconnect_e := catch: 
          network = wifi.open --ssid=WIFI_SSID --password=WIFI_PASS
        if reconnect_e:  
          debug "couldn't reconnect $reconnect_e"
          sleep --ms=1000
        else:
          result ::= ntp.synchronize
          if result:
            adjust_real_time_clock result.adjustment
          mqtt_init
          mqtt_subs ui
          ui.wifi_connected = true
      // debug "WiFi strength: $signal_strength"
      sleep --ms=1000

mqtt_subs ui/MainUi:
  task::
    mqtt_lost := false
    resub := true
    while true:
      if resub:
        if SIMULATE:
          screenshot_sub ui
        weather_updater ui.weather_win ui.weather_icon
        message_updater ui.messages
        FortniteStats ui.fortnite_stats
        resub = false
      else:
        if not mqtt_service.client_.connection_.is_alive:
          mqtt_service.unsubscribe_all ["gstation_to", "fortnite", "weather"]
          print "mqtt_lost"
          mqtt_lost = true
        else if mqtt_lost:
          print "mqtt found"
          mqtt_lost = false
          resub = true
      sleep --ms=1000

main:
  if not SIMULATE:
    turn_off_led
    Led.green
    debug "Started Application\nReset Reason: $(esp32.reset_reason)"
    sleep --ms=4000
  set_timezone "IST-1GMT0,M10.5.0,M3.5.0/1"

  time := Time.now.local
  start_time = "$time.day/$time.month/$time.year $time.h:$(%02d time.m):$(%02d time.s)"
  
  display := ?
  display_driver := ?
  if SIMULATE:
    display_driver = TrueColorPngDriver 480 320
    display = TrueColorPixelDisplay display_driver  
  else:
    // Touchscreen Init
    gt911_int
    display_driver = load_driver
    display = get_display display_driver

  ui := MainUi display display_driver
  ui_callbacks ui
  sleep --ms=500
  ui.draw

  display_timer := Time.now
  button_timer := Time.now
  if not SIMULATE:
    Led.off

  while true:
    // if not wifi_connect:
    //   debug "wifi not connected"
    //   ui.draw
    //   sleep --ms=5000
    //   continue
    exception := catch --trace:
      // Send stats to server
      // if stats_timer.to_now.in_m == 5:
      //   debug system_stats
      //   mqtt_debug system_stats
      //   stats_timer = Time.now
      // If the display is enabled
      if ui.display_enabled:
        coords := get_coords

        if coords.s:
          display_timer = Time.now
          if new_msg_alert:
            new_msg_alert = false 

        ui.update coords
        ui.draw 

        if ui.send_btn.released:
          play_request "You've been invited to play fortnite!"
        else if ui.accept_btn.released:
          play_request "Your fortnite request has been accepted"
        else if ui.reject_btn.released:
          play_deny "Your fortnite request has been rejected"

        if not ui.send_btn.enabled and button_timer.to_now.in_ms >= 500:
          ui.buttons_enabled = true

        adjust_backlight

        // Disable display if button pressed or 5 minutes untouched
        if ui.screen_btn.released or display_timer.to_now.in_m == 5:
          debug "disabling display"
          ui.display_enabled = false
          set_backlight 0
          
        sleep --ms=20
      else:
        // Re-enable on touch
        if get_coords.s:          
          // We disable the buttons for a second
          ui.buttons_enabled = false
          button_timer = Time.now

          ui.display_enabled = true
          adjust_backlight
          display_timer = Time.now

          ui.draw
          
        // Sleep a bit longer when the display is off
        sleep --ms=1000
    if exception:
      debug "MAIN EXCEPTION: $exception"
      debug system_stats
      mqtt_debug "MAIN EXCEPTION: $exception"

screenshot_sub ui/Ui:
  mqtt_service.subscribe "take_screenshot":: | topic/string payload/ByteArray |
    ui.screenshot

new_message_alert_led:
  if SIMULATE or new_msg_alert: return
  new_msg_alert = true
  while new_msg_alert:
    Led.blue
    sleep --ms=1000
    Led.off
    sleep --ms=1000  

clock time_texture/TextTexture:
  task::
    while true:
      now := (Time.now).local
      time_texture.text = "$now.h:$(%02d now.m)"

      // Sleep this task until the next whole minute.
      sleep_time := 60 - now.s
      sleep --ms=sleep_time*1000

play_request msg:
  e := catch: mqtt_service.publish "gstation_from" msg.to_byte_array
  if e:
    debug "couldn't send play request: $e"

play_deny msg:
  e := catch: mqtt_service.publish "gstation_from" msg.to_byte_array
  if e:
    debug "couldn't send deny request: $e"
