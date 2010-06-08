class ContentArea < ActiveRecord::Base
  has_many :exams

  validates_presence_of :title, :description

  named_scope :ordered, { :order => 'ordinal' }

  def completed_by?(user)
    exams.all? do |exam|
      !exam.version_for(user) || (
        exam.version_for(user) && exam.version_for(user).completed_by?(user)
      )
    end
  end

  def self.current_for(user)
    ordered.detect do |area|
      ! area.completed_by?(user)
    end
  end
end