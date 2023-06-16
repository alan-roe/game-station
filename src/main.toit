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
import esp32 show enable_external_wakeup deep_sleep wakeup_cause enable_touchpad_wakeup reset_reason
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
    
    window 0 0 480 320 "Jackson's Game Station"
      --title_font = sans_14
      --padding = 5
      --title_bg = title_color
      --content_bg = bg_color

    weather_win = window 20 35 130 115 "Weather" 
      --content = "21°C"
      --content_font = sans_14
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --x_padding = 30
      --padding = 5
      --rounded

    window 160 35 300 115 "Actions"
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded

    fortnite_stats = (window 20 160 130 140 "Fortnite Stats" 
      --content = "Played: \nWins: \nKills: \nTop 25: "
      --title_font = sans_14
      --title_bg = title_color
      --content_bg = content_color
      --padding = 5
      --rounded)

    messages = window 160 160 300 140 "Messages" 
      --content = "No new messages"
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

    wifi_on = (IconTexture 430 (6+(icons.WIFI.icon_extent[1])) ctx.transform TEXT_TEXTURE_ALIGN_LEFT icons.WIFI icons.WIFI.font_ BLACK)
    wifi_off = (IconTexture 430 (6+(icons.WIFI_OFF.icon_extent[1])) ctx.transform TEXT_TEXTURE_ALIGN_LEFT icons.WIFI_OFF icons.WIFI_OFF.font_ BLACK)
    
    now := (Time.now).local
    time_texture = display.text (ctx.with --color=BLACK --font=sans_14) 380 18 "$now.h:$(%02d now.m)"

    weather_icon = TextureGroup
    Weather.set ctx.transform display

    Weather.insert "01d" weather_icon
    display.add weather_icon 
    
    wifi_icon = TextureGroup
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
    if coords.s:
      mqtt_debug "Detected touch: $coords.x $coords.y"

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
  else: monitor_wifi ui
  clock ui.time_texture
  mqtt_subs ui
  
    
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
        reconnect_e := catch: 
          network = wifi.open --ssid=WIFI_SSID --password=WIFI_PASS
          mqtt_service.close --force
          mqtt_service = mqtt_init
          mqtt_subs ui
        if reconnect_e:  
          debug "couldn't reconnect"
          sleep --ms=1000
      else if not ui.wifi_connected:
        ui.wifi_connected = true
      // debug "WiFi strength: $signal_strength"
      sleep --ms=1000

mqtt_subs ui/MainUi:
  if SIMULATE:
    screenshot_sub ui
  weather_updater ui.weather_win ui.weather_icon
  message_updater ui.messages
  FortniteStats ui.fortnite_stats

main:
  // debug "Started Application\nReset Reason: $(esp32.reset_reason)"
  if not SIMULATE: sleep --ms=10000

  if SIMULATE: network = net.open
  else: network = wifi.open --ssid=WIFI_SSID --password=WIFI_PASS
  
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
    display_driver = load_driver WROOM_16_BIT_LANDSCAPE_SETTINGS
    display = get_display display_driver

  ui := MainUi display display_driver
  ui_callbacks ui
  sleep --ms=50

  ui.draw

  // stats_timer := Time.now
  display_timer := Time.now
  button_timer := Time.now

  while true:
    // if not wifi_connect:
    //   debug "wifi not connected"
    //   ui.draw
    //   sleep --ms=5000
    //   continue
    exception := catch:
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

        // Disable display if 5 minutes untouched
        if display_timer.to_now.in_m == 5:
          debug "disabling display: timeout"
          ui.display_enabled = false
          display_driver.backlight_off

        // Check buttons
        if ui.send_btn.released or ui.accept_btn.released:
          play_request
        else if ui.reject_btn.released:
          play_deny

        if not ui.send_btn.enabled and button_timer.to_now.in_s > 1:
          ui.buttons_enabled = true

        if ui.screen_btn.released:
          ui.display_enabled = false
          display_driver.backlight_off

        sleep --ms=20
      else:
        // Re-enable on touch
        if get_coords.s:          
          // We disable the buttons for a second
          ui.buttons_enabled = false
          button_timer = Time.now

          ui.display_enabled = true
          display_driver.backlight_on
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

play_request:
  e := catch: mqtt_service.publish "gstation_from" "fa".to_byte_array
  if e:
    debug "couldn't send play request: $e"

play_deny:
  e := catch: mqtt_service.publish "gstation_from" "fr".to_byte_array
  if e:
    debug "couldn't send deny request: $e"
