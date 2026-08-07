class ChangeClientsOnboardingStatusDefaultToPending < ActiveRecord::Migration[8.1]
  def change
    change_column_default :clients, :onboarding_status, from: nil, to: "pending"
    up_only { execute "UPDATE clients SET onboarding_status = 'pending' WHERE onboarding_status IS NULL" }
  end
end
