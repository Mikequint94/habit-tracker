# 68-Point Weekly Habit Tracker (GitHub Pages + Supabase)

## 1. Deploy to GitHub Pages
1. Create a new repository on GitHub (e.g., `habit-tracker`).
2. Upload `index.html` to the root of the repository and commit.
3. Go to **Settings → Pages** in your GitHub repository.
4. Under **Build and deployment**, set **Source** to **Deploy from a branch**, select `master` (and `/ (root)`), and click **Save**.
5. Your app will be live at `https://<your-username>.github.io/habit-tracker/` in ~60 seconds.

## 2. Connect Supabase for Two-Way Cloud Sync
1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** in the left sidebar, paste the contents of `supabase-setup.sql`, and click **Run**.
3. Go to **Project Settings → API** and copy your **Project URL** and **`anon` `public` key**.
4. Open your live Habit Tracker app, click **Supabase / Export** in the top bar, paste your URL and key, and click **Save & Sync with Supabase**.

## 3. Install it on your phone
Open the GitHub Pages URL on your phone, then:
- **iPhone (Safari):** Share → **Add to Home Screen**
- **Android (Chrome):** ⋮ menu → **Install app**

It opens full-screen and works offline. Edits made offline sync to Supabase the next time you're online.

## 4. Editing styles (Tailwind)
The page uses a prebuilt `tailwind.css` instead of the Tailwind CDN script. If you (or an AI) add **new** Tailwind classes to `index.html`, rebuild the CSS or those classes won't have any styling:

```bash
npm install        # first time only
npm run build:css  # regenerates tailwind.css — commit it
```

If you change any file listed in `sw.js`, bump `CACHE_VERSION` there so installed copies pick up the update.

## How sync works
- Each week records when it was last edited (`updatedAt`). Only weeks you changed are uploaded.
- On open, when you come back to the app, and when you go back online, the app pulls from Supabase and keeps the **newer copy of each week**.
- If an upload fails, the badge turns red ("Sync failed — saved locally"). Your edits stay queued and retry automatically.
- Check-ins before 4am count toward the previous day.
