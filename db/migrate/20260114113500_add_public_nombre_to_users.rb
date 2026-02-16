class AddPublicNombreToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :public_nombre, :boolean, default: true, null: false
  end
end