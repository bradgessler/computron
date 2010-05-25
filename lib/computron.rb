dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

module Computron
  autoload :Client,     'computron/client'
  autoload :Simulation, 'computron/simulation'
  autoload :Report,     'computron/report'
end