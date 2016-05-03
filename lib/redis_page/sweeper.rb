require 'redis_page/sweeper_worker'

module RedisPage
  module Sweeper
    extend ActiveSupport::Concern

    included do
      after_save :invalidate_instance_cache
      after_touch :invalidate_instance_cache
      after_destroy :invalidate_clazz_cache

      def invalidate_instance_cache
        urls = {}
        key = "i:#{self.class.table_name}:#{self.id}"
        Rails.logger.info "[page cache]invalidate: #{key}"
        RedisPage.redis.smembers(key).each do |info|
          RedisPage.redis.srem(key, info)
          add_infos(urls, info)
        end
        add_clazz_infos(urls)
        clear_info(urls)
        fetch_infos(urls)
      end

      def invalidate_clazz_cache
        urls = {}
        add_clazz_infos(urls)
        clear_info(urls)
        fetch_infos(urls)
      end

      private

      def clear_info(urls)
        urls.values.each do |info|
          cur_key = info['url'] + '-' + info['country']
          RedisPage.redis.del(cur_key)
        end
      end

      def add_infos(urls, info)
        info = JSON.parse(info)
        key = "#{info['url']}-#{info['country']}"
        urls[key] = info unless urls[key]
      end

      def add_clazz_infos(urls)
        key = "c:#{self.class.table_name}"
        Rails.logger.info "[page cache]invalidate: #{key}"
        RedisPage.redis.smembers(key).each do |info|
          RedisPage.redis.srem(key, info)
          add_infos(urls, info)
        end
      end

      def fetch_infos(urls)
        urls.values.each do |info|
          RedisPage::Sweeper.sweep info
        end
      end
    end

    def self.sweep(info)
      Rails.logger.info "[page cache]add sweeper job: #{info['url']}-#{info['country']}"
      SweeperWorker.perform_async(info['url'], info['country'])
    end
  end
end
