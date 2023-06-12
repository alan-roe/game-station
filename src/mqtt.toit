import mqtt
import net
import pixel_display.true_color show *
import pixel_display.texture show *

import .env
import .fortnite
import .ui
import .weather
import .main

mqtt_service := MqttServices

class MqttServices:
  client/mqtt.Client? := null

  connect:
    while true:
      try: 
        network := net.open
        transport := mqtt.TcpTransport network --host=MQTT_HOST
        client = mqtt.Client --transport=transport
        options := mqtt.SessionOptions
          --client_id=MQTT_CLIENT_ID
        client.start --options=options
        break
      finally:
        sleep --ms=500 

  constructor:
    connect

  wait_for_connect:
    while true:
      if connected:
        break
      sleep --ms=500

  messages msg_texture/ContentWindow:
    task::
      wait_for_connect
      msg_queue := []
      client.subscribe "gstation_to":: | topic/string payload/ByteArray |
        now := (Time.now).local
        msg := payload.to_string
        if msg_queue.size > 5:
          msg_queue.remove msg_queue.first
        msg_queue.add "$now.h:$(%02d now.m) <Alan> $msg"
        new_msg := ""
        msg_queue.do: new_msg = new_msg + "$it \n" 
        task:: new_message_alert_led
        msg_texture.content = new_msg

  weather weather_win/ContentWindow weather_icon/TextureGroup:
    task::
      wait_for_connect
      client.subscribe "openweather/main/temp":: | topic/string payload/ByteArray |
        temp := float.parse payload.to_string
        weather_win.content = "$(%.1f temp)°C"
      client.subscribe "openweather/weather/0/icon" :: | topic/string payload/ByteArray |
        code := payload.to_string[0..3]
        weather_icon.remove_all
        Weather.insert code weather_icon
        weather_icon.invalidate

  fortnite fortnite_window/ContentWindow:
    // TODO Migrate to actuall MQTT
    task::
      wait_for_connect
      stats := null
      exception := catch:
        stats = (FortniteStats FORTNITE_ACC)
      if exception: mqtt_debug "Couldn't retrieve fortnite stats: $exception"
      else: mqtt_debug "Retrieved fortnite stats"
      while true:
        new_stats := stats.stringify
        fortnite_window.content = new_stats
        sleep --ms=60_000
        stats.update

  connected -> bool:
    return (not client.is_closed)
    
  publish topic/string payload/ByteArray:
    task::
      wait_for_connect
      client.publish topic payload

mqtt_debug msg/string:
  mqtt_service.publish "esp32_debug" msg.to_byte_array
