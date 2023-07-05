import mqtt
import net
import net.wifi as wifi
import pixel_display.true_color show *
import pixel_display.texture show *
import encoding.json
import line_wrap show line_wrap
import .env
import .fortnite
import .ui
import .weather
import .main
import .storage

mqtt_service := null

mqtt_init:
  while true:
    e := catch:
      transport := mqtt.TcpTransport network --host=MQTT_HOST
      mqtt_service = mqtt.Client --transport=transport
      options := mqtt.SessionOptions
        --client_id=MQTT_CLIENT_ID
        --password=MQTT_PASSWORD
        --username=MQTT_CLIENT_ID
      mqtt_service.start --options=options
    if e:
      debug "mqtt_init: $e"
      sleep --ms=500
      continue
    break

weather_updater weather_win/ContentWindow weather_icon/TextureGroup:
  mqtt_service.subscribe "weather":: | topic/string payload/ByteArray |
    data := json.decode payload
    temp := (data.get "temp")
    temp_str := "$(%.1f temp)°C"
    bucket["weather.temp"] = temp_str
    weather_win.content = temp_str
    
    code := (data.get "icon")
    bucket["weather.icon"] = code
    weather_icon.remove_all
    Weather.insert code weather_icon
    weather_icon.invalidate

message_updater msg_texture/ContentWindow:
  msg_queue := []

  mqtt_service.subscribe "gstation_to":: | topic/string payload/ByteArray |
    msg := [payload.to_string]
    font := msg_texture.content_font
    msg = 
      line_wrap msg[0] msg_texture.w_
        --compute_width=: | s from to| 
          w := font.text_extent s from to
          w[0] + w[2] - 5
        --can_split=: |s i| 
          if i < s.size:
            s[i] == ' '
          else: false
    msg.do: msg_queue.add it
    while msg_queue.size > 6:
      msg_queue.remove msg_queue.first
    new_msg := ""
    msg_queue.do: new_msg = new_msg + "$it\n" 
    task:: new_message_alert_led
    msg_texture.content = new_msg

mqtt_debug msg/string:
  e := catch:
    time := Time.now.local
    mqtt_service.publish "esp32_debug" ("--- $time.day/$time.month/$time.year $time.h:$(%02d time.m):$(%02d time.s) ---\n$msg").to_byte_array
  if e: debug "mqtt_debug exception: $e"
