# name: onlyoffice-discourse-footer
# about: Info about active users in footer
# version: 0.1
# authors: Ascensio System SIA

enabled_site_setting :onlyoffice_discourse_footer_enabled

PLUGIN_NAME ||= "onlyoffice-discourse-footer".freeze

after_initialize do
    module ::OnlyofficeWhosOnline
        class Engine < ::Rails::Engine
            engine_name PLUGIN_NAME
            isolate_namespace OnlyofficeWhosOnline
        end
    end

    module ::OnlyofficeWhosOnline::OnlineManager

        def self.redis_key
            "onlyoffice_whosonline_users"
        end

        def self.add(user_id, hidden, anonymous)
            Discourse.redis.hset(redis_key, user_id, {time: Time.zone.now, hidden: hidden, anonymous: anonymous}.to_json)
        end

        def self.remove(user_id)
            Discourse.redis.hdel(redis_key, user_id) > 0
        end

        def self.get_users_info
            online_count = 0
            hidden_count = 0
            anonymous_count = 0

            hash = Discourse.redis.hgetall(redis_key)
            hash.each do |user_id, user_hash_info|
                online_count += 1

                user_prop = JSON.parse(user_hash_info)

                if user_prop["hidden"]
                    hidden_count += 1
                end

                if user_prop["anonymous"]
                    anonymous_count += 1
                end

            end
            {
                online: online_count, 
                hidden: hidden_count,
                anonymous: anonymous_count
            }
        end

        def self.cleanup
            active_time_ago = 5.minutes

            hash = Discourse.redis.hgetall(redis_key)
            hash.each do |user_id, user_hash_info|
                user_prop = JSON.parse(user_hash_info)

                if Time.zone.now - Time.parse(user_prop["time"]) >= active_time_ago
                    remove(user_id)
                end
            end
        end
    end

    require_dependency "application_controller"

    class OnlyofficeWhosOnline::WhosOnlineController < ::ApplicationController
        requires_plugin PLUGIN_NAME
    
        def on_request
            render json: { users: ::OnlyofficeWhosOnline::OnlineManager.get_users_info }
        end
    end

    OnlyofficeWhosOnline::Engine.routes.draw do
        get "/get" => "whos_online#on_request"
    end

    ::Discourse::Application.routes.append do
        mount ::OnlyofficeWhosOnline::Engine, at: "/whosonline"
    end

    on(:user_seen) do |user|
        hidden = false
        anonymous = false

        hidden = user.user_option.hide_profile_and_presence if defined? user.user_option.hide_profile_and_presence
        anonymous = user.anonymous?

        ::OnlyofficeWhosOnline::OnlineManager.add(user.id, hidden, anonymous)
    end

    module ::Jobs
        class WhosOnlineGoingOffline < ::Jobs::Scheduled
            every 1.minutes
      
            def execute(args)
                OnlyofficeWhosOnline::OnlineManager.cleanup
            end
        end
    end
end