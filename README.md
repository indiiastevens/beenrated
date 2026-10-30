# beenrated — launch guide

beenrated is a plain website (no build step) that stores classes and reviews in a free Supabase database. Duke students sign in with a link sent to their duke.edu email, and their reviews show only their year.

Files in this folder:

| File | What it is |
|---|---|
| `index.html` | The whole website |
| `config.js` | Where you paste your Supabase address and key |
| `supabase-setup.sql` | Creates the database tables and privacy rules |
| `README.md` | This guide |

Allow about an hour. Everything below is free.

---

## 1. Create the database (Supabase)

1. Go to supabase.com and sign up **with your duke.edu email**. This matters for testing: until step 5, Supabase only sends sign-in emails to people on your Supabase team, which will be you.
2. Click **New project**. Name it `beenrated`, choose a strong database password (save it somewhere), and pick the **East US** region. Wait a minute or two while it sets up.
3. In the left sidebar, open **SQL Editor**, click **New query**, paste the entire contents of `supabase-setup.sql`, and click **Run**. You should see "Success. No rows returned."
4. Open **Project Settings → API Keys** (on some accounts it's **Project Settings → API**). Copy two things:
   - the **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - the **publishable** key (older projects call it the **anon public** key). Do not use the secret / service_role key.
5. Open `config.js` in any text editor, replace the two `PASTE_…` placeholders with those values, and save.

> Supabase may show a warning that `public_reviews` is a "security definer view". That's intentional: it's what lets everyone read reviews without ever seeing who wrote them.

## 2. Put the code on GitHub

1. Sign up at github.com.
2. Click **+ → New repository**, name it `beenrated`, leave it **Public**, and click **Create repository**.
3. On the next page, click **uploading an existing file**, drag in `index.html`, `config.js`, `supabase-setup.sql` and `README.md`, then click **Commit changes**.

## 3. Publish the site (Vercel)

1. Go to vercel.com and choose **Continue with GitHub**.
2. Click **Add New → Project**, find `beenrated`, and click **Import**.
3. Leave the framework preset as **Other** and click **Deploy**.
4. When it finishes you get an address like `beenrated.vercel.app` (or `beenrated-abc123.vercel.app`). Copy it.

Any time you change a file on GitHub, Vercel republishes the site automatically within about a minute.

## 4. Tell Supabase where the site lives

In Supabase, open **Authentication → URL Configuration**:

- **Site URL**: paste your Vercel address, e.g. `https://beenrated.vercel.app`
- **Redirect URLs**: click **Add URL** and add the same address followed by `/**`, e.g. `https://beenrated.vercel.app/**`

Without this, the sign-in link in the email sends people to the wrong place.

### Test it

Open your site, click **Sign in**, enter your duke.edu email, open the link from your inbox on the same device, add a class, and rate it. Check that your review shows as "Anonymous [your year]".

## 5. Before you share it widely: set up a proper email sender

Supabase's built-in email only sends to members of your Supabase team, and only about 2 emails an hour. That's fine for testing on your own, but other students won't get their sign-in links until you connect an email service ("custom SMTP").

The cleanest way:

1. Buy a domain, for example `beenrated.com` or `beenrated.app` (about $10–15 a year from Namecheap, Cloudflare or Vercel itself). You can point it at your Vercel site too, in Vercel → Project → **Settings → Domains**.
2. Sign up at resend.com (free for up to 3,000 emails a month), add your domain, and add the DNS records it shows you.
3. In Supabase, open **Authentication → Emails → SMTP Settings**, turn on custom SMTP, and enter the details Resend gives you. Use a sender like `hello@beenrated.com`, sender name `beenrated`.
4. Optional: in **Authentication → Emails → Templates → Magic Link**, change the subject to "Your beenrated sign-in link".
5. In **Authentication → Rate Limits**, raise the email limit (for example to 100 an hour) so a busy day doesn't lock people out.

Duke's email filters are stricter with brand-new senders, so send yourself and a couple of friends a test first and check spam folders.

## Looking after the site

- **Remove a review or class:** Supabase → **Table Editor** → `reviews` or `courses` → select the row → **Delete**. Deleting a class also deletes its reviews.
- **Fix a class title:** edit the `title` cell in Table Editor. (Students can fix codes on the site, but not titles.)
- **When there are lots of reviews:** Supabase returns at most 1,000 rows per request by default. Once you pass about 1,000 reviews, raise **Project Settings → Data API → Max rows** to 20000.

## How privacy works

- Visitors can read classes and reviews without signing in.
- Only signed-in accounts with a duke.edu email can add classes, change codes, or post reviews. The database enforces this, not just the website.
- Each person gets one review per class and can only edit or delete their own.
- The database stores which account wrote each review so people can edit their own, but that link is never sent to anyone's browser. Only you, as the Supabase owner, could see it in the dashboard.
