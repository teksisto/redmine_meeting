module MeetingPlugin
  module MailerPatch
    def self.included(base)

      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)

      base.class_eval do
        include Rails.application.routes.url_helpers
      end

    end

    module ClassMethods
      def meeting_approver_create(approver)
        author = User.current#approver.meeting_container.author
        user = approver.user
        container = approver.meeting_container
        mail_meeting_approver_create(author, user, container)
      end

      def meeting_approver_destroy(approver)
        author = User.current #approver.meeting_container.author
        user = approver.user
        container = approver.meeting_container
        mail_meeting_approver_destroy(author, user, container)
      end

      def meeting_approver_approve(approver)
        author = approver.meeting_container.author
        user = approver.user
        container = approver.meeting_container
        mail_meeting_approver_approve(author, user, container)
      end

      def meeting_comment_create(comment)
        author = comment.meeting_container.author
        user = comment.author
        container = case comment.meeting_container_type
          when 'MeetingQuestion'
            comment.meeting_container.meeting_agenda
          when 'MeetingAnswer', 'MeetingExtraAnswer'
            comment.meeting_container.meeting_protocol
          when 'MeetingAgenda', 'MeetingProtocol'
            comment.meeting_container
        end
        comment_for = case comment.meeting_container_type
          when 'MeetingQuestion'
            comment.meeting_container.title
          when 'MeetingAnswer', 'MeetingExtraAnswer'
            comment.meeting_container.description
          when 'MeetingAgenda', 'MeetingProtocol'
            nil
        end
        comment = comment.note
        mail_meeting_comment_create(author, user, container, comment, comment_for)
      end

      def meeting_external_approver_agenda_create(approver)
        mail_meeting_external_approver_agenda_create(approver)
      end

      def meeting_external_approver_protocol_create(approver)
        mail_meeting_external_approver_protocol_create(approver)
      end

      def meeting_contacts_invite(meeting_contact)
        mail_meeting_contacts_invite(meeting_contact)
      end

      def meeting_contacts_notice(meeting_contact)
        mail_meeting_contacts_notice(meeting_contact)
      end
    end

    module InstanceMethods
      def mail_meeting_approver_create(author, user, container)
        @user = user
        @author = author
        @container = container
        type = {MeetingAgenda => ::I18n.t(:label_meeting_agenda), MeetingProtocol => ::I18n.t(:label_meeting_protocol)}[container.class]
        subject = ::I18n.t(:message_subject_meeting_approver_create, author: @author.name, type: type, type_id: container.id)

        mail(to: user.mail, subject: subject)
      end

      def mail_meeting_approver_destroy(author, user, container)
        @user = user
        @author = author
        @container = container
        type = {MeetingAgenda => ::I18n.t(:label_meeting_agenda), MeetingProtocol => ::I18n.t(:label_meeting_protocol)}[container.class]
        subject = ::I18n.t(:message_subject_meeting_approver_destroy, author: @author.name, type: type, type_id: container.id)

        mail(to: user.mail, subject: subject)
      end

      def mail_meeting_approver_approve(author, user, container)
        @user = user
        @author = author
        @container = container
        type = {MeetingAgenda => ::I18n.t(:label_meeting_agenda), MeetingProtocol => ::I18n.t(:label_meeting_protocol)}[container.class]
        subject = ::I18n.t(:message_subject_meeting_approver_approve, user: @user.name, type: type, type_id: container.id)

        mail(to: author.mail, subject: subject)
      end

      def mail_meeting_comment_create(author, user, container, comment, comment_for)
        @user = user
        @author = author
        @container = container
        @comment = comment
        @comment_for = comment_for
        type = {MeetingAgenda => ::I18n.t(:label_meeting_agenda), MeetingProtocol => ::I18n.t(:label_meeting_protocol)}[container.class]
        subject = ::I18n.t(:message_subject_meeting_comment_create, user: @user.name, type: type, type_id: container.id)

        mail(to: author.mail, subject: subject)
      end

      def mail_meeting_external_approver_agenda_create(approver)
        container = approver.meeting_container
        author = container.author
        contact = approver.contact
        address = container.is_external? ? container.address : container.meeting_company.fact_address

        key_words = {
          contact: contact,
          subject: container.subject,
          meet_on: container.meet_on.strftime("%d-%m-%Y"),
          start_time: container.start_time.strftime("%H:%M"),
          end_time: container.end_time.strftime("%H:%M"),
          author: author,
          "author.job_title" => author.job_title,
          "author.mail" => author.mail,
          "author.phone" => author.phone,
          meeting_company: container.meeting_company,
          address: address
        }

        @body = key_words.inject(Setting.plugin_redmine_meeting[:external_approvers_agenda_description]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }
        subject = key_words.inject(Setting.plugin_redmine_meeting[:external_approvers_agenda_subject]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }

        attachments["Pv%04d_#{key_words[:meet_on]}.pdf" % container.id] = MeetingAgendaReport.new.to_pdf(container)
        mail(to: contact.email, subject: subject)
      end

      def mail_meeting_external_approver_protocol_create(approver)
        container = approver.meeting_container
        author = container.author
        contact = approver.contact
        address = container.is_external? ? container.address : container.meeting_company.fact_address

        key_words = {
          contact: contact,
          subject: container.subject,
          meet_on: container.meet_on.strftime("%d-%m-%Y"),
          start_time: container.start_time.strftime("%H:%M"),
          end_time: container.end_time.strftime("%H:%M"),
          author: author,
          "author.job_title" => author.job_title,
          "author.mail" => author.mail,
          "author.phone" => author.phone,
          meeting_company: container.meeting_company,
          address: address
        }

        @body = key_words.inject(Setting.plugin_redmine_meeting[:external_approvers_protocol_description]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }
        subject = key_words.inject(Setting.plugin_redmine_meeting[:external_approvers_protocol_subject]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }

        attachments["Pt%04d_#{key_words[:meet_on]}.pdf" % container.id] = MeetingProtocolReport.new.to_pdf(container)
        mail(to: contact.email, subject: subject)
      end

      def mail_meeting_contacts_invite(meeting_contact)
        container = meeting_contact.meeting_container
        author = container.author
        contact = meeting_contact.contact
        address = container.is_external? ? container.address : container.meeting_company.fact_address

        key_words = {
          contact: contact,
          subject: container.subject,
          meet_on: container.meet_on.strftime("%d-%m-%Y"),
          start_time: container.start_time.strftime("%H:%M"),
          end_time: container.end_time.strftime("%H:%M"),
          author: author,
          "author.job_title" => author.job_title,
          "author.mail" => author.mail,
          "author.phone" => author.phone,
          meeting_company: container.meeting_company,
          address: address
        }

        @body = key_words.inject(Setting.plugin_redmine_meeting[:contacts_agenda_description]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }
        subject = key_words.inject(Setting.plugin_redmine_meeting[:contacts_agenda_subject]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }

        attachments["Pv%04d_#{key_words[:meet_on]}.pdf" % container.id] = MeetingAgendaReport.new.to_pdf(container)
        mail(to: contact.email, subject: subject)
      end

      def mail_meeting_contacts_notice(meeting_contact)
        container = meeting_contact.meeting_container
        author = container.author
        contact = meeting_contact.contact
        address = container.is_external? ? container.address : container.meeting_company.fact_address

        key_words = {
          contact: contact,
          subject: container.subject,
          meet_on: container.meet_on.strftime("%d-%m-%Y"),
          start_time: container.start_time.strftime("%H:%M"),
          end_time: container.end_time.strftime("%H:%M"),
          author: author,
          "author.job_title" => author.job_title,
          "author.mail" => author.mail,
          "author.phone" => author.phone,
          meeting_company: container.meeting_company,
          address: address
        }

        @body = key_words.inject(Setting.plugin_redmine_meeting[:contacts_protocol_description]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }
        subject = key_words.inject(Setting.plugin_redmine_meeting[:contacts_protocol_subject]){ |result, item|
          result.gsub("%#{item.first}%", "#{item.last}")
        }

        attachments["Pt%04d_#{key_words[:meet_on]}.pdf" % container.id] = MeetingProtocolReport.new.to_pdf(container)
        mail(to: contact.email, subject: subject)
      end

#      def mail_meeting_approver_create(author, user, container)
#        set_language_if_valid user.language
#        mail(to: user.mail, subject: @subject)
#        @issues = issues
#        issues_count = @issues.count

#        @conjugation = case issues_count
#                         when 1    then 1
#                         when 2..4 then 2
#                         else           5
#                       end

#        @subject = l(:"#{@conjugation}", scope: "mail_subject_approval_items", :count => issues_count)
#        @body = l(:"#{@conjugation}", scope: "mail_body_approval_items", :count => issues_count)

#        @username = user.name

#        mail(to: user.mail, subject: @subject)

#      end

    end
  end
end
