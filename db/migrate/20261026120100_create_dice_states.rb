class CreateDiceStates < ActiveRecord::Migration[8.1]
  def change
    create_table :dice_states do |t|
      t.integer :first_die, null: false
      t.integer :second_die, null: false

      t.check_constraint "first_die BETWEEN 1 AND 6 AND second_die BETWEEN 1 AND 6", name: "dice_states_range_check"
    end

    add_index :dice_states, [ :first_die, :second_die ], unique: true
  end
end
