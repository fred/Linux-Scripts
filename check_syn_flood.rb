#!/bin/env ruby
# Will check if there are more than 40 SYN_REC from the same IP 
# Then block with iptables
@check = "SYN_REC"
@limit = 40
@iptables_command = "/sbin/iptables -I INPUT -s"
@iptables_action  = "-j DROP"
@count = []

# Using netstat here, Works on Linux and OSX
@netstat = `netstat -n | grep #{@check} | awk '{print $5}' | awk -F: '{print $1}' | sort -n | uniq -c`.split("\n")
@netstat.each do |t|
  @count << t.strip.split
end

@count.each do |t|
  @already_blocked = `iptables -nvL | grep 'DROP' | grep '#{t[1]}'`
  if t[0].to_i > @limit && @already_blocked.empty?
    puts "Going to block #{t[1]} , found #{t[0]} flood occurrences from that ip"
    command="#{@iptables_command} #{t[1]} #{@iptables_action}"
    `#{command}`
  end
end
