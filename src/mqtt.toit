import mqtt
import net
import pixel_display.true_color show *
import pixel_display.texture show *

import .env
import .fortnite
import .ui
import .weather
import .main

mqtt_service := mqtt_init

mqtt_init -> mqtt.Client?:
  while true:
    try:
      network := net.open
      transport := mqtt.TcpTransport network --host=MQTT_HOST
      client := mqtt.Client --transport=transport
      options := mqtt.SessionOptions
        --client_id=MQTT_CLIENT_ID
      client.start --options=options
      return client
    finally:
      sleep --ms=500
  return null

weather_updater weather_win/ContentWindow weather_icon/TextureGroup:
  mqtt_service.subscribe "openweather/main/temp":: | topic/string payload/ByteArray |
    temp := float.parse payload.to_string
    weather_win.content = "$(%.1f temp)°C"
  mqtt_service.subscribe "openweather/weather/0/icon" :: | topic/string payload/ByteArray |
    code := payload.to_string[0..3]
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
    msg_queue.add "$now.h:$(%02d now.m) <Alan> $msg"
    new_msg := ""
    msg_queue.do: new_msg = new_msg + "$it \n" 
    task:: new_message_alert_led
    msg_texture.content = new_msg

mqtt_debug msg/string:
  e := catch --trace:
    time := Time.now.local
    mqtt_service.publish "esp32_debug" ("--- $time.day/$time.month/$time.year $time.h:$(%02d time.m):$(%02d time.s) ---\n$msg").to_byte_array
  if e: debug "mqtt_debug exception: $e"
