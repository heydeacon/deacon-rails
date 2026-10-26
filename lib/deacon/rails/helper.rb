require "erb"

module Deacon
  module Rails
    # The view helper the layout calls once, in its head.
    module Helper
      LOADER_SRC = "https://heydeacon.com/widget/v1/loader.js".freeze

      MISSING_KEY = "deacon-rails: the key is missing, so the page has no Deacon widget. Set " \
                    "DEACON_KEY or config.deacon.key. In Deacon, open Install (the button at the " \
                    "top of the dashboard) and copy the data-key value from the snippet. It " \
                    "starts with pk_.".freeze

      # The tag Install gives, with the key from config.deacon.key, or from DEACON_KEY when
      # the app sets none. With no key it prints nothing and logs a warning, so a missing
      # setting never takes a page down.
      def deacon_widget_tag
        key = (::Rails.application.config.deacon.key || ENV["DEACON_KEY"]).to_s.strip

        if key.empty?
          ::Rails.logger&.warn(MISSING_KEY)
          return
        end

        %(<script src="#{LOADER_SRC}" data-key="#{ERB::Util.html_escape(key)}" async></script>).html_safe
      end
    end
  end
end
