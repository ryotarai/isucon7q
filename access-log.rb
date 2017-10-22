#!/home/isucon/local/ruby/bin/ruby

class Log
  def initialize(h)
    @h = h
  end

  def response_time
    # unit: ms
    @h['reqtime'].to_f * 1000
  end

  def endpoint
    case @h['method']
    when 'GET'
      case @h['uri']
      when '/'
        'GET /'
      when '/initialize'
        'GET /initialize'
      when '/add_channel'
        'GET /add_channel'
      when %r{\A/history/\d+\z}
        'GET /history/:id'
      when %r{\A/history/\d+\?page=\d+\z}
        'GET /history/:id?page=:page'
      when %r{\A/icons/[0-9a-f]+\.png\z}
        'GET /icons/:hex.png'
      when %r{\A/icons/[0-9a-f]+\.jpg\z}
        'GET /icons/:hex.jpg'
      when '/icons/default.png'
        'GET /icons/default.png'
      when '/register'
        'GET /register'
      when %r{\A/message\?channel_id=\d+&last_message_id=\d+\z}
        '/message?channel_id=:id&last_message_id=:id'
      when '/fetch'
        'GET /fetch'
      when '/login'
        'GET /login'
      when '/logout'
        'GET /logout'
      when %r{\A/profile/\w+\z}
        'GET /profile/:username'
      when %r{\A/channel/\d+\z}
        'GET /channel/:id'
      when %r{\A/css/.*\.css}
        'GET /css/*.css'
      when '/favicon.ico'
        'GET /favicon.ico'
      when %r{\A/fonts/.*}
        'GET /fonts/*'
      when %r{\A/js/.*\.js}
        'GET /js/*.js'
      end
    when 'POST'
      case @h['uri']
      when '/login'
        'POST /login'
      when '/add_channel'
        'POST /add_channel'
      when '/register'
        'POST /register'
      when '/message'
        'POST /message'
      when '/profile'
        'POST /profile'
      end
    end
  end

  def status
    @h['status'].to_i
  end
end

class Stat < Struct.new(:total_count, :total_time, :average)
end

stats = {}
status_stats = Hash.new { |h, k| h[k] = {} }

ARGF.each_line do |line|
  h = {}
  line.chomp.split("\t").each do |seg|
    key, val = seg.split(':', 2)
    if val =~ /\A\d+\z/
      val = val.to_i
    end
    h[key] = val
  end
  h['uri'] = h['uri'].sub(%r{\A//}, '/')
  next if h.size == 1
  next unless /benchmarker/ === h['ua']

  log = Log.new(h)
  e = log.endpoint
  unless e
    p h
    raise 'Unknown endpoint'
  end
  stats[e] ||= Stat.new(0, 0)
  stats[e].total_count += 1
  stats[e].total_time += log.response_time
  status_stats[e][log.status] ||= Stat.new(0, 0)
  status_stats[e][log.status].total_count += 1
  status_stats[e][log.status].total_time += log.response_time
end

stats.each do |_, stat|
  stat.average = stat.total_time.to_f / stat.total_count
end
status_stats.each do |_, ss|
  ss.each do |_, stat|
    stat.average = stat.total_time.to_f / stat.total_count
  end
end
stats.sort_by { |e, stat| -stat.total_time }.each do |e, stat|
  if stat.average >= 0
    meth, path = e.split(' ', 2)
    printf("%5s %-25s total %.2f s (access: %d, average: %.1f ms)\n", meth, path, stat.total_time / 1000.0, stat.total_count, stat.average)
    status_stats[e].each do |status, s|
      printf("\t%d total %.2f s (access: %d, average: %.1f ms)\n", status, s.total_time / 1000.0, s.total_count, s.average)
    end
  end
end

# vim: set et sw=2 sts=2 autoindent:
