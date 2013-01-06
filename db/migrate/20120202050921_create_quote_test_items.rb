class CreateQuoteTestItems < ActiveRecord::Migration
  def change
    create_table :quotex_quote_test_items do |t|
      t.integer :quote_id
      t.integer :test_item_id

      t.timestamps
    end
  end
end
