ruleset manage_sensors {

    meta {
        provides all_temperatures
        shares __testing, all_temperatures
        use module io.picolabs.subscription alias Subscriptions
    }

    global {

        default_threshold = "80.0"
        default_phone_number = "8013100486"


        sensors = function(name) {//return eci
            sensor = ent:sensors.filter(
                function(s) {
                    s.get("name") == name
                }
            )
            ret = (sensor.length() == 1) => sensor[0] | null
            ret
        }

        all_temperatures = function() {
            Subscriptions:established("Tx_role", "sensor").map(
                function(sub) {
                    eci = sub{"Tx"}
                    args = {}
                    host = (sub{"Tx_host"} == null) => "http://localhost:8080" | sub{"Tx_host"};
                    url = host + "/sky/cloud/" + eci + "/temperature_store/temperatures";
                    response = http:get(url,args);
                    answer = response{"content"}.decode();
                    answer
                }
            )
        }

        temperature_report = function() {
            (ent:reports.length() < 5) => ent:reports | ent:reports.slice(ent:reports.length() - 5, ent:reports.length() - 1) 
        }

        __testing = { "queries": [],
            "events":  
            [ 
                { 
                    "domain": "sensor", "type": "new_sensor", "attrs": [ "name" ] 
                },
                { 
                    "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "name" ] 
                },
                {
                    "domain": "manager", "type": "add_sub", "attrs": [ "eci", "name", "Rx_role", "Tx_role", "wellKnown_Tx" ]
                },
                {
                    "domain": "sensor", "type": "subscribe", "attrs": [ "name", "wellKnown_Tx" ]
                },
                {
                    "domain": "sensor", "type": "subscribe_out", "attrs": [ "name", "wellKnown_Tx", "Tx_host" ]
                },
                {
                    "domain": "manager", "type": "new_report", "attrs": []
                }
            ] 
        }

    }

    rule initialize {
        select when wrangler ruleset_added where event:attr("rids") >< meta:rid
        always {
            ent:report_id := 0
            ent:reports := {}
        }
    }

    rule start_new_temperature_report {
        select when manager:new_report
      
        fired {
            new_id = ent:report_id
            ent:report_id := ent:report_id + 1

            ent:reports{new_id} := {
                "sensors_queried" : 0,
                "sensors_responded" : 0,
                "temperatures" : []
            }

            raise manager event "send_report_requests"
                attributes 
                {
                    "report_id": new_id
                }
        }
        
    }

    rule send_report_requests {
        select when manager:send_report_requests
        foreach Subscriptions:established("Tx_role", "sensor") setting (sub)
            pre {
                id = event:attr("report_id")
            }
            event:send(
                {
                    "eci": sub{"Tx"},
                    "eid": "1337",
                    "domain": "sensor",
                    "type": "report_request",
                    "attrs": {
                        "report_id": id,
                        "Rx": sub{"Rx"}
                    }
                },
                sub{"Tx_host"}
            )
            fired {
                ent:reports{id} := ent:reports{id}.put(
                    "sensors_queried", 
                    ent:reports{id}{"sensors_queried"} + 1
                    )
            }
    }

    rule receive_report {
        select when sensor:temperature_report
        pre {
            id = event:attr("report_id")
            report = event:attr("report")
        }
        fired {
            ent:reports{id} := ent:reports{id}.put(
                "sensors_responded", 
                ent:reports{id}{"sensors_responded"} + 1
                )
            ent:reports{id} := ent:reports{id}.put(
                "reports", 
                ent:reports{id}{"reports"}.append(report)
                )
        }
    }

    rule make_sensor_subscription {
        select when sensor:subscribe
        send_directive("test", {"hello": "world"})
        fired {
            raise manager event "add_sub"
                attributes 
                {
                    "name": event:attr("name"),
                    "Rx_role": "manager",
                    "Tx_role": "sensor",
                    "wellKnown_Tx": event:attr("wellKnown_Tx")
                    
                };
        }
        
    }

    rule make_subscription {
        select when manager:add_sub
        send_directive("test", {"hello": "world"})
        fired {
            raise wrangler event "subscription"
                attributes
                { 
                    "name": event:attr("name"),
                    "Rx_role": event:attr("Rx_role"),
                    "Tx_role": event:attr("Tx_role"),
                    "channel_type": "subscription",
                    "wellKnown_Tx": event:attr("wellKnown_Tx") 
                } 
        }
    }

    rule make_outside_sensor_subscription {
        select when sensor:subscribe_out
        send_directive("test", {"hello": "world"})
        fired {
            raise manager event "add_sub_out"
                attributes 
                {
                    "name": event:attr("name"),
                    "Rx_role": "manager",
                    "Tx_role": "sensor",
                    "wellKnown_Tx": event:attr("wellKnown_Tx"),
                    "Tx_host": event:attr("Tx_host")
                };
        }
        
    }

    rule make_outside_subscription {
        select when manager:add_sub_out
        send_directive("test", {"hello": "world"})
        fired {
            raise wrangler event "subscription"
                attributes
                { 
                    "name": event:attr("name"),
                    "Rx_role": event:attr("Rx_role"),
                    "Tx_role": event:attr("Tx_role"),
                    "channel_type": "subscription",
                    "wellKnown_Tx": event:attr("wellKnown_Tx"),
                    "Tx_host": event:attr("Tx_host")
                } 
        }
    }
    
    rule on_new_sensor {
        select when sensor:new_sensor
        pre {
            name = event:attr("name")

            check = sensors(name)
            eci = meta:eci

            rids = "temperature_store;sensor_profile;twilio_lesson_keys;twilio_m;wovyn_base"
        }
        
        if (check != null) then
            send_directive("name already taken", {"name":name})
        notfired {
            
            raise wrangler event "child_creation"
                attributes { 
                    "name": name, 
                    "color": "#555555",
                    "rids": rids 
                }
        }
    }

    rule delete_sensor {
        select when sensor:unneeded_sensor
        
        pre {
            name_to_delete = event:attr("name")

            check = sensors(name_to_delete)

        }
        if (check != null) then
            send_directive("deleting sensor", {"name": name_to_delete})
        fired {
            ent:sensors := ent:sensors.filter(
                function(s) {
                    s.get("name") != name_to_delete
                }
            )
            raise wrangler event "child_deletion"
                attributes {"name": name_to_delete};
        }
    }

    rule save_new_sensor {
        select when wrangler child_initialized
        pre {
            name = event:attr("name")
            eci = event:attr("eci")
            newSensor = {
                "name":name, 
                "eci":eci
            }

        }
        if name.klog("adding sensor")
        then
            event:send(
                {
                    "eci": eci,
                    "eid": "1337",
                    "domain": "sensor",
                    "type": "profile_updated",
                    "attrs": {
                        "name": name,
                        "threshold": default_threshold,
                        "phone_number": default_phone_number
                    }
                }
            )
        fired {
            ent:sensors := ent:sensors.defaultsTo([]).union([newSensor])
            raise sensor event "subscribe"
                attributes {
                    "name": name,
                    "wellKnown_Tx": eci
                }
        }
    }
    // HEsekZzRb64ZMkMWd5DRYU
    // after pico is done being made, send a sensor:profile_updated event to prime it


}
