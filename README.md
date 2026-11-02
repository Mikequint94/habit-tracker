# 68-Point Weekly Habit Tracker (GitHub Pages + Supabase)

## 1. Deploy to GitHub Pages
1. Create a new repository on GitHub (e.g., `habit-tracker`).
2. Upload `index.html` to the root of the repository and commit.
3. Go to **Settings → Pages** in your GitHub repository.
4. Under **Build and deployment**, set **Source** to **Deploy from a branch**, select `main` (and `/ (root)`), and click **Save**.
5. Your app will be live at `https://<your-username>.github.io/habit-tracker/` in ~60 seconds.

## 2. Connect Supabase for Two-Way Cloud Sync
1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** in the left sidebar, paste the contents of `supabase-setup.sql`, and click **Run**.
3. Go to **Project Settings → API** and copy your **Project URL** and **`anon` `public` key**.
4. Open your live Habit Tracker app, click **Supabase / Export** in the top bar, paste your URL and key, and click **Save & Sync with Supabase**.
