class CreateTimeControls < ActiveRecord::Migration[8.1]
  def change
    create_table :time_controls do |t|
      t.integer :initial_seconds, null: false
      t.integer :increment_seconds, null: false, default: 0

      t.check_constraint "initial_seconds BETWEEN 60 AND 10800", name: "time_controls_initial_check"
      t.check_constraint "increment_seconds BETWEEN 0 AND 60", name: "time_controls_increment_check"
    end

    add_index :time_controls, [ :initial_seconds, :increment_seconds ], unique: true
  end
end
