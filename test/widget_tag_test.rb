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
end
