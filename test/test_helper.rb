ENV["RAILS_ENV"] = "test"

require "rails"
require "action_controller/railtie"
require "deacon/rails"
require "jwt"

# The smallest Rails app that renders a layout: the gem's own engine adds config.deacon,
# the helper and the token route, as it does in a founder's app.
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
    get "/account" => "account_pages#show"
  end
end

DummyApp.initialize!

# A page in an app with no way to say who is signed in.
class PagesController < ActionController::Base
  def show
    render inline: "<%= deacon_widget_tag %>"
  end
end

# Someone the dummy app can sign in, in Devise's shape: an id, an email and a name.
User = Struct.new(:id, :email, :name)

# Someone signed in with Rails 8's built-in authentication, whose User has an email_address.
BuiltInUser = Struct.new(:id, :email_address)

# Where Rails 8's built-in authentication keeps who is signed in.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
end

# The dummy app's own controller, which signs in whoever the user cookie names, as a Devise
# app's current_user does, and checks the CSRF token on every POST, as a new Rails app does.
class ApplicationController < ActionController::Base
  USERS = { "ana" => User.new(7, "ana@studio.com", "Ana Ruiz") }.freeze
  MEMBERS = { "bo" => User.new(12, "bo@studio.com", "Bo Chen") }.freeze
  BUILT_IN_USERS = { "s1" => BuiltInUser.new(21, "cy@studio.com") }.freeze

  protect_from_forgery with: :exception

  private

  def current_user
    USERS[cookies[:user]]
  end

  # A second kind of user, as an app with two Devise models has.
  def current_member
    MEMBERS[cookies[:member]]
  end

  # As Rails 8's built-in authentication does: resume the session cookie's user into Current.
  def authenticated?
    Current.user ||= BUILT_IN_USERS[cookies[:session_id]]
  end
end

# A page in the app that has someone signed in, or nobody.
class AccountPagesController < ApplicationController
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
    @saved_env_secret = ENV["DEACON_SECRET"]
    @saved_logger = Rails.logger
    @log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log)
    ENV.delete("DEACON_KEY")
    ENV.delete("DEACON_SECRET")
  end

  teardown do
    @saved_config.each { |name, value| Rails.application.config.deacon[name] = value }
    ENV["DEACON_KEY"] = @saved_env_key
    ENV["DEACON_SECRET"] = @saved_env_secret
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

  # The CSRF token the signed-in script sends, which Rails masks afresh on every render.
  def csrf_token_in(html)
    html[/"X-CSRF-Token": "([^"]+)"/, 1]
  end

  # The page with its CSRF token swapped for CSRF, so the rest can be compared exactly.
  def without_csrf_token(html)
    token = csrf_token_in(html)
    token.nil? ? html : html.sub(token, "CSRF")
  end
end
