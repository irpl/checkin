# Checkin Admin Panel

React-based admin panel for managing check-in campaigns.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your Supabase credentials:
   ```
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key
   ```

3. Start development server:
   ```bash
   npm run dev
   ```

## Building

```bash
npm run build
```

Output will be in `dist/` folder.

## Features

- Admin authentication
- Campaign management (create, edit, view)
- Beacon configuration (iBeacon UUID, major/minor)
- Dynamic form builder for check-in actions
- Real-time check-in dashboard
- Filtering and search

## Project Structure

```
src/
├── main.tsx           # Entry point
├── App.tsx            # Root component with routing
├── index.css          # Tailwind styles
├── lib/
│   └── supabase.ts    # Supabase client
├── stores/
│   └── auth.ts        # Auth state (Zustand)
├── types/
│   └── index.ts       # TypeScript types
├── components/
│   └── Layout.tsx     # App shell with sidebar
└── pages/
    ├── LoginPage.tsx
    ├── RegisterPage.tsx
    ├── DashboardPage.tsx
    ├── CampaignsPage.tsx
    ├── CreateCampaignPage.tsx
    ├── CampaignDetailPage.tsx
    └── CheckinsPage.tsx
```

## Tech Stack

- React 18
- TypeScript
- Vite
- Tailwind CSS
- React Router
- React Hook Form + Zod
- Zustand (state management)
- Supabase (backend)
