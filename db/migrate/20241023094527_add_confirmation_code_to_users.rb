class AddConfirmationCodeToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :confirmation_code, :string
  end
end
