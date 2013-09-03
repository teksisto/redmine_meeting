class MeetingAgenda < ActiveRecord::Base
  unloadable

  has_one :meeting_protocol
  has_many :meeting_questions, dependent: :delete_all, order: :id
  has_many :issues, through: :meeting_questions, order: :id, uniq: true
  has_many :projects, through: :issues, order: :title, uniq: true
  has_many :statuses, through: :issues, uniq: true
  has_many :meeting_members, dependent: :delete_all
  has_many :users, through: :meeting_members, order: [:lastname, :firstname], uniq: true
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  belongs_to :priority, class_name: 'IssuePriority', foreign_key: 'priority_id'

  accepts_nested_attributes_for :meeting_questions, allow_destroy: true
  accepts_nested_attributes_for :meeting_members, allow_destroy: true

  before_create :add_author_id

  attr_accessible :meeting_members_attributes
  attr_accessible :meeting_questions_attributes
  attr_accessible :subject, :place, :meet_on, :start_time, :end_time, :priority_id

  validates_uniqueness_of :subject, scope: :meet_on
  validates_presence_of :subject, :place, :meet_on, :start_time, :end_time, :priority_id
  validate :end_time_less_than_start_time, if: -> {self.start_time && self.end_time && (self.end_time <= self.start_time)}
  validate :meet_on_less_than_today, if: -> {
    self.meet_on && (self.meet_on < Date.today)
  }
  validate :start_time_less_than_now, if: -> {
    self.meet_on && (self.meet_on == Date.today) &&
    self.start_time && (self.start_time.seconds_since_midnight < Time.now.seconds_since_midnight)
  }
  validate :end_time_less_than_now, if: -> {
    self.meet_on && (self.meet_on == Date.today) &&
    self.end_time && (self.end_time.seconds_since_midnight < Time.now.seconds_since_midnight)
  }
  validate :presence_of_meeting_questions, if: -> {self.meeting_questions.blank?}
  validate :presence_of_meeting_members, if: -> {self.meeting_members.blank?}

  scope :free, -> {
    where("id NOT IN (SELECT meeting_agenda_id FROM meeting_protocols)")
  }

  scope :like_field, ->(q, field) {
    if q.present? && field.present?
      where("LOWER(#{field}) LIKE LOWER(?)", "%#{q.to_s.downcase}%")
    end
  }

  scope :eql_field, ->(q, field) {
    if q.present? && field.present?
      where("#{field} = ?", q)
    end
  }

  scope :eql_project_id, ->(q) {
    if q.present?
      joins(meeting_questions: :issue).where("issues.project_id = ?", q)
    end
  }

  def to_s
    self.subject
  end

private

  def add_author_id
    self.author_id = User.current.id
  end

  def end_time_less_than_start_time
    errors.add(:end_time, :less_than_start_time)
  end

  def meet_on_less_than_today
    errors.add(:meet_on, :less_than_today)
  end

  def start_time_less_than_now
    errors.add(:start_time, :less_than_now)
  end

  def end_time_less_than_now
    errors.add(:end_time, :less_than_now)
  end

  def presence_of_meeting_questions
    errors[:base] << ::I18n.t(:error_messages_meeting_questions_must_exist)
  end

  def presence_of_meeting_members
    if self.meeting_questions.blank? || self.meeting_questions.all?{ |q| q.user.blank? }
      errors.add(:meeting_members, :must_exist)
    end
  end
end
