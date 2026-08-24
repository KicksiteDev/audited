# frozen_string_literal: true

module Audited
  module AuditsHelper
    def humanize_audit(audit)
      downcased_type = audit.auditable_type.underscore

      enums = audited_enums(audit)
      audited_changes = humanize_enum_values(audit.humanizable_audited_changes, enums)

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
        humanize_update(audited_changes, downcased_type, i18n_context, enums)
      when "destroy"
        humanize_destroy(audited_changes, downcased_type, i18n_context)
      end

      Array.wrap(changes).map { |change| sanitize(change, tags: [ "a" ], attributes: [ "target", "href", "rel" ]) }
    end

    private

    def audited_enums(audit)
      klass = audit.auditable_type.safe_constantize
      return {} unless klass.respond_to?(:defined_enums)

      klass.defined_enums
    end

    def humanize_enum_values(audited_changes, enums)
      return audited_changes if enums.empty?

      audited_changes.to_h do |key, value|
        mapping = enums[key.to_s]
        next [ key, value ] if mapping.nil?

        [ key, humanize_enum_value(value, mapping) ]
      end
    end

    def humanize_enum_value(value, mapping)
      return mapping.key(value) || value unless value.is_a?(Array)

      value.map { |element| mapping.key(element) || element }
    end

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

    def humanize_update(audited_changes, type, i18n_context, enums)
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
          humanize_changed(k, v, type, i18n_context, enums)
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

    def humanize_changed(key, value, type, i18n_context, enums)
      return humanize_changed_array(key, value, type, i18n_context) if value.first.is_a?(Array)
      return humanize_changed_hash(key, value, type, i18n_context, enums) if value.first.is_a?(Hash)

      i18n_key, default = humanize_changed_lookup(key, value, type, enums)

      t(
        i18n_key,
        from: value.first,
        to: value.last,
        default: default,
        **i18n_context,
      )
    end

    def humanize_changed_lookup(key, value, type, enums)
      fallback = "#{key.to_s.titleize} was changed from #{value.first} to #{value.last}"
      generic = :"audited.#{type}.update.changed.#{key}"

      return [ generic, fallback ] unless enums.key?(key.to_s)

      [ :"#{generic}.#{value.last}", [ generic, fallback ] ]
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

    def humanize_changed_hash(key, value, type, i18n_context, enums)
      changes = {}

      value.first.each do |k, v|
        next if v == value.last[k]

        changes[k] = [ v, value.last[k] ]
      end

      value.last.each do |k, v|
        next if value.first.key?(k)

        changes[k] = [ nil, v ]
      end

      humanize_update(changes, type, i18n_context, enums)
    end
  end
end
