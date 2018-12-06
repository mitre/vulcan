class Ability
  include CanCan::Ability

  def initialize(user)
    if user.present?
      if user.has_role?(:admin)
        can :manage, :all
      end
      if user.has_role?(:vendor)
        can :read, :all
        can :manage, [
        Srg,
        Vendor,
        Project,
        ProjectHistory,
        Request,
        NistFamily,
        NistControl
      ], created_by: user.id
      end
      if user.has_role?(:sponsor)
        can :read, :all
        can :manage, [
          Srg,
          SponsorAgency,
          Project,
          ProjectHistory,
          Request,
          NistFamily,
          NistControl,
          ProjectChangeStatus,
          ProjectControlHistory,
          ProjectControl
        ], created_by: user.id
      end
    end
  end
end
