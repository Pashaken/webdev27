class CreateUsers < ActiveRecord::Migration[8.1]
  def up
    create_table :users, id: :serial, if_not_exists: true do |t|
      t.string :username, limit: 50, null: false
      t.string :password_digest, limit: 255, null: false
      t.datetime :created_at, precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :users, :username, unique: true, name: "users_username_key", if_not_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
