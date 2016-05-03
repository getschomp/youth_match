require 'sinatra/base'
require 'sinatra/activerecord'
require './environment'
require 'airbrake'

class Apps::Relay < Sinatra::Base

  if ENV['AIRBRAKE_PROJECT_ID']
    Airbrake.configure do |c|
      c.project_id  = ENV['AIRBRAKE_PROJECT_ID']
      c.project_key = ENV['AIRBRAKE_KEY']
      c.environment = DATABASE_ENV.to_sym
      c.ignore_environments = [:development, :test]
      c.logger.level = Logger::DEBUG
    end
  end

  set :method_override, true
  set :logger, $stdout

  get '/' do
    "Hello, Relay!"
  end

  get '/placements/:id/accept/?' do
    load_placement(params)
    @placement.accepted
    redirect *DYEERedirect.to(:accept)
  end

  get '/placements/:id/decline/?' do
    load_placement(params)
    @placement.declined
    redirect *DYEERedirect.to(:decline)
  end

  get '/placements/:id/opt-out/?' do
    load_placement(params)
    @placement.declined
    @placement.applicant.opted_out
    redirect *DYEERedirect.to(:opt_out)
  end

  # error ActiveRecord::RecordNotFound do
  #   Airbrake.notify('Record Not Found', params: params)
  #   redirect *DYEERedirect.to(:error)
  # end

  # error 404 do
  #   Airbrake.notify('404 / Record Not Found', params: params)
  #   redirect *DYEERedirect.to(:error)
  # end

  # error 422 do
  #   Airbrake.notify('Unprocessable Entity', params: params)
  #   redirect *DYEERedirect.to(:error)
  # end

  # error 500 do
  #   Airbrake.notify('Internal Server Error', params: params)
  #   redirect *DYEERedirect.to(:error)
  # end

  private

  def load_placement(params)
    @placement = Placement.find_by(
      uuid: params[:id],
      applicant_id: applicant(params).id,
      position_id: position(params).id
    )
    assert_decidable(@placement)
  rescue ActiveRecord::RecordNotFound
    $logger.error 'RecordNotFound'
    halt 404
  end

  def applicant(params)
    if applicant = Applicant.find_by(uuid: params[:applicant_uuid])
      applicant
    else
      halt 404
    end
  end

  def position(params)
    if position = Position.find_by(uuid: params[:position_uuid])
      position
    else
      halt 404
    end
  end

  def assert_decidable(placement)
    halt 404 if placement.nil?
    redirect *DYEERedirect.to(:expired) if placement.expired?
    halt 422 unless placement.updatable?
    true
  end
end
