class User
  attr_accessor :ws
  attr_accessor :name
  attr_accessor :score
  
  def initialize(ws, name)
    @ws = ws
    @name = name
    @score = 0
  end
  
  def trigger_event(event)
    @ws.send Event.export(event)
  end
end
