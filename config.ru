require 'bundler/setup'
require 'sinatra/base'
require 'ruby-saml'

$stdout.sync = true

# The project root directory
$root = ::File.dirname(__FILE__)


class SinatraStaticServer < Sinatra::Base

  get(/saml\/init/) do
    request = Onelogin::Saml::Authrequest.new
    p request.create(saml_settings)
    redirect to(request.create(saml_settings))
  end

  get(/saml\/consume/) do
    p "&&params:" + params[:SAMLResponse]
    response = Onelogin::Saml::Response.new(params[:SAMLResponse])
    p "&&response:" + response
    response.settings = saml_settings

    if response.is_valid? && user = current_account.users.find_by_email(response.name_id)
      puts '&&success&&'
      authorize_success(user)
    else
      puts '&&failure&&'
      authorize_failure(user)
    end
  end

  get(/.+/) do
    send_sinatra_file(request.path) { 404 }
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
    settings.name_identifier_format = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    # Optional for most SAML IdPs
    settings.authn_context = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"

    settings
  end
end

run SinatraStaticServer
