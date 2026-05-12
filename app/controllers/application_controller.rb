class ApplicationController < ActionController::API
  before_action :set_current_user_for_activity
  after_action :clear_current_user_for_activity

  private

  def authenticate_user!
    token = request.headers["X-AUTH-TOKEN"] || params["access_token"]
    if token.present?
      @current_user = fetch_user_with_role(token)
      head :unauthorized unless @current_user
    else
      render json: { error: "Unauthorized" }, status: 401
    end
  end

  def current_user
    @current_user
  end

  def fetch_user_with_role(token)
    Rails.cache.fetch("user_token:#{token}", expires_in: 5.minutes) do
      User.includes(:role).find_by(access_token: token)
    end
  end

  # Activity tracking methods
  def set_current_user_for_activity
    Thread.current[:current_user_id] = current_user.try(:id) if current_user.present?
  end

  def clear_current_user_for_activity
    Thread.current[:current_user_id] = nil
  end

  def user_assumed_by
    User.find_by_id(session[:assume_user]) if session[:assume_user].present?
  end

  rescue_from CanCan::AccessDenied do |exception|
    render json: { error: "Requested resource is locked. You cannot do this operation." }, status: :forbidden
  end
end
