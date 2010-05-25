require '/Users/bgessler/Projects/imprezo/web/config/environment.rb'
require 'lib/computron'

clients_count = 2
post_interval = 10

clients = clients_count.times.map{ Computron::Client.new }

default_host 'localhost:3000'

get url('/events/1.json') do |response|
  response.ok {|json|
    event_id = json['event']['id']
    ticks_url = url("/events/#{event_id}/ticks/stream.json")

    clients.each do |client|
      client.long_poll ticks_url do |response, repoll|
        response.ok {|ticks|
          if last_tick = ticks.last
            repoll.url = "#{ticks_url}?since_id=#{last_tick['routing']['id']}"
          end
        }
      end

      every post_interval do
        client.post url("/events/#{event_id}/comments"), :body => Comment.new(:response => 'Hey!').to_json, :head => {'Content-Type' => 'application/json'} do |response|
          # response.ok             { p "Super fun" }
          # response.found          { p "Redirected" }
          # response.code(405)      { p "Method not supported jagoff" }
        end
      end
    end
  }
end