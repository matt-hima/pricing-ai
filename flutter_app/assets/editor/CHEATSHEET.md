# Site design cheat sheet

The rules the site builder (chat, "start with chat" and the quality check) follows when it writes or changes a page.
They are short paraphrases of two public sources, turned into things the app can check or enforce:

- **Digital Agency Japan — ウェブサイトガイドライン（案）** (DS-680.1 draft, 2025): <https://www.digital.go.jp/>
- **SmartHR Design System — 伝わる文章 / アクセシビリティガイドライン / 色 / タイポグラフィ**: <https://smarthr.design/>
- **note.com / TSUYOSHI KANEKO — free UX and design-thinking learning resources** (2018): <https://note.com/osi_ire/n/ned2515003924>
  (a reading list, not a rule set: it supplies the *process* section below)
- **予約システム比較 — 業種別の導入事例と必要な機能** (restaurants, salons, schools, rental spaces, clinics): <https://reservation-system-comparison.info/column/reservation-system-case-studies/>
  (supplies the *business types* section below and the test scenarios)

Where each rule is enforced: **audit** = `check_quality` in `actions.js`, **template** = `blocks.js`, **export** = `main.js`,
**prompt** = given to the model (`site_style.dart`), **polish** = fixed in code after the model answers.

## Process (note.com reading list: human-centred design, Lean UX)
- Start from **who the customers are and what they need**, before choosing words or colours (also guideline 9.1). The start-with-chat questions ask for exactly this.
- Summarise the business on one page (a Lean Canvas style: customers, problem, offer, price) and write the site from it.
- Test with two or three real customers: ask them to book from their phone and note where they hesitate. Fix that first.
- You do not need to memorise every framework. Know what exists and look it up when a real problem needs it.

## Business types and what their booking needs (予約システム比較 case studies)
| Business | What gets booked | What the page and form should offer |
|---|---|---|
| Restaurant / café (飲食店) | a time slot and a table | party size, seat type, 24-hour online booking, a note about prepayment or cancellation (no-shows), no double booking |
| Salon / beauty (美容室・サロン) | a menu item, often with a chosen stylist | stylist choice, booking outside opening hours, reminders, a way to return later (coupon, next visit) |
| School / lessons (教室・習い事) | a lesson slot, a trial lesson, make-up lessons | trial lesson request, class level or course, absence / make-up note, monthly fee shown clearly |
| Rental space / facility (施設・レンタルスペース) | a block of hours | start time and length, number of people, purpose, how the entry code is sent, 24-hour use |
| Clinic (医院・診療所) | a visit slot | first visit or return visit, reason for the visit, reminders, how to change or cancel, how many people are seen per slot |
Common questions to answer on the page: how to book, how to change or cancel, whether phone booking still works, where to find the shop (a booking system does not bring customers by itself: link the site from Google Business Profile, LINE and social media).

## Structure and markup
| Rule | Where |
|---|---|
| Use real headings: exactly one `h1`, levels never skip (guideline 7.2; SmartHR 3-2) | template, audit |
| Mark up landmarks: `header`, `nav` with a label, `main`, `footer`; offer a "skip to main content" link (7.2; SmartHR 5-1/5-2) | template, audit |
| Set the page language on `<html lang>` and give the page a descriptive title (SmartHR 6-1/6-2) | export |
| Responsive layout; keep every piece of information reachable on a phone (8.1) | template |
| Open Graph + description meta so shared links look right (7.4) | export |
| Do not depend on JavaScript for the basics; show a `noscript` message with another way to book (7.1, 7.3.1) | export |

## Accessibility (checkable)
| Rule | Where |
|---|---|
| Text contrast at least **4.5:1**, large text (24px+) at least 3:1 (SmartHR 4-2) | audit, auto-fix, `set_color`, `set_background` |
| Never rely on colour alone to carry meaning (SmartHR 4-3) | template |
| Buttons and links are big enough to tap (44px high) (SmartHR low-vision insight) | audit, auto-fix |
| Visible keyboard focus; everything works from the keyboard (SmartHR 5-1) | template |
| Images need `alt` (empty for decoration); links and buttons need a readable name (SmartHR 1-1, 6-4) | audit |
| Every form field has a visible label and an accessible name; required fields are marked; status messages are announced (SmartHR 7-1/7-2/7-3) | template, audit |
| No text smaller than 12px | audit |

## Writing — all languages
- Short, plain sentences, one idea each (about 50 characters in Japanese or Chinese, about 15 words elsewhere).
- Calm, polite, friendly tone. No pressure or hype: no stacked exclamation marks, no "the best in the world".
- One word per concept; keep the same term everywhere on the page.
- Say things directly and positively; avoid double negatives, jargon and unexplained abbreviations.
- Buttons say what happens ("Book a visit"), not "Submit" or "Click here"; link text names its destination.
- Prices carry the currency and thousands separators (12,000); times use the 24-hour clock (10:00 – 19:00).
- Name services concretely and avoid names that could be confused with an existing organisation or trademark (guideline 4.1).

## Writing — Japanese (SmartHR 伝わる文章)
- です・ます調, full-width punctuation（、。！？）, a single ellipsis character （…）.
- No half-width spaces next to numbers or Latin letters: 3件, JavaScriptを.
- Everyday kanji (常用漢字); katakana only for words normally written that way; spell out abbreviations once.
- Keep case particles (を・に・が); keep sentences near 50 characters.
- Numbers of four or more digits use commas (12,000円).

## Colour and type (SmartHR 色 / タイポグラフィ)
- One main colour plus a dark and a light tone of it; use the main colour for buttons and accents, a near-black for text.
- Do not put a light brand colour behind white text or use it as text on white: darken it until contrast reaches 4.5:1.
- System fonts are fine; use two weights (regular and bold).

## Publishing
- Serve over HTTPS (Firebase Hosting does) (5.1.1).
- If you add analytics or cookies, say so in a privacy notice (5.3).
