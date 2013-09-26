module MeetingIssuesHelper
  def can_create_issue?(answer)
    (admin? || meeting_manager? && author?(answer.meeting_protocol))
  end

  def can_update_issue?(answer)
    (admin? || meeting_manager? && author?(answer.meeting_protocol)) && answer.meeting_question.present? && answer.meeting_question.is_a?(MeetingQuestion) && answer.meeting_question.try(:issue).present?
  end

  def can_destroy_issue?(answer)
    (admin? || meeting_manager? && author?(answer.meeting_protocol))
  end
end
