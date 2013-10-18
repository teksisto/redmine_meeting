class MeetingPendingIssue < ActiveRecord::Base
  unloadable

  belongs_to :meeting_container, polymorphic: true
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  belongs_to :assigned_to, class_name: 'User', foreign_key: 'assigned_to_id'
  belongs_to :project
  belongs_to :tracker, class_name: 'Tracker', foreign_key: 'tracker_id'
  belongs_to :priority, class_name: 'IssuePriority', foreign_key: 'priority_id'
  belongs_to :status, class_name: 'IssueStatus', foreign_key: 'status_id'
  has_one :issue, through: :meeting_container

  validates_uniqueness_of :meeting_container_id, scope: :meeting_container_type
#  validates_presence_of :subject, :assigned_to_id, :start_date, :due_date, :tracker_id,
#    :description, :priority_id, :status_id, if: -> { self.meeting_container && self.meeting_container.issue_type self.meeting_container.issue_type["new"] }
#  validates_presence_of :issue_note, if: -> { self.meeting_container && self.meeting_container.issue_type["update"] }
  validates_presence_of :author_id, :meeting_container_id, :meeting_container_type

  def watched_by?(user)
    true
  end

  def css_classes
    "issue tracker-#{tracker_id} status-#{status_id} #{priority.try(:css_classes)}"
  end

  def done_ratio
    if self.meeting_container.issue_id && self.executed?
      self.issue.done_ratio
    else
      0
    end
  end

  def execute
    unless self.executed?
      case self.issue_type
      when 'update'
        update_issue
      when 'create'
        create_issue
      end
      self.update_attribute(:executed_on, Time.now)
      self.update_attribute(:executed, true)
    end
  end

  def create_issue
    @issue = Issue.new(
      tracker: self.tracker,
      project: self.project,
      subject: self.subject,
      description: self.description,
      priority: self.priority,
      status: self.status,
      assigned_to: self.assigned_to,
      start_date: self.start_date,
      due_date: self.due_date
    )
    @issue.author = self.author
    @issue.parent_issue_id  = self.parent_issue_id
    @issue.watcher_user_ids = self.watcher_user_ids
    if @issue.save
      self.update_attribute(:issue_id, @issue.id)
    end
  end

  def update_issue
    @issue = self.meeting_container.issue
    @issue.init_journal(User.current, self.issue_note)
    @issue.status = IssueStatus.default
    @issue.save
  end

  def watcher_user_ids=(array)
    super(array.to_yaml)
  end

  def watcher_user_ids
    YAML.load(super)
  end
end
