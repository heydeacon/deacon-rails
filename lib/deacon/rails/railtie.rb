module Deacon
  module Rails
    # What config.deacon holds. A Struct rather than ordered options, so a misspelt setting
    # fails loudly at boot instead of being ignored.
    Configuration = Struct.new(:key, :context, :page_views)

    # Adds config.deacon to the app and deacon_widget_tag to its views.
    class Railtie < ::Rails::Railtie
      config.deacon = Configuration.new

      initializer "deacon.view_helper" do
        ActiveSupport.on_load(:action_view) { include Deacon::Rails::Helper }
      end
    end
  end
end
