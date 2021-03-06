class Pool < ActiveRecord::Base

  after_create :allocate_and_count_positions

  belongs_to :placement
  has_and_belongs_to_many :pooled_positions, join_table: :pooled_positions,
    class_name: 'PooledPosition', association_foreign_key: :id,
    dependent: :destroy

  validates :placement, presence: true

  delegate :applicant, to: :placement
  delegate :run,       to: :placement

  def best_pooled
    return nil if pooled_positions.count == 0
    best_pooled = pooled_positions.to_a.
      # Don't assign someone to a job they were placed at and declined before.
      reject  { |p|
        placement.applicant.declined_placements(run).
          pluck(:position_id).
          include?(p.position_id)
      }.
      sort_by { |p| p.score["total"]  }.
      detect  { |p| p.available?(run) }
  end

  def best_fit
    best_pooled.position if best_pooled
  end

  # This would add the compression too early, because we're precalculating
  # the base pools and basing RUNTIME compression off of that.
  # So we need to allocate base positions first, then add compressed positions
  # at runtime to balance out the effects of the randomness on removing jobs
  # from the base pools.
  def compress!
    compressor.compress!
  end

  def compressor
    @compressor = Compressor.new(self)
  end

  private

  def allocate_and_count_positions
    Position.base_pool_for(applicant, run).map do |position|
      PooledPosition.create!(position: position, pool: self)
    end
    update_attribute :position_count, self.pooled_positions.count
  end

  def placements_with(position)
    run.placements.where(position: position).count
  end

end
