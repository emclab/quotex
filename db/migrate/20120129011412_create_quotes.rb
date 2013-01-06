class CreateQuotes < ActiveRecord::Migration
  def change
    create_table :quotex_quotes do |t|
      t.integer :rfq_id
      t.decimal :total, :precision => 8, :scale => 2
      t.integer :discount, :default => 0
      t.integer :last_updated_by_id  
      t.boolean :approved_by_dept_head
      t.datetime :approve_date_dept_head
      t.integer :dept_head_id
      t.boolean :approved_by_corp_head
      t.datetime :approve_date_corp_head
      t.integer :corp_head_id
      t.boolean :approved_by_customer
      t.datetime :approve_date_custuomer
      t.string :customer_approver_name
      t.text :reason_for_reject
      t.text :note

      t.timestamps
    end
  end
end
