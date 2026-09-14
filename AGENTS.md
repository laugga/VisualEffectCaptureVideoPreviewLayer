# AGENTS.md

## What this is

**`LAUCaptureVideoPreviewLayer`** is a preview layer for an `AVCaptureSession`
with a GPU blur filter — a near-drop-in replacement for AVFoundation's
`AVCaptureVideoPreviewLayer` that adds one animatable `blur` property in
`[0,1]`. It is a `CAEAGLLayer` subclass; the blur is a separable Gaussian
implemented in OpenGL ES 2.0 and GLSL.

It does not sit in the capture session the way Apple's layer does. It adds an
`AVCaptureVideoDataOutput` to the session you hand it, and renders each frame
from `captureOutput:didOutputSampleBuffer:fromConnection:`. If the session
already has an `AVCaptureVideoDataOutput`, it hijacks that one and forwards the
delegate callback on to you.

**Objective-C, and only Objective-C.** Nine files and roughly 3,000 lines under
`lib/`, plus GLSL embedded in a header. There is no Swift anywhere, no
`Package.swift`, no module map, and no Swift interop layer — see
[Objective-C, and what it costs](#objective-c-and-what-it-costs).

**Nothing depends on this component today.** It is a standalone Lightmate
component, not a dependency of any repository in the organisation:
`lightmate-app-ios` uses Apple's own `AVCaptureVideoPreviewLayer`, and no other
laugga repository references this one. The repository is public and MIT
licensed, and the podspec describes a CocoaPods pod, but **nothing has ever been
released from it** — there are no git tags at all, so the podspec's
`:tag => s.version` source cannot resolve. Treat the public API as unpublished:
no consumer is pinned to it and no change here breaks anyone downstream.

It is, in the author's own words in the README, an R&D project.

**Four large migrations are already proposed and open as pull requests** —
OpenGL ES to Metal (#1), CocoaPods to Swift Package Manager (#2), Objective-C to
Swift (#3), and the documentation to match (#4). None is merged. They are the
context for almost any change here: check whether what you are about to do is
already in flight before starting.

## Build and test

**`LAUCaptureVideoPreviewLayer.xcodeproj` at the repository root is the whole
build.** It has four targets — `Static Library` (the library itself),
`Tests` (unit tests), `UI Tests`, and `UI Tests Application` (the host app the
UI tests drive) — and four shared schemes with the same names.

The commands below are verified to work from a clean `git clone` of `main` with
Xcode 27, and need no extra flags. Run them from the repository root.

```bash
# Build the library
xcodebuild build -project LAUCaptureVideoPreviewLayer.xcodeproj \
  -scheme "Static Library" -destination 'generic/platform=iOS Simulator'

# Run the 4 unit tests
xcodebuild test -project LAUCaptureVideoPreviewLayer.xcodeproj \
  -scheme "Static Library" -destination 'platform=iOS Simulator,name=iPhone 17'

# Run the 1 UI test
xcodebuild test -project LAUCaptureVideoPreviewLayer.xcodeproj \
  -scheme "UI Tests Application" -destination 'platform=iOS Simulator,name=iPhone 17'
```

Substitute any installed simulator for `iPhone 17`; check with
`xcrun simctl list devices available`.

**The scheme names do not say which tests they run, and two of them run
nothing.** This is the single easiest thing to get wrong here:

| Scheme | `xcodebuild test` runs |
|---|---|
| `Static Library` | the **unit tests** (`Tests.xctest`) |
| `UI Tests Application` | the **UI tests** (`UI Tests.xctest`) |
| `Tests` | nothing — `error: Scheme Tests is not currently configured for the test action` |
| `UI Tests` | nothing — the same error |

`Tests` and `UI Tests` are schemes for *building* those targets; their
`<Testables>` lists are empty. The two schemes that do have a testable are the
library and the host app. Reaching for `-scheme Tests` to run the unit tests is
the obvious move and it fails outright — which is the good case. Do not
"fix" this by editing the schemes unless that is the task.

**Two of the four unit tests fail on `main`, and that is the baseline.** Both
compare GPU output against PNGs committed in 2016, and both fail on a current
simulator for reasons that have nothing to do with any change you are making:

- `testRenderedImageSimilarityWithTargetImage` — the rendered blur at radius
  36px and 48px no longer matches `test/Samples.xcassets/target-image-*` within
  the hard-coded tolerances.
- `testRenderedImageSimilarityWithAnotherRenderedImage` — asserts that two
  renders of the same frame are *bit-identical* (`XCTAssertEqual(similarity,
  0.0)`); the measured difference is `1.8e-07`.

`testSourceImageIsNotNil` and `testRenderPerformance` pass. Confirm this same
2-pass/2-fail split before you start, so you can tell your own breakage from
the standing failures, and say in your pull request that you left it unchanged.
Re-baselining the reference images is its own task, not a step in someone
else's.

**The one UI test asserts nothing.** `testExample` launches the host app,
`sleep(5)`, and ends. It passes, and all it really proves is that the app
launches without crashing. Do not read a green UI test run as coverage.

**There is no lint step and no CI.** No SwiftLint, no clang-format, no
`.editorconfig`, no GitHub Actions workflows, no Xcode Cloud. `.travis.yml`
exists but is dead: it names `LAPickerView.xcodeproj` and a `Test` scheme, from
a different project entirely, and Travis does not run on this repository. The
commands above are the entire gate — run them yourself.

**There is no `Makefile`.** Every typed repository in the practice is supposed
to have one exposing `build`, `test` and `lint`/`clean`
([`laugga/ops`](https://github.com/laugga/ops)`/CONVENTIONS.md`); this
repository predates that and has not adopted it. Use the `xcodebuild` commands
above directly. The absence is also the "UI surfaces only" signal: there is no
root `deploy` target, so there is no try-it build to make here.

## Build and run the example app

`examples/LAUCaptureVideoPreviewLayerExample/` is a single-view app — a capture
session, a back camera, tap to blur in, pull down to blur out — and it is the
only place the layer is exercised against a real camera.

**It is a CocoaPods project, and it was not verified for this document.** The
Podfile consumes the repository as a local pod (`:path => '../../'`), so
`Pods/` must be generated before the workspace will open or build:

```bash
cd examples/LAUCaptureVideoPreviewLayerExample
pod install
xcodebuild build -workspace LAUCaptureVideoPreviewLayerExample.xcworkspace \
  -scheme LAUCaptureVideoPreviewLayerExample \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Without `pod install` the build fails immediately with `Unable to open base
configuration reference file … Pods-LAUCaptureVideoPreviewLayerExample.debug.xcconfig`
— `Pods/` is gitignored and absent from a fresh checkout.

`pod install` could not be run while writing this: the CocoaPods on this
machine is broken (`Could not find 'ffi' (>= 1.15.0)`, a Homebrew Ruby
mismatch, not a problem with this repository). So the three commands above are
the documented path, not a verified one, and the example's own
`platform :ios, '7.0'` in the Podfile is below what current Xcode accepts and
will likely need raising too. **Expect to fix something here**, and if the
example is central to your task, get CocoaPods working first rather than
assuming the example is broken.

The library itself needs none of this — it builds and tests through the root
xcodeproj, with no CocoaPods involvement at all.

## Objective-C, and what it costs

This is the oldest component in the practice and the only one still written in
Objective-C. That is a constraint on how you change it, not just a fact about
it:

- **Write Objective-C.** Do not add Swift files, a `Package.swift`, or a
  bridging header to make a change more comfortable. Converting this library to
  Swift is pull request #3, already open; a half-conversion landed alongside an
  unrelated fix is worse than either.
- **The public API is what a header exposes, not what a module exports.** There
  is no `public`/`internal` distinction — the podspec declares `lib/*.h` as
  public headers wholesale, so every header, including the ones that are plainly
  internal, is part of the surface. `LAUCaptureVideoPreviewLayerInternal.h` is
  named "Internal" and is still public. Adding a header to `lib/` publishes it.
- **Memory is ARC, but the GL and CoreMedia resources are not.** Texture,
  framebuffer, program and `CMSampleBufferRef` lifetimes are managed by hand in
  `LAUCaptureVideoPreviewLayer.m` and `LAUCaptureVideoPreviewLayerInternal.m`.
  ARC will not help you; match the existing paired alloc/free.
- **Nothing is nullability-annotated and nothing is generic.** Don't add
  `NS_ASSUME_NONNULL_BEGIN` to one file in passing — it changes the generated
  Swift interface for that header only and makes the surface inconsistent.
- **OpenGL ES is deprecated and the build says so, loudly.** Every `gl*` call,
  `EAGLContext` and `CAEAGLLayer` raises a deprecation warning; a library build
  emits dozens. They are expected. Do not silence them with
  `GLES_SILENCE_DEPRECATION` — the warnings are the standing argument for
  pull request #1, the Metal migration.
- **Every `.h`/`.m` in this repository carries a `#warning`** marking it for
  rewrite in Swift — `#warning "Objective-C — needs to be refactored and
  re-written in Swift"`, added by LM-600, the same mark LM-590 put on the app's
  own Objective-C. Thirty-one files under `lib/`, `test/` and `examples/` have
  it. **Expect those marks, leave them in place, and add one to any new file.**
  It sits immediately after the license block, or immediately after the
  `#define` of the include guard in the four headers that have one, so it is
  emitted once per translation unit rather than once per `#include`.

  Two things deliberately do *not* carry it. The `-Prefix.pch` files are
  outside the `.h`/`.m`/`.c` scope and are included in every translation unit,
  so a mark there would repeat the per-file mark rather than add to it. And the
  GLSL cannot take one at all — see the gotcha below.

The deployment floor is **iOS 15.0**, raised from 7.0/8.0/10.0 in LM-598 only
because Xcode 27 refuses to build anything below 15.0. It is not a considered
minimum, and the podspec still declares `7.0` — see the gotchas.

## Project layout

| Path | What's there |
|---|---|
| `LAUCaptureVideoPreviewLayer.xcodeproj` | The authoritative build. Four targets, four shared schemes. |
| `lib/` | The library, all of it. `LAUCaptureVideoPreviewLayer.{h,m}` is the layer and the public API (1,399 lines in the `.m`). `LAUCaptureVideoPreviewLayerInternal.{h,m}` owns the capture session and the sample-buffer pipeline. `…Utilities.{h,m}` is shader and program compilation. `…Structures.h`, `…Shaders.h` and `…GaussianFilterKernel.h` are header-only. |
| `lib/LAUCaptureVideoPreviewLayerShaders.h` | **The GLSL that actually runs**, as C string literals — six shader sources, two vertex and four fragment, combined into two programs (default and blur filter). |
| `lib/LAUCaptureVideoPreviewLayerGaussianFilterKernel.h` | 11 precomputed Gaussian kernels, generated by `docs/matlab/LAUCaptureVideoPreviewLayer.m`. Regenerate rather than hand-edit. |
| `resources/shaders/*.vsh`, `*.fsh` | **Reference copies only.** Not in the project, not compiled, not loaded at runtime. See the gotchas. |
| `support/` | `…-Prefix.pch` (the prefix header — `Log`, `PrettyLog`, assertion blocking) and `…-Info.plist` (rewritten by the build). |
| `test/` | `LAUCaptureVideoPreviewLayerTests/` the 4 unit tests, their `UIImage+Compare` category and the mock; `LAUCaptureVideoPreviewLayerUITests/` the one stub UI test; `LAUCaptureVideoPreviewLayerUITestsApplication/` the host app it launches; `Samples.xcassets` the source and reference images both test targets bundle. |
| `examples/LAUCaptureVideoPreviewLayerExample/` | The CocoaPods example app. |
| `scripts/` | `update_version.sh`, run as a build phase of `Static Library`. `clean_version.sh` is wired to nothing — dead. |
| `docs/` | `features.md` (three lines), `figures/` (the README's GIF) and `matlab/` — the MATLAB research script that generates the filter kernels, plus its plots. |
| `Rakefile`, `*.podspec`, `CHANGELOG.md` | The CocoaPods release machinery. Not usable as it stands — see below. |
| `.travis.yml` | Dead, and wrong: it names a different project. |

## The Rakefile, the podspec and the xcodeproj

All three look like build entry points. Only one is:

- **`LAUCaptureVideoPreviewLayer.xcodeproj` is live.** It is how the library is
  built and how both test suites are run. Everything in
  [Build and test](#build-and-test) goes through it.
- **`LAUCaptureVideoPreviewLayer.podspec` is live but only for the example.**
  The example app's Podfile consumes it as a local pod, which is the one thing
  it is actually used for. As a *publishing* manifest it is stale: its
  `homepage` still points at `github.com/coletiv/…` rather than `laugga/…`, its
  `platform` and `deployment_target` still say iOS 7.0 where the project now
  says 15.0, and its `:tag => s.version` (0.1.0) names a tag that does not
  exist. Pull request #2 proposes replacing it with Swift Package Manager.
- **`Rakefile` is dead — do not run it.** `rake spec` is an empty stub with a
  `# Provide your own implementation` comment, so it silently does nothing and
  is *not* how tests are run. `rake release` is worse than useless: it requires
  the `cocoapods` gem at load time, refuses to run unless you are on a branch
  called `master` (this repository's default branch is `main`), and ends in
  `pod push`. It describes a release process that has never been performed here.
  Releasing is not a thing this repository currently does.

## Conventions

Branch names, pull request titles and bodies, and how a pull request references
its task are the same in every Laugga Practice repository and are documented in
[`laugga/ops`](https://github.com/laugga/ops). What is specific here:

- **The default and integration branch is `main`.** Open pull requests against
  it. Ignore the `Rakefile`'s references to `master`.
- **Every type carries the `LAU` prefix; the repository does not.** The
  repository is `VisualEffectCaptureVideoPreviewLayer`, the class is
  `LAUCaptureVideoPreviewLayer`, and the mismatch is deliberate and settled —
  `LAU` replaced an older `LMT` prefix in `d0de99d`. Keep new code on `LAU`;
  do not rename toward the repository name.
- **Every file in `lib/` opens with the MIT-style license header block**
  carrying the file name and `LAUCaptureVideoPreviewLayer`. Copy it into new
  files. `test/` and `examples/` use the short Xcode header instead.
- **Public API is documented with `/*! @property … @abstract … */` HeaderDoc
  blocks**, not `///`. Match the surrounding style — the headers are uniform.
- **Log through the prefix header's macros**, not `NSLog` directly: `Log(…)`,
  `Logc(…)`, `PrettyLog`, `PrettyLogc`. They compile away in Release.
- **Directory names are lowercase** — `lib/`, `test/`, `support/`,
  `resources/`, `scripts/`, `examples/`, `docs/`. This does not conform to
  `CONVENTIONS.md`, which has no row for a CocoaPods static-library repository
  of this age; the whole tree predates the document. Do not partially
  rename toward `Sources/`/`Tests/` — that is a migration, and pull request #2
  is where it belongs.
- **`CHANGELOG.md` has exactly one entry** (`0.1.0`, one line). Add to it only
  if the change is one a consumer would notice; there being no consumers, that
  is rarely.

## Gotchas

- **Building rewrites a tracked file.** The `Run Update Version Script` build
  phase on `Static Library` runs `scripts/update_version.sh`, which stamps
  `CFBundleVersion` in `support/LAUCaptureVideoPreviewLayer-Info.plist` with the
  commit count — in the working tree, not in the built product. Every build
  leaves that file modified. **Never commit it.** Restore it before you stage
  anything:

  ```bash
  git checkout -- support/LAUCaptureVideoPreviewLayer-Info.plist
  ```

  Until LM-598 the same script also *failed the build outright* in a fresh
  clone: it ran `git describe --tags` under `set -e`, and this repository has no
  tags, so the phase exited 128. It is now best-effort and leaves alone what git
  cannot supply. If you see `fatal: No names found, cannot describe anything`,
  something has reverted that fix.

- **The GLSL in `resources/shaders/` is not the GLSL that runs.** The shaders
  the library compiles are C string literals in
  `lib/LAUCaptureVideoPreviewLayerShaders.h`. The `.vsh`/`.fsh` files are not
  referenced by the project, not copied into any bundle, and not loaded at
  runtime — they are readable copies, and they have drifted:
  `blur_filter_bts_unrolled.{vsh,fsh}` has no counterpart in the header at all.
  **Editing a `.fsh` changes nothing.** Change the header, and update the file
  beside it if you want them to keep matching. (This is also why LM-600's
  `#warning` sweep reaches the live shader source for free — it lives in a
  `.h`.)

- **The GLSL itself is not marked, and must not be.** The shader sources are
  not Swift and never will be: GLSL's replacement here is Metal Shading
  Language under pull request #1, not Swift, so "needs to be re-written in
  Swift" would be the wrong claim even if it could be written. And it cannot:
  these shaders declare no `#version`, which makes them GLSL ES 1.00, whose
  preprocessor has no `#warning` — it defines `#define`, `#undef`, `#if`,
  `#ifdef`, `#ifndef`, `#else`, `#elif`, `#endif`, `#error`, `#pragma`,
  `#extension`, `#version` and `#line`, and nothing else. An unrecognised
  directive is a *compile error*, and these shaders compile at runtime, so a
  `#warning` inside one of the string literals in
  `lib/LAUCaptureVideoPreviewLayerShaders.h` would not warn — it would fail
  `glCompileShader` and blank the preview. The same goes for the dead reference
  copies in `resources/shaders/`. The header they live in carries the mark for
  them; the GLSL between the quotes is left alone.

- **`…GaussianFilterKernel.h` defines thirteen non-`static` functions with
  bodies** — `gaussianFilterKernelCount()`, the `dtsGaussianFilter*` accessors,
  the `btsGaussianFilter*` accessors — in the header itself. That works today
  only because exactly one translation unit imports it
  (`LAUCaptureVideoPreviewLayer.m`). `#import`ing it from a second `.m`
  produces duplicate-symbol link errors. If you need one of those accessors
  elsewhere, move its definition into a `.m` first. `…Shaders.h` is also
  header-only but declares its string literals `static`, so it does not have
  this problem — though it is likewise imported by only one file.

- **The blur implementation is selected by `#define`s in the middle of a `.m`.**
  `lib/LAUCaptureVideoPreviewLayer.m:112-113` sets `FilterBoundsEnabled 0` and
  `FilterBilinearTextureSamplingEnabled 1`, and those two choose which of three
  fragment shaders the blur program is linked from
  (`…BlurFilterBts`, `…BlurFilterBtsBounds`, `…BlurFilterDts`). At the current
  settings it is `…BlurFilterBts`, which leaves the other two unreachable.
  Behaviour you cannot reproduce may be behind a flag that is off; check there
  before concluding a shader is broken.

- **The unit tests reach into internal API.** They inject a
  `MockLAUCaptureVideoPreviewLayerInternal` through the public `internal`
  property and call `drawPixelBuffer:` directly to render one frame without a
  camera. Changing the `internal` property, the
  `LAUCaptureVideoPreviewLayerInternal` interface, or `drawPixelBuffer:` breaks
  the tests even though none of it is API anyone was meant to use. There are two
  near-identical copies of that mock — one under
  `test/LAUCaptureVideoPreviewLayerTests/`, one under
  `test/LAUCaptureVideoPreviewLayerUITestsApplication/`. Update both.

- **The Xcode project is from Xcode 8 and its bundle identifiers are stale.**
  `compatibilityVersion = "Xcode 3.2"`, `LastUpgradeCheck = 0730`, and every
  bundle id is `co.coletiv.lightmate.*` — a former organisation. Xcode will
  offer to "update to recommended settings"; **decline it** unless modernising
  the project is the task. Accepting rewrites hundreds of pbxproj lines and
  buries whatever you were actually changing.

- **The library builds for the simulator; a device build is unverified.** The
  commands above all use an iOS Simulator destination. `SDKROOT = iphoneos` and
  `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` are set at the
  project level, and no device build was attempted for this document. Note that
  the simulator's OpenGL ES is an emulation layer — a rendering difference
  between simulator and device is plausible here in a way it would not be for
  ordinary UIKit code.

- **`docs/matlab/LAUCaptureVideoPreviewLayer` is a Photoshop file with no
  extension**, sitting next to the `.m` script of the same name. Not a
  directory, not MATLAB. Leave it alone.

## Definition of done

Before opening a pull request, confirm:

- [ ] `xcodebuild build -project LAUCaptureVideoPreviewLayer.xcodeproj -scheme "Static Library" -destination 'generic/platform=iOS Simulator'` succeeds
- [ ] `xcodebuild test … -scheme "Static Library" -destination 'platform=iOS Simulator,name=iPhone 17'` still fails exactly the two standing image-comparison tests and no others
- [ ] `xcodebuild test … -scheme "UI Tests Application" -destination 'platform=iOS Simulator,name=iPhone 17'` passes
- [ ] `support/LAUCaptureVideoPreviewLayer-Info.plist` is not in the diff
- [ ] No pbxproj churn beyond what the change needs — no "recommended settings" upgrade
- [ ] If a shader changed, `lib/LAUCaptureVideoPreviewLayerShaders.h` changed, not only a file in `resources/shaders/`
- [ ] The change is Objective-C, and does not overlap an already-open migration pull request (#1–#4)
