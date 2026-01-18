/**
 * Navigation Types
 */

export interface INavLink {
  icon: string
  name: string
  link: string
}

export interface INavigationState {
  links: INavLink[]
  accessRequests: IAccessRequestNotification[]
  loading: boolean
}

export interface IAccessRequestNotification {
  id: number
  user: {
    id: number
    name: string
    email: string
  }
  project: {
    id: number
    name: string
  }
  created_at: string
}
