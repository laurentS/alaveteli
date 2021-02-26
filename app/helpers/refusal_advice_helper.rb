# Helpers for rendering help page refusal advice
module RefusalAdviceHelper
  def refusal_advice_actionable?(action, info_request:)
    return true unless action.target.key?(:internal)
    current_user && current_user == info_request&.user
  end

  def refusal_advice_form_data(info_request)
    return {} unless info_request

    { refusals: latest_refusals_as_json(info_request) }
  end

  private

  def latest_refusals_as_json(info_request)
    latest_refusals(info_request).map(&:to_param)
  end

  def latest_refusals(info_request)
    info_request.incoming_messages&.map(&:refusals).reject(&:empty?).last || []
  end
end
