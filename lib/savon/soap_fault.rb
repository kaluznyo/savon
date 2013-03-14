require "savon"

module Savon
  class SOAPFault < Error

    def self.present?(http)
      p "SOAPFault::present"
      fault_node  = http.body.include?("Fault>")
      soap1_fault = http.body.include?("faultcode>") && http.body.include?("faultstring>")
      soap2_fault = http.body.include?("Code>") && http.body.include?("Reason>")

      fault_node && (soap1_fault || soap2_fault)
    end

    def initialize(http, nori)
      p "SOAPFault::initialize"
      
      @http = http
      @nori = nori
    end

    attr_reader :http, :nori

    def to_s
      p "SOAPFault::to_s"
      
      message_by_version to_hash[:fault]
    end

    def to_hash
      p "SOAPFault::to_hash"
      
      nori.parse(@http.body)[:envelope][:body]
    end

    private

    def message_by_version(fault)
      p "SOAPFault::message_by_version"
      
      if fault[:faultcode]
        "(#{fault[:faultcode]}) #{fault[:faultstring]}"
      elsif fault[:code]
        "(#{fault[:code][:value]}) #{fault[:reason][:text]}"
      end
    end

  end
end
