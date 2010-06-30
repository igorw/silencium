require 'bundler'

Bundler.setup

require 'eventmachine'
require 'em-websocket'
require 'json'

require 'warren'
require 'warren/adapters/amqp_adapter'

require './model/card.rb'
require './model/event.rb'
require './model/user.rb'

class SilenciumServer
  def initialize(name, port)
    @name = name
    @port = port
    
    @ws_channel = EM::Channel.new
    
    @cards = [
      Card.new('car', ['wheels', 'mercedes']),
      Card.new('github', ['git', 'hub']),
      Card.new('hell', ['god', 'satan', 'demon']),
      Card.new('beer', ['duff', 'drink']),
      Card.new('phpbb', ['forum', 'bulletin', 'board']),
    ]
    @old_cards = []
    @users = []
    @card = nil
    
    @time_remaining = 60
    @paused = true
    @game_over = false
    
    EM::PeriodicTimer.new(1) do
      if !@paused
        if @time_remaining == 0
          @paused = true
          next_round
        end
        
        @time_remaining -= 1
        
        trigger_time_sync
      end
    end
  end
  
  def reset
    @cards = @old_cards
    @old_cards = []
    @card = nil
    
    @time_remaining = 60
    @paused = true
    @game_over = false
    
    trigger_global_event Event.new(:reset)
    
    @users = []
  end
  
  def init_ws(options)
    EM::WebSocket.start(options) do |ws|
      ws.onopen {
        # outgoing message
        sid = @ws_channel.subscribe do |event|
          trigger_event ws, event
        end
        
        # client disconnect
        ws.onclose {
          @ws_channel.unsubscribe sid
          client_disconnect ws, sid
        }
        
        # incoming message
        ws.onmessage { |raw_event|
          event = Event.import(raw_event)
          receive_event ws, event
        }
        
        client_connect ws, sid
      }
    end
  end
  
  def init_mq(queue, options)
    @mq_queue = queue
    
    Warren::Queue.connection = options
    
    # contact room server
    EM::PeriodicTimer.new(5) do
      trigger_mq_event Event.new(:room_broadcast, {name: @name, port: @port, users: @users.size})
    end
  end
  
  def client_connect(ws, sid)
    log "Client connected: #{sid}"
    
    trigger_event ws, Event.new(:connect)
  end
  
  def client_disconnect(ws, sid)
    log "Client disconnected: #{sid}"
    
    remove_user ws
    user_count_changed :leave
  end
  
  def trigger_event(ws, event)
    ws.send Event.export(event)
  end
  
  def trigger_global_event(event)
    @users.each do |user|
      user.trigger_event event
    end
    
    log "Trigger global event: " + event.to_s
  end
  
  def trigger_mq_event(event)
    Warren::Queue.publish(@mq_queue, event)
  end
  
  def receive_event(ws, event)
    log "Received event: #{event.to_s}"
    
    user = find_user(ws)
    
    if event.name != :join && user.nil?
      log "Rejected #{event.name.to_s} event from non-joined user (ws: #{ws})"
      return
    elsif event.name == :guess && is_giver?(user)
      log "Giver trying to guess"
      return
    end
    
    case event.name
      when :join then
        error = false
        if event.data[:username].empty?
          error = "No username given"
        elsif find_user_name(event.data[:username])
          error = "Username already taken"
        end
        
        if error
          trigger_event ws, Event.new(:join, {accepted: false, username: event.data[:username], message: error})
        else
          @users << User.new(ws, event.data[:username])
          trigger_event ws, Event.new(:join, {accepted: true, username: event.data[:username]})
          trigger_event ws, Event.new(:debug, message: "joined game")
          user_count_changed :join
        end
      when :guess then
        correct = false
        
        # correct guess
        if event.data[:word] == @card.word
          user.score += 1
          find_giver.score += 1
          correct = true
          
          next_card
        end
        
        trigger_global_event Event.new(:guess, {username: user.name, word: event.data[:word], correct: correct})
      when :give then
        hint = event.data[:hint]
        
        regex = Regexp.new(Regexp.escape(@card.word) + '|' + @card.taboo_words.map { |word| Regexp.escape(word) }.join('|'))
        
        if regex.match(hint)
          find_giver.trigger_event Event.new(:system_message, message: "#{hint} is taboo, you fool")
        else
          trigger_global_event Event.new(:give, {username: user.name, hint: hint})
        end
    end
  end
  
  # called whenever a user joins or leaves
  # status is :join or :leave
  def user_count_changed(status = :join)
    # set up giver
    if @users.size > 0
      @card = @cards.first
      
      if @card.nil?
        game_over
        return
      end
      
      giver = find_giver
      giver.trigger_event Event.new(:become_giver)
      giver.trigger_event Event.new(:new_card, {word: @card.word, taboo_words: @card.taboo_words})
    end
    
    # check if more than one user is playing
    if @users.size == 1
      # only one guy left
      @paused = true
      trigger_global_event Event.new(:pause)
    elsif @users.size == 2 && status == :join
      # second user joined, game can continue
      @paused = false
      trigger_global_event Event.new(:unpause)
    end
    
    trigger_users
    trigger_time_sync
  end
  
  def find_user(ws)
    @users.each do |user|
      if ws === user.ws
        return user
      end
    end
  end
  
  def find_user_name(name)
    @users.each do |user|
      if name === user.name
        return user
      end
    end
    
    nil
  end
  
  def remove_user(ws)
    user = find_user(ws)
    @users.delete user
  end
  
  def find_giver
    @users.first
  end
  
  def is_giver?(user)
    user === find_giver
  end
  
  def next_round
    log "Next round"
    
    # first user becomes last
    @users << @users.shift
    
    find_giver.trigger_event Event.new(:become_giver)
    @users.last.trigger_event Event.new(:become_player)
    
    @time_remaining = 60
    @paused = false
    
    next_card
  end
  
  def next_card
    log "Next card"
    
    @old_cards << @cards.shift
    @card = @cards.first
    
    if @card.nil?
      game_over
      return
    end
    
    find_giver.trigger_event Event.new(:new_card, {word: @card.word, taboo_words: @card.taboo_words})
    trigger_users
  end
  
  def game_over
    log "Game over"
    
    if !@game_over
      EM::Timer.new(10) do
        reset
      end
    end
    
    @paused = true
    @game_over = true
    
    scoreboard = @users.sort {|a, b| a.score <=> b.score }.map { |user| {name: user.name, score: user.score} }.reverse
    trigger_global_event Event.new(:game_over, users: scoreboard)
  end
  
  def trigger_time_sync
    trigger_global_event Event.new(:time_sync, time_remaining: @time_remaining)
  end
  
  def trigger_users
    trigger_global_event Event.new(:users, users: @users.map { |user| {name: user.name, giver: is_giver?(user), score: user.score} })
  end
  
  def log(message)
    puts "[#{Time.new.strftime("%H:%M:%S")}] #{message}"
  end
end

if ARGV.size < 2
  puts "Usage: server NAME PORT"
  exit
end

name = ARGV[0].to_s
port = ARGV[1].to_i

EM.run {
  @server = SilenciumServer.new(name, port)
  @server.init_ws host: "0.0.0.0", port: port
  @server.init_mq :default, YAML::load("config/warren.yml")
}
