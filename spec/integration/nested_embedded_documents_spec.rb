require 'spec_helper'

describe Mongoid::History::Tracker do
  before :all do
    class Model
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name, type: String
      belongs_to :user, inverse_of: :models
      embeds_many :embones
      accepts_nested_attributes_for :embones

      track_history on: :all,       # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false    # track document destruction, default is false
    end

    class Embone
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embeds_many :embtwos, store_as: :ems
      embedded_in :model

      track_history on: :all,       # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false,    # track document destruction, default is false
                    scope: :model
    end

    class Embtwo
      include Mongoid::Document
      include Mongoid::History::Trackable

      field :name
      embedded_in :embone

      track_history on: :all,       # track title and body fields only, default is :all
                    modifier_field: :modifier, # adds "referenced_in :modifier" to track who made the change, default is :modifier
                    version_field: :version,   # adds "field :version, :type => Integer" to track current version, default is :version
                    track_create: false,    # track document creation, default is false
                    track_update: true,     # track document updates, default is true
                    track_destroy: false,    # track document destruction, default is false
                    scope: :model
    end

    class User
      include Mongoid::Document
      has_many :models, dependent: :destroy, inverse_of: :user
    end
  end

  it "should be able to track history for nested embedded documents" do
    user = User.new
    user.save!

    model = Model.new(name: "m1name")
    model.user = user
    model.save!
    embedded1 = model.embones.create(name: "e1name")
    embedded2 = embedded1.embtwos.create(name: "e2name")

    embedded2.name = "a new name"
    embedded2.save!

    model.history_tracks.first.undo! user

    # without calling this, line 92 throws an error on
    # lib/mongoid/history/trackable.rb#315 (327 in this branch)
    #   NoMethodError:
    #     undefined method `[]' for nil:NilClass
    embedded1.history_tracks

    embedded1.reload.name.should == "e1name"
    embedded2.reload.name.should == "e2name"
  end

  it "tracks changes for nested attributes" do
    model = Model.create!(name: 'model_2')
    embedded = model.embones.create(name: 'embedded_1')

    model.update_attributes(name: 'model_2-updated', embones_attributes: [{ name: 'embedded_1-updated', id: embedded.id }])

    expect(embedded.history_tracks.count).to eq(1)
    expect(embedded.history_tracks.last.original).to eq({ 'name' => 'embedded_1' })
    expect(embedded.history_tracks.last.modified).to eq({ 'name' => 'embedded_1-updated' })
  end
end
