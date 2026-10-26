ENV["RAILS_ENV"] = "test"

require "rails"
require "action_controller/railtie"
require "deacon/rails"

# The smallest Rails app that renders a layout: the gem's own Railtie adds config.deacon and
# the helper, as it does in a founder's app.
class DummyApp < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.logger = ActiveSupport::Logger.new(nil)
  config.secret_key_base = "test" * 16
  config.hosts.clear
  config.action_dispatch.show_exceptions = :none

  routes.append do
    get "/" => "pages#show"
    get "/with-nonce" => "nonce_pages#show"
  end
end

DummyApp.initialize!

class PagesController < ActionController::Base
  def show
    render inline: "<%= deacon_widget_tag %>"
  end
end

# A page whose app gives each request a Content Security Policy nonce, as an app does with
# config.content_security_policy_nonce_generator.
class NoncePagesController < PagesController
  before_action { request.content_security_policy_nonce_generator = ->(_request) { "n0nce" } }
end

require "rails/test_help"

class DeaconTest < ActionDispatch::IntegrationTest
  setup do
    @saved_config = Rails.application.config.deacon.to_h
    @saved_env_key = ENV["DEACON_KEY"]
    @saved_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
    ENV.delete("DEACON_KEY")
  end

  teardown do
    @saved_config.each { |name, value| Rails.application.config.deacon[name] = value }
    ENV["DEACON_KEY"] = @saved_env_key
    Rails.logger = @saved_logger
  end

  # What the layout's <%= deacon_widget_tag %> printed.
  def rendered_tag(path = "/")
    get path
    assert_response :success
    response.body
  end

  def logged
    @log.string
  end
end
