class AddRatingToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :rating, :integer, null: false, default: 1500
    add_check_constraint :users, "rating >= 100", name: "users_rating_check"
  end
end
