require 'date'
require 'rexml/document'
require 'net/http'
require 'net/https'
require 'rubygems'
require 'active_support'

module UPS
  # Provides a simple api to to ups's time in transit service.
  class TimeInTransit
    XPCI_VERSION = '1.0002'
    DEFAULT_CUTOFF_TIME = 14
    DEFAULT_TIMEOUT = 30
    DEFAULT_RETRY_COUNT = 3
    DEFAULT_COUNTRY_CODE = 'US'
    DEFAULT_UNIT_OF_MEASUREMENT = 'LBS'

    # Creates a TimeInTransit instance based on the given hash of access 
    # options The following access options are available and are required 
    # unless a default value is specified:
    #
    # [<tt>:url</tt>]
    #   The ups api url to use
    #
    # [<tt>:access_license_number</tt>]
    #   Your ups license number
    #
    # [<tt>:user_id</tt>]
    #    Your ups user id
    #
    # [<tt>password</tt>]
    #   Your ups password
    #
    # [<tt>:order_cutoff_time</tt>]
    #   Your own arbitrary cutoff time that is some time before the actual ups cutoff 
    #   time.  Requests made after this time will use the following day as the send 
    #   date (or the following monday if the request is made on a weekend or on a 
    #   friday after this time.)
    #
    # [<tt>:sender_city</tt>]
    #   The city you are shipping from
    #
    # [<tt>:sender_state</tt>]
    #   The state you are shipping from
    #
    # [<tt>:sender_zip</tt>]
    #   The zip code you are shipping from
    #
    # [<tt>:sender_country_code</tt>]
    #   The country you are shipping from (defaults to 'US')
    #
    # [<tt>:retry_count</tt>]
    #   The number of times you would like to retry when a connection 
    #   fails (defaults to 3)
    #
    # [<tt>:timeout</tt>]
    #   The number of seconds you would like to wait for a response before 
    #   giving up (defaults to 30)
    #
    def initialize(access_options)
      @order_cutoff_time = access_options[:order_cutoff_time] || DEFAULT_CUTOFF_TIME
      @url = access_options[:url]
      @timeout = access_options[:timeout] || DEFAULT_TIMEOUT 
      @retry_count = access_options[:retry_count] || DEFAULT_CUTOFF_TIME 

      @access_xml = generate_xml({
        :AccessRequest => {
          :AccessLicenseNumber => access_options[:access_license_number],
          :UserId => access_options[:user_id],
          :Password => access_options[:password]
        }
      })

      @transit_from_attributes = {
        :AddressArtifactFormat => {
          :PoliticalDivision2 => access_options[:sender_city],
          :PoliticalDivision1 => access_options[:sender_state],
          :CountryCode => access_options[:sender_country_code] || DEFAULT_COUNTRY_CODE,
          :PostcodePrimaryLow => access_options[:sender_zip]
        }
      }
    end

    # Requests time in transit information based on the given hash of options:
    #
    # [<tt>:total_packages</tt>]
    #   the number of packages in the shipment (defaults to 1)
    #
    # [<tt>:unit_of_measurement</tt>]
    #   the unit of measurement to use (defaults to 'LBS')
    #
    # [<tt>:weight</tt>]
    #   the weight of the shipment in the given units
    #
    # [<tt>:city</tt>]
    #   the city you are shipping to
    #
    # [<tt>:state</tt>]
    #   the state you are shipping to
    #
    # [<tt>:zip</tt>]
    #   the zip code you are shipping to
    #
    # [<tt>:country_code</tt>]
    #   the country you are shipping to (defaults to 'US')
    #
    # An error will be raised if the request is unsuccessful.
    #
    def request(options)
      
      # build our request xml
      pickup_date = calculate_pickup_date
      options[:pickup_date] = pickup_date.strftime('%Y%m%d')
      xml = @access_xml + generate_xml(build_transit_attributes(options))

      # attempt the request in a timeout
      delivery_dates = {}
      attempts = 0
      begin 
        Timeout.timeout(@timeout) do
          response = send_request(@url, xml)
          delivery_dates = response_to_map(response)
        end

      # We can only attempt to recover from Timeout errors, all other errors
      # should be raised back to the user
      rescue Timeout::Error => error
        if(attempts < @retry_count)
          attempts += 1
          retry

        else
          raise error
        end
      end

      delivery_dates
    end

    private 

    # calculates the next available pickup date based on the current time and the 
    # configured order cutoff time
    def calculate_pickup_date
      now = Time.now
      day_of_week = now.strftime('%w').to_i
      in_weekend = [6,0].include?(day_of_week)
      in_friday_after_cutoff = day_of_week == 5 and now.hour > @order_cutoff_time

      # If we're in a weekend (6 is Sat, 0 is Sun,) or we're in Friday after
      # the cutoff time, then our ship date will move
      if(in_weekend or in_friday_after_cutoff)
        pickup_date = now.next_week

      # if we're in another weekday but after the cutoff time, our ship date
      # moves to tomorrow
      elsif(now.hour > @order_cutoff_time)
        pickup_date = now.tomorrow
      else
        pickup_date = now
      end
    end

    # Builds a hash of transit request attributes based on the given values
    def build_transit_attributes(options)
      # set defaults if none given
      options[:total_packages] = 1 unless options[:total_packages]

      # convert all options to string values
      options.each_value {|option| option = options.to_s}

      transit_attributes = {
        :TimeInTransitRequest => {
          :Request => {
            :RequestAction => 'TimeInTransit',
            :TransactionReference => {
              :XpciVersion => XPCI_VERSION
            }
          },
          :TotalPackagesInShipment => options[:total_packages],
          :ShipmentWeight => {
            :UnitOfMeasurement => {
              :Code => options[:unit_of_measurement] || DEFAULT_UNIT_OF_MEASUREMENT
            },
            :Weight => options[:weight],
          },
          :PickupDate => options[:pickup_date],
          :TransitFrom => @transit_from_attributes,
          :TransitTo => {
            :AddressArtifactFormat => {
              :PoliticalDivision2 => options[:city],
              :PoliticalDivision1 => options[:state],
              :CountryCode => options[:country_code] || DEFAULT_COUNTRY_CODE,
              :PostcodePrimaryLow => options[:zip],
            }
          }
        }
      }
    end

    # generates an xml document for the given attributes
    def generate_xml(attributes)
      xml = REXML::Document.new
      xml << REXML::XMLDecl.new
      emit(attributes, xml)
      xml.root.add_attribute("xml:lang", "en-US")
      xml.to_s
    end

    # recursively emits xml nodes under the given node for values in the given hash
    def emit(attributes, node)
      attributes.each do |k,v|
        child_node = REXML::Element.new(k.to_s, node)
        (v.respond_to? 'each_key') ? emit(v, child_node) : child_node.add_text(v.to_s)
      end
    end

    # Posts the given data to the given url, returning the raw response
    def send_request(url, data)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.port == 443
        http.use_ssl	= true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      response = http.post(uri.path, data)
      response.code == '200' ? response.body : response.error!
    end

    # converts the given raw xml response to a map of local service codes
    # to estimated delivery dates
    def response_to_map(response) 
      response_doc = REXML::Document.new(response)
      response_code = response_doc.elements['//ResponseStatusCode'].text.to_i
      raise "Invalid response from ups:\n#{response_doc.to_s}" if(!response_code || response_code != 1)

      service_codes_to_delivery_dates = {}
      response_code = response_doc.elements.each('//ServiceSummary') do |service_element|
        service_code = service_element.elements['Service/Code'].text
        if(service_code)
          date_string = service_element.elements['EstimatedArrival/Date'].text
          time_string = service_element.elements['EstimatedArrival/Time'].text
          delivery_date = Time.parse("#{date_string} #{time_string}")
          service_codes_to_delivery_dates[service_code] = delivery_date
        end
      end
      service_codes_to_delivery_dates
    end
  end
end
