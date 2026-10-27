require "test_helper"

class SignedInTest < DeaconTest
  setup do
    Rails.application.config.deacon.key = "pk_test123"
  end

  test "tells Deacon who is signed in, with a token function, above the loader tag" do
    cookies[:user] = "ana"

    assert_equal(
      '<script>window.deaconUser = { id: "7", email: "ana@studio.com", name: "Ana Ruiz", ' \
      'token: (nonce) => fetch("/deacon/token", { method: "POST", credentials: "same-origin", ' \
      'headers: { "Content-Type": "application/json", "X-CSRF-Token": "CSRF" }, ' \
      'body: JSON.stringify({ nonce }) }).then((r) => (r.status === 200 ? r.text() : "")) }; ' \
      "window.Deacon?.identify(window.deaconUser);</script>" \
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      without_csrf_token(rendered_tag("/account"))
    )
  end

  test "signs the visitor out of Deacon when nobody is signed in" do
    assert_equal(
      "<script>window.deaconUser = null; window.Deacon?.identify(null);</script>" \
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag("/account")
    )
  end

  # The id, email and name the page tells Deacon, as written in the script.
  def user_fields(html)
    html[/window\.deaconUser = \{ (.*?), token: /, 1]
  end

  test "finds the user with config.deacon.current_user as a method name" do
    Rails.application.config.deacon.current_user = :current_member
    cookies[:member] = "bo"

    assert_equal 'id: "12", email: "bo@studio.com", name: "Bo Chen"', user_fields(rendered_tag("/account"))
  end

  test "finds a Rails 8 built-in authentication user with config.deacon.current_user as a lambda" do
    Rails.application.config.deacon.current_user = -> { Current.user if authenticated? }
    cookies[:session_id] = "s1"

    assert_equal 'id: "21", email: "cy@studio.com"', user_fields(rendered_tag("/account"))
  end

  test "refuses a current_user that isn't a method name or a lambda" do
    Rails.application.config.deacon.current_user = 42

    error = assert_raises(ActionView::Template::Error) { get "/account" }

    assert_equal(
      [ArgumentError, "deacon-rails: config.deacon.current_user must be a method name or a lambda."],
      [error.cause.class, error.cause.message]
    )
  end

  { "someone" => "ana", "nobody" => nil }.each do |description, user|
    test "says nothing about who is signed in when config.deacon.signed_in is false, with #{description} signed in" do
      Rails.application.config.deacon.signed_in = false
      cookies[:user] = user unless user.nil?

      assert_equal(
        '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
        rendered_tag("/account")
      )
    end
  end

  test "refuses a signed_in that isn't true or false" do
    Rails.application.config.deacon.signed_in = "false"

    error = assert_raises(ActionView::Template::Error) { get "/account" }

    assert_equal(
      [ArgumentError, "deacon-rails: config.deacon.signed_in must be true or false."],
      [error.cause.class, error.cause.message]
    )
  end

  test "carries the Content Security Policy nonce on the signed-in script too" do
    assert_equal(
      '<script nonce="n0nce">window.deaconUser = null; window.Deacon?.identify(null);</script>' \
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async ' \
      'nonce="n0nce"></script>',
      rendered_tag("/account-with-nonce")
    )
  end

  test "says nothing about who is signed in when the app has no current_user" do
    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag("/")
    )
  end
end
