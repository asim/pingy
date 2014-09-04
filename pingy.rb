require 'rubygems'
require 'bundler/setup'
require 'json'

Bundler.require

@dir = File.dirname(__FILE__)
require @dir + '/lib/pingy'
settings = ENV['RACK_ENV'] == 'production' ? YAML::load_file(@dir + '/pingy.yml') : {}

PINGY = Pingy.new(settings)

# background thread for host checks
Thread.new do
  loop do
    sleep 30
    PINGY.timed_jobs
  end
end

before %r{/(host)?} do
  @info = PINGY.info
end

get '/' do
  @hosts = PINGY.get_all_hosts
  erb :index
end

get '/host/:ip' do
  if params[:ip] && params[:ip] =~ /^(\d{1,3}\.){3}\d{1,3}$/
    @ip      = params[:ip]
    @details = PINGY.get_host(params[:ip])
    @host    = PINGY.get_host_data(params[:ip])
    if @host['service'].class != Array
      @host['service'] = [@host['service']]
    end
    erb :host
  else
    return 404
  end
end

post '/collector' do
  content_type :xml
  request.body.rewind
  data = request.body.read
  PINGY.update(request.ip, data)
end

helpers do
  def label(key, value)
    # service types
    type = {}
    type[0] = 'FILESYSTEM'
    type[1] = 'DIRECTORY'
    type[2] = 'FILE'
    type[3] = 'PROCESS'
    type[4] = 'HOST'
    type[5] = 'SYSTEM'
    type[6] = 'FIFO'
    type[7] = 'PROGRAM'

    monitor = {}
    monitor[0] = 'NOT'
    monitor[1] = 'YES'
    monitor[2] = 'INIT'
    monitor[4] = 'WAITING'

    every = {}
    every[0] = 'CYCLE'
    every[1] = 'SKIPCYCLES'
    every[2] = 'CRON'
    every[3] = 'NOTINCRON'

    state = {}
    state[0] = 'SUCCEEDED'
    state[1] = 'FAILED'
    state[2] = 'CHANGED'
    state[3] = 'CHANGEDNOT'
    state[4] = 'INIT'

    action = {}
    action[0] = 'IGNORE'
    action[1] = 'ALERT'
    action[2] = 'RESTART'
    action[3] = 'STOP'
    action[4] = 'EXEC'
    action[5] = 'UNMONITOR'
    action[6] = 'START'
    action[7] = 'MONITOR'

    case key
      when 'type'
        return type[value.to_i] rescue ''
      when 'monitor'
        return monitor[value.to_i] rescue ''
      else
        return value
    end
  end
end
