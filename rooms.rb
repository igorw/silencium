require 'bundler'

Bundler.setup

require 'eventmachine'
require 'em-websocket'
require 'json'

require 'warren'
require 'warren/adapters/amqp_adapter'

require './model/event.rb'
require './model/room.rb'

require './lib/server_base.rb'
require './lib/room_server.rb'

EM.run {
  @server = Silencium::RoomServer.new
  @server.init_ws host: "0.0.0.0", port: 4001
  @server.init_mq :default, YAML::load("config/warren.yml")
}
