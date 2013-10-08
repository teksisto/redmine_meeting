class MeetingMember < ActiveRecord::Base
  unloadable

  include Rails.application.routes.url_helpers

  belongs_to :meeting_agenda
  belongs_to :user
#  belongs_to :person, class_name: 'Person', foreign_key: 'user_id'
  belongs_to :issue
  belongs_to :time_entry
  has_one :status, through: :issue
  has_one :meeting_participator
  has_many :meeting_questions, through: :meeting_agenda, uniq: true

  validates_uniqueness_of :user_id, scope: :meeting_agenda_id
  validates_presence_of :user_id
  validate :validate_meeting_agenda, if: -> {self.meeting_agenda.present? && !self.meeting_agenda.valid?}

  def to_s
    self.user.try(:name) || ''
  end

  def send_invite
    created_issue_id = create_issue.try(:id)
    self.update_attribute(:issue_id, created_issue_id)
    estimated_time_create(created_issue_id)
#  rescue
  end

  def resend_invite
    cancel_status_id = IssueStatus.find(Setting[:plugin_redmine_meeting][:cancel_issue_status]).id
    if self.issue.present? && !self.issue.closed?
      self.issue.update_attribute(:status_id, cancel_status_id)
      EstimatedTime.where(plan_on: self.meeting_agenda.meet_on, issue_id: self.issue_id, user_id: self.user_id).delete_all
      self.update_attribute(:issue_id, nil)
      self.send_invite
    end
#  rescue
  end

private
  def estimated_time_create(created_issue_id)
    EstimatedTime.new(
      issue_id: created_issue_id,
      user_id: self.user_id,
      hours: (((self.meeting_agenda.end_time.seconds_since_midnight - self.meeting_agenda.start_time.seconds_since_midnight) / 36) / 100.0),
      comments: ::I18n.t(:message_participate_in_the_meeting),
      plan_on: self.meeting_agenda.meet_on
      tyear: self.meeting_agenda.meet_on.year
      tmonth: self.meeting_agenda.meet_on.month
      tweek: self.meeting_agenda.meet_on.cweek
      project_id: Issue.find(created_issue_id).project.id
    ).save(validate: false)
  end

  def key_words
    {
      subject: self.meeting_agenda.subject,
      meet_on: self.meeting_agenda.meet_on.strftime("%d.%m.%Y"),
      start_time: self.meeting_agenda.start_time.strftime("%H:%M"),
      end_time: self.meeting_agenda.end_time.strftime("%H:%M"),
      author: self.meeting_agenda.author.name,
      place: self.meeting_agenda.place,
      url: url_for(controller: 'meeting_agendas', action: 'show', id: self.meeting_agenda_id, only_path: true)
    }
  end

  def put_key_words(template)
    key_words.inject(template){ |result, key_word|
      result.gsub("%#{key_word[0]}%", key_word[1])
    }
  end

  def issue_subject
    put_key_words(Setting[:plugin_redmine_meeting][:subject])
  end

  def issue_description
    put_key_words(Setting[:plugin_redmine_meeting][:description])
  end

  def create_issue
    settings = Setting[:plugin_redmine_meeting]
    Issue.create!(
      status: IssueStatus.default,
      tracker: Tracker.find(settings[:issue_tracker]),
      subject: issue_subject,
      project: Project.find(settings[:project_id]),
      description: issue_description,
      author: User.current,
      start_date: Date.today,
      due_date: self.meeting_agenda.meet_on,
      priority: self.meeting_agenda.priority || IssuePriority.default,
      assigned_to: self.user)
  end

  def validate_meeting_agenda
    errors[:base] << ::I18n.t(:error_messages_meeting_agenda_not_valid)
  end
end
