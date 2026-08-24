# frozen_string_literal: true

require "spec_helper"
require "audited/audits_helper"

describe Audited::AuditsHelper, type: :helper do
  let(:user) do
    Models::ActiveRecord::User.create!(name: "Bob", username: "bob", status: :active, favourite_device: "phone")
  end
  let(:audited_type) { Models::ActiveRecord::User.name.underscore }

  around do |example|
    example.run
  ensure
    I18n.backend.reload!
  end

  def audit_for(attributes)
    user.update!(attributes)
    user.audits.last
  end

  def store_changed_translations(changed)
    I18n.backend.store_translations(
      :en,
      "audited" => { audited_type => { "update" => { "changed" => changed } } },
    )
  end

  describe "#humanize_audit" do
    it "prefers a key scoped to the new value of an enum" do
      store_changed_translations("status" => { "banned" => "%{identifier} was banned" })

      expect(helper.humanize_audit(audit_for(status: :banned))).to(eq([ "bob was banned" ]))
    end

    it "resolves an enum to its label rather than the value stored in the database" do
      store_changed_translations("status" => "%{identifier} went from %{from} to %{to}")

      expect(helper.humanize_audit(audit_for(status: :banned))).to(eq([ "bob went from active to banned" ]))
    end

    it "falls back to the attribute key when the enum value has no translation" do
      store_changed_translations("status" => "%{identifier} changed status")

      expect(helper.humanize_audit(audit_for(status: :banned))).to(eq([ "bob changed status" ]))
    end

    it "falls back to the generated sentence when neither key is translated" do
      expect(helper.humanize_audit(audit_for(status: :banned)))
        .to(eq([ "Status was changed from active to banned" ]))
    end

    it "does not scope attributes that are not enums" do
      store_changed_translations("favourite_device" => "%{identifier} switched to %{to}")

      expect(helper.humanize_audit(audit_for(favourite_device: "tablet"))).to(eq([ "bob switched to tablet" ]))
    end
  end
end
