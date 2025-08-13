# Puma configuration for Rails 5.0.7.2 with Docker
# This file configures Puma 4.3.3 for the Consul application

# Ensure required directories exist (Windows Docker compatibility)
require 'fileutils'
begin
  FileUtils.mkdir_p('/var/www/consul/tmp/pids')
  FileUtils.mkdir_p('/var/www/consul/tmp/sockets')
  FileUtils.mkdir_p('/var/www/consul/log')
  puts "Puma: Required directories created successfully"
rescue => e
  puts "Puma: Warning - Could not create directories: #{e.message}"
  # Continue anyway - the entrypoint script should have handled this
end

# The directory to operate out of.
directory '/var/www/consul'

# Use "path" as the file to store the server info state. This is
# used by "pumactl" to query and control the server.
state_path '/var/www/consul/tmp/pids/puma.state'

# Redirect STDOUT and STDERR to files specified.
stdout_redirect '/var/www/consul/log/puma.stdout.log', '/var/www/consul/log/puma.stderr.log', true

# The default is "false".
daemonize false

# Bind the server to "url". "tcp://", "unix://" and "ssl://" are the only accepted protocols.
bind 'tcp://0.0.0.0:3000'

# Define the environment in which the app's code will run. Available environments are "development", "production" and "test".
environment ENV.fetch('RAILS_ENV', 'development')

# Store the pid of the server in the file at "path".
pidfile '/var/www/consul/tmp/pids/puma.pid'

# Use "path" as the file to store the server info state. This is
# used by "pumactl" to query and control the server.
# activate_control_app 'unix:///var/www/consul/tmp/sockets/pumactl.sock'

# Configure "min" to be the minimum number of threads to use to answer
# requests and "max" the maximum.
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Port is configured via bind directive below
# port ENV.fetch("PORT") { 3000 }

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked webserver processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
workers ENV.fetch("WEB_CONCURRENCY") { 1 }

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
preload_app!

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# The code in the `on_worker_boot` will be called if you are using
# clustered mode by specifying a number of `workers`. After each worker
# process is booted, this block will be run. If you are using the `preload_app!`
# option, you will want to use this block to reconnect to any threads
# or connections that may have been created at application boot, as Ruby
# cannot share connections between processes.
# Disabled for Docker single-threaded mode
on_worker_boot do
  # Worker specific setup for Rails 5.0.7.2
  # Valid for Rails 5.0+ only
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
