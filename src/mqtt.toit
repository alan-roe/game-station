import mqtt
import net
import net.wifi as wifi
import pixel_display.true_color show *
import pixel_display.texture show *
import encoding.json

import .env
import .fortnite
import .ui
import .weather
import .main

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
    weather_win.content = "$(%.1f temp)°C"
    
    code := (data.get "icon")
    weather_icon.remove_all
    Weather.insert code weather_icon
    weather_icon.invalidate

message_updater msg_texture/ContentWindow:
  msg_queue := []
  mqtt_service.subscribe "gstation_to":: | topic/string payload/ByteArray |
    now := (Time.now).local
    msg := payload.to_string
    if msg_queue.size > 5:
      msg_queue.remove msg_queue.first
    msg_queue.add msg
    new_msg := ""
    msg_queue.do: new_msg = new_msg + "$it\n" 
    task:: new_message_alert_led
    msg_texture.content = new_msg

mqtt_debug msg/string:
  e := catch:
    time := Time.now.local
    mqtt_service.publish "esp32_debug" ("--- $time.day/$time.month/$time.year $time.h:$(%02d time.m):$(%02d time.s) ---\n$msg").to_byte_array
  if e: debug "mqtt_debug exception: $e"
