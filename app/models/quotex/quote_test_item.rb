module Quotex
  class QuoteTestItem < ActiveRecord::Base
    belongs_to :quote
    belongs_to :test_item, :class_name => 'TestItemx::TestItem'
    
    validates_numericality_of :quote_id, :greater_than => 0
    validates_numericality_of :test_item_id, :greater_than => 0
    validates :test_item_id, :uniqueness => { :scope => :quote_id }   
  end

end