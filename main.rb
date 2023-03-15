require 'discordrb'
require 'yaml'
require 'pry'
require 'httparty'

BAD_WORDS_FILE = './lists/bad_words.txt'.freeze
OPT_OUT_FILE = './lists/opt_out.txt'.freeze
USER_COUNTS_FILE = 'user_counts.yaml'.freeze

@opt_out_users = []
@bad_words = []
@user_counts = YAML.load_file(USER_COUNTS_FILE)

def select_mom_line(filename)
  lines = File.readlines("./moms/" + filename + ".txt").map(&:strip).reject(&:empty?)
  lines.sample unless lines.empty?
end

def get_parent_type_for_day
  parent_types = ["abusive", "ashamed", "conservative", "distant", "dommy", "manipulative", "neglectful"]
  week_number = Time.now.strftime("%U").to_i
  day_number = Time.now.strftime("%u").to_i
  parent_type_index = (week_number + day_number) % parent_types.length
  return parent_types[parent_type_index]
end

def load_bad_words
  @bad_words.clear
  File.readlines(BAD_WORDS_FILE).each do |line|
    word = line.strip
    next if word.empty? || word.start_with?('#')

    @bad_words << word.downcase
  end
end

def load_opt_out_users
  @opt_out_users.clear
  File.readlines(OPT_OUT_FILE).each do |line|
    user_id = line.strip
    next if user_id.empty? || user_id.start_with?('#')

    user = bot.user(user_id.to_i)
    @opt_out_users << user if user
  end
end

def get_insult
  response = HTTParty.get("https://evilinsult.com/generate_insult.php?lang=en&type=txt")
  response.body
end

# load arrays from files
load_opt_out_users
load_bad_words

# Initialize the bot with the bot token and prefix
bot = Discordrb::Commands::CommandBot.new(
  token: ENV["token"],
  prefix: '*'
)

# Define the help command
bot.command :help do |event, word|
  event.respond("commands: addword removeword emancipate adopt wordlist mood amibad")
end

# Define the help command
bot.command :amibad do |event|
  event.respond("You have been shamed: " + (@user_counts[event.user.id] || 0).to_s + " times")
end


# Define the help command
bot.command :mood do |event, word|
  event.respond("I'm feeling " + get_parent_type_for_day)
end

# Define the help command
bot.command :wordlist do |event, word|
  event.respond(@bad_words.inspect)
end

def pick_mom()
    today = Time.now.strftime("%w").to_i

    if today == 0 || today == 6
      parent_type = :distant
    elsif today == 1 || today == 3 || today == 5
      parent_type = :abusive
    else
      parent_type = :conservative
    end

    response = parent_types[parent_type].sample
end

#######################################################################

# Define the command to add a word to the list of bad words
bot.command :addword do |event, word|
  # Add the word to the bad words list
  File.open(BAD_WORDS_FILE, 'a') do |file|
    file.puts(word)
  end

  # Reload the bad words array
  load_bad_words
  event.respond("The word '#{word}' has been added to the bad words list.")
end

# Define the command to remove a word from the list of bad words
bot.command :removeword do |event, word|
  # Remove the word from the bad words list
  File.open(BAD_WORDS_FILE, 'r+') do |file|
    lines = file.readlines
    file.rewind
    file.truncate(0)

    lines.each do |line|
      file.write(line) unless line.strip.downcase == word.downcase
    end
  end
  # Reload the bad words array
  @bad_words.clear
  load_bad_words
  event.respond("The word '#{word}' has been removed from the bad words list.")
end

##############################Opt Out##################################
# Define the command to opt-out from message scanning
bot.command :emancipate do |event|
  user_id = event.user.id

  # Add the user to the opt-out list
  File.open(OPT_OUT_FILE, 'a') do |file|
    file.puts(user_id)
  end

  event.respond('You have been opted out of message scanning.')
end

# Define the command to opt-in to message scanning
bot.command :adopt do |event|
  user_id = event.user.id

  # Remove the user from the opt-out list
  lines = File.readlines(OPT_OUT_FILE)
  File.open(OPT_OUT_FILE, 'w') do |file|
    lines.each do |line|
      file.puts(line) unless line.strip == user_id.to_s
    end
  end

  event.respond('You have been opted back in to message scanning.')
end
###################################################################




bot.message do |event|
  user_id = event.user.id

  # Check if the user is opted-out before scanning
  if File.readlines(OPT_OUT_FILE).map(&:chomp).include?(user_id.to_s)
    next
  end

  # Check if the message contains any bad words
  if @bad_words.any? { |word| event.message.content.downcase.include?(word) }
    # Increment users forbidden word count
    @user_counts[user_id] ||= 0
    @user_counts[user_id] += 1

    # Write to YAML so we dont risk losing data
    File.write(USER_COUNTS_FILE, YAML.dump(@user_counts))
    
    # Send a message indicating that a forbidden word was used
    response = select_mom_line(get_parent_type_for_day)
    event.respond(response)
  elsif event.message.content.downcase.include?("mom,") && event.message.content.downcase.include?("is bullying me")
    # Respond to bullying message
    random_name = event.message.content.downcase.scan(/mom, (.*) is bullying me/).flatten.first
    response = "#{random_name.capitalize}, #{get_insult}"
    event.respond(response)
  end
end


# Start the bot
bot.run
