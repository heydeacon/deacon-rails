module Deacon
  module Rails
    # Who is signed in to the app, found the same way for the page and for the token route.
    module CurrentUser
      # The signed-in user as Deacon is told them: the id as a string, and the email and name
      # when the user has them.
      Details = Struct.new(:id, :email, :name)

      # The signed-in user's Details, nil when nobody is signed in, or :unknown when the app has
      # no way to say who is. config.deacon.current_user names a method on the controller, or is
      # a lambda run inside it; without one, the controller's own current_user is used.
      def self.find(controller)
        lookup = ::Rails.application.config.deacon.current_user
        lookup ||= :current_user if controller.respond_to?(:current_user, true)
        return :unknown if lookup.nil?

        user = case lookup
               when Proc then controller.instance_exec(&lookup)
               when Symbol, String then controller.send(lookup)
               else
                 raise ArgumentError, "deacon-rails: config.deacon.current_user must be a method " \
                                      "name or a lambda."
               end

        details(user) if user
      end

      # Rails 8's built-in authentication names the address email_address. A user with no id,
      # such as a guest object or one never saved, names nobody, so it counts as nobody.
      def self.details(user)
        id = user.id.to_s
        return if id.empty?

        email = if user.respond_to?(:email) then user.email
                elsif user.respond_to?(:email_address) then user.email_address
                end
        name = user.name if user.respond_to?(:name)

        Details.new(id, email.to_s.presence, name.to_s.presence)
      end
      private_class_method :details
    end
  end
end
