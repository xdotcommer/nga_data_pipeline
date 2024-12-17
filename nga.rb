require 'dotenv'
module NGA
  def self.load_env
    Dotenv.load
  end
end

NGA.load_env
