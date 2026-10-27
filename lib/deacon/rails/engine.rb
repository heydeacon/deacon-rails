module Deacon
  module Rails
    # What config.deacon holds. A Struct rather than ordered options, so a misspelt setting
    # fails loudly at boot instead of being ignored.
    Configuration = Struct.new(:key, :context, :page_views)

    # Adds config.deacon to the app, deacon_widget_tag to its views and POST /deacon/token to its
    # routes. An engine rather than a plain Railtie, so the app loads the token route's
    # controller with its own, after the ApplicationController it inherits.
    class Engine < ::Rails::Engine
      config.deacon = Configuration.new

      initializer "deacon.view_helper" do
        ActiveSupport.on_load(:action_view) { include Deacon::Rails::Helper }
      end

      # Ahead of the app's own routes, so a catch-all route of its own never answers instead.
      initializer "deacon.token_route" do |app|
        app.routes.prepend do
          post "/deacon/token" => "deacon/rails/tokens#create", as: :deacon_token
        end
      end
    end
  end
end
