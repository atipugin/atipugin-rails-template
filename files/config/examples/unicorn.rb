worker_processes 1
timeout 15
preload_app true

before_fork do |server, _|
  old_pid = "#{server.config[:pid]}.oldbin"
  if File.exist?(old_pid) && server.pid != old_pid
    begin
      Process.kill('QUIT', File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # Nothing to do here...
    end
  end

  Signal.trap 'TERM' do
    Process.kill 'QUIT', Process.pid
  end

  ActiveRecord::Base.connection.disconnect! if defined?(ActiveRecord::Base)
end

after_fork do |_server, _worker|
  Signal.trap 'TERM' do
    # Do nothing :)
  end

  ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
end
