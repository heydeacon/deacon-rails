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

  test "says nothing about who is signed in when the app has no current_user" do
    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag("/")
    )
  end
end
