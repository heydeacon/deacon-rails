require "erb"

module Deacon
  module Rails
    # The view helper the layout calls once, in its head.
    module Helper
      LOADER_SRC = "https://heydeacon.com/widget/v1/loader.js".freeze

      # The tag Install gives, with the key from config.deacon.key, or from DEACON_KEY when
      # the app sets none.
      def deacon_widget_tag
        key = ::Rails.application.config.deacon.key || ENV["DEACON_KEY"]

        %(<script src="#{LOADER_SRC}" data-key="#{ERB::Util.html_escape(key)}" async></script>).html_safe
      end
    end
  end
end
