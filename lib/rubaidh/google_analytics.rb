require 'active_support'
require 'action_pack'
require 'action_view'

module Rubaidh # :nodoc:
  # This module gets mixed in to ActionController::Base
  module GoogleAnalyticsMixin
    # The javascript code to enable Google Analytics on the current page.
    # Normally you won't need to call this directly; the +add_google_analytics_code+
    # after filter will insert it for you.
    def google_analytics_code
      #TODO: ensure request.ssl? is correctly evaluating for SSL requests, and then stop forcing SSL
      # GoogleAnalytics.google_analytics_code(request.ssl?) if GoogleAnalytics.enabled?(request.format)
      GoogleAnalytics.google_analytics_code(true) if GoogleAnalytics.enabled?(request.format)
    end

    # Custom filter to prevent HIPPA data in search queries from being sent to Google Analytics
    def search_query_found?
      return ((request.query_string != nil && request.query_string != "") || (request.referer != nil && request.referer.include?('?')))
    end

    # An after_filter to automatically add the analytics code.
    # If you intend to use the link_to_tracked view helpers, you need to set Rubaidh::GoogleAnalytics.defer_load = false
    # to load the code at the top of the page
    # (see http://www.google.com/support/googleanalytics/bin/answer.py?answer=55527&topic=11006)
    def add_google_analytics_code
      return if search_query_found?

      if GoogleAnalytics.defer_load
        response.body = response.body.sub(/<\/[bB][oO][dD][yY]>/, "#{google_analytics_code}</body>")
      else
        response.body = response.body.sub(/(<[bB][oO][dD][yY][^>]*>)/, "\\1#{google_analytics_code}")
      end
    end
  end

  class GoogleAnalyticsConfigurationError < StandardError; end

  # The core functionality to connect a Rails application
  # to a Google Analytics installation.
  class GoogleAnalytics

    @@defer_load = true
    cattr_accessor :defer_load

    @@tracker_id = nil
    ##
    # :singleton-method:
    # Specify the Google Analytics ID for this web site. This can be found
    # as the value of +_getTracker+ if you are using the new (ga.js) tracking
    # code, or the value of +_uacct+ if you are using the old (urchin.js)
    # tracking code.
    cattr_accessor :tracker_id

    @@environments = ['production']
    ##
    # :singleton-method:
    # The environments in which to enable the Google Analytics code. Defaults
    # to 'production' only. Supply an array of environment names to change this.
    cattr_accessor :environments

    @@formats = [:html, "text/html", :all]
    ##
    # :singleton-method:
    # The request formats where tracking code should be added. Defaults to +[:html, :all]+. The entry for
    # +:all+ is necessary to make Google recognize that tracking is installed on a
    # site; it is not the same as responding to all requests. Supply an array
    # of formats to change this.
    cattr_accessor :formats

    ##
    # :singleton-method:
    # Set this to override the initialized domain name for a single render. Useful
    # when you're serving to multiple hosts from a single codebase. Typically you'd
    # set up a before filter in the appropriate controller:
    #    before_filter :override_domain_name
    #    def override_domain_name
    #      Rubaidh::GoogleAnalytics.override_domain_name  = 'foo.com'
    #   end
    cattr_accessor :override_domain_name

    ##
    # :singleton-method:
    # Set this to override the initialized tracker ID for a single render. Useful
    # when you're serving to multiple hosts from a single codebase. Typically you'd
    # set up a before filter in the appropriate controller:
    #    before_filter :override_tracker_id
    #    def override_tracker_id
    #      Rubaidh::GoogleAnalytics.override_tracker_id  = 'UA-123456-7'
    #   end
    cattr_accessor :override_tracker_id

    ##
    # :singleton-method:
    # Set this to override the automatically generated path to the page in the
    # Google Analytics reports for a single render. Typically you'd set this up on an
    # action-by-action basis:
    #    def show
    #      Rubaidh::GoogleAnalytics.override_trackpageview = "path_to_report"
    #      ...
    cattr_accessor :override_trackpageview

    # Return true if the Google Analytics system is enabled and configured
    # correctly for the specified format
    def self.enabled?(format)
      raise Rubaidh::GoogleAnalyticsConfigurationError if tracker_id.blank?
      environments.include?(Rails.env) && format && formats.include?(format.to_sym)
    end

    # Construct the javascript code to be inserted on the calling page. The +ssl+
    # parameter can be used to force the SSL version of the code in legacy mode only.
    def self.google_analytics_code(ssl = false)
      protocol = (ssl) ? "https://ssl" : "http://www"

      code = <<-HTML
      <script type="text/javascript">

      var _gaq = _gaq || [];
      _gaq.push(['_setAccount', '#{request_tracker_id}']);
      _gaq.push(['_setDetectTitle', false]);
      _gaq.push(['_trackPageview']);

      (function() {
        var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
        ga.src = '#{protocol}.google-analytics.com/ga.js';
        var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
      })();

      </script>
      HTML
    end

    # Determine the tracker ID for this request
    def self.request_tracker_id
      use_tracker_id = override_tracker_id.blank? ? tracker_id : override_tracker_id
      self.override_tracker_id = nil
      use_tracker_id
    end

    # Determine the path to report for this request
    def self.request_tracked_path
      use_tracked_path = override_trackpageview.blank? ? '' : "'#{override_trackpageview}'"
      self.override_trackpageview = nil
      use_tracked_path
    end

  end

  class LocalAssetTagHelper # :nodoc:
    # For helping with local javascripts
    include ActionView::Helpers::AssetTagHelper
  end
end
