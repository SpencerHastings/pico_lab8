ruleset wovyn_base {

    meta {
        shares __testing
        use module sensor_profile alias profile
        use module io.picolabs.subscription alias Subscriptions
    }

    global {
        __testing = { "queries": [],
            "events":  
            [ 
                { 
                    "domain": "wovyn", "type": "fakeheartbeat", "attrs": [ "temperature" ] 
                }
            ] 
        }
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        fired {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        }
      }

    rule process_heartbeat {
        select when wovyn:heartbeat genericThing re#(.+)#
        pre {
            temp = event:attr("genericThing").get("data").get("temperature").head()

        }
        send_directive("test", {"hello": "world"})
        fired {
            raise wovyn event "new_temperature_reading"
                attributes {"temperature":temp.get("temperatureF"), "timestamp":time:now()}
        }
    }

    rule process_fake_heartbeat {
        select when wovyn:fakeheartbeat
        pre {
            temp = event:attr("temperature")

        }
        send_directive("test", {"hello": "world"})
        fired {
            raise wovyn event "new_temperature_reading"
                attributes {"temperature":temp, "timestamp":time:now()}
        }
    }

    rule find_high_temps {
        select when wovyn:new_temperature_reading
        pre {
            temperature = event:attr("temperature")
            is_violation = (temperature > profile:get_threshold()) 
                => true | false
        }
        send_directive("temp_reading", {"is_violation": is_violation})
        fired {
            raise wovyn event "threshold_violation" 
                attributes {"temperature": temperature,"timestamp": event:attr("timestamp") , "threshold": profile:get_threshold()}
                if is_violation
        }
    }

    rule threshold_notification {
        select when wovyn:threshold_violation
        foreach Subscriptions:established("Tx_role","manager") setting (subscription)
            event:send
            (
                { 
                    "eci": subscription{"Tx"}, 
                    "eid": "1337",
                    "domain": "wovyn", 
                    "type": "threshold_violation",
                    "attrs": {"temperature": event:attr("temperature"),"timestamp": event:attr("timestamp") , "threshold": event:attr("threshold")}
                },
                subscription{"Tx_host"}
            )
    }
}