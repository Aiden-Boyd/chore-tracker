# Chore Tracker

A native SwiftUI family chores app inspired by the simplicity of Choresy, with a stronger family workflow.

## V1 features

- Parent and child views
- Assigned chores
- Claimable family chores
- Daily / weekly / monthly recurrence metadata
- Mark chores complete
- Optional parent approval
- Parent approval queue
- Create new assigned or claimable chores
- Local prototype state with sample household data

## Run

This repo uses XcodeGen so the project stays easy to maintain.

1. Install XcodeGen if needed:
   `brew install xcodegen`
2. From the repo root:
   `xcodegen generate`
3. Open `ChoreTracker.xcodeproj`
4. Run on iOS 17+.

The current version is an offline prototype. The next backend step is household accounts + sync (CloudKit or a small API).
