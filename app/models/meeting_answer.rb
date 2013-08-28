class MeetingAnswer < ActiveRecord::Base
  unloadable

  belongs_to :meeting_protocol
  belongs_to :meeting_question
  belongs_to :user
  belongs_to :reporter, class_name: "User", foreign_key: "reporter_id"
  belongs_to :issue
  has_one :status, through: :issue
  has_one :project, through: :issue
  has_many :meeting_answers, through: :meeting_protocol

  validates_presence_of :user_id, :description, :start_date, :due_date, :meeting_question_id

  after_save :add_new_users_from_answers

private

  def add_new_users_from_answers
    (self.meeting_answers.map(&:reporter) - self.meeting_protocol.users).each do |user|
      MeetingParticipator.create(user: user, meeting_protocol: self.meeting_protocol)
    end
  end

end
