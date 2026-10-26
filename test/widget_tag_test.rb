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

  test "trims spaces pasted around the key" do
    Rails.application.config.deacon.key = "  pk_test123\n"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag
    )
  end
end
