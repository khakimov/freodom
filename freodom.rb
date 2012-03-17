require 'fileutils'

BlockSites = [
  'facebook.com',
  '*.tumblr.com',
  'news.ycombinator.com',
  'leprosorium.ru',
  'habrahabr.ru',
  'reddit.com'
]


class IMStatus
  STATUSES = %w{online available offline away dnd invisible}

  def initialize(status, message = nil)
    @status = status
    @message = message.gsub('"', '\\"') unless message.nil?
  end

  def status(client)
    if (client == :ichat or client == :adium) and @status == "dnd"
      "away"
    elsif (client == :ichat or client == :adium) and @status == "online"
      "available"
    elsif client == :skype and @status == "available"
      "online"
    else
      @status
    end
  end

  def message(client)
    if @message.nil? and (client == :ichat or client == :adium) and @status == "dnd"
      "Do not disturb"
    else
      @message
    end
  end

  def ichat_status
    "set status to #{status(:ichat)}"
  end
  def ichat_message
    if message = message(:ichat)
      %{set status message to "#{message}"}
    end
  end

  def adium_status
    "go #{status(:adium)}"
  end
  def adium_message
    if message = message(:adium)
      %{set status message of every account to "#{message}"}
    end
  end
  def adium_status_with_message
    unless message = message(:adium)
      adium_status
    else
      %{#{adium_status} with message "#{message}"}
    end
  end

  def skype_status
    %{send command "set userstatus #{status(:skype)}" script name "imstatus"}
  end
  def skype_message
    if message = message(:skype)
      %{send command "set profile mood_text #{message}" script name "imstatus"}
    end
  end

  def applescript
    %Q{
      tell application "System Events"
        if exists process "iChat" then
          tell application "iChat"
            #{ichat_status}
            #{ichat_message}
          end tell
        end if
        if exists process "Adium" then
          tell application "Adium"
            #{adium_status_with_message}
          end tell
        end if
        if exists process "Skype" then
          tell application "Skype"
            #{skype_status}
            #{skype_message}
          end tell
        end if
      end tell
    }
  end

  def run_applescript
    IO.popen("osascript", "w") { |f| f.puts(applescript) }
  end
end

class Blocker
  HOSTS_FILE = "/etc/hosts"
  def initialize
    @host = File.open(HOSTS_FILE, "a")
  end

  def block(block_list)
    backup_hosts
    block_list.each do |site|
      @host.puts("127.0.0.1 #{site}\n")
    end
    IMStatus.new("dnd", "put off procrastionation").run_applescript
  end

  def self.unblock
    FileUtils.mv(HOSTS_FILE + ".backup", HOSTS_FILE)
    IMStatus.new("online", "Until an asteroid...").run_applescript
  rescue Errno::ENOENT
    p "Already unblocked"
  end

  def backup_hosts
    unless File.exist?(HOSTS_FILE + ".backup")
      FileUtils.copy(HOSTS_FILE, HOSTS_FILE + ".backup")
    end
  end
end

if ENV['USER'] == 'root'
  puts ARGV
  
  case ARGV[0]
  when "activate" 
    puts "Do work!"
    Blocker.new.block(BlockSites)
  when "deactivate"
    puts "Have a fun!"
    Blocker.unblock
  else
    puts <<-EOS
  USAGE: #{File.basename($0)} activate/deactivate
         Do work or have a fun!    
    EOS
    exit 1
  end
else 
  system "sudo ruby #{File.basename($0)} #{ARGV[0]}"
end

