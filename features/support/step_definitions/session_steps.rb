Given "the log file contains a login request for {string} from {string}" do |email, ip|
  append_to_log(generate_login_log(email: email, ip: ip))
end

Given "the log file contains a login request for {string} from {string} at {string}" do |email, ip, timestamp|
  append_to_log(generate_login_log(email: email, ip: ip, timestamp: timestamp))
end

Given "the log file contains a logout request from {string}" do |ip|
  append_to_log(generate_logout_log(ip: ip))
end
