ruleset manage_profile {

    meta {
        use module twilio_lesson_keys
        use module twilio_m alias twilio
            with account_sid = keys:twilio{"account_sid"}
                auth_token =  keys:twilio{"auth_token"}
        
    }

    global {
        phone_number = "+18013100486"
    }


    rule threshold_notification {
        select when wovyn:threshold_violation
        pre {
            message = "The current temperature of " + 
                event:attr("temperature") +
                " has violated the threshold of " +
                event:attr("threshold") +
                " at " +
                event:attr("timestamp") + 
                "."
        }
        twilio:send_sms(phone_number,
                       "+12029911769",
                       message)
    }
}