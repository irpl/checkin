import { create } from 'zustand'
import { User, Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'

interface AuthState {
  user: User | null
  session: Session | null
  loading: boolean
  initialize: () => Promise<void>
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string, orgName: string) => Promise<void>
  signOut: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  session: null,
  loading: true,

  initialize: async () => {
    const { data: { session } } = await supabase.auth.getSession()
    set({ session, user: session?.user ?? null, loading: false })

    supabase.auth.onAuthStateChange((_event, session) => {
      set({ session, user: session?.user ?? null })
    })
  },

  signIn: async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
  },

  signUp: async (email: string, password: string, orgName: string) => {
    // Sign up the user
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password
    })
    if (authError) throw authError
    if (!authData.user) throw new Error('Failed to create user')

    // Use the register_admin function to create org and admin profile
    // This function runs with SECURITY DEFINER to bypass RLS
    const { error: regError } = await supabase.rpc('register_admin', {
      admin_user_id: authData.user.id,
      admin_email: email,
      org_name: orgName
    })
    if (regError) throw regError
  },

  signOut: async () => {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
  },
}))
