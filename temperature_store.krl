ruleset temperature_store {

    meta {
        provides temperatures, threshold_violations, inrange_temperatures, last_temperature
        shares temperatures, threshold_violations, inrange_temperatures, last_temperature, __testing
    }

    global {
        temperatures = function() {
            ent:temps
        }

        threshold_violations = function() {
            ent:violations
        }

        inrange_temperatures = function() {
            ent:temps.difference(ent:violations)
        }

        last_temperature = function() {
            ent:temps[ent:temps.length() - 1]
        }

        __testing = { "queries": [],
            "events":  
            [ 
                { 
                    "domain": "sensor", "type": "reading_reset", "attrs": [ ] 
                }
            ] 
        }

    }

    rule collect_temperatures {
        select when wovyn:new_temperature_reading

        always {
            ent:temps := ent:temps.defaultsTo([]).append({"temperature":event:attr("temperature"), "timestamp":event:attr("timestamp")})
        }

    }

    rule collect_threshold_violations {
        select when wovyn:threshold_violation
        
        always {
            ent:violations := ent:violations.append({"temperature":event:attr("temperature"), "timestamp":event:attr("timestamp")})
        }

    }

    rule clear_temperatures {
        select when sensor:reading_reset
        always {    
            ent:temps := []
            ent:violations := []
        }
    }
}