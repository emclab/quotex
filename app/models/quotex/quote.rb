# encoding: utf-8

module Quotex

  class Quote < ActiveRecord::Base

    belongs_to :rfq, :class_name => 'RfqxEmc::Rfq'
    belongs_to :last_updated_by, :class_name => 'Authentify::User'
    belongs_to :dept_head, :class_name => 'Authentify::User'
    belongs_to :corp_head, :class_name => 'Authentify::User'
    has_one :test_plan, :class_name => 'TestItemx::TestPlan'
    has_many :quote_test_items
    has_many :test_items, :through => :quote_test_items
    has_many :invoices

    attr_accessible :rfq_id, :quoted_total, :note, :face_total, :quote_date, :last_updated_by_id, :as => :role_new
    attr_accessible :approved_by_dept_head, :approve_date_dept_head, :dept_head_id,
                    :approved_by_corp_head, :approve_date_corp_head, :corp_head_id,
                    :approved_by_customer, :approve_date_customer, :customer_approver_name,
                    :reason_for_reject, :note, :cancelled, :quote_date, :last_updated_by_id,
                    :as => :role_update
    attr_accessor   :earliest_created_at, :latest_created_at, :sales_id_s, :customer_id_s,
                    :not_approved_by_corp_s, :not_approved_by_customer_s, :rfq_id_s, :cancelled_s, :time_frame,
                    :quoted_total, :face_total, :cancelled, :quote_date
    attr_accessible :earliest_created_at, :latest_created_at, :sales_id_s, :customer_id_s,
                    :not_approved_by_corp_s, :not_approved_by_customer_s, :rfq_id_s, :cancelled_s, :time_frame,
                    :as => :role_search

    validates :rfq_id, :presence => true
    validates_presence_of :customer_approver_name, :unless => "approved_by_customer.nil?", :message => '输入客户答复人姓名！'
    validates_numericality_of :quoted_total, :greater_than => 0.00
    validates :quote_date, :presence => true

    scope :approved_corp_head, lambda { |t| where('approved_by_corp_head = ?', t) }
    scope :approved_dept_head, lambda { |t| where('approved_by_dept_head = ?', t) }
    scope :approved_customer, lambda { |t| where('approved_by_customer = ?', t) }

    scope :active_quote, where(:cancelled => false)
    scope :cancelled_quote, where(:cancelled => true)

    def find_quotes
      quotes = Quotex::Quote.where("quote_date > ?", 6.years.ago) #.order(:rfq_id)

      quotes = quotes.where("rfq_id = ?", rfq_id_s) if rfq_id_s.present?
      quotes = quotes.where("quote_date >= ?", earliest_created_at) if earliest_created_at.present?
      quotes = quotes.where("quote_date <= ?", latest_created_at) if latest_created_at.present?
      quotes = quotes.where("(approved_by_dept_head = ? OR approved_by_dept_head IS NULL) OR (approved_by_corp_head = ? OR approved_by_corp_head IS NULL)", false, false) if not_approved_by_corp_s.present? && not_approved_by_corp_s == 'false'
      quotes = quotes.where("approved_by_dept_head = ? AND approved_by_corp_head = ?", true, true) if not_approved_by_corp_s.present? && not_approved_by_corp_s == 'true'
      quotes = quotes.where("approved_by_customer = ? OR approved_by_customer IS NULL", false ) if not_approved_by_customer_s.present?  && not_approved_by_customer_s == 'false'
      quotes = quotes.where("approved_by_customer = ?", true ) if not_approved_by_customer_s.present?  && not_approved_by_customer_s == 'true'
      quotes = quotes.where("quotex_quotes.cancelled = ?", true ) if cancelled_s.present?  && cancelled_s == 'true'
      uotes = quotes.where("quotex_quotes.cancelled = ?", false ) if cancelled_s.present?  && cancelled_s == 'false'
      quotes = quotes.joins(:rfq).where("rfqx_emc_rfqs.sales_id = ?", sales_id_s) if sales_id_s.present?
      quotes = quotes.joins(:rfq).where("rfqx_emc_rfqs.customer_id = ?", customer_id_s) if customer_id_s.present?

      quotes
    end

    protected

  end


end
