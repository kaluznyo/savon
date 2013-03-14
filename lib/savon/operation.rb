require "savon/options"
require "savon/block_interface"
require "savon/request"
require "savon/builder"
require "savon/response"
require "savon/log_message"

module Savon
  class Operation

    def self.create(operation_name, wsdl, globals)
      p "Operation::create"
      
      if wsdl.document?
        ensure_name_is_symbol! operation_name
        ensure_exists! operation_name, wsdl
      end

      new(operation_name, wsdl, globals)
    end

    def self.ensure_exists!(operation_name, wsdl)
      p "Operation::ensure_exists"
      
      unless wsdl.soap_actions.include? operation_name
        raise UnknownOperationError, "Unable to find SOAP operation: #{operation_name.inspect}\n" \
                                     "Operations provided by your service: #{wsdl.soap_actions.inspect}"
      end
    end

    def self.ensure_name_is_symbol!(operation_name)
      p "Operation::ensure_name_is_symbol"
      
      unless operation_name.kind_of? Symbol
        raise ArgumentError, "Expected the first parameter (the name of the operation to call) to be a symbol\n" \
                             "Actual: #{operation_name.inspect} (#{operation_name.class})"
      end
    end

    def initialize(name, wsdl, globals)
      p "Operation::initialize"
    
      @name = name
      @wsdl = wsdl
      @globals = globals
    end

    def build(locals = {}, &block)
      p "Operation::build"
      
      set_locals(locals, block)
      Builder.new(@name, @wsdl, @globals, @locals)
    end

    def call(locals = {}, &block)
      p "Operation::call"
      
      builder = build(locals, &block)

      response = Savon.notify_observers(@name, builder, @globals, @locals)
      response ||= call! build_request(builder)

      raise_expected_httpi_response! unless response.kind_of?(HTTPI::Response)

      Response.new(response, @globals, @locals)
    end

    private

    def set_locals(locals, block)
      p "Operation::set_locals"
      
      locals = LocalOptions.new(locals)
      BlockInterface.new(locals).evaluate(block) if block

      @locals = locals
    end

    def call!(request)
      p "Operation::call!"
      
      log_request(request) if log?
      response = HTTPI.post(request)
      log_response(response) if log?

      response
    end

    def build_request(builder)
      p "Operation::build_request"
      
      request = SOAPRequest.new(@globals).build(
        :soap_action => soap_action,
        :cookies     => @locals[:cookies]
      )

      request.url = endpoint
      request.body = builder.to_s

      # TODO: could HTTPI do this automatically in case the header
      #       was not specified manually? [dh, 2013-01-04]
      request.headers["Content-Length"] = request.body.bytesize.to_s

      request
    end

    def soap_action
      p "Operation::soap_action"
      
      # soap_action explicitly set to something falsy
      return if @locals.include?(:soap_action) && !@locals[:soap_action]

      # get the soap_action from local options
      soap_action = @locals[:soap_action]
      # with no local option, but a wsdl, ask it for the soap_action
      soap_action ||= @wsdl.soap_action(@name.to_sym) if @wsdl.document?
      # if there is no soap_action up to this point, fallback to a simple default
      soap_action ||= Gyoku.xml_tag(@name, :key_converter => @globals[:convert_request_keys_to])
    end

    def endpoint
      p "Operation::endpoint"
      
      @globals[:endpoint] || @wsdl.endpoint
    end

    def log_request(request)
      p "Operation::log_request"
      
      logger.info  "SOAP request: #{request.url}"
      logger.info  headers_to_log(request.headers)
      logger.debug body_to_log(request.body)
    end

    def log_response(response)
      p "Operation::log_response"
      
      logger.info  "SOAP response (status #{response.code})"
      logger.debug body_to_log(response.body)
    end

    def headers_to_log(headers)
      p "Operation::headers_to_log"
      
      headers.map { |key, value| "#{key}: #{value}" }.join(", ")
    end

    def body_to_log(body)
      p "Operation::body_to_log"
      
      LogMessage.new(body, @globals[:filters], @globals[:pretty_print_xml]).to_s
    end

    def logger
      p "Operation::logger"
      
      @globals[:logger]
    end

    def log?
      p "Operation::log?"
      
      @globals[:log]
    end

    def raise_expected_httpi_response!
      raise Error, "Observers need to return an HTTPI::Response to mock " \
                   "the request or nil to execute the request."
    end

  end
end
