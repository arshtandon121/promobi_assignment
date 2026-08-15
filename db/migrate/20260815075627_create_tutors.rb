class CreateTutors < ActiveRecord::Migration[8.1]
  def change
    create_table :tutors do |t|
      t.string :name, null: false
      t.string :email, null: false, index: { unique: true }
      t.references :course, null: false, foreign_key: true

      t.timestamps
    end
  end
end
