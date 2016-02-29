class CreateApplicants < ActiveRecord::Migration

  def change
    enable_extension 'uuid-ossp'
    create_table :applicants do |t|
      t.string :interests, array: true
      t.boolean :prefers_nearby,   null: false, default: true
      t.boolean :has_transit_pass, null: false, default: false
      t.uuid :uuid, null: false, default: 'uuid_generate_v4()'
      t.timestamps null: false
    end
  end

end
