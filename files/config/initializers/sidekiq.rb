%w(server client).each do |type|
  Sidekiq.send "configure_#{type}" do |config|
    config.redis = Settings
      .redis
      .to_hash
      .merge(namespace: "#{Settings.redis.namespace}:sidekiq")
  end
end
