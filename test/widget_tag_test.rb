require "test_helper"

class WidgetTagTest < DeaconTest
  test "prints the tag from Install with the key from config.deacon.key" do
    Rails.application.config.deacon.key = "pk_test123"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag
    )
  end

  test "takes the key from DEACON_KEY when config.deacon.key isn't set" do
    ENV["DEACON_KEY"] = "pk_from_env"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_from_env" async></script>',
      rendered_tag
    )
  end

  test "prefers config.deacon.key to DEACON_KEY" do
    ENV["DEACON_KEY"] = "pk_from_env"
    Rails.application.config.deacon.key = "pk_from_config"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_from_config" async></script>',
      rendered_tag
    )
  end

  MISSING_KEY = "deacon-rails: the key is missing, so the page has no Deacon widget. Set " \
                "DEACON_KEY or config.deacon.key. In Deacon, open Install (the button at the top " \
                "of the dashboard) and copy the data-key value from the snippet. It starts with pk_."

  {
    "unset" => nil,
    "empty, as from an empty DEACON_KEY" => "",
    "blank" => "   "
  }.each do |description, key|
    test "prints nothing and logs a warning when the key is #{description}" do
      ENV["DEACON_KEY"] = key

      assert_equal ["", ["#{MISSING_KEY}\n"]], [rendered_tag, logged.lines.grep(/deacon-rails/)]
    end
  end

  test "trims spaces pasted around the key" do
    Rails.application.config.deacon.key = "  pk_test123\n"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag
    )
  end

  test "passes config.deacon.context to Deacon as the data-context attribute" do
    Rails.application.config.deacon.key = "pk_test123"
    Rails.application.config.deacon.context = { site: "docs", version: "3.2", beta: true }

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" ' \
      'data-context="{&quot;site&quot;:&quot;docs&quot;,&quot;version&quot;:&quot;3.2&quot;,' \
      '&quot;beta&quot;:true}" async></script>',
      rendered_tag
    )
  end

  test "keeps a context value that looks like HTML as it was written" do
    Rails.application.config.deacon.key = "pk_test123"
    Rails.application.config.deacon.context = { note: '</script><b>"hi" &amp;</b>' }

    script = Nokogiri::HTML5.fragment(rendered_tag).at_css("script")

    assert_equal '{"note":"</script><b>\"hi\" &amp;</b>"}', script["data-context"]
  end

  test "holds back page views with the data-no-page-views attribute" do
    Rails.application.config.deacon.key = "pk_test123"
    Rails.application.config.deacon.page_views = false

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" ' \
      "data-no-page-views async></script>",
      rendered_tag
    )
  end

  test "carries the Content Security Policy nonce when the app gives each request one" do
    Rails.application.config.deacon.key = "pk_test123"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async ' \
      'nonce="n0nce"></script>',
      rendered_tag("/with-nonce")
    )
  end

  test "refuses a page_views that isn't true or false" do
    Rails.application.config.deacon.key = "pk_test123"
    Rails.application.config.deacon.page_views = "false"

    error = assert_raises(ActionView::Template::Error) { get "/" }

    assert_equal(
      [ArgumentError, "deacon-rails: config.deacon.page_views must be true or false."],
      [error.cause.class, error.cause.message]
    )
  end

  {
    "a string" => "plan=pro",
    "an array" => ["docs"],
    "a hash with a nested value" => { plan: { tier: "pro" } },
    "a hash with a nil value" => { plan: nil }
  }.each do |description, context|
    test "refuses a context that is #{description}" do
      Rails.application.config.deacon.key = "pk_test123"
      Rails.application.config.deacon.context = context

      error = assert_raises(ActionView::Template::Error) { get "/" }

      assert_equal(
        [
          ArgumentError,
          "deacon-rails: config.deacon.context must be a hash whose values are strings, " \
          "numbers or booleans."
        ],
        [error.cause.class, error.cause.message]
      )
    end
  end
end
