## 10. Smart Loading & Skeleton Behavior

Do **not** show skeleton loaders for content that does not depend on a backend/API response.

Follow this rule strictly:

### Static / Local Content
If content is already available locally or is hardcoded/static, render it **immediately** without any skeleton loader.

Examples:

- Static labels and text
- Button text
- Navigation elements
- Tabs
- Icons
- Static section headings
- Local UI elements
- Default/placeholder content that does not require an API
- Any content already available in local state/cache
- Previously loaded content that does not need to wait for a new request

### Backend-Dependent Content
Use skeleton/loading states **only** for content that genuinely requires waiting for a backend/API/network response.

Examples:

- Profile data being fetched from API
- Posts being fetched
- Pieces being fetched
- Collects being fetched
- Artist information being fetched
- Event data being fetched
- Payment/purchase status being processed
- Other dynamic server-side data

### Important Loading Principle

Do not block the entire screen just because one API request is still loading.

For example, on the Profile screen:

1. Render static UI immediately.
2. Show cached profile image/banner immediately if available.
3. Fetch profile image/banner if needed.
4. Show profile image/banner as soon as they are available.
5. Load posts/pieces/collects independently.
6. Show skeletons **only in the specific sections that are actually waiting for backend data**.

If a section's data is already available, render it immediately.

If one API is slow, other independent content should still appear without waiting for it.

### Previously Loaded Data

If the user has already visited a screen and the data exists in cache:

- Display the cached content immediately.
- Do not replace the existing content with a full-screen skeleton.
- Fetch fresh data in the background.
- Update the UI when fresh data arrives.

Use skeletons primarily for the **initial empty state when there is genuinely no data available yet**.

Avoid unnecessary loading animations because they make the application feel slower even when the required content is already available.