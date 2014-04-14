require 'net/http'
require 'net/https'

class Privat24

  class RequestError < StandardError
  end

  class ResponseError < StandardError
  end

  class PaymentError < StandardError
  end

  WAIT_TIME = 5
  TEST_MODE = 0
  API_REQUEST_URL = "https://api.privatbank.ua/p24api/"

  attr_accessor :merchant_phone, :merchant_id, :test_mode, :wait_time

  def initialize(options)
    @password = options[:password]
    @merchant_id = options[:id]
    @merchant_phone = options[:phone]
    @test_mode = options[:test_mode] || TEST_MODE
    @wait_time = options[:wait_time] || WAIT_TIME
  end

  def properties(operation)
    response = request operation do |data|
      data.oper 'prp'
    end
    h = Hash.from_xml response
    h["response"]["data"]["props"]["prop"]
  end

  def pay_pb(options = {})
    response = execute __method__, options
    result = parse_response response, 'payment'
    if result.attributes["state"].nil? or result.attributes["state"].value != "1"
      raise PaymentError, result.attributes["message"].value
    end
    true
  end

  def rest_fiz account, date_from, date_to
    params = {
        :sd => date_from,
        :ed => date_to,
        :card => account
    }
    response_xml = execute __method__, params
    h = Hash.from_xml response_xml
    h["response"]["data"]["info"]["statements"]
  end

  def balance(account)
    response = execute __method__, :cardnum => account
    result = parse_response(response, 'balance')
    result.text.to_f
  end

  def execute name, params
    payment_id = params.delete(:payment_id)
    request name do |data|
      data.oper 'cmt'
      data.wait wait_time
      data.test test_mode
      data.payment(:id => payment_id) {
        params.each do |key, value|
          data.prop :name => key.to_s, :value => value
        end
      }
    end
  end

  def sign(data)
    signature(data)
  end

  private

  def request operation, &data
    uri = URI.parse(API_REQUEST_URL + operation.to_s)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = make_xml(&data)
    response = http.request(request)
    p response.body
    response.body
  end

  def parse_response response, xpath
    doc = Nokogiri::XML(response)

    if doc.at("//response/data/error")
      raise ResponseError, doc.at("//response/data/error").attributes["message"].try(:value)
    elsif doc.at("//error")
      raise RequestError, doc.at("//error").text
    else
      doc.at(xpath)
    end
  end

  def signature(data)
    sha1(md5(data + @password))
  end

  def sha1(str)
    Digest::SHA1.hexdigest(str)
  end

  def md5(str)
    Digest::MD5.hexdigest(str)
  end

  def make_xml(&block)
#      xml = <<-EOL
#<?xml version="1.0" encoding="UTF-8"?>
#<request version="1.0">
#  <merchant>
#    <id>#{@merchant_id}</id>
#    <signature>#{signature(data)}</signature>
#  </merchant>
#  <data>
#    #{data}
#  </data>
#</request>
#      EOL

    doc = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.request {
        xml.merchant {
          xml.id_ @merchant_id
        }
        xml.data
      }
    end.doc

    # append <data></data> block to xml
    doc = Nokogiri::XML::Builder.with(doc.at('data'), &block).doc

    # extract <data></data> block for signature
    data = doc.at('data').children.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)

    # append signature to <merchant />
    Nokogiri::XML::Builder.with(doc.at('merchant')) do |xml|
      xml.signature signature(data)
    end.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

end