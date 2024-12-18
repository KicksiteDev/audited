# frozen_string_literal: true

module Audited
  module AuditsHelper
    def humanize_audit(audit)
      downcased_type = audit.auditable_type.underscore

      audited_changes = audit.humanizable_audited_changes

      i18n_context = if respond_to?(audit.humanized_path_method) && audit.auditable.present?
        {
          identifier: link_to(
            audit.humanized_identifier,
            send(audit.humanized_path_method, **audit.humanized_path_options),
            target: :_blank,
            rel: "noopener noreferrer",
          ),
        }
      else
        { identifier: audit.humanized_identifier }
      end

      changes = case audit.action
      when "create"
        humanize_create(audited_changes, downcased_type, i18n_context)
      when "update"
        humanize_update(audited_changes, downcased_type, i18n_context)
      when "destroy"
        humanize_destroy(audited_changes, downcased_type, i18n_context)
      end

      Array.wrap(changes).map { |change| sanitize(change, tags: [ "a" ], attributes: [ "target", "href", "rel" ]) }
    end

    private

    def humanize_create(audited_changes, type, i18n_context)
      t(
        "audited.#{type}.create",
        default: "Created.",
        **audited_changes,
        **i18n_context,
      )
    end

    def humanize_destroy(audited_changes, type, i18n_context)
      t(
        "audited.#{type}.destroy",
        default: "Deleted.",
        **audited_changes,
        **i18n_context,
      )
    end

    def humanize_update(audited_changes, type, i18n_context)
      array = audited_changes.map do |k, v|
        if v.first.is_a?(TrueClass) || v.first.is_a?(FalseClass) || v.last.is_a?(TrueClass) || v.last.is_a?(FalseClass)
          next humanize_changed_boolean(k, v, type, i18n_context)
        end

        first_present = !v.first.nil?
        last_present = !v.last.nil?

        if k.to_s.ends_with?("date") || k.to_s.ends_with?("through")
          v[0] = l(v.first.to_date) if v.first.present?
          v[1] = l(v.last.to_date) if v.last.present?
        end

        if first_present && last_present
          humanize_changed(k, v, type, i18n_context)
        elsif !first_present && last_present
          t(
            "audited.#{type}.update.added.#{k}",
            value: v.last,
            default: "#{k.to_s.titleize} was added #{v.last}",
            **i18n_context,
          )
        else
          t(
            "audited.#{type}.update.removed.#{k}",
            value: v.first,
            default: "#{k.to_s.titleize} #{v.first} was removed.",
            **i18n_context,
          )
        end
      end

      array.flatten
    end

    def humanize_changed(key, value, type, i18n_context)
      return humanize_changed_array(key, value, type, i18n_context) if value.first.is_a?(Array)
      return humanize_changed_hash(key, value, type, i18n_context) if value.first.is_a?(Hash)

      t(
        "audited.#{type}.update.changed.#{key}",
        from: value.first,
        to: value.last,
        default: "#{key.to_s.titleize} was changed from #{value.first} to #{value.last}",
        **i18n_context,
      )
    end

    def humanize_changed_boolean(key, value, type, i18n_context)
      if !value.first && value.last
        t(
          "audited.#{type}.update.changed.boolean.#{key}.enabled",
          default: "#{key.to_s.titleize} enabled.",
          **i18n_context,
        )
      else
        t(
          "audited.#{type}.update.changed.boolean.#{key}.disabled",
          default: "#{key.to_s.titleize} disabled.",
          **i18n_context,
          )
      end
    end

    def humanize_changed_array(key, value, type, i18n_context)
      removed = value.first - value.last
      added = value.last - value.first

      changes = []

      if added.any?
        changes << t(
          "audited.#{type}.update.changed.array.added.#{key}",
          added: added.join(", "),
          default: "#{key.to_s.titleize} had #{added.join(", ")} added.",
          **i18n_context,
        )
      end

      if removed.any?
        changes << t(
          "audited.#{type}.update.changed.array.removed.#{key}",
          removed: removed.join(", "),
          default: "#{key.to_s.titleize} had #{removed.join(", ")} removed.",
          **i18n_context,
        )
      end

      changes
    end

    def humanize_changed_hash(key, value, type, i18n_context)
      changes = {}

      value.first.each do |k, v|
        next if v == value.last[k]

        changes[k] = [ v, value.last[k] ]
      end

      value.last.each do |k, v|
        next if value.first.key?(k)

        changes[k] = [ nil, v ]
      end

      humanize_update(changes, type, i18n_context)
    end
  end
end
