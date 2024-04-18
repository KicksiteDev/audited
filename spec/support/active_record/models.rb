# frozen_string_literal: true

require "cgi"
require File.expand_path("../schema", __FILE__)

module Models
  module ActiveRecord
    class User < ::ActiveRecord::Base
      audited except: :password
      attribute :non_column_attr if Rails.gem_version >= Gem::Version.new("5.1")
      attr_protected :logins if respond_to?(:attr_protected)
      enum status: { active: 0, reliable: 1, banned: 2 }

      if Rails.gem_version >= Gem::Version.new("7.1")
        serialize :phone_numbers, type: Array
      else
        serialize :phone_numbers, Array
      end

      def name=(val)
        write_attribute(:name, CGI.escapeHTML(val))
      end
    end

    class UserExceptPassword < ::ActiveRecord::Base
      self.table_name = :users
      audited except: :password
    end

    class UserOnlyPassword < ::ActiveRecord::Base
      self.table_name = :users
      attribute :non_column_attr if Rails.gem_version >= Gem::Version.new("5.1")
      audited only: :password
    end

    class UserRedactedPassword < ::ActiveRecord::Base
      self.table_name = :users
      audited redacted: :password
    end

    class UserMultipleRedactedAttributes < ::ActiveRecord::Base
      self.table_name = :users
      audited redacted: [ :password, :ssn ]
    end

    class UserRedactedPasswordCustomRedaction < ::ActiveRecord::Base
      self.table_name = :users
      audited redacted: :password, redaction_value: [ "My", "Custom", "Value", 7 ]
    end

    if ::ActiveRecord::VERSION::MAJOR >= 7
      class UserWithEncryptedPassword < ::ActiveRecord::Base
        self.table_name = :users
        audited
        encrypts :password
      end
    end

    class UserWithReadOnlyAttrs < ::ActiveRecord::Base
      self.table_name = :users
      audited
      attr_readonly :status
    end

    class CommentRequiredUser < ::ActiveRecord::Base
      self.table_name = :users
      audited except: :password, comment_required: true
    end

    class OnCreateCommentRequiredUser < ::ActiveRecord::Base
      self.table_name = :users
      audited comment_required: true, on: :create
    end

    class OnUpdateCommentRequiredUser < ::ActiveRecord::Base
      self.table_name = :users
      audited comment_required: true, on: :update
    end

    class OnDestroyCommentRequiredUser < ::ActiveRecord::Base
      self.table_name = :users
      audited comment_required: true, on: :destroy
    end

    class NoUpdateWithCommentOnlyUser < ::ActiveRecord::Base
      self.table_name = :users
      audited update_with_comment_only: false
    end

    class AccessibleAfterDeclarationUser < ::ActiveRecord::Base
      self.table_name = :users
      audited
      attr_accessible :name, :username, :password if respond_to?(:attr_accessible)
    end

    class AccessibleBeforeDeclarationUser < ::ActiveRecord::Base
      self.table_name = :users
      attr_accessible :name, :username, :password if respond_to?(:attr_accessible)
      audited
    end

    class NoAttributeProtectionUser < ::ActiveRecord::Base
      self.table_name = :users
      audited
    end

    class UserWithAfterAudit < ::ActiveRecord::Base
      self.table_name = :users
      audited
      attr_accessor :bogus_attr, :around_attr

      private

      def after_audit
        self.bogus_attr = "do something"
      end

      def around_audit
        self.around_attr = yield
      end
    end

    class MaxAuditsUser < ::ActiveRecord::Base
      self.table_name = :users
      audited max_audits: 5
    end

    class Company < ::ActiveRecord::Base
      audited
    end

    class Company::STICompany < Company
    end

    class Country < ::ActiveRecord::Base
      audited

      has_many :comapnies, class_name: "OwnedCompany", dependent: :destroy
    end

    class Owner < ::ActiveRecord::Base
      self.table_name = "users"
      audited
      has_many :companies, class_name: "OwnedCompany", dependent: :destroy
      accepts_nested_attributes_for :companies
      enum status: { active: 0, reliable: 1, banned: 2 }
    end

    class OwnedCompany < ::ActiveRecord::Base
      self.table_name = "companies"
      belongs_to :owner, class_name: "Owner", touch: true
      belongs_to :country
      # declare attr_accessible before calling audited
      attr_accessible :name, :owner, :country if respond_to?(:attr_accessible)
      audited associated_with: [ :owner, :country ]
    end

    class OwnedCompany::STICompany < OwnedCompany
    end


    class Driver < ::ActiveRecord::Base
      self.table_name = "drivers"

      has_many :vehicles, class_name: "Vehicle"

      audited
    end

    class Vehicle < ::ActiveRecord::Base
      self.table_name = "vehicles"

      belongs_to :driver, class_name: "Driver"

      audited associated_with: :driver
      audit_associated_attribute :driver, :name
    end

    class OnUpdateDestroy < ::ActiveRecord::Base
      self.table_name = "companies"
      audited on: [ :update, :destroy ]
    end

    class OnCreateDestroy < ::ActiveRecord::Base
      self.table_name = "companies"
      audited on: [ :create, :destroy ]
    end

    class OnCreateDestroyUser < ::ActiveRecord::Base
      self.table_name = "users"
      audited on: [ :create, :destroy ]
    end

    class OnCreateDestroyExceptName < ::ActiveRecord::Base
      self.table_name = "companies"
      audited except: :name, on: [ :create, :destroy ]
    end

    class OnCreateUpdate < ::ActiveRecord::Base
      self.table_name = "companies"
      audited on: [ :create, :update ]
    end

    class OnTouchOnly < ::ActiveRecord::Base
      self.table_name = "users"
      audited on: [ :touch ]
    end
  end
end
