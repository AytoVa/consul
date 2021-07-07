require_dependency Rails.root.join("app", "models", "officing", "residence").to_s

class Officing::Residence
  validate :local_residence

  def local_residence
    return if errors.any?

    unless residency_valid?
      store_failed_census_call
      errors.add(:local_residence, false)
    end
  end
end
