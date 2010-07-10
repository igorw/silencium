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

require './lib/server_base.rb'
require './lib/game_server.rb'

if ARGV.size < 3
  puts "Usage: server NAME PORT CARDS_FILE"
  puts "CARDS_FILE is a json file"
  exit
end

name = ARGV[0].to_s
port = ARGV[1].to_i
cards_file = ARGV[2].to_s

cards = []

all_cards = JSON.parse(File.read(cards_file)).sort_by { rand }
(1..50).each do
  raw_card = all_cards.shift
  cards << Card.new(raw_card[0], raw_card[1])
end
all_cards = nil

EM.run {
  @server = Silencium::GameServer.new(name, port, cards)
  @server.init_ws host: "0.0.0.0", port: port
  @server.init_mq :default, YAML::load("config/warren.yml")
}
