require "test_helper"

class TokenRouteTest < DeaconTest
  SECRET = "dk_sec_Wf3pX9qLr2Tz8vNc4bJh6yKd1sMa7eGu0oPiQwErTyU".freeze

  # A widget session's nonce, as Deacon makes them: an HMAC-SHA256 in hex.
  NONCE = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08".freeze

  setup do
    Rails.application.config.deacon.key = "pk_test123"
    ENV["DEACON_SECRET"] = SECRET
  end

  # What the page's token function sends: the JSON body, with the CSRF token the page printed.
  def ask_for_token(body: JSON.generate(nonce: NONCE))
    post_token(csrf_token_in(rendered_tag("/account")), body: body)
  end

  def post_token(csrf, body: JSON.generate(nonce: NONCE))
    post "/deacon/token",
         params: body,
         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => csrf }
  end

  test "answers with a token Deacon accepts: HS256 with DEACON_SECRET, naming who is signed in" do
    cookies[:user] = "ana"

    travel_to Time.utc(2026, 10, 27, 12) do
      ask_for_token
      payload, header = JWT.decode(response.body, SECRET, true, algorithm: "HS256")

      assert_equal(
        [
          200,
          "text/plain",
          "HS256",
          {
            "sub" => "7",
            "email" => "ana@studio.com",
            "name" => "Ana Ruiz",
            "nonce" => NONCE,
            "iat" => 1_793_102_400,
            "exp" => 1_793_103_000
          }
        ],
        [response.status, response.media_type, header["alg"], payload]
      )
    end
  end

  test "answers 204 with no token when nobody is signed in" do
    cookies[:user] = "ana"
    csrf = csrf_token_in(rendered_tag("/account"))
    cookies.delete("user") # signed out since the page loaded

    post_token(csrf)

    assert_equal [204, ""], [response.status, response.body]
  end

  MISSING_SECRET = "deacon-rails: DEACON_SECRET is missing, so the token route signs nobody " \
                   "and Deacon can't verify who is signed in. In Deacon, open Install (the button " \
                   "at the top of the dashboard) and make a secret under Verify who's signed in. " \
                   "It starts with dk_sec_."

  {
    "unset" => nil,
    "empty" => "",
    "blank" => "   "
  }.each do |description, secret|
    test "answers 204 and logs a warning when DEACON_SECRET is #{description}" do
      ENV["DEACON_SECRET"] = secret
      cookies[:user] = "ana"

      ask_for_token

      assert_equal(
        [204, "", ["#{MISSING_SECRET}\n"]],
        [response.status, response.body, logged.lines.grep(/deacon-rails/)]
      )
    end
  end

  # Rails writes the two directives in its own order, which means the same to a cache.
  { "a token" => "ana", "no token" => nil }.each do |answer, user|
    test "tells caches never to keep #{answer}" do
      cookies[:user] = "ana"
      csrf = csrf_token_in(rendered_tag("/account"))
      cookies.delete("user") if user.nil?

      post_token(csrf)

      assert_equal %w[no-store private], response.headers["Cache-Control"].split(", ").sort
    end
  end

  test "sends no CORS headers, so only the app's own pages can read a token" do
    cookies[:user] = "ana"

    ask_for_token

    assert_equal [200, []], [response.status, response.headers.keys.grep(/\Aaccess-control-/i)]
  end

  {
    "missing" => {},
    "not a string" => { nonce: 42 },
    "longer than 128 characters" => { nonce: "a" * 129 },
    "more than letters, digits, - and _" => { nonce: "abc def" }
  }.each do |description, body|
    test "answers 400 with no token when the nonce is #{description}" do
      cookies[:user] = "ana"

      ask_for_token(body: JSON.generate(body))

      assert_equal [400, ""], [response.status, response.body]
    end
  end

  test "refuses a request without the page's CSRF token, as the app refuses any POST" do
    cookies[:user] = "ana"
    rendered_tag("/account")

    assert_raises(ActionController::InvalidAuthenticityToken) do
      post "/deacon/token",
           params: JSON.generate(nonce: NONCE),
           headers: { "Content-Type" => "application/json" }
    end
  end
end
