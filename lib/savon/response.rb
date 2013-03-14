require "nori"
require "savon/soap_fault"
require "savon/http_error"

module Savon
  class Response

    def initialize(http, globals, locals)
      p "Response::initialize"
      @http    = http
      @globals = globals
      @locals  = locals

      raise_soap_and_http_errors! if @globals[:raise_errors]
    end

    attr_reader :http, :globals, :locals

    def success?
      p "Response::success?"
      
      !soap_fault? && !http_error?
    end
    alias successful? success?

    def soap_fault?
      p "Response::soap_fault?"
      
      SOAPFault.present? @http
    end

    def http_error?     
       p "Response::http_error?"

      HTTPError.present? @http
    end

    def header
      p "Response::header"
      
      raise_invalid_response_error! unless hash.key? :envelope
      hash[:envelope][:header]
    end

    def body
      p "Response::body"
      
      raise_invalid_response_error! unless hash.key? :envelope
      hash[:envelope][:body]
    end
    alias to_hash body

    def to_array(*path)
      p "Response::to_array"
      
      result = path.inject body do |memo, key|
        return [] if memo[key].nil?
        memo[key]
      end

      result.kind_of?(Array) ? result.compact : [result].compact
    end

    def hash
      p "Response::hash"
      
      @hash ||= nori.parse(to_xml)
    end

    def to_xml
      p "Response::to_xml"
      
      @http.body
    end

    def doc
      p "Response::doc"
      
      @doc ||= Nokogiri.XML(to_xml)
    end

    def xpath(path, namespaces = nil)
      p "Response::xpath"
      
      doc.xpath(path, namespaces || xml_namespaces)
    end

    private

    def raise_soap_and_http_errors!
      p "Response::raise_soap_and_http_errors"
      
      raise SOAPFault.new(@http, nori) if soap_fault?
      raise HTTPError.new(@http) if http_error?
    end

    def raise_invalid_response_error!
      p "Response::raise_invalid_response_error"
      
      raise InvalidResponseError, "Unable to parse response body:\n" + to_xml.inspect
    end

    def xml_namespaces
      p "Response::xml_namespaces"
      
      @xml_namespaces ||= doc.collect_namespaces
    end

    def nori
      p "Response::nori"
      
      return @nori if @nori

      nori_options = {
        :strip_namespaces     => @globals[:strip_namespaces],
        :convert_tags_to      => @globals[:convert_response_tags_to],
        :advanced_typecasting => @locals[:advanced_typecasting],
        :parser               => @locals[:response_parser]
      }

      non_nil_nori_options = nori_options.reject { |_, value| value.nil? }
      @nori = Nori.new(non_nil_nori_options)
    end

  end
end
