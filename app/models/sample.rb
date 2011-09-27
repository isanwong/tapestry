class Sample < ActiveRecord::Base
  stampable
  acts_as_paranoid_versioned :version_column => :lock_version

  belongs_to :study
  belongs_to :kit
  belongs_to :original_kit_design_sample, :class_name => "KitDesignSample"
  belongs_to :kit_design_sample

  belongs_to :participant, :class_name => "User"
  belongs_to :owner, :class_name => "User"

  has_many :sample_logs

  validates_uniqueness_of :crc_id
  validates_uniqueness_of :url_code
  validates_presence_of :study_id
  validates_presence_of :kit_id

  scope :real, where('samples.is_destroyed is ?',nil)
  scope :destroyed, where('samples.is_destroyed is not ?',nil)
  scope :visible_to, lambda { |user|
    if user.is_admin?
      unscoped
    else
      real.scoped(:include => [:study],
                  :conditions => ['samples.owner_id=? or studies.creator_id=?',
                                  user.id, user.id])
    end
  }

  def as_json(options)
    j = super
    j.delete :participant_id
    j.delete :url_code unless options[:for] and (options[:for].is_admin? or options[:for].is_researcher_onirb?)
    j
  end

  def self.help_datatables_sort_by(sortkey, options={})
    case sortkey
    when :id, :crc_id
      sortkey
    when :url_code
      (options[:for] and options[:for].is_admin?) ? sortkey : :id
    else
      :id
    end
  end

  def self.help_datatables_search(options)
    s = 'id like :search or crc_id like :search'
    s << ' or url_code like :search' if options[:for] and options[:for].is_admin?
    s
  end
end
