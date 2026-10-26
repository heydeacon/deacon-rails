require "test_helper"

class WidgetTagTest < DeaconTest
  test "prints the tag from Install with the key from config.deacon.key" do
    Rails.application.config.deacon.key = "pk_test123"

    assert_equal(
      '<script src="https://heydeacon.com/widget/v1/loader.js" data-key="pk_test123" async></script>',
      rendered_tag
    )
  end
end
