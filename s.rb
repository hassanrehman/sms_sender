#contacts only work for Pakistan, with a +92 prefix .. 

$__contacts_string = "
me:3214321640
example:3214567892
"

$sleep_time = 2    #seconds

#only works for my local
$adb_path = "/home/sagii/apps/android/adt-bundle-linux-x86_64/sdk/platform-tools/adb"


require "readline"

def contacts
  @contacts ||= $__contacts_string.strip.split("\n").map(&:strip).inject({}) do |s, i| 
    t = i.split(":").map(&:strip)
    s.merge!(t[0] => t[1])
  end
end

#gets 1000th of a second .. and returns the last 5 characters
def timestamp
  (Time.now.to_f * 1000).ceil.to_s[-5..-1]
end

def help
  "Usage:
  ruby s \"message\" <recipient(s)>
    sends a message to one or more recipients. Recipients could be pre-saved numbers or phone numbers
    in the format: 3214321640
    e.g. ruby s \"how you doing man\" hassan
    e.g. ruby s \"happy holidays guys\" \"hassan, 3214321640, mom, dad\"
  OR
  ruby s <recipient>
    the above command will open an interactive console ONE recipient
    type help in that console for further commands available
    e.g. ruby s hassan
    e.g. ruby s 3214321640
  ".strip
end

def help_interactive_mode
  "In interactive mode, just write a message on the prompt to send the message.
    hassan: this sms will go to the contact hassan
  You can send a single message to another recipient with a 'to' command as follows.
    hassan: to:tj this sms will belongs to tj .. but the prompt will stay with hassan
  You can switch to a different contact with the 'switch' command
    hassan: switch:tj
    tj: the prompt is now set to tj. This message itself is going to tj.
  Use 'exit' to come exit program
  ".strip
end

def is_phone_valid?(number)
  /^3\d{9}$/ =~ number
end

def phone_number(recipient, country_code=false)
  return "#{"+92" if country_code}#{contacts[recipient]}" if contacts[recipient]
  return "#{"+92" if country_code}#{recipient}" if is_phone_valid?(recipient)
end

def extract_recipients(arg_string)
  (arg_string||"").split(",").map(&:strip).inject({}) do |recipients, single|
    recipients.merge!(single => phone_number(single))
  end
end

def send_sms(message, number)
  if $sleep_time > 0
    puts "waiting for #{$sleep_time} seconds..."
    sleep($sleep_time)
  end

  #write the file with the text
  base_path = `pwd`.strip
  File.open("#{base_path}/s_tmp", 'w'){|f| f.print message }
  `#{$adb_path} push #{base_path}/s_tmp /sdcard/sagi_sms_sender/#{number}_#{timestamp}`
end

def process_message(message, recipients, verbose = true)
  recipients.each do |_alias, number|
    puts "Sending to #{_alias} (#{number})" if verbose
    send_sms(message, number)
  end
end

#takes a string, extracts just one recipient (or throws an error) and
#run the block on that one recipient hash
def for_one_recipient(recipient_string)
  recipients = extract_recipients(recipient_string)
  if recipients.length == 1
    if recipients.values.first.nil?
      puts "ERROR: Illegal recipient: #{recipients.keys.first}"
      puts "run 'ruby s help' to see proper usage"
      puts "if in interactive mode, just type 'help'"
    else
      yield(recipients)
    end
  else
    puts "ERROR: only one recipient is allowed in interactive mode. run 'ruby s help' to see more."
  end
end

def analyse_message_for_commands(message)
  return :break if message.downcase == "exit"
  return :next if message.length == 0

  if message.strip == "help"
    puts help_interactive_mode
    return :next
  end

  #to:recipient command
  command, param = message.split(/\s+/).first.split(":").map(&:strip)
  if command == "to"
    new_message = message.gsub("#{command}:#{param}", "").strip
    for_one_recipient(param) do |recipients|
      process_message(new_message, recipients)
    end
    return :next
  end

  #switch:recipient command
  if command == "switch"
    for_one_recipient(param) do |recipients|
      run_interactive(recipients)
      return :break
    end
    return :next
  end

  return nil
end

#http://bogojoker.com/readline/
# Smarter Readline to prevent empty and dups
#   1. Read a line and append to history
#   2. Quick Break on nil
#   3. Remove from history if empty or dup
#
def readline_with_hist_management(prompt = "> ")
  line = Readline.readline(prompt, true)
  return "" if line.nil?
  if line =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == line
    Readline::HISTORY.pop
  end
  line
end

#hash will have only one recipient .. need to check that first
def run_interactive(recipients)
  _alias = recipients.keys.first
  number = recipients.values.first
  puts "starting interactive mode for: #{_alias} (#{number})"

  loop do
    begin
      message = readline_with_hist_management("#{_alias}: ")
      action = analyse_message_for_commands(message)
      break if action == :break
      next if action == :next

      process_message(message, {_alias => number}, false)

    rescue Interrupt => i
      puts "Interrupted.."
    end
  end
end

def main(args)
  args = $*
  if args.length == 2
    recipients = extract_recipients(args[1])
    if recipients.any?{|k, v| v.nil? }
      puts "ERROR: Illegal recipient(s): #{recipients.select{|k, v| v.nil? }.keys.join(", ")}"
      puts "run 'ruby s help' to see proper usage"
    else
      process_message(args[0], recipients)
    end
  elsif args.length == 1
    arg = args[0].strip
    if arg == "help"
      puts help
    else   #has to be a recipient
      for_one_recipient(arg) do |recipients|
        run_interactive(recipients)
      end
    end
  else
    puts "ERROR: Invalid number of arguments."
    puts help
  end
end

main($*)
