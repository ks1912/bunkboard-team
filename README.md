# BunkBoard Team – sales app for PG / hostel clients

A phone-friendly web app. Your sales reps sign in, add the PGs/hostels they meet, log visits and follow-ups, run the compliance checklist on site, quote prices and move each PG through Lead → Pilot → Paying → Lost. Admins (you) see every rep's clients, performance, revenue and can export to Excel.

Runs free on Supabase (database + login) and any free static host. Setup takes about 30 minutes.

## 1. Create the database (Supabase)

1. Go to https://supabase.com, sign up, click **New project**. Pick a region near you (Mumbai/Singapore) and set a database password.
2. When the project is ready open **SQL Editor → New query**, paste the whole of `schema.sql`, click **Run**. It should say "Success".
3. Open **Authentication → Sign In / Providers → Email**. For the easiest start, switch **Confirm email** OFF (reps can sign in immediately). If you leave it ON, reps must click the email link first.
4. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key.

## 2. Connect the app

Open `config.js` and paste both values between the quotes. Save.

## 3. Put it online (free)

Pick one:
- **Netlify Drop** (easiest): go to https://app.netlify.com/drop, drag this whole folder in. You get a link like `https://something.netlify.app`.
- **Cloudflare Pages** or **GitHub Pages**: upload the folder and enable hosting.

Then, in Supabase **Authentication → URL Configuration**, set **Site URL** to your link (needed for password-reset emails).

## 4. First login

1. Open your link, tap **Create account**. **Leave the invite code empty**: the first account becomes the **admin**.
2. Go to **More → Team & invite code**. Share the invite code with each rep.
3. Reps open the link, tap Create account, enter their name, email, password and the invite code.
4. On a phone: browser menu → **Add to Home screen**.

## What each person can do

| | Rep | Admin |
|---|---|---|
| Add PGs, log visits, follow-ups, checklist, stage, fees, referrals | own clients | all clients |
| See other reps' clients | no | yes |
| Rep performance, area chart, revenue | – | yes |
| Reassign a client, delete a client | – | yes |
| Invite code, switch reps on/off, make admin | – | yes |
| Export CSV (opens in Excel) | own | all |

A rep adding a PG whose owner phone already exists with another rep gets a warning (not the other rep's data, only name/area/rep/stage).

## Owner demo (to show PG owners)

Open `owner-demo.html` (link on the sign-in screen and under More). It needs no login and stores nothing in the database: a fictional 5-floor, 26-room, 78-bed PG with 1/2/3/4-sharing rooms, residents, rent collection (cash/UPI), reminders, staff salaries and a compliance score. English, Telugu and Hindi. "Reset demo" restores it.

## Seeker demo (the PG-finder side)

Open `find-pg.html` (link on the sign-in screen and under More). It shows what people looking for a PG would see: search by area, gender, sharing and budget; a verified score from licences and safety checks; live bed counts; true monthly cost; compare up to 3; book a visit with recorded consent; reserve a bed; and see their stay.

It is linked to `owner-demo.html` through the browser's local storage. Open both pages in the same browser and the whole loop works: the seeker books a visit, the owner sees it under **Enquiries**, confirms, moves the person in, and when the seeker pays rent the owner's Residents list turns Paid. Seeker and owner demos share data on one device only. Nothing is sent to the database.

## Notes and limits

- Needs internet; there is no offline mode.
- Supabase's free plan pauses a project after a week of no use. Open the dashboard and click Restore if that happens. Paid plan removes this.
- Back up: Supabase Dashboard → Database → Backups (paid) or use the in-app CSV export regularly.
- Client records hold owner names and phone numbers, which are personal data under India's DPDP Act. Keep access to the invite code limited, switch off reps who leave, and don't share the export outside the company.
- The "anon key" in `config.js` is meant to be public. The database rules (row level security in `schema.sql`) are what protect the data, so do not remove them.
- Passwords reset by email use Supabase's built-in email (low sending limit). For heavy use, add your own SMTP in Supabase.

## Files

- `index.html` – the whole app
- `config.js` – your Supabase URL and key
- `schema.sql` – database tables and security rules
- `manifest.webmanifest`, `icon.svg` – home-screen install
