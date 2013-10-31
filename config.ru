require 'bundler/setup'
require 'sinatra/base'
require 'ruby-saml'
require "sinatra/cookies"

$stdout.sync = true

# The project root directory
$root = ::File.dirname(__FILE__)


class SinatraStaticServer < Sinatra::Base
  use Rack::Session::Cookie, :key => 'rack.session',
      :path => '/',
      :expire_after => 2592000,
      :secret => SecureRandom.hex

  get(/saml\/init/) do
    request = Onelogin::Saml::Authrequest.new

    settings = saml_settings
    created_request = request.create(settings)

    redirect to(created_request)
  end

  post(/saml\/consume/) do
    response = Onelogin::Saml::Response.new(params[:SAMLResponse])

    response.settings = saml_settings

    p response

    if response.is_valid?
      log_user_in

      puts 'successfully authorized with user id' + response.name_id

      redirect to('/')
    else
      'Sorry, you couldn\'t be successfully authorized'
    end
  end

  get(/sign-out/) do
    log_user_out
    send_sinatra_file('/sign-in')
  end

  get(/sign-in/) do
    send_sinatra_file('/sign-in')
  end

  get(/.+/) do
    
    puts 'trying to authorize session information...'
    p request.session

    if request.session['logged_in']
      send_sinatra_file(request.path) { 404 }
    else
      redirect to('/sign-in')
    end
  end

  not_found do
    send_file(File.join(File.dirname(__FILE__), 'public', '404.html'), {:status => 404})
  end

  def send_sinatra_file(path, &missing_file_block)
    file_path = File.join(File.dirname(__FILE__), 'public', path)
    file_path = File.join(file_path, 'index.html') unless file_path =~ /\.[a-z]+$/i
    File.exist?(file_path) ? send_file(file_path) : missing_file_block.call
  end

  private
  def saml_settings
    settings = Onelogin::Saml::Settings.new

    settings.assertion_consumer_service_url = "http://#{request.host}/saml/consume"
    settings.issuer = request.host

    settings.idp_sso_target_url = 'https://thoughtworks.oktapreview.com/home/template_saml_2_0/0oahmrxahZAGXOAFAMHT/1541'
    settings.idp_cert_fingerprint = 'B8:53:D4:A7:E6:1B:86:FF:4E:91:F6:2D:34:EB:A6:A2:8F:89:9E:6F'
    settings.name_identifier_format = 'urn:oasis:names:tc:SAML:1.1:nameid-format:transient'
    # Optional for most SAML IdPs
    settings.authn_context = 'urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport'

    settings
  end

  def log_user_in
    env['rack.session'][:logged_in] = true
  end

  def log_user_out
    env['rack.session'][:logged_in] = false
  end
end

run SinatraStaticServer
