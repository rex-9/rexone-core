class AddConfirmationCodeToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :confirmation_code, :string
    add_column :users, :confirmation_code_sent_at, :datetime
  end
end
