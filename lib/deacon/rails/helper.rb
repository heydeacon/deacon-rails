require "erb"
require "json"

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

        context = ::Rails.application.config.deacon.context
        deacon_check_context(context)

        attributes = { "data-key" => key }
        attributes["data-context"] = JSON.generate(context) unless context.nil?

        deacon_loader_tag(attributes)
      end

      private

      # A wrong type is a mistake in the app's code, so it raises, as any view error does.
      def deacon_check_context(context)
        return if context.nil?
        return if context.is_a?(Hash) && context.each_value.all? { |value| deacon_scalar?(value) }

        raise ArgumentError, "deacon-rails: config.deacon.context must be a hash whose values " \
                             "are strings, numbers or booleans."
      end

      def deacon_scalar?(value)
        value.is_a?(String) || value.is_a?(Integer) || value.is_a?(Float) || value == true || value == false
      end

      # The tag Install gives, with any of its other attributes between the key and async.
      def deacon_loader_tag(attributes)
        rendered = attributes.map { |name, value| %( #{name}="#{ERB::Util.html_escape(value)}") }.join

        %(<script src="#{LOADER_SRC}"#{rendered} async></script>).html_safe
      end
    end
  end
end
