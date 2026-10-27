require "erb"
require "json"
require "securerandom"

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
        key = (deacon_config.key || ENV["DEACON_KEY"]).to_s.strip

        if key.empty?
          ::Rails.logger&.warn(MISSING_KEY)
          return
        end

        context = deacon_config.context
        page_views = deacon_config.page_views
        signed_in = deacon_config.signed_in
        deacon_check_context(context)
        deacon_check_boolean(:page_views, page_views)
        deacon_check_boolean(:signed_in, signed_in)

        attributes = { "data-key" => key }
        attributes["data-context"] = JSON.generate(context) unless context.nil?
        attributes["data-no-page-views"] = true if page_views == false

        csp_nonce = deacon_csp_nonce
        script = signed_in == false ? nil : deacon_signed_in_script(csp_nonce)

        "#{script}#{deacon_loader_tag(attributes, csp_nonce)}".html_safe
      end

      private

      # Who is signed in, for the loader to read as it starts, so it goes above the loader tag.
      # The token function asks the app's own POST /deacon/token to sign them when the chat
      # opens, sending the CSRF token as every other POST in the app does. With nobody signed
      # in it signs the visitor out, so a sign-out ends Deacon's proof of who they were. An app
      # with no way to say who is signed in gets neither.
      def deacon_signed_in_script(csp_nonce)
        user = CurrentUser.find(controller)
        return if user == :unknown

        code = if user.nil?
                 "window.deaconUser = null; window.Deacon?.identify(null);"
               else
                 "window.deaconUser = #{deacon_user_object(user)}; " \
                   "window.Deacon?.identify(window.deaconUser);"
               end

        deacon_script(code, csp_nonce)
      end

      # The user's id, email and name, and the token function: written as code rather than
      # JSON, since a function has no JSON.
      def deacon_user_object(user)
        headers = { "Content-Type" => "application/json" }
        headers["X-CSRF-Token"] = form_authenticity_token if protect_against_forgery?
        path = ::Rails.application.routes.url_helpers.deacon_token_path

        token = "(nonce) => fetch(#{deacon_js(path)}, { method: \"POST\", " \
                "credentials: \"same-origin\", headers: #{deacon_js_object(headers)}, " \
                "body: JSON.stringify({ nonce }) })" \
                '.then((r) => (r.status === 200 ? r.text() : ""))'

        fields = { id: user.id, email: user.email, name: user.name }.compact
        fields = fields.map { |name, value| "#{name}: #{deacon_js(value)}" }

        "{ #{[*fields, "token: #{token}"].join(', ')} }"
      end

      # A string as JavaScript, escaped so nothing in it can end the script it sits in.
      def deacon_js(value)
        ERB::Util.json_escape(JSON.generate(value.to_s))
      end

      def deacon_js_object(hash)
        "{ #{hash.map { |name, value| "#{deacon_js(name)}: #{deacon_js(value)}" }.join(', ')} }"
      end

      # Turbo Drive keeps the head between visits and runs a script in the new page's head only
      # when none just like it is there, so each page's is made unlike the last one's. Otherwise a
      # sign-in or sign-out back to someone the head has seen before would never reach Deacon.
      def deacon_script(code, csp_nonce)
        render = SecureRandom.hex(8)

        %(<script data-deacon-render="#{render}"#{deacon_nonce_attribute(csp_nonce)}>#{code}</script>)
      end

      def deacon_nonce_attribute(csp_nonce)
        csp_nonce.nil? ? "" : %( nonce="#{ERB::Util.html_escape(csp_nonce)}")
      end

      def deacon_config
        ::Rails.application.config.deacon
      end

      # The request's Content Security Policy nonce, when the app has a nonce generator and the
      # page was rendered for a request.
      def deacon_csp_nonce
        content_security_policy_nonce if respond_to?(:content_security_policy_nonce)
      end

      # A wrong type is a mistake in the app's code, so it raises, as any view error does.
      def deacon_check_context(context)
        return if context.nil?
        return if context.is_a?(Hash) && context.each_value.all? { |value| deacon_scalar?(value) }

        raise ArgumentError, "deacon-rails: config.deacon.context must be a hash whose values " \
                             "are strings, numbers or booleans."
      end

      def deacon_check_boolean(name, value)
        return if value.nil? || value == true || value == false

        raise ArgumentError, "deacon-rails: config.deacon.#{name} must be true or false."
      end

      def deacon_scalar?(value)
        value.is_a?(String) || value.is_a?(Integer) || value.is_a?(Float) || value == true || value == false
      end

      # The tag Install gives, with any of its other attributes between the key and async, and
      # the nonce after them. An attribute that is true is written with no value, as async is.
      def deacon_loader_tag(attributes, csp_nonce)
        rendered = attributes.map do |name, value|
          value == true ? " #{name}" : %( #{name}="#{ERB::Util.html_escape(value)}")
        end.join

        %(<script src="#{LOADER_SRC}"#{rendered} async#{deacon_nonce_attribute(csp_nonce)}></script>)
          .html_safe
      end
    end
  end
end
