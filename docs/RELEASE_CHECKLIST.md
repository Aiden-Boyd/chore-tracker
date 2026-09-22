# Chore Tracker 1.0 Release Checklist

## Required before submission

- Confirm `support@newlifemedia.co` is monitored, or replace it in the privacy and support pages.
- Publish `docs/PRIVACY.md` and `docs/SUPPORT.md` at stable HTTPS URLs and add them in App Store Connect.
- Set the Apple Developer Team and confirm the bundle ID `com.newlifemedia.choretracker`.
- Generate the Xcode project with XcodeGen and archive a Release build on a Mac with the current Xcode release.
- Test sign-in and account deletion against `https://auth.newlifemedia.co`.
- Test first launch, returning launch, offline launch, sign-out, account switching, and reinstall behavior on a physical iPhone and iPad.
- Verify VoiceOver, Dynamic Type, dark mode, reduced motion, and landscape layouts.
- Capture App Store screenshots from the final signed build.

## App Store Connect

- App name: Chore Tracker
- Version: 1.0.0
- Category: Productivity
- Age rating: complete the questionnaire based on the final feature set.
- Privacy: declare email address collection for app functionality; no tracking.
- Review notes: sign-in uses an emailed one-time code. Provide Apple review with a reliable test account/inbox workflow.

## Backend

- Keep `BETTER_AUTH_SECRET`, `RESEND_API_KEY`, and database credentials only in Coolify secrets.
- Confirm HTTPS, database backups, health checks, restart policy, and log retention.
- Run the Better Auth migration after every schema-affecting configuration change.
- Verify rate limiting and the Cloudflare client IP header in production.

## Release gate

Do not submit until there are no crashes or data loss in the critical-path tests above. Cross-device household sharing is intentionally out of scope for 1.0 and must not be advertised in the store listing.
