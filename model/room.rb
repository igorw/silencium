class Room
  attr_accessor :name
  attr_accessor :port
  attr_accessor :users
  attr_accessor :updated
  
  def initialize(name, port, users = 0)
    @name = name
    @port = port
    @users = users
    @updated = Time.new
  end
  
  def alive
    @updated = Time.new
  end
  
  def update(users)
    @users = users
  end
end
