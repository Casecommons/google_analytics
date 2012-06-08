require File.dirname(__FILE__) + '/test_helper.rb'
require 'test/unit'
require 'rubygems'
require 'mocha'
class Rails
  def self.env
    "test"
  end
end

class TestMixin
  class MockRequest
    attr_accessor :format
    attr_accessor :query_string
    attr_accessor :referer
    attr_accessor :ssl

    def ssl?
      ssl
    end
  end
  class MockResponse
    attr_accessor :body
  end

  include Rubaidh::GoogleAnalyticsMixin
  attr_accessor :request, :response

  def initialize
    self.request = MockRequest.new
    self.response = MockResponse.new
  end

end


class GoogleAnalyticsTest < Test::Unit::TestCase
  def setup
    @ga = Rubaidh::GoogleAnalytics.new
    @ga.tracker_id = "the tracker id"
  end

  def test_createable
    assert_not_nil(@ga)
  end

  def test_default_environments
    assert_equal(false, @ga.environments.include?('test'))
    assert_equal(false, @ga.environments.include?('development'))
    assert_equal(true, @ga.environments.include?('production'))
  end

  def test_default_formats
    assert_equal(false, @ga.formats.include?(:xml))
    assert_equal(true, @ga.formats.include?(:html))
  end

  def test_defer_load_defaults_to_true
    assert_equal(true, @ga.defer_load)
  end

  # test self.enabled
  def test_enabled_requires_tracker_id
    Rubaidh::GoogleAnalytics.stubs(:tracker_id).returns(nil)
    assert_raise(Rubaidh::GoogleAnalyticsConfigurationError) { Rubaidh::GoogleAnalytics.enabled?(:html) }
  end

  def test_enabled_returns_false_if_current_environment_not_enabled
    Rubaidh::GoogleAnalytics.stubs(:environments).returns(['production'])
    assert_equal(false, Rubaidh::GoogleAnalytics.enabled?(:html))
  end

  def test_enabled_with_default_format
    Rubaidh::GoogleAnalytics.stubs(:environments).returns(['test'])
    assert_equal(true, Rubaidh::GoogleAnalytics.enabled?(:html))
  end

  def test_enabled_with_not_included_format
    Rubaidh::GoogleAnalytics.stubs(:environments).returns(['test'])
    assert_equal(false, Rubaidh::GoogleAnalytics.enabled?(:xml))
  end

  def test_enabled_with_added_format
    Rubaidh::GoogleAnalytics.stubs(:environments).returns(['test'])
    Rubaidh::GoogleAnalytics.stubs(:formats).returns([:xml])
    assert_equal(true, Rubaidh::GoogleAnalytics.enabled?(:xml))
  end

  # test request_tracker_id
  def test_request_tracker_id_without_override
    Rubaidh::GoogleAnalytics.stubs(:tracker_id).returns("1234")
    assert_equal("1234", Rubaidh::GoogleAnalytics.request_tracker_id)
  end

  def test_request_tracker_id_with_override
    Rubaidh::GoogleAnalytics.stubs(:tracker_id).returns("1234")
    Rubaidh::GoogleAnalytics.override_tracker_id = "4567"
    assert_equal("4567", Rubaidh::GoogleAnalytics.request_tracker_id)
  end

  def test_request_tracker_id_resets_override
    Rubaidh::GoogleAnalytics.override_tracker_id = "4567"
    Rubaidh::GoogleAnalytics.stubs(:tracker_id).returns("1234")
    foo = Rubaidh::GoogleAnalytics.request_tracker_id
    assert_nil(Rubaidh::GoogleAnalytics.override_tracker_id)
  end

  # test request_tracked_path
  def test_request_tracked_path_without_override
    assert_equal('', Rubaidh::GoogleAnalytics.request_tracked_path)
  end

  def test_request_tracked_path_with_override
    Rubaidh::GoogleAnalytics.override_trackpageview = "/my/path"
    assert_equal("'/my/path'", Rubaidh::GoogleAnalytics.request_tracked_path)
  end

  def test_request_tracked_path_resets_override
    Rubaidh::GoogleAnalytics.override_trackpageview = "/my/path"
    foo = Rubaidh::GoogleAnalytics.request_tracked_path
    assert_nil(Rubaidh::GoogleAnalytics.override_trackpageview)
  end

  # Test the before_filter method does what we expect by subsituting the body tags and inserting
  # some google code for us automagically.
  def test_add_google_analytics_code
    # setup our test mixin
    mixin = TestMixin.new
    mixin.stubs(:google_analytics_code).returns("Google Code")
    Rubaidh::GoogleAnalyticsMixin.stubs(:search_query_found?).returns(false)

    # bog standard body tag
    Rubaidh::GoogleAnalytics.defer_load = false
    mixin.response.body = "<body><p>some text</p></body>"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<body>Google Code<p>some text</p></body>'

    Rubaidh::GoogleAnalytics.defer_load = true
    mixin.response.body = "<body><p>some text</p></body>"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<body><p>some text</p>Google Code</body>'

    # body tag upper cased (ignoring this is semantically incorrect)
    Rubaidh::GoogleAnalytics.defer_load = false
    mixin.response.body = "<BODY><p>some text</p></BODY>"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<BODY>Google Code<p>some text</p></BODY>'

    Rubaidh::GoogleAnalytics.defer_load = true
    mixin.response.body = "<BODY><p>some text</p></BODY>"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<BODY><p>some text</p>Google Code</body>'

    # body tag has additional attributes
    Rubaidh::GoogleAnalytics.defer_load = false
    mixin.response.body = '<body style="background-color:red"><p>some text</p></body>'
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<body style="background-color:red">Google Code<p>some text</p></body>'

    Rubaidh::GoogleAnalytics.defer_load = true
    mixin.response.body = '<body style="background-color:red"><p>some text</p></body>'
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<body style="background-color:red"><p>some text</p>Google Code</body>'

    #body tag has no additional attributes when search query found
    Rubaidh::GoogleAnalytics.defer_load = true
    mixin.response.body = "<BODY><p>some text</p></BODY>"
    mixin.request.query_string = "I EXIST"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<BODY><p>some text</p></BODY>'

    mixin.response.body = "<BODY><p>some text</p></BODY>"
    mixin.request.query_string = ""
    mixin.add_google_analytics_code
    assert_not_equal mixin.response.body, '<BODY><p>some text</p></BODY>'

    mixin.response.body = "<BODY><p>some text</p></BODY>"
    mixin.request.referer = "blabla?blabla"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<BODY><p>some text</p></BODY>'

    mixin.request.query_string = "lkasjdkl"
    mixin.add_google_analytics_code
    assert_equal mixin.response.body, '<BODY><p>some text</p></BODY>'

    mixin.request.query_string = ""
    mixin.request.referer = ""
    mixin.add_google_analytics_code
    assert_not_equal mixin.response.body, '<BODY><p>some text</p></BODY>'

  end
  #test search_query_found
  def test_search_query_found
    # setup our test mixin
    mixin = TestMixin.new

    mixin.request.query_string = "HIHIHIHI"
    assert_equal(true, mixin.search_query_found?)

    mixin = TestMixin.new
    assert_equal(false, mixin.search_query_found?)

    mixin.request.referer = "?HIHIHIHI"
    assert_equal(true, mixin.search_query_found?)
  end

  def test_ssl_is_forced_on
    mixin = TestMixin.new
    mixin.response.body = "<body><p>some text</p></body>"
    Rubaidh::GoogleAnalytics.stubs(:enabled?).returns(true)

    mixin.request.ssl = true
    assert_equal(mixin.request.ssl?, true)

    mixin.add_google_analytics_code
    assert(mixin.response.body =~ /https/, "should contain https when request.ssl? is true")

    mixin.response.body = "<body><p>some text</p></body>"
    mixin.request.ssl = false
    assert_equal(mixin.request.ssl?, false)

    mixin.add_google_analytics_code
    assert(mixin.response.body =~ /https/, "should contain https when request.ssl? is false")
  end

end
