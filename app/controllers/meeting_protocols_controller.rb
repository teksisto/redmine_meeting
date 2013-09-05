class MeetingProtocolsController < ApplicationController
  unloadable

  helper :attachments
  include AttachmentsHelper
  helper :meeting_protocols
  include MeetingProtocolsHelper

  before_filter :find_object, only: [:edit, :show, :destroy, :update, :send_notices, :resend_notices]
  before_filter :new_object, only: [:new, :create]
  before_filter :require_meeting_manager, only: [:edit, :update, :new, :create, :destroy]
  before_filter :require_meeting_participator, only: [:index, :show]

  def send_notices
    (render_403; return false) unless can_send_notices?(@object)
    @object.meeting_participators.each do |member|
      send_notice(member)
    end

    redirect_to controller: 'meeting_protocols', action: 'show', id: @object.id
  end

  def resend_notices
    (render_403; return false) unless can_send_notices?(@object)
    @object.meeting_participators.each do |member|
      resend_notice(member)
    end

    redirect_to controller: 'meeting_protocols', action: 'show', id: @object.id
  end

  def show
    (render_403; return false) unless can_show_protocol?(@object)
  end

  def index
    @limit = per_page_option

    @scope = model_class.joins(:meeting_agenda).
      time_period(params[:time_period_created_on], 'meeting_protocols.created_on').
      time_period(params[:time_period_meet_on], 'meeting_agendas.meet_on').
      eql_field(params[:author_id], 'meeting_protocols.author_id').
      eql_field(params[:created_on], 'DATE(meeting_protocols.created_on)').
      eql_field(params[:meet_on], 'meeting_agendas.meet_on').
      eql_project_id(params[:project_id]).
      like_field(params[:subject], 'meeting_agendas.subject').
      uniq

    @count = @scope.count

    @pages = begin
      Paginator.new @count, @limit, params[:page]
    rescue
      Paginator.new self, @count, @limit, params[:page]
    end
    @offset ||= begin
      @pages.offset
    rescue
      @pages.current.offset
    end

    @collection = @scope.
      limit(@limit).
      offset(@offset).
#      order(sort_clause).
      order('created_on desc').
      all
  end

  def create
    (render_403; return false) unless can_create_protocol?(@object)
    @object.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    @object.meeting_participators_attributes = session[:meeting_participator_ids].map{ |user_id| {user_id: user_id} }
    if @object.save
      flash[:notice] = l(:notice_successful_create)
      render_attachment_warning_if_needed(@object)
      redirect_to action: 'show', id: @object.id
    else
      @members = User.order(:lastname, :firstname).find(session[:meeting_participator_ids])
      render action: 'new'
    end
  end

  def update
    (render_403; return false) unless can_update_protocol?(@object)
    @object.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    if @object.update_attributes(params[model_sym])
      flash[:notice] = l(:notice_successful_update)
      render_attachment_warning_if_needed(@object)
      redirect_to action: 'show', id: @object.id
    else
      @members = @object.users
      render action: 'edit'
    end
  end

  def new
    (render_403; return false) unless can_create_protocol?(@object)
    @members = @object.meeting_agenda.users
    session[:meeting_participator_ids] = @object.meeting_agenda.user_ids
    @object.meeting_answers_attributes = @object.meeting_agenda.meeting_questions.map do |question|
      {meeting_question_id: question.id, reporter_id: question.user_id}
    end
#    @object.meeting_participators_attributes = @object.meeting_agenda.meeting_members.map do |member|
#      {meeting_member_id: member.id, user_id: member.user_id}
#    end
  rescue
    render_403
  end

  def edit
    (render_403; return false) unless can_update_protocol?(@object)
    @members = @object.users
  end

  def destroy
    (render_403; return false) unless can_destroy_protocol?(@object)
    flash[:notice] = l(:notice_successful_delete) if @object.destroy
    redirect_to action: 'index'
  end

private

  def model_class
    MeetingProtocol
  end

  def model_sym
    :meeting_protocol
  end

  def find_object
    @object = model_class.find(params[:id])
  end

  def new_object
    @object = model_class.new(params[model_sym])
  end

  def require_meeting_manager
    (render_403; return false) unless User.current.meeting_manager?
  end

  def require_meeting_participator
    (render_403; return false) unless User.current.meeting_participator?
  end

  def send_notice(member)
    member.update_attribute(:issue_id, create_issue(member).try(:id))
#  rescue
  end

  def resend_notice(member)
    close_status_id = IssueStatus.find(Setting[:plugin_redmine_meeting][:notice_issue_status]).id
    if member.issue.present? && !member.issue.closed?
      member.issue.update_attribute(:status_id, close_status_id)
      member.update_attribute(:issue_id, nil)
      send_notice(member)
    end
#  rescue
  end

  def key_words
    {
      id: @object.id,
      subject: @object.meeting_agenda.subject,
      meet_on: @object.meeting_agenda.meet_on.strftime("%d.%m.%Y"),
      start_time: @object.meeting_agenda.start_time.strftime("%H:%M"),
      end_time: @object.meeting_agenda.end_time.strftime("%H:%M"),
      author: @object.author,
      place: @object.meeting_agenda.place,
      url: url_for(controller: 'meeting_protocols', action: 'show', id: @object.id)
    }
  end

  def put_key_words(template)
    key_words.inject(template){ |result, key_word|
      result.gsub("%#{key_word[0]}%", "#{key_word[1]}")
    }
  end

  def issue_subject
    put_key_words(Setting[:plugin_redmine_meeting][:notice_subject])
  end

  def issue_description
    put_key_words(Setting[:plugin_redmine_meeting][:notice_description])
  end

  def create_issue(member)
    settings = Setting[:plugin_redmine_meeting]
    Issue.create!(
      status: IssueStatus.default,
      tracker: Tracker.find(settings[:notice_issue_tracker]),
      subject: issue_subject,
      project: Project.find(settings[:notice_project_id]),
      description: issue_description,
      author: User.current,
      start_date: @object.meeting_agenda.meet_on,
      due_date: @object.meeting_agenda.meet_on + settings[:notice_duration].to_i.days,
      priority: @object.meeting_agenda.priority || IssuePriority.default,
      assigned_to: member.user)
  end
end
