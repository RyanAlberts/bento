# LinkedIn launch post

> Copy the post body verbatim. Post from your account. The optimization playbook below is the multiplier.

## The post (≈165 words, hook in first 110 chars, mobile-truncation-safe)

> Built a Stream Deck for your Mac screen. No hardware, no subscription, fully open source.
>
> **Bento** — a tiny floating macro grid for macOS power users.
>
> Install in one line: `npm install -g bento`
>
> Press `⌃⌘B` from anywhere → 8 tiles appear. Click one → magic happens.
>
> What ships in the default deck:
> · Toggle dark mode
> · Caffeinate 60min — with a live progress ring
> · Mute the mic — glows red when muted
> · Snap a screenshot
> · Eject all disks
> · Sleep displays
> · Play / pause media
> · 25-minute focus timer
>
> Plus you can drop in any shell command, URL, or app. So it doubles as a Hammerspoon companion, a Shortcuts launcher, a one-key OBS controller, or a tiny dashboard for whatever else you script.
>
> Built in Swift in a weekend. Zero telemetry, zero accounts, zero network calls. Hot-reloadable JSON config. Tiny `bento` CLI for Hammerspoon-style chaining.
>
> What macro would you put on your second row?
>
> (GitHub link in the first comment ↓)

## First-comment text (post within 60 seconds of publishing, pin it)

> Repo: https://github.com/RyanAlberts/bento — `npm install -g bento` to try it.
>
> A star ⭐ helps a lot; that's how indie projects find new people on GitHub.
>
> If you build a tile worth sharing, drop it in `recipes/` via PR — fast-merge promise on those.

## Visual asset

Attach the hero GIF (Coffee tile press → progress ring traces → Mic toggles red). LinkedIn autoplays GIFs muted. If LinkedIn rejects the size, fall back to a static panel screenshot with the coachmark visible.

To record the GIF (need to do this manually — autonomous agent can't drive UI):
1. Launch Bento
2. Use `Cmd+Shift+5` to start screen recording → Selection
3. Frame the panel + small margin
4. Record: panel visible → click Coffee → ring starts → click Mic → red → wait 1s → stop
5. Convert to GIF: `ffmpeg -i recording.mov -vf "fps=18,scale=720:-1:flags=lanczos" -loop 0 docs/hero.gif`
6. Aim for <5MB

## Optimization playbook (engagement + GitHub stars)

### Pre-launch (do BEFORE you post)

1. **Recruit 5–10 warm-up engagers.** Friends/colleagues who'll like + leave a real comment within the first 30 minutes. LinkedIn's algorithm uses early engagement velocity as the primary ranking signal — this is the single biggest lever.
2. **Pin the repo to your GitHub profile.** Settings → Customize your pins → select bento.
3. **README hero above the fold.** GIF in the first 200px so the GitHub repo page sells itself when the LinkedIn click lands.
4. **Pre-write Show HN draft** for Hacker News (`title: "Show HN: Bento – a minimal, open-source soft Stream Deck for macOS"`, body ≤2 short paragraphs). Pre-write an r/macapps post too. Post both 30–60 min after the LinkedIn post so GitHub stars compound across platforms.

### Posting mechanics

5. **Day + time:** Tuesday, Wednesday, or Thursday. 8:00–10:00am in your audience's primary timezone (US Eastern for tech). Avoid Mondays (low attention) and Fridays (everyone's checked out).
6. **LINK GOES IN THE FIRST COMMENT, NOT THE POST BODY.** LinkedIn measurably suppresses reach on posts with outbound links. Don't fight it — the trade-off is real and documented.
7. **Maximum 4 hashtags.** One broad (`#macOS`), one medium (`#OpenSource`), one specific (`#SwiftUI` or `#IndieHackers`). More = spam signal.
8. **Tag selectively, not greedily.** If you used Sindre Sorhus's Swift packages or any other concrete person who influenced this, tag them by name. Tagging celebrities you don't actually know reads as spam and tanks reach. Real attribution does the opposite.
9. **End with a question.** "What macro would you put on your second row?" — drives comments, comments drive reach.
10. **Reply to every single comment in the first 2 hours.** Each reply is another engagement signal. Aim for substantive 2-sentence replies, not "Thanks!".

### After the post is live

11. **Cross-post within 30–60 min** in this order: Hacker News (Show HN), Twitter/X, r/macapps, r/SideProject. Each platform has its own audience; cross-posting compounds GitHub traffic.
12. **DM 5 specific people** who would actually use this — not "would you check out my project," but "I built this thing because of [specific pain you know they have]; thought of you." Personal asks convert way better than broadcast.
13. **Pin your own first comment** (the GitHub link) at the top of comments via LinkedIn's "Pin comment" option. New visitors see it immediately.
14. **Track at 24h and 7d:** GitHub star count, repo unique visitors (Insights → Traffic), LinkedIn impressions, and click-through to the repo. If stars are <50 at 7d, the bottleneck is usually the README hero GIF or the LinkedIn hook — iterate, don't re-post the same copy.

### Repo-side SEO (do BEFORE the post)

15. **Repo description** must include "macOS", "Stream Deck", "open source", and "npm" — the search terms people type. Current draft: *"A minimal, fun, open-source soft Stream Deck for macOS. `npm install -g bento`. No hardware, no subscription. Built in SwiftUI."* — covers all four.
16. **Topics:** `macos`, `stream-deck`, `swiftui`, `productivity`, `menubar`, `open-source`, `mac-app`, `npm`. Each topic is a separate GitHub discovery surface.
17. **Social preview image** at GitHub repo → Settings → Social preview → upload a 1280×640 image of the panel with the project name. Required so the LinkedIn / Twitter preview card looks great instead of generic.
18. **A "Why" paragraph in the README** above the install section. People who land cold need to know in 3 sentences whether this is for them. The post hook works on LinkedIn; the README "Why" is the conversion step on GitHub.
19. **The npm package page is a second SEO surface.** `bento` on npmjs.com is itself indexed by Google. Make `npm/README.md` a tight ~300-word version of the main README. Many users will land here first via `npm search bento` or Google.

### Anti-patterns to avoid

- "I'm humbled to announce…" / "I'm thrilled to share…" — LinkedIn-cliché tells that suppress reach
- More than 1 emoji in the post body
- Linking from a tweet to your LinkedIn post ("see my LinkedIn for more") — Twitter users will not click through
- A follow-up "thanks for the support!" post within 48h — dilutes the original. Wait at least a week before the next Bento update post.
