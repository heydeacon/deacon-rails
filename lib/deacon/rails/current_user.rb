module Deacon
  module Rails
    # Who is signed in to the app, found the same way for the page and for the token route.
    module CurrentUser
      # The signed-in user as Deacon is told them: the id as a string, and the email and name.
      Details = Struct.new(:id, :email, :name)

      # The signed-in user's Details, nil when nobody is signed in, or :unknown when the app has
      # no way to say who is.
      def self.find(controller)
        return :unknown unless controller.respond_to?(:current_user, true)

        user = controller.send(:current_user)
        Details.new(user.id.to_s, user.email, user.name) if user
      end
    end
  end
end
