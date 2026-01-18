/**
 * Membership-related TypeScript interfaces
 */

/**
 * Member role values
 */
export type MemberRole = 'viewer' | 'author' | 'reviewer' | 'admin'

/**
 * Membership type (polymorphic)
 */
export type MembershipType = 'Project' | 'Component'

/**
 * Core Membership interface matching Rails Membership model
 */
export interface IMembership {
  id: number
  user_id: number
  membership_type: MembershipType
  membership_id: number
  role: MemberRole
  created_at: string
  updated_at: string
  // Delegated from User
  name: string
  email: string
}

/**
 * Membership creation data
 */
export interface IMembershipCreate {
  user_id: number
  membership_type: MembershipType
  membership_id: number
  role: MemberRole
}

/**
 * Membership update data
 */
export interface IMembershipUpdate {
  role: MemberRole
}

/**
 * Available member for adding to project/component
 */
export interface IAvailableMember {
  id: number
  name: string
  email: string
}
