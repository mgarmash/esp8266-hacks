WIFI_SSID = "Wireless"
WIFI_PASS = "password"

BROKER_HOST="m20.cloudmqtt.com"
BROKER_USER=""
BROKER_PASS=""
BROKER_PORT=13321
TIMEOUT = 120
TOPIC = "/aps"

CONNECT_INTERVAL=2000
DATA_INTERVAL=4000
RECONNECT_ATTEMPTS = 5
MAX_QUEUE_LENGTH = 2
MAX_LOCK = 10

queue = {}
lock = 0
tail = 0
head = 0
reconnects = 6

wifi.setmode(wifi.STATION)
print(wifi.sta.getip())
wifi.sta.config(WIFI_SSID, WIFI_PASS)
wifi.sta.autoconnect(1)
wifi.sta.connect()

m = mqtt.Client(wifi.sta.getmac(), TIMEOUT, BROKER_USER, BROKER_PASS)

m:lwt("/lwt", "offline", 0, 0)

function publish(msg)
     if tail-head > MAX_QUEUE_LENGTH then 
          queue = {}
          tail = 0
          head = 0
     end  
     queue[tail] = msg
     tail = tail + 1
     if head ~= tail then
          if (lock == 0 or lock > MAX_LOCK) then
               lock = 1
               m:publish(TOPIC, queue[head], 0, 0, function(conn)
                    print("sent("..tail-head..")")
                    queue[head] = nil
                    head = head + 1
                    lock = 0
               end)
          else
               lock = lock + 1
          end
     end
end

function listap(t)
     local aps = ""
     if t ~= nil then
          for k,v in pairs(t) do
               local rssi, bssid = v:match("[^,]+,([^,]+),([^,]+),[^,]")
               aps = aps.." "..bssid.."="..rssi.."\n"
          end
     end
     print(aps)
     publish(aps)
end

function reconnect()
     tmr.stop(1)
     tmr.alarm(0, CONNECT_INTERVAL, 1, function() 
          if reconnects > RECONNECT_ATTEMPTS then
               reconnects = 0
               print("reconnecting to wifi")
               wifi.sta.disconnect()
               wifi.sta.connect()
          else
               reconnects = reconnects + 1
               if wifi.sta.status() == 5 and wifi.sta.getip() ~= nil then
                    print("reconnecting to mqtt")
                    m:connect(BROKER_HOST, BROKER_PORT, 0)
               end
          end
     end) 
end

m:on("connect", function(con) 
     tmr.stop(0)
     queue = {}
     tail = 0
     head = 0
     lock = 0
     reconnects = 0 
     print ("connected to mqtt")
     tmr.alarm(1, DATA_INTERVAL, 1, function() wifi.sta.getap(listap) end)
end)

m:on("offline", function(con) 
     reconnect()
end)

reconnect()
