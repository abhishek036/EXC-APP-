# Vibe-coded → Human-built Checklist

> Make your app look and feel like a senior dev built it — inside and out.

**Legend**  
`[EXT]` = external — what users see  
`[INT]` = internal — what devs see  
`[BOTH]` = affects both surface and structure

**Total items:** 90 across 15 sections

---

## 01 · Spacing & layout consistency `[EXT]`

- [ ] Use a single spacing scale — only multiples of 4px or 8px (4, 8, 12, 16, 24, 32, 48, 64). Grep for arbitrary values like `margin: 13px` or `padding: 22px` and replace every one.
- [ ] Align all elements to a column or row grid. Nothing positioned at an arbitrary x/y with `position: absolute` for layout purposes.
- [ ] Every card, modal, and panel uses the same internal padding token — never re-typed per component.
- [ ] Section-to-section spacing is 2–3× larger than intra-section element spacing. Add breathing room — it signals craft.
- [ ] No layout shifts on load, state change, or dropdown open. Fix with skeleton loaders at fixed dimensions and `min-height` on dynamic containers.
- [ ] Inputs, buttons, and form elements share a consistent height (e.g. 36px for normal, 44px for large). Mixed heights on one form look broken.
- [ ] Consistent left-edge alignment on every page. If content starts at 24px on one page and 32px on another, it reads as a bug.

---

## 02 · Typography `[EXT]`

- [ ] Use at most 2 font families — one for UI, one for display/brand. Vibe code often has 3–4 mixed in accidentally.
- [ ] Define a strict type scale: e.g. 12 / 13 / 14 / 16 / 18 / 22 / 28px. Audit every `font-size` in the codebase and normalize to the scale.
- [ ] Only 2 font weights in the UI: regular (400) and medium/semibold (500–600). Bold (700) reserved for marketing headlines only.
- [ ] Line height is set explicitly: `1.4` for headings, `1.6–1.7` for body text, `1` for single-line UI labels. No element inherits a mismatched line height.
- [ ] Letter spacing is set to `0` or slightly negative (−0.01em) for headings. Never positive letter spacing on body text.
- [ ] Text never overflows its container. Every text element has overflow protection: `overflow: hidden`, `text-overflow: ellipsis`, or `word-break: break-word` where appropriate.
- [ ] Sentence case everywhere in the UI. No random Title Case on labels, no ALL CAPS on body text. Only intentional all-caps with letter-spacing for labels or tags.
- [ ] Paragraph width is capped at 60–72 characters (roughly `max-width: 65ch`) for any long-form text. Full-width paragraphs are hard to read.

---

## 03 · Color & visual consistency `[EXT]`

- [ ] Define a color system: 1 primary, 1 neutral/gray scale, and semantic colors (success, warning, danger, info). No free-floating hex values anywhere.
- [ ] Background colors form a clear hierarchy: page bg → surface bg → raised card bg. Never more than 3 levels of background stacking.
- [ ] Text on colored backgrounds always uses the darkest shade of that same color family — never generic black or gray on a tinted surface.
- [ ] Interactive states are consistent across all components: default → hover → active → disabled → focus. Every button, link, and input has all five.
- [ ] Focus rings are visible on all interactive elements for keyboard navigation. `outline: none` with no replacement is a UX bug, not a style choice.
- [ ] Dark mode (if supported) uses variables — no hardcoded `#333` or `white` anywhere in the stylesheet. Every color goes through a CSS variable or token.
- [ ] Icon set is from a single library. No mixing Heroicons, Material Icons, and Font Awesome on the same page. Sizes are consistent: 16px inline, 20px standalone, 24px decorative.
- [ ] Borders use consistent opacity: `0.1–0.15` for subtle separators, `0.3` for visible borders, `1` for active/focus. Audit and normalize.

---

## 04 · Component polish `[EXT]`

- [ ] Buttons have distinct visual hierarchy: primary (filled), secondary (outlined), ghost (text-only). Never two filled buttons side by side with the same weight.
- [ ] Destructive actions (delete, remove, cancel subscription) use red/danger styling and require a confirmation step — not just a click.
- [ ] All buttons have a loading state: spinner replaces label, button is disabled during async operation. No double-submit risk.
- [ ] Inputs show clear validation state: default border → error (red border + message below) → success (optional green checkmark). Error message is below the field, not in a toast.
- [ ] Dropdowns and selects close when clicking outside and on `Escape`. This is expected behavior — vibe code often misses it.
- [ ] Modals trap focus inside while open. `Tab` cycles through modal elements only. `Escape` closes the modal.
- [ ] Tooltips appear on hover after a 300–500ms delay — not instantly (jarring) and not after 1s+ (useless).
- [ ] Empty states have an illustration or icon, a clear headline ("No results yet"), a sub-label, and a primary action button. Never just a blank space or raw "null".
- [ ] Every list and table has a loading skeleton that matches the real content's layout — same number of rows, same column widths.
- [ ] Badges and pills use consistent sizing (font-size: 11–12px, padding: 2–3px 8px, border-radius: 10–20px). Not a random mix of sizes per page.

---

## 05 · Motion & micro-interactions `[EXT]`

- [ ] Transitions are 150–250ms for UI state changes (hover, open, close). Nothing is instant and nothing takes longer than 400ms for a simple interaction.
- [ ] Use `ease-out` for things entering the screen, `ease-in` for things leaving. `linear` only for continuous motion (spinners, progress bars).
- [ ] Page transitions exist and are consistent — even a simple 100ms fade-in on route change makes the app feel intentional.
- [ ] Skeleton loaders use a subtle shimmer animation, not a static gray block.
- [ ] Success feedback is visible: a checkmark, a green flash, or a toast — something confirms the action worked. No silent success.
- [ ] Form submission shows progress: button disables, spinner appears, then transitions to success or error state. Users never wonder if they clicked.
- [ ] Scroll behavior is `smooth` for anchor links and in-page jumps. Instant scroll for page navigation.
- [ ] All animations respect `prefers-reduced-motion` — wrap non-essential animations in the media query.

---

## 06 · Copy & content `[EXT]`

- [ ] Every error message explains what went wrong AND what to do next. "Something went wrong" is not an error message. "Payment failed — check your card details and try again" is.
- [ ] No placeholder copy left in production: "Lorem ipsum", "Test user", "Coming soon", "TODO", "example.com".
- [ ] Button labels are verbs: "Save changes", "Delete account", "Send invite" — not "Submit", "OK", "Yes".
- [ ] Confirmation dialogs say what will happen: "Delete this student? This cannot be undone." — not "Are you sure?".
- [ ] Empty state copy is specific to the context: "No students enrolled yet — add your first student to get started." Not "No data found."
- [ ] Form labels are above the input, not inside as placeholder text. Placeholder text disappears on focus — users lose context.
- [ ] Page titles and tab titles are set correctly per page. Every page should have a unique, descriptive `<title>` — not just the app name.
- [ ] Dates and numbers are formatted for the user's locale: `Intl.DateTimeFormat`, `Intl.NumberFormat`. No raw ISO strings (`2024-04-20T14:33:00Z`) shown to users.

---

## 07 · Responsiveness & accessibility `[EXT]`

- [ ] The app works at 320px, 375px, 768px, 1024px, and 1440px. Test each breakpoint — do not just test desktop.
- [ ] Touch targets are at least 44×44px on mobile. Tiny icon buttons that are 20×20px are inaccessible.
- [ ] No horizontal scroll on mobile from overflowing elements (tables, code blocks, long strings). Add `overflow-x: auto` on wrappers.
- [ ] All images have meaningful `alt` text. Decorative images have `alt=""`. No `alt="image"` or `alt="photo"`.
- [ ] Color is never the only indicator of meaning. Error states show an icon + text, not just a red border.
- [ ] All interactive elements are reachable and operable by keyboard alone. Tab through every form and modal and verify.
- [ ] Contrast ratios meet WCAG AA: 4.5:1 for body text, 3:1 for large text and UI components. Use a contrast checker on your gray-on-white text.
- [ ] Semantic HTML is used correctly: `<button>` for actions, `<a>` for navigation, `<nav>`, `<main>`, `<section>`, `<h1>`–`<h6>` in order. No `<div onclick>` for interactive elements.

---

## 08 · Code organization `[INT]`

- [ ] Folder structure is feature-based or domain-based — not type-based. `features/payments/` not `components/ hooks/ utils/ pages/` all at the top level.
- [ ] No file is longer than 300 lines. If it is, split it. Long files are a sign of mixed concerns.
- [ ] No function is longer than 40 lines. Extract helpers with descriptive names instead of stacking logic vertically.
- [ ] No deeply nested callbacks or promise chains. Use `async/await` throughout. Max nesting depth: 3 levels.
- [ ] Dead code is removed: commented-out blocks, unused imports, unused variables, unreachable branches. Run `eslint --no-unused-vars` and fix all warnings.
- [ ] No `console.log` statements in production code. Use a proper logger with log levels. Grep and remove all debug logs before shipping.
- [ ] All magic numbers and strings are named constants. `const MAX_FILE_SIZE_MB = 5` not `if (size > 5242880)` inline.
- [ ] Imports are grouped and ordered: external libs → internal modules → relative imports. Use an ESLint import-order rule to enforce automatically.

---

## 09 · Naming conventions `[INT]`

- [ ] Variables, functions, and files use consistent casing: `camelCase` for variables/functions, `PascalCase` for components/classes, `SCREAMING_SNAKE_CASE` for constants, `kebab-case` for file names.
- [ ] No single-letter variable names outside of loop indices and math. `u` is not a user. `d` is not data. `e` is not an event (unless it truly is a trivial loop variable).
- [ ] Boolean variables are named as questions: `isLoading`, `hasError`, `canEdit`, `isVisible`. Not `loading`, `error`, `edit`, `visible`.
- [ ] Functions are named for what they do, not what they are. `fetchStudentResults()` not `studentResults()`. `handlePaymentSubmit()` not `paymentSubmit()`.
- [ ] Event handlers are prefixed with `handle` or `on`: `handleSubmit`, `onClose`, `handleFilterChange`. Not `click`, `submit`, `go`.
- [ ] No abbreviations unless universally understood (`id`, `url`, `api`). `usr` is not a user. `pmt` is not a payment. `inst` is not an institute.
- [ ] Component and file names match exactly: if the component is called `PaymentCard`, the file is `PaymentCard.tsx` — not `paycard.tsx` or `Card.tsx`.
- [ ] API endpoint names are consistent: all plural nouns, RESTful. `GET /students`, `POST /payments`, `PATCH /students/:id`. No mixed `getStudents` vs `/student/list`.

---

## 10 · Error handling `[INT]`

- [ ] Every `async/await` call is wrapped in `try/catch`. No fire-and-forget promises. Unhandled rejections crash Node.js silently in some environments.
- [ ] API errors are typed. Define an `ApiError` class or interface with `status`, `message`, `code`. Do not pass raw `Error` objects to the UI layer.
- [ ] Network errors (timeout, offline) are handled separately from API errors (4xx, 5xx). Show different messages: "Check your connection" vs "Server error, try again".
- [ ] All error boundaries are in place in React/Flutter. A crash in one widget/component should not take down the entire page.
- [ ] Form validation errors are caught and displayed before the API call — not returned from the server as a 400 error that then has to be parsed and shown.
- [ ] Null/undefined is handled defensively everywhere. No `cannot read property of undefined` in production. Use optional chaining (`?.`) and nullish coalescing (`??`).
- [ ] 404 routes are handled — a custom 404 page, not a blank screen or a framework error page.
- [ ] Retry logic exists for transient failures (network flaps). Implement exponential backoff for critical operations. Do not retry on 4xx errors.

---

## 11 · State management `[INT]`

- [ ] Server state and client state are separate concerns. Use React Query / SWR / TanStack Query for server data — not `useState` + `useEffect` + manual fetching everywhere.
- [ ] No prop drilling beyond 2 levels. Extract to context, a store, or a composition pattern. Deeply drilled props are a maintenance trap.
- [ ] Loading, error, and empty states are modelled explicitly in state — not derived from `data === null` checks scattered through render logic.
- [ ] Optimistic updates are used for fast-feeling interactions (toggle, like, reorder). Roll back on error with a visible notification.
- [ ] No stale data shown after mutations. Invalidate or update the relevant cache keys after every create/update/delete operation.
- [ ] Global state contains only truly global data: auth user, theme, locale. Everything else is local or server-cached. Vibe code often puts everything in a global store.
- [ ] State is never mutated directly. Always create new objects/arrays. `state.items.push(x)` is a bug in React. Use `[...state.items, x]`.

---

## 12 · API & data layer `[INT]`

- [ ] All API calls go through a single client module — not `fetch()` called inline across 40 components. Centralizing enables consistent headers, auth, error handling, and base URL config.
- [ ] API response types are fully typed (TypeScript interfaces or Dart classes). No `any` or `dynamic` for API response shapes.
- [ ] API calls are not made inside render functions or build methods. Use hooks, services, or controllers.
- [ ] Pagination is implemented on every list endpoint. No endpoint returns all records unbounded. Frontend renders in pages or uses infinite scroll.
- [ ] Date/time values are stored and transmitted as UTC ISO 8601 strings. Converted to local time only at the display layer.
- [ ] Sensitive fields (passwords, tokens, keys) are never logged, never included in error messages, and never returned in API responses where not needed.
- [ ] All API responses follow a consistent shape: `{ data, error, meta }` or similar. Not sometimes `{ users: [] }` and sometimes `{ result: { list: [] } }`.
- [ ] Deprecated or unused API endpoints are removed — not just commented out. Dead routes are attack surface.

---

## 13 · Performance `[BOTH]`

- [ ] Images are compressed, served in modern format (WebP/AVIF), and lazy-loaded below the fold. No 2MB PNGs for UI icons.
- [ ] JavaScript bundle is code-split by route. The home page does not load the dashboard's code. Use dynamic imports for heavy components.
- [ ] Fonts are preloaded and use `font-display: swap`. No invisible text during load (FOIT).
- [ ] No waterfalls of sequential API calls on page load. Parallelize independent requests with `Promise.all`. Prefetch data for the likely next page.
- [ ] Expensive computations are memoized (`useMemo`, `useCallback`, `computed`). Verified with profiling — not just added everywhere as cargo-cult.
- [ ] List rendering is virtualized for lists over 100 items. `react-window`, `flutter_list_view`, or equivalent. Rendering 10,000 DOM nodes blocks the main thread.
- [ ] Lighthouse score is 90+ on Performance, Accessibility, and Best Practices. Run it and fix what it flags before launch.
- [ ] Database queries have `LIMIT` clauses. No query returns an unbounded number of rows from the application layer.

---

## 14 · Testing & reliability `[INT]`

- [ ] Every utility function has a unit test. Pure functions are the easiest things to test — there is no excuse not to.
- [ ] Every API endpoint has at least one integration test: happy path + auth failure + validation failure.
- [ ] Critical user flows have end-to-end tests: login, payment submission, enrollment. Use Playwright, Cypress, or Flutter integration tests.
- [ ] Tests run in CI on every pull request. A failing test blocks the merge. No broken tests committed with "will fix later".
- [ ] Test data is isolated — tests never share state or depend on execution order. Each test sets up and tears down its own data.
- [ ] Edge cases are tested: empty list, single item, max-length input, special characters in names, concurrent operations.
- [ ] No `// TODO: add tests` comments in production code. If the feature is shipped, the test ships with it.

---

## 15 · Developer experience & hygiene `[INT]`

- [ ] `.env.example` is committed to the repo with every required variable listed (values blank). New devs should be able to set up locally with zero guesswork.
- [ ] `README.md` covers: what the project is, how to set it up, how to run tests, how to deploy. No "it's obvious" assumptions.
- [ ] Linting and formatting run on pre-commit via `husky` + `lint-staged`. Code style is never debated — the formatter decides.
- [ ] TypeScript strict mode is enabled (`"strict": true`). No `@ts-ignore` without a comment explaining why. No `any` without justification.
- [ ] Git commit messages are descriptive: `fix: prevent duplicate payment submission on fast double-click` not `fix stuff` or `wip`.
- [ ] No large commented-out code blocks in git. If it's not used, delete it — git history preserves it. Commented code rots and confuses.
- [ ] Dependencies are audited: `npm audit` or `yarn audit` shows zero high/critical vulnerabilities. Remove unused packages (`depcheck`).
- [ ] Environment configs are clearly separated: `development`, `staging`, `production`. No `if (url.includes('localhost'))` checks in business logic.
- [ ] The app starts in under 3 seconds locally with a single command. If setup requires more than 5 steps, write a `Makefile` or `setup.sh`.
- [ ] Secrets are never in git history. Run `git log -S "password"` and `git log -S "secret"` — if anything appears, rotate those credentials immediately.

---

## Summary

| Section | Items | Type |
|---|---|---|
| 01 · Spacing & layout | 7 | External |
| 02 · Typography | 8 | External |
| 03 · Color & visual consistency | 8 | External |
| 04 · Component polish | 10 | External |
| 05 · Motion & micro-interactions | 8 | External |
| 06 · Copy & content | 8 | External |
| 07 · Responsiveness & accessibility | 8 | External |
| 08 · Code organization | 8 | Internal |
| 09 · Naming conventions | 8 | Internal |
| 10 · Error handling | 8 | Internal |
| 11 · State management | 7 | Internal |
| 12 · API & data layer | 8 | Internal |
| 13 · Performance | 8 | Both |
| 14 · Testing & reliability | 7 | Internal |
| 15 · Developer experience | 10 | Internal |
| **Total** | **90** | |

---

## The 10 highest-impact items (do these first)

- [ ] **Spacing scale** — replace all magic numbers with a 4/8px grid. Single highest visual impact per hour of work.
- [ ] **Type scale** — normalize font sizes to 6–7 stops. Removes the #1 tell of vibe-coded UI.
- [ ] **Component states** — every button/input has loading, error, disabled, and focus states.
- [ ] **Empty states** — replace blank screens with illustration + copy + action.
- [ ] **Error messages** — every error tells the user what happened and what to do.
- [ ] **Dead code removal** — delete all `console.log`, commented blocks, and unused imports.
- [ ] **Named constants** — no magic numbers or strings inline in logic.
- [ ] **API client module** — centralize all fetch calls into one place.
- [ ] **Linter + formatter** — install ESLint + Prettier with pre-commit hook today.
- [ ] **`.env.example`** — document every environment variable so the project is reproducible.

---

*A vibe-coded app is not a bad app — it's an unfinished one. This checklist is the finishing.*
