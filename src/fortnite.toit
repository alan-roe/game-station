import encoding.json

import .env
import .mqtt
import .ui

class FortniteStats:
  static HOST ::= "fortniteapi.io"
  static PATH ::= "/v1/stats?account="
  level/int := 0
  kills/int := 0
  wins/int := 0
  played/int := 0
  top25/int := 0
  fortnite_window/ContentWindow
  
  constructor .fortnite_window/ContentWindow:
    mqtt_service.subscribe "fortnite/stats" :: | topic/string payload/ByteArray |
      data := json.decode payload
      if (data.get "result"):
        level = (data.get "account").get "level"
        global := (data.get "global_stats")
        duo := (global.get "duo")
        solo := (global.get "solo")

        kills = (solo.get "kills") + (duo.get "kills")
        wins = (solo.get "placetop1") + (duo.get "placetop1")
        played = (solo.get "matchesplayed") + (duo.get "matchesplayed")
        top25 = (get_top25_ solo) + (get_top25_ duo)

      fortnite_window.content = stringify
  
  stringify -> string:
    return "Level: $level\nPlayed: $played\nWins: $wins\nKills: $kills\nTop 25: $top25"

  static get_top25_ xs -> int:
    return ((xs.get "placetop3") + (xs.get "placetop5") + (xs.get "placetop6") + (xs.get "placetop10") + (xs.get "placetop12") + (xs.get "placetop25"))
