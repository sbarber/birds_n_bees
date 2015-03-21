#!/usr/bin/env ruby

require 'tweetstream'
require 'yaml'
require 'pp'
require 'slack-notifier'

class Birdsnbees

  def initialize(config_file="./config.yaml")
    @config = ::YAML.load_file config_file

    TweetStream.configure do |config|
      config.consumer_key       = @config['consumer_key']
      config.consumer_secret    = @config['consumer_secret']
      config.oauth_token        = @config['oauth_token']
      config.oauth_token_secret = @config['oauth_token_secret']
      config.auth_method        = :oauth
      config.parser             = :json_gem
    end

    @client = TweetStream::Client.new
    @slack = Slack::Notifier.new( @config['webhook_url'],
                                  channel: @config['slack_channel'],
                                  username: "BuzzBot" )

    puts "Tracking theses keywords: \n#{(@config['searches']).join(', ')}\n\n" 

    @client.on_error do |message|
      puts "ERROR: #{message}"
    end.on_reconnect do |timeout, retries|
      puts "ERROR: Reconnect failed. Timeout: #{timeout} | Retries #{retries}"
    end.track(@config['searches']) do |status|
      if filter(status)
        to_slack(status)
      end
      puts "-------\n"
    end

  end

  def filter(status)
    care = true
    
    if status.lang != "en" # Only english tweets
      cuz = "non-english tweet"
      care = false
    elsif status.text[0..1] == "RT" # Week retweet detection
      cuz = "retweet"
      care = false
    elsif words_filter(status)
      cuz = "words filter"
      care = false
    end

    if !care
      puts " *filtered cuz #{cuz} -- #{status.text}"
    end

    care
  end

  def words_filter(status)
    text = status.text.downcase

    has_good = false
    has_bad  = false

    @config['good_words'].each do |good|
      if text.include? good
        has_good = true
        break
      end
    end

    @config['bad_words'].each do |bad|
      if text.include? bad
        puts "BAD WORD: #{bad}"
        has_bad = true
        break
      end
    end

    if has_bad
      result = has_good
    else
      result = true
    end

    !result
  end

  def to_slack(status)
    puts "#{status.text}"
    message = "[#{status.user.screen_name}](http://twitter.com/#{status.user.screen_name}/status/#{status.id}): #{status.text}"
    @slack.ping message, icon_emoji: ':bee:', unfurl_media: false, unfurl_links: false
  end

end 


bot = Birdsnbees.new

