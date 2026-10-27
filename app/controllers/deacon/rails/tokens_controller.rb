require "jwt"

module Deacon
  module Rails
    # POST /deacon/token, which the page's token function calls when the chat opens: a token
    # saying who is signed in, signed with DEACON_SECRET, for Deacon to check. It inherits the
    # app's ApplicationController, so it finds the user as the app's own pages do and checks the
    # CSRF token as every other POST in the app does.
    class TokensController < ::ApplicationController
      # How long a token lasts. Deacon refuses one that lasts more than 15 minutes.
      LIFETIME = 10 * 60

      # The widget session's nonce, which the token carries so it proves who is signed in to that
      # session and no other. Deacon's are hex; anything far from that isn't one.
      NONCE = /\A[A-Za-z0-9_-]{1,128}\z/

      MISSING_SECRET = "deacon-rails: DEACON_SECRET is missing, so the token route signs nobody " \
                       "and Deacon can't verify who is signed in. In Deacon, open Install (the " \
                       "button at the top of the dashboard) and make a secret under Verify who's " \
                       "signed in. It starts with dk_sec_.".freeze

      # The route answers for nobody signed in itself, with a 204, so the app's sign-in gates must
      # not send that request to a sign-in page: Rails 8's built-in authentication's and Devise's.
      skip_before_action :require_authentication, :authenticate_user!, raise: false

      def create
        # A token names one person, so no cache in front of the app may keep it for another.
        response.headers["Cache-Control"] = "no-store, private"

        nonce = request.request_parameters["nonce"]
        return head(:bad_request) unless nonce.is_a?(String) && NONCE.match?(nonce)

        user = CurrentUser.find(self)
        return head(:no_content) unless user.is_a?(CurrentUser::Details)

        # The key is the whole secret as Deacon showed it, dk_sec_ and all.
        secret = ENV["DEACON_SECRET"].to_s.strip

        if secret.empty?
          ::Rails.logger&.warn(MISSING_SECRET)
          return head(:no_content)
        end

        now = Time.now.to_i
        claims = { sub: user.id, email: user.email, name: user.name, nonce: nonce, iat: now, exp: now + LIFETIME }.compact

        render plain: JWT.encode(claims, secret, "HS256")
      end
    end
  end
end
