module RedisPage
  class SweeperWorker
    include Sidekiq::Worker

    def perform(url, country=nil)
      uri = URI(url)
      uri.port = RedisPage.sweeper[:port]

      auth = { username: RedisPage.sweeper[:username], password: RedisPage.sweeper[:password] }
      options = { basic_auth: auth }
      options[:cookies] = { country: country } if country

      Rails.logger.info "[page cache]sweeper fetching: #{url}, country: #{country}"
      response = HTTParty.get(uri, options)
      Rails.logger.debug "[page cache]sweeper response: #{response.body}"
    end
  end
end
