class MeetingAgenda < ActiveRecord::Base
  unloadable

  has_one :meeting_protocol
  has_many :meeting_questions, dependent: :delete_all, order: :title
  has_many :issues, through: :meeting_questions, order: :id
  has_many :projects, through: :issues, order: :title
  has_many :statuses, through: :issues
  has_many :meeting_members, dependent: :delete_all
  has_many :users, through: :meeting_members, order: [:lastname, :firstname]
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'

  accepts_nested_attributes_for :meeting_questions, allow_destroy: true
  accepts_nested_attributes_for :meeting_members, allow_destroy: true

  before_create :add_author_id

  attr_accessible :meeting_members_attributes
  attr_accessible :meeting_questions_attributes
  attr_accessible :subject, :place, :meet_on, :start_time, :end_time

  validates_uniqueness_of :subject, scope: :meet_on
  validates_presence_of :subject, :place, :meet_on
  validate :start_time_less_than_end_time, if: "self.start_time > self.end_time"
  validate :presence_of_meeting_questions, if: "self.meeting_questions.blank?"
  validate :presence_of_meeting_members, if: "self.meeting_members.blank?"

  scope :free, -> {
    where("id NOT IN (SELECT meeting_agenda_id FROM meeting_protocols)")
  }

  def to_s
    self.subject
  end

private

  def add_author_id
    self.author_id = User.current.id
  end

  def start_time_less_than_end_time
    errors.add(:end_time, :less_than_start_time)
  end

  def presence_of_meeting_questions
    errors.add(:meeting_questions, :must_exist)
  end

  def presence_of_meeting_members
    errors.add(:meeting_members, :must_exist)
  end
end
