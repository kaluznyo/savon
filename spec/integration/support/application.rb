require "rack/builder"

class IntegrationServer

  def self.respond_with(options = {})
    code = options.fetch(:code, 200)
    body = options.fetch(:body, "")
    headers = { "Content-Type" => "text/plain", "Content-Length" => body.size.to_s }

    [code, headers, [body]]
  end

  Application = Rack::Builder.new do

    map "/" do
      run lambda { |env|
        IntegrationServer.respond_with :body => env["REQUEST_METHOD"].downcase
      }
    end

    map "/repeat" do
      run lambda { |env|
        # stupid way of extracting the value from a query string (e.g. "code=500") [dh, 2012-12-08]
        IntegrationServer.respond_with :body => env["rack.input"].read
      }
    end

    map "/404" do
      run lambda { |env|
        IntegrationServer.respond_with :code => 404, :body => env["rack.input"].read
      }
    end

    map "/timeout" do
      run lambda { |env|
        sleep 2
        IntegrationServer.respond_with :body => "timeout"
      }
    end

    map "/repeat_header" do
      run lambda { |env|
        IntegrationServer.respond_with :body => env["HTTP_REPEAT_HEADER"]
      }
    end

    map "/inspect_header" do
      run lambda { |env|
        IntegrationServer.respond_with :body => env[env["HTTP_INSPECT"]]
      }
    end

    map "/basic-auth" do
      use Rack::Auth::Basic, "basic-realm" do |username, password|
        username == "admin" && password == "secret"
      end

      run lambda { |env|
        IntegrationServer.respond_with :body => "basic-auth"
      }
    end

    map "/digest-auth" do
      unprotected_app = lambda { |env|
        IntegrationServer.respond_with :body => "digest-auth"
      }

      realm = 'digest-realm'
      app = Rack::Auth::Digest::MD5.new(unprotected_app) do |username|
        username == 'admin' ? Digest::MD5.hexdigest("admin:#{realm}:secret") : nil
      end
      app.realm = realm
      app.opaque = 'this-should-be-secret'
      app.passwords_hashed = true

      run app
    end

  end
end
