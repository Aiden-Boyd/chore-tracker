# Chore Tracker

A native SwiftUI family chores app focused on a simple household workflow.

## Current prototype

### Parent
- Home is the main control center
- Add chores directly from Home
- Assigned or claimable chores
- Emoji for every chore
- Dollar rewards instead of points
- See total money owed and what is owed to each child
- Mark a child's owed balance paid
- Approve completed chores
- Edit or delete active chores
- Recurring schedules and due dates

### Child
- See assigned chores
- See money currently owed
- Claim open family chores
- Complete chores with spring animations and haptic feedback
- View completed chore history

## Run

This repo uses XcodeGen.

1. Install XcodeGen if needed:
   `brew install xcodegen`
2. From the repo root:
   `xcodegen generate`
3. Open:
   `open ChoreTracker.xcodeproj`
4. Run on iOS 17+.

The current build stores data locally. Account setup and family sync are the next backend-level steps.
